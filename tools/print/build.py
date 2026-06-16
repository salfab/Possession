"""
Possession V1h — Print-and-Play kit builder (English cards + FR/EN rulebooks).

One-shot CLI : parses I18n.gd for the EN/FR strings, renders every game card
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

from PIL import Image, ImageDraw, ImageFont, ImageOps
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, A3, A5, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader
from reportlab.platypus import (
    Flowable,
    HRFlowable,
    Image as RLImage,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from xml.sax.saxutils import escape


# ─── Paths ──────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS = REPO_ROOT / "assets"
FONTS_DIR = ASSETS / "fonts"
PRINT_ASSETS_DIR = ASSETS / "print"
ILLUSTRATIONS_DIR = ASSETS / "cards" / "illustrations"
TEMPLATES_DIR = ASSETS / "cards" / "templates"
SPECIAL_DIR = ASSETS / "cards" / "special"
REFERENCE_DIR = ASSETS / "cards" / "reference"
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
RULEBOOK_TEXTURE = PRINT_ASSETS_DIR / "rulebook_page_texture.png"


# ─── Template slot anchors ─────────────────────────────────────────────────────

# Mirrors Card.tscn — normalised [0,1] anchors of every text / illustration
# slot inside the WebP template. Used to compose printable cards on top of
# the illustrated frame at exactly the positions Card.gd would draw them
# in-game, so the print kit reads the same as the game.
SLOT_TITLE_TRANS = (0.260, 0.094, 0.740, 0.181)
SLOT_TITLE_LITURGY = (0.260, 0.098, 0.740, 0.185)
SLOT_COST        = (0.056, 0.095, 0.198, 0.198)
SLOT_DOMAIN      = (0.805, 0.095, 0.945, 0.198)
SLOT_ILLUSTR     = (0.123, 0.135, 0.873, 0.728)
SLOT_EFFECT_TEXT = (0.160, 0.690, 0.840, 0.872)
SLOT_EFFECT_TEXT_IN_INTEGRO = (0.215, 0.735, 0.785, 0.895)
SLOT_EFFECT_TEXT_IMPEDITA = (0.225, 0.735, 0.775, 0.895)
SLOT_FACE        = (0.300, 0.902, 0.700, 0.947)

TEMPLATE_LAYOUTS = {
    "transgression_scandale": {
        "title": SLOT_TITLE_TRANS,
        "cost": SLOT_COST,
        "domain": SLOT_DOMAIN,
        "effect": SLOT_EFFECT_TEXT,
        "face": SLOT_FACE,
        "dark_plates": True,
        "effect_pad": 14,
        "body_start": 31,
        "body_min": 17,
        "face_size_offset": 10,
        "face_width_pad": 28,
        "face_y_adjust": -2,
    },
    "transgression_infamie": {
        "title": SLOT_TITLE_TRANS,
        "cost": SLOT_COST,
        "domain": SLOT_DOMAIN,
        "effect": (0.160, 0.675, 0.840, 0.848),
        "face": SLOT_FACE,
        "dark_plates": True,
        "effect_pad": 14,
        "body_start": 31,
        "body_min": 17,
        "face_size_offset": 10,
        "face_width_pad": 28,
        "face_y_adjust": -2,
    },
    "liturgie_in_integro": {
        "title": SLOT_TITLE_LITURGY,
        "cost": (0.050, 0.045, 0.205, 0.150),
        "domain": (0.800, 0.045, 0.950, 0.150),
        "effect": SLOT_EFFECT_TEXT_IN_INTEGRO,
        "face": (0.340, 0.935, 0.660, 0.978),
        "dark_plates": False,
        "effect_pad": 14,
        "body_start": 28,
        "body_min": 14,
        "face_size_offset": 12,
        "face_width_pad": 12,
        "face_y_adjust": 0,
    },
    "liturgie_impedita": {
        "title": SLOT_TITLE_LITURGY,
        "cost": (0.055, 0.045, 0.195, 0.145),
        "domain": (0.805, 0.045, 0.945, 0.145),
        "effect": SLOT_EFFECT_TEXT_IMPEDITA,
        "face": (0.340, 0.935, 0.660, 0.978),
        "dark_plates": False,
        "effect_pad": 18,
        "body_start": 29,
        "body_min": 18,
        "face_size_offset": 12,
        "face_width_pad": 12,
        "face_y_adjust": 0,
    },
}


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

DOMAIN_BADGE_EN = {
    "ambition": "AMB",
    "desir": "DES",
    "foi": "FTH",
    "peur": "FEA",
    "volonte": "WIL",
}


@dataclass
class CardSpec:
    """One physical printable card (with two sides)."""
    card_id: str
    title: str                      # title shown on BOTH faces
    subtitle: str                   # e.g. "Transgression 01"
    domain_label: str               # e.g. "AMB" or "FTH/AMB" for split
    front_face: str                 # e.g. "Scandal", "In Integro"
    back_face: str                  # e.g. "Infamy", "Impedita"
    front_cost: Optional[int | str]  # cost or short target cue shown in the top-left circle
    back_cost: Optional[int | str]
    front_body: list[tuple[str, str]]   # list of (label, paragraph) blocks for the front
    back_body: list[tuple[str, str]]    # same for the back
    illustration_path: Optional[Path] = None  # optional artwork file
    front_template: Optional[Path] = None  # WebP frame to use as background, front face
    back_template: Optional[Path] = None   # WebP frame to use as background, back face
    is_reference: bool = False
    front_full_bleed: Optional[Path] = None  # painted card art that occupies the entire face (Exorcism)
    front_reference_art: Optional[Path] = None  # illustrated background for text-heavy reference faces
    back_reference_art: Optional[Path] = None


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

LITURGY_TARGET_BADGE = {
    "signe_de_croix": "GRIP",
    "examen_de_conscience": "AMB\nDES",
    "contrition": "GRAVE\nSIN",
    "confession": "DEMON",
    "communion": "FAITH\nWILL",
}


# ─── I18n parser ────────────────────────────────────────────────────────────────

I18N_RE = re.compile(
    r'"(?P<key>[a-zA-Z0-9_.]+)"\s*:\s*\{\s*"fr"\s*:\s*"(?P<fr>(?:[^"\\]|\\.)*)"\s*,\s*"en"\s*:\s*"(?P<en>(?:[^"\\]|\\.)*)"\s*[,}]',
    re.MULTILINE,
)


def parse_i18n(locale: str = "en") -> dict[str, str]:
    """Return {key: localised_text} for every entry in I18n.gd."""
    if locale not in ("fr", "en"):
        raise ValueError(f"Unsupported locale: {locale}")
    raw = I18N_GD.read_text(encoding="utf-8")
    out: dict[str, str] = {}
    for m in I18N_RE.finditer(raw):
        key = m.group("key")
        en = m.group(locale)
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


def rounded_rect_layer(
    img: Image.Image,
    xy,
    radius: int,
    fill,
    outline=None,
    width: int = 1,
) -> None:
    """Draw a translucent rounded panel directly into an RGB card image."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    layer_draw = ImageDraw.Draw(layer)
    layer_draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)
    img.alpha_composite(layer)


