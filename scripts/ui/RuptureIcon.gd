class_name RuptureIcon
extends Control
# Small custom-drawn vector glyph for one Soul-Rupture condition, shown in the
# bottom-left rupture panel. Drawn (not a font glyph / SVG) so it stays crisp
# at any size and needs no asset import — same approach as ActionEffect /
# PenitenceArch.
#
# State is conveyed by SHAPE as well as colour (accessibility rule) :
#   • met     → filled gold disc with a dark glyph,
#   • pending → hollow dim ring with a dim glyph.
#
# kinds : "profondeur" (descending strata), "etendue" (four spread domains),
#         "ancrage" (an anchor).

const SIZE := 34.0
const GOLD := Color(0.95, 0.80, 0.40)
const DIM := Color(0.56, 0.48, 0.34)
const INK := Color(0.10, 0.06, 0.02)

var kind: String = "profondeur"
var met: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(k: String, m: bool) -> void:
	kind = k
	met = m
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	var glyph: Color
	if met:
		draw_circle(c, radius, GOLD)                 # filled gold disc
		glyph = INK
	else:
		draw_arc(c, radius, 0.0, TAU, 40, DIM, 2.0, true)  # hollow ring
		glyph = DIM
	match kind:
		"profondeur": _draw_depth(c, radius, glyph)
		"etendue":    _draw_spread(c, radius, glyph)
		"ancrage":    _draw_anchor(c, radius, glyph)


# Three stacked strata narrowing as they descend — corruption sinking deep.
func _draw_depth(c: Vector2, r: float, col: Color) -> void:
	for i in 3:
		var y := c.y - r * 0.42 + i * r * 0.42
		var w := r * (0.62 - i * 0.16)
		draw_line(Vector2(c.x - w, y), Vector2(c.x + w, y), col, 2.6, true)


# Four points spread around the centre — domains touched across the board.
func _draw_spread(c: Vector2, r: float, col: Color) -> void:
	for off in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
		draw_circle(c + off * r * 0.52, r * 0.15, col)


# A simple anchor — the "anchoring" of the corruption via seals.
func _draw_anchor(c: Vector2, r: float, col: Color) -> void:
	var top := c.y - r * 0.55
	# Top ring.
	draw_arc(Vector2(c.x, top + r * 0.16), r * 0.16, 0.0, TAU, 16, col, 2.4, true)
	# Shank.
	draw_line(Vector2(c.x, top + r * 0.16), Vector2(c.x, c.y + r * 0.5), col, 2.6, true)
	# Crossbar.
	draw_line(Vector2(c.x - r * 0.38, c.y - r * 0.18), Vector2(c.x + r * 0.38, c.y - r * 0.18), col, 2.6, true)
	# Bottom flukes (arc).
	draw_arc(Vector2(c.x, c.y), r * 0.5, deg_to_rad(25.0), deg_to_rad(155.0), 18, col, 2.6, true)
