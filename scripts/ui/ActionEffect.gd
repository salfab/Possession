class_name ActionEffect
extends Control
# Transient, self-animating overlay that plays a short per-action visual
# signature at a board position, then frees itself. Lives full-board inside
# the ZoomLayer (anchored 0..1) like PenitenceArch, so it follows zoom / pan
# and draws at `center * size`. Pure _draw + one tween ; ignores input, never
# blocks taps. Spawned by Main._spawn_action_effect() for both human and bot
# moves (same _animate_action_feedback dispatch).
#
# `kind` selects the drawn signature ; `color` is usually the acting player's
# colour (gold for Seal, bone for Crack, dusk for Puiser). `progress` 0→1 is
# driven by play()'s tween ; effects expand and fade as it rises.

var center: Vector2 = Vector2(0.5, 0.5)   # normalised board position
var color: Color = Color.WHITE
var kind: String = "place"
var _progress: float = 0.0:
	set(v):
		_progress = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func play(duration: float = 0.55) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_progress", 1.0, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)


func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var c := Vector2(center.x * sz.x, center.y * sz.y)
	var base := sz.y * 0.055
	match kind:
		"place":   _draw_place(c, base)
		"exploit": _draw_exploit(c, base)
		"seal":    _draw_seal(c, base)
		"crack":   _draw_crack(c, base)
		"spike":   _draw_spike(c, base)
		"amplify": _draw_amplify(c, base)
		"hinder":  _draw_hinder(c, base)
		"shadow":  _draw_shadow(c, base)
		_:         _draw_place(c, base)


# Alpha that fades out as the effect plays.
func _fade(a0: float) -> float:
	return a0 * (1.0 - _progress)


func _ring(c: Vector2, r: float, a: float, w: float) -> void:
	if r <= 0.0 or a <= 0.0:
		return
	draw_arc(c, r, 0.0, TAU, 48, Color(color.r, color.g, color.b, a), w, true)


# INVESTIR — corruption posée : two rings bloom outward + 6 dots radiate.
func _draw_place(c: Vector2, base: float) -> void:
	var r := base * (0.5 + _progress * 1.6)
	_ring(c, r, _fade(0.9), 3.0)
	_ring(c, r * 0.6, _fade(0.6), 2.0)
	var dotr := base * (0.25 + _progress * 1.3)
	for i in 6:
		var ang := TAU * i / 6.0
		var p := c + Vector2(cos(ang), sin(ang)) * dotr
		draw_circle(p, base * 0.12 * (1.0 - _progress), Color(color.r, color.g, color.b, _fade(1.0)))


# EXPLOITER — converging ring + dots pulled inward (extraction).
func _draw_exploit(c: Vector2, base: float) -> void:
	var r := base * (1.6 - _progress * 1.1)
	_ring(c, r, _fade(0.9), 3.0)
	var dotr: float = maxf(0.0, base * (1.4 - _progress * 1.2))
	for i in 6:
		var ang := TAU * i / 6.0 + PI / 6.0
		var p := c + Vector2(cos(ang), sin(ang)) * dotr
		draw_circle(p, base * 0.10, Color(color.r, color.g, color.b, _fade(1.0)))


# SCELLER — a gold arc sweeps shut into a full ring + inner disc fades in.
func _draw_seal(c: Vector2, base: float) -> void:
	var r := base * 1.3
	var end_ang := -PI / 2.0 + TAU * clampf(_progress * 1.2, 0.0, 1.0)
	draw_arc(c, r, -PI / 2.0, end_ang, 48, Color(color.r, color.g, color.b, 0.95 * (1.0 - _progress * 0.3)), 4.0, true)
	draw_circle(c, r * 0.5 * _progress, Color(color.r, color.g, color.b, _fade(0.45)))


# FISSURER — jagged shards radiate outward (the seal breaking).
func _draw_crack(c: Vector2, base: float) -> void:
	var a := _fade(0.95)
	var ln := base * (0.6 + _progress * 1.6)
	for i in 5:
		var ang := TAU * i / 5.0 + 0.3
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var p1 := c + dir * base * 0.2
		var mid := c + dir * ln * 0.55 + perp * base * 0.18
		var p2 := c + dir * ln
		draw_polyline(PackedVector2Array([p1, mid, p2]), Color(color.r, color.g, color.b, a), 2.5, true)


# PROVOQUER — a burst of triangular spikes.
func _draw_spike(c: Vector2, base: float) -> void:
	var a := _fade(0.95)
	var ln := base * (0.5 + _progress * 1.7)
	for i in 8:
		var ang := TAU * i / 8.0
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var tip := c + dir * ln
		var b1 := c + dir * base * 0.3 + perp * base * 0.12
		var b2 := c + dir * base * 0.3 - perp * base * 0.12
		draw_colored_polygon(PackedVector2Array([tip, b1, b2]), Color(color.r, color.g, color.b, a))


# AMPLIFIER — two out-of-phase echo rings (intensifying).
func _draw_amplify(c: Vector2, base: float) -> void:
	_ring(c, base * (0.4 + _progress * 1.5), (1.0 - _progress) * 0.9, 3.0)
	var p2 := fmod(_progress + 0.5, 1.0)
	_ring(c, base * (0.4 + p2 * 1.5), (1.0 - p2) * 0.7, 2.0)


# ENTRAVER — a horizontal strike bar across the banner + a small X.
func _draw_hinder(c: Vector2, base: float) -> void:
	var a := _fade(0.95)
	var w := base * 2.2 * clampf(_progress * 1.5, 0.0, 1.0)
	draw_line(c - Vector2(w, 0.0), c + Vector2(w, 0.0), Color(color.r, color.g, color.b, a), 4.0, true)
	var s := base * 0.5
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Color(color.r, color.g, color.b, a), 3.0, true)
	draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Color(color.r, color.g, color.b, a), 3.0, true)


# PUISER — dark wisps rising from the bottom (drawing from the Shadow).
func _draw_shadow(c: Vector2, base: float) -> void:
	var a := _fade(0.9)
	for i in 4:
		var off := (i - 1.5) * base * 0.35
		var x := c.x + off
		var y0 := c.y + base * 0.6
		var y1 := c.y - base * (0.4 + _progress * 1.6)
		var sway := sin(_progress * PI + i) * base * 0.2
		draw_line(Vector2(x, y0), Vector2(x + sway, y1), Color(color.r, color.g, color.b, a), 3.0, true)
