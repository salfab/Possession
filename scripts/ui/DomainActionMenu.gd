class_name DomainActionMenu
extends Control
# Custom replacement for the native PopupMenu opened on domain tap. A parchment
# panel : header (name + yield pill + "why invest" line + control/transgression
# meta), a 2x2 grid of the four base actions, and a list of dynamic
# Provoquer/Amplifier entries below.
#
# Stateless re-population : open_for() rebuilds the body on every open. Cheap —
# it's a tap-triggered modal, never refreshed per frame. Owns the action list
# and label keys that used to live in Main.gd.

signal action_chosen(payload: Dictionary)
# payload variants :
#   {"kind": Kind.BASE,    "action_id": int}                 # ActionId
#   {"kind": Kind.PROVOKE, "tid": String, "origin": int}
#   {"kind": Kind.AMPLIFY, "tid": String}

enum Kind { BASE, PROVOKE, AMPLIFY }

const ACTIONS := [
	GameEnums.ActionId.INVESTIR,
	GameEnums.ActionId.EXPLOITER,
	GameEnums.ActionId.SCELLER,
	GameEnums.ActionId.FISSURER,
]
const LABEL_KEYS := {
	GameEnums.ActionId.INVESTIR:  "action.investir",
	GameEnums.ActionId.EXPLOITER: "action.exploiter",
	GameEnums.ActionId.SCELLER:   "action.sceller",
	GameEnums.ActionId.FISSURER:  "action.fissurer",
}

const GOLD := Color(0.79, 0.63, 0.29)
const VIOLET := Color(0.69, 0.42, 0.81)
const TXT := Color(0.91, 0.84, 0.66)
const TXT_DIM := Color(0.60, 0.54, 0.42)
const GAIN := Color(0.62, 0.79, 0.54)
const REFUSE := Color(0.79, 0.54, 0.54)

var _panel: PanelContainer
var _content: VBoxContainer
# Cached static styleboxes (built once) — the menu rebuilds its body on every
# open, so creating these fresh each time was needless allocation churn.
var _cell_style_on: StyleBoxFlat
var _cell_style_off: StyleBoxFlat
var _pill_gold: StyleBoxFlat
var _pill_violet: StyleBoxFlat

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
	_content.add_theme_constant_override("separation", 2)
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

func open_for(d_id: int, state: GameState, player: int, _at: Vector2 = Vector2.ZERO) -> void:
	if not is_inside_tree():
		return
	_rebuild(d_id, state, player)
	# Centred modal : wide enough to read comfortably on iPad, clamped so it
	# never overflows a narrow viewport. (The tap position is ignored now.)
	var vp := get_viewport_rect().size
	_panel.custom_minimum_size.x = clampf(vp.x * 0.82, 380.0, 640.0)
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

# ─── Build ────────────────────────────────────────────────────────────────

func _rebuild(d_id: int, state: GameState, player: int) -> void:
	for c in _content.get_children():
		c.queue_free()
	_content.add_child(_build_header(d_id, state))
	_content.add_child(_build_grid(d_id, state, player))
	var dyn := _build_dynamic(d_id, state, player)
	if dyn != null:
		_content.add_child(dyn)

