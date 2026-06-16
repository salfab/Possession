from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ILLUSTRATIONS_DIR = ROOT / "assets" / "cards" / "illustrations"
BANNERS_DIR = ROOT / "assets" / "cards" / "liturgy_banners"
TEMPLATES_DIR = BANNERS_DIR / "templates"
INSERTS_DIR = BANNERS_DIR / "inserts"
SOURCES_DIR = BANNERS_DIR / "sources"

BANNER_W = 600
BANNER_H = 225
INSERT_BOX = (10, 12, 234, 213)
CARTOUCHE_BOX = (240, 19, 584, 204)
KEY_COLOR = (0, 255, 0, 255)

RESPONSES = [
    "signe_de_croix",
    "examen_de_conscience",
    "contrition",
    "confession",
    "communion",
]
ROMAN_BY_RESPONSE = {
    "signe_de_croix": "I",
    "examen_de_conscience": "II",
    "contrition": "III",
    "confession": "IV",
    "communion": "V",
}


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = ROOT / "assets" / "fonts" / "CinzelDecorative-Bold.ttf"
    try:
        return ImageFont.truetype(str(path), size)
    except OSError:
        return ImageFont.load_default()


def _cover_crop(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    src_w, src_h = src.size
    src_ratio = src_w / src_h
    target_ratio = target_w / target_h
    if src_ratio > target_ratio:
        crop_w = int(src_h * target_ratio)
        x0 = (src_w - crop_w) // 2
        box = (x0, 0, x0 + crop_w, src_h)
    else:
        crop_h = int(src_w / target_ratio)
        y0 = max(0, (src_h - crop_h) // 2)
        box = (0, y0, src_w, y0 + crop_h)
    return src.crop(box).resize(size, Image.Resampling.LANCZOS)


def _add_noise(img: Image.Image, alpha: int, seed: int) -> Image.Image:
    rng = random.Random(seed)
    noise = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px = noise.load()
    for y in range(img.height):
        for x in range(img.width):
            v = rng.randint(-18, 18)
            if v >= 0:
                px[x, y] = (255, 245, 215, min(alpha, v * 2))
            else:
                px[x, y] = (55, 34, 18, min(alpha, -v * 2))
    return Image.alpha_composite(img, noise.filter(ImageFilter.GaussianBlur(0.55)))


def _draw_parchment(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], mode: str) -> None:
    x0, y0, x1, y1 = box
    base_top = (244, 230, 188, 255) if mode == "in_integro" else (229, 210, 178, 255)
    base_bot = (215, 178, 116, 255) if mode == "in_integro" else (189, 154, 124, 255)
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0)
        col = tuple(int(base_top[i] * (1 - t) + base_bot[i] * t) for i in range(4))
        draw.line((x0, y, x1, y), fill=col)


def _rounded_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill, outline, width: int) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def _draw_crack(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill, width: int = 2) -> None:
    for a, b in zip(points, points[1:]):
        draw.line((a[0], a[1], b[0], b[1]), fill=fill, width=width)