def measure_text(draw: ImageDraw.ImageDraw, txt: str, fnt) -> tuple[int, int]:
    bbox = draw.textbbox((0, 0), txt, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


def draw_centered_text(draw: ImageDraw.ImageDraw, box, txt: str, fnt, fill, y_adjust: int = 0):
    """Center text using the actual glyph bounding box, not just advance size."""
    x0, y0, x1, y1 = box
    bbox = draw.textbbox((0, 0), txt, font=fnt)
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    x = x0 + ((x1 - x0) - bw) // 2 - bbox[0]
    y = y0 + ((y1 - y0) - bh) // 2 - bbox[1] + y_adjust
    draw.text((x, y), txt, fill=fill, font=fnt)


def draw_centered_multiline_text(draw: ImageDraw.ImageDraw, box, txt: str, weight: str, fill, start_size: int, min_size: int):
    x0, y0, x1, y1 = box
    lines = [line for line in str(txt).split("\n") if line]
    size = start_size
    while size >= min_size:
        fnt = font(size, weight)
        line_metrics = []
        max_w = 0
        total_h = 0
        line_gap = max(2, size // 9)
        for line in lines:
            bbox = draw.textbbox((0, 0), line, font=fnt)
            bw = bbox[2] - bbox[0]
            bh = bbox[3] - bbox[1]
            line_metrics.append((line, bbox, bw, bh))
            max_w = max(max_w, bw)
            total_h += bh
        total_h += line_gap * max(0, len(lines) - 1)
        if max_w <= (x1 - x0) - 22 and total_h <= (y1 - y0) - 22:
            break
        size -= 1

    fnt = font(size, weight)
    line_gap = max(2, size // 9)
    metrics = []
    total_h = 0
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=fnt)
        bw = bbox[2] - bbox[0]
        bh = bbox[3] - bbox[1]
        metrics.append((line, bbox, bw, bh))
        total_h += bh
    total_h += line_gap * max(0, len(lines) - 1)
    y = y0 + ((y1 - y0) - total_h) // 2
    for line, bbox, bw, bh in metrics:
        x = x0 + ((x1 - x0) - bw) // 2 - bbox[0]
        draw.text((x, y - bbox[1]), line, fill=fill, font=fnt)
        y += bh + line_gap


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


def paragraph_height(draw, max_width, blocks, body_font, label_font, line_h, label_h, paragraph_gap=12) -> int:
    h = 0
    for label, text in blocks:
        if label:
            h += label_h + 4
        h += line_h * len(wrap_text(draw, text, body_font, max_width))
        h += paragraph_gap
    return h


def fit_paragraph_fonts(
    draw,
    max_width: int,
    max_height: int,
    blocks,
    *,
    start_body_size: int,
    start_label_size: int,
    min_body_size: int,
    paragraph_gap: int,
    line_extra: int = 8,
    label_extra: int = 4,
):
    body_size = start_body_size
    label_delta = start_body_size - start_label_size
    while True:
        body_font = font(body_size, "body")
        label_size = max(14, body_size - label_delta)
        label_font = font(label_size, "face")
        line_h = body_size + line_extra
        label_h = label_size + label_extra
        total_h = paragraph_height(draw, max_width, blocks, body_font, label_font,
                                   line_h, label_h, paragraph_gap)
        if total_h <= max_height or body_size <= min_body_size:
            return body_font, label_font, line_h, label_h, total_h, body_size
        body_size -= 1


# ─── Per-face card render — illustrated template path ─────────────────────────

# Slot palette for templated cards — dark ink on parchment, warm gold for
# the title pill which sits on a darker plate in the template.
COL_TPL_INK         = (40, 22, 12)         # near-black umber for body
COL_TPL_INK_TITLE   = (32, 16, 8)          # near-black for pale parchment title pills
COL_TPL_INK_LABEL   = (84, 50, 18)         # darker umber for block labels
COL_TPL_RIBBON_INK  = (32, 16, 8)          # near-black on the bottom face plate
COL_TPL_LIGHT_INK   = (239, 224, 172)      # warm parchment ink on dark red/violet plates


def template_layout(template_path: Path) -> dict:
    return TEMPLATE_LAYOUTS.get(template_path.stem, TEMPLATE_LAYOUTS["transgression_scandale"])


def render_face_with_template(
    *,
    template_path: Path,
    title: str,
    cost: Optional[int | str],
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
    is_impedita = template_path.stem.endswith("impedita")
    is_in_integro = template_path.stem.endswith("in_integro")
    layout = template_layout(template_path)
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

    def transparent_bbox():
        mask = template.getchannel("A").point(lambda a: 255 if a < 128 else 0)
        return mask.getbbox()

    # Illustration into the central arch slot, cover-cropped to fill it
    # exactly. Drawn first so the template's arch ornaments overlay on top.
    if illustration is not None:
        x0, y0, x1, y1 = transparent_bbox() or slot_box(SLOT_ILLUSTR)
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
    tx0, ty0, tx1, ty1 = slot_box(layout["title"])
    title_h = ty1 - ty0
    title_w = tx1 - tx0
    safe_title_w = title_w - 48
    title_size = 38
    title_font = font(title_size, "title")
    while measure_text(d, title, title_font)[0] > safe_title_w and title_size > 18:
        title_size -= 2
        title_font = font(title_size, "title")
    tw, th = measure_text(d, title, title_font)
    title_y_adjust = 0
    title_ink = COL_TPL_LIGHT_INK if layout["dark_plates"] else COL_TPL_INK_TITLE
    draw_centered_text(d, (tx0, ty0, tx1, ty1), title, title_font,
                       title_ink, y_adjust=title_y_adjust)

    # Cost — number centered in the top-left circle of the template.
    if cost is not None:
        cx0, cy0, cx1, cy1 = slot_box(layout["cost"])
        cs = str(cost)
        if cs.isdigit():
            cost_size = (cy1 - cy0) - 32
            cost_font = font(cost_size, "face")
            draw_centered_text(d, (cx0, cy0, cx1, cy1), cs, cost_font,
                               COL_TPL_INK_LABEL)
        else:
            draw_centered_multiline_text(d, (cx0, cy0, cx1, cy1), cs.upper(), "title",
                                         COL_TPL_INK_LABEL, start_size=31, min_size=18)

    # Domain — short label in the top-right shield.
    dx0, dy0, dx1, dy1 = slot_box(layout["domain"])
    dom_w = dx1 - dx0
    dom_h = dy1 - dy0
    dom_size = dom_h - 22
    dom_font = font(dom_size, "title")
    while measure_text(d, domain_label, dom_font)[0] > dom_w - 24 and dom_size > 14:
        dom_size -= 2
        dom_font = font(dom_size, "title")
    draw_centered_text(d, (dx0, dy0, dx1, dy1), domain_label, dom_font,
                       COL_TPL_INK_LABEL)

    # Effect text — body blocks inside the bottom parchment plate.
    effect_slot = layout["effect"]
    ex0, ey0, ex1, ey1 = slot_box(effect_slot)
    inner_pad = layout["effect_pad"]
    text_max_w = ex1 - ex0 - (inner_pad * 2)
    available_h = ey1 - ey0 - (inner_pad * 2)
    body_font_lg, label_font, line_h, label_h, body_h, _body_size = fit_paragraph_fonts(
        d,
        text_max_w,
        available_h,
        body,
        start_body_size=layout["body_start"],
        start_label_size=24 if is_impedita else 23,
        min_body_size=layout["body_min"],
        paragraph_gap=6,
        line_extra=5,
        label_extra=2,
    )
    spare_h = max(0, available_h - body_h)
    center_offset = spare_h // 2
    liturgy_front_y_adjust = 0
    text_y = ey0 + inner_pad + center_offset + liturgy_front_y_adjust
    draw_paragraph(d, ex0 + inner_pad, text_y, text_max_w, body, body_font_lg, label_font,
                   COL_TPL_INK, COL_TPL_INK_LABEL, line_h, label_h, paragraph_gap=6)

    # Face label — "SCANDAL" / "INFAMY" / "IN INTEGRO" / "IMPEDITA" centred
    # on the bottom small pill.
    fx0, fy0, fx1, fy1 = slot_box(layout["face"])
    face_w = fx1 - fx0
    face_h = fy1 - fy0
    face_size = face_h - layout["face_size_offset"]
    face_font = font(face_size, "face")
    face_text = face.upper()
    while measure_text(d, face_text, face_font)[0] > face_w - layout["face_width_pad"] and face_size > 14:
        face_size -= 2
        face_font = font(face_size, "face")
    draw_centered_text(d, (fx0, fy0, fx1, fy1), face_text, face_font,
                       COL_TPL_LIGHT_INK if layout["dark_plates"] else COL_TPL_RIBBON_INK,
                       y_adjust=layout["face_y_adjust"])

    return img


# ─── Per-face card render — fallback custom layout (reference cards) ──────────

def render_face(
    *,
    title: str,
    subtitle: str,
    domain_label: str,
    face: str,           # "Scandal" / "Infamy" / "In Integro" / "Impedita" / etc.
    cost: Optional[int | str],
    body: list[tuple[str, str]],
    illustration: Optional[Image.Image] = None,
    background: Optional[Image.Image] = None,
    is_reference: bool = False,
    compact_body: bool = False,    # smaller body fonts when many blocks (reference cards)
) -> Image.Image:
    if background is not None:
        fitted = ImageOps.fit(background.convert("RGB"), (CARD_W, CARD_H), method=Image.LANCZOS)
        navy_wash = Image.new("RGB", (CARD_W, CARD_H), (7, 16, 34))
        img = Image.blend(fitted, navy_wash, 0.18).convert("RGBA")
    else:
        img = Image.new("RGBA", (CARD_W, CARD_H), COL_BG + (255,))
    d = ImageDraw.Draw(img)

    # Flat reference cards used to be drawn entirely with line art. When a
    # painted background is available, keep its own frame and only add
    # translucent reading plates so the illustration remains part of the card.
    if background is None:
        d.rectangle((SAFE_MARGIN, SAFE_MARGIN, CARD_W - SAFE_MARGIN, CARD_H - SAFE_MARGIN),
                    outline=COL_BORDER_GOLD, width=3)
        d.rectangle((SAFE_MARGIN + 8, SAFE_MARGIN + 8, CARD_W - SAFE_MARGIN - 8, CARD_H - SAFE_MARGIN - 8),
                    outline=COL_BORDER_DIM, width=1)
        draw_corner_marks(d, CARD_W, CARD_H, COL_BORDER_GOLD)

    # Title plate — rounded rect at the top, title + subtitle inside.
    plate_top = SAFE_MARGIN + 50
    plate_bot = plate_top + 200
    plate_lr_inset = 90
    if background is not None:
        rounded_rect_layer(
            img,
            (plate_lr_inset, plate_top, CARD_W - plate_lr_inset, plate_bot),
            radius=18,
            fill=(8, 18, 38, 205),
            outline=COL_BORDER_GOLD + (210,),
            width=2,
        )
        d = ImageDraw.Draw(img)
    else:
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
    if background is not None:
        rounded_rect_layer(
            img,
            (rib_inset, rib_top, CARD_W - rib_inset, rib_bot),
            radius=10,
            fill=COL_RIBBON_BG + (225,),
            outline=COL_RIBBON_BORDER + (230,),
            width=2,
        )
        d = ImageDraw.Draw(img)
    else:
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
    if background is not None:
        rounded_rect_layer(
            img,
            (body_lr, body_top, CARD_W - body_lr, body_bot),
            radius=22,
            fill=(9, 20, 42, 218),
            outline=COL_BORDER_DIM + (210,),
            width=2,
        )
        d = ImageDraw.Draw(img)
    else:
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

    text_left = body_inset_x + (110 if cost is not None else 0)
    if cost is not None:
        text_top = max(text_top, body_inset_y + 110)
    text_max_w = body_inset_r - text_left - 10
    paragraph_gap = 6 if compact_body else 12
    body_font_lg, label_font, line_h, label_h, _body_h, _body_size = fit_paragraph_fonts(
        d,
        text_max_w,
        max(1, body_inset_b - text_top),
        body,
        start_body_size=27 if compact_body else 36,
        start_label_size=24 if compact_body else 31,
        min_body_size=18 if compact_body else 22,
        paragraph_gap=paragraph_gap,
    )
    draw_paragraph(d, text_left, text_top, text_max_w, body, body_font_lg, label_font,
                   COL_INK, COL_LABEL_GOLD, line_h, label_h, paragraph_gap)

    # Footer.
    foot_font = font(22, "face")
    foot = "POSSESSION  ·  V1h  ·  Fiat Tenebris"
    fw, fh = measure_text(d, foot, foot_font)
    d.text(((CARD_W - fw) // 2, CARD_H - SAFE_MARGIN - 40), foot,
           fill=COL_LABEL_GOLD, font=foot_font)

    return img.convert("RGB")


# ─── Card spec building (pull data from i18n + catalogue) ──────────────────────

def domain_label_for(domains: list[str], origin_choice: bool) -> str:
    parts = [DOMAIN_BADGE_EN[d] for d in domains]
    if origin_choice and len(parts) > 1:
        return "/".join(parts)   # e.g. "FTH/AMB"
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
        ill_path = ILLUSTRATIONS_DIR / f"{rid}.jpg"
        target_badge = LITURGY_TARGET_BADGE.get(rid, "TARGET")

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
            front_cost=target_badge,
            back_cost=target_badge,
            front_body=[
                ("In Integro effect", in_int),
            ],
            back_body=[
                # Drop the Targeting block on the back — same rule as the
                # front, and the impedita template's parchment plate has
                # ornate skull / candle ornaments that eat into the usable
                # text area, so the Impedita effect needs the full slot
                # to render at a legible size.
                ("", impedita),
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
        back_reference_art=REFERENCE_DIR / "final_exorcism_rules.png",
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
            ("Starting pool", "Red begins with 4 available Corruptions ; Purple begins with 5."),
            ("Start of Station I-V", "In initiative order, each demon may freely Exploit one controlled Domain. This counts as that demon's Exploit for that Domain this Station."),
            ("Pulses", "Each Station has a fixed number of Pulses. On every Pulse, the initiative demon acts, then the other demon acts."),
            ("One action", "Choose ONE: Invest, Exploit, Provoke, Amplify, Seal, Crack, Hinder, Draw from the Shadow, or Pass."),
            ("End of Station", "After the last Pulse, resolve the Liturgical Response. It is In Integro unless a Hinder or card effect made it Impedita."),
        ],
        back_body=[
            ("Station order", "I: Red, 3 Pulses. II: Purple, 4. III: Red, 4. IV: Purple, 4. V: Red, 5. VI: Purple, 3."),
            ("Control", "A demon controls a Domain only if he has more Corruption there than the other demon. Equal Grip means no controller."),
            ("Net Domination", "A lead of 2+ Corruptions. Required to Seal unless a card says otherwise."),
            ("Soul Rupture", "Depth: 3+ total Infamies, or an Infamy in Faith/Will. Spread: 4+ transgressed Domains. Anchor: 2+ Seals, or Will Sealed and transgressed."),
            ("Final check", "If Rupture is incomplete, the Exorcism succeeds. If complete, check Fiat Tenebris, then final Ascendancy and tie-breakers."),
        ],
        is_reference=True,
        front_reference_art=REFERENCE_DIR / "station_flow.png",
        back_reference_art=REFERENCE_DIR / "station_flow.png",
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
            ("Invest (1 pool Corruption)", "Place 1 of your available Corruptions on a Domain. You cannot Invest into a Domain Sealed by the other demon."),
            ("Exploit (action)", "On a Domain you control, gain that Domain's production. Each demon may Exploit each Domain only once per Station."),
            ("Provoke", "Pay the card's Scandal cost, place it on a required Domain you control, gain +1 Ascendancy, then apply the Scandal effect."),
            ("Amplify", "Pay the Amplification cost. The Scandal's origin Domain must be Sealed by you and not in Penitence. Flip to Infamy and gain +1 Ascendancy."),
            ("Draw from the Shadow", "Only legal when your available Corruption pool is exactly 0. Gain 1 available Corruption."),
            ("Pass", "Spend your action doing nothing. The Station still lasts its printed number of Pulses."),
        ],
        back_body=[
            ("Seal (1 pool Corruption)", "Place a Seal on an unsealed Domain you control with Net Domination. You cannot Seal a Domain in Penitence or under Communion's reseal ban."),
            ("Crack (1+ pool Corruption)", "Remove the other demon's Seal. If cracking Will while it is transgressed, pay +1 Corruption to the Seal owner."),
            ("Hinder a Liturgy", "Target this Station or one of the next two. Remove 1 of your board Corruptions from a linked Domain you control ; reserve is untouched. The Response becomes Impedita."),
            ("Linked Domains", "I: any Domain. II: Ambition/Desire. III: transgressed Domains. IV: origins of your Transgressions. V: Faith/Will. VI: none."),
            ("Penitence", "A Domain in Penitence cannot be Sealed. A Scandal whose origin is in Penitence cannot be Amplified."),
            ("Ascendancy", "Only Provoke and Amplify add Ascendancy during play. Sealing, Cracking and Hindering do not."),
        ],
        is_reference=True,
        front_reference_art=REFERENCE_DIR / "demon_actions.png",
        back_reference_art=REFERENCE_DIR / "demon_actions.png",
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
                     f"Possession V1h — print kit (EN) — page {page * 2 + 1} (fronts)")
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
                     f"Possession V1h — print kit (EN) — page {page * 2 + 2} (backs ; mirrored for duplex)")
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
    c.drawString(margin, margin / 2, "Possession V1h — game board (A3 landscape, EN print kit)")
    c.save()


# ─── Banners : text overlay + PDF (A4 portrait, slot-sized) ────────────────────

# Cartouche anchors on the banner WebP, mean of the 10 banner masters per
# tools/banner_calibrate.py — same values used in-game by Main.gd to place
# the runtime label on the parchment area of each banner.
BANNER_CARTOUCHE = (0.40, 0.10, 0.97, 0.89)

# Banner physical size on the printed A3 board. NOT derived from
# LITURGY_BANNER_HALF — that constant defines the in-game tap hotspot,
# which is intentionally a touch larger than the painted slot for thumb
# comfort. Measured directly off Board v3 (possession board 3.png) by
# scanning the brightness profile of the right-side banner column :
# the painted parchment slots are 0.168 × 0.093 of the board (NOT the
# 0.180 × 0.090 the in-game hotspot uses). On A3 landscape with 10 mm
# margins the board renders at 395.2 × 277 mm (height-limited), giving
# slots of 66.4 × 25.8 mm. The banner artwork itself is 600 × 225 ≈
# 2.667:1 — printing at 66.5 × 25.0 mm preserves that native aspect and
# leaves ~0.4 mm of parchment margin top/bottom in each slot, which
# reads as a clean inset rather than an overlap.
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
        # phone-cartouche-friendly compressed wording. The Exorcism banner is
        # intentionally image-only: no baked title or rules text.
        if mode == "special":
            composed = Image.open(path).convert("RGB")
        else:
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
                 "Possession V1h — liturgy banners (EN print kit) — sized to A3 board slots")
    c.showPage()
    c.save()


