"""把菜谱数据和一个 180px 图标打进单文件网页，生成可以直接发给手机用的 HTML。"""

import base64
import io
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "web" / "app.html"
SEED = ROOT / "Sources" / "Resources" / "SeedRecipes.json"
ICON = ROOT / "Sources" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
OUTPUT = ROOT / "dist" / "今晚吃什么.html"


def icon_data_uri(size: int = 180) -> str:
    image = Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def main() -> None:
    payload = json.loads(SEED.read_text(encoding="utf-8"))
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    # 内联 JSON 里不能出现 </script，转义斜杠即可
    data = data.replace("</", "<\\/")

    html = TEMPLATE.read_text(encoding="utf-8")
    if "__RECIPES__" not in html or "__ICON__" not in html:
        raise SystemExit("模板占位符丢了，检查 web/app.html")

    html = html.replace("__RECIPES__", data).replace("__ICON__", icon_data_uri())
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(html, encoding="utf-8")

    # 顺手把内联脚本抽出来做一次语法体检
    scripts = re.findall(r'<script charset="utf-8">(.*?)</script>', html, flags=re.S)
    if not scripts:
        scripts = re.findall(r"<script>\n(.*?)</script>", html, flags=re.S)
    if scripts:
        (ROOT / ".workbuddy" / "tmp").mkdir(parents=True, exist_ok=True)
        (ROOT / ".workbuddy" / "tmp" / "app.js").write_text(scripts[-1], encoding="utf-8")

    print(f"菜谱 {len(payload['dishes'])} 道")
    print(f"输出 {OUTPUT.relative_to(ROOT)}，{OUTPUT.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    main()