def _draw_impedita_insert_veil(img: Image.Image, seed: int) -> None:
    rng = random.Random(seed)
    overlay = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay, "RGBA")
    x0, y0, x1, y1 = INSERT_BOX

    # A ritual darkening, not a cancellation mark: smoke gathers near the
    # frame and a few hairline fractures cross the keyed window.
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0)
        alpha = int(34 + 34 * abs(t - 0.5) * 2)
        od.line((x0, y, x1, y), fill=(34, 12, 15, alpha))
    for _ in range(34):
        cx = rng.randint(x0 - 28, x1 + 20)
        cy = rng.randint(y0 - 20, y1 + 18)
        rx = rng.randint(28, 78)
        ry = rng.randint(12, 38)
        od.ellipse((cx - rx, cy - ry, cx + rx, cy + ry),
                   fill=(58, 22, 20, rng.randint(12, 32)))
    overlay = overlay.filter(ImageFilter.GaussianBlur(5.5))
    clipped = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 0))
    clipped.paste(overlay.crop(INSERT_BOX), INSERT_BOX[:2])
    img.alpha_composite(clipped)

    draw = ImageDraw.Draw(img, "RGBA")
    crack = (73, 23, 20, 170)
    crack_hi = (198, 76, 61, 70)
    crack_sets = [
        [(x0 + 36, y0 + 3), (x0 + 48, y0 + 30), (x0 + 43, y0 + 55), (x0 + 61, y0 + 88)],
        [(x1 - 42, y0 + 8), (x1 - 57, y0 + 38), (x1 - 48, y0 + 70), (x1 - 66, y0 + 107)],
        [(x0 + 76, y1 - 7), (x0 + 94, y1 - 34), (x0 + 88, y1 - 62), (x0 + 112, y1 - 91)],
    ]
    for pts in crack_sets:
        _draw_crack(draw, pts, crack, 2)
        _draw_crack(draw, [(x + 1, y) for x, y in pts], crack_hi, 1)
    for pts in (
        [(x0 + 47, y0 + 31), (x0 + 27, y0 + 46)],
        [(x1 - 56, y0 + 39), (x1 - 30, y0 + 49)],
        [(x0 + 94, y1 - 34), (x0 + 120, y1 - 28)],
    ):
        _draw_crack(draw, pts, (50, 16, 14, 130), 1)


def _draw_broken_wax_seal(draw: ImageDraw.ImageDraw) -> None:
    cx, cy = 238, 112
    wax = (96, 18, 24, 235)
    wax_dark = (42, 8, 12, 245)
    wax_hi = (205, 75, 62, 100)
    draw.ellipse((cx - 17, cy - 21, cx + 15, cy + 11), fill=wax, outline=wax_dark, width=2)
    draw.ellipse((cx - 12, cy - 16, cx + 10, cy + 6), outline=wax_hi, width=1)
    draw.line((cx - 12, cy - 18, cx + 8, cy + 7), fill=wax_dark, width=3)
    draw.line((cx - 8, cy - 8, cx + 12, cy - 17), fill=wax_dark, width=2)
    draw.line((cx - 15, cy + 18, cx + 10, cy + 54), fill=(92, 18, 25, 190), width=4)
    draw.line((cx + 2, cy + 17, cx - 17, cy + 52), fill=(65, 13, 18, 175), width=3)