# ─── Illustrated rulebook PDFs (A5 portrait, French + English) ────────────────

RB_INK = colors.HexColor("#33251B")
RB_MUTED = colors.HexColor("#756246")
RB_GOLD = colors.HexColor("#A77D34")
RB_DARK = colors.HexColor("#211711")
RB_PANEL = colors.HexColor("#F7F0E0")
RB_PANEL_ALT = colors.HexColor("#EFE0C4")


class RulebookStationFlow(Flowable):
    """Small visual flow: start-of-station decisions → pulses → response."""

    def __init__(self, width: float, labels: Optional[list[tuple[str, str, str]]] = None):
        super().__init__()
        self.width = width
        self.height = 34 * mm
        self.labels = labels or [
            ("1", "Début", "exploitation gratuite"),
            ("2", "Pulsations", "1 action chacun"),
            ("3", "Fin", "réponse liturgique"),
            ("4", "Suite", "station suivante"),
        ]

    def draw(self):
        c = self.canv
        gap = 2.8 * mm
        box_w = (self.width - gap * (len(self.labels) - 1)) / len(self.labels)
        box_h = 23 * mm
        y = 6 * mm
        c.saveState()
        for i, (num, title, note) in enumerate(self.labels):
            x = i * (box_w + gap)
            c.setFillColor(colors.HexColor("#FBF4E6"))
            c.setStrokeColor(RB_GOLD)
            c.setLineWidth(0.7)
            c.roundRect(x, y, box_w, box_h, 4, fill=1, stroke=1)
            c.setFillColor(RB_GOLD)
            c.circle(x + 5 * mm, y + box_h - 5.5 * mm, 3.3 * mm, fill=1, stroke=0)
            c.setFillColor(colors.white)
            c.setFont("RBFace", 6.5)
            c.drawCentredString(x + 5 * mm, y + box_h - 7.6 * mm, num)
            c.setFillColor(RB_DARK)
            c.setFont("RBSC", 8.5)
            c.drawString(x + 9.4 * mm, y + box_h - 8.3 * mm, title)
            c.setFont("RBBody", 6.9)
            c.setFillColor(RB_MUTED)
            c.drawCentredString(x + box_w / 2, y + 6.6 * mm, note)
            if i < len(self.labels) - 1:
                ax = x + box_w + 0.6 * mm
                ay = y + box_h / 2
                c.setStrokeColor(RB_GOLD)
                c.line(ax, ay, ax + gap - 1.1 * mm, ay)
                c.line(ax + gap - 1.1 * mm, ay, ax + gap - 2.2 * mm, ay + 1.3 * mm)
                c.line(ax + gap - 1.1 * mm, ay, ax + gap - 2.2 * mm, ay - 1.3 * mm)
        c.restoreState()


