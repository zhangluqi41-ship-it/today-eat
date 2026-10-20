"""画 App 图标：一碗热汤 + 一双筷子，纯代码生成，不依赖外部素材。

尺寸按 1024 设计，内部 3 倍超采样再缩小，边缘干净。
"""

import math

from PIL import Image, ImageDraw, ImageFilter

S = 3
W = 1024 * S


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def steam(draw, x, top, bottom, width, color, direction=1):
    """一条上扬的 S 形蒸汽。"""
    points = []
    steps = 60
    amp = 11 * S
    for i in range(steps + 1):
        t = i / steps
        y = bottom + (top - bottom) * t
        points.append((x + direction * amp * math.sin(math.pi * 1.7 * t), y))
    draw.line(points, fill=color, width=width, joint="curve")


def main():
    image = Image.new("RGB", (W, W), (255, 227, 196))
    draw = ImageDraw.Draw(image)

    # 背景：上浅下深的暖色渐变
    top_color = (255, 231, 203)
    bottom_color = (255, 148, 84)
    for y in range(W):
        t = y / (W - 1)
        draw.line([(0, y), (W, y)], fill=lerp(top_color, bottom_color, t ** 0.85))

    # 中间柔光
    glow = Image.new("L", (W, W), 0)
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        (W * 0.04, W * 0.10, W * 0.96, W * 0.92),
        fill=90,
    )
    glow = glow.filter(ImageFilter.GaussianBlur(W // 12))
    white = Image.new("RGB", (W, W), (255, 246, 232))
    image = Image.composite(white, image, glow.point(lambda v: int(v * 0.55)))
    draw = ImageDraw.Draw(image, "RGBA")

    # 蒸汽
    steam_color = (255, 255, 255, 175)
    steam(draw, int(W * 0.40), int(W * 0.245), int(W * 0.405), int(5 * S), steam_color, direction=1)
    steam(draw, int(W * 0.52), int(W * 0.205), int(W * 0.395), int(6 * S), steam_color, direction=-1)
    steam(draw, int(W * 0.64), int(W * 0.255), int(W * 0.405), int(5 * S), steam_color, direction=1)

    # 地面阴影
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((W * 0.30, W * 0.79, W * 0.70, W * 0.86), fill=(160, 60, 20, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(W // 40))
    image = Image.alpha_composite(image.convert("RGBA"), shadow).convert("RGB")
    draw = ImageDraw.Draw(image, "RGBA")

    # 碗身
    body = (W * 0.22, W * 0.165, W * 0.78, W * 0.81)
    draw.pieslice(body, start=0, end=180, fill=(255, 253, 249))
    # 碗底的一小段收口
    draw.ellipse((W * 0.435, W * 0.795, W * 0.565, W * 0.835), fill=(248, 238, 226))

    # 碗口：橙色厚边 + 汤
    draw.ellipse((W * 0.215, W * 0.405, W * 0.785, W * 0.585), fill=(244, 112, 43))
    draw.ellipse((W * 0.255, W * 0.435, W * 0.745, W * 0.565), fill=(184, 58, 24))
    draw.ellipse((W * 0.275, W * 0.448, W * 0.725, W * 0.552), fill=(198, 66, 28))

    # 汤里的料：几段面 + 葱花
    draw.line([(W * 0.33, W * 0.515), (W * 0.44, W * 0.487), (W * 0.55, W * 0.512)], fill=(246, 206, 148), width=int(9 * S), joint="curve")
    draw.line([(W * 0.40, W * 0.535), (W * 0.53, W * 0.505), (W * 0.64, W * 0.528)], fill=(246, 206, 148), width=int(9 * S), joint="curve")
    for x, y, r in [(0.365, 0.468, 0.012), (0.585, 0.470, 0.010), (0.505, 0.540, 0.011)]:
        draw.ellipse(
            (W * (x - r), W * (y - r), W * (x + r), W * (y + r)),
            fill=(126, 191, 95),
        )

    # 筷子：斜搭在碗沿上
    chopsticks = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    stick_draw = ImageDraw.Draw(chopsticks)
    length = int(W * 0.62)
    thickness = int(W * 0.026)
    for offset in (0, int(W * 0.045)):
        stick_draw.rounded_rectangle(
            (int(W * 0.10), int(W * 0.36) + offset, int(W * 0.10) + length, int(W * 0.36) + offset + thickness),
            radius=thickness // 2,
            fill=(74, 44, 30, 255),
        )
    chopsticks = chopsticks.rotate(-27, resample=Image.BICUBIC, center=(W * 0.5, W * 0.5))
    image = Image.alpha_composite(image.convert("RGBA"), chopsticks).convert("RGB")

    image = image.resize((1024, 1024), Image.LANCZOS)
    image.save("Sources/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
    print("图标已生成 1024x1024")


if __name__ == "__main__":
    main()
