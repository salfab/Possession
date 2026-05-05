"""
Possession V1g — Print-and-Play kit builder (English).

One-shot CLI : parses I18n.gd for the EN strings, renders every game card
(transgressions + liturgies + Exorcism + 2 reference cards) as a 900×1260
PNG via PIL, then composes a print-ready A4 PDF with cut marks and
front/back alignment via ReportLab.

Outputs land in ../../print/ relative to this script :
- print/cards_individual/*.png — one PNG per card face for review
- print/possession_print_kit_en.pdf — the A4 booklet, 3×3 cards per page,
  fronts on odd pages, mirrored backs on even pages so a duplex print
  lands the right back behind the right front.

Run :
    python tools/print/build.py

Re-run any time the i18n strings or the card list change.
"""

from __future__ import annotations

import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import io

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import A4, A3, landscape
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.lib.utils import ImageReader


# ─── Paths ──────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS = REPO_ROOT / "assets"
FONTS_DIR = ASSETS / "fonts"
ILLUSTRATIONS_DIR = ASSETS / "cards" / "illustrations"
TEMPLATES_DIR = ASSETS / "cards" / "templates"
SPECIAL_DIR = ASSETS / "cards" / "special"
BANNERS_DIR = ASSETS / "cards" / "liturgy_banners"
# For print, prefer the original PNG source over the JPG ingame export :
# JPG was recompressed to ~500 KB for runtime download size, the PNG keeps
# the full painterly detail for the A3 board PDF. Falls back to the JPG
# if the PNG source isn't on disk (a contributor without the high-res
# asset can still build a print kit, just with mild JPG artefacts).
_BOARD_PRINT_SOURCE = REPO_ROOT / "tools" / "sources" / "board" / "possession board 3.png"
_BOARD_RUNTIME = ASSETS / "board.jpg"
BOARD_PATH = _BOARD_PRINT_SOURCE if _BOARD_PRINT_SOURCE.exists() else _BOARD_RUNTIME
I18N_GD = REPO_ROOT / "scripts" / "data" / "I18n.gd"
OUT_DIR = REPO_ROOT / "print"
INDIVIDUAL_DIR = OUT_DIR / "cards_individual"


# ─── Template slot anchors ─────────────────────────────────────────────────────

# Mirrors Card.tscn — normalised [0,1] anchors of every text / illustration
# slot inside the WebP template. Used to compose printable cards on top of
# the illustrated frame at exactly the positions Card.gd would draw them
# in-game, so the print kit reads the same as the game.
SLOT_TITLE       = (0.283, 0.057, 0.726, 0.128)
SLOT_COST        = (0.066, 0.047, 0.245, 0.179)
SLOT_DOMAIN      = (0.774, 0.088, 0.929, 0.145)
SLOT_ILLUSTR     = (0.123, 0.135, 0.873, 0.728)
SLOT_EFFECT_TEXT = (0.203, 0.743, 0.807, 0.890)
SLOT_FACE        = (0.302, 0.917, 0.708, 0.957)


# ─── Card / page constants ──────────────────────────────────────────────────────

# 900×1260 px = 67.5×94.5 mm at 340 DPI, or 75×105 mm at 300 DPI. The cut
# trim in the final PDF is 65×91 mm, so we have a comfortable bleed +
# safe margin even after the page-layout downscale.
CARD_W = 900
CARD_H = 1260
SAFE_MARGIN = 60        # px : keep all text within (0,0)+(SAFE,SAFE) ↔ (W-SAFE,H-SAFE)

# Print page : A4 with 3×3 grid of 65×91 mm cards.
PRINT_CARD_W_MM = 65
PRINT_CARD_H_MM = 91
GRID_COLS = 3
GRID_ROWS = 3
CARDS_PER_PAGE = GRID_COLS * GRID_ROWS


# ─── Colour palette ─────────────────────────────────────────────────────────────

# Roughly mirrors the FR sample card the user shared : deep navy ground,
# warm cream ink, gold-amber accents, ochre ribbon highlight for the face
# / mode tag.
COL_BG          = (10, 22, 45)         # deep navy
COL_BG_INNER    = (16, 28, 56)         # slightly lifted inner panel
COL_BORDER_GOLD = (212, 184, 106)      # warm gold
COL_BORDER_DIM  = (96, 78, 38)         # darker gold for line-art
COL_INK         = (232, 228, 216)      # cream ink (body)
COL_INK_TITLE   = (244, 226, 168)      # brighter cream for titles
COL_RIBBON_BG   = (140, 92, 36)        # umber/ochre ribbon
COL_RIBBON_INK  = (250, 240, 218)      # off-white on ribbon
COL_RIBBON_BORDER = (60, 36, 14)       # dark wood edge
COL_LABEL_GOLD  = (218, 184, 110)      # subhead labels (e.g. "EFFECT")


# ─── Domain → palette (tiny accent on the cost circle / domain tag) ─────────────

DOMAIN_ACCENT = {
    "Ambition": (185, 106, 76),
    "Desire":   (160, 70, 110),
    "Faith":    (96, 130, 188),
    "Fear":     (110, 130, 92),
    "Will":     (148, 96, 178),
}


# ─── Card data ──────────────────────────────────────────────────────────────────

DOMAIN_EN = {
    "ambition": "Ambition",
    "desir": "Desire",
    "foi": "Faith",
    "peur": "Fear",
    "volonte": "Will",
}


@dataclass
class CardSpec:
    """One physical printable card (with two sides)."""
    card_id: str
    title: str                      # title shown on BOTH faces
    subtitle: str                   # e.g. "Transgression 01"
    domain_label: str               # e.g. "Ambition" or "Faith ▸ Will" for split
    front_face: str                 # e.g. "Scandal", "In Integro"
    back_face: str                  # e.g. "Infamy", "Impedita"
    front_cost: Optional[int]       # corruption cost shown on front, None to hide
    back_cost: Optional[int]
    front_body: list[tuple[str, str]]   # list of (label, paragraph) blocks for the front
    back_body: list[tuple[str, str]]    # same for the back
    illustration_path: Optional[Path] = None  # optional artwork file
    front_template: Optional[Path] = None  # WebP frame to use as background, front face
    back_template: Optional[Path] = None   # WebP frame to use as background, back face
    is_reference: bool = False
    front_full_bleed: Optional[Path] = None  # painted card art that occupies the entire face (Exorcism)


# Hardcoded transgression catalogue (domain + costs from TransgressionData.gd).
# Names and effect text are filled at parse time from I18n.gd.
TRANSGRESSION_CATALOG = [
    # (id, [domain_keys], origin_choice, scandal_cost, amplification_cost)
    ("nepotisme",            ["ambition"],         False, 2, 2),
    ("trafic_charges",       ["ambition"],         False, 2, 2),
    ("festin_obscene",       ["desir"],            False, 2, 3),
    ("favori_secret",        ["desir"],            False, 2, 3),
    ("simonie",              ["foi", "ambition"],  True,  3, 2),
    ("profanation",          ["foi"],              False, 3, 3),
    ("paranoia",             ["peur"],             False, 2, 2),
    ("persecution",          ["peur"],             False, 2, 2),
    ("pacte_silencieux",     ["volonte"],          False, 3, 3),
    ("abdication_interieure",["volonte"],          False, 3, 3),
]