class RulebookDomainStrip(Flowable):
    """Five-domain visual with production reminders."""

    def __init__(self, width: float, domains: Optional[list[tuple[str, str, str]]] = None, production_label: str = "production"):
        super().__init__()
        self.width = width
        self.height = 33 * mm
        self.domains = domains or [
            ("Ambition", "2", "#B86D4E"),
            ("Désir", "2 / 3*", "#A64F78"),
            ("Foi", "1 / 2*", "#587FB8"),
            ("Peur", "1 / 2*", "#6E845A"),
            ("Volonté", "0", "#8C63A9"),
        ]
        self.production_label = production_label

    def draw(self):
        c = self.canv
        gap = 2 * mm
        box_w = (self.width - gap * 4) / 5
        box_h = 24 * mm
        y = 5 * mm
        c.saveState()
        for i, (name, prod, hex_col) in enumerate(self.domains):
            x = i * (box_w + gap)
            accent = colors.HexColor(hex_col)
            c.setFillColor(colors.HexColor("#FBF4E6"))
            c.setStrokeColor(accent)
            c.setLineWidth(0.8)
            c.roundRect(x, y, box_w, box_h, 5, fill=1, stroke=1)
            c.setFillColor(accent)
            c.rect(x, y + box_h - 4.5 * mm, box_w, 4.5 * mm, fill=1, stroke=0)
            c.setFillColor(colors.white)
            c.setFont("RBSC", 6.9)
            c.drawCentredString(x + box_w / 2, y + box_h - 3.3 * mm, name)
            c.setFillColor(RB_DARK)
            c.setFont("RBFace", 11)
            c.drawCentredString(x + box_w / 2, y + 8.4 * mm, prod)
            c.setFont("RBBody", 5.6)
            c.setFillColor(RB_MUTED)
            c.drawCentredString(x + box_w / 2, y + 3.8 * mm, self.production_label)
        c.restoreState()


def _register_rulebook_fonts():
    fonts = {
        "RBBody": FONTS_DIR / "IMFellEnglish-Regular.ttf",
        "RBSC": FONTS_DIR / "IMFellEnglishSC.ttf",
        "RBFace": FONTS_DIR / "CinzelDecorative-Bold.ttf",
    }
    for name, path in fonts.items():
        try:
            pdfmetrics.getFont(name)
        except KeyError:
            pdfmetrics.registerFont(TTFont(name, str(path)))


def _rulebook_styles() -> dict[str, ParagraphStyle]:
    return {
        "cover_title": ParagraphStyle(
            "cover_title", fontName="RBFace", fontSize=31, leading=34,
            textColor=RB_DARK, alignment=TA_CENTER, spaceAfter=2 * mm),
        "cover_sub": ParagraphStyle(
            "cover_sub", fontName="RBSC", fontSize=13, leading=16,
            textColor=RB_GOLD, alignment=TA_CENTER, spaceAfter=6 * mm),
        "kicker": ParagraphStyle(
            "kicker", fontName="RBFace", fontSize=6.8, leading=8.5,
            textColor=RB_GOLD, spaceAfter=1.5 * mm),
        "h1": ParagraphStyle(
            "h1", fontName="RBSC", fontSize=17, leading=19.5,
            textColor=RB_DARK, spaceAfter=3 * mm),
        "h2": ParagraphStyle(
            "h2", fontName="RBSC", fontSize=11.5, leading=14,
            textColor=RB_DARK, spaceBefore=2 * mm, spaceAfter=1.2 * mm),
        "body": ParagraphStyle(
            "body", fontName="RBBody", fontSize=8.8, leading=11.3,
            textColor=RB_INK, spaceAfter=1.8 * mm),
        "small": ParagraphStyle(
            "small", fontName="RBBody", fontSize=7.4, leading=9.2,
            textColor=RB_INK, spaceAfter=1.1 * mm),
        "caption": ParagraphStyle(
            "caption", fontName="RBBody", fontSize=6.4, leading=7.4,
            textColor=RB_MUTED, alignment=TA_CENTER),
        "table_head": ParagraphStyle(
            "table_head", fontName="RBSC", fontSize=6.8, leading=8,
            textColor=colors.white),
        "table_cell": ParagraphStyle(
            "table_cell", fontName="RBBody", fontSize=6.9, leading=8.1,
            textColor=RB_INK),
        "callout_title": ParagraphStyle(
            "callout_title", fontName="RBSC", fontSize=9.2, leading=11,
            textColor=RB_DARK, spaceAfter=0.8 * mm),
        "callout_body": ParagraphStyle(
            "callout_body", fontName="RBBody", fontSize=7.5, leading=9.1,
            textColor=RB_INK),
    }


def _rulebook_text(text: str) -> str:
    """Keep text inside the glyph range of the print fonts used here."""
    replacements = {
        "≥": ">=",
        "≤": "<=",
        "−": "-",
        "→": "->",
        "✓": "OK",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def _plain(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(escape(_rulebook_text(text)).replace("\n", "<br/>"), style)


def _section_title(story: list, styles: dict[str, ParagraphStyle], kicker: str, title: str, subtitle: str = ""):
    story.append(Paragraph(escape(_rulebook_text(kicker.upper())), styles["kicker"]))
    story.append(Paragraph(escape(_rulebook_text(title)), styles["h1"]))
    if subtitle:
        story.append(_plain(subtitle, styles["body"]))
    story.append(HRFlowable(width="100%", thickness=0.7, color=RB_GOLD, spaceAfter=3.2 * mm))


def _rulebook_image(path: Path, max_w: float, max_h: float, *, h_align: str = "CENTER"):
    if not path.exists():
        return Spacer(1, 0)
    with Image.open(path) as im:
        iw, ih = im.size
    scale = min(max_w / iw, max_h / ih)
    img = RLImage(str(path), iw * scale, ih * scale)
    img.hAlign = h_align
    return img


def _callout(title: str, body: str, styles: dict[str, ParagraphStyle], width: float) -> Table:
    data = [[
        Paragraph(escape(_rulebook_text(title)), styles["callout_title"]),
        _plain(body, styles["callout_body"]),
    ]]
    table = Table(data, colWidths=[29 * mm, width - 29 * mm], hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F4E8D1")),
        ("BOX", (0, 0), (-1, -1), 0.65, RB_GOLD),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return table


def _rule_table(headers: list[str], rows: list[list[str]], col_widths: list[float], styles: dict[str, ParagraphStyle]) -> Table:
    data = [[Paragraph(escape(_rulebook_text(h)), styles["table_head"]) for h in headers]]
    for row in rows:
        data.append([_plain(str(cell), styles["table_cell"]) for cell in row])
    table = Table(data, colWidths=col_widths, repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#5B3420")),
        ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#FBF5E8")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#FBF5E8"), colors.HexColor("#F2E7D4")]),
        ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C9A86A")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3.5),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3.2),
    ]))
    return table


def _image_gallery(items: list[tuple[Path, str]], styles: dict[str, ParagraphStyle], width: float, thumb_h: float) -> Table:
    cells = []
    col_w = width / len(items)
    for path, caption in items:
        cells.append([
            _rulebook_image(path, col_w - 2 * mm, thumb_h),
            Paragraph(escape(_rulebook_text(caption)), styles["caption"]),
        ])
    table = Table([cells], colWidths=[col_w] * len(items), hAlign="CENTER")
    table.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 1.5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 1.5),
        ("TOPPADDING", (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
    ]))
    return table


