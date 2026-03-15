#!/usr/bin/env python3
"""Generate TasteTheLens app icons (1024x1024) for light, dark, and tinted variants."""

from PIL import Image, ImageDraw, ImageFont
import math
import os

SIZE = 1024
CENTER = SIZE // 2
OUTPUT_DIR = "Taste The Lens/Taste The Lens/Assets.xcassets/AppIcon.appiconset"

# Color palette from CLAUDE.md
BG_DARK = "#0D0D0F"
GOLD = "#C9A84C"
GOLD_DIM = "#8A7235"
CYAN = "#64D2FF"
CORAL = "#FF6B6B"
WHITE = "#FFFFFF"


def draw_lens_ring(draw, cx, cy, outer_r, inner_r, color, width=None):
    """Draw a camera lens ring (circle outline)."""
    if width is None:
        width = outer_r - inner_r
    r = (outer_r + inner_r) // 2
    draw.ellipse(
        [cx - r, cy - r, cx + r, cy + r],
        outline=color,
        width=width,
    )


def draw_aperture_blades(draw, cx, cy, radius, color, num_blades=6, blade_width=3):
    """Draw aperture blade lines inside the lens."""
    for i in range(num_blades):
        angle = (2 * math.pi * i / num_blades) - math.pi / 2
        inner_r = radius * 0.35
        outer_r = radius * 0.75
        x1 = cx + inner_r * math.cos(angle)
        y1 = cy + inner_r * math.sin(angle)

        # Each blade connects to the next position rotated slightly
        next_angle = angle + math.pi / num_blades
        x2 = cx + outer_r * math.cos(next_angle)
        y2 = cy + outer_r * math.sin(next_angle)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=blade_width)