def _build_template(mode: str) -> Image.Image:
    if mode not in {"in_integro", "impedita"}:
        raise ValueError(mode)

    seed = 7 if mode == "in_integro" else 13
    frame = (27, 20, 13, 255) if mode == "in_integro" else (25, 14, 16, 255)
    inner = (54, 35, 18, 255) if mode == "in_integro" else (58, 22, 25, 255)
    trim = (170, 128, 56, 245) if mode == "in_integro" else (148, 38, 42, 248)
    trim_soft = (214, 175, 94, 180) if mode == "in_integro" else (210, 77, 76, 190)
    accent = (228, 193, 98, 235) if mode == "in_integro" else (176, 34, 45, 240)

    img = Image.new("RGBA", (BANNER_W, BANNER_H), frame)
    draw = ImageDraw.Draw(img, "RGBA")

    for y in range(BANNER_H):
        t = y / max(1, BANNER_H - 1)
        shade = tuple(int(frame[i] * (1 - t) + inner[i] * t) for i in range(3)) + (255,)
        draw.line((0, y, BANNER_W, y), fill=shade)

    img = _add_noise(img, 16, seed)
    draw = ImageDraw.Draw(img, "RGBA")

    draw.rounded_rectangle((4, 4, BANNER_W - 5, BANNER_H - 5), radius=9, outline=(4, 3, 2, 255), width=5)
    draw.rounded_rectangle((10, 10, BANNER_W - 11, BANNER_H - 11), radius=5, outline=trim, width=2)
    draw.rounded_rectangle((17, 17, BANNER_W - 18, BANNER_H - 18), radius=4, outline=(74, 46, 22, 180), width=1)

    # Color-key window: this exact key is removed below to make the insert slot transparent.
    draw.rectangle(INSERT_BOX, fill=KEY_COLOR)
    draw.rounded_rectangle((INSERT_BOX[0] - 4, INSERT_BOX[1] - 4, INSERT_BOX[2] + 4, INSERT_BOX[3] + 4),
                           radius=4, outline=(10, 8, 6, 235), width=4)
    draw.rounded_rectangle((INSERT_BOX[0] - 1, INSERT_BOX[1] - 1, INSERT_BOX[2] + 1, INSERT_BOX[3] + 1),
                           radius=3, outline=trim_soft, width=2)

    # Shared state key between the insert and text cartouche.
    key_x0, key_x1 = 231, 246
    draw.rectangle((key_x0, 10, key_x1, BANNER_H - 11), fill=(18, 12, 8, 230))
    draw.rectangle((key_x0 + 4, 18, key_x1 - 4, BANNER_H - 19), fill=accent)
    for y in range(23, BANNER_H - 24, 23):
        draw.line((key_x0 + 4, y, key_x1 - 4, y + 12), fill=(255, 236, 179, 90), width=1)

    _draw_parchment(draw, CARTOUCHE_BOX, mode)
    _rounded_rect(draw, CARTOUCHE_BOX, 7, fill=None, outline=(53, 32, 17, 220), width=4)
    _rounded_rect(draw, (CARTOUCHE_BOX[0] + 5, CARTOUCHE_BOX[1] + 5, CARTOUCHE_BOX[2] - 5, CARTOUCHE_BOX[3] - 5),
                  4, fill=None, outline=trim_soft, width=2)

    # Light/damaged texture on the parchment, kept subtle so runtime text remains readable.
    rng = random.Random(seed + 100)
    spots = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 0))
    spots_draw = ImageDraw.Draw(spots, "RGBA")
    for _ in range(110):
        x = rng.randint(CARTOUCHE_BOX[0] + 10, CARTOUCHE_BOX[2] - 10)
        y = rng.randint(CARTOUCHE_BOX[1] + 10, CARTOUCHE_BOX[3] - 10)
        r = rng.randint(1, 4)
        col = (83, 45, 18, rng.randint(8, 24)) if mode == "in_integro" else (79, 30, 26, rng.randint(12, 34))
        spots_draw.ellipse((x - r, y - r, x + r, y + r), fill=col)
    img = Image.alpha_composite(img, spots)
    draw = ImageDraw.Draw(img, "RGBA")

    if mode == "impedita":
        draw.rounded_rectangle((3, 3, BANNER_W - 4, BANNER_H - 4), radius=9,
                               outline=(91, 13, 19, 230), width=3)
    else:
        draw.line((INSERT_BOX[0] + 22, INSERT_BOX[1] + 10, INSERT_BOX[2] - 20, INSERT_BOX[1] + 10),
                  fill=(255, 225, 140, 95), width=2)
        draw.rounded_rectangle((3, 3, BANNER_W - 4, BANNER_H - 4), radius=9,
                               outline=(196, 151, 70, 190), width=2)

    draw.line((240, 0, 240, BANNER_H), fill=(5, 4, 3, 180), width=2)
    draw.line((247, 13, 247, BANNER_H - 14), fill=(223, 177, 87, 95), width=1)

    alpha = img.getchannel("A")
    data = img.load()
    alpha_data = alpha.load()
    for y in range(BANNER_H):
        for x in range(BANNER_W):
            if data[x, y] == KEY_COLOR:
                alpha_data[x, y] = 0
    img.putalpha(alpha)
    if mode == "impedita":
        _draw_impedita_insert_veil(img, seed + 400)
        draw = ImageDraw.Draw(img, "RGBA")
        _draw_broken_wax_seal(draw)
        draw.rounded_rectangle((3, 3, BANNER_W - 4, BANNER_H - 4), radius=9,
                               outline=(91, 13, 19, 230), width=3)
    return img


