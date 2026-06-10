class_name RuptureMeter
extends Control
# Soul-Rupture panel — the "best of both" view : per condition, a thematic
# drawn icon + the short name + a row of progress cells + a check when met.
# All drawn as primitives (no font glyphs / no SVG import → no web "tofu",
# crisp at any DPI). Accessibility : the met state is cued by SHAPE (filled
# cells + check) AND colour (green), not colour alone.
#
# Fed once per refresh via set_rows() ; never redraws per frame.
#
# Row schema : {kind:String, name:String, count:int, total:int, met:bool}
#   kind ∈ "profondeur" | "etendue" | "ancrage" → selects the leading glyph.

const ICON := 26.0           # leading thematic glyph box
const ICON_GAP := 7.0
const NAME_W := 104.0        # parchment-font condition name column
const NAME_GAP := 7.0
const CELL := 20.0           # progress cell side
const CELL_GAP := 4.0
const CHECK_GAP := 8.0
const ROW := 30.0            # row height
const ROW_GAP := 8.0
const FONT_SIZE := 18
const PAD := 4.0

const GOLD := Color(0.86, 0.72, 0.34)            # in-progress filled cell / glyph
const GOLD_DIM := Color(0.55, 0.46, 0.28, 0.80)  # empty cell outline / pending glyph
const GREEN := Color(0.55, 0.85, 0.50)           # met : cell + check + name + glyph
const INK := Color(0.04, 0.03, 0.02, 0.85)       # filled-cell hairline
const EMPTY_BG := Color(0, 0, 0, 0.28)
const TXT := Color(0.90, 0.84, 0.66)             # name, not-yet-met

# Parchment font (Card.FONT_BODY), set by Main so the names match the rest of
# the UI instead of Godot's default font. Falls back to the theme font.
var name_font: Font = null
var _rows: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_rows(rows: Array) -> void:
	_rows = rows
	_update_min_size()
	queue_redraw()


func _max_total() -> int:
	var m := 0
	for r in _rows:
		m = maxi(m, int(r.get("total", 0)))
	return m


func _update_min_size() -> void:
	var cells_w: float = _max_total() * CELL + maxf(0.0, _max_total() - 1) * CELL_GAP
	var w: float = PAD + ICON + ICON_GAP + NAME_W + NAME_GAP + cells_w + CHECK_GAP + CELL + PAD
	var n: int = _rows.size()
	var h: float = PAD + n * ROW + maxf(0.0, n - 1) * ROW_GAP + PAD
	custom_minimum_size = Vector2(w, h)


func _draw() -> void:
	var f: Font = name_font if name_font != null else ThemeDB.fallback_font
	var y := PAD
	for r in _rows:
		var kind: String = String(r.get("kind", ""))
		var name_str: String = String(r.get("name", ""))
		var count: int = int(r.get("count", 0))
		var total: int = int(r.get("total", 0))
		var met: bool = bool(r.get("met", false))
		var accent: Color = GREEN if met else GOLD
		# Leading thematic glyph.
		_draw_glyph(kind, Rect2(PAD, y + (ROW - ICON) * 0.5, ICON, ICON), accent)
		# Condition name (parchment font), green once met.
		if f != null:
			var bx := PAD + ICON + ICON_GAP
			var baseline := Vector2(bx, y + ROW * 0.5 + FONT_SIZE * 0.34)
			draw_string(f, baseline, name_str, HORIZONTAL_ALIGNMENT_LEFT,
				NAME_W, FONT_SIZE, GREEN if met else TXT)
		# Progress cells. When met, every cell is shown filled (the condition
		# can be satisfied by its OR-shortcut before the numeric count fills).
		var shown: int = total if met else count
		var x := PAD + ICON + ICON_GAP + NAME_W + NAME_GAP
		var cy := y + (ROW - CELL) * 0.5
		for i in total:
			_draw_cell(Rect2(x, cy, CELL, CELL), i < shown, met)
			x += CELL + CELL_GAP
		# Trailing check when satisfied — the authoritative cue.
		if met:
			_draw_check(Rect2(x + CHECK_GAP, cy, CELL, CELL))
		y += ROW + ROW_GAP


func _draw_cell(rect: Rect2, filled: bool, met: bool) -> void:
	if filled:
		draw_rect(rect, GREEN if met else GOLD, true)
		draw_rect(rect, INK, false, 1.0)
	else:
		draw_rect(rect, EMPTY_BG, true)
		draw_rect(rect, GOLD_DIM, false, 2.0)


func _draw_check(rect: Rect2) -> void:
	var o := rect.position
	var s := rect.size
	draw_line(o + Vector2(s.x * 0.16, s.y * 0.54), o + Vector2(s.x * 0.40, s.y * 0.80), GREEN, 3.0, true)
	draw_line(o + Vector2(s.x * 0.40, s.y * 0.80), o + Vector2(s.x * 0.86, s.y * 0.20), GREEN, 3.0, true)


# ─── Thematic glyphs (carried over from the icon prototype) ───────────────────

func _draw_glyph(kind: String, box: Rect2, col: Color) -> void:
	var c := box.position + box.size * 0.5
	var r: float = box.size.y * 0.5
	match kind:
		"profondeur": _glyph_depth(c, r, col)
		"etendue":    _glyph_spread(c, r, col)
		"ancrage":    _glyph_anchor(c, r, col)


# Three stacked strata narrowing as they descend — corruption sinking deep.
func _glyph_depth(c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var y := c.y - r * 0.55 + i * r * 0.55
		var w := r * (0.78 - i * 0.20)
		draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), col, 2.6, true)


# Four points spread around the centre — domains touched across the board.
func _glyph_spread(c: Vector2, r: float, col: Color) -> void:
	for off in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		draw_circle(c + off * r * 0.62, r * 0.20, col)


# A simple anchor — the "anchoring" of corruption via seals.
func _glyph_anchor(c: Vector2, r: float, col: Color) -> void:
	var top := c.y - r * 0.68
	draw_arc(Vector2(c.x, top + r * 0.18), r * 0.18, 0.0, TAU, 16, col, 2.2, true)
	draw_line(Vector2(c.x, top + r * 0.18), Vector2(c.x, c.y + r * 0.62), col, 2.6, true)
	draw_line(Vector2(c.x - r * 0.46, c.y - r * 0.10), Vector2(c.x + r * 0.46, c.y - r * 0.10), col, 2.6, true)
	draw_arc(Vector2(c.x, c.y + r * 0.12), r * 0.6, deg_to_rad(25.0), deg_to_rad(155.0), 18, col, 2.6, true)
