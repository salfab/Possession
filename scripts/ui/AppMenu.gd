class_name AppMenu
extends Control
# Reusable parchment-panel menu modelled on DomainActionMenu : a dark scrim that
# closes on outside tap, a centred PanelContainer with a gold border + shadow,
# and a vertical list of big tap cells. Generic — the caller feeds a title and a
# list of item dictionaries via open(); a tap on an enabled cell closes the menu
# and emits item_chosen(id).
#
# Item dict shape :
#   { "id": int, "label": String, "hint": String (optional), "disabled": bool (optional) }
#
# Stateless re-population : open() rebuilds the body on every open, so labels
# follow the current locale and disabled state is always fresh. Cheap — it's a
# tap-triggered modal, never refreshed per frame.

signal item_chosen(id: int)

const GOLD := Color(0.79, 0.63, 0.29)
const TXT := Color(0.91, 0.84, 0.66)
const TXT_DIM := Color(0.60, 0.54, 0.42)

var _panel: PanelContainer
var _content: VBoxContainer
# Cached styleboxes (built once) — the body is rebuilt on every open, so making
# these fresh each time was needless allocation churn.
var _cell_style_on: StyleBoxFlat
var _cell_style_off: StyleBoxFlat

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # invisible/closed = pass-through
	visible = false

func _ready() -> void:
	# Dark backdrop : reads as a modal AND catches taps outside the panel to close.
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.custom_minimum_size = Vector2(520, 0)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.05, 0.99)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 24
	return sb

func _on_scrim_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed):
		close()

func close() -> void:
	visible = false


# Deterministic click-out : close on any press whose position is outside the
# panel rect. Runs before GUI picking, so it doesn't depend on the scrim winning
# the pick. Presses inside the panel fall through to the cells. Only active while
# visible, so it never interferes with the tap that opens the menu.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pos: Vector2
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		pos = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			return
		pos = st.position
	else:
		return
	if not _panel.get_global_rect().has_point(pos):
		close()
		get_viewport().set_input_as_handled()

func open(title: String, items: Array) -> void:
	if not is_inside_tree():
		return
	_rebuild(title, items)
	# Centred modal, clamped so it never overflows a narrow viewport.
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size.x = clampf(vp.x * 0.7, 480.0, 900.0)
	# Ensure we render on top of sibling Controls (board + HUD).
	if get_parent() != null:
		get_parent().move_child(self, -1)
	visible = true
	# Wait one frame so the panel's container layout (and thus its size) is
	# resolved before we centre it.
	await get_tree().process_frame
	_center_panel()

func _center_panel() -> void:
	var vp := get_viewport_rect().size
	var ps := _panel.size
	var p := (vp - ps) * 0.5
	p.x = maxf(8.0, p.x)
	p.y = maxf(8.0, p.y)
	_panel.position = p

# ─── Build ──────────────────────────────────────────────────────────────────

func _rebuild(title: String, items: Array) -> void:
	for c in _content.get_children():
		c.queue_free()
	_content.add_child(_build_header(title))
	for item in items:
		var d: Dictionary = item
		var id: int = int(d.get("id", -1))
		var label: String = String(d.get("label", ""))
		var hint: String = String(d.get("hint", ""))
		var disabled: bool = bool(d.get("disabled", false))
		_content.add_child(_make_cell(id, label, hint, not disabled))

func _margins(node: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(node)
	return m

func _build_header(title: String) -> Control:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_override("font", Card.FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 60)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return _margins(lbl, 32, 22)

func _make_cell(id: int, title: String, hint: String, enabled: bool) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _cell_style(enabled))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(0, 110)   # big tap target
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER   # centre text block in the taller cell
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 48)
	t.add_theme_color_override("font_color", TXT if enabled else TXT_DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if hint != "":
		var s := Label.new()
		s.text = hint
		s.add_theme_font_size_override("font_size", 30)
		s.add_theme_color_override("font_color", TXT_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	pc.add_child(_margins(v, 24, 16))
	# Disabled cells swallow the tap (STOP, no handler) so poking them neither
	# acts nor closes the menu.
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if enabled:
		pc.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) \
					or (ev is InputEventScreenTouch and ev.pressed):
				_emit(id))
	return pc

func _cell_style(enabled: bool) -> StyleBoxFlat:
	if _cell_style_on == null:
		_cell_style_on = _make_cell_style(true)
		_cell_style_off = _make_cell_style(false)
	return _cell_style_on if enabled else _cell_style_off

func _make_cell_style(enabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.13, 0.08) if enabled else Color(0.13, 0.10, 0.07)
	sb.border_color = GOLD if enabled else Color(0.35, 0.29, 0.18, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb

func _emit(id: int) -> void:
	close()
	item_chosen.emit(id)
