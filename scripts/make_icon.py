# /// script
# requires-python = ">=3.12"
# dependencies = ["pillow>=11"]
# ///
"""Generate the 1024x1024 app icon.

Four frosted-glass cards fanned like a hand, one per daily offer; the front card is lit.
Rendered at 2x and downsampled for clean edges. App Store icons must not carry alpha,
so the result is flattened to RGB.

    uv run scripts/make_icon.py
"""

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parents[1] / "ios/Sources/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
S = 2048
RED = (255, 70, 85)


def vertical_gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        column.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return column.resize((w, h))


def radial_glow(center, radius, color, strength):
    layer = Image.new("RGB", (S, S), (0, 0, 0))
    mask = Image.new("L", (S, S), 0)
    cx, cy = center
    ImageDraw.Draw(mask).ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=int(255 * strength))
    mask = mask.filter(ImageFilter.GaussianBlur(radius * 0.45))
    layer.paste(color, mask=mask)
    return layer, mask


def card_shape(w, h, radius, cut):
    """Rounded card with the top-right corner sliced off at 45 degrees."""
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    d.polygon([(w - cut, 0), (w, 0), (w, cut)], fill=0)
    # Re-round the inner edge of the slice so it matches the other corners' softness.
    return mask.filter(ImageFilter.GaussianBlur(1.2))


def make_card(w, h, lit):
    radius, cut = 64, 150
    shape = card_shape(w, h, radius, cut)
    if lit:
        fill = vertical_gradient((w, h), (255, 104, 112), (196, 28, 58))
        alpha = 255
    else:
        fill = vertical_gradient((w, h), (200, 190, 255), (120, 110, 190))
        alpha = 46
    card = fill.convert("RGBA")
    card.putalpha(shape.point(lambda v: v * alpha // 255))

    # Glass sheen: a soft diagonal highlight across the upper half.
    sheen = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sheen).polygon([(0, 0), (w * 1.1, 0), (0, h * 0.7)], fill=80 if lit else 55)
    sheen = ImageChops.multiply(sheen.filter(ImageFilter.GaussianBlur(120)), shape)
    white = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    white.putalpha(sheen)
    card = Image.alpha_composite(card, white)

    # Hairline rim, brighter on glass cards so they read against the dark background.
    rim = ImageChops.subtract(shape, shape.filter(ImageFilter.MinFilter(9)))
    rim_layer = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    rim_layer.putalpha(rim.point(lambda v: v * (150 if lit else 120) // 255))
    card = Image.alpha_composite(card, rim_layer)

    if lit:
        # Drawn on their own layer: ImageDraw overwrites alpha instead of blending.
        marks = Image.new("RGBA", (w, h), (255, 255, 255, 0))
        d = ImageDraw.Draw(marks)
        # Four pips along the bottom: the four daily slots, first one filled.
        pip, gap = 34, 26
        total = 4 * pip + 3 * gap
        x0, y0 = (w - total) // 2, h - 150
        for i in range(4):
            x = x0 + i * (pip + gap)
            box = (x, y0, x + pip, y0 + pip)
            if i == 0:
                d.ellipse(box, fill=(255, 255, 255, 240))
            else:
                d.ellipse(box, outline=(255, 255, 255, 170), width=6)
        # Angular slash mark in the upper body of the card.
        cx, cy = w // 2, int(h * 0.42)
        slash = [(cx - 150, cy + 120), (cx - 40, cy - 150), (cx + 40, cy - 150), (cx - 70, cy + 120)]
        d.polygon(slash, fill=(255, 255, 255, 235))
        slash2 = [(cx + 10, cy + 120), (cx + 120, cy - 150), (cx + 170, cy - 150), (cx + 60, cy + 120)]
        d.polygon(slash2, fill=(255, 255, 255, 120))
        card = Image.alpha_composite(card, marks)
    return card, shape


def paste_rotated(base, card, shape, angle, center, lit):
    rotated = card.rotate(angle, resample=Image.BICUBIC, expand=True)
    rotated_shape = shape.rotate(angle, resample=Image.BICUBIC, expand=True)
    x = center[0] - rotated.width // 2
    y = center[1] - rotated.height // 2
    box = (x, y, x + rotated.width, y + rotated.height)
    # Shadow is blurred on the full canvas so its falloff is not clipped to the card's box.
    alpha = Image.new("L", base.size, 0)
    alpha.paste(rotated_shape, (x + 16, y + 44))
    alpha = alpha.filter(ImageFilter.GaussianBlur(60))
    shade = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shade.putalpha(alpha.point(lambda v: v * (170 if lit else 90) // 255))
    base.alpha_composite(shade)
    if not lit:
        # Frosted glass: whatever sits behind the card, heavily blurred, seen through it.
        # Blur the whole canvas before cropping; blurring a crop darkens its edges into seams.
        frosted = base.filter(ImageFilter.GaussianBlur(46)).crop(box)
        frosted = Image.eval(frosted, lambda v: min(255, int(v * 1.25 + 14)))
        base.paste(frosted, box[:2], rotated_shape)
    base.alpha_composite(rotated, (x, y))


def main() -> None:
    bg = vertical_gradient((S, S), (18, 16, 36), (8, 8, 16))
    glow, glow_mask = radial_glow((int(S * 0.6), int(S * 0.52)), 820, RED, 0.8)
    bg = Image.composite(glow, bg, glow_mask)
    violet, violet_mask = radial_glow((int(S * 0.24), int(S * 0.3)), 700, (120, 80, 255), 0.55)
    bg = Image.composite(violet, bg, violet_mask).convert("RGBA")

    w, h = 600, 840
    pivot = (S // 2, int(S * 1.15))
    # Symmetric fan; the lit card is last so it sits on top.
    fan = [(-24, False), (-8, False), (8, False), (24, True)]
    for angle, lit in fan:
        # Rotate each card around a pivot below the canvas so the fan arcs like a held hand.
        distance = pivot[1] - int(S * 0.5)
        rad = math.radians(angle)
        center = (int(pivot[0] + distance * math.sin(rad)), int(pivot[1] - distance * math.cos(rad)))
        card, shape = make_card(w, h, lit)
        paste_rotated(bg, card, shape, -angle, center, lit)

    icon = bg.convert("RGB").resize((1024, 1024), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.save(OUT, "PNG")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
