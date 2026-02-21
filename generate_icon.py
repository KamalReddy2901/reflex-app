#!/usr/bin/env python3
"""
Generate a polished macOS-style app icon for Reflex.
Follows Apple's Human Interface Guidelines:
- Continuous superellipse (squircle) shape
- Depth with inner shadows and highlights
- Rich gradient background
- Clean, recognizable symbol
- Professional lighting and material feel
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math
import os
import json

SIZE = 1024
CENTER = SIZE // 2
ICON_DIR = "/Users/kamal/Desktop/reflex/Reflex/Assets.xcassets/AppIcon.appiconset"


def superellipse_path(cx, cy, a, b, n=5, points=400):
    """Generate a continuous superellipse (squircle) path."""
    coords = []
    for i in range(points):
        t = 2 * math.pi * i / points
        cos_t = math.cos(t)
        sin_t = math.sin(t)
        x = cx + a * abs(cos_t) ** (2/n) * (1 if cos_t >= 0 else -1)
        y = cy + b * abs(sin_t) ** (2/n) * (1 if sin_t >= 0 else -1)
        coords.append((x, y))
    return coords


def draw_filled_superellipse(draw, cx, cy, a, b, fill, n=5):
    """Draw a filled superellipse."""
    path = superellipse_path(cx, cy, a, b, n)
    draw.polygon(path, fill=fill)


def create_gradient_layer(size, colors_top, colors_bottom):
    """Create a vertical gradient image."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for y in range(size):
        ratio = y / size
        r = int(colors_top[0] + (colors_bottom[0] - colors_top[0]) * ratio)
        g = int(colors_top[1] + (colors_bottom[1] - colors_top[1]) * ratio)
        b = int(colors_top[2] + (colors_bottom[2] - colors_top[2]) * ratio)
        a = int(colors_top[3] + (colors_bottom[3] - colors_top[3]) * ratio)
        for x in range(size):
            img.putpixel((x, y), (r, g, b, a))
    return img