def _rulebook_page(canvas, doc):
    page_w, page_h = A5
    canvas.saveState()
    if RULEBOOK_TEXTURE.exists():
        canvas.drawImage(str(RULEBOOK_TEXTURE), 0, 0, width=page_w, height=page_h, preserveAspectRatio=False)
    else:
        canvas.setFillColor(colors.HexColor("#F7F0E0"))
        canvas.rect(0, 0, page_w, page_h, fill=1, stroke=0)
    # Quiet wash behind the text block: keeps the generated paper visible
    # while preserving dense-rule readability on home printers.
    try:
        canvas.setFillAlpha(0.62)
    except Exception:
        pass
    canvas.setFillColor(colors.white)
    canvas.roundRect(doc.leftMargin - 4 * mm, doc.bottomMargin - 5 * mm,
                     doc.width + 8 * mm, doc.height + 10 * mm, 5, fill=1, stroke=0)
    canvas.restoreState()
    if doc.page > 1:
        canvas.saveState()
        canvas.setFont("RBSC", 7)
        canvas.setFillColor(RB_MUTED)
        canvas.drawString(doc.leftMargin, 7.4 * mm, getattr(doc, "rulebook_footer", "Possession V1h — Rulebook"))
        canvas.drawRightString(page_w - doc.rightMargin, 7.4 * mm, str(doc.page))
        canvas.restoreState()


