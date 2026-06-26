#!/usr/bin/env python3
"""Generate Recipes web/PWA icons from the cheese ingredient sprite.

The ingredient sprite includes a gameplay shadow sized for table cards. App icons
need a tighter shadow so the cheese reads cleanly at favicon and launcher sizes.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
WEB_DIR = ROOT / "client" / "web"
SOURCE_CHEESE = ROOT / "art" / "cheese_64.png"


def _rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _cheese_without_source_shadow() -> Image.Image:
    cheese = Image.open(SOURCE_CHEESE).convert("RGBA")
    pixels = cheese.load()
    for y in range(cheese.height):
        for x in range(cheese.width):
            r, g, b, a = pixels[x, y]
            if a < 120:
                pixels[x, y] = (r, g, b, 0)
    return cheese


def _paste_centered(canvas: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
    canvas.alpha_composite(image, (center[0] - image.width // 2, center[1] - image.height // 2))


def _resize_sprite(sprite: Image.Image, target_width: int) -> Image.Image:
    scale = target_width / float(sprite.width)
    return sprite.resize((target_width, int(round(sprite.height * scale))), Image.Resampling.NEAREST)


def _icon(size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    pad = max(4, int(size * 0.055))
    radius = int(size * 0.18)
    outer = (pad, pad, size - pad, size - pad)
    shadow_offset = max(2, int(size * 0.025))

    draw.rounded_rectangle(
        (outer[0] + shadow_offset, outer[1] + shadow_offset, outer[2], outer[3]),
        radius=radius,
        fill=(64, 37, 16, 82),
    )
    draw.rounded_rectangle(outer, radius=radius, fill=(247, 211, 83, 255), outline=(96, 57, 22, 255), width=max(2, int(size * 0.027)))

    inner = int(size * 0.77)
    draw.rounded_rectangle(
        ((size - inner) // 2, int(size * 0.08), (size + inner) // 2, int(size * 0.82)),
        radius=int(size * 0.10),
        fill=(255, 226, 101, 255),
    )

    shadow_w = int(size * 0.32)
    shadow_h = max(3, int(size * 0.045))
    shadow_y = int(size * 0.70)
    draw.ellipse(
        (size // 2 - shadow_w // 2, shadow_y - shadow_h // 2, size // 2 + shadow_w // 2, shadow_y + shadow_h // 2),
        fill=(89, 52, 23, 95),
    )

    cheese = _resize_sprite(_cheese_without_source_shadow(), int(size * 0.56))
    _paste_centered(canvas, cheese, (size // 2, int(size * 0.48)))
    return canvas


def _splash() -> Image.Image:
    canvas = Image.new("RGBA", (640, 360), (235, 217, 165, 255))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((244, 40, 396, 320), radius=28, fill=(247, 211, 83, 255))
    draw.rounded_rectangle((244, 40, 396, 68), radius=16, fill=(106, 60, 22, 255))
    draw.rounded_rectangle((244, 58, 396, 68), fill=(106, 60, 22, 255))

    draw.ellipse((276, 205, 364, 226), fill=(89, 52, 23, 88))
    cheese = _resize_sprite(_cheese_without_source_shadow(), 146)
    _paste_centered(canvas, cheese, (320, 176))
    return canvas


def main() -> None:
    WEB_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "index.144x144.png": _icon(144),
        "index.180x180.png": _icon(180),
        "index.512x512.png": _icon(512),
        "index.apple-touch-icon.png": _icon(180),
        "index.icon.png": _icon(512),
        "index.png": _splash(),
    }
    for name, image in outputs.items():
        image.save(WEB_DIR / name)
    print("Generated web icons with tighter cheese shadows.")


if __name__ == "__main__":
    main()
