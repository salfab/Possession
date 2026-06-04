class_name CorruptionDots
extends Control
# Tiny visual badge that draws a row of corruption tokens per player to show
# how much Corruption each demon has placed on a Domain. The token is a simple
# flame/drop shape tinted with the owning demon's colour. Both players' tokens
# share the same row, separated by a small gap.

const DOT_SIZE := 14.0
const DOT_GAP := 2.0
const GROUP_GAP := 6.0
const TEX_CORRUPTION_PATH := "res://assets/ui/markers/corruption.png"
const USE_TEXTURE_MARKERS := false

var red_count: int = 0
var blue_count: int = 0
var _corruption_texture: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, DOT_SIZE)
	_corruption_texture = _load_corruption_texture()


func set_counts(r: int, b: int) -> void:
	if r == red_count and b == blue_count:
		return
	red_count = r
	blue_count = b
	# Recalculate width so the parent container can size us correctly.
	var total := r + b
	var w := total * DOT_SIZE + maxi(total - 1, 0) * DOT_GAP
	if r > 0 and b > 0:
		w += GROUP_GAP - DOT_GAP
	custom_minimum_size = Vector2(w, DOT_SIZE)
	queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	var y: float = (size.y - DOT_SIZE) * 0.5
	var red: Color = GameEnums.PLAYER_COLORS[GameEnums.PlayerId.RED]
	var blue: Color = GameEnums.PLAYER_COLORS[GameEnums.PlayerId.PURPLE]
	for i in red_count:
		var rect := Rect2(x, y, DOT_SIZE, DOT_SIZE)
		_draw_corruption_token(rect, red)
		x += DOT_SIZE + DOT_GAP
	if red_count > 0 and blue_count > 0:
		x += GROUP_GAP - DOT_GAP
	for i in blue_count:
		var rect := Rect2(x, y, DOT_SIZE, DOT_SIZE)
		_draw_corruption_token(rect, blue)
		x += DOT_SIZE + DOT_GAP


func _load_corruption_texture() -> Texture2D:
	if not USE_TEXTURE_MARKERS:
		return null
	if DisplayServer.get_name() == "headless":
		return null
	var tex := load(TEX_CORRUPTION_PATH)
	return tex if tex is Texture2D else null


func _draw_corruption_token(rect: Rect2, player_color: Color) -> void:
	if _corruption_texture == null:
		_draw_corruption_flame(rect, player_color)
		return

	var c := rect.get_center()
	var glow := Color(player_color.r, player_color.g, player_color.b, 0.65)
	draw_circle(c, DOT_SIZE * 0.50, Color(0, 0, 0, 0.88))
	draw_circle(c, DOT_SIZE * 0.43, glow)
	draw_texture_rect(_corruption_texture, rect, false, player_color)
	draw_texture_rect(_corruption_texture, rect, false, Color(1, 0.92, 0.68, 0.18))


func _draw_corruption_flame(rect: Rect2, player_color: Color) -> void:
	var c := rect.get_center()
	var s := minf(rect.size.x, rect.size.y)
	var outline := PackedVector2Array([
		c + Vector2(0.00, -0.58) * s,
		c + Vector2(0.34, -0.18) * s,
		c + Vector2(0.42, 0.24) * s,
		c + Vector2(0.00, 0.58) * s,
		c + Vector2(-0.42, 0.24) * s,
		c + Vector2(-0.28, -0.18) * s,
	])
	var fill := PackedVector2Array([
		c + Vector2(0.00, -0.43) * s,
		c + Vector2(0.26, -0.12) * s,
		c + Vector2(0.31, 0.20) * s,
		c + Vector2(0.00, 0.43) * s,
		c + Vector2(-0.31, 0.20) * s,
		c + Vector2(-0.21, -0.12) * s,
	])
	draw_colored_polygon(outline, Color(0, 0, 0, 0.90))
	draw_colored_polygon(fill, player_color)
	draw_polyline(PackedVector2Array([outline[0], outline[1], outline[2], outline[3], outline[4], outline[5], outline[0]]),
		Color(0.95, 0.72, 0.30, 0.82), 1.0, true)
