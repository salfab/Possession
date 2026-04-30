#!/usr/bin/env python3
"""
Convert ChatGPT-generated card templates into RGBA. Uses connected-component
detection of the parchment region around the image center, then keeps
true ornaments (skull, doves, candles, crosses) opaque inside that region.

Output is binary alpha (0 or 255) so edges are crisp and the parchment
inside the arch is fully transparent regardless of palette.

Usage:
    python3 tools/extract_arch_alpha.py <input.png> <output.png>
"""
import sys
from PIL import Image
import numpy as np
from scipy.ndimage import label, binary_closing

SEARCH_Y = (0.13, 0.74)
SEARCH_X = (0.13, 0.87)
CLOSING_ITER = 6


def process(in_path: str, out_path: str) -> None:
    img = Image.open(in_path).convert("RGBA")
    w, h = img.size
    arr = np.array(img).astype(np.int16)
    R, G, B = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    maxc = np.maximum(np.maximum(R, G), B)
    minc = np.minimum(np.minimum(R, G), B)
    desat = maxc - minc
    lum = (R + G + B) / 3.0

    parchment = (
        (R > 165) & (G > 145) & (B > 110)
        & (R - B > 15) & (R - B < 110)
        & (lum > 160) & (lum < 248)
        & (desat < 90)
    )
    box = np.zeros_like(parchment, dtype=bool)
    y0, y1 = int(h * SEARCH_Y[0]), int(h * SEARCH_Y[1])
    x0, x1 = int(w * SEARCH_X[0]), int(w * SEARCH_X[1])
    box[y0:y1, x0:x1] = parchment[y0:y1, x0:x1]

    labeled, _ = label(box)
    cy, cx = h // 2, w // 2
    seed = labeled[cy, cx]
    if seed == 0:
        for dy in range(0, h, 20):
            for dx in range(-w // 4, w // 4, 20):
                yy = cy + dy
                xx = cx + dx
                if 0 <= yy < h and 0 <= xx < w and labeled[yy, xx] != 0:
                    seed = labeled[yy, xx]
                    break
            if seed:
                break
    arch_zone = labeled == seed if seed else np.zeros_like(labeled, dtype=bool)
    arch_zone = ~binary_closing(~arch_zone, iterations=CLOSING_ITER)

    s_sat = np.clip((desat - 30) / 30.0, 0, 1)
    s_dark = np.clip((130 - lum) / 60.0, 0, 1)
    s_gold = np.clip((90 - B) / 40.0, 0, 1)
    ornament_strength = np.maximum(np.maximum(s_sat, s_dark), s_gold)
    is_inner_ornament = ornament_strength > 0.45

    transparent_zone = arch_zone & ~is_inner_ornament
    alpha = np.where(transparent_zone, 0, 255).astype(np.uint8)
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
