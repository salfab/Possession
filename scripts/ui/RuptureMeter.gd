class_name RuptureMeter
extends Control
# Soul-Rupture panel — the "best of both" view : per condition, a thematic
# drawn icon + the short name + a row of progress cells + a check when met,
# AND a small caption naming WHAT is being counted (so the player knows what
# feeds each objective, not just the count). All text drawn with the parchment
# font ; cells/icons drawn as primitives (no web "tofu", crisp at any DPI).
# Accessibility : met state cued by SHAPE (filled cells + check) AND colour.
#
# Fed once per refresh via set_rows() ; never redraws per frame.
#
# Row schema : {kind:String, name:String, desc:String, count:int, total:int, met:bool}
#   kind ∈ "profondeur" | "etendue" | "ancrage" → selects the leading glyph.
#   desc = what is counted (e.g. "Infamies — ou Foi/Volonté frappée").

const ICON := 26.0           # leading thematic glyph box
const ICON_GAP := 7.0
const NAME_W := 104.0        # parchment-font condition name column
const NAME_GAP := 7.0
const CELL := 20.0           # progress cell side
const CELL_GAP := 4.0
const CHECK_GAP := 8.0
const NAME_FS := 18          # condition name font size
const DESC_FS := 12          # caption ("what is counted") font size
const LINE1 := 26.0          # height of the name + cells line
const DESC_GAP := 2.0        # gap between name line and caption
const ROW_GAP := 9.0         # gap between conditions
const PAD := 4.0

const GOLD := Color(0.86, 0.72, 0.34)            # in-progress filled cell / glyph
const GOLD_DIM := Color(0.55, 0.46, 0.28, 0.80)  # empty cell outline / pending glyph
const GREEN := Color(0.55, 0.85, 0.50)           # met : cell + check + name + glyph
const INK := Color(0.04, 0.03, 0.02, 0.85)       # filled-cell hairline
const EMPTY_BG := Color(0, 0, 0, 0.28)
const TXT := Color(0.90, 0.84, 0.66)             # name, not-yet-met
const DESC_COL := Color(0.70, 0.63, 0.50)        # caption, dim parchment

# Parchment font (Card.FONT_BODY), set by Main so the text matches the rest of
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


func _total_width() -> float:
	var cells_w: float = _max_total() * CELL + maxf(0.0, _max_total() - 1) * CELL_GAP
	return PAD + ICON + ICON_GAP + NAME_W + NAME_GAP + cells_w + CHECK_GAP + CELL + PAD


func _desc_x() -> float:
	return PAD + ICON + ICON_GAP


func _desc_width() -> float:
	return _total_width() - _desc_x() - PAD


func _desc_height(f: Font, desc: String) -> float:
	if f == null or desc == "":
		return 0.0
	return f.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, _desc_width(), DESC_FS).y


func _update_min_size() -> void:
	var f: Font = name_font if name_font != null else ThemeDB.fallback_font
	var h := PAD
	for i in _rows.size():
		if i > 0:
			h += ROW_GAP
		h += LINE1 + DESC_GAP + _desc_height(f, String(_rows[i].get("desc", "")))
	h += PAD
	custom_minimum_size = Vector2(_total_width(), h)


func _draw() -> void:
	var f: Font = name_font if name_font != null else ThemeDB.fallback_font
	var y := PAD
	for r in _rows:
		var kind: String = String(r.get("kind", ""))
		var name_str: String = String(r.get("name", ""))
		var desc: String = String(r.get("desc", ""))
		var count: int = int(r.get("count", 0))
		var total: int = int(r.get("total", 0))
		var met: bool = bool(r.get("met", false))
		var accent: Color = GREEN if met else GOLD
		# Leading thematic glyph, centred on the name line.
		_draw_glyph(kind, Rect2(PAD, y + (LINE1 - ICON) * 0.5, ICON, ICON), accent)
		# Condition name (parchment font), green once met.
		if f != null:
			var baseline := Vector2(_desc_x(), y + LINE1 * 0.5 + NAME_FS * 0.34)
			draw_string(f, baseline, name_str, HORIZONTAL_ALIGNMENT_LEFT,
				NAME_W, NAME_FS, GREEN if met else TXT)
		# Progress cells. When met, every cell is shown filled (the condition
		# can be satisfied by its OR-shortcut before the numeric count fills).
		var shown: int = total if met else count
		var x := _desc_x() + NAME_W + NAME_GAP
		var cy := y + (LINE1 - CELL) * 0.5
		for i in total:
			_draw_cell(Rect2(x, cy, CELL, CELL), i < shown, met)
			x += CELL + CELL_GAP
		# Trailing check when satisfied — the authoritative cue.
		if met:
			_draw_check(Rect2(x + CHECK_GAP, cy, CELL, CELL))
		# Caption : what is counted, under the name.
		var dy := y + LINE1 + DESC_GAP
		if f != null and desc != "":
			draw_multiline_string(f, Vector2(_desc_x(), dy + DESC_FS * 0.9), desc,
				HORIZONTAL_ALIGNMENT_LEFT, _desc_width(), DESC_FS, -1, DESC_COL)
		y = dy + _desc_height(f, desc) + ROW_GAP


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