def _rulebook_copy(lang: str) -> dict:
    if lang == "en":
        return {
            "doc_title": "Possession V1h — Rulebook",
            "footer": "Possession V1h — Rulebook",
            "cover_sub": "Fiat Tenebris · Rulebook V1h",
            "read_first_title": "Read first",
            "read_first_body": "This booklet accompanies the print kit. The cards keep the detailed effects ; the booklet gives the game flow, targeting exceptions and a quick glossary.",
            "gallery_cover": ["Responses", "Transgressions", "Exorcism"],
            "overview_kicker": "1. Overview",
            "overview_title": "Goal and setup",
            "overview_subtitle": "Two demons contest the possession of a pope. They try to make Soul Rupture complete before the Final Exorcism, then to be the best-positioned demon when the end is resolved.",
            "domain_production": "production",
            "setup_text": "Quick setup : place the board, give 4 available Corruptions to Red and 5 to Purple, and start at Station I — Whispers. Prepare the Transgression cards, Liturgical Responses and Station banners. Banners start on their In Integro side ; flip them only if the Response is hindered.",
            "overview_headers": ["Component", "What it does"],
            "overview_rows": [
                ["Board", "Five Domains receive Corruptions, Seals, Penitences and Transgressions."],
                ["Transgressions", "Unique cards played as Scandals, then possibly amplified into Infamies."],
                ["Liturgical Responses", "Automatic effects at the end of Stations I to V. Each Response has an In Integro face and an Impedita face."],
                ["Final Exorcism", "Station VI resolution : Soul Rupture, Fiat Tenebris, then final Ascendancy."],
            ],
            "flow_kicker": "2. Tempo",
            "flow_title": "Stations, Pulses and Initiative",
            "flow_labels": [
                ("1", "Start", "free exploit"),
                ("2", "Pulses", "1 action each"),
                ("3", "End", "liturgical response"),
                ("4", "Next", "next station"),
            ],
            "station_text": "A Station has a fixed number of Pulses. On each Pulse, the initiative demon acts, then the other demon acts. Passing simply spends your action : it does not shorten the Station.",
            "station_headers": ["Station", "Initiative", "Pulses", "End of Station"],
            "station_rows": [
                ["I — Whispers", "Red", "3", "Sign of the Cross"],
                ["II — Temptation", "Purple", "4", "Examination of Conscience"],
                ["III — Fall", "Red", "4", "Contrition"],
                ["IV — Confession", "Purple", "4", "Confession"],
                ["V — Holy Office", "Red", "5", "Communion"],
                ["VI — Exorcism", "Purple", "3", "Final Exorcism"],
            ],
            "start_callout_title": "Start of Station",
            "start_callout_body": "In Stations I to V, each demon may freely Exploit one controlled Domain, in Initiative order. This free Exploit counts as that demon's normal Exploit for that Domain during the Station.",
            "actions_kicker": "3. Actions",
            "actions_title": "What a demon can do",
            "actions_gallery": ["Action aid A", "Action aid B", "Pulse aid"],
            "actions_headers": ["Action", "Cost / condition", "Effect"],
            "actions_rows": [
                ["Invest", "1 available Corruption", "Place 1 Corruption on a Domain. You cannot Invest into a Domain Sealed by the other demon."],
                ["Exploit", "Control the Domain", "Gain that Domain's production. Each demon may Exploit each Domain only once per Station."],
                ["Provoke", "The card's Scandal cost", "Place a unique Transgression on a required Domain you control. Gain +1 Ascendancy, then apply the Scandal effect."],
                ["Amplify", "Infamy cost ; origin Sealed by you and not in Penitence", "Flip your Scandal to Infamy. Gain +1 Ascendancy, then apply the Infamy effect."],
                ["Seal", "1 Corruption ; controlled Domain with Net Domination", "Place your Seal. Illegal if already Sealed, in Penitence, or blocked by Communion."],
                ["Crack", "1 Corruption ; opponent's Seal", "Remove the opponent's Seal. On transgressed Will, also pay 1 Corruption to the Seal owner."],
                ["Hinder", "Remove 1 of your Corruptions from a linked Domain you control", "The targeted Response becomes Impedita. Target this Station or one of the next two ; never the Exorcism."],
                ["Draw from the Shadow", "Pool exactly at 0", "Gain 1 available Corruption."],
                ["Pass", "No cost", "Do nothing with this action."],
            ],
            "trans_kicker": "4. Transgressions",
            "trans_title": "Scandals, Infamies and Codex",
            "trans_body": "A Transgression is unique : if one demon already owns it, the other cannot Provoke it. Provoke creates a Scandal and gives +1 Ascendancy. Amplify turns that Scandal into an Infamy and gives another +1 Ascendancy.",
            "trans_gallery": ["Scandal", "Infamy", "Will"],
            "codex_title": "Codex of Transgressions",
            "codex_body": "Without the Codex, use the 10 V1h Transgressions. With the Codex, each Domain has a group of 4 cards ; select 2 cards per Domain, for 10 available Transgressions in the game. Non-selected cards cannot be Provoked.",
            "codex_headers": ["Domain", "Codex group (choose 2 of 4)"],
            "liturgy_kicker": "5. Liturgy",
            "liturgy_title": "Targeting and Hinder",
            "liturgy_body": "The target is always determined before resolution. If the Response is hindered, it resolves on its Impedita face. Simony Infamy is checked after the target is chosen : if the target is Faith, the Response automatically becomes Impedita and the trigger is consumed.",
            "liturgy_headers": ["Response", "V1h targeting"],
            "entrave_kicker": "6. Hinder",
            "entrave_title": "Domains linked to Responses",
            "entrave_body": "Hinder does not spend the reserve : the active demon removes 1 of his Corruptions already on the board from a linked Domain he controls and where he has at least one Corruption. This sacrifice may make him lose control of the Domain ; the Hinder remains valid.",
            "entrave_headers": ["Targeted Station", "Linked Domains used to pay Hinder"],
            "entrave_rows": [
                ["I — Whispers", "Any Domain."],
                ["II — Temptation", "Ambition or Desire."],
                ["III — Fall", "The currently transgressed Domains."],
                ["IV — Confession", "The origin Domains of the hindering demon's Transgressions."],
                ["V — Holy Office", "Faith or Will."],
                ["VI — Exorcism", "None : the Final Exorcism cannot be hindered."],
            ],
            "window_title": "Timing window",
            "window_body": "A Hinder can target the current Station or one of the next two Stations. A single Response can receive only one Hinder.",
            "missel_kicker": "7. Corrupted Missal",
            "missel_title": "Targeting variants",
            "missel_body": "The Corrupted Missal never changes a Response's effect : it only replaces its targeting. If the variant has no valid target, return to that Response's V1h targeting.",
            "missel_headers": ["Missal", "Replaced targeting"],
            "missel_rows": [
                ["I-A Purifying Sign", "Unsealed Domain with the most total Corruption ; priority Will > Faith > Fear > Desire > Ambition."],
                ["I-B Sign on the Wound", "Transgressed Domain with the most total Corruption ; same priority on ties."],
                ["II-A Examination of the Flesh", "Desire if it contains Corruption, otherwise Ambition."],
                ["II-B Examination of Vanities", "Ambition if it contains Corruption, otherwise Desire."],
                ["III-A Contrition of the Infamous", "Transgressed Domain with the most Infamies ; then Scandals, then Grip."],
                ["III-B Contrition of Scandals", "Transgressed Domain with the most Scandals ; then Infamies, then Grip."],
                ["IV-A Confession of the Proud", "Demon favoured by Ascendancy ; if Ascendancy is 0, use V1h targeting."],
                ["IV-B Confession of the Corrupter", "Demon with the most Infamies ; then total Transgressions, Ascendancy, then no Initiative."],
                ["V-A Communion of Faith", "Faith if it is active, otherwise Will."],
                ["V-B Communion of Will", "Will if it is active, otherwise Faith."],
            ],
            "final_kicker": "8. Final Exorcism",
            "final_title": "Rupture, Fiat Tenebris, Ascendancy",
            "final_headers": ["Step", "Condition / resolution"],
            "final_rows": [
                ["1. Soul Rupture", "It is complete only if Depth, Spread and Anchor are all filled. Otherwise, the Exorcism succeeds and no demon wins."],
                ["Depth", "3+ total Infamies, or at least one Infamy in Faith or Will."],
                ["Spread", "4+ transgressed Domains."],
                ["Anchor", "2+ Sealed Domains, or Will Sealed and transgressed."],
                ["2. Fiat Tenebris", "If Will is Sealed and transgressed by the same demon, that demon wins immediately."],
                ["3. Final Ascendancy", "+1 per Seal, +1 extra for Sealed Will, +1 per Infamy in a Domain you control, +1 per Infamy in Faith, plus Silent Pact / Inner Abdication bonuses."],
                ["Tie", "Demon who Sealed Will ; otherwise Will's controller ; otherwise most Infamies ; otherwise most controlled Domains ; otherwise Unstable Possession."],
            ],
            "glossary_kicker": "9. Glossary",
            "glossary_title": "Quick reference",
            "glossary_headers": ["Term", "Definition"],
        }

    return {
        "doc_title": "Possession V1h — Livret de règles",
        "footer": "Possession V1h — Livret de règles",
        "cover_sub": "Fiat Tenebris · Livret de règles V1h",
        "read_first_title": "Lire d'abord",
        "read_first_body": "Ce livret accompagne le print kit. Les cartes gardent les effets détaillés ; le livret donne le fil de partie, les exceptions de ciblage et un glossaire rapide.",
        "gallery_cover": ["Réponses", "Transgressions", "Exorcisme"],
        "overview_kicker": "1. Vue d'ensemble",
        "overview_title": "But du jeu et mise en place",
        "overview_subtitle": "Deux démons disputent la possession d'un pape. Ils cherchent à rendre la Rupture de l'âme complète avant l'Exorcisme final, puis à être le démon le mieux placé pour l'emporter.",
        "domain_production": "production",
        "setup_text": "Mise en place courte : placez le plateau, donnez 4 Corruptions disponibles à Rouge et 5 à Violet, démarrez à la Station I — Murmures. Préparez les cartes Transgression, les Réponses liturgiques et les bannières de Station. Les bannières commencent côté In Integro ; retournez-les seulement si la Réponse est entravée.",
        "overview_headers": ["Élément", "À quoi ça sert"],
        "overview_rows": [
            ["Plateau", "Cinq Domaines reçoivent les Corruptions, Sceaux, Pénitences et Transgressions."],
            ["Transgressions", "Cartes uniques posées en Scandale, puis éventuellement amplifiées en Infamie."],
            ["Réponses liturgiques", "Effets automatiques à la fin des Stations I à V. Chaque réponse a une face In Integro et une face Impedita."],
            ["Exorcisme final", "Résolution de la Station VI : Rupture de l'âme, Fiat Tenebris, puis Ascendant final."],
        ],
        "flow_kicker": "2. Rythme",
        "flow_title": "Stations, pulsations et initiative",
        "flow_labels": [
            ("1", "Début", "exploitation gratuite"),
            ("2", "Pulsations", "1 action chacun"),
            ("3", "Fin", "réponse liturgique"),
            ("4", "Suite", "station suivante"),
        ],
        "station_text": "Une Station possède un nombre fixe de Pulsations. À chaque Pulsation, le démon d'Initiative agit, puis l'autre. Passer consomme simplement son action : cela ne raccourcit pas la Station.",
        "station_headers": ["Station", "Initiative", "Pulsations", "Fin de Station"],
        "station_rows": [
            ["I — Murmures", "Rouge", "3", "Signe de croix"],
            ["II — Tentation", "Violet", "4", "Examen de conscience"],
            ["III — Chute", "Rouge", "4", "Contrition"],
            ["IV — Confession", "Violet", "4", "Confession"],
            ["V — Office sacré", "Rouge", "5", "Communion"],
            ["VI — Exorcisme", "Violet", "3", "Exorcisme final"],
        ],
        "start_callout_title": "Début de Station",
        "start_callout_body": "Aux Stations I à V, chaque démon peut exploiter gratuitement un Domaine qu'il contrôle, dans l'ordre d'Initiative. Cette exploitation gratuite compte comme une exploitation normale pour ce Domaine et ce démon pendant la Station.",
        "actions_kicker": "3. Actions",
        "actions_title": "Ce qu'un démon peut faire",
        "actions_gallery": ["Aide actions A", "Aide actions B", "Aide pulsations"],
        "actions_headers": ["Action", "Coût / condition", "Effet"],
        "actions_rows": [
            ["Investir", "1 Corruption disponible", "Placez 1 Corruption sur un Domaine. Impossible dans un Domaine scellé par l'autre démon."],
            ["Exploiter", "Contrôler le Domaine", "Gagnez sa production. Chaque démon ne peut exploiter chaque Domaine qu'une fois par Station."],
            ["Provoquer", "Coût Scandale de la carte", "Placez une Transgression unique sur un Domaine requis que vous contrôlez. +1 Ascendant, puis effet Scandale."],
            ["Amplifier", "Coût Infamie ; origine scellée par vous et hors Pénitence", "Retournez votre Scandale en Infamie. +1 Ascendant, puis effet Infamie."],
            ["Sceller", "1 Corruption ; Domaine contrôlé avec Domination nette", "Posez votre Sceau. Interdit si déjà scellé, en Pénitence, ou bloqué par Communion."],
            ["Fissurer", "1 Corruption ; Sceau adverse", "Retirez le Sceau adverse. Sur Volonté transgressée, payez aussi 1 Corruption au propriétaire du Sceau."],
            ["Entraver", "Retirer 1 de vos Corruptions d'un Domaine lié que vous contrôlez", "La Réponse ciblée devient Impedita. Cible : Station actuelle ou une des deux prochaines ; jamais l'Exorcisme."],
            ["Puiser dans l'Ombre", "Réserve exactement à 0", "Gagnez 1 Corruption disponible."],
            ["Passer", "Aucun coût", "Vous ne faites rien pour cette action."],
        ],
        "trans_kicker": "4. Transgressions",
        "trans_title": "Scandales, Infamies et Codex",
        "trans_body": "Une Transgression est unique : si elle appartient déjà à un démon, l'autre ne peut plus la provoquer. Provoquer crée un Scandale et donne +1 Ascendant. Amplifier transforme ce Scandale en Infamie et donne encore +1 Ascendant.",
        "trans_gallery": ["Scandale", "Infamie", "Volonté"],
        "codex_title": "Codex des Transgressions",
        "codex_body": "Sans Codex, utilisez les 10 Transgressions V1h. Avec Codex, chaque Domaine possède un groupe de 4 cartes ; sélectionnez 2 cartes par Domaine, soit 10 Transgressions disponibles pour la partie. Les cartes non sélectionnées ne peuvent pas être provoquées.",
        "codex_headers": ["Domaine", "Groupe Codex (choisir 2 sur 4)"],
        "liturgy_kicker": "5. Réponses liturgiques",
        "liturgy_title": "Ciblage et Entrave",
        "liturgy_body": "La cible est toujours déterminée avant la résolution. Si la réponse est entravée, elle résout sa face Impedita. Simonie Infamie se vérifie après le choix de cible : si la cible est Foi, la réponse devient automatiquement Impedita et le déclencheur est consommé.",
        "liturgy_headers": ["Réponse", "Ciblage V1h"],
        "entrave_kicker": "6. Entrave",
        "entrave_title": "Domaines liés aux Réponses",
        "entrave_body": "Entraver ne dépense pas la réserve : le démon actif retire 1 de ses Corruptions déjà posées sur le plateau depuis un Domaine lié, contrôlé par lui, et contenant au moins une de ses Corruptions. Ce sacrifice peut lui faire perdre le contrôle du Domaine ; l'Entrave reste valide.",
        "entrave_headers": ["Station ciblée", "Domaines liés pour payer l'Entrave"],
        "entrave_rows": [
            ["I — Murmures", "N'importe quel Domaine."],
            ["II — Tentation", "Ambition ou Désir."],
            ["III — Chute", "Les Domaines actuellement transgressés."],
            ["IV — Confession", "Les Domaines d'origine des Transgressions du démon qui entrave."],
            ["V — Office sacré", "Foi ou Volonté."],
            ["VI — Exorcisme", "Aucun : l'Exorcisme final ne peut pas être entravé."],
        ],
        "window_title": "Fenêtre de tir",
        "window_body": "Une Entrave peut viser la Station en cours ou une des deux Stations suivantes. Une même Réponse ne peut recevoir qu'une seule Entrave.",
        "missel_kicker": "7. Missel Corrompu",
        "missel_title": "Variantes de ciblage",
        "missel_body": "Le Missel Corrompu ne change jamais l'effet d'une Réponse : il remplace seulement son ciblage. Si la variante n'a aucune cible valide, revenez au ciblage V1h de la Réponse.",
        "missel_headers": ["Missel", "Ciblage remplacé"],
        "missel_rows": [
            ["I-A Signe purificateur", "Domaine non scellé avec le plus de Corruption totale ; priorité Volonté > Foi > Peur > Désir > Ambition."],
            ["I-B Signe sur la plaie", "Domaine transgressé avec le plus de Corruption totale ; même priorité en cas d'égalité."],
            ["II-A Examen de la chair", "Désir s'il contient de la Corruption, sinon Ambition."],
            ["II-B Examen des vanités", "Ambition si elle contient de la Corruption, sinon Désir."],
            ["III-A Contrition des infâmes", "Domaine transgressé contenant le plus d'Infamies ; puis Scandales, puis Emprise."],
            ["III-B Contrition des scandales", "Domaine transgressé contenant le plus de Scandales ; puis Infamies, puis Emprise."],
            ["IV-A Confession du plus orgueilleux", "Démon favorisé par l'Ascendant ; si Ascendant nul, ciblage V1h."],
            ["IV-B Confession du corrupteur", "Démon avec le plus d'Infamies ; puis total de Transgressions, Ascendant, puis sans Initiative."],
            ["V-A Communion de la Foi", "Foi si elle est active, sinon Volonté."],
            ["V-B Communion de la Volonté", "Volonté si elle est active, sinon Foi."],
        ],
        "final_kicker": "8. Exorcisme final",
        "final_title": "Rupture, Fiat Tenebris, Ascendant",
        "final_headers": ["Étape", "Condition / résolution"],
        "final_rows": [
            ["1. Rupture de l'âme", "Elle est complète seulement si Profondeur, Étendue et Ancrage sont tous remplis. Sinon, l'Exorcisme réussit et aucun démon ne gagne."],
            ["Profondeur", "3+ Infamies au total, ou au moins une Infamie en Foi ou Volonté."],
            ["Étendue", "4+ Domaines transgressés."],
            ["Ancrage", "2+ Domaines scellés, ou Volonté scellée et transgressée."],
            ["2. Fiat Tenebris", "Si Volonté est scellée et transgressée par le même démon, ce démon gagne immédiatement."],
            ["3. Ascendant final", "+1 par Sceau, +1 supplémentaire pour Volonté scellée, +1 par Infamie dans un Domaine que vous contrôlez, +1 par Infamie en Foi, plus bonus Pacte silencieux / Abdication intérieure."],
            ["Égalité", "Démon qui a scellé Volonté ; sinon contrôleur de Volonté ; sinon plus d'Infamies ; sinon plus de Domaines contrôlés ; sinon Possession instable."],
        ],
        "glossary_kicker": "9. Glossaire",
        "glossary_title": "Référence rapide",
        "glossary_headers": ["Terme", "Définition"],
    }


