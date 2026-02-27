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
    for radius in range(350, 0, -2):
        alpha = int(22 * (1.0 - radius / 350.0) ** 1.5)
        cx, cy = CENTER + 140, CENTER - 180
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                          fill=(0, 220, 200, alpha))

    # Bottom-left: purple glow
    for radius in range(300, 0, -2):
        alpha = int(18 * (1.0 - radius / 300.0) ** 1.5)
        cx, cy = CENTER - 160, CENTER + 200
        glow_draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                          fill=(140, 60, 240, alpha))

    # Center: strong green/teal glow for the brain area
    for radius in range(280, 0, -2):
        alpha = int(20 * (1.0 - radius / 280.0) ** 1.5)
        glow_draw.ellipse([CENTER - radius, CENTER - radius - 20, CENTER + radius, CENTER + radius - 20],
                          fill=(30, 230, 170, alpha))

    glow.putalpha(mask_composite(glow.getchannel("A"), mask))
    img = Image.alpha_composite(img, glow)

    # === STEP 4: Main symbol — Bold brain with bright neural network ===
    symbol = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(symbol)

    # --- Outer monitoring ring (progress arc) ---
    ring_cx, ring_cy = CENTER, CENTER - 10
    ring_r = 340  # Bigger ring
    ring_width = 20

    # Ring background (dark track)
    for angle_deg in range(360):
        angle = math.radians(angle_deg - 90)
        for w in range(-ring_width//2, ring_width//2 + 1):
            x = int(ring_cx + (ring_r + w) * math.cos(angle))
            y = int(ring_cy + (ring_r + w) * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                s_draw.point((x, y), fill=(255, 255, 255, 10))

    # Active arc (about 75% filled) — gradient from teal to mint — BRIGHTER
    arc_extent = 270  # degrees of fill
    for angle_deg in range(arc_extent):
        angle = math.radians(angle_deg - 90)
        progress = angle_deg / arc_extent
        # Brighter color gradient: teal → mint → green
        r = int(0 + progress * 60)
        g = int(210 + progress * 45)
        b = int(190 - progress * 50)
        alpha = int(200 + progress * 55)

        for w in range(-ring_width//2, ring_width//2 + 1):
            dist_from_center = abs(w) / (ring_width / 2)
            edge_alpha = int(alpha * (1.0 - dist_from_center * 0.3))
            x = int(ring_cx + (ring_r + w) * math.cos(angle))
            y = int(ring_cy + (ring_r + w) * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                s_draw.point((x, y), fill=(r, g, b, edge_alpha))

    # Bright cap at the end of the arc
    end_angle = math.radians(arc_extent - 90)
    cap_x = int(ring_cx + ring_r * math.cos(end_angle))
    cap_y = int(ring_cy + ring_r * math.sin(end_angle))
    for cr in range(30, 0, -1):
        alpha = int(220 * (1.0 - cr / 30.0))
        s_draw.ellipse([cap_x - cr, cap_y - cr, cap_x + cr, cap_y + cr],
                       fill=(120, 255, 220, alpha))
    s_draw.ellipse([cap_x - 10, cap_y - 10, cap_x + 10, cap_y + 10],
                   fill=(200, 255, 240, 255))

    # --- Tick marks around the ring ---
    num_ticks = 60
    for i in range(num_ticks):
        angle = math.radians(i * (360 / num_ticks) - 90)
        is_major = (i % 5 == 0)
        tick_len = 16 if is_major else 8
        tick_alpha = 70 if is_major else 35
        tick_w = 2 if is_major else 1

        inner_r = ring_r + ring_width // 2 + 5
        outer_r = inner_r + tick_len

        x1 = int(ring_cx + inner_r * math.cos(angle))
        y1 = int(ring_cy + inner_r * math.sin(angle))
        x2 = int(ring_cx + outer_r * math.cos(angle))
        y2 = int(ring_cy + outer_r * math.sin(angle))
        s_draw.line([(x1, y1), (x2, y2)], fill=(160, 255, 220, tick_alpha), width=tick_w)

    # --- Center brain symbol — BIGGER, BRIGHTER, BOLDER ---
    brain_cx, brain_cy = CENTER, CENTER - 10

    # Left hemisphere center
    lh_cx = brain_cx - 60
    # Right hemisphere center
    rh_cx = brain_cx + 60

    # Brain outer glow — larger, brighter
    for radius in range(160, 0, -2):
        alpha = int(50 * (1.0 - radius / 160.0) ** 1.2)
        s_draw.ellipse([brain_cx - radius, brain_cy - radius - 10,
                        brain_cx + radius, brain_cy + radius - 10],
                       fill=(60, 240, 190, alpha))

    # Left hemisphere — larger
    for radius in range(105, 0, -1):
        alpha = int(200 * (1.0 - radius / 105.0) ** 0.5)
        s_draw.ellipse([lh_cx - radius, brain_cy - radius + 5,
                        lh_cx + radius, brain_cy + radius + 5],
                       fill=(30, 190, 150, alpha))

    # Right hemisphere — larger
    for radius in range(105, 0, -1):
        alpha = int(200 * (1.0 - radius / 105.0) ** 0.5)
        s_draw.ellipse([rh_cx - radius, brain_cy - radius + 5,
                        rh_cx + radius, brain_cy + radius + 5],
                       fill=(40, 210, 170, alpha))

    # Central divide line — bolder
    s_draw.line([(brain_cx, brain_cy - 100), (brain_cx, brain_cy + 100)],
                fill=(15, 50, 42, 140), width=4)

    # Brain folds (sulci) — larger, bolder curves
    fold_points_l = [
        [(lh_cx - 80, brain_cy - 30), (lh_cx - 35, brain_cy - 50), (lh_cx + 15, brain_cy - 35)],
        [(lh_cx - 70, brain_cy + 15), (lh_cx - 20, brain_cy + 35), (lh_cx + 20, brain_cy + 20)],
        [(lh_cx - 60, brain_cy - 5), (lh_cx - 30, brain_cy + 5), (lh_cx + 5, brain_cy - 5)],
    ]
    for fold in fold_points_l:
        for i in range(len(fold) - 1):
            s_draw.line([fold[i], fold[i+1]], fill=(15, 100, 85, 100), width=3)

    fold_points_r = [
        [(rh_cx - 15, brain_cy - 35), (rh_cx + 35, brain_cy - 50), (rh_cx + 80, brain_cy - 30)],
        [(rh_cx - 20, brain_cy + 20), (rh_cx + 20, brain_cy + 35), (rh_cx + 70, brain_cy + 15)],
        [(rh_cx - 5, brain_cy - 5), (rh_cx + 30, brain_cy + 5), (rh_cx + 60, brain_cy - 5)],
    ]
    for fold in fold_points_r:
        for i in range(len(fold) - 1):
            s_draw.line([fold[i], fold[i+1]], fill=(15, 100, 85, 100), width=3)

    # Neural nodes — BIGGER, BRIGHTER, more prominent
    node_positions = [
        (lh_cx - 42, brain_cy - 45), (lh_cx + 8, brain_cy - 15),
        (lh_cx - 30, brain_cy + 30), (lh_cx - 65, brain_cy + 8),
        (rh_cx + 42, brain_cy - 45), (rh_cx - 8, brain_cy - 15),
        (rh_cx + 30, brain_cy + 30), (rh_cx + 65, brain_cy + 8),
        (brain_cx, brain_cy - 80), (brain_cx, brain_cy + 70),
        (lh_cx - 50, brain_cy - 20), (rh_cx + 50, brain_cy - 20),
    ]

    # Connect nodes with brighter lines
    connections = [
        (0, 1), (1, 2), (2, 3), (3, 0), (0, 8), (3, 10),
        (4, 5), (5, 6), (6, 7), (7, 4), (4, 8), (7, 11),
        (1, 5), (2, 9), (6, 9), (8, 9), (10, 0), (11, 4),
    ]
    for i, j in connections:
        x1, y1 = node_positions[i]
        x2, y2 = node_positions[j]
        s_draw.line([(x1, y1), (x2, y2)], fill=(100, 255, 215, 80), width=2)

    # Draw nodes — bigger glow, brighter cores
    for nx, ny in node_positions:
        # Outer glow
        for nr in range(18, 0, -1):
            alpha = int(110 * (1.0 - nr / 18.0))
            s_draw.ellipse([nx - nr, ny - nr, nx + nr, ny + nr],
                           fill=(80, 255, 210, alpha))
        # Core
        s_draw.ellipse([nx - 6, ny - 6, nx + 6, ny + 6], fill=(170, 255, 235, 250))
        s_draw.ellipse([nx - 3, ny - 3, nx + 3, ny + 3], fill=(230, 255, 250, 255))

    # Central bright core node — larger, glowing
    for nr in range(45, 0, -1):
        alpha = int(130 * (1.0 - nr / 45.0))
        s_draw.ellipse([brain_cx - nr, brain_cy - nr, brain_cx + nr, brain_cy + nr],
                       fill=(70, 245, 195, alpha))
    s_draw.ellipse([brain_cx - 14, brain_cy - 14, brain_cx + 14, brain_cy + 14],
                   fill=(150, 255, 225, 255))
    s_draw.ellipse([brain_cx - 8, brain_cy - 8, brain_cx + 8, brain_cy + 8],
                   fill=(210, 255, 245, 255))

    # NO TEXT — icon only

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
