"""画 App 图标：扁平碗形 + 三缕蒸汽，四个配色方案，最后合成一张对比图。

运行后会生成：
  .workbuddy/icon/variants/a.png .. d.png  （1024 单图）
  .workbuddy/icon/variants/sheet.png       （2x2 对比）
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
S = 3
W = SIZE * S
OUT = Path(__file__).resolve().parent.parent / ".workbuddy" / "icon" / "variants"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(top, bottom):
    image = Image.new("RGB", (W, W), top)
    draw = ImageDraw.Draw(image)
    for y in range(W):
        draw.line([(0, y), (W, y)], fill=lerp(top, bottom, (y / (W - 1)) ** 0.9))
    return image


def steam_stroke(draw, x, top, bottom, base_width, color, lean=1.0):
    """上细下粗的蒸汽：只有一次柔和摆动，太长太卷会像面条。"""
    steps = 70
    for i in range(steps + 1):
        t = i / steps
        y = bottom + (top - bottom) * t
        swing = math.sin(t * math.pi) * 11 * S * lean
        px = x + swing
        width = base_width * (1.0 - 0.62 * t)
        r = max(width / 2, 1.5 * S)
        draw.ellipse((px - r, y - r, px + r, y + r), fill=color)


def bowl_path(rim_y: int, half_width: int, depth: int):
    """碗的轮廓：平口 + 两条二次贝塞尔弧，返回点列表。"""
    cx = W // 2
    left = cx - half_width
    right = cx + half_width
    bottom = rim_y + depth
    points = []
    for i in range(41):
        t = i / 40
        x = (1 - t) ** 2 * left + 2 * (1 - t) * t * (left + half_width * 0.18) + t ** 2 * cx
        y = (1 - t) ** 2 * rim_y + 2 * (1 - t) * t * bottom + t ** 2 * bottom
        points.append((x, y))
    for i in range(1, 41):
        t = i / 40
        x = (1 - t) ** 2 * cx + 2 * (1 - t) * t * (right - half_width * 0.18) + t ** 2 * right
        y = (1 - t) ** 2 * bottom + 2 * (1 - t) * t * bottom + t ** 2 * rim_y
        points.append((x, y))
    return points


def draw_icon(bg_top, bg_bottom, bowl_color, steam_color, rim_color, line_art=False):
    image = vertical_gradient(bg_top, bg_bottom)
    draw = ImageDraw.Draw(image, "RGBA")

    rim_y, half_width, depth = int(W * 0.575), int(W * 0.242), int(W * 0.225)
    points = bowl_path(rim_y, half_width, depth)

    if line_art:
        draw.line(points, fill=bowl_color, width=int(W * 0.052), joint="curve")
    else:
        draw.polygon(points, fill=bowl_color)
        # 碗口厚度：宽度和碗口一致，只往上加，避免两端探出小耳朵
        draw.rounded_rectangle(
            (W // 2 - half_width, rim_y - int(W * 0.024),
             W // 2 + half_width, rim_y + int(W * 0.004)),
            radius=int(W * 0.012),
            fill=bowl_color,
        )

    steam_stroke(draw, int(W * 0.450), int(W * 0.340), int(W * 0.505), int(W * 0.023), steam_color, lean=1.0)
    steam_stroke(draw, int(W * 0.520), int(W * 0.272), int(W * 0.505), int(W * 0.029), steam_color, lean=-1.0)
    steam_stroke(draw, int(W * 0.590), int(W * 0.326), int(W * 0.505), int(W * 0.021), steam_color, lean=1.0)

    return image.resize((SIZE, SIZE), Image.LANCZOS)


VARIANTS = {
    "a": dict(
        bg_top=(252, 247, 238), bg_bottom=(240, 230, 213),
        bowl_color=(30, 90, 71), rim_color=(23, 72, 56),
        steam_color=(201, 107, 69, 205),
    ),
    "b": dict(
        bg_top=(23, 58, 48), bg_bottom=(12, 36, 29),
        bowl_color=(246, 239, 226), rim_color=(255, 252, 246),
        steam_color=(246, 239, 226, 150),
    ),
    "c": dict(
        bg_top=(250, 250, 247), bg_bottom=(242, 242, 238),
        bowl_color=(24, 24, 27, 255), rim_color=(24, 24, 27, 255),
        steam_color=(24, 24, 27, 150), line_art=True,
    ),
    "d": dict(
        bg_top=(255, 250, 242), bg_bottom=(247, 236, 221),
        bowl_color=(176, 84, 47), rim_color=(156, 70, 38),
        steam_color=(214, 154, 92, 210),
    ),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    tiles = []
    for key, options in VARIANTS.items():
        icon = draw_icon(**options)
        icon.save(OUT / f"{key}.png")
        tiles.append(icon.resize((512, 512), Image.LANCZOS))

    sheet = Image.new("RGB", (1064, 1064), (229, 229, 234))
    positions = [(16, 16), (536, 16), (16, 536), (536, 536)]
    for tile, position in zip(tiles, positions):
        sheet.paste(tile, position)
    sheet.save(OUT / "sheet.png")
    print("生成完成：", OUT)


if __name__ == "__main__":
    main()