def _build_insert(response_id: str) -> Image.Image:
    path = ILLUSTRATIONS_DIR / f"{response_id}.jpg"
    src = Image.open(path).convert("RGB")
    insert_w = INSERT_BOX[2] - INSERT_BOX[0]
    insert_h = INSERT_BOX[3] - INSERT_BOX[1]
    insert = _cover_crop(src, (insert_w, insert_h)).convert("RGBA")
    insert = ImageEnhance.Color(insert).enhance(0.86)
    insert = ImageEnhance.Contrast(insert).enhance(1.08)

    vignette = Image.new("L", insert.size, 0)
    vd = ImageDraw.Draw(vignette)
    vd.rounded_rectangle((0, 0, insert.width - 1, insert.height - 1), radius=3, fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(16))
    dark = Image.new("RGBA", insert.size, (11, 7, 5, 95))
    insert = Image.composite(insert, Image.alpha_composite(insert, dark), Image.eval(vignette, lambda v: 255 - v))
    return insert


def _draw_roman_badge(img: Image.Image, response_id: str, mode: str) -> None:
    roman = ROMAN_BY_RESPONSE[response_id]
    draw = ImageDraw.Draw(img, "RGBA")
    x0, y0, x1, y1 = (20, 18, 60, 58)
    outline = (194, 150, 70, 235) if mode == "in_integro" else (184, 56, 60, 245)
    fill = (22, 15, 10, 205) if mode == "in_integro" else (31, 11, 14, 220)
    draw.ellipse((x0, y0, x1, y1), fill=fill, outline=(4, 3, 2, 255), width=3)
    draw.ellipse((x0 + 4, y0 + 4, x1 - 4, y1 - 4), outline=outline, width=2)
    font = _font(18 if len(roman) <= 2 else 15)
    bbox = draw.textbbox((0, 0), roman, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = x0 + ((x1 - x0) - tw) / 2 - bbox[0]
    ty = y0 + ((y1 - y0) - th) / 2 - bbox[1] - 1
    draw.text((tx + 1, ty + 1), roman, font=font, fill=(0, 0, 0, 210))
    draw.text((tx, ty), roman, font=font, fill=(238, 204, 116, 255))


def _compose_banner(template: Image.Image, insert: Image.Image, response_id: str, mode: str) -> Image.Image:
    out = Image.new("RGBA", (BANNER_W, BANNER_H), (0, 0, 0, 255))
    out.paste(insert, INSERT_BOX[:2])
    out.alpha_composite(template, (0, 0))
    _draw_roman_badge(out, response_id, mode)
    return out.convert("RGB")


def _build_exorcism_banner() -> Image.Image:
	src = Image.open(SOURCES_DIR / "exorcisme_generated.png").convert("RGB")
	src_ratio = src.width / src.height
	banner_ratio = BANNER_W / BANNER_H
	if abs(src_ratio - banner_ratio) > 0.001:
		raise ValueError(
			"exorcisme_generated.png must be generated at the banner ratio "
			f"{BANNER_W}:{BANNER_H}; got {src.width}x{src.height}"
		)
	return src.resize((BANNER_W, BANNER_H), Image.Resampling.LANCZOS)


def main() -> None:
    TEMPLATES_DIR.mkdir(parents=True, exist_ok=True)
    INSERTS_DIR.mkdir(parents=True, exist_ok=True)

    templates = {mode: _build_template(mode) for mode in ("in_integro", "impedita")}
    for mode, template in templates.items():
        template.save(TEMPLATES_DIR / f"{mode}.webp", quality=92, method=6)

    for response_id in RESPONSES:
        insert = _build_insert(response_id)
        insert.save(INSERTS_DIR / f"{response_id}.webp", quality=90, method=6)
        for mode, template in templates.items():
            banner = _compose_banner(template, insert, response_id, mode)
            banner.save(BANNERS_DIR / f"{response_id}_{mode}.webp", quality=90, method=6)

    _build_exorcism_banner().save(BANNERS_DIR / "exorcisme.webp", quality=90, method=6)


if __name__ == "__main__":
    main()