def draw_fork(draw, cx, cy, height, color, prong_width=8, handle_width=10):
    """Draw a simplified fork icon."""
    top = cy - height // 2
    bottom = cy + height // 2
    mid = top + height * 0.45  # where prongs end and handle begins

    # Handle
    draw.rounded_rectangle(
        [cx - handle_width // 2, mid, cx + handle_width // 2, bottom],
        radius=handle_width // 2,
        fill=color,
    )

    # Prongs (3)
    spacing = prong_width * 2.2
    for i in range(3):
        px = cx + (i - 1) * spacing
        draw.rounded_rectangle(
            [px - prong_width // 2, top, px + prong_width // 2, mid + prong_width],
            radius=prong_width // 2,
            fill=color,
        )


def draw_knife(draw, cx, cy, height, color, blade_width=16):
    """Draw a simplified knife icon."""
    top = cy - height // 2
    bottom = cy + height // 2
    mid = top + height * 0.45

    # Handle
    handle_w = blade_width * 0.7
    draw.rounded_rectangle(
        [cx - handle_w // 2, mid, cx + handle_w // 2, bottom],
        radius=handle_w // 2,
        fill=color,
    )

    # Blade — tapered rectangle with rounded top
    draw.rounded_rectangle(
        [cx - blade_width // 2, top, cx + blade_width // 2, mid + blade_width // 2],
        radius=blade_width // 2,
        fill=color,
    )
    # Flat edge on one side
    draw.rectangle(
        [cx - blade_width // 2, top + blade_width // 2, cx, mid + blade_width // 2],
        fill=color,
    )


def generate_icon(variant="light"):
    """Generate a single icon variant."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background
    if variant == "light":
        bg_color = "#1A1A1E"
    elif variant == "dark":
        bg_color = BG_DARK
    else:  # tinted — monochrome, will be tinted by iOS
        bg_color = "#000000"

    # Rounded rect background (iOS clips to rounded rect automatically, but fill the square)
    draw.rectangle([0, 0, SIZE, SIZE], fill=bg_color)

    # Determine colors based on variant
    if variant == "tinted":
        ring_color = "#FFFFFF"
        accent_color = "#FFFFFF"
        blade_color = "#CCCCCC"
        text_color = "#FFFFFF"
        utensil_color = "#DDDDDD"
    else:
        ring_color = GOLD
        accent_color = CYAN
        blade_color = GOLD_DIM
        text_color = GOLD
        utensil_color = CORAL

    # --- Camera lens (outer ring) ---
    lens_radius = 310
    draw_lens_ring(draw, CENTER, CENTER - 30, lens_radius, lens_radius - 28, ring_color, width=28)

    # Inner ring
    inner_radius = 240
    draw_lens_ring(draw, CENTER, CENTER - 30, inner_radius, inner_radius - 8, blade_color, width=8)

    # Aperture blades
    draw_aperture_blades(draw, CENTER, CENTER - 30, inner_radius - 10, blade_color, num_blades=6, blade_width=6)

    # Center circle (lens glass)
    glass_r = 80
    glass_color = accent_color if variant != "tinted" else "#AAAAAA"
    draw.ellipse(
        [CENTER - glass_r, CENTER - 30 - glass_r, CENTER + glass_r, CENTER - 30 + glass_r],
        outline=glass_color,
        width=6,
    )

    # --- Fork & Knife crossed in the center ---
    utensil_h = 130
    # Fork (left of center)
    fork_cx = CENTER - 28
    draw_fork(draw, fork_cx, CENTER - 30, utensil_h, utensil_color, prong_width=7, handle_width=9)

    # Knife (right of center)
    knife_cx = CENTER + 28
    draw_knife(draw, knife_cx, CENTER - 30, utensil_h, utensil_color, blade_width=14)

    # --- Text: "TASTE THE LENS" curved at bottom ---
    text = "TASTE THE LENS"
    # Place text in an arc along the bottom of the lens ring
    text_radius = lens_radius + 50
    total_angle = math.pi * 0.55  # spread across ~100 degrees
    # Start from the left side and go right (decreasing angle in screen coords)
    start_angle = math.pi / 2 + total_angle / 2  # start left

    # Try to load a font
    font_size = 52
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
    except (OSError, IOError):
        try:
            font = ImageFont.truetype("/System/Library/Fonts/SFNSMono.ttf", font_size)
        except (OSError, IOError):
            font = ImageFont.load_default()

    for i, char in enumerate(text):
        if len(text) > 1:
            angle = start_angle - (total_angle * i / (len(text) - 1))
        else:
            angle = start_angle
        x = CENTER + text_radius * math.cos(angle)
        y = (CENTER - 30) + text_radius * math.sin(angle)

        # Create a temporary image for the rotated character
        char_img = Image.new("RGBA", (font_size * 2, font_size * 2), (0, 0, 0, 0))
        char_draw = ImageDraw.Draw(char_img)
        bbox = char_draw.textbbox((0, 0), char, font=font)
        cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
        char_draw.text(
            (font_size - cw // 2, font_size - ch // 2),
            char,
            fill=text_color,
            font=font,
        )

        # Rotate: angle is from center, text should face outward
        rotation = -math.degrees(angle) + 90
        char_img = char_img.rotate(rotation, resample=Image.BICUBIC, expand=False)

        # Paste
        paste_x = int(x - font_size)
        paste_y = int(y - font_size)
        img.paste(char_img, (paste_x, paste_y), char_img)

    # Small decorative dots on the ring
    for angle_deg in [135, 45]:
        angle = math.radians(angle_deg)
        dot_r = 8
        dx = CENTER + (lens_radius - 14) * math.cos(angle)
        dy = (CENTER - 30) - (lens_radius - 14) * math.sin(angle)
        draw.ellipse(
            [dx - dot_r, dy - dot_r, dx + dot_r, dy + dot_r],
            fill=accent_color if variant != "tinted" else "#BBBBBB",
        )

    return img


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Generate all three variants
    variants = {
        "light": "AppIcon.png",
        "dark": "AppIcon-dark.png",
        "tinted": "AppIcon-tinted.png",
    }

    for variant, filename in variants.items():
        icon = generate_icon(variant)
        path = os.path.join(OUTPUT_DIR, filename)
        icon.save(path, "PNG")
        print(f"Generated {path} ({variant})")

    # Update Contents.json to reference the images
    import json

    contents = {
        "images": [
            {
                "filename": "AppIcon.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "dark"}
                ],
                "filename": "AppIcon-dark.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "tinted"}
                ],
                "filename": "AppIcon-tinted.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }

    contents_path = os.path.join(OUTPUT_DIR, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)
    print(f"Updated {contents_path}")


if __name__ == "__main__":
    main()
