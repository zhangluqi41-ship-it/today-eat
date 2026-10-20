"""把 Data/*.txt 的紧凑菜谱稿编译成 App 用的 SeedRecipes.json。

稿件格式（每道菜一段）：
  @ 菜名 | 分类key | 类型 | 分钟 | 难度 | 辣度 | 标签,标签
  - 主料名 | 用量          （"-" 主料，可多行）
  + 调料名 | 用量          （"+" 调料，可多行）
  > 步骤文字               （">" 一行一步，按出现顺序）
  ! 窍门                   （"!" 一行，最后一行生效）

这份脚本只做编译和体检，不改写任何文字内容。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Data"
OUTPUT = ROOT / "Sources" / "Resources" / "SeedRecipes.json"

# 顺序即 App 里的分类顺序
CATEGORY_FILES = [
    ("pork", "猪肉", "🍖"),
    ("poultry", "禽类", "🍗"),
    ("beef", "牛肉", "🥩"),
    ("veggie", "蔬菜", "🥬"),
    ("tofu", "豆制品", "🧈"),
    ("egg", "蛋类", "🥚"),
]
KINDS = {"荤", "素", "汤", "蛋", "豆"}
MIN_INGREDIENTS = 3
MIN_STEPS = 4


class Problem(Exception):
    pass


def parse_file(path: Path, category_key: str) -> list[dict]:
    dishes: list[dict] = []
    current: dict | None = None
    line_number = 0

    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        line_number += 1
        line = raw.strip()
        if not line or line.startswith("//"):
            continue

        if line.startswith("@"):
            if current:
                dishes.append(current)
            parts = [p.strip() for p in line[1:].split("|")]
            if len(parts) != 7:
                raise Problem(f"{path.name}:{line_number} 头部字段应为 7 段，实际 {len(parts)}")
            name, key, kind, minutes, difficulty, spicy, tags = parts
            if key != category_key:
                raise Problem(f"{path.name}:{line_number} 分类 key 不符：{key}")
            if kind not in KINDS:
                raise Problem(f"{path.name}:{line_number} 未知类型：{kind}")
            current = {
                "name": name,
                "category": category_key,
                "kind": kind,
                "minutes": int(minutes),
                "difficulty": int(difficulty),
                "spicy": int(spicy),
                "tags": [t for t in re.split(r"[,，]", tags) if t],
                "ingredients": [],
                "steps": [],
                "tips": "",
                "_line": line_number,
            }
            continue

        if current is None:
            raise Problem(f"{path.name}:{line_number} 在菜名之前出现内容")

        marker = line[0]
        body = line[1:].strip()

        if marker in "-+":
            name, _, amount = body.partition("|")
            name, amount = name.strip(), amount.strip()
            if not name or not amount:
                raise Problem(f"{path.name}:{line_number} 配料缺名称或用量：{body}")
            current["ingredients"].append(
                {"name": name, "amount": amount, "group": "主料" if marker == "-" else "调料"}
            )
        elif marker == ">":
            if len(body) < 4:
                raise Problem(f"{path.name}:{line_number} 步骤太短：{body}")
            current["steps"].append(body)
        elif marker == "!":
            current["tips"] = body
        else:
            raise Problem(f"{path.name}:{line_number} 无法识别的行：{line[:20]}")

    if current:
        dishes.append(current)
    return dishes


def check(dishes: list[dict]) -> list[str]:
    warnings: list[str] = []
    seen: dict[str, str] = {}
    for dish in dishes:
        where = f"{dish['category']}/{dish['name']}"
        if dish["name"] in seen:
            raise Problem(f"菜名重复：{dish['name']}（{seen[dish['name']]} 与 {where}）")
        seen[dish["name"]] = where
        if len(dish["ingredients"]) < MIN_INGREDIENTS:
            raise Problem(f"{where} 配料只有 {len(dish['ingredients'])} 项")
        if len(dish["steps"]) < MIN_STEPS:
            raise Problem(f"{where} 步骤只有 {len(dish['steps'])} 步")
        if not dish["tips"]:
            raise Problem(f"{where} 缺窍门")
        if not 3 <= dish["minutes"] <= 240:
            raise Problem(f"{where} 耗时异常：{dish['minutes']}")
        if not 1 <= dish["difficulty"] <= 3:
            raise Problem(f"{where} 难度异常：{dish['difficulty']}")
        if not 0 <= dish["spicy"] <= 3:
            raise Problem(f"{where} 辣度异常：{dish['spicy']}")
        if any("|" in step for step in dish["steps"]):
            warnings.append(f"{where} 步骤里出现竖线，检查是否漏拆字段")
    return warnings


def main() -> int:
    all_dishes: list[dict] = []
    summary = []
    for index, (key, display, emoji) in enumerate(CATEGORY_FILES, start=1):
        path = DATA / f"{key}.txt"
        parsed = parse_file(path, key)
        for position, dish in enumerate(parsed, start=1):
            dish.pop("_line", None)
            dish["id"] = f"{key}-{position:02d}"
            dish["source"] = "内置菜谱"
        all_dishes.extend(parsed)
        summary.append((display, emoji, len(parsed)))

    warnings = check(all_dishes)

    payload = {
        "version": 1,
        "categories": [
            {"key": key, "name": display, "emoji": emoji, "order": i}
            for i, (key, display, emoji) in enumerate(CATEGORY_FILES, start=1)
        ],
        "dishes": all_dishes,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )

    print("分类统计：")
    for display, emoji, count in summary:
        print(f"  {emoji} {display}: {count} 道")
    print(f"合计 {len(all_dishes)} 道菜，输出 {OUTPUT.relative_to(ROOT)}")
    print(f"文件大小 {OUTPUT.stat().st_size / 1024:.1f} KB")
    if warnings:
        print("提醒：")
        for item in warnings:
            print("  -", item)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Problem as error:
        print("编译失败：", error)
        sys.exit(1)