def compose_rulebook_pdf(pdf_path: Path, i18n: dict[str, str], lang: str = "fr"):
    _register_rulebook_fonts()
    styles = _rulebook_styles()
    copy = _rulebook_copy(lang)
    doc = SimpleDocTemplate(
        str(pdf_path),
        pagesize=A5,
        leftMargin=12.5 * mm,
        rightMargin=12.5 * mm,
        topMargin=12 * mm,
        bottomMargin=15 * mm,
        title=copy["doc_title"],
        author="Possession print kit",
    )
    doc.rulebook_footer = copy["footer"]
    w = doc.width
    story: list = []
    domain_strip = [
        (i18n.get("domain.ambition", "Ambition"), "2", "#B86D4E"),
        (i18n.get("domain.desir", "Desire"), "2 / 3*", "#A64F78"),
        (i18n.get("domain.foi", "Faith"), "1 / 2*", "#587FB8"),
        (i18n.get("domain.peur", "Fear"), "1 / 2*", "#6E845A"),
        (i18n.get("domain.volonte", "Will"), "0", "#8C63A9"),
    ]

    # Cover
    story.append(Spacer(1, 7 * mm))
    story.append(Paragraph("POSSESSION", styles["cover_title"]))
    story.append(Paragraph(escape(_rulebook_text(copy["cover_sub"])), styles["cover_sub"]))
    story.append(_rulebook_image(BOARD_PATH, w, 58 * mm))
    story.append(Spacer(1, 4 * mm))
    story.append(_callout(copy["read_first_title"], copy["read_first_body"], styles, w))
    story.append(Spacer(1, 5 * mm))
    story.append(_image_gallery([
        (ILLUSTRATIONS_DIR / "signe_de_croix.jpg", copy["gallery_cover"][0]),
        (ILLUSTRATIONS_DIR / "simonie.jpg", copy["gallery_cover"][1]),
        (SPECIAL_DIR / "exorcisme_final.jpg", copy["gallery_cover"][2]),
    ], styles, w, 28 * mm))
    story.append(PageBreak())

    # Goal / setup
    _section_title(story, styles, copy["overview_kicker"], copy["overview_title"], copy["overview_subtitle"])
    story.append(RulebookDomainStrip(w, domain_strip, copy["domain_production"]))
    story.append(_plain(copy["setup_text"], styles["body"]))
    story.append(_rule_table(
        copy["overview_headers"],
        copy["overview_rows"],
        [31 * mm, w - 31 * mm],
        styles))
    story.append(PageBreak())

    # Station flow
    _section_title(story, styles, copy["flow_kicker"], copy["flow_title"])
    story.append(RulebookStationFlow(w, copy["flow_labels"]))
    story.append(_plain(copy["station_text"], styles["body"]))
    story.append(_rule_table(
        copy["station_headers"],
        copy["station_rows"],
        [33 * mm, 23 * mm, 20 * mm, w - 76 * mm],
        styles))
    story.append(_callout(copy["start_callout_title"], copy["start_callout_body"], styles, w))
    story.append(PageBreak())

    # Actions
    _section_title(story, styles, copy["actions_kicker"], copy["actions_title"])
    story.append(_image_gallery([
        (INDIVIDUAL_DIR / "aid_actions_A.png", copy["actions_gallery"][0]),
        (INDIVIDUAL_DIR / "aid_actions_B.png", copy["actions_gallery"][1]),
        (INDIVIDUAL_DIR / "aid_pulse_A.png", copy["actions_gallery"][2]),
    ], styles, w, 33 * mm))
    story.append(Spacer(1, 2 * mm))
    story.append(_rule_table(
        copy["actions_headers"],
        copy["actions_rows"],
        [22 * mm, 40 * mm, w - 62 * mm],
        styles))
    story.append(PageBreak())

    # Transgressions and Codex setup
    _section_title(story, styles, copy["trans_kicker"], copy["trans_title"])
    story.append(_plain(copy["trans_body"], styles["body"]))
    story.append(_image_gallery([
        (INDIVIDUAL_DIR / "transgression_nepotisme_A.png", copy["trans_gallery"][0]),
        (INDIVIDUAL_DIR / "transgression_simonie_B.png", copy["trans_gallery"][1]),
        (INDIVIDUAL_DIR / "transgression_pacte_silencieux_A.png", copy["trans_gallery"][2]),
    ], styles, w, 35 * mm))
    story.append(Spacer(1, 2 * mm))
    story.append(_callout(copy["codex_title"], copy["codex_body"], styles, w))
    codex_groups = [
        (i18n.get("domain.ambition", "Ambition"), ["nepotisme", "trafic_charges", "intrigue_consistoire", "bulle_vendue"]),
        (i18n.get("domain.desir", "Desire"), ["festin_obscene", "favori_secret", "mascarade_velours", "appetit_heretique"]),
        (i18n.get("domain.foi", "Faith"), ["simonie", "profanation", "dogme_renverse", "reliques_menteuses"]),
        (i18n.get("domain.peur", "Fear"), ["paranoia", "persecution", "denonciation_anonyme", "panique_contagieuse"]),
        (i18n.get("domain.volonte", "Will"), ["pacte_silencieux", "abdication_interieure", "obeissance_pervertie", "renoncement_noir"]),
    ]
    story.append(_rule_table(
        copy["codex_headers"],
        [[domain, ", ".join(i18n.get(f"transgression.{tid}.name", tid) for tid in tids)]
         for domain, tids in codex_groups],
        [24 * mm, w - 24 * mm],
        styles))
    story.append(PageBreak())

    # Liturgy targeting
    _section_title(story, styles, copy["liturgy_kicker"], copy["liturgy_title"])
    story.append(_plain(copy["liturgy_body"], styles["body"]))
    story.append(_image_gallery([
        (INDIVIDUAL_DIR / "liturgy_signe_de_croix_A.png", "In Integro"),
        (INDIVIDUAL_DIR / "liturgy_signe_de_croix_B.png", "Impedita"),
        (INDIVIDUAL_DIR / "liturgy_communion_A.png", "Communion"),
    ], styles, w, 35 * mm))
    lit_rows = [
        [f"I — {i18n.get('liturgy.signe_de_croix.name', 'Sign of the Cross')}", i18n.get("liturgy.targeting.signe_de_croix", "")],
        [f"II — {i18n.get('liturgy.examen_de_conscience.name', 'Examination')}", i18n.get("liturgy.targeting.examen_de_conscience", "")],
        [f"III — {i18n.get('liturgy.contrition.name', 'Contrition')}", i18n.get("liturgy.targeting.contrition", "")],
        [f"IV — {i18n.get('liturgy.confession.name', 'Confession')}", i18n.get("liturgy.targeting.confession", "")],
        [f"V — {i18n.get('liturgy.communion.name', 'Communion')}", i18n.get("liturgy.targeting.communion", "")],
    ]
    story.append(_rule_table(copy["liturgy_headers"], lit_rows, [31 * mm, w - 31 * mm], styles))
    story.append(PageBreak())

    _section_title(story, styles, copy["entrave_kicker"], copy["entrave_title"])
    story.append(_plain(copy["entrave_body"], styles["body"]))
    story.append(_rule_table(
        copy["entrave_headers"],
        copy["entrave_rows"],
        [33 * mm, w - 33 * mm],
        styles))
    story.append(_callout(copy["window_title"], copy["window_body"], styles, w))
    story.append(PageBreak())

    # Missel Corrompu
    _section_title(story, styles, copy["missel_kicker"], copy["missel_title"])
    story.append(_plain(copy["missel_body"], styles["body"]))
    story.append(_rule_table(copy["missel_headers"], copy["missel_rows"], [35 * mm, w - 35 * mm], styles))
    story.append(PageBreak())

    # Final Exorcism
    _section_title(story, styles, copy["final_kicker"], copy["final_title"])
    story.append(_rulebook_image(SPECIAL_DIR / "exorcisme_final.jpg", w, 47 * mm))
    story.append(Spacer(1, 2 * mm))
    story.append(_rule_table(
        copy["final_headers"],
        copy["final_rows"],
        [34 * mm, w - 34 * mm],
        styles))
    story.append(PageBreak())

    # Glossary
    _section_title(story, styles, copy["glossary_kicker"], copy["glossary_title"])
    glossary_order = [
        "domain", "emprise", "domination", "transgression", "scandale", "infamie",
        "sceau", "penitence", "liturgie", "in_integro", "impedita",
        "rupture_ame", "fiat_tenebris", "ascendant",
    ]
    glossary_rows = []
    for key in glossary_order:
        name = i18n.get(f"glossary.{key}.name", key)
        definition = i18n.get(f"glossary.{key}.def", "")
        glossary_rows.append([name, definition])
    story.append(_rule_table(copy["glossary_headers"], glossary_rows, [30 * mm, w - 30 * mm], styles))

    doc.build(story, onFirstPage=_rulebook_page, onLaterPages=_rulebook_page)


