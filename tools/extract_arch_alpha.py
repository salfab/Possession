#!/usr/bin/env python3
"""
Convert ChatGPT-generated card templates into RGBA with the central
arch made transparent (with the noise/grain preserved as
semi-transparency).

Why this is needed: ChatGPT outputs the arch as a *painted* checker
pattern in 8-bit RGB (no alpha channel). This script detects beige
parchment-like pixels inside the arch shape and converts their
luminance into alpha, keeping the warm ornaments (gold, red, purple)
fully opaque.

Usage:
    python3 tools/extract_arch_alpha.py <input.png> <output.png>
"""

import sys
from PIL import Image
import numpy as np

# Arch shape in fractional coordinates: half-ellipse on top + rectangle
# extending downward. Tweak per-template if the arch layout shifts.
ARCH_CX, ARCH_CY = 0.50, 0.32
ARCH_RX, ARCH_RY = 0.35, 0.22
ARCH_BOTTOM = 0.74


def process(in_path: str, out_path: str) -> None:
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img).astype(np.int16)
    R, G, B = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    maxc = np.maximum(np.maximum(R, G), B)
    minc = np.minimum(np.minimum(R, G), B)
    desat = maxc - minc
    lum = (R + G + B) / 3.0

    # ornament_strength ∈ [0,1] — how "ornament-like" the pixel is.
    s_sat = np.clip((desat - 20) / 50.0, 0, 1)
    s_dark = np.clip((140 - lum) / 60.0, 0, 1)
    s_gold = np.clip((100 - B) / 40.0, 0, 1)
    ornament_strength = np.maximum(np.maximum(s_sat, s_dark), s_gold)

    # Arch mask
    yy, xx = np.indices((h, w))
    fx = xx / float(w)
    fy = yy / float(h)
    on_ellipse = ((fx - ARCH_CX) / ARCH_RX) ** 2 + ((fy - ARCH_CY) / ARCH_RY) ** 2 <= 1.0
    in_top = (fy <= ARCH_CY) & on_ellipse
    in_bot = (fy > ARCH_CY) & (fy <= ARCH_BOTTOM) & (np.abs(fx - ARCH_CX) <= ARCH_RX)
    in_arch = in_top | in_bot

    alpha = np.where(
        in_arch,
        np.clip(255 * ornament_strength, 0, 255),
        255,
    ).astype(np.uint8)
    arr[:, :, 3] = alpha
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA").save(
        out_path, optimize=True
    )


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    process(sys.argv[1], sys.argv[2])
    print(f"Wrote {sys.argv[2]}")