func _margins(node: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(node)
	return m

func _build_header(d_id: int, state: GameState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_lbl := Label.new()
	name_lbl.text = String(GameEnums.DOMAIN_NAMES.get(d_id, ""))
	name_lbl.add_theme_font_override("font", Card.FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var pill := Label.new()
	pill.text = DomainData.chip_label(d_id)
	pill.add_theme_font_size_override("font_size", 20)
	pill.add_theme_color_override("font_color", Color(0.10, 0.07, 0.03))
	pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_theme_stylebox_override("normal", _pill_style(DomainData.is_victory_domain(d_id)))
	row.add_child(pill)
	box.add_child(row)

	var adv := Label.new()
	adv.text = DomainData.advantage_text(d_id)
	adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv.add_theme_font_size_override("font_size", 19)
	adv.add_theme_color_override("font_color", Color(0.76, 0.69, 0.52))
	box.add_child(adv)

	var meta := Label.new()
	var ctrl: int = state.controller_of(d_id)
	var ctrl_txt: String = (GameEnums.player_name(ctrl)
		if ctrl != GameEnums.PlayerId.NONE else I18n.t("player.none"))
	var dom: GameState.DomainState = state.domain(d_id)
	var trans_n: int = dom.scandals.size() + dom.infamies.size()
	meta.text = I18n.t("ui.menu.meta", [ctrl_txt, trans_n])
	meta.add_theme_font_size_override("font_size", 16)
	meta.add_theme_color_override("font_color", TXT_DIM)
	box.add_child(meta)

	return _margins(box, 22, 18)

func _build_grid(d_id: int, state: GameState, player: int) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for aid in ACTIONS:
		var why: String = _why_cannot(aid, state, player, d_id)
		var enabled: bool = why == ""
		var sub: String = ""
		var sub_col: Color = GAIN
		if aid == GameEnums.ActionId.EXPLOITER and enabled:
			sub = I18n.t("ui.menu.gain", [GameRules.production_of(state, d_id, player)])
		elif not enabled:
			sub = why
			sub_col = REFUSE
		grid.add_child(_make_cell(I18n.t(String(LABEL_KEYS[aid])), sub, sub_col,
			enabled, _emit_base.bind(aid)))
	return _margins(grid, 18, 8)

func _build_dynamic(d_id: int, state: GameState, player: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var added := false

	# Provokable : any Transgression legally provocable with this domain as origin.
	var prov := VBoxContainer.new()
	prov.add_theme_constant_override("separation", 8)
	for tid in TransgressionData.ALL_IDS:
		if GameRules.why_cannot_provoquer(state, player, tid) != "":
			continue
		if d_id in GameRules.transgression_origin_options(player, tid):
			var lbl := I18n.t("ui.popup.provoke_in",
				[TransgressionData.name_of(tid), GameEnums.DOMAIN_NAMES[d_id]])
			prov.add_child(_make_cell(lbl, "", GAIN, true, _emit_provoke.bind(tid, d_id)))
			added = true
	if prov.get_child_count() > 0:
		box.add_child(_section_label("ui.menu.provoke_section"))
		box.add_child(prov)

	# Amplifiable : Scandales the player owns whose origin is this domain.
	var amp := VBoxContainer.new()
	amp.add_theme_constant_override("separation", 8)
	var dom: GameState.DomainState = state.domain(d_id)
	for ti in dom.scandals:
		if ti.owner != player:
			continue
		if GameRules.why_cannot_amplifier(state, player, ti.def_id, ti) != "":
			continue
		var lbl := I18n.t("ui.popup.amplify_in",
			[TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]])
		amp.add_child(_make_cell(lbl, "", GAIN, true, _emit_amplify.bind(ti.def_id)))
		added = true
	if amp.get_child_count() > 0:
		box.add_child(_section_label("ui.menu.amplify_section"))
		box.add_child(amp)

	if not added:
		return null
	return _margins(box, 18, 10)

func _section_label(key: String) -> Label:
	var l := Label.new()
	l.text = I18n.t(key)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", TXT_DIM)
	return l

func _make_cell(title: String, sub: String, sub_col: Color, enabled: bool,
		on_tap: Callable) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _cell_style(enabled))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(0, 76)   # big tap target
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER   # centre text block in the taller cell
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", TXT if enabled else TXT_DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 17)
		s.add_theme_color_override("font_color", sub_col)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	pc.add_child(_margins(v, 16, 14))
	# Disabled cells swallow the tap (STOP, no handler) so poking them neither
	# acts nor closes the menu.
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if enabled:
		pc.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) \
					or (ev is InputEventScreenTouch and ev.pressed):
				on_tap.call())
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


func _pill_style(victory: bool) -> StyleBoxFlat:
	if _pill_gold == null:
		_pill_gold = _make_pill_style(false)
		_pill_violet = _make_pill_style(true)
	return _pill_violet if victory else _pill_gold


func _make_pill_style(victory: bool) -> StyleBoxFlat:
	var psb := StyleBoxFlat.new()
	psb.bg_color = VIOLET if victory else GOLD
	psb.set_corner_radius_all(14)
	psb.set_content_margin(SIDE_LEFT, 13)
	psb.set_content_margin(SIDE_RIGHT, 13)
	psb.set_content_margin(SIDE_TOP, 5)
	psb.set_content_margin(SIDE_BOTTOM, 5)
	return psb

func _why_cannot(aid: int, state: GameState, player: int, d_id: int) -> String:
	match aid:
		GameEnums.ActionId.INVESTIR:  return GameRules.why_cannot_investir(state, player, d_id)
		GameEnums.ActionId.EXPLOITER: return GameRules.why_cannot_exploiter(state, player, d_id)
		GameEnums.ActionId.SCELLER:   return GameRules.why_cannot_sceller(state, player, d_id)
		GameEnums.ActionId.FISSURER:  return GameRules.why_cannot_fissurer(state, player, d_id)
	return ""

func _emit_base(aid: int) -> void:
	close()
	action_chosen.emit({"kind": Kind.BASE, "action_id": aid})

func _emit_provoke(tid: String, origin: int) -> void:
	close()
	action_chosen.emit({"kind": Kind.PROVOKE, "tid": tid, "origin": origin})

func _emit_amplify(tid: String) -> void:
	close()
	action_chosen.emit({"kind": Kind.AMPLIFY, "tid": tid})
