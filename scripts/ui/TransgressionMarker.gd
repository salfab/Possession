class_name TransgressionMarker
extends Control
# Small clickable token displayed on a Domain hotspot to indicate that a
# Transgression instance is sitting there.
#
# Visuals :
#   • Scandale → filled circle in the owner's colour, black outline
#   • Infamie  → filled diamond in the owner's colour, black outline
# Tap → emits `pressed`, which Main.gd uses to open the fullscreen card.

signal pressed

const DEFAULT_SIZE := 26.0

var marker_color: Color = Color.WHITE
var is_infamy: bool = false


func _init(color: Color = Color.WHITE, infamy: bool = false) -> void:
	marker_color = color
	is_infamy = infamy
	custom_minimum_size = Vector2(DEFAULT_SIZE, DEFAULT_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = ""


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.44
	if is_infamy:
		# Diamond — rotated square, points up/down/left/right.
		var pts := PackedVector2Array([
			c + Vector2(0, -r),
			c + Vector2(r, 0),
			c + Vector2(0, r),
			c + Vector2(-r, 0),
		])
		draw_colored_polygon(pts, marker_color)
		var loop := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
		draw_polyline(loop, Color(0, 0, 0, 0.85), 2.0, true)
	else:
		# Filled circle for Scandale.
		draw_circle(c, r, marker_color)
		draw_arc(c, r, 0.0, TAU, 32, Color(0, 0, 0, 0.85), 2.0, true)


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
