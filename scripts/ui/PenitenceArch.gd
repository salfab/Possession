class_name PenitenceArch
extends Control
# Custom-drawn golden arch outline that frames a Domain niche while that
# Domain is in Penitence. One PenitenceArch instance covers the whole board
# (anchored 0..1 inside the ZoomLayer, exactly like the hotspots) and draws
# every visible arch in its own _draw(), converting normalised board
# coordinates → local pixels via its current size. Because it lives in the
# ZoomLayer alongside the hotspots, it follows zoom / pan / resize for free.
#
# An arch is a rectangle whose top edge is replaced by an ogival / rounded
# arc rising to an apex. It is drawn as a stroked polyline (no opaque fill)
# so the niche artwork stays visible behind it. Accessibility : the golden
# colour is paired with a non-colour cue — a small "+" keystone glyph at the
# apex — so the marker reads even without colour perception.
#
# Parameter schema (one entry per DomainId, normalised 0..1 board coords) :
#   cx  : centre x of the arch
#   cy  : centre y of the arch (vertical middle of the bounding box)
#   hw  : half-width of the arch (left/right reach from cx)
#   h   : total height of the arch (apex → base, full span)
#   arc : apex rise as a fraction of total height (0 = flat top / plain
#         rectangle, 1 = the whole height is the curved arch). Typical
#         ogival niche ≈ 0.45.

# Stroke colour — muted gold per the project's "accent muted" visual rule,
# kept bright enough to read against the dark board art.
const ARCH_COLOR := Color(0.86, 0.72, 0.30, 0.85)
const ARCH_COLOR_HALO := Color(0.0, 0.0, 0.0, 0.5)  # dark halo for contrast
const ARCH_WIDTH := 3.0
const ARCH_SEGMENTS := 24   # polyline segments for the curved top

# domain_id -> param Dictionary (cx, cy, hw, h, arc). Set by Main.
var arches: Dictionary = {}
# Set of domain_ids currently visible (in penitence, or all in calib mode).
var visible_ids: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_right = 1.0
	anchor_bottom = 1.0


func set_arches(new_arches: Dictionary) -> void:
	arches = new_arches
	queue_redraw()


func set_visible_ids(ids: Dictionary) -> void:
	visible_ids = ids
	queue_redraw()


func _draw() -> void:
	var sz := size
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	for d_id in arches.keys():
		if not visible_ids.get(d_id, false):
			continue
		_draw_arch(arches[d_id], sz)


func _draw_arch(p: Dictionary, sz: Vector2) -> void:
	var pts := _arch_points(p, sz)
	if pts.size() < 2:
		return
	# Dark halo underneath for legibility on light niche art, then the gold.
	draw_polyline(pts, ARCH_COLOR_HALO, ARCH_WIDTH + 2.0, true)
	draw_polyline(pts, ARCH_COLOR, ARCH_WIDTH, true)
	# Non-colour cue : a small "+" keystone at the apex.
	var cx: float = float(p.get("cx", 0.5)) * sz.x
	var cy: float = float(p.get("cy", 0.5)) * sz.y
	var h: float = float(p.get("h", 0.2)) * sz.y
	var apex := Vector2(cx, cy - h * 0.5)
	_draw_keystone(apex)


# Build the closed arch outline as a polyline : up the left side, around the
# curved top (left base of arc → apex → right base of arc), down the right
# side, across the flat bottom, back to start.
func _arch_points(p: Dictionary, sz: Vector2) -> PackedVector2Array:
	var cx: float = float(p.get("cx", 0.5)) * sz.x
	var cy: float = float(p.get("cy", 0.5)) * sz.y
	var hw: float = float(p.get("hw", 0.08)) * sz.x
	var h: float = float(p.get("h", 0.2)) * sz.y
	var arc: float = clampf(float(p.get("arc", 0.45)), 0.0, 1.0)

	var top: float = cy - h * 0.5
	var bottom: float = cy + h * 0.5
	var arc_rise: float = h * arc            # vertical extent of the curved top
	var shoulder: float = top + arc_rise     # y where the straight sides start

	var left: float = cx - hw
	var right: float = cx + hw

	var out := PackedVector2Array()
	# Start at bottom-left, go up the left straight side to the shoulder.
	out.append(Vector2(left, bottom))
	out.append(Vector2(left, shoulder))
	# Curved top : a rounded arch from the left shoulder up to the apex and
	# down to the right shoulder. Parametrised as a half-ellipse of width hw
	# (per side) and height arc_rise, sampled across ARCH_SEGMENTS.
	for i in range(ARCH_SEGMENTS + 1):
		var t: float = float(i) / float(ARCH_SEGMENTS)   # 0 → 1 left → right
		# Angle sweeps PI (left) → 0 (right) over the top half of an ellipse.
		var ang: float = PI * (1.0 - t)
		var x: float = cx + cos(ang) * hw
		var y: float = shoulder - sin(ang) * arc_rise
		out.append(Vector2(x, y))
	# Down the right straight side, then close along the flat bottom.
	out.append(Vector2(right, bottom))
	out.append(Vector2(left, bottom))
	return out


func _draw_keystone(apex: Vector2) -> void:
	# Tiny "+" centred just below the apex — non-colour accessibility cue.
	var arm: float = 5.0
	var thick: float = 2.0
	var c := apex + Vector2(0.0, arm + 2.0)
	draw_line(c + Vector2(-arm, 0.0), c + Vector2(arm, 0.0), ARCH_COLOR, thick, true)
	draw_line(c + Vector2(0.0, -arm), c + Vector2(0.0, arm), ARCH_COLOR, thick, true)
