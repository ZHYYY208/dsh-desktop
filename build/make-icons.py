#!/usr/bin/env python3
# Generate the DSH Desktop app icon: modern gradient + glassmorphism.
# Pure PIL (no numpy). Renders at 2x supersample, then downsamples.
#
# Outputs (relative to this file's directory):
#   icon.png                       512x512  main icon (Linux/Windows source)
#   icon.ico                       multi-size ICO for the Windows shell
#   icons/{32,48,64,128,256,512}.png  per-size icons for the Linux hicolor tree
#   ../electron/splash-icon.png    256x256  icon used by the Electron splash

import os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
S = 1024  # supersample canvas


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient_mask(size, c1, c2):
    """Linear gradient from c1 (top-left) to c2 (bottom-right) at low res."""
    small = 256
    mask = Image.new("L", (small, small))
    px = mask.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * small - 2)
            px[x, y] = int(255 * t)
    return mask.resize((size, size), Image.BILINEAR)


def radial_mask(size, cx, cy, radius, peak):
    """Soft radial light, 1 at center fading to 0."""
    small = 256
    mask = Image.new("L", (small, small))
    px = mask.load()
    s_cx, s_cy = cx / size * small, cy / size * small
    s_r = radius / size * small
    for y in range(small):
        for x in range(small):
            d = ((x - s_cx) ** 2 + (y - s_cy) ** 2) ** 0.5
            v = max(0.0, 1.0 - d / s_r)
            px[x, y] = int(255 * peak * v * v)
    return mask.resize((size, size), Image.BILINEAR)


def build_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c1 = (61, 111, 255)   # #3D6FFF deepseek blue
    c2 = (139, 91, 255)   # #8B5BFF violet

    # diagonal gradient base
    g = diagonal_gradient_mask(size, c1, c2)
    base = Image.new("RGB", (size, size), c1)
    top = Image.new("RGB", (size, size), c2)
    base = Image.composite(top, base, g)

    # glass light from top-left
    glow = radial_mask(size, 0.34 * size, 0.27 * size, 0.62 * size, 0.34)
    lit = Image.new("RGB", (size, size), (255, 255, 255))
    base = Image.composite(Image.blend(base, lit, 0.55), base, glow)

    # rounded-square alpha + subtle inner edge
    alpha = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(alpha)
    radius = round(size * 0.18)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    base.putalpha(alpha)

    d = ImageDraw.Draw(base)
    d.rounded_rectangle([2, 2, size - 3, size - 3], radius=radius,
                        outline=(255, 255, 255, 42), width=max(2, size // 512))

    # ---- glass panel (frosted) ----
    p0, p1 = round(size * 0.19), round(size * 0.81)
    prad = round((p1 - p0) * 0.30)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    ds.rounded_rectangle([p0, p0 + round(size * 0.02), p1, p1 + round(size * 0.02)],
                         radius=prad, fill=(8, 16, 60, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.03))
    base = Image.alpha_composite(base, shadow)

    panel = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dp = ImageDraw.Draw(panel)
    dp.rounded_rectangle([p0, p0, p1, p1], radius=prad,
                         fill=(255, 255, 255, 34))
    dp.rounded_rectangle([p0, p0, p1, p1], radius=prad,
                         outline=(255, 255, 255, 108), width=max(3, size // 256))
    # specular sheen across the top of the glass
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dsh = ImageDraw.Draw(sheen)
    dsh.ellipse([p0 - size * 0.02, p0 - size * 0.10, p1 + size * 0.02,
                 p0 + (p1 - p0) * 0.34], fill=(255, 255, 255, 26))
    sheen = sheen.filter(ImageFilter.GaussianBlur(size * 0.02))
    panel = Image.alpha_composite(panel, sheen)
    base = Image.alpha_composite(base, panel)

    # ---- neural-node glyph ----
    gd = ImageDraw.Draw(base)
    cx = cy = size * 0.5
    ring = size * 0.185
    center_r = size * 0.075
    sat_r = size * 0.037
    spoke_w = max(10, size // 64)
    import math
    angles = [-90, -18, 54, 126, 198]
    sat_pos = [(cx + ring * math.cos(math.radians(a)),
                cy + ring * math.sin(math.radians(a))) for a in angles]
    for sx, sy in sat_pos:
        gd.line([(cx, cy), (sx, sy)], fill=(255, 255, 255, 190), width=spoke_w)
    for sx, sy in sat_pos:
        gd.ellipse([sx - sat_r, sy - sat_r, sx + sat_r, sy + sat_r],
                   fill=(255, 255, 255, 245))
    gd.ellipse([cx - center_r, cy - center_r, cx + center_r, cy + center_r],
               fill=(255, 255, 255, 250))
    gd.ellipse([cx - center_r * 0.55, cy - center_r * 0.55,
                cx + center_r * 0.55, cy + center_r * 0.55],
               fill=(200, 214, 255, 255))

    return base


def main():
    master = build_icon(S)

    def save(size, path):
        master.resize((size, size), Image.LANCZOS).save(path, optimize=True)

    icons_dir = os.path.join(HERE, "icons")
    os.makedirs(icons_dir, exist_ok=True)
    save(512, os.path.join(HERE, "icon.png"))
    save(256, os.path.join(icons_dir, "256.png"))
    save(128, os.path.join(icons_dir, "128.png"))
    save(64, os.path.join(icons_dir, "64.png"))
    save(48, os.path.join(icons_dir, "48.png"))
    save(32, os.path.join(icons_dir, "32.png"))
    save(512, os.path.join(icons_dir, "512.png"))

    master.resize((256, 256), Image.LANCZOS).save(
        os.path.join(HERE, "..", "electron", "splash-icon.png"), optimize=True)

    master.resize((512, 512), Image.LANCZOS).save(
        os.path.join(HERE, "icon.ico"),
        sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])

    print("icons written")


if __name__ == "__main__":
    main()
