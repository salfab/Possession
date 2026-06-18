class_name DomainBadges
extends Control
# Tiny custom-drawn badges that replace the "◆R  ★  †" emoji-text the
# Domain label used to render. The Godot web build's bundled font misses
# glyphs from the Geometric Shapes / Misc Symbols blocks on some
# devices, so the indicators came out as tofu boxes. Drawing them as
# primitives sidesteps font support entirely.
#
# Layout : a single horizontal row with the three optional badges in
# this order, each ~16 px square :
#   • Controller : heraldic shield (pentagon) in the player's colour
#                  with a centred white letter "R" or "V" — distinct
#                  from the Infamie diamonds used on transgression chips
#   • Sealed     : padlock — filled square with an inverted-U shackle
#   • Penitence  : a + sign (cross) drawn from two thick rectangles

const BADGE_SIZE := 52.0
const BADGE_GAP  := 10.0

var controller_color: Color = Color(0, 0, 0, 0)  # alpha=0 means "no controller"
var controller_letter: String = ""
var is_sealed: bool = false
var is_in_penitence: bool = false
# Seal owner cue : a player-coloured padlock body + the same R/V letter
# the controller badge uses, so a colour-blind player can tell who
# placed the Seal even when it differs from the Domain's controller.
# Empty letter / default gold = no owner info (legacy callers).
var sealed_color: Color = Color(0.86, 0.72, 0.30)
var sealed_letter: String = ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, BADGE_SIZE)


func set_state(ctrl_color: Color, ctrl_letter: String, sealed: bool, penitence: bool,
		seal_color: Color = Color(0.86, 0.72, 0.30), seal_letter: String = "") -> void:
	if ctrl_color == controller_color and ctrl_letter == controller_letter \
			and sealed == is_sealed and penitence == is_in_penitence \
			and seal_color == sealed_color and seal_letter == sealed_letter:
		return
	controller_color = ctrl_color
	controller_letter = ctrl_letter
	is_sealed = sealed
	is_in_penitence = penitence
	sealed_color = seal_color
	sealed_letter = seal_letter
	# Recompute width so the parent container sizes correctly.
	var n := 0
	if controller_color.a > 0.0: n += 1
	if is_sealed: n += 1
	if is_in_penitence: n += 1
	var w: float = 0.0
	if n > 0:
		w = n * BADGE_SIZE + (n - 1) * BADGE_GAP
	custom_minimum_size = Vector2(w, BADGE_SIZE)
	queue_redraw()


func _draw() -> void:
	var x: float = 0.0
	var y: float = 0.0
	if controller_color.a > 0.0:
		_draw_controller(Vector2(x, y))
		x += BADGE_SIZE + BADGE_GAP
	if is_sealed:
		_draw_padlock(Vector2(x, y))
		x += BADGE_SIZE + BADGE_GAP
	if is_in_penitence:
		_draw_cross(Vector2(x, y))


func _draw_controller(top_left: Vector2) -> void:
	# Heraldic shield (pentagon : flat top, pointed bottom). Visually distinct
	# from the diamond shape used by Infamie transgression markers, and the
	# "control / defence of a domain" semantics fit the indicator's purpose.
	var bs := BADGE_SIZE
	var pts := PackedVector2Array([
		top_left + Vector2(bs * 0.12, bs * 0.15),
		top_left + Vector2(bs * 0.88, bs * 0.15),
		top_left + Vector2(bs * 0.92, bs * 0.55),
		top_left + Vector2(bs * 0.50, bs * 0.92),
		top_left + Vector2(bs * 0.08, bs * 0.55),
	])
	draw_colored_polygon(pts, controller_color)
	var loop := PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]])
	draw_polyline(loop, Color(0, 0, 0, 0.85), 1.5, true)
	# Center letter (R / V) in white with black outline for legibility.
	if controller_letter != "":
		var c := top_left + Vector2(bs * 0.5, bs * 0.5)
		var font := ThemeDB.fallback_font
		var font_size := int(bs * 0.55)
		var letter_size := font.get_string_size(controller_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var pos := c - Vector2(letter_size.x * 0.5, -font_size * 0.30)
		draw_string_outline(font, pos, controller_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color(0, 0, 0, 0.9))
		draw_string(font, pos, controller_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1))


func _draw_padlock(top_left: Vector2) -> void:
	# Body : tinted with the seal owner's player colour when known
	# (otherwise the legacy muted-gold default). Shackle : inverted U arc
	# at top in dark ink.
	var dark := Color(0, 0, 0, 0.85)
	# Backing disc so the padlock reads against busy board art and stands out
	# from the controller shield / penitence cross as the strong "sealed" cue.
	var center := top_left + Vector2(BADGE_SIZE * 0.5, BADGE_SIZE * 0.5)
	draw_circle(center, BADGE_SIZE * 0.52, Color(0, 0, 0, 0.45))
	var body_top: float = top_left.y + BADGE_SIZE * 0.42
	var body_h: float = BADGE_SIZE * 0.55
	var body_x: float = top_left.x + BADGE_SIZE * 0.18
	var body_w: float = BADGE_SIZE * 0.64
	var body := Rect2(body_x, body_top, body_w, body_h)
	draw_rect(body, sealed_color, true)
	draw_rect(body, dark, false, 1.5)
	# Shackle (the curved metal loop on top) — drawn as an arc.
	var shackle_center := Vector2(top_left.x + BADGE_SIZE * 0.5, body_top)
	var shackle_radius: float = BADGE_SIZE * 0.26
	draw_arc(shackle_center, shackle_radius, PI, TAU, 16, dark, 2.0, true)
	# Owner letter (R / V) inside the body — non-colour cue so
	# colour-blind players can still tell apart Red and Violet seals.
	if sealed_letter != "":
		var font := ThemeDB.fallback_font
		if font == null:
			return
		var fs: int = int(BADGE_SIZE * 0.36)
		var letter_size := font.get_string_size(sealed_letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var cx: float = body_x + body_w * 0.5
		var cy: float = body_top + body_h * 0.5
		var pos := Vector2(cx - letter_size.x * 0.5, cy + float(fs) * 0.30)
		draw_string_outline(font, pos, sealed_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(0, 0, 0, 0.9))
		draw_string(font, pos, sealed_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))


func _draw_cross(top_left: Vector2) -> void:
	# Two filled rectangles forming a "+" sign — symbolises Penitence.
	var col := Color(0.92, 0.86, 0.65)
	var dark := Color(0, 0, 0, 0.85)
	var thickness: float = BADGE_SIZE * 0.22
	var c := top_left + Vector2(BADGE_SIZE * 0.5, BADGE_SIZE * 0.5)
	var horiz := Rect2(top_left.x + BADGE_SIZE * 0.12, c.y - thickness * 0.5,
		BADGE_SIZE * 0.76, thickness)
	var vert := Rect2(c.x - thickness * 0.5, top_left.y + BADGE_SIZE * 0.12,
		thickness, BADGE_SIZE * 0.76)
	draw_rect(horiz, col, true)
	draw_rect(vert, col, true)
	draw_rect(horiz, dark, false, 1.0)
	draw_rect(vert, dark, false, 1.0)