# Same idea for liturgical responses : id, station name, target rule.
LITURGY_CATALOG = [
    ("signe_de_croix",         "I — Whispers"),
    ("examen_de_conscience",   "II — Temptation"),
    ("contrition",             "III — Fall"),
    ("confession",             "IV — Confession"),
    ("communion",              "V — Holy Office"),
]


# ─── I18n parser ────────────────────────────────────────────────────────────────

I18N_RE = re.compile(
    r'"(?P<key>[a-zA-Z0-9_.]+)"\s*:\s*\{\s*"fr"\s*:\s*"(?P<fr>(?:[^"\\]|\\.)*)"\s*,\s*"en"\s*:\s*"(?P<en>(?:[^"\\]|\\.)*)"\s*[,}]',
    re.MULTILINE,
)


def parse_i18n() -> dict[str, str]:
    """Return {key: en_text} for every entry in I18n.gd."""
    raw = I18N_GD.read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for m in I18N_RE.finditer(raw):
        key = m.group("key")
        en = m.group("en")
        # Unescape what the GDScript source quotes.
        en = en.replace("\\n", "\n").replace('\\"', '"').replace("\\\\", "\\")
        out[key] = en
    return out


# ─── Font loading ───────────────────────────────────────────────────────────────

def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    """
    weight :
      "title" → IM Fell English SC  (small caps, used for big titles)
      "body"  → IM Fell English Regular
      "face"  → Cinzel Decorative Bold (used for the face / mode tag)
      "regular" / default → IM Fell English Regular (alias for body)
    """
    paths = {
        "title":   FONTS_DIR / "IMFellEnglishSC.ttf",
        "body":    FONTS_DIR / "IMFellEnglish-Regular.ttf",
        "regular": FONTS_DIR / "IMFellEnglish-Regular.ttf",
        "face":    FONTS_DIR / "CinzelDecorative-Bold.ttf",
    }
    p = paths.get(weight, paths["body"])
    return ImageFont.truetype(str(p), size=size)


# ─── Drawing primitives ────────────────────────────────────────────────────────

def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def draw_corner_marks(draw: ImageDraw.ImageDraw, w: int, h: int, gold):
    """Four small concentric-ring corner ornaments — purely decorative."""
    r1, r2 = 32, 22
    for cx, cy in [(SAFE_MARGIN + 24, SAFE_MARGIN + 24),
                   (w - SAFE_MARGIN - 24, SAFE_MARGIN + 24),
                   (SAFE_MARGIN + 24, h - SAFE_MARGIN - 24),
                   (w - SAFE_MARGIN - 24, h - SAFE_MARGIN - 24)]:
        draw.ellipse((cx - r1, cy - r1, cx + r1, cy + r1), outline=gold, width=2)
        draw.ellipse((cx - r2, cy - r2, cx + r2, cy + r2), outline=gold, width=2)


def measure_text(draw: ImageDraw.ImageDraw, txt: str, fnt) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), txt, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def wrap_text(draw: ImageDraw.ImageDraw, txt: str, fnt, max_width: int) -> list[str]:
    """Word-wrap text to fit within max_width, preserving \\n breaks."""
    out: list[str] = []
    for paragraph in txt.split("\n"):
        words = paragraph.split(" ")
        line = ""
        for w in words:
            candidate = (line + " " + w).strip() if line else w
            if measure_text(draw, candidate, fnt)[0] <= max_width:
                line = candidate
            else:
                if line:
                    out.append(line)
                line = w
        if line:
            out.append(line)
        # Preserve blank line between paragraphs by emitting an empty string
        # only if the next paragraph follows immediately (handled by caller
        # via \n\n if needed). For now, no blank-line preservation.
    return out


def draw_paragraph(draw, x, y, max_width, blocks, body_font, label_font, ink, label_ink, line_h, label_h, paragraph_gap=12):
    """
    Render a list of (label, text) blocks. label may be "" to skip.
    Returns the y after the last line drawn.
    """
    cur_y = y
    for label, text in blocks:
        if label:
            draw.text((x, cur_y), label.upper(), fill=label_ink, font=label_font)
            cur_y += label_h + 4
        for line in wrap_text(draw, text, body_font, max_width):
            draw.text((x, cur_y), line, fill=ink, font=body_font)
            cur_y += line_h
        cur_y += paragraph_gap
    return cur_y


# ─── Per-face card render — illustrated template path ─────────────────────────

# Slot palette for templated cards — dark ink on parchment, warm gold for
# the title pill which sits on a darker plate in the template.
COL_TPL_INK         = (40, 22, 12)         # near-black umber for body
COL_TPL_INK_TITLE   = (32, 16, 8)          # near-black for the title pill — readable
                                           # on both dark velvet (transgression
                                           # template) and pale parchment (liturgy
                                           # template) without per-template tuning.
COL_TPL_INK_LABEL   = (84, 50, 18)         # darker umber for block labels
COL_TPL_RIBBON_INK  = (32, 16, 8)          # near-black on the bottom face plate


