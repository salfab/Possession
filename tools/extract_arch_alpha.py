#!/usr/bin/env python3
"""
Chroma-key extraction: ChatGPT generated the templates with a pure green
(#00FF00) fill in the arch. We compute a "greenness" score per pixel
(G - max(R, B)) — pure chroma green = 255, parchment / gold / red ornaments
= negative — and convert it to alpha. Edges get anti-aliasing for free
because the green spills slightly into the surrounding ornament during
rendering.

Usage:
    python3 tools/extract_arch_alpha.py <input.png> <output.png>
"""
import sys
from PIL import Image
import numpy as np


def process(in_path: str, out_path: str) -> None:
    img = Image.open(in_path).convert("RGBA")
    arr = np.array(img).astype(np.int16)
    R = arr[:, :, 0]
    G = arr[:, :, 1]
    B = arr[:, :, 2]

    # Greenness: how much green dominates over the brighter of R or B.
    # Pure #00FF00 → 255, gold (200,160,40) → 160-200=-40, etc.
    greenness = G - np.maximum(R, B)

    # Alpha curve:
    #   greenness >= 150 → α=0   (pure green)
    #   greenness <= 50  → α=255 (no green domination)
    #   between          → linear (anti-alias on edges)
    alpha = np.clip((150 - greenness) * 255 / 100, 0, 255).astype(np.uint8)

    # When alpha < 255 we are partially seeing the green; suppress the green
    # contamination of the visible (bleeding) pixels by reducing the green
    # channel proportionally to the transparency. Standard "spill suppression".
    transparent_factor = (255 - alpha) / 255.0   # 1.0 if fully green, 0.0 if opaque
    new_G = (G - transparent_factor * np.maximum(0, greenness)).clip(0, 255)
    arr[:, :, 1] = new_G

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
