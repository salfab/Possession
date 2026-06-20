class_name AscendantPawn
extends Control
# Board-track pawn for the demonic Ascendant. Uses the illustrated marker asset
# when rendering is available, with the old procedural sigil kept as a safe
# fallback for headless tests or a missing import.

const DEFAULT_SIZE := Vector2(42, 52)
const TEXTURE_PATH := "res://assets/ui/markers/ascendant.png"

var value: int = 0
var pawn_color: Color = Color(0.92, 0.72, 0.30)
var _pawn_texture: Texture2D = null


func _init() -> void:
	custom_minimum_size = DEFAULT_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pawn_texture = _load_pawn_texture()


func set_value(v: int) -> void:
	if v == value:
		return
	value = v
	if value > 0:
		pawn_color = GameEnums.player_color_light(GameEnums.PlayerId.RED)
	elif value < 0:
		pawn_color = GameEnums.player_color_light(GameEnums.PlayerId.PURPLE)
	else:
		pawn_color = Color(0.92, 0.72, 0.30)
	queue_redraw()


func _draw() -> void:
	if _pawn_texture != null:
		_draw_asset_pawn()
		return
	_draw_fallback_pawn()


func _load_pawn_texture() -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var tex := load(TEXTURE_PATH)
	return tex if tex is Texture2D else null


func _draw_asset_pawn() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.48)
	var r := minf(size.x, size.y) * 0.47
	var glow := Color(pawn_color.r, pawn_color.g, pawn_color.b, 0.52)
	# The glow carries the current leading demon's colour while the neutral
	# black-and-gold artwork remains legible over the detailed board painting.
	draw_circle(c, r * 1.08, Color(0, 0, 0, 0.72))
	draw_circle(c, r, glow)
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_pawn_texture, rect, false, Color.WHITE)
	draw_texture_rect(_pawn_texture, rect, false,
		Color(pawn_color.r, pawn_color.g, pawn_color.b, 0.16))


func _draw_fallback_pawn() -> void:
	var w := size.x
	var h := size.y
	var c := Vector2(w * 0.5, h * 0.43)
	var outer := PackedVector2Array([
		Vector2(w * 0.50, h * 0.02),
		Vector2(w * 0.78, h * 0.18),
		Vector2(w * 0.90, h * 0.47),
		Vector2(w * 0.67, h * 0.70),
		Vector2(w * 0.50, h * 0.98),
		Vector2(w * 0.33, h * 0.70),
		Vector2(w * 0.10, h * 0.47),
		Vector2(w * 0.22, h * 0.18),
	])
	var rim := PackedVector2Array([
		Vector2(w * 0.50, h * 0.09),
		Vector2(w * 0.71, h * 0.22),
		Vector2(w * 0.80, h * 0.45),
		Vector2(w * 0.61, h * 0.65),
		Vector2(w * 0.50, h * 0.84),
		Vector2(w * 0.39, h * 0.65),
		Vector2(w * 0.20, h * 0.45),
		Vector2(w * 0.29, h * 0.22),
	])
	var fill := PackedVector2Array([
		Vector2(w * 0.50, h * 0.16),
		Vector2(w * 0.64, h * 0.26),
		Vector2(w * 0.71, h * 0.43),
		Vector2(w * 0.57, h * 0.58),
		Vector2(w * 0.50, h * 0.72),
		Vector2(w * 0.43, h * 0.58),
		Vector2(w * 0.29, h * 0.43),
		Vector2(w * 0.36, h * 0.26),
	])

	draw_colored_polygon(outer, Color(0, 0, 0, 0.92))
	draw_colored_polygon(rim, Color(0.95, 0.72, 0.30, 0.96))
	draw_colored_polygon(fill, pawn_color)

	# Large, non-text sigil: readable in grayscale and does not depend on font.
	draw_line(c + Vector2(0, -h * 0.20), c + Vector2(0, h * 0.16), Color(0, 0, 0, 0.74), 3.0, true)
	draw_line(c + Vector2(-w * 0.16, h * 0.08), c + Vector2(w * 0.16, h * 0.08), Color(0, 0, 0, 0.70), 2.4, true)
	draw_arc(c, minf(w, h) * 0.20, PI * 0.18, PI * 0.82, 14, Color(1, 0.92, 0.68, 0.55), 1.2, true)