def render_face_with_template(
    *,
    template_path: Path,
    title: str,
    cost: Optional[int],
    domain_label: str,
    face: str,
    body: list[tuple[str, str]],
    illustration: Optional[Image.Image] = None,
) -> Image.Image:
    """
    Compose a printable card face by overlaying text + illustration onto
    the supplied WebP template frame. Slot positions match Card.tscn so
    the printed card reads the same way as the in-game card.
    """
    # Load the template at our render resolution. The shipped templates are
    # 720×1008 ; we render at 900×1260 (1.25×) so we resample once with
    # LANCZOS — losing some fine detail but staying ahead of the print DPI
    # (~300) at the final 65×91 mm trim size.
    template = Image.open(template_path).convert("RGBA").resize(
        (CARD_W, CARD_H), Image.LANCZOS)

    # Composite onto a white background so any transparent margin in the
    # template doesn't leak through to the PDF page.
    img = Image.new("RGB", (CARD_W, CARD_H), (250, 245, 232))
    img.paste(template, (0, 0), template)
    d = ImageDraw.Draw(img)

    def slot_box(slot):
        l, t, r, b = slot
        return (int(l * CARD_W), int(t * CARD_H), int(r * CARD_W), int(b * CARD_H))

    # Illustration into the central arch slot, cover-cropped to fill it
    # exactly. Drawn first so the template's arch ornaments overlay on top.
    if illustration is not None:
        x0, y0, x1, y1 = slot_box(SLOT_ILLUSTR)
        ill_w, ill_h = x1 - x0, y1 - y0
        sw, shh = illustration.size
        target_aspect = ill_w / ill_h
        src_aspect = sw / shh
        if src_aspect > target_aspect:
            new_w = int(shh * target_aspect)
            cx = (sw - new_w) // 2
            cropped = illustration.crop((cx, 0, cx + new_w, shh))
        else:
            new_h = int(sw / target_aspect)
            cy = (shh - new_h) // 2
            cropped = illustration.crop((0, cy, sw, cy + new_h))
        cropped = cropped.resize((ill_w, ill_h), Image.LANCZOS)
        # Paste *under* the template's arch frame ; we already pasted the
        # template above so we can't simply re-paste. Workaround : composite
        # the illustration first, then re-paste the template on top.
        base = Image.new("RGB", (CARD_W, CARD_H), (250, 245, 232))
        base.paste(cropped, (x0, y0))
        base.paste(template, (0, 0), template)
        img = base
        d = ImageDraw.Draw(img)

    # Title — fits inside the top center pill of the template. Mirrors the
    # in-game Card.gd which uses FONT_TITLE base size 30 at a 720 wide
    # reference card → ~37 px at our 900 wide canvas. Shrink further only
    # if the longest titles ("Sign of the Cross", "Inner Abdication")
    # need it. Tighter horizontal padding (24 px each side) than the raw
    # slot — the liturgy template's pill graphic is visibly narrower than
    # the slot's bounding box.
    tx0, ty0, tx1, ty1 = slot_box(SLOT_TITLE)
    title_h = ty1 - ty0
    title_w = tx1 - tx0
    safe_title_w = title_w - 48
    title_size = 38
    title_font = font(title_size, "title")
    while measure_text(d, title, title_font)[0] > safe_title_w and title_size > 18:
        title_size -= 2
        title_font = font(title_size, "title")
    tw, th = measure_text(d, title, title_font)
    d.text((tx0 + (title_w - tw) // 2, ty0 + (title_h - th) // 2 - 4),
           title, fill=COL_TPL_INK_TITLE, font=title_font)

    # Cost — number centered in the top-left circle of the template.
    if cost is not None:
        cx0, cy0, cx1, cy1 = slot_box(SLOT_COST)
        cost_size = (cy1 - cy0) - 32
        cost_font = font(cost_size, "face")
        cs = str(cost)
        cw, chh = measure_text(d, cs, cost_font)
        d.text((cx0 + (cx1 - cx0 - cw) // 2,
                cy0 + (cy1 - cy0 - chh) // 2 - 6),
               cs, fill=COL_TPL_INK_LABEL, font=cost_font)

    # Domain — short label in the top-right shield.
    dx0, dy0, dx1, dy1 = slot_box(SLOT_DOMAIN)
    dom_w = dx1 - dx0
    dom_h = dy1 - dy0
    dom_size = dom_h - 12
    dom_font = font(dom_size, "title")
    while measure_text(d, domain_label, dom_font)[0] > dom_w - 8 and dom_size > 14:
        dom_size -= 2
        dom_font = font(dom_size, "title")
    dw, dh = measure_text(d, domain_label, dom_font)
    d.text((dx0 + (dom_w - dw) // 2, dy0 + (dom_h - dh) // 2 - 2),
           domain_label, fill=COL_TPL_INK_LABEL, font=dom_font)

    # Effect text — body blocks inside the bottom parchment plate.
    ex0, ey0, ex1, ey1 = slot_box(SLOT_EFFECT_TEXT)
    text_max_w = ex1 - ex0 - 20
    body_size = 24
    body_font_lg = font(body_size, "body")
    label_font = font(20, "face")
    line_h = 30
    label_h = 24
    # Pre-flight : if the body is too tall for the slot at the default size,
    # scale fonts down progressively until it fits. Avoids the body
    # overflowing the parchment plate on long Infamy effects.
    def total_body_height(b_font, lbl_font, lh, lh_label):
        h = 0
        for label, text in body:
            if label:
                h += lh_label + 4
            wrapped = wrap_text(d, text, b_font, text_max_w)
            h += lh * len(wrapped)
            h += 6
        return h

    while body_size > 14 and total_body_height(body_font_lg, label_font, line_h, label_h) > (ey1 - ey0):
        body_size -= 2
        body_font_lg = font(body_size, "body")
        label_font = font(max(14, body_size - 4), "face")
        line_h = body_size + 6
        label_h = max(18, body_size - 2)

    draw_paragraph(d, ex0 + 10, ey0 + 8, text_max_w, body, body_font_lg, label_font,
                   COL_TPL_INK, COL_TPL_INK_LABEL, line_h, label_h, paragraph_gap=6)

    # Face label — "SCANDAL" / "INFAMY" / "IN INTEGRO" / "IMPEDITA" centred
    # on the bottom small pill.
    fx0, fy0, fx1, fy1 = slot_box(SLOT_FACE)
    face_w = fx1 - fx0
    face_h = fy1 - fy0
    face_size = face_h - 12
    face_font = font(face_size, "face")
    face_text = face.upper()
    while measure_text(d, face_text, face_font)[0] > face_w - 12 and face_size > 14:
        face_size -= 2
        face_font = font(face_size, "face")
    fw, fh = measure_text(d, face_text, face_font)
    d.text((fx0 + (face_w - fw) // 2, fy0 + (face_h - fh) // 2 - 2),
           face_text, fill=COL_TPL_RIBBON_INK, font=face_font)

    return img


# ─── Per-face card render — fallback custom layout (reference cards) ──────────

def render_face(
    *,
    title: str,
    subtitle: str,
    domain_label: str,
    face: str,           # "Scandal" / "Infamy" / "In Integro" / "Impedita" / etc.
    cost: Optional[int],
    body: list[tuple[str, str]],
    illustration: Optional[Image.Image] = None,
    is_reference: bool = False,
    compact_body: bool = False,    # smaller body fonts when many blocks (reference cards)
) -> Image.Image:
    img = Image.new("RGB", (CARD_W, CARD_H), COL_BG)
    d = ImageDraw.Draw(img)

    # Outer + inner border lines, with a subtle inset gold rectangle.
    d.rectangle((SAFE_MARGIN, SAFE_MARGIN, CARD_W - SAFE_MARGIN, CARD_H - SAFE_MARGIN),
                outline=COL_BORDER_GOLD, width=3)
    d.rectangle((SAFE_MARGIN + 8, SAFE_MARGIN + 8, CARD_W - SAFE_MARGIN - 8, CARD_H - SAFE_MARGIN - 8),
                outline=COL_BORDER_DIM, width=1)
    draw_corner_marks(d, CARD_W, CARD_H, COL_BORDER_GOLD)

    # Title plate — rounded rect at the top, title + subtitle inside.
    plate_top = SAFE_MARGIN + 50
    plate_bot = plate_top + 200
    plate_lr_inset = 90
    rounded_rect(d, (plate_lr_inset, plate_top, CARD_W - plate_lr_inset, plate_bot),
                 radius=18, outline=COL_BORDER_GOLD, width=3)
    title_font = font(72, "title")
    sub_font = font(34, "title")
    tw, th = measure_text(d, title, title_font)
    d.text(((CARD_W - tw) // 2, plate_top + 40), title, fill=COL_INK_TITLE, font=title_font)
    sw, sh = measure_text(d, subtitle, sub_font)
    d.text(((CARD_W - sw) // 2, plate_top + 130), subtitle, fill=COL_INK_TITLE, font=sub_font)

    # Domain ribbon — ochre band with face / mode label.
    rib_top = plate_bot + 30
    rib_bot = rib_top + 84
    rib_inset = 110
    rounded_rect(d, (rib_inset, rib_top, CARD_W - rib_inset, rib_bot),
                 radius=10, fill=COL_RIBBON_BG, outline=COL_RIBBON_BORDER, width=2)
    rib_text = f"{domain_label}  —  {face.upper()}"
    rib_font = font(38, "face")
    rw, rh = measure_text(d, rib_text, rib_font)
    d.text(((CARD_W - rw) // 2, rib_top + 22), rib_text, fill=COL_RIBBON_INK, font=rib_font)

    # Inner body panel.
    body_top = rib_bot + 30
    body_bot = CARD_H - SAFE_MARGIN - 90
    body_lr = SAFE_MARGIN + 30
    rounded_rect(d, (body_lr, body_top, CARD_W - body_lr, body_bot),
                 radius=22, fill=COL_BG_INNER, outline=COL_BORDER_DIM, width=2)

    # Optional illustration in the upper half of the body panel.
    body_inset_x = body_lr + 30
    body_inset_y = body_top + 30
    body_inset_r = CARD_W - body_lr - 30
    body_inset_b = body_bot - 30

    text_top = body_inset_y
    if illustration is not None and not is_reference:
        # 280 (was 360) — leaves more vertical room for the body blocks so
        # the Reminder line on transgressions doesn't get pushed onto the
        # footer.
        ill_h = 280
        ill_w = body_inset_r - body_inset_x
        # Fit-and-crop the illustration into a centred box. Preserves its
        # aspect by cover-cropping (PIL.ImageOps would do it, but we want
        # zero deps beyond what we already import).
        src = illustration
        sw, shh = src.size
        target_aspect = ill_w / ill_h
        src_aspect = sw / shh
        if src_aspect > target_aspect:
            # source wider — crop sides
            new_w = int(shh * target_aspect)
            x0 = (sw - new_w) // 2
            cropped = src.crop((x0, 0, x0 + new_w, shh))
        else:
            new_h = int(sw / target_aspect)
            y0 = (shh - new_h) // 2
            cropped = src.crop((0, y0, sw, y0 + new_h))
        cropped = cropped.resize((ill_w, ill_h), Image.LANCZOS)
        img.paste(cropped, (body_inset_x, body_inset_y))
        # Thin gold frame around the illustration.
        d.rectangle((body_inset_x, body_inset_y, body_inset_x + ill_w, body_inset_y + ill_h),
                    outline=COL_BORDER_DIM, width=2)
        text_top = body_inset_y + ill_h + 28

    # Cost circle (top-left of body panel) — small medallion with the cost.
    if cost is not None:
        cc_r = 50
        cc_x = body_inset_x + cc_r + 4
        cc_y = body_inset_y + cc_r + 4
        d.ellipse((cc_x - cc_r, cc_y - cc_r, cc_x + cc_r, cc_y + cc_r),
                  fill=COL_RIBBON_BG, outline=COL_BORDER_GOLD, width=3)
        cost_font = font(64, "face")
        cs = str(cost)
        cw, chh = measure_text(d, cs, cost_font)
        d.text((cc_x - cw // 2, cc_y - chh // 2 - 6), cs, fill=COL_RIBBON_INK, font=cost_font)

    # Body blocks. Compact mode = smaller everything, used for reference
    # cards that pack many short paragraphs into a single face.
    if compact_body:
        body_font_lg = font(24, "body")
        label_font = font(22, "face")
        line_h = 32
        label_h = 26
    else:
        body_font_lg = font(32, "body")
        label_font = font(28, "face")
        line_h = 42
        label_h = 32
    text_left = body_inset_x + (110 if cost is not None else 0)
    if cost is not None:
        text_top = max(text_top, body_inset_y + 110)
    text_max_w = body_inset_r - text_left - 10
    paragraph_gap = 6 if compact_body else 12
    draw_paragraph(d, text_left, text_top, text_max_w, body, body_font_lg, label_font,
                   COL_INK, COL_LABEL_GOLD, line_h, label_h, paragraph_gap)

    # Footer.
    foot_font = font(22, "face")
    foot = "POSSESSION  ·  V1g  ·  Fiat Tenebris"
    fw, fh = measure_text(d, foot, foot_font)
    d.text(((CARD_W - fw) // 2, CARD_H - SAFE_MARGIN - 40), foot,
           fill=COL_LABEL_GOLD, font=foot_font)

    return img


# ─── Card spec building (pull data from i18n + catalogue) ──────────────────────

def domain_label_for(domains: list[str], origin_choice: bool) -> str:
    parts = [DOMAIN_EN[d] for d in domains]
    if origin_choice and len(parts) > 1:
        return " ▸ ".join(parts)   # e.g. "Faith ▸ Ambition"
    return parts[0]


def build_transgression_specs(i18n: dict[str, str]) -> list[CardSpec]:
    out: list[CardSpec] = []
    for idx, (tid, doms, origin_choice, sc, ac) in enumerate(TRANSGRESSION_CATALOG, start=1):
        name = i18n.get(f"transgression.{tid}.name", tid)
        scandal_text = i18n.get(f"transgression.{tid}.scandal", "")
        infamy_text = i18n.get(f"transgression.{tid}.infamy", "")
        domain_label = domain_label_for(doms, origin_choice)
        ill_path = ILLUSTRATIONS_DIR / f"{tid}.jpg"

        out.append(CardSpec(
            card_id=f"transgression_{tid}",
            title=name,
            subtitle=f"Transgression {idx:02d}",
            domain_label=domain_label,
            front_face="Scandal",
            back_face="Infamy",
            front_cost=sc,
            back_cost=ac,
            front_body=[
                ("Scandal effect", scandal_text),
            ],
            back_body=[
                ("Infamy effect", infamy_text),
            ],
            illustration_path=ill_path if ill_path.exists() else None,
            front_template=TEMPLATES_DIR / "transgression_scandale.webp",
            back_template=TEMPLATES_DIR / "transgression_infamie.webp",
        ))
    return out


def build_liturgy_specs(i18n: dict[str, str]) -> list[CardSpec]:
    out: list[CardSpec] = []
    for idx, (rid, station_name) in enumerate(LITURGY_CATALOG, start=1):
        name = i18n.get(f"liturgy.{rid}.name", rid)
        in_int = i18n.get(f"liturgy.{rid}.in_integro", "")
        impedita = i18n.get(f"liturgy.{rid}.impedita", "")
        target = i18n.get(f"liturgy.targeting.{rid}", "")
        ill_path = ILLUSTRATIONS_DIR / f"{rid}.jpg"

        out.append(CardSpec(
            card_id=f"liturgy_{rid}",
            title=name,
            subtitle=station_name,
            # Domain shield on the templated card now carries the Station
            # number (the in-game card uses the resolved target Domain ;
            # for printable use the static Station ID is more useful).
            domain_label=station_name.split(" — ")[0],   # "I", "II", …
            front_face="In Integro",
            back_face="Impedita",
            front_cost=None,
            back_cost=None,
            front_body=[
                ("Targeting", target),
                ("In Integro effect", in_int),
            ],
            back_body=[
                # Drop the Targeting block on the back — same rule as the
                # front, and the impedita template's parchment plate has
                # ornate skull / candle ornaments that eat into the usable
                # text area, so the Impedita effect needs the full slot
                # to render at a legible size.
                ("Impedita effect", impedita),
            ],
            illustration_path=ill_path if ill_path.exists() else None,
            front_template=TEMPLATES_DIR / "liturgie_in_integro.webp",
            back_template=TEMPLATES_DIR / "liturgie_impedita.webp",
        ))
    return out


def build_exorcism_spec(i18n: dict[str, str]) -> CardSpec:
    # Restructure the long Exorcism back text into discrete (label, body)
    # blocks instead of a single 700-char paragraph. The i18n source ships
    # this rule as one BBCode string with [b]…[/b] section headers ; we
    # split on those markers and rebuild as the kind of block the
    # render_face draw_paragraph helper consumes (label promoted to a
    # FACE-font header, body rendered as flowing text). Bullet markers (•)
    # are preserved since IM Fell carries U+2022.
    return CardSpec(
        card_id="exorcism_final",
        title="Final Exorcism",
        subtitle="VI — Exorcism",
        domain_label="Endgame",
        front_face="Final Card",
        back_face="Resolution Rules",
        front_cost=None,
        back_cost=None,
        front_body=[],   # ignored — the painted JPG occupies the full face
        back_body=[
            ("Soul Rupture",
             "The final Exorcism fails if all three conditions are met:"),
            ("Depth",
             "3+ total Infamies, or any Infamy in Faith / Will."),
            ("Spread",
             "4+ transgressed Domains."),
            ("Anchor",
             "2+ Sealed Domains, or Will sealed AND transgressed."),
            ("Winning demon",
             "Fiat Tenebris — Will sealed AND transgressed by the same demon — that demon wins. Otherwise: final Ascendancy with bonuses (+1 per Seal, extra +1 for sealed Will, +1 per Infamy in a controlled Domain, +1 per Infamy in Faith, plus Silent Pact / Inner Abdication bonuses)."),
            ("Tie-break",
             "If Ascendancy is 0 for both: demon who sealed Will, else Will's controller, else most Infamies, else most controlled Domains, else Unstable Possession (no winner)."),
        ],
        # Front : the painted endgame card gets reproduced edge-to-edge
        # because the artwork already carries title + image + rules in
        # the printed source asset.
        front_full_bleed=SPECIAL_DIR / "exorcisme_final.jpg",
        is_reference=True,    # routes to compact custom layout (smaller fonts)
    )


def build_reference_pulse_spec() -> CardSpec:
    """Player-aid card : how a Station unfolds, pulse by pulse."""
    return CardSpec(
        card_id="aid_pulse",
        title="Station & Pulse",
        subtitle="Player Aid 1 of 2",
        domain_label="Reference",
        front_face="Station Flow",
        back_face="Tie-breakers",
        front_cost=None,
        back_cost=None,
        front_body=[
            ("Per Station", "Initiative Demon plays first ; players alternate Pulses until both Pass consecutively."),
            ("On a Pulse", "Choose ONE: Invest, Provoke, Amplify, Seal, Hinder, Exploit, Draw from the Shadow, or Pass."),
            ("End of Station", "Resolve the Liturgical Response (In Integro by default ; Impedita if a Hinder was paid in time). Then advance to the next Station."),
            ("Initiative", "Tracked separately from Ascendancy. Passes between players based on Provocations placed during the Station."),
            ("Reminder", "Provoking a new Transgression gives you +1 Ascendancy. Sealing or Hindering does not."),
        ],
        back_body=[
            ("Tie-breakers — Grip", "Most Corruption in the Domain. Tie: most Seals. Tie: holder of Ascendancy."),
            ("Tie-breakers — Domains", "Will > Faith > Desire > Ambition > Fear (Sign of the Cross)."),
            ("Soul Rupture", "Depth: an Infamy in Faith. Reach: 4 distinct Domains transgressed. Anchorage: a Will Seal."),
            ("Fiat Tenebris", "Will is Sealed AND transgressed by the same demon. Instant win at the Final Exorcism."),
            ("Final Ascendancy", "If Soul is Ruptured at Station VI, the demon with more Ascendancy wins ; tie goes to Initiative holder."),
        ],
        is_reference=True,
    )


def build_reference_actions_spec() -> CardSpec:
    """Player-aid card : every action a demon can take, with cost + effect."""
    return CardSpec(
        card_id="aid_actions",
        title="Demon Actions",
        subtitle="Player Aid 2 of 2",
        domain_label="Reference",
        front_face="Build & Spread",
        back_face="Press & Defend",
        front_cost=None,
        back_cost=None,
        front_body=[
            ("Invest (1 Corruption)", "Place 1 Corruption on a Domain. No restriction."),
            ("Exploit (free, once per Pulse)", "Once per Pulse on a Domain you control: gain +1 Corruption to your pool."),
            ("Provoke", "Pay the Transgression's Scandal cost. Place it on its Required Domain. +1 Ascendancy. Apply Scandal effect."),
            ("Amplify", "Pay the Transgression's Amplification cost. Origin Domain must be Sealed by you. Flip Scandal to Infamy. Apply Infamy effect."),
            ("Draw from the Shadow (free)", "Only when your pool is at 0 Corruption. Gain 1 Corruption."),
            ("Pass (free)", "End your Pulse without taking another action. Two consecutive Passes end the Station."),
        ],
        back_body=[
            ("Seal (2 Corruption)", "Place a Seal on a Domain you control with no opposing Corruption. Locks the Domain — opponent cannot Invest there or Provoke onto it."),
            ("Hinder a Liturgy (2 Corruption)", "Pay during the active Station. Forces the Liturgical Response into its Impedita mode at end of Station."),
            ("Crack a Seal", "Triggered by a Liturgy or a Transgression effect — never a direct action. Removes the Seal."),
            ("Reseal", "Replay the Seal action on a Domain that lost its Seal. Same restrictions apply."),
            ("Penitence", "Triggered by a Liturgy. Places a Penitence ring on a Domain — the demon there cannot Provoke from it until the Penitence is removed."),
            ("Reminder", "Hindering and Sealing do NOT grant Ascendancy. Only Provocations do."),
        ],
        is_reference=True,
    )


# ─── Page composition (PDF) ────────────────────────────────────────────────────

def compose_pdf(card_pngs: list[tuple[Path, Path]], pdf_path: Path):
    """
    card_pngs : list of (front_png, back_png). Outputs an A4 PDF with
    fronts on odd pages and mirrored backs on even pages so a duplex flip
    along the long edge lines up properly.
    """
    page_w, page_h = A4
    cw_mm = PRINT_CARD_W_MM * mm
    ch_mm = PRINT_CARD_H_MM * mm
    grid_w = GRID_COLS * cw_mm
    grid_h = GRID_ROWS * ch_mm
    margin_x = (page_w - grid_w) / 2
    margin_y = (page_h - grid_h) / 2

    c = pdfcanvas.Canvas(str(pdf_path), pagesize=A4)

    # Cache of compressed JPG bytes per PNG path. Embedding the raw PNGs
    # in the PDF gave a 112 MB output that hit GitHub's 100 MB hard limit.
    # Converting once to JPG quality 85 cuts the file ~5× while staying
    # at print quality (illustrations are photographic, JPG is the right
    # codec for them anyway). The few solid-fill UI cards lose nothing
    # visible at 85.
    jpg_cache: dict[Path, ImageReader] = {}

    def jpg_reader_for(image_path: Path) -> ImageReader:
        if image_path in jpg_cache:
            return jpg_cache[image_path]
        with Image.open(image_path) as im:
            buf = io.BytesIO()
            im.convert("RGB").save(buf, format="JPEG", quality=85, optimize=True)
            buf.seek(0)
            reader = ImageReader(buf)
        jpg_cache[image_path] = reader
        return reader

    def draw_card(image_path: Path, col: int, row: int):
        x = margin_x + col * cw_mm
        # ReportLab origin is bottom-left, so rows count from the top.
        y = page_h - margin_y - (row + 1) * ch_mm
        c.drawImage(jpg_reader_for(image_path), x, y, width=cw_mm, height=ch_mm,
                    preserveAspectRatio=True, anchor='c')
        # Cut marks at corners — small ticks 4 mm long, sitting just outside
        # the card box, so the print shop can guillotine accurately.
        tick = 4 * mm
        c.setLineWidth(0.4)
        c.setStrokeColorRGB(0.4, 0.4, 0.4)
        for cx_mark, cy_mark in [(x, y), (x + cw_mm, y), (x, y + ch_mm), (x + cw_mm, y + ch_mm)]:
            c.line(cx_mark - tick, cy_mark, cx_mark, cy_mark)
            c.line(cx_mark, cy_mark - tick, cx_mark, cy_mark)

    # Group into pages of 9.
    pages_count = (len(card_pngs) + CARDS_PER_PAGE - 1) // CARDS_PER_PAGE
    for page in range(pages_count):
        page_cards = card_pngs[page * CARDS_PER_PAGE : (page + 1) * CARDS_PER_PAGE]
        # FRONT page : cards laid left-to-right, top-to-bottom.
        for i, (front, _) in enumerate(page_cards):
            col = i % GRID_COLS
            row = i // GRID_COLS
            draw_card(front, col, row)
        # Page footer label.
        c.setFont("Helvetica", 8)
        c.setFillColorRGB(0.5, 0.5, 0.5)
        c.drawString(margin_x, margin_y / 2,
                     f"Possession V1g — print kit (EN) — page {page * 2 + 1} (fronts)")
        c.showPage()

        # BACK page : MIRROR the column order so that a duplex flip on the
        # long edge (= flip-on-short-edge in some printer dialogs ; the one
        # called "binding on top") lands the right back behind each front.
        for i, (_, back) in enumerate(page_cards):
            col = (GRID_COLS - 1) - (i % GRID_COLS)
            row = i // GRID_COLS
            draw_card(back, col, row)
        c.setFont("Helvetica", 8)
        c.setFillColorRGB(0.5, 0.5, 0.5)
        c.drawString(margin_x, margin_y / 2,
                     f"Possession V1g — print kit (EN) — page {page * 2 + 2} (backs ; mirrored for duplex)")
        c.showPage()

    c.save()


# ─── Board PDF (A3 landscape) ──────────────────────────────────────────────────

def _jpg_reader_from_path(image_path: Path) -> ImageReader:
    """Re-encode an image (PNG, WebP, JPG) as JPG quality 88 in memory and
    return an ImageReader on the buffer. Keeps the PDF small."""
    with Image.open(image_path) as im:
        buf = io.BytesIO()
        im.convert("RGB").save(buf, format="JPEG", quality=88, optimize=True)
        buf.seek(0)
    return ImageReader(buf)


def compose_board_pdf(pdf_path: Path):
    """A3 landscape (420×297 mm) with the game board centred and full-bleed
    inside a 10 mm safe margin. Cut marks at the four corners of the
    image bbox so a print shop can trim it off the A3 sheet."""
    page_size = landscape(A3)        # (420, 297) mm in points
    page_w, page_h = page_size
    margin = 10 * mm
    avail_w = page_w - 2 * margin
    avail_h = page_h - 2 * margin
    # Board aspect : 1448 × 1086 ≈ 1.333.
    with Image.open(BOARD_PATH) as im:
        bw, bh = im.size
    board_aspect = bw / bh
    avail_aspect = avail_w / avail_h
    if board_aspect > avail_aspect:
        draw_w = avail_w
        draw_h = avail_w / board_aspect
    else:
        draw_h = avail_h
        draw_w = avail_h * board_aspect
    x = (page_w - draw_w) / 2
    y = (page_h - draw_h) / 2

    c = pdfcanvas.Canvas(str(pdf_path), pagesize=page_size)
    c.drawImage(_jpg_reader_from_path(BOARD_PATH), x, y, width=draw_w, height=draw_h,
                preserveAspectRatio=True, anchor='c')

    # Cut marks at the four image corners.
    tick = 5 * mm
    c.setLineWidth(0.4)
    c.setStrokeColorRGB(0.4, 0.4, 0.4)
    for cx_mark, cy_mark in [(x, y), (x + draw_w, y), (x, y + draw_h), (x + draw_w, y + draw_h)]:
        c.line(cx_mark - tick, cy_mark, cx_mark, cy_mark)
        c.line(cx_mark, cy_mark - tick, cx_mark, cy_mark)

    # Footer label.
    c.setFont("Helvetica", 9)
    c.setFillColorRGB(0.5, 0.5, 0.5)
    c.drawString(margin, margin / 2, "Possession V1g — game board (A3 landscape, EN print kit)")
    c.save()


# ─── Banners : text overlay + PDF (A4 portrait, slot-sized) ────────────────────

# Cartouche anchors on the banner WebP, mean of the 10 banner masters per
# tools/banner_calibrate.py — same values used in-game by Main.gd to place
# the runtime label on the parchment area of each banner.
BANNER_CARTOUCHE = (0.40, 0.10, 0.92, 0.89)

# Banner physical size on the printed A3 board, derived from
# LITURGY_BANNER_HALF = Vector2(0.090, 0.045) in Main.gd (= 0.180 × 0.090
# of the board image). The board PDF lays the board at ~369.4 × 277 mm
# (height-limited inside the A3 minus margins envelope), so each banner
# slot is :
#   width  : 0.180 × 369.4 ≈ 66.5 mm
#   height : 0.090 × 277   ≈ 24.93 mm
# That matches the 600/225 ≈ 2.67 banner aspect cleanly. Print at this
# size so the cut banners drop right onto their slot on the printed board.
BANNER_PRINT_W_MM = 66.5
BANNER_PRINT_H_MM = 25.0


def render_banner_with_text(banner_path: Path, banner_text: str) -> Image.Image:
    """
    Load the WebP banner and overlay the cartouche text in IM Fell English
    Regular at the same anchors the in-game banner uses. The shipped WebP
    is 600 × 225 with an empty parchment cartouche on the right ; the
    runtime layer would normally provide the text — we have to bake it in
    for print.
    """
    img = Image.open(banner_path).convert("RGB")
    bw, bh = img.size
    d = ImageDraw.Draw(img)

    cl, ct, cr, cb = BANNER_CARTOUCHE
    x0 = int(cl * bw)
    y0 = int(ct * bh)
    x1 = int(cr * bw)
    y1 = int(cb * bh)
    box_w = x1 - x0
    box_h = y1 - y0
    inner_pad = 6
    text_max_w = box_w - 2 * inner_pad

    # Auto-shrink : start from a generous size and shrink until the wrapped
    # text height stays inside the cartouche.
    size = 32
    fnt = font(size, "body")
    while size > 12:
        wrapped = wrap_text(d, banner_text, fnt, text_max_w)
        line_h = size + 4
        total_h = line_h * len(wrapped)
        if total_h <= box_h - 2 * inner_pad and all(
                measure_text(d, line, fnt)[0] <= text_max_w for line in wrapped):
            break
        size -= 2
        fnt = font(size, "body")
    wrapped = wrap_text(d, banner_text, fnt, text_max_w)
    line_h = size + 4
    total_h = line_h * len(wrapped)

    # Vertically centre the wrapped block inside the cartouche.
    cur_y = y0 + (box_h - total_h) // 2
    ink = (40, 22, 12)         # near-black umber, same as the templated cards
    for line in wrapped:
        lw, _ = measure_text(d, line, fnt)
        d.text((x0 + (box_w - lw) // 2, cur_y), line, fill=ink, font=fnt)
        cur_y += line_h

    return img


# Print-only banner text overrides. The in-game i18n strings are tuned for
# the runtime cartouche on a phone-portrait screen, so they use compressed
# abbreviations ("Corr.", "Dom.") and the U+2212 minus glyph which IM Fell
# English doesn't carry — that minus would tofu when baked in for print.
# At print scale the cartouche has room for the full words ; this map
# expands them and substitutes ASCII hyphen-minus for the tofu-prone glyph.
# Keys are i18n keys ; values are the strings to render in print only.
BANNER_PRINT_TEXT_OVERRIDE = {
    "banner.signe_de_croix.impedita":         "-1 Corruption on top dominant",
    "banner.examen_de_conscience.in_integro": "Break Domination + bar Seal",
    # All other banner strings already render cleanly with no tofu and no
    # truncated abbreviations, so they fall through to the i18n value.
}


# Order : station-by-station, both modes adjacent so a player can cut + glue
# back-to-back into 5 double-sided station banners + 1 single-sided Exorcism.
# Tuple = (response_id, mode, station_label_for_caption, i18n_key_for_text)
BANNER_ORDER = [
    ("signe_de_croix",         "in_integro", "I — Whispers · In Integro",       "banner.signe_de_croix.in_integro"),
    ("signe_de_croix",         "impedita",   "I — Whispers · Impedita",         "banner.signe_de_croix.impedita"),
    ("examen_de_conscience",   "in_integro", "II — Temptation · In Integro",    "banner.examen_de_conscience.in_integro"),
    ("examen_de_conscience",   "impedita",   "II — Temptation · Impedita",      "banner.examen_de_conscience.impedita"),
    ("contrition",             "in_integro", "III — Fall · In Integro",         "banner.contrition.in_integro"),
    ("contrition",             "impedita",   "III — Fall · Impedita",           "banner.contrition.impedita"),
    ("confession",             "in_integro", "IV — Confession · In Integro",    "banner.confession.in_integro"),
    ("confession",             "impedita",   "IV — Confession · Impedita",      "banner.confession.impedita"),
    ("communion",              "in_integro", "V — Holy Office · In Integro",    "banner.communion.in_integro"),
    ("communion",              "impedita",   "V — Holy Office · Impedita",      "banner.communion.impedita"),
    ("exorcisme",              "special",    "VI — Final Exorcism",             "banner.exorcisme.special"),
]


def compose_banners_pdf(pdf_path: Path, i18n: dict[str, str]):
    """
    A4 portrait — 11 banners on a single page laid out 2 columns × 6 rows.
    Left column = in_integro variants, right column = impedita variants of
    the same Station, so a print + cut + glue gives 5 double-sided station
    banners + 1 single-sided Exorcism. Banner physical size on paper
    matches the corresponding banner slot on the A3 game board, so the
    cut pieces drop right onto the slots.
    """
    page_w, page_h = A4
    cw_mm_pt = BANNER_PRINT_W_MM * mm
    ch_mm_pt = BANNER_PRINT_H_MM * mm
    grid_cols = 2
    grid_rows = 6
    col_gap = 6 * mm
    row_gap = 5 * mm
    label_gap = 1.5 * mm
    label_h = 3 * mm
    grid_w = grid_cols * cw_mm_pt + (grid_cols - 1) * col_gap
    grid_h = grid_rows * (ch_mm_pt + label_gap + label_h) + (grid_rows - 1) * row_gap
    margin_x = (page_w - grid_w) / 2
    margin_y = (page_h - grid_h) / 2

    c = pdfcanvas.Canvas(str(pdf_path), pagesize=A4)

    def draw_banner(rid: str, mode: str, caption: str, text_key: str, col: int, row: int):
        x = margin_x + col * (cw_mm_pt + col_gap)
        # Top-of-page-down rows.
        block_h = ch_mm_pt + label_gap + label_h
        y_top = page_h - margin_y - row * (block_h + row_gap)
        y_banner_bot = y_top - ch_mm_pt
        # Resolve banner asset path.
        if mode == "special":
            path = BANNERS_DIR / f"{rid}.webp"
        else:
            path = BANNERS_DIR / f"{rid}_{mode}.webp"
        # Render text overlay onto the WebP, JPG-encode in memory. Print
        # override takes precedence over the i18n string so abbreviations
        # ("Corr." → "Corruption") and tofu-prone glyphs ("−" → "-") get
        # corrected for the printed kit while the live game keeps the
        # phone-cartouche-friendly compressed wording.
        text = BANNER_PRINT_TEXT_OVERRIDE.get(text_key) or i18n.get(text_key, "")
        composed = render_banner_with_text(path, text)
        buf = io.BytesIO()
        composed.save(buf, format="JPEG", quality=88, optimize=True)
        buf.seek(0)
        c.drawImage(ImageReader(buf), x, y_banner_bot,
                    width=cw_mm_pt, height=ch_mm_pt,
                    preserveAspectRatio=False, anchor='c')
        # Cut marks at the four corners.
        tick = 3 * mm
        c.setLineWidth(0.4)
        c.setStrokeColorRGB(0.4, 0.4, 0.4)
        for cx_mark, cy_mark in [(x, y_banner_bot),
                                 (x + cw_mm_pt, y_banner_bot),
                                 (x, y_top),
                                 (x + cw_mm_pt, y_top)]:
            c.line(cx_mark - tick, cy_mark, cx_mark, cy_mark)
            c.line(cx_mark, cy_mark - tick, cx_mark, cy_mark)
        # Caption underneath.
        c.setFont("Helvetica", 7)
        c.setFillColorRGB(0.3, 0.3, 0.3)
        c.drawString(x, y_banner_bot - label_gap - label_h + 1, caption)

    # Lay out station-by-station : row N has (in_integro, impedita) of the
    # same station in columns 0/1 ; the Exorcism single-sided takes col 0
    # of the last row, col 1 stays empty.
    for i in range(0, 10, 2):
        row = i // 2
        rid, mode, cap, key = BANNER_ORDER[i]
        draw_banner(rid, mode, cap, key, col=0, row=row)
        rid, mode, cap, key = BANNER_ORDER[i + 1]
        draw_banner(rid, mode, cap, key, col=1, row=row)
    # Exorcism on row 5, col 0.
    rid, mode, cap, key = BANNER_ORDER[10]
    draw_banner(rid, mode, cap, key, col=0, row=5)

    c.setFont("Helvetica", 8)
    c.setFillColorRGB(0.5, 0.5, 0.5)
    c.drawString(margin_x, 8 * mm,
                 "Possession V1g — liturgy banners (EN print kit) — sized to A3 board slots")
    c.showPage()
    c.save()


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    OUT_DIR.mkdir(exist_ok=True)
    INDIVIDUAL_DIR.mkdir(exist_ok=True)

    print("[1/4] Parsing I18n.gd ...")
    i18n = parse_i18n()
    print(f"    {len(i18n)} EN strings extracted")

    print("[2/4] Building card specs ...")
    specs: list[CardSpec] = []
    specs.extend(build_transgression_specs(i18n))
    specs.extend(build_liturgy_specs(i18n))
    specs.append(build_exorcism_spec(i18n))
    specs.append(build_reference_pulse_spec())
    specs.append(build_reference_actions_spec())
    print(f"    {len(specs)} physical cards (= {len(specs) * 2} faces)")

    print("[3/4] Rendering each face to PNG ...")
    card_pairs: list[tuple[Path, Path]] = []
    for spec in specs:
        ill = None
        if spec.illustration_path and spec.illustration_path.exists():
            try:
                ill = Image.open(spec.illustration_path).convert("RGB")
            except Exception as e:
                print(f"    illustration failed for {spec.card_id}: {e}")

        # Dispatcher : templated cards (transgressions, liturgies) use the
        # illustrated WebP frame from assets/cards/templates/ ; reference
        # cards (player aids) and the Exorcism back use the custom navy
        # layout via render_face. The Exorcism front is just the painted
        # JPG full-bleed — no template needed.
        if spec.front_full_bleed and spec.front_full_bleed.exists():
            full = Image.open(spec.front_full_bleed).convert("RGB").resize(
                (CARD_W, CARD_H), Image.LANCZOS)
            front_img = full
        elif spec.front_template and spec.front_template.exists():
            front_img = render_face_with_template(
                template_path=spec.front_template,
                title=spec.title,
                cost=spec.front_cost,
                domain_label=spec.domain_label,
                face=spec.front_face,
                body=spec.front_body,
                illustration=ill,
            )
        else:
            front_img = render_face(
                title=spec.title,
                subtitle=spec.subtitle,
                domain_label=spec.domain_label,
                face=spec.front_face,
                cost=spec.front_cost,
                body=spec.front_body,
                illustration=ill,
                is_reference=spec.is_reference,
                compact_body=spec.is_reference,
            )

        if spec.back_template and spec.back_template.exists():
            back_img = render_face_with_template(
                template_path=spec.back_template,
                title=spec.title,
                cost=spec.back_cost,
                domain_label=spec.domain_label,
                face=spec.back_face,
                body=spec.back_body,
                illustration=ill,
            )
        else:
            back_img = render_face(
                title=spec.title,
                subtitle=spec.subtitle,
                domain_label=spec.domain_label,
                face=spec.back_face,
                cost=spec.back_cost,
                body=spec.back_body,
                illustration=ill,
                is_reference=spec.is_reference,
                compact_body=spec.is_reference,
            )
        front_path = INDIVIDUAL_DIR / f"{spec.card_id}_A.png"
        back_path = INDIVIDUAL_DIR / f"{spec.card_id}_B.png"
        front_img.save(front_path)
        back_img.save(back_path)
        card_pairs.append((front_path, back_path))
        print(f"    {spec.card_id} A+B")

    print("[4/6] Composing cards A4 PDF ...")
    cards_pdf = OUT_DIR / "possession_print_kit_en.pdf"
    compose_pdf(card_pairs, cards_pdf)
    print(f"    {cards_pdf}")

    print("[5/6] Composing board A3 PDF ...")
    board_pdf = OUT_DIR / "possession_board_a3.pdf"
    compose_board_pdf(board_pdf)
    print(f"    {board_pdf}")

    print("[6/6] Composing banners A4 PDF ...")
    banners_pdf = OUT_DIR / "possession_banners_a4.pdf"
    compose_banners_pdf(banners_pdf, i18n)
    print(f"    {banners_pdf}")

    print()
    print("Done. Three PDFs produced :")
    print(" - cards : print duplex (long-edge binding) on 200-250 g/m² cardstock,")
    print("           trim along the cut marks. Final card 65×91 mm.")
    print(" - board : print A3 landscape on heavy paper, trim to the cut marks.")
    print(" - banners : print A4 portrait, 3 per page over 4 pages, trim and")
    print("             pair adjacent (in_integro / impedita) for 5 double-sided")
    print("             station banners plus the single-sided Exorcism banner.")


if __name__ == "__main__":
    main()
