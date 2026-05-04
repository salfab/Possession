#!/usr/bin/env python3
"""Cartouche calibration for the right-column Liturgy banners.

Background : the banner artwork is split between an illustration on the
left and a parchment cartouche on the right. The cartouche is where the
ultra-minimal status text is overlaid (e.g. "Brise Domination"). The
GDScript label anchors were initially set by eye and bleed slightly off
the parchment on most banners.

This script auto-detects the parchment area on every shipped banner,
prints the per-banner bbox plus the aggregate mean, and dumps a ready-
to-paste anchor block. Re-run whenever the artwork changes.

Usage:
    python3 tools/banner_calibrate.py

Dependencies: PIL, numpy, scipy (already in the dev environment).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as nd


# Parchment colour signature on the master art : warm beige, low
# saturation. Empirically RGB(210, 190, 155) ± 60 captures the cartouche
# on every shipped banner without grabbing the dark illustration.
PARCHMENT_TARGET = np.array([210, 190, 155])
PARCHMENT_TOLERANCE = 60

# Restrict detection to the right 70 % of the image — the illustration on
# the left can occasionally have warm pixels that would otherwise pollute
# the bbox. The cartouche always lives on the right half.
LEFT_CROP = 0.30


def detect_cartouche_bbox(path: Path) -> tuple[float, float, float, float] | None:
    """Returns the parchment bbox in normalised coords (L, T, R, B), or
    None if no parchment-coloured blob is found."""
    im = np.asarray(Image.open(path).convert("RGB"))
    h, w, _ = im.shape
    diff = np.abs(im.astype(int) - PARCHMENT_TARGET).max(axis=2)
    mask = diff < PARCHMENT_TOLERANCE
    mask[:, : int(w * LEFT_CROP)] = False
    if not mask.any():
        return None
    # Keep the largest connected component — defends against the
    # threshold catching small warm spots in the illustration.
    labeled, n = nd.label(mask)
    if n == 0:
        return None
    sizes = nd.sum(mask, labeled, range(1, n + 1))
    biggest_label = int(sizes.argmax()) + 1
    big = labeled == biggest_label
    rows = np.any(big, axis=1)
    cols = np.any(big, axis=0)
    rmin, rmax = np.where(rows)[0][[0, -1]]
    cmin, cmax = np.where(cols)[0][[0, -1]]
    return (cmin / w, rmin / h, cmax / w, rmax / h)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--dir",
        default="assets/cards/liturgy_banners",
        help="Directory holding the .webp banners (default: %(default)s)",
    )
    p.add_argument(
        "--exclude",
        default="exorcisme.webp",
        help="Comma-separated filenames to skip (Exorcism layout differs).",
    )
    args = p.parse_args()

    banner_dir = Path(args.dir)
    if not banner_dir.is_dir():
        print(f"banner directory missing: {banner_dir}", file=sys.stderr)
        return 1
    excluded = {x.strip() for x in args.exclude.split(",") if x.strip()}

    bboxes: list[tuple[float, float, float, float]] = []
    print(f"== Per-banner cartouche bbox (normalised) ==")
    for f in sorted(banner_dir.iterdir()):
        if f.suffix != ".webp" or f.name in excluded:
            continue
        bb = detect_cartouche_bbox(f)
        if bb is None:
            print(f"  {f.name:48s}  (no parchment found)")
            continue
        bboxes.append(bb)
        print(f"  {f.name:48s}  L={bb[0]:.3f} T={bb[1]:.3f} R={bb[2]:.3f} B={bb[3]:.3f}")

    if not bboxes:
        print("no banners detected, nothing to recommend.")
        return 1

    arr = np.array(bboxes)
    mean = arr.mean(axis=0)
    print()
    print(f"== Aggregate ({len(bboxes)} banners) ==")
    print(f"  mean : L={mean[0]:.3f} T={mean[1]:.3f} R={mean[2]:.3f} B={mean[3]:.3f}")

    # Conservative recommendation : nudge each edge inward by ~1 % from
    # the mean so the label tucks comfortably inside the cartouche even
    # on the looser banners.
    rec_l = round(mean[0] + 0.01, 2)
    rec_t = round(mean[1] + 0.01, 2)
    rec_r = round(mean[2] - 0.01, 2)
    rec_b = round(mean[3] - 0.0, 2)
    print()
    print(f"== Recommended anchors for _build_liturgy_banners (Main.gd) ==")
    print(f"  lbl.anchor_left   = {rec_l}")
    print(f"  lbl.anchor_top    = {rec_t}")
    print(f"  lbl.anchor_right  = {rec_r}")
    print(f"  lbl.anchor_bottom = {rec_b}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
