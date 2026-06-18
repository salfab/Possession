class_name TransgressionMarker
extends Control
# Small clickable token displayed on a Domain hotspot to indicate that a
# Transgression instance is sitting there.
#
# Visuals :
#   • Scandale → simple circular cracked-seal shape, tinted by owner colour
#   • Infamie  → simple diamond sigil shape, tinted by owner colour
# Tap → emits `pressed`, which Main.gd uses to open the fullscreen card.

signal pressed

const DEFAULT_SIZE := 52.0
const TEX_SCANDALE_PATH := "res://assets/ui/markers/transgression_scandale.png"
const TEX_INFAMIE_PATH := "res://assets/ui/markers/transgression_infamie.png"
const USE_TEXTURE_MARKERS := false

var marker_color: Color = Color.WHITE
var is_infamy: bool = false
var _marker_texture: Texture2D = null


func _init(color: Color = Color.WHITE, infamy: bool = false) -> void:
	marker_color = color
	is_infamy = infamy
	_marker_texture = _load_marker_texture()
	custom_minimum_size = Vector2(DEFAULT_SIZE, DEFAULT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.44
	if _marker_texture != null:
		_draw_asset_marker(c, r)
		return

	_draw_fallback_marker(c, r)


func _load_marker_texture() -> Texture2D:
	if not USE_TEXTURE_MARKERS:
		return null
	if DisplayServer.get_name() == "headless":
		return null
	var path := TEX_INFAMIE_PATH if is_infamy else TEX_SCANDALE_PATH
	var tex := load(path)
	return tex if tex is Texture2D else null


func _draw_asset_marker(c: Vector2, r: float) -> void:
	var owner_glow := Color(marker_color.r, marker_color.g, marker_color.b, 0.42)
	if is_infamy:
		var pts := PackedVector2Array([
			c + Vector2(0, -r * 1.16),
			c + Vector2(r * 1.16, 0),
			c + Vector2(0, r * 1.16),
			c + Vector2(-r * 1.16, 0),
		])
		var outline := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_colored_polygon(pts, owner_glow)
		draw_polyline(outline, Color(0, 0, 0, 0.92), 3.0, true)
		draw_polyline(outline, Color(0.95, 0.72, 0.30, 0.90), 1.4, true)
	else:
		draw_circle(c, r * 1.18, Color(0, 0, 0, 0.92))
		draw_circle(c, r * 1.10, owner_glow)
		draw_arc(c, r * 1.07, 0.0, TAU, 36, Color(0.95, 0.72, 0.30, 0.90), 1.4, true)

	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_marker_texture, rect, false, marker_color)
	draw_texture_rect(_marker_texture, rect, false, Color(1, 0.93, 0.70, 0.16))


func _draw_fallback_marker(c: Vector2, r: float) -> void:
	if is_infamy:
		# Infamie: permanent diamond sigil, owner-tinted and readable at chip size.
		var pts := PackedVector2Array([
			c + Vector2(0, -r * 1.12),
			c + Vector2(r * 1.12, 0),
			c + Vector2(0, r * 1.12),
			c + Vector2(-r * 1.12, 0),
		])
		var loop := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_colored_polygon(pts, Color(0, 0, 0, 0.92))
		var fill := PackedVector2Array([
			c + Vector2(0, -r * 0.92),
			c + Vector2(r * 0.92, 0),
			c + Vector2(0, r * 0.92),
			c + Vector2(-r * 0.92, 0),
		])
		draw_colored_polygon(fill, marker_color)
		draw_polyline(loop, Color(0, 0, 0, 0.95), 2.6, true)
		draw_polyline(loop, Color(0.95, 0.72, 0.30, 0.95), 1.2, true)
		var inner := PackedVector2Array([
			c + Vector2(0, -r * 0.52),
			c + Vector2(r * 0.46, 0),
			c + Vector2(0, r * 0.52),
			c + Vector2(-r * 0.46, 0),
			c + Vector2(0, -r * 0.52),
		])
		draw_polyline(inner, Color(0, 0, 0, 0.62), 2.0, true)
		draw_line(c + Vector2(0, -r * 0.47), c + Vector2(0, r * 0.47), Color(0, 0, 0, 0.72), 2.2, true)
	else:
		# Scandale: broken public seal, owner-tinted.
		draw_circle(c, r * 1.13, Color(0, 0, 0, 0.92))
		draw_circle(c, r, marker_color)
		draw_arc(c, r * 0.98, 0.0, TAU, 32, Color(0.95, 0.72, 0.30, 0.95), 1.4, true)
		draw_line(c + Vector2(-r * 0.46, -r * 0.55), c + Vector2(r * 0.42, r * 0.38), Color(0, 0, 0, 0.74), 2.4, true)
		draw_line(c + Vector2(r * 0.54, -r * 0.34), c + Vector2(-r * 0.08, r * 0.06), Color(0, 0, 0, 0.62), 2.0, true)
		draw_line(c + Vector2(0, -r * 0.46), c + Vector2(0, r * 0.48), Color(0, 0, 0, 0.72), 2.4, true)
		draw_line(c + Vector2(-r * 0.31, r * 0.24), c + Vector2(r * 0.31, r * 0.24), Color(0, 0, 0, 0.72), 2.4, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			pressed.emit()
			accept_event()
