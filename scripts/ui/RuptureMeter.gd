class_name RuptureMeter
extends Control
# Synthetic checkbox view of the three Soul-Rupture conditions. Each condition
# is a row : short name + N cells filled by progress + a drawn check when the
# condition is met. Drawn as primitives (no font glyphs → no web-build "tofu",
# no SVG import) in the game's muted palette, so it blends with the board and
# stays crisp at any size / DPI. Accessibility : shape AND colour both cue the
# met state (filled+green+check vs outlined+gold).
#
# Fed once per refresh via set_rows() — never redraws per frame.

const CELL := 24.0           # cell side, px
const CELL_GAP := 5.0
const ROW_GAP := 9.0
const NAME_W := 132.0        # left column reserved for the condition name
const CHECK_GAP := 8.0       # space before the trailing "met" check
const FONT_SIZE := 19
const PAD := 4.0

const GOLD := Color(0.82, 0.68, 0.32)         # in-progress filled cell
const GOLD_DIM := Color(0.55, 0.46, 0.28, 0.75)  # empty cell outline
const GREEN := Color(0.55, 0.85, 0.50)        # met : filled cell + check + name
const INK := Color(0.04, 0.03, 0.02, 0.85)    # filled-cell hairline
const EMPTY_BG := Color(0, 0, 0, 0.28)
const TXT := Color(0.90, 0.84, 0.66)          # name, not-yet-met

# Array of {name:String, count:int, total:int, met:bool}, in display order.
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
	var w: float = PAD + NAME_W + cells_w + CHECK_GAP + CELL + PAD
	var n: int = _rows.size()
	var h: float = PAD + n * CELL + maxf(0.0, n - 1) * ROW_GAP + PAD
	custom_minimum_size = Vector2(w, h)


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var y := PAD
	for r in _rows:
		var name_str: String = String(r.get("name", ""))
		var count: int = int(r.get("count", 0))
		var total: int = int(r.get("total", 0))
		var met: bool = bool(r.get("met", false))
		# Condition name (green once met, parchment otherwise).
		if f != null:
			var baseline := Vector2(PAD, y + CELL * 0.5 + FONT_SIZE * 0.34)
			draw_string(f, baseline, name_str, HORIZONTAL_ALIGNMENT_LEFT,
				NAME_W - 4.0, FONT_SIZE, GREEN if met else TXT)
		# Cells. When met, show every cell filled (the condition can be met by
		# its OR-shortcut before the numeric count fills) ; otherwise fill the
		# live progress count.
		var shown: int = total if met else count
		var x := PAD + NAME_W
		for i in total:
			_draw_cell(Rect2(x, y, CELL, CELL), i < shown, met)
			x += CELL + CELL_GAP
		# Trailing check when the condition is satisfied — the authoritative cue.
		if met:
			_draw_check(Rect2(x + CHECK_GAP, y, CELL, CELL))
		y += CELL + ROW_GAP


func _draw_cell(rect: Rect2, filled: bool, met: bool) -> void:
	if filled:
		draw_rect(rect, GREEN if met else GOLD, true)
		draw_rect(rect, INK, false, 1.0)
	else:
		draw_rect(rect, EMPTY_BG, true)
		draw_rect(rect, GOLD_DIM, false, 2.0)


func _draw_check(rect: Rect2) -> void:
	# Two-stroke check mark, drawn (not a glyph).
	var o := rect.position
	var s := rect.size
	var p1 := o + Vector2(s.x * 0.16, s.y * 0.54)
	var p2 := o + Vector2(s.x * 0.40, s.y * 0.80)
	var p3 := o + Vector2(s.x * 0.86, s.y * 0.20)
	draw_line(p1, p2, GREEN, 3.0, true)
	draw_line(p2, p3, GREEN, 3.0, true)
