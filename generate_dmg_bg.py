#!/usr/bin/env python3
"""Generate DMG background image with drag-to-Applications guide."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import os

# DMG window size: 600x400
W, H = 600, 400


def create_dmg_background():
    # Work at 2x for retina
    sw, sh = W * 2, H * 2
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: dark gradient matching the app theme
    for y in range(sh):
        ratio = y / sh
        r = int(14 + ratio * 8)
        g = int(10 + ratio * 12)
        b = int(38 + ratio * 22)
        for x in range(sw):
            img.putpixel((x, y), (r, g, b, 255))

    # Subtle top-to-bottom vignette
    for y in range(sh):
        ratio = y / sh
        # Darken edges slightly
        if ratio < 0.08:
            alpha = int(30 * (1.0 - ratio / 0.08))
            for x in range(sw):
                px = img.getpixel((x, y))
                img.putpixel((x, y), (max(0, px[0] - alpha), max(0, px[1] - alpha), max(0, px[2] - alpha), 255))
        if ratio > 0.92:
            edge = (ratio - 0.92) / 0.08
            alpha = int(25 * edge)
            for x in range(sw):
                px = img.getpixel((x, y))
                img.putpixel((x, y), (max(0, px[0] - alpha), max(0, px[1] - alpha), max(0, px[2] - alpha), 255))

    # --- Subtle horizontal line separating areas ---
    line_y = sh - 130
    for x in range(60, sw - 60):
        dist_from_center = abs(x - sw // 2) / (sw // 2)
        alpha = int(40 * (1.0 - dist_from_center ** 1.5))
        r, g, b = 100, 200, 175
        draw.point((x, line_y), fill=(r, g, b, alpha))

    # --- Center arrow: clean dashed arrow pointing right ---
    arrow_y = sh // 2 + 20
    arrow_x_start = sw // 2 - 160
    arrow_x_end = sw // 2 + 160

    # Dashed line — thicker, more visible
    dash_len = 24
    gap_len = 14
    x = arrow_x_start
    while x < arrow_x_end - 40:
        x2 = min(x + dash_len, arrow_x_end - 40)
        # Gradient alpha: fade in from start, fade out near end
        progress = (x - arrow_x_start) / (arrow_x_end - arrow_x_start)
        alpha = int(120 + progress * 80)
        draw.line([(x, arrow_y), (x2, arrow_y)], fill=(100, 220, 190, alpha), width=5)
        x += dash_len + gap_len

    # Arrowhead — clean filled triangle
    ah_x = arrow_x_end - 20
    draw.polygon([
        (ah_x + 28, arrow_y),
        (ah_x - 6, arrow_y - 22),
        (ah_x - 6, arrow_y + 22),
    ], fill=(120, 235, 200, 220))

    # --- Text ---
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
                font = ImageFont.truetype(fp, 30)
                small_font = ImageFont.truetype(fp, 20)
                break

        if font:
            # "Drag to Applications" above arrow
            text = "Drag to Applications"
            bbox = font.getbbox(text)
            tw = bbox[2] - bbox[0]
            draw.text(((sw - tw) // 2, arrow_y - 65), text,
                     font=font, fill=(190, 245, 225, 220))

        if small_font:
            # Subtitle at bottom
            bottom_text = "Reflex — Cognitive Load Monitor"
            bbox = small_font.getbbox(bottom_text)
            tw = bbox[2] - bbox[0]
            draw.text(((sw - tw) // 2, sh - 100), bottom_text,
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