# ─── Main ──────────────────────────────────────────────────────────────────────

def main():
    OUT_DIR.mkdir(exist_ok=True)
    INDIVIDUAL_DIR.mkdir(exist_ok=True)

    print("[1/7] Parsing I18n.gd ...")
    i18n = parse_i18n("en")
    i18n_fr = parse_i18n("fr")
    print(f"    {len(i18n)} EN strings extracted")
    print(f"    {len(i18n_fr)} FR strings extracted")

    print("[2/7] Building card specs ...")
    specs: list[CardSpec] = []
    specs.extend(build_transgression_specs(i18n))
    specs.extend(build_liturgy_specs(i18n))
    specs.append(build_exorcism_spec(i18n))
    specs.append(build_reference_pulse_spec())
    specs.append(build_reference_actions_spec())
    print(f"    {len(specs)} physical cards (= {len(specs) * 2} faces)")

    print("[3/7] Rendering each face to PNG ...")
    card_pairs: list[tuple[Path, Path]] = []
    for spec in specs:
        ill = None
        if spec.illustration_path and spec.illustration_path.exists():
            try:
                ill = Image.open(spec.illustration_path).convert("RGB")
            except Exception as e:
                print(f"    illustration failed for {spec.card_id}: {e}")
        front_bg = None
        if spec.front_reference_art and spec.front_reference_art.exists():
            try:
                front_bg = Image.open(spec.front_reference_art).convert("RGB")
            except Exception as e:
                print(f"    reference art failed for {spec.card_id} A: {e}")
        back_bg = None
        if spec.back_reference_art and spec.back_reference_art.exists():
            try:
                back_bg = Image.open(spec.back_reference_art).convert("RGB")
            except Exception as e:
                print(f"    reference art failed for {spec.card_id} B: {e}")

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
                background=front_bg,
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
                background=back_bg,
                is_reference=spec.is_reference,
                compact_body=spec.is_reference,
            )
        front_path = INDIVIDUAL_DIR / f"{spec.card_id}_A.png"
        back_path = INDIVIDUAL_DIR / f"{spec.card_id}_B.png"
        front_img.save(front_path)
        back_img.save(back_path)
        card_pairs.append((front_path, back_path))
        print(f"    {spec.card_id} A+B")

    print("[4/7] Composing rulebooks A5 PDF ...")
    rulebook_fr_pdf = OUT_DIR / "possession_rulebook_fr.pdf"
    compose_rulebook_pdf(rulebook_fr_pdf, i18n_fr, "fr")
    print(f"    {rulebook_fr_pdf}")
    rulebook_en_pdf = OUT_DIR / "possession_rulebook_en.pdf"
    compose_rulebook_pdf(rulebook_en_pdf, i18n, "en")
    print(f"    {rulebook_en_pdf}")

    print("[5/7] Composing cards A4 PDF ...")
    cards_pdf = OUT_DIR / "possession_print_kit_en.pdf"
    compose_pdf(card_pairs, cards_pdf)
    print(f"    {cards_pdf}")

    print("[6/7] Composing board A3 PDF ...")
    board_pdf = OUT_DIR / "possession_board_a3.pdf"
    compose_board_pdf(board_pdf)
    print(f"    {board_pdf}")

    print("[7/7] Composing banners A4 PDF ...")
    banners_pdf = OUT_DIR / "possession_banners_a4.pdf"
    compose_banners_pdf(banners_pdf, i18n)
    print(f"    {banners_pdf}")

    print()
    print("Done. Five PDFs produced :")
    print(" - rulebooks : A5 French + English rulebooks, illustrated, with glossary,")
    print("               targeting, Missel Corrompu / Corrupted Missal and Codex")
    print("               des Transgressions references.")
    print(" - cards : print duplex (long-edge binding) on 200-250 g/m² cardstock,")
    print("           trim along the cut marks. Final card 65×91 mm.")
    print(" - board : print A3 landscape on heavy paper, trim to the cut marks.")
    print(" - banners : print A4 portrait, 2 columns x 6 rows, trim and")
    print("             pair adjacent (in_integro / impedita) for 5 double-sided")
    print("             station banners plus the single-sided Exorcism banner.")


if __name__ == "__main__":
    main()