def create_icon():
    """Create the main icon."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # === STEP 1: Background squircle with rich gradient ===
    bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)

    # Create the squircle mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    mask_draw = ImageDraw.Draw(mask)
    sq_path = superellipse_path(CENTER, CENTER, 440, 440, n=5)
    mask_draw.polygon(sq_path, fill=255)

    # Gradient background: deep indigo to dark navy
    for y in range(SIZE):
        ratio = y / SIZE
        # Top: rich indigo (#2D1B69) → Bottom: deep navy (#0D1B2A)
        r = int(45 - ratio * 32)    # 45 → 13
        g = int(27 + ratio * 0)     # 27 → 27
        b = int(105 - ratio * 63)   # 105 → 42
        for x in range(SIZE):
            bg.putpixel((x, y), (r, g, b, 255))

    # Apply squircle mask to background
    bg.putalpha(mask)
    img = Image.alpha_composite(img, bg)

    # === STEP 2: Subtle inner edge highlight (top-left light source) ===
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)

    # Top edge highlight
    inner_sq = superellipse_path(CENTER, CENTER - 2, 436, 436, n=5)
    h_draw.polygon(inner_sq, fill=(255, 255, 255, 18))
    # Mask with slightly smaller shape to create edge-only highlight
    inner_mask = Image.new("L", (SIZE, SIZE), 255)
    im_draw = ImageDraw.Draw(inner_mask)
    smaller_sq = superellipse_path(CENTER, CENTER + 6, 430, 430, n=5)
    im_draw.polygon(smaller_sq, fill=0)
    highlight.putalpha(mask_composite(highlight.getchannel("A"), inner_mask))
    # Apply main mask
    h_alpha = highlight.getchannel("A")
    combined_mask = Image.new("L", (SIZE, SIZE), 0)
    for y in range(SIZE):
        for x in range(SIZE):
            combined_mask.putpixel((x, y), min(h_alpha.getpixel((x, y)), mask.getpixel((x, y))))
    highlight.putalpha(combined_mask)
    img = Image.alpha_composite(img, highlight)

    # === STEP 3: Ambient glow orbs for depth ===
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Top-right: warm teal glow
    for radius in range(320, 0, -2):
        alpha = int(18 * (1.0 - radius / 320.0) ** 1.5)
        cx, cy = CENTER + 160, CENTER - 200
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                          fill=(0, 210, 190, alpha))

    # Bottom-left: purple glow
    for radius in range(280, 0, -2):
        alpha = int(14 * (1.0 - radius / 280.0) ** 1.5)
        cx, cy = CENTER - 180, CENTER + 220
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                          fill=(140, 60, 240, alpha))

    # Center: subtle green glow
    for radius in range(200, 0, -2):
        alpha = int(12 * (1.0 - radius / 200.0) ** 1.5)
        glow_draw.ellipse([CENTER - radius, CENTER - radius, CENTER + radius, CENTER + radius],
                          fill=(40, 230, 160, alpha))

    glow.putalpha(mask_composite(glow.getchannel("A"), mask))
    img = Image.alpha_composite(img, glow)

    # === STEP 4: Main symbol — stylized brain/pulse ring ===
    symbol = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(symbol)

    # --- Outer monitoring ring (progress arc) ---
    ring_cx, ring_cy = CENTER, CENTER - 10
    ring_r = 280
    ring_width = 18

    # Ring background (dark track)
    for angle_deg in range(360):
        angle = math.radians(angle_deg - 90)
        for w in range(-ring_width//2, ring_width//2 + 1):
            x = int(ring_cx + (ring_r + w) * math.cos(angle))
            y = int(ring_cy + (ring_r + w) * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                s_draw.point((x, y), fill=(255, 255, 255, 8))

    # Active arc (about 75% filled) — gradient from teal to mint
    arc_extent = 270  # degrees of fill
    for angle_deg in range(arc_extent):
        angle = math.radians(angle_deg - 90)
        progress = angle_deg / arc_extent
        # Color gradient: teal → mint → green
        r = int(0 + progress * 40)
        g = int(200 + progress * 55)
        b = int(180 - progress * 40)
        alpha = int(180 + progress * 75)

        for w in range(-ring_width//2, ring_width//2 + 1):
            dist_from_center = abs(w) / (ring_width / 2)
            edge_alpha = int(alpha * (1.0 - dist_from_center * 0.4))
            x = int(ring_cx + (ring_r + w) * math.cos(angle))
            y = int(ring_cy + (ring_r + w) * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                s_draw.point((x, y), fill=(r, g, b, edge_alpha))

    # Bright cap at the end of the arc
    end_angle = math.radians(arc_extent - 90)
    cap_x = int(ring_cx + ring_r * math.cos(end_angle))
    cap_y = int(ring_cy + ring_r * math.sin(end_angle))
    for cr in range(24, 0, -1):
        alpha = int(200 * (1.0 - cr / 24.0))
        s_draw.ellipse([cap_x - cr, cap_y - cr, cap_x + cr, cap_y + cr],
                       fill=(100, 255, 210, alpha))
    s_draw.ellipse([cap_x - 9, cap_y - 9, cap_x + 9, cap_y + 9],
                   fill=(180, 255, 230, 255))

    # --- Tick marks around the ring ---
    num_ticks = 60
    for i in range(num_ticks):
        angle = math.radians(i * (360 / num_ticks) - 90)
        is_major = (i % 5 == 0)
        tick_len = 14 if is_major else 7
        tick_alpha = 60 if is_major else 30
        tick_w = 2 if is_major else 1

        inner_r = ring_r + ring_width // 2 + 4
        outer_r = inner_r + tick_len

        x1 = int(ring_cx + inner_r * math.cos(angle))
        y1 = int(ring_cy + inner_r * math.sin(angle))
        x2 = int(ring_cx + outer_r * math.cos(angle))
        y2 = int(ring_cy + outer_r * math.sin(angle))
        s_draw.line([(x1, y1), (x2, y2)], fill=(160, 255, 220, tick_alpha), width=tick_w)

    # --- Center brain symbol ---
    # Stylized brain as two hemispheres with neural connections

    brain_cx, brain_cy = CENTER, CENTER - 10
    brain_scale = 1.0

    # Brain outer shape (two overlapping hemispheres)
    # Left hemisphere
    lh_cx = brain_cx - 45
    # Right hemisphere
    rh_cx = brain_cx + 45

    # Draw a simplified brain outline using curves
    # Main brain body glow
    for radius in range(110, 0, -2):
        alpha = int(35 * (1.0 - radius / 110.0) ** 1.2)
        s_draw.ellipse([brain_cx - radius, brain_cy - radius - 10,
                        brain_cx + radius, brain_cy + radius - 10],
                       fill=(60, 230, 180, alpha))

    # Left hemisphere
    for radius in range(75, 0, -1):
        alpha = int(160 * (1.0 - radius / 75.0) ** 0.6)
        s_draw.ellipse([lh_cx - radius, brain_cy - radius + 5,
                        lh_cx + radius, brain_cy + radius + 5],
                       fill=(30, 180, 140, alpha))

    # Right hemisphere
    for radius in range(75, 0, -1):
        alpha = int(160 * (1.0 - radius / 75.0) ** 0.6)
        s_draw.ellipse([rh_cx - radius, brain_cy - radius + 5,
                        rh_cx + radius, brain_cy + radius + 5],
                       fill=(40, 200, 160, alpha))

    # Central divide line
    s_draw.line([(brain_cx, brain_cy - 70), (brain_cx, brain_cy + 70)],
                fill=(20, 60, 50, 120), width=3)

    # Brain folds (sulci) — curved lines on each hemisphere
    # Left side folds
    fold_points_l = [
        [(lh_cx - 55, brain_cy - 20), (lh_cx - 25, brain_cy - 35), (lh_cx + 10, brain_cy - 25)],
        [(lh_cx - 50, brain_cy + 10), (lh_cx - 15, brain_cy + 25), (lh_cx + 15, brain_cy + 15)],
    ]
    for fold in fold_points_l:
        for i in range(len(fold) - 1):
            s_draw.line([fold[i], fold[i+1]], fill=(20, 120, 100, 80), width=2)

    # Right side folds
    fold_points_r = [
        [(rh_cx - 10, brain_cy - 25), (rh_cx + 25, brain_cy - 35), (rh_cx + 55, brain_cy - 20)],
        [(rh_cx - 15, brain_cy + 15), (rh_cx + 15, brain_cy + 25), (rh_cx + 50, brain_cy + 10)],
    ]
    for fold in fold_points_r:
        for i in range(len(fold) - 1):
            s_draw.line([fold[i], fold[i+1]], fill=(20, 120, 100, 80), width=2)

    # Neural nodes on the brain
    node_positions = [
        (lh_cx - 30, brain_cy - 30), (lh_cx + 5, brain_cy - 10),
        (lh_cx - 20, brain_cy + 20), (lh_cx - 45, brain_cy + 5),
        (rh_cx + 30, brain_cy - 30), (rh_cx - 5, brain_cy - 10),
        (rh_cx + 20, brain_cy + 20), (rh_cx + 45, brain_cy + 5),
        (brain_cx, brain_cy - 55), (brain_cx, brain_cy + 50),
    ]

    # Connect some nodes with subtle lines
    connections = [
        (0, 1), (1, 2), (2, 3), (3, 0), (0, 8),
        (4, 5), (5, 6), (6, 7), (7, 4), (4, 8),
        (1, 5), (2, 9), (6, 9), (8, 9),
    ]
    for i, j in connections:
        x1, y1 = node_positions[i]
        x2, y2 = node_positions[j]
        s_draw.line([(x1, y1), (x2, y2)], fill=(100, 255, 210, 50), width=1)

    # Draw the nodes themselves
    for nx, ny in node_positions:
        # Glow
        for nr in range(12, 0, -1):
            alpha = int(80 * (1.0 - nr / 12.0))
            s_draw.ellipse([nx - nr, ny - nr, nx + nr, ny + nr],
                           fill=(80, 255, 200, alpha))
        # Core
        s_draw.ellipse([nx - 4, ny - 4, nx + 4, ny + 4], fill=(160, 255, 230, 240))
        s_draw.ellipse([nx - 2, ny - 2, nx + 2, ny + 2], fill=(220, 255, 245, 255))

    # Central bright core node
    for nr in range(30, 0, -1):
        alpha = int(100 * (1.0 - nr / 30.0))
        s_draw.ellipse([brain_cx - nr, brain_cy - nr, brain_cx + nr, brain_cy + nr],
                       fill=(80, 240, 190, alpha))
    s_draw.ellipse([brain_cx - 10, brain_cy - 10, brain_cx + 10, brain_cy + 10],
                   fill=(140, 255, 220, 255))
    s_draw.ellipse([brain_cx - 6, brain_cy - 6, brain_cx + 6, brain_cy + 6],
                   fill=(200, 255, 240, 255))

    # --- Score text below brain ---
    try:
        font_paths = [
            "/System/Library/Fonts/SFCompact-Bold.otf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
        ]
        score_font = None
        for fp in font_paths:
            if os.path.exists(fp):
                score_font = ImageFont.truetype(fp, 72)
                break
        if score_font:
            # Draw "72" as example score
            text = "72"
            bbox = score_font.getbbox(text)
            tw = bbox[2] - bbox[0]
            th = bbox[3] - bbox[1]
            tx = CENTER - tw // 2
            ty = CENTER + 130
            # Text glow
            for offset in range(8, 0, -1):
                alpha = int(30 * (1.0 - offset / 8.0))
                s_draw.text((tx, ty), text, font=score_font, fill=(60, 220, 170, alpha))
            s_draw.text((tx, ty), text, font=score_font, fill=(180, 255, 230, 220))

            # Small label
            label_font = ImageFont.truetype(fp, 28) if score_font else None
            if label_font:
                label = "COGNITIVE LOAD"
                lbbox = label_font.getbbox(label)
                lw = lbbox[2] - lbbox[0]
                s_draw.text((CENTER - lw // 2, ty + 75), label,
                           font=label_font, fill=(120, 200, 180, 120))
    except Exception:
        pass

    symbol.putalpha(mask_composite(symbol.getchannel("A"), mask))
    img = Image.alpha_composite(img, symbol)

    # === STEP 5: Top highlight bevel ===
    bevel = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(bevel)

    # Very subtle top-to-bottom gradient overlay for 3D feel
    for y in range(SIZE):
        ratio = y / SIZE
        if ratio < 0.15:
            # Top shine
            alpha = int(25 * (1.0 - ratio / 0.15))
            for x in range(SIZE):
                bevel.putpixel((x, y), (255, 255, 255, alpha))
        elif ratio > 0.85:
            # Bottom shadow
            shadow_ratio = (ratio - 0.85) / 0.15
            alpha = int(20 * shadow_ratio)
            for x in range(SIZE):
                bevel.putpixel((x, y), (0, 0, 0, alpha))

    bevel.putalpha(mask_composite(bevel.getchannel("A"), mask))
    img = Image.alpha_composite(img, bevel)

    # === STEP 6: Outer shadow for depth ===
    # Create shadow behind the icon
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_path = superellipse_path(CENTER, CENTER + 12, 440, 440, n=5)
    shadow_draw.polygon(shadow_path, fill=(0, 0, 0, 40))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=20))

    # Composite: shadow behind icon
    final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    final = Image.alpha_composite(final, shadow)
    final = Image.alpha_composite(final, img)

    return final


def mask_composite(alpha_channel, mask):
    """Combine alpha channel with mask."""
    result = Image.new("L", (SIZE, SIZE), 0)
    for y in range(SIZE):
        for x in range(SIZE):
            result.putpixel((x, y), min(alpha_channel.getpixel((x, y)), mask.getpixel((x, y))))
    return result


def generate_all_sizes(master_img):
    """Generate all required macOS icon sizes."""
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for filename, size in sizes.items():
        resized = master_img.resize((size, size), Image.Resampling.LANCZOS)
        filepath = os.path.join(ICON_DIR, filename)
        resized.save(filepath, "PNG")
        print(f"  {filename} ({size}x{size})")


def write_contents_json():
    """Write the Contents.json mapping."""
    contents = {
        "images": [
            {"filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"},
            {"filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"},
            {"filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"},
            {"filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"},
            {"filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"},
            {"filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"},
            {"filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"},
            {"filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"},
            {"filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"},
            {"filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"},
        ],
        "info": {"author": "xcode", "version": 1}
    }

    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("  Contents.json updated")


if __name__ == "__main__":
    print("Generating Reflex app icon (macOS HIG style)...")
    master = create_icon()

    master_path = "/Users/kamal/Desktop/reflex/icon_master_1024.png"
    master.save(master_path, "PNG")
    print(f"  Master saved ({SIZE}x{SIZE})")

    print("Generating all sizes...")
    generate_all_sizes(master)

    print("Writing Contents.json...")
    write_contents_json()

    print("Done!")
