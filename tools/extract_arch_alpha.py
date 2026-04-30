#!/usr/bin/env python3
"""
Convert ChatGPT-generated card templates into RGBA via color keying:
1. Detect the arch parchment region as a connected component.
2. Sample the median (key) color of that region.
3. For each pixel inside the region, alpha is proportional to the
   euclidean color distance from the key — pixels matching the key
   are transparent, ornaments (saturated/dark/colored) stay opaque,
   and intermediate pixels get a graduated semi-transparency.
4. A 1.5 px gaussian blur on the alpha mask softens the edge.

Usage:
    python3 tools/extract_arch_alpha.py <input.png> <output.png>
"""
import sys
from PIL import Image
import numpy as np
from scipy.ndimage import label, binary_closing, gaussian_filter

SEARCH_Y = (0.13, 0.74)
SEARCH_X = (0.13, 0.87)
CLOSING_ITER = 6
DIST_TRANSPARENT = 25
DIST_OPAQUE = 80
EDGE_BLUR_SIGMA = 1.5


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

    if arch_zone.any():
        key_R = float(np.median(R[arch_zone]))
        key_G = float(np.median(G[arch_zone]))
        key_B = float(np.median(B[arch_zone]))
    else:
        key_R, key_G, key_B = 220, 200, 175

    dist = np.sqrt((R - key_R) ** 2 + (G - key_G) ** 2 + (B - key_B) ** 2)
    alpha_from_dist = np.clip(
        (dist - DIST_TRANSPARENT) / (DIST_OPAQUE - DIST_TRANSPARENT) * 255,
        0, 255,
    )
    alpha = np.where(arch_zone, alpha_from_dist, 255).astype(np.float32)
    alpha = gaussian_filter(alpha, sigma=EDGE_BLUR_SIGMA)
    alpha = np.clip(alpha, 0, 255).astype(np.uint8)
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
