#!/usr/bin/env python3
"""EdgeLauncher AppIcon (모든 사이즈) 생성. kms-jyp 컨셉.
실행: python3 scripts/make-icon.py
출력: EdgeLauncher/Assets.xcassets/AppIcon.appiconset/icon_*.png"""

from PIL import Image, ImageDraw, ImageFont
import os
import sys

OUT_DIR = sys.argv[1] if len(sys.argv) > 1 else "EdgeLauncher/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024


def load_font(size):
    candidates = [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def render(size):
    s = size
    scale = s / 1024
    img = Image.new("RGBA", (s, s), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    bar_w = int(s * 0.50)
    bar_h = int(bar_w * 9 / 32)
    bar_x = (s - bar_w) // 2
    bar_y = int(s * 0.17)
    draw.rounded_rectangle(
        [bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
        radius=max(int(bar_h / 3), 2),
        fill=(64, 117, 217, 255),
    )

    dot_r = max(int(bar_h / 5), 1)
    cy = bar_y + bar_h // 2
    draw.ellipse([bar_x - dot_r * 3, cy - dot_r, bar_x - dot_r, cy + dot_r], fill=(64, 117, 217, 255))
    draw.ellipse([bar_x + bar_w + dot_r, cy - dot_r, bar_x + bar_w + dot_r * 3, cy + dot_r], fill=(64, 117, 217, 255))

    title_font = load_font(max(int(260 * scale), 6))
    title = "EDGE"
    bbox = draw.textbbox((0, 0), title, font=title_font)
    tw = bbox[2] - bbox[0]
    tx = (s - tw) // 2 - bbox[0]
    ty = int(s * 0.40) - bbox[1]
    draw.text((tx, ty), title, fill=(28, 28, 35, 255), font=title_font)

    line_w = int(s * 0.18)
    line_y = int(s * 0.78)
    line_x = (s - line_w) // 2
    line_h = max(int(5 * scale), 1)
    draw.rectangle([line_x, line_y, line_x + line_w, line_y + line_h], fill=(190, 190, 200, 255))

    sub_font = load_font(max(int(70 * scale), 4))
    sub = "JYP"
    bbox = draw.textbbox((0, 0), sub, font=sub_font)
    sw = bbox[2] - bbox[0]
    sx = (s - sw) // 2 - bbox[0]
    sy = int(s * 0.82) - bbox[1]
    draw.text((sx, sy), sub, fill=(150, 150, 160, 255), font=sub_font)

    return img


SIZES = {
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

os.makedirs(OUT_DIR, exist_ok=True)

base = render(SIZE)
for name, sz in SIZES.items():
    if sz == SIZE:
        img = base
    else:
        img = base.resize((sz, sz), Image.LANCZOS)
    img.save(os.path.join(OUT_DIR, name))
    print(f"  {name} ({sz}x{sz})")

print(f"saved to {OUT_DIR}")
