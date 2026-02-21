#!/usr/bin/env python3
"""Generate DMG background image with drag-to-Applications guide."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

# DMG window size: 600x400
W, H = 600, 400


def create_dmg_background():
    img = Image.new("RGBA", (W * 2, H * 2), (0, 0, 0, 0))  # @2x for retina
    draw = ImageDraw.Draw(img)
    sw, sh = W * 2, H * 2

    # Background gradient: dark indigo to navy (matching app theme)
    for y in range(sh):
        ratio = y / sh
        r = int(22 + ratio * 5)
        g = int(15 + ratio * 10)
        b = int(55 + ratio * 15)
        for x in range(sw):
            img.putpixel((x, y), (r, g, b, 255))

    # Subtle radial glow in center
    cx, cy = sw // 2, sh // 2
    for radius in range(400, 0, -2):
        alpha = int(8 * (1.0 - radius / 400.0))
        draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                     fill=(60, 200, 170, alpha))

    # Draw a dashed arrow from left area to right area
    arrow_y = sh // 2 + 30
    arrow_x_start = sw // 2 - 120
    arrow_x_end = sw // 2 + 120

    # Dashed line
    dash_len = 16
    gap_len = 12
    x = arrow_x_start
    while x < arrow_x_end - 30:
        x2 = min(x + dash_len, arrow_x_end - 30)
        draw.line([(x, arrow_y), (x2, arrow_y)], fill=(120, 220, 190, 150), width=4)
        x += dash_len + gap_len

    # Arrowhead
    ah_x = arrow_x_end - 10
    draw.polygon([
        (ah_x + 20, arrow_y),
        (ah_x - 5, arrow_y - 18),
        (ah_x - 5, arrow_y + 18),
    ], fill=(120, 220, 190, 180))

    # Text labels
    try:
        font_paths = [
            "/System/Library/Fonts/SFCompact-Medium.otf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        font = None
        small_font = None
        for fp in font_paths:
            if os.path.exists(fp):
                font = ImageFont.truetype(fp, 28)
                small_font = ImageFont.truetype(fp, 22)
                break

        if font:
            # "Drag to install" text above arrow
            text = "Drag to Applications"
            bbox = font.getbbox(text)
            tw = bbox[2] - bbox[0]
            draw.text(((sw - tw) // 2, arrow_y - 60), text,
                     font=font, fill=(180, 240, 220, 200))
    except Exception:
        pass

    # Bottom subtle text
    try:
        if small_font:
            bottom_text = "Reflex — Cognitive Load Monitor"
            bbox = small_font.getbbox(bottom_text)
            tw = bbox[2] - bbox[0]
            draw.text(((sw - tw) // 2, sh - 70), bottom_text,
                     font=small_font, fill=(100, 160, 150, 100))
    except Exception:
        pass

    return img


if __name__ == "__main__":
    print("Generating DMG background...")
    bg = create_dmg_background()

    path = "/Users/kamal/Desktop/reflex/dmg_background.png"
    # Save at 1x resolution (600x400) for create-dmg
    bg_1x = bg.resize((W, H), Image.Resampling.LANCZOS)
    bg_1x.save(path, "PNG")

    # Also save @2x for retina
    bg.save("/Users/kamal/Desktop/reflex/dmg_background@2x.png", "PNG")

    print(f"  Saved {path}")
    print("Done!")
