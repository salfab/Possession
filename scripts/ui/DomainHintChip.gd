class_name DomainHintChip
extends Control
# Always-visible per-domain yield hint, drawn as a custom pill so it does not
# depend on web-font glyph coverage (same rationale as DomainBadges — the web
# build's bundled font misses some symbol glyphs on certain devices). Content
# is STATIC : set once at board build via set_domain(), never refreshed per
# frame. Re-call set_domain() on locale change to pick up FR/EN.

const PAD_X := 9.0
const PAD_Y := 3.0
const FONT_SIZE := 16
const GOLD := Color(0.79, 0.63, 0.29)      # producing domains
const VIOLET := Color(0.69, 0.42, 0.81)    # Volonté / victory
const INK := Color(0.10, 0.07, 0.03)       # text on the pill
const STAR_GAP := 5.0

var _label: String = ""
var _is_victory: bool = false
var _fill: Color = GOLD
var _style: StyleBoxFlat

func _init() -> void:
	# The chip never eats taps — the domain hotspot underneath must stay
	# tappable to open the action menu.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_domain(d: int) -> void:
	_label = DomainData.chip_label(d)
	_is_victory = DomainData.is_victory_domain(d)
	_fill = VIOLET if _is_victory else GOLD
	_style = StyleBoxFlat.new()
	_style.bg_color = _fill
	_style.set_corner_radius_all(int(FONT_SIZE * 0.6))
	_style.border_color = Color(0.04, 0.02, 0.01, 0.85)
	_style.set_border_width_all(1)
	_update_min_size()
	queue_redraw()

func _star_size() -> float:
	return float(FONT_SIZE) if _is_victory else 0.0

func _update_min_size() -> void:
	var f := ThemeDB.fallback_font
	if f == null:
		# Font not ready yet (early in the scene lifecycle) — fall back to a
		# height-only minimum; queue_redraw() in set_domain() will repaint once
		# a real layout pass runs.
		custom_minimum_size = Vector2(0, FONT_SIZE + PAD_Y * 2.0)
		return
	var ts := f.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var star_w := (_star_size() + STAR_GAP) if _is_victory else 0.0
	custom_minimum_size = Vector2(ts.x + star_w + PAD_X * 2.0, FONT_SIZE + PAD_Y * 2.0)

func _draw() -> void:
	if _style == null:
		return
	var sz := size
	draw_style_box(_style, Rect2(Vector2.ZERO, sz))
	var f := ThemeDB.fallback_font
	if f == null:
		return
	var x := PAD_X
	var cy := sz.y * 0.5
	if _is_victory:
		_draw_star(Vector2(x + _star_size() * 0.5, cy), _star_size() * 0.5)
		x += _star_size() + STAR_GAP
	# Baseline approximation mirrors DomainBadges' draw_string usage.
	draw_string(f, Vector2(x, cy + FONT_SIZE * 0.35), _label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)

func _draw_star(c: Vector2, r: float) -> void:
	# Five-pointed star as a 10-vertex polygon (drawn, not a ★ glyph, to dodge
	# missing-glyph tofu on the web build).
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, INK)
