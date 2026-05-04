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

from PIL import Image, ImageDraw, ImageFont
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas as pdfcanvas
from reportlab.lib.utils import ImageReader


# ─── Paths ──────────────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS = REPO_ROOT / "assets"
FONTS_DIR = ASSETS / "fonts"
ILLUSTRATIONS_DIR = ASSETS / "cards" / "illustrations"
SPECIAL_DIR = ASSETS / "cards" / "special"
I18N_GD = REPO_ROOT / "scripts" / "data" / "I18n.gd"
OUT_DIR = REPO_ROOT / "print"
INDIVIDUAL_DIR = OUT_DIR / "cards_individual"


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
    is_reference: bool = False


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


# ─── Per-face card render ──────────────────────────────────────────────────────

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
                ("Required Domain", domain_label.replace(" ▸ ", " or ")),
                ("Scandal effect", scandal_text),
            ],
            back_body=[
                ("Required Domain", domain_label.replace(" ▸ ", " or ")),
                ("Infamy effect", infamy_text),
            ],
            illustration_path=ill_path if ill_path.exists() else None,
        ))
    return out


def build_liturgy_specs(i18n: dict[str, str]) -> list[CardSpec]:
    out: list[CardSpec] = []
    for idx, (rid, station_name) in enumerate(LITURGY_CATALOG, start=1):
        name = i18n.get(f"liturgy.{rid}.name", rid)
        in_int = i18n.get(f"liturgy.{rid}.in_integro", "")
        impedita = i18n.get(f"liturgy.{rid}.impedita", "")
        target = i18n.get(f"liturgy.targeting.{rid}", "")

        out.append(CardSpec(
            card_id=f"liturgy_{rid}",
            title=name,
            subtitle=station_name,
            # "Liturgy" alone (was "Liturgical Response") so the ribbon
            # text "Liturgy — In Integro" / "Liturgy — Impedita" fits
            # comfortably within the inset ribbon width.
            domain_label="Liturgy",
            front_face="In Integro",
            back_face="Impedita",
            front_cost=None,
            back_cost=None,
            front_body=[
                ("Targeting", target),
                ("In Integro effect", in_int),
            ],
            back_body=[
                ("Targeting", target),
                ("Impedita effect", impedita),
                ("Reminder", "Hindering a Liturgy costs Corruption from the active demon."),
            ],
        ))
    return out


def build_exorcism_spec(i18n: dict[str, str]) -> CardSpec:
    back_text = i18n.get("liturgy.exorcisme.back", "")
    return CardSpec(
        card_id="exorcism_final",
        title="Final Exorcism",
        subtitle="VI — Exorcism",
        domain_label="Endgame",
        front_face="Final Card",
        back_face="Resolution Rules",
        front_cost=None,
        back_cost=None,
        front_body=[
            ("Trigger", "Reached when Station VI begins. The Liturgical Response cannot be Hindered."),
            ("Resolution", "The game ends — outcome is determined from the board state at this moment."),
        ],
        back_body=[
            ("Endgame rules", back_text),
        ],
        illustration_path=SPECIAL_DIR / "exorcisme_final.jpg",
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

    def draw_card(image_path: Path, col: int, row: int):
        x = margin_x + col * cw_mm
        # ReportLab origin is bottom-left, so rows count from the top.
        y = page_h - margin_y - (row + 1) * ch_mm
        c.drawImage(ImageReader(str(image_path)), x, y, width=cw_mm, height=ch_mm,
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

    print("[4/4] Composing A4 PDF ...")
    pdf_path = OUT_DIR / "possession_print_kit_en.pdf"
    compose_pdf(card_pairs, pdf_path)
    print(f"    {pdf_path}")

    print()
    print("Done. Open the PDF, print duplex (long-edge binding) on 200-250 g/m² cardstock,")
    print("then trim along the cut marks. Card backs land mirrored for double-sided alignment.")


if __name__ == "__main__":
    main()
