#!/usr/bin/env python3

import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parent
ICONSET = ROOT / "MacCleaner.iconset"
OUTPUT_ICNS = ROOT / "MacCleaner.icns"
OUTPUT_PNG = ROOT / "MacCleaner-1024.png"

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def lerp(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, mid, bottom):
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        if t < 0.55:
            c = lerp(top, mid, t / 0.55)
        else:
            c = lerp(mid, bottom, (t - 0.55) / 0.45)
        for x in range(size):
            px[x, y] = (*c, 255)
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def add_soft_glow(base, bbox, color, blur):
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse(bbox, fill=color)
    glow = glow.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(base, glow)


def draw_sparkle(draw, cx, cy, outer, inner, fill):
    points = [
        (cx, cy - outer),
        (cx + inner, cy - inner),
        (cx + outer, cy),
        (cx + inner, cy + inner),
        (cx, cy + outer),
        (cx - inner, cy + inner),
        (cx - outer, cy),
        (cx - inner, cy - inner),
    ]
    draw.polygon(points, fill=fill)


def make_icon(size):
    base = vertical_gradient(
        size,
        top=(118, 108, 242),
        mid=(196, 78, 234),
        bottom=(80, 18, 121),
    )

    base = add_soft_glow(
        base,
        (-0.18 * size, -0.22 * size, 0.62 * size, 0.48 * size),
        (90, 214, 255, 120),
        int(size * 0.09),
    )
    base = add_soft_glow(
        base,
        (0.28 * size, -0.15 * size, 1.05 * size, 0.64 * size),
        (255, 122, 214, 128),
        int(size * 0.13),
    )
    base = add_soft_glow(
        base,
        (0.10 * size, 0.42 * size, 0.95 * size, 1.10 * size),
        (99, 29, 138, 130),
        int(size * 0.14),
    )

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hdraw = ImageDraw.Draw(highlight)
    hdraw.rounded_rectangle(
        (
            size * 0.10,
            size * 0.05,
            size * 0.66,
            size * 0.36,
        ),
        radius=size * 0.12,
        fill=(255, 255, 255, 40),
    )
    highlight = highlight.filter(ImageFilter.GaussianBlur(int(size * 0.03)))
    base = Image.alpha_composite(base, highlight)

    vignette = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    vdraw.rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=int(size * 0.23),
        outline=(255, 255, 255, 28),
        width=max(2, size // 128),
    )
    base = Image.alpha_composite(base, vignette)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    draw_sparkle(
        sdraw,
        size * 0.50,
        size * 0.54,
        size * 0.20,
        size * 0.06,
        (0, 0, 0, 70),
    )
    draw_sparkle(
        sdraw,
        size * 0.33,
        size * 0.39,
        size * 0.10,
        size * 0.035,
        (0, 0, 0, 50),
    )
    draw_sparkle(
        sdraw,
        size * 0.58,
        size * 0.26,
        size * 0.07,
        size * 0.025,
        (0, 0, 0, 40),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(size * 0.015)))

    art = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    adraw = ImageDraw.Draw(art)
    draw_sparkle(
        adraw,
        size * 0.50,
        size * 0.52,
        size * 0.20,
        size * 0.06,
        (255, 255, 255, 245),
    )
    draw_sparkle(
        adraw,
        size * 0.33,
        size * 0.39,
        size * 0.10,
        size * 0.035,
        (255, 255, 255, 235),
    )
    draw_sparkle(
        adraw,
        size * 0.58,
        size * 0.26,
        size * 0.07,
        size * 0.025,
        (255, 255, 255, 235),
    )

    combined = Image.alpha_composite(base, shadow)
    combined = Image.alpha_composite(combined, art)

    mask = rounded_mask(size, int(size * 0.23))
    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final.paste(combined, (0, 0), mask)
    return final


def main():
    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True, exist_ok=True)

    img_1024 = make_icon(1024)
    img_1024.save(OUTPUT_PNG)

    for base_size in SIZES[:-1]:
        img = img_1024.resize((base_size, base_size), Image.Resampling.LANCZOS)
        img.save(ICONSET / f"icon_{base_size}x{base_size}.png")

        retina = img_1024.resize((base_size * 2, base_size * 2), Image.Resampling.LANCZOS)
        retina.save(ICONSET / f"icon_{base_size}x{base_size}@2x.png")

    img_1024.save(ICONSET / "icon_512x512@2x.png")

    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(OUTPUT_ICNS)], check=True)


if __name__ == "__main__":
    main()
