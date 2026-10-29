"""在这台 Windows 上把工程推到 GitHub、等 macOS runner 编出 IPA、再把包下载回来。

令牌从本机凭据管理器现取，只在内存里用，不落盘、不打印。
用法：python Scripts/cloud_build.py
"""

from __future__ import annotations

import base64
import glob
import hashlib
import io
import json
import os
import subprocess
import sys
import time
import zipfile
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen

ROOT = Path(__file__).resolve().parent.parent
REPO_NAME = "today-eat"
BRANCH = "main"
OUT_DIR = ROOT / "dist"
LOG_FILE = ROOT / ".workbuddy" / "build-log.txt"
BUILD_TIMEOUT = 30 * 60


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def find_git() -> str:
    candidates = sorted(glob.glob(os.path.expandvars(
        r"%USERPROFILE%\.workbuddy\binaries\PortableGit\versions\*\mingw64\bin\git.exe")))
    if not candidates:
        raise SystemExit("找不到便携版 git")
    return candidates[-1]


GIT = find_git()


def credentials() -> tuple[str, str]:
    """从凭据管理器取 GitHub 账号与令牌。"""
    result = subprocess.run(
        [GIT, "-c", "credential.helper=manager", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        capture_output=True,
        text=True,
        env={**os.environ, "GCM_INTERACTIVE": "never", "GIT_TERMINAL_PROMPT": "0"},
        timeout=60,
    )
    if result.returncode != 0:
        raise SystemExit("本机没有 GitHub 凭据，请先在浏览器登录一次")
    data = {}
    for line in result.stdout.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            data[key.strip()] = value.strip()
    user, token = data.get("username"), data.get("password")
    if not token:
        raise SystemExit("凭据里没有令牌")
    return user or "", token


TOKEN = ""
REPO = ""


def api(method: str, path: str, body: dict | None = None, allow_redirect: bool = False):
    url = path if path.startswith("http") else "https://api.github.com" + path
    payload = json.dumps(body).encode() if body is not None else None
    req = Request(url, data=payload, method=method)
    req.add_header("Authorization", "Bearer " + TOKEN)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    if payload:
        req.add_header("Content-Type", "application/json")
    opener = build_opener() if allow_redirect else build_opener(NoRedirect)
    try:
        with opener.open(req, timeout=120) as resp:
            raw = resp.read()
            return json.loads(raw) if raw and resp.headers.get("Content-Type", "").startswith("application/json") else raw
    except HTTPError as error:
        if error.code in (301, 302, 303, 307, 308):
            return {"__redirect__": error.headers.get("Location")}
        detail = error.read().decode("utf-8", "replace")[:400]
        raise RuntimeError(f"{method} {path} -> {error.code} {detail}") from None


def ensure_repo(login: str) -> str:
    try:
        info = api("GET", f"/repos/{login}/{REPO_NAME}")
        print(f"仓库已存在：{info['full_name']}", flush=True)
        return info["full_name"]
    except RuntimeError as error:
        if "-> 404" not in str(error):
            raise
    info = api("POST", "/user/repos", {
        "name": REPO_NAME,
        "private": False,
        "auto_init": False,
        "description": "今晚吃什么 · 213 道家常菜 + 抽签决定",
    })
    print(f"已创建公开仓库：{info['full_name']}", flush=True)
    return info["full_name"]


def local_files() -> list[str]:
    # core.quotepath=false：中文文件名不能被转义成 "\344\273\212" 这种形式，否则读不到文件
    result = subprocess.run(
        [GIT, "-c", "core.quotepath=false", "ls-files"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def local_head() -> str:
    result = subprocess.run([GIT, "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True)
    return result.stdout.strip()


def verify_remote(login: str, sha: str) -> None:
    ref = api("GET", f"/repos/{login}/{REPO_NAME}/git/ref/heads/{BRANCH}")
    remote_sha = ref["object"]["sha"]
    if remote_sha != sha:
        raise SystemExit(f"回读校验失败：远端 {remote_sha[:8]} != 本地 {sha[:8]}")
    print(f"  回读校验通过：远端 {remote_sha[:8]}", flush=True)


def push_with_git(login: str) -> bool:
    """优先用 git push：走 delta 压缩，比逐个 blob 快得多。令牌放在请求头里，不写进 URL。"""
    token_b64 = base64.b64encode(f"x-access-token:{TOKEN}".encode()).decode()
    remote = f"https://github.com/{login}/{REPO_NAME}.git"
    command = [
        GIT,
        "-c", "credential.helper=",
        "-c", f"http.extraheader=AUTHORIZATION: basic {token_b64}",
        "push", remote, f"HEAD:refs/heads/{BRANCH}", "--force",
    ]
    print("用 git push 上传…", flush=True)
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode == 0:
        return True
    message = (result.stderr or result.stdout).strip().splitlines()
    print("  git push 失败：" + (message[-1] if message else "未知原因"), flush=True)
    return False


def ensure_initial_commit(login: str) -> str:
    """返回远端当前 head；空仓库则先用 Contents API 建一个初始提交。"""
    try:
        ref = api("GET", f"/repos/{login}/{REPO_NAME}/git/ref/heads/{BRANCH}")
        return ref["object"]["sha"]
    except RuntimeError as error:
        if "-> 404" not in str(error):
            raise
    content = base64.b64encode("今晚吃什么\n".encode()).decode()
    result = api("PUT", f"/repos/{login}/{REPO_NAME}/contents/README.md", {
        "message": "init",
        "content": content,
    })
    print("  空仓库已建初始提交", flush=True)
    return result["commit"]["sha"]


def push_with_api(login: str) -> str:
    """git push 不通时的兜底：blobs -> tree -> commit -> ref。"""
    files = local_files()
    print(f"改用 REST API 上传 {len(files)} 个文件…", flush=True)
    parent = ensure_initial_commit(login)
    parent_commit = api("GET", f"/repos/{login}/{REPO_NAME}/git/commits/{parent}")
    tree = []
    for index, rel in enumerate(files, start=1):
        data = (ROOT / rel).read_bytes()
        blob = api("POST", f"/repos/{login}/{REPO_NAME}/git/blobs", {
            "content": base64.b64encode(data).decode(),
            "encoding": "base64",
        })
        tree.append({"path": rel, "mode": "100644", "type": "blob", "sha": blob["sha"]})
        if index % 5 == 0 or index == len(files):
            print(f"  已上传 {index}/{len(files)}", flush=True)
    tree_result = api("POST", f"/repos/{login}/{REPO_NAME}/git/trees", {
        "base_tree": parent_commit["tree"]["sha"],
        "tree": tree,
    })
    commit = api("POST", f"/repos/{login}/{REPO_NAME}/git/commits", {
        "message": "今晚吃什么：213 道菜 + SwiftUI App",
        "tree": tree_result["sha"],
        "parents": [parent],
    })
    api("PATCH", f"/repos/{login}/{REPO_NAME}/git/refs/heads/{BRANCH}", {
        "sha": commit["sha"],
        "force": True,
    })
    return commit["sha"]


def push(login: str) -> str:
    sha = local_head()
    ok = push_with_git(login)
    if not ok:
        sha = push_with_api(login)
    verify_remote(login, sha)
    print(f"已推送，commit {sha[:8]}", flush=True)
    return sha


def wait_for_run(sha: str) -> dict:
    started = time.time()
    seen = None
    while time.time() - started < BUILD_TIMEOUT:
        runs = api("GET", f"/repos/{REPO}/actions/runs?branch={BRANCH}&per_page=10")
        target = next((r for r in runs.get("workflow_runs", []) if r.get("head_sha") == sha), None)
        if target is None:
            print("  等 CI 接单…", flush=True)
            time.sleep(10)
            continue
        if seen != target["status"]:
            seen = target["status"]
            print(f"  CI 状态：{target['status']} / {target.get('conclusion') or '进行中'}", flush=True)
        if target["status"] == "completed":
            return target
        time.sleep(15)
    raise SystemExit("构建超时")


def fetch_logs(run_id: int) -> None:
    jobs = api("GET", f"/repos/{REPO}/actions/runs/{run_id}/jobs")
    collected = []
    for job in jobs.get("jobs", []):
        if job.get("conclusion") != "failure":
            continue
        print(f"  失败 job：{job['name']}", flush=True)
        for step in job.get("steps", []):
            if step.get("conclusion") == "failure":
                print(f"    失败步骤：{step['name']}", flush=True)
        log_url = f"/repos/{REPO}/actions/jobs/{job['id']}/logs"
        result = api("GET", log_url)
        text = ""
        if isinstance(result, dict) and "__redirect__" in result:
            with urlopen(result["__redirect__"], timeout=120) as resp:
                text = resp.read().decode("utf-8", "replace")
        elif isinstance(result, bytes):
            text = result.decode("utf-8", "replace")
        collected.append(f"===== {job['name']} =====\n{text}")
        errors = [line for line in text.splitlines() if "error:" in line.lower()]
        for line in errors[:25]:
            print("    " + line.strip()[:220], flush=True)
    if collected:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        LOG_FILE.write_text("\n\n".join(collected), encoding="utf-8")
        print(f"  完整日志已存到 {LOG_FILE}", flush=True)


def download_ipa(run_id: int) -> None:
    for attempt in range(10):
        artifacts = api("GET", f"/repos/{REPO}/actions/runs/{run_id}/artifacts")
        target = next((a for a in artifacts.get("artifacts", []) if a["name"] == "TodayEat-ipa"), None)
        if target:
            break
        print("  等 artifact 生成…", flush=True)
        time.sleep(6)
    else:
        raise SystemExit("找不到 artifact")

    result = api("GET", target["archive_download_url"])
    if not (isinstance(result, dict) and "__redirect__" in result):
        raise SystemExit("artifact 下载没有拿到重定向地址")
    # 关键：签名地址必须匿名取，带上 Authorization 会被 Azure 直接 403
    with urlopen(result["__redirect__"], timeout=180) as resp:
        blob = resp.read()
    print(f"  下载完成 {len(blob) / 1024 / 1024:.1f} MB", flush=True)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(blob)) as archive:
        for name in archive.namelist():
            if name.endswith(".ipa"):
                data = archive.read(name)
                out = OUT_DIR / Path(name).name
                out.write_bytes(data)
                digest = hashlib.sha256(data).hexdigest()
                print(f"  解出 {out.name}（{len(data) / 1024 / 1024:.1f} MB）", flush=True)
                print(f"  SHA256 {digest[:16]}…", flush=True)


def main() -> None:
    global TOKEN, REPO
    user, token = credentials()
    TOKEN = token
    me = api("GET", "/user")
    login = me["login"]
    print(f"账号 {login}（凭据里记的是 {user}）", flush=True)

    repo_full = ensure_repo(login)
    REPO = repo_full
    sha = push(login)
    run = wait_for_run(sha)
    print(f"运行结果：{run['conclusion']}  {run['html_url']}", flush=True)

    if run["conclusion"] != "success":
        fetch_logs(run["id"])
        print("构建失败，日志见上。", flush=True)
        sys.exit(2)

    download_ipa(run["id"])
    print(f"RELEASE https://github.com/{REPO}/releases", flush=True)
    print("完成", flush=True)


if __name__ == "__main__":
    main()
