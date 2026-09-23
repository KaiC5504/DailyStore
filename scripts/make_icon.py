#!/usr/bin/env python3
"""Generate the 1024x1024 app icon. Run once; commit the PNG.

Placeholder art: four tiles for the four daily offers. Replace when the real design exists.
App Store Connect rejects an upload with no 1024 icon, so something has to be here.

    python -m pip install --user pillow
    python scripts/make_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT = Path(__file__).resolve().parents[1] / "ios/Sources/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main() -> None:
    top, bottom = (16, 18, 28), (52, 22, 34)
    img = Image.new("RGB", (SIZE, SIZE), top)
    px = img.load()
    for y in range(SIZE):
        row = lerp(top, bottom, y / (SIZE - 1))
        for x in range(SIZE):
            px[x, y] = row

    glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    ImageDraw.Draw(glow).ellipse((200, 160, 824, 784), fill=(255, 70, 85))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    img = Image.blend(img, Image.composite(glow, img, glow.convert("L")), 0.5)

    draw = ImageDraw.Draw(img, "RGBA")
    gap, tile, radius = 40, 232, 44
    origin = (SIZE - (2 * tile + gap)) // 2
    alphas = iter((235, 150, 150, 90))
    for row in range(2):
        for col in range(2):
            x = origin + col * (tile + gap)
            y = origin + row * (tile + gap)
            draw.rounded_rectangle(
                (x, y, x + tile, y + tile), radius=radius, fill=(255, 255, 255, next(alphas))
            )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # RGB on purpose: App Store icons must not carry an alpha channel.
    img.save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
