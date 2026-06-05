class_name PenitenceArch
extends Control
# Custom-drawn golden arch outline that frames a Domain niche while that
# Domain is in Penitence. One PenitenceArch instance covers the whole board
# (anchored 0..1 inside the ZoomLayer, exactly like the hotspots) and draws
# every visible arch in its own _draw(), converting normalised board
# coordinates → local pixels via its current size. Because it lives in the
# ZoomLayer alongside the hotspots, it follows zoom / pan / resize for free.
#
# The arch REUSES the Domain's existing zone rectangle (the hotspot bounds)
# as its left / right / top / bottom box — Main feeds those in each refresh.
# The only arch-specific parameter is `rise` : how far the curved apex sits
# ABOVE the rectangle's top edge. So an arch = the zone rectangle with its
# top edge replaced by an ogival curve peaking at (cx, top - rise).
# Drawn as a stroked polyline (no opaque fill) so the niche art stays visible.
# Accessibility : the golden colour is paired with a non-colour cue — a small
# "+" keystone glyph at the apex — so the marker reads even without colour.
#
# Geometry schema (one entry per visible DomainId, normalised 0..1 coords) :
#   cx     : centre x of the arch (= zone rectangle centre x)
#   hw     : half-width (= zone rectangle half-width)
#   top    : y of the rectangle's top edge (where the straight sides end and
#            the curve springs from — the "shoulders")
#   bottom : y of the rectangle's bottom edge
#   rise   : apex height above `top` (0 = flat top, larger = taller arch)

# Stroke colour — muted gold per the project's "accent muted" visual rule,
# kept bright enough to read against the dark board art.
const ARCH_COLOR := Color(0.86, 0.72, 0.30, 0.85)
const ARCH_COLOR_HALO := Color(0.0, 0.0, 0.0, 0.5)  # dark halo for contrast
const ARCH_WIDTH := 3.0
const ARCH_SEGMENTS := 24   # polyline segments for the curved top

# domain_id -> geometry Dictionary (cx, hw, top, bottom, rise). Set by Main.
var arches: Dictionary = {}
# Set of domain_ids currently visible (in penitence, or all in calib mode).
var visible_ids: Dictionary = {}
# Whether to draw the "+" keystone at each apex. True for the penitence
# overlay ; the seal overlay reuses this class with keystone = false (the
# colour itself + the padlock badge are the cue there).
var keystone: bool = true


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
	var pts := outline(p, sz)
	if pts.size() < 2:
		return
	# Per-arch stroke colour (seal arches pass the owning demon's colour) ;
	# defaults to the muted gold of the penitence overlay.
	var col: Color = p.get("color", ARCH_COLOR)
	# Dark halo underneath for legibility on light niche art, then the stroke.
	draw_polyline(pts, ARCH_COLOR_HALO, ARCH_WIDTH + 2.0, true)
	draw_polyline(pts, col, ARCH_WIDTH, true)
	# Non-colour cue : a small "+" keystone at the apex (penitence overlay only).
	if keystone:
		var cx: float = float(p.get("cx", 0.5)) * sz.x
		var top: float = float(p.get("top", 0.4)) * sz.y
		var rise: float = float(p.get("rise", 0.05)) * sz.y
		_draw_keystone(Vector2(cx, top - rise))


# Build the closed arch outline as a polyline : up the left side from the
# bottom to the shoulder (= rectangle top), around the curved top (left
# shoulder → apex → right shoulder), down the right side, then close along
# the flat bottom. Static so the penitence-reveal animation (ActionEffect)
# can trace the exact same contour.
static func outline(p: Dictionary, sz: Vector2) -> PackedVector2Array:
	var cx: float = float(p.get("cx", 0.5)) * sz.x
	var hw: float = float(p.get("hw", 0.08)) * sz.x
	var top: float = float(p.get("top", 0.4)) * sz.y
	var bottom: float = float(p.get("bottom", 0.6)) * sz.y
	var rise: float = maxf(0.0, float(p.get("rise", 0.05))) * sz.y

	var left: float = cx - hw
	var right: float = cx + hw

	var out := PackedVector2Array()
	# Start at bottom-left, go up the left straight side to the shoulder (top).
	out.append(Vector2(left, bottom))
	out.append(Vector2(left, top))
	# Curved top : a rounded arch from the left shoulder up to the apex
	# (cx, top - rise) and down to the right shoulder. Half-ellipse of width hw
	# per side and height `rise`, sampled across ARCH_SEGMENTS.
	for i in range(ARCH_SEGMENTS + 1):
		var t: float = float(i) / float(ARCH_SEGMENTS)   # 0 → 1 left → right
		# Angle sweeps PI (left) → 0 (right) over the top half of an ellipse.
		var ang: float = PI * (1.0 - t)
		var x: float = cx + cos(ang) * hw
		var y: float = top - sin(ang) * rise
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
