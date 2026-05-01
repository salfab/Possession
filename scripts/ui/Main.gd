extends Control
# Plateau visuel : image board.png en background, hotspots normalisés
# sur les 5 domaines, popup d'actions au clic.

const SAVE_PATH := "user://save_game.json"

# Positions normalisées (0..1) des centres de domaines sur l'image.
# À ajuster en regardant l'image board.png si nécessaire.
const DOMAIN_POS := {
	GameEnums.DomainId.AMBITION: Vector2(0.50, 0.22),
	GameEnums.DomainId.FOI:      Vector2(0.32, 0.52),
	GameEnums.DomainId.VOLONTE:  Vector2(0.50, 0.55),
	GameEnums.DomainId.DESIR:    Vector2(0.67, 0.52),
	GameEnums.DomainId.PEUR:     Vector2(0.50, 0.78),
}
const DOMAIN_HALF := Vector2(0.09, 0.11)  # demi-taille du hotspot, normalisée

const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.25

const SCROLL_DRAG_THRESHOLD := 8.0

@onready var stage: Control = $BoardAspect/Stage

var state: GameState
var manager: TurnManager
var pending_action: int = -1
var pending_kwargs: Dictionary = {}

# Created in _build_overlays
var _zoom_layer: Control            # parent scaled/translated of board+hotspots
var _hotspots: Dictionary = {}      # domain_id -> Button
var _domain_labels: Dictionary = {} # domain_id -> Label
var _status_label: Label
var _ascendant_label: Label
var _action_popup: PopupMenu
var _selected_domain: int = -1
var _log_rtl: RichTextLabel
var _log_panel: PanelContainer
var _log_scroll: ScrollContainer
var _liturgy_dialog: AcceptDialog
var _liturgy_rtl: RichTextLabel
var _liturgy_image: TextureButton
var _decision_dialog: AcceptDialog
var _decision_content: VBoxContainer
var _endgame_dialog: AcceptDialog
var _endgame_rtl: RichTextLabel
var _endgame_image: TextureButton
var _endgame_shown: bool = false
var _trans_dialog: AcceptDialog
var _trans_content: VBoxContainer
var _trans_scroll: ScrollContainer

# Per-player owned-transgressions side panels (top/bottom in portrait,
# left/right in landscape). Each panel lists the names of the
# transgressions the player owns; tapping a name opens the fullscreen
# flippable card view.
var _player_panel_red: PanelContainer
var _player_panel_blue: PanelContainer
var _player_list_red: HFlowContainer
var _player_list_blue: HFlowContainer
var _fullscreen_card_dialog: AcceptDialog
var _fullscreen_card_image: TextureRect
var _fullscreen_card_flip_btn: Button
var _fullscreen_card_tex_a: Texture2D
var _fullscreen_card_tex_b: Texture2D
var _fullscreen_card_label_to_a: String
var _fullscreen_card_label_to_b: String

# Zoom / pan state
var _zoom: float = 1.0
var _is_panning: bool = false
var _pan_last: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}       # event.index -> position
var _pinch_prev_dist: float = 0.0

# Action ids exposed in the popup
const POPUP_ACTIONS := [
	GameEnums.ActionId.INVESTIR,
	GameEnums.ActionId.EXPLOITER,
	GameEnums.ActionId.SCELLER,
	GameEnums.ActionId.FISSURER,
]
const POPUP_LABELS := {
	GameEnums.ActionId.INVESTIR:  "Investir",
	GameEnums.ActionId.EXPLOITER: "Exploiter",
	GameEnums.ActionId.SCELLER:   "Sceller",
	GameEnums.ActionId.FISSURER:  "Fissurer",
}


func _ready() -> void:
	_apply_theme()
	_build_overlays()
	new_game()


func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_font_size("font_size", "Button", 22)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_constant("h_separation", "PopupMenu", 14)
	t.set_font_size("font_size", "Label", 22)
	theme = t


func new_game() -> void:
	state = GameState.new()
	manager = TurnManager.new(state)
	pending_action = -1
	pending_kwargs.clear()
	_endgame_shown = false
	_refresh_all()


# ─── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _build_overlays() -> void:
	# Stage: clip + capture inputs (wheel/pinch/middle-pan)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.gui_input.connect(_on_stage_gui_input)

	# Move BoardImage into a ZoomLayer (so we can scale/translate the whole board)
	var board_image: Node = stage.get_node_or_null("BoardImage")
	_zoom_layer = Control.new()
	_zoom_layer.name = "ZoomLayer"
	_zoom_layer.anchor_right = 1.0
	_zoom_layer.anchor_bottom = 1.0
	_zoom_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_zoom_layer)
	if board_image != null:
		stage.remove_child(board_image)
		_zoom_layer.add_child(board_image)
		stage.move_child(_zoom_layer, 0)

	# Hotspots and per-domain overlay labels — inside the ZoomLayer so they
	# stay aligned with the image when zooming/panning.
	for d_id in DOMAIN_POS.keys():
		var pos: Vector2 = DOMAIN_POS[d_id]
		var btn := Button.new()
		btn.flat = true
		btn.text = ""
		btn.anchor_left = pos.x - DOMAIN_HALF.x
		btn.anchor_right = pos.x + DOMAIN_HALF.x
		btn.anchor_top = pos.y - DOMAIN_HALF.y
		btn.anchor_bottom = pos.y + DOMAIN_HALF.y
		btn.offset_left = 0
		btn.offset_right = 0
		btn.offset_top = 0
		btn.offset_bottom = 0
		var did: int = d_id
		btn.pressed.connect(func(): _on_domain_clicked(did))
		_zoom_layer.add_child(btn)
		_hotspots[d_id] = btn

		var lbl := Label.new()
		lbl.anchor_left = pos.x - DOMAIN_HALF.x
		lbl.anchor_right = pos.x + DOMAIN_HALF.x
		lbl.anchor_top = pos.y + DOMAIN_HALF.y - 0.04
		lbl.anchor_bottom = pos.y + DOMAIN_HALF.y
		lbl.offset_left = 0
		lbl.offset_right = 0
		lbl.offset_top = 0
		lbl.offset_bottom = 0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.add_theme_font_size_override("font_size", 22)
		_zoom_layer.add_child(lbl)
		_domain_labels[d_id] = lbl

	# Top status bar (HUD — fixed, not zoomed)
	_status_label = Label.new()
	_status_label.anchor_left = 0.02
	_status_label.anchor_right = 0.98
	_status_label.anchor_top = 0.0
	_status_label.anchor_bottom = 0.08
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_label.tooltip_text = "Cliquer pour voir la Réponse liturgique de la Station"
	_status_label.gui_input.connect(_on_status_label_input)
	_status_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 5)
	_status_label.add_theme_font_size_override("font_size", 26)
	stage.add_child(_status_label)

	# Ascendant label over the bottom bar
	_ascendant_label = Label.new()
	_ascendant_label.anchor_left = 0.25
	_ascendant_label.anchor_right = 0.75
	_ascendant_label.anchor_top = 0.78
	_ascendant_label.anchor_bottom = 0.86
	_ascendant_label.offset_left = 0
	_ascendant_label.offset_right = 0
	_ascendant_label.offset_top = 0
	_ascendant_label.offset_bottom = 0
	_ascendant_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascendant_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ascendant_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_ascendant_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_ascendant_label.add_theme_constant_override("outline_size", 5)
	_ascendant_label.add_theme_font_size_override("font_size", 28)
	stage.add_child(_ascendant_label)

	# Bottom debug bar (top-level Control overlay, not in stage)
	_build_debug_bar()

	# Per-player transgression side panels (around the board)
	_build_player_transgression_panels()

	# Log panel (right side, hidden by default; toggled with a button)
	_build_log_panel()

	# Action popup
	_action_popup = PopupMenu.new()
	for aid in POPUP_ACTIONS:
		_action_popup.add_item(POPUP_LABELS[aid], aid)
	_action_popup.id_pressed.connect(_on_popup_action)
	add_child(_action_popup)

	# Liturgy dialog (full-screen modal at end of station)
	_build_liturgy_dialog()
	# Decision dialog (free exploitation, confession picks)
	_build_decision_dialog()
	# Endgame dialog (Exorcisme final)
	_build_endgame_dialog()
	# Transgressions catalog dialog
	_build_transgressions_dialog()
	# Full-screen card viewer
	_build_fullscreen_card_dialog()


func _build_liturgy_dialog() -> void:
	_liturgy_dialog = AcceptDialog.new()
	_liturgy_dialog.exclusive = true
	_liturgy_dialog.title = "Réponse liturgique"
	_liturgy_dialog.ok_button_text = "Continuer"
	_liturgy_dialog.dialog_text = ""
	_liturgy_dialog.min_size = Vector2i(820, 520)
	_liturgy_dialog.confirmed.connect(_on_liturgy_acknowledged)
	add_child(_liturgy_dialog)
	_make_dialog_touch_friendly(_liturgy_dialog)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liturgy_dialog.add_child(hbox)

	_liturgy_image = TextureButton.new()
	_liturgy_image.ignore_texture_size = true
	_liturgy_image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_liturgy_image.custom_minimum_size = Vector2(300, 420)
	_liturgy_image.tooltip_text = "Cliquer pour agrandir"
	_liturgy_image.pressed.connect(_on_liturgy_image_clicked)
	hbox.add_child(_liturgy_image)

	_liturgy_rtl = RichTextLabel.new()
	_liturgy_rtl.bbcode_enabled = true
	_liturgy_rtl.fit_content = true
	_liturgy_rtl.scroll_active = false
	_liturgy_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.custom_minimum_size = Vector2(420, 420)
	_liturgy_rtl.add_theme_font_size_override("normal_font_size", 22)
	_liturgy_rtl.add_theme_font_size_override("bold_font_size", 24)
	hbox.add_child(_liturgy_rtl)


func _build_debug_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.86
	bar.anchor_bottom = 1.0
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 4
	bar.offset_bottom = -8
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	var actions := [
		["−", _on_btn_zoom_out],
		["⊙", _on_btn_zoom_reset],
		["+", _on_btn_zoom_in],
		["Trans.", _on_btn_transgressions],
		["Nouvelle", _on_btn_new_game],
		["Station →", _on_btn_force_next_station],
		["Passer", _on_btn_pass],
		["Journal", _on_btn_toggle_log],
	]
	for a in actions:
		var btn := Button.new()
		btn.text = a[0]
		btn.custom_minimum_size = Vector2(64, 56)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(a[1])
		bar.add_child(btn)


func _build_log_panel() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.anchor_left = 0.45
	_log_panel.anchor_right = 1.0
	_log_panel.anchor_top = 0.08
	_log_panel.anchor_bottom = 0.85
	_log_panel.offset_left = 0
	_log_panel.offset_right = -10
	_log_panel.offset_top = 0
	_log_panel.offset_bottom = 0
	_log_panel.visible = false
	add_child(_log_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.85)
	sb.border_color = Color(0.8, 0.7, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	_log_panel.add_theme_stylebox_override("panel", sb)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_panel.add_child(_log_scroll)
	_enable_drag_scroll(_log_scroll)
	var sc: ScrollContainer = _log_scroll
	_log_rtl = RichTextLabel.new()
	_log_rtl.bbcode_enabled = true
	_log_rtl.fit_content = true
	_log_rtl.scroll_active = false  # let the parent ScrollContainer handle scrolling
	_log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	_log_rtl.selection_enabled = false
	_log_rtl.add_theme_color_override("default_color", Color(0.95, 0.9, 0.75))
	_log_rtl.add_theme_font_size_override("normal_font_size", 18)
	sc.add_child(_log_rtl)


# ─── REFRESH ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_status()
	_refresh_overlays()
	_refresh_log()
	_refresh_player_transgression_panels()
	_maybe_show_liturgy_dialog()
	_maybe_show_decision_dialog()
	_maybe_show_endgame_dialog()


func _refresh_status() -> void:
	if state.game_over:
		_status_label.text = "PARTIE TERMINÉE — %s" % GameEnums.player_name(state.winner)
		return
	var st_name: String = GameEnums.STATION_NAMES[state.current_station]
	var pulses: int = GameEnums.STATION_PULSES[state.current_station]
	var init_p: int = GameEnums.STATION_INITIATIVE[state.current_station]
	_status_label.text = "Station %s — Pulse %d/%d — Actif: %s — Init: %s" % [
		st_name, state.current_pulse, pulses,
		GameEnums.player_name(state.active_player),
		GameEnums.player_name(init_p),
	]


func _refresh_overlays() -> void:
	for d_id in DOMAIN_POS.keys():
		if not _domain_labels.has(d_id):
			continue
		var d := state.domain(d_id)
		var lbl: Label = _domain_labels[d_id]
		var line := "R:%d  B:%d" % [d.red_corruption, d.blue_corruption]
		var ctrl: int = state.controller_of(d_id)
		if ctrl != GameEnums.PlayerId.NONE:
			line += "  ◆%s" % GameEnums.player_name(ctrl).substr(0, 1)
		if state.is_sealed(d_id):
			line += "  ⚔"
		if state.is_in_penitence(d_id):
			line += "  ✝"
		lbl.text = line
	# Ascendant
	_ascendant_label.text = "Asc %+d  |  R:%d  B:%d" % [
		state.ascendant,
		state.available_corruption[GameEnums.PlayerId.RED],
		state.available_corruption[GameEnums.PlayerId.BLUE],
	]


# ─── Per-player owned-transgressions side panels ──────────────────────────────

func _build_player_transgression_panels() -> void:
	var bundle_red: Dictionary = _build_player_panel(GameEnums.PlayerId.RED,  Color(1.0, 0.45, 0.45))
	var bundle_blue: Dictionary = _build_player_panel(GameEnums.PlayerId.BLUE, Color(0.50, 0.70, 1.0))
	_player_panel_red = bundle_red["panel"]
	_player_list_red = bundle_red["list"]
	_player_panel_blue = bundle_blue["panel"]
	_player_list_blue = bundle_blue["list"]
	add_child(_player_panel_red)
	add_child(_player_panel_blue)
	# React to viewport rotation / window resize
	get_viewport().size_changed.connect(_layout_player_transgression_panels)
	_layout_player_transgression_panels()
	print("[panels] Built Red+Blue transgression panels")


func _build_player_panel(pid: int, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.08, 0.95)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	# Subtle glow in player accent so the panel pops on the dark board.
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s — Transgressions" % GameEnums.player_name(pid)
	title.add_theme_color_override("font_color", accent)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 4)
	list.add_theme_constant_override("v_separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	return {"panel": panel, "list": list}


func _layout_player_transgression_panels() -> void:
	if _player_panel_red == null or _player_panel_blue == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var portrait: bool = vp.y > vp.x
	if portrait:
		# Top strip (Red) and bottom strip (Blue), full width.
		# Sandwich between the status label (~0..0.08) and the ascendant
		# label (~0.78..0.86) / debug bar at the bottom.
		_set_anchors(_player_panel_red,  0.0, 0.08, 1.0, 0.20, 4, 4, 0, -2)
		_set_anchors(_player_panel_blue, 0.0, 0.65, 1.0, 0.77, 4, -2, 0, 0)
	else:
		# Left column (Red) and right column (Blue).
		_set_anchors(_player_panel_red,  0.0, 0.10, 0.16, 0.90, 4, 4, -4, -4)
		_set_anchors(_player_panel_blue, 0.84, 0.10, 1.0, 0.90, 4, 4, -4, -4)


func _set_anchors(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _refresh_player_transgression_panels() -> void:
	if _player_list_red == null or _player_list_blue == null:
		print("[panels] refresh skipped (lists null)")
		return
	for c in _player_list_red.get_children():
		c.queue_free()
	for c in _player_list_blue.get_children():
		c.queue_free()
	if state == null:
		return
	var n_red := 0
	var n_blue := 0
	for tid in TransgressionData.ALL_IDS:
		var owner: int = state.transgression_owner(tid)
		if owner == GameEnums.PlayerId.NONE:
			continue
		var def: Dictionary = TransgressionData.get_def(tid)
		var inst_inf: GameState.TransgressionInstance = state.find_transgression_instance(owner, tid, GameEnums.TransgressionFace.INFAMIE)
		var face: int = GameEnums.TransgressionFace.INFAMIE if inst_inf != null else GameEnums.TransgressionFace.SCANDALE
		var btn := Button.new()
		var name_str: String = String(def.get("name", tid))
		btn.text = name_str
		btn.add_theme_font_size_override("font_size", 14)
		btn.tooltip_text = "Cliquer pour voir la carte"
		# Magenta if the transgression has been amplified to Infamie, warm orange for Scandale.
		var fcol: Color = Color(1.0, 0.55, 1.0) if face == GameEnums.TransgressionFace.INFAMIE else Color(1.0, 0.78, 0.45)
		btn.add_theme_color_override("font_color", fcol)
		btn.pressed.connect(_on_player_transgression_clicked.bind(String(tid), face, name_str))
		if owner == GameEnums.PlayerId.RED:
			_player_list_red.add_child(btn)
			n_red += 1
		else:
			_player_list_blue.add_child(btn)
			n_blue += 1
	# Show "(aucune)" hint when empty so players know the panel is theirs.
	if _player_list_red.get_child_count() == 0:
		_player_list_red.add_child(_make_empty_hint())
	if _player_list_blue.get_child_count() == 0:
		_player_list_blue.add_child(_make_empty_hint())
	print("[panels] refresh: Red=%d Blue=%d" % [n_red, n_blue])


func _make_empty_hint() -> Label:
	var lbl := Label.new()
	lbl.text = "(aucune)"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	return lbl


func _on_player_transgression_clicked(tid: String, face: int, name_str: String) -> void:
	var tex_s: Texture2D = CardImages.transgression(tid, GameEnums.TransgressionFace.SCANDALE)
	var tex_i: Texture2D = CardImages.transgression(tid, GameEnums.TransgressionFace.INFAMIE)
	if face == GameEnums.TransgressionFace.SCANDALE:
		_show_fullscreen_card_flippable(tex_s, "Voir Infamie ↻", tex_i, "Voir Scandale ↻", name_str)
	else:
		_show_fullscreen_card_flippable(tex_i, "Voir Scandale ↻", tex_s, "Voir Infamie ↻", name_str)


func _refresh_log() -> void:
	if _log_rtl == null:
		return
	var lines: Array = state.log
	var max_lines := 200
	var start: int = max(0, lines.size() - max_lines)
	var s := ""
	for i in range(start, lines.size()):
		s += String(lines[i]) + "\n"
	_log_rtl.text = s
	# Auto-scroll to the bottom (after the layout has had a frame to update).
	if _log_scroll != null and _log_panel.visible:
		_scroll_log_to_bottom()


func _scroll_log_to_bottom() -> void:
	await get_tree().process_frame
	if _log_scroll == null:
		return
	var vbar := _log_scroll.get_v_scroll_bar()
	if vbar != null:
		_log_scroll.scroll_vertical = int(vbar.max_value)


# ─── INTERACTION ──────────────────────────────────────────────────────────────

func _on_domain_clicked(d_id: int) -> void:
	if state.game_over:
		return
	if state.has_pending_decisions():
		state.add_log("[INFO] Une décision est en attente — non géré dans cette UI.")
		_refresh_log()
		return
	_selected_domain = d_id
	var p: int = state.active_player
	# Build labels enriched with the legality reason if illegal.
	for idx in POPUP_ACTIONS.size():
		var aid: int = POPUP_ACTIONS[idx]
		var why: String = ""
		if aid == GameEnums.ActionId.INVESTIR:
			why = GameRules.why_cannot_investir(state, p, d_id)
		elif aid == GameEnums.ActionId.EXPLOITER:
			why = GameRules.why_cannot_exploiter(state, p, d_id)
		elif aid == GameEnums.ActionId.SCELLER:
			why = GameRules.why_cannot_sceller(state, p, d_id)
		elif aid == GameEnums.ActionId.FISSURER:
			why = GameRules.why_cannot_fissurer(state, p, d_id)
		var label_str: String = "%s %s" % [POPUP_LABELS[aid], GameEnums.DOMAIN_NAMES[d_id]]
		if why != "":
			label_str += "  —  " + why
		_action_popup.set_item_text(idx, label_str)
		_action_popup.set_item_disabled(idx, why != "")
	# Position the popup near the touch
	var mp: Vector2 = get_viewport().get_mouse_position()
	_action_popup.position = Vector2i(int(mp.x), int(mp.y))
	_action_popup.size = Vector2i(540, 0)
	_action_popup.popup()


func _on_popup_action(action_id: int) -> void:
	if _selected_domain < 0:
		return
	var result := manager.perform_action(action_id, {"domain": _selected_domain})
	if not result.get("ok", false):
		state.add_log("[REFUSÉ] " + result.get("message", "?"))
	_selected_domain = -1
	_refresh_all()


# ─── DEBUG BUTTONS ────────────────────────────────────────────────────────────

func _on_btn_new_game() -> void:
	new_game()
	state.add_log("*** NOUVELLE PARTIE COMMENCÉE à %s ***" % Time.get_time_string_from_system())
	_refresh_log()


func _on_btn_force_next_station() -> void:
	if state.game_over:
		return
	state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
	manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
	manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
	manager._end_pulse()
	_refresh_all()


func _on_btn_pass() -> void:
	if state.game_over:
		return
	if state.has_pending_decisions():
		state.add_log("[INFO] Décision en attente — non géré.")
		_refresh_log()
		return
	var result := manager.perform_action(GameEnums.ActionId.PASSER, {})
	if not result.get("ok", false):
		state.add_log("[REFUSÉ] " + result.get("message", "?"))
	_refresh_all()


func _on_btn_toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		_refresh_log()


# ─── LITURGY DIALOG ───────────────────────────────────────────────────────────

func _maybe_show_liturgy_dialog() -> void:
	if manager == null:
		return
	if manager.pending_liturgy.is_empty():
		return
	if _liturgy_dialog.visible:
		return
	_show_liturgy_dialog(manager.pending_liturgy)


func _show_liturgy_dialog(info: Dictionary) -> void:
	var resp_name: String = String(info.get("name", "?"))
	var imp: bool = bool(info.get("impedita", false))
	var desc: String = String(info.get("description", ""))
	var lines: Array = info.get("log_lines", [])
	var st: int = int(info.get("station", 0))
	var st_name: String = GameEnums.STATION_NAMES.get(st, "?")
	var mode_str: String = "Impedita" if imp else "In Integro"
	var mode_color: String = "#e88" if imp else "#8e8"

	var details := ""
	for l in lines:
		details += "• " + String(l) + "\n"
	if details == "":
		details = "(aucun effet)"

	_liturgy_dialog.title = "Fin de la Station %s" % st_name
	# Card image (preloaded via CardImages autoload)
	var resp_id: String = String(LiturgicalResponseData.get_response(st).get("id", ""))
	var img_tex: Texture2D = CardImages.liturgy(resp_id, imp) if resp_id != "" else null
	_liturgy_image.texture_normal = img_tex
	_liturgy_image.visible = (img_tex != null)
	# Stash for the fullscreen flip viewer when the image is clicked.
	_liturgy_image.set_meta("resp_id", resp_id)
	_liturgy_image.set_meta("impedita", imp)
	_liturgy_image.set_meta("name", resp_name)
	# Text panel
	_liturgy_rtl.clear()
	_liturgy_rtl.append_text("[font_size=30][b]%s[/b][/font_size]\n" % resp_name)
	_liturgy_rtl.append_text("[font_size=22][color=%s][b]%s[/b][/color][/font_size]\n\n" % [mode_color, mode_str])
	_liturgy_rtl.append_text("[i]%s[/i]\n\n" % desc)
	_liturgy_rtl.append_text("[b]Résolution :[/b]\n")
	_liturgy_rtl.append_text(details)

	_liturgy_dialog.popup_centered()


func _on_liturgy_acknowledged() -> void:
	manager.acknowledge_liturgy()
	_refresh_all()


# ─── DECISION DIALOG (free_exploit, confession) ───────────────────────────────

func _build_decision_dialog() -> void:
	_decision_dialog = AcceptDialog.new()
	_decision_dialog.exclusive = true
	_decision_dialog.title = "Décision"
	_decision_dialog.dialog_text = ""
	_decision_dialog.min_size = Vector2i(560, 420)
	_decision_dialog.confirmed.connect(_on_decision_skip)
	add_child(_decision_dialog)
	_make_dialog_touch_friendly(_decision_dialog)
	_decision_content = VBoxContainer.new()
	_decision_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decision_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decision_content.add_theme_constant_override("separation", 8)
	_decision_dialog.add_child(_decision_content)


func _maybe_show_decision_dialog() -> void:
	if state == null or manager == null:
		return
	if not state.has_pending_decisions():
		return
	if _decision_dialog.visible:
		return
	# Show liturgy first if pending
	if not manager.pending_liturgy.is_empty():
		return
	if _liturgy_dialog.visible:
		return
	_populate_decision_dialog(state.pending_decisions[0])
	_decision_dialog.popup_centered()


func _populate_decision_dialog(dec: GameState.PendingDecision) -> void:
	for c in _decision_content.get_children():
		c.queue_free()

	if dec.kind == "free_exploit":
		_decision_dialog.title = "Exploitation gratuite — %s" % GameEnums.player_name(dec.player)
		_decision_dialog.ok_button_text = "Passer (ne pas exploiter)"
		_decision_dialog.get_ok_button().disabled = false
		var hint := Label.new()
		hint.text = "%s : choisis un domaine à exploiter, ou clique « Passer »." % GameEnums.player_name(dec.player)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		_decision_content.add_child(hint)
		var options: Array = dec.data.get("options", [])
		for d_id in options:
			var did: int = d_id
			var btn := Button.new()
			btn.text = "Exploiter %s" % GameEnums.DOMAIN_NAMES[d_id]
			btn.custom_minimum_size = Vector2(0, 56)
			btn.add_theme_font_size_override("font_size", 22)
			btn.pressed.connect(func(): _on_decision_pick({"domain": did}))
			_decision_content.add_child(btn)

	elif dec.kind == "confession":
		_decision_dialog.title = "Confession — %s" % GameEnums.player_name(dec.player)
		_decision_dialog.ok_button_text = "(choix obligatoire)"
		_decision_dialog.get_ok_button().disabled = true
		var imp: bool = dec.data.get("impedita", false)
		var n: int = dec.picks_remaining
		var s_plural: String = "s" if n > 1 else ""
		var hint := Label.new()
		hint.text = "%s doit choisir %d pénitence%s parmi 3 (mode %s)." % [
			GameEnums.player_name(dec.player), n, s_plural,
			"Impedita" if imp else "In Integro",
		]
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		_decision_content.add_child(hint)
		var avail: Array = LiturgyResolver.available_confession_kinds(state, dec)
		if "lose2" in avail:
			var btn := Button.new()
			btn.text = "Perdre 2 Corruptions disponibles"
			btn.custom_minimum_size = Vector2(0, 56)
			btn.add_theme_font_size_override("font_size", 22)
			btn.pressed.connect(func(): _on_decision_pick({"kind": "lose2"}))
			_decision_content.add_child(btn)
		if "penitence" in avail:
			for d_id in DomainData.DOMAINS:
				if state.controller_of(d_id) == dec.player and not state.is_in_penitence(d_id):
					var did: int = d_id
					var btn := Button.new()
					btn.text = "Pénitence : %s" % GameEnums.DOMAIN_NAMES[d_id]
					btn.custom_minimum_size = Vector2(0, 56)
					btn.add_theme_font_size_override("font_size", 22)
					btn.pressed.connect(func(): _on_decision_pick({"kind": "penitence", "domain": did}))
					_decision_content.add_child(btn)
		if "fissure" in avail:
			for d_id in DomainData.DOMAINS:
				var dd := state.domain(d_id)
				if state.controller_of(d_id) == dec.player and state.is_sealed(d_id) and dd.seal_owner == dec.player:
					var did: int = d_id
					var btn := Button.new()
					btn.text = "Fissurer mon Sceau sur %s" % GameEnums.DOMAIN_NAMES[d_id]
					btn.custom_minimum_size = Vector2(0, 56)
					btn.add_theme_font_size_override("font_size", 22)
					btn.pressed.connect(func(): _on_decision_pick({"kind": "fissure", "domain": did}))
					_decision_content.add_child(btn)


func _on_decision_pick(picks: Dictionary) -> void:
	# Hide first so the AcceptDialog "confirmed" signal is NOT emitted.
	_decision_dialog.hide()
	var r := manager.resolve_decision(picks)
	if not r.get("ok", false):
		state.add_log("[REFUSÉ] " + r.get("message", "?"))
	_refresh_all()


func _on_decision_skip() -> void:
	# Triggered when the user clicks the OK ("Passer") button — only valid
	# for free_exploit (the OK button is disabled for confession).
	if not state.has_pending_decisions():
		_refresh_all()
		return
	var dec: GameState.PendingDecision = state.pending_decisions[0]
	if dec.kind != "free_exploit":
		_refresh_all()
		return
	var r := manager.resolve_decision({"skip": true})
	if not r.get("ok", false):
		state.add_log("[REFUSÉ] " + r.get("message", "?"))
	_refresh_all()


# ─── ENDGAME DIALOG (Exorcisme final) ─────────────────────────────────────────

func _build_endgame_dialog() -> void:
	_endgame_dialog = AcceptDialog.new()
	_endgame_dialog.exclusive = true
	_endgame_dialog.title = "Exorcisme final"
	_endgame_dialog.ok_button_text = "Nouvelle partie"
	_endgame_dialog.dialog_text = ""
	_endgame_dialog.min_size = Vector2i(880, 540)
	_endgame_dialog.confirmed.connect(_on_endgame_acknowledged)
	add_child(_endgame_dialog)
	_make_dialog_touch_friendly(_endgame_dialog)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_endgame_dialog.add_child(hbox)

	_endgame_image = TextureButton.new()
	_endgame_image.ignore_texture_size = true
	_endgame_image.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_endgame_image.custom_minimum_size = Vector2(320, 448)
	_endgame_image.texture_normal = CardImages.exorcisme()
	_endgame_image.tooltip_text = "Cliquer pour agrandir"
	_endgame_image.pressed.connect(_on_endgame_image_clicked)
	hbox.add_child(_endgame_image)

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(440, 448)
	hbox.add_child(sc)
	_enable_drag_scroll(sc)

	_endgame_rtl = RichTextLabel.new()
	_endgame_rtl.bbcode_enabled = true
	_endgame_rtl.fit_content = true
	_endgame_rtl.scroll_active = false
	_endgame_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_endgame_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_endgame_rtl.add_theme_font_size_override("normal_font_size", 22)
	_endgame_rtl.add_theme_font_size_override("bold_font_size", 24)
	sc.add_child(_endgame_rtl)


func _maybe_show_endgame_dialog() -> void:
	if state == null or not state.game_over:
		return
	if _endgame_shown:
		return
	if _endgame_dialog.visible:
		return
	_show_endgame_dialog()
	_endgame_shown = true


func _show_endgame_dialog() -> void:
	var rupture := EndGameResolver.check_rupture(state)
	var winner_str: String = GameEnums.player_name(state.winner) if state.winner != GameEnums.PlayerId.NONE else "Pape sauvé (aucun démon)"
	var s := ""
	s += "[font_size=30][b]%s[/b][/font_size]\n\n" % winner_str
	s += "[i]%s[/i]\n\n" % state.winner_reason
	s += "[b]Rupture de l'âme :[/b]\n"
	s += "  • Profondeur : %s\n" % ("[color=#8e8]✓ remplie[/color]" if rupture.profondeur else "[color=#888]— non remplie[/color]")
	s += "  • Étendue : %s\n" % ("[color=#8e8]✓ remplie[/color]" if rupture.etendue else "[color=#888]— non remplie[/color]")
	s += "  • Ancrage : %s\n" % ("[color=#8e8]✓ rempli[/color]" if rupture.ancrage else "[color=#888]— non rempli[/color]")
	s += "  • [b]Complète : %s[/b]\n\n" % ("[color=#8e8]OUI — l'exorcisme échoue[/color]" if rupture.complete else "[color=#e88]NON — l'exorcisme réussit[/color]")
	s += "[b]Ascendant final :[/b] %+d\n\n" % state.ascendant
	s += "[b]Résolution (dernières lignes du journal) :[/b]\n"
	var lines: Array = state.log
	var last_n: int = min(12, lines.size())
	for i in range(lines.size() - last_n, lines.size()):
		s += "  • " + String(lines[i]) + "\n"
	_endgame_rtl.clear()
	_endgame_rtl.append_text(s)
	_endgame_dialog.popup_centered()


func _on_endgame_acknowledged() -> void:
	new_game()


# ─── TRANSGRESSIONS DIALOG ────────────────────────────────────────────────────

func _build_transgressions_dialog() -> void:
	_trans_dialog = AcceptDialog.new()
	_trans_dialog.exclusive = true
	_trans_dialog.title = "Transgressions"
	_trans_dialog.ok_button_text = "Fermer"
	_trans_dialog.dialog_text = ""
	_trans_dialog.min_size = Vector2i(720, 520)
	add_child(_trans_dialog)
	_make_dialog_touch_friendly(_trans_dialog)
	_trans_scroll = ScrollContainer.new()
	_trans_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trans_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trans_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_trans_scroll.custom_minimum_size = Vector2(680, 460)
	_trans_dialog.add_child(_trans_scroll)
	_enable_drag_scroll(_trans_scroll)
	_trans_content = VBoxContainer.new()
	_trans_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trans_content.add_theme_constant_override("separation", 10)
	_trans_scroll.add_child(_trans_content)


func _on_btn_transgressions() -> void:
	if state == null:
		return
	_populate_transgressions_dialog()
	# Plein écran : on aligne sur la taille du viewport
	var vp_size: Vector2 = get_viewport_rect().size
	_trans_dialog.size = vp_size
	_trans_dialog.popup(Rect2i(Vector2i.ZERO, Vector2i(vp_size)))


func _populate_transgressions_dialog() -> void:
	for c in _trans_content.get_children():
		c.queue_free()
	var p: int = state.active_player
	_trans_dialog.title = "Transgressions — Joueur actif : %s" % GameEnums.player_name(p)
	for tid in TransgressionData.ALL_IDS:
		var def: Dictionary = TransgressionData.get_def(tid)
		var card := _make_transgression_card(p, String(tid), def)
		_trans_content.add_child(card)


func _make_transgression_card(player: int, tid: String, def: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.16, 0.95)
	sb.border_color = Color(0.55, 0.45, 0.20)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Determine current face (Scandale by default; Infamie if any owner amplified it).
	var owner: int = state.transgression_owner(tid)
	var face: int = GameEnums.TransgressionFace.SCANDALE
	if owner != GameEnums.PlayerId.NONE:
		var inf_inst: GameState.TransgressionInstance = state.find_transgression_instance(owner, tid, GameEnums.TransgressionFace.INFAMIE)
		if inf_inst != null:
			face = GameEnums.TransgressionFace.INFAMIE

	# Card image (left) — clickable to view full-screen, flippable via right-column button.
	var img := TextureButton.new()
	img.ignore_texture_size = true
	img.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(180, 252)
	img.tooltip_text = "Cliquer pour agrandir"
	img.mouse_filter = Control.MOUSE_FILTER_PASS  # let scroll-drag pass through
	img.set_meta("face", face)
	img.set_meta("tid", tid)
	img.texture_normal = CardImages.transgression(tid, face)
	var captured_name: String = String(def.get("name", ""))
	var captured_tid: String = tid
	img.pressed.connect(_on_transgression_image_clicked.bind(img, captured_tid, captured_name))
	hbox.add_child(img)

	# Right column: state badge + buttons + reason
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var state_lbl := Label.new()
	if owner == GameEnums.PlayerId.NONE:
		state_lbl.text = "Libre (face Scandale)"
		state_lbl.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	else:
		if face == GameEnums.TransgressionFace.INFAMIE:
			state_lbl.text = "Infamie · " + GameEnums.player_name(owner)
			state_lbl.add_theme_color_override("font_color", Color(1, 0.6, 1))
		else:
			state_lbl.text = "Scandale · " + GameEnums.player_name(owner)
			state_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0.5))
	state_lbl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(state_lbl)

	# Flip button — toggle the displayed face between Scandale and Infamie
	var flip_btn := Button.new()
	flip_btn.add_theme_font_size_override("font_size", 16)
	flip_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	flip_btn.text = _flip_button_label(face)
	flip_btn.pressed.connect(_on_transgression_flip_pressed.bind(img, flip_btn, tid))
	vbox.add_child(flip_btn)

	# Action buttons
	var btn_row := HFlowContainer.new()
	btn_row.add_theme_constant_override("h_separation", 6)
	btn_row.add_theme_constant_override("v_separation", 6)
	vbox.add_child(btn_row)

	var why_prov: String = GameRules.why_cannot_provoquer(state, player, tid)
	var origins: Array = GameRules.transgression_origin_options(player, tid)
	for origin_d in origins:
		var btn := Button.new()
		var origin_int: int = origin_d
		if origins.size() > 1:
			btn.text = "Provoquer (%s)" % GameEnums.DOMAIN_NAMES[origin_d]
		else:
			btn.text = "Provoquer"
		btn.disabled = (why_prov != "")
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.add_theme_font_size_override("font_size", 18)
		btn.tooltip_text = why_prov
		btn.pressed.connect(func(): _on_provoquer_clicked(tid, origin_int))
		btn_row.add_child(btn)

	var why_amp: String = GameRules.why_cannot_amplifier(state, player, tid)
	var amp_btn := Button.new()
	amp_btn.text = "Amplifier"
	amp_btn.disabled = (why_amp != "")
	amp_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	amp_btn.add_theme_font_size_override("font_size", 18)
	amp_btn.tooltip_text = why_amp
	amp_btn.pressed.connect(func(): _on_amplifier_clicked(tid))
	btn_row.add_child(amp_btn)

	if why_prov != "" or why_amp != "":
		var hint := Label.new()
		var bits := ""
		if why_prov != "":
			bits += "Provoquer : %s" % why_prov
		if why_amp != "":
			if bits != "":
				bits += "\n"
			bits += "Amplifier : %s" % why_amp
		hint.text = bits
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 15)
		hint.add_theme_color_override("font_color", Color(0.85, 0.5, 0.5))
		vbox.add_child(hint)

	# Push content to top of the right column
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Let drag events bubble up to the parent ScrollContainer (Labels and
	# basic Controls default to MOUSE_FILTER_STOP, which would swallow the
	# drag and prevent the dialog from scrolling by drag).
	_set_pass_through(panel)

	return panel


func _set_pass_through(node: Node) -> void:
	if node is Control:
		var c: Control = node
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_pass_through(child)


# Make AcceptDialog buttons + title-bar comfortable for fat fingers on a phone.
# Apply after add_child(dlg) so the OK button exists.
func _make_dialog_touch_friendly(dlg: AcceptDialog) -> void:
	var ok_btn: Button = dlg.get_ok_button()
	if ok_btn != null:
		ok_btn.add_theme_font_size_override("font_size", 24)
		ok_btn.custom_minimum_size = Vector2(160, 64)
	# Taller title bar → larger touch zone around the close X.
	dlg.add_theme_constant_override("title_height", 48)
	dlg.add_theme_font_size_override("title_font_size", 22)


# ─── FULLSCREEN CARD VIEWER ───────────────────────────────────────────────────

func _build_fullscreen_card_dialog() -> void:
	_fullscreen_card_dialog = AcceptDialog.new()
	_fullscreen_card_dialog.exclusive = true
	_fullscreen_card_dialog.title = "Carte"
	_fullscreen_card_dialog.ok_button_text = "Fermer"
	_fullscreen_card_dialog.dialog_text = ""
	_fullscreen_card_dialog.min_size = Vector2i(360, 440)
	add_child(_fullscreen_card_dialog)
	_make_dialog_touch_friendly(_fullscreen_card_dialog)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_fullscreen_card_dialog.add_child(vbox)

	_fullscreen_card_image = TextureRect.new()
	_fullscreen_card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fullscreen_card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fullscreen_card_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fullscreen_card_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fullscreen_card_image.custom_minimum_size = Vector2(340, 420)
	vbox.add_child(_fullscreen_card_image)

	_fullscreen_card_flip_btn = Button.new()
	_fullscreen_card_flip_btn.add_theme_font_size_override("font_size", 18)
	_fullscreen_card_flip_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_fullscreen_card_flip_btn.visible = false
	_fullscreen_card_flip_btn.pressed.connect(_on_fullscreen_card_flip_pressed)
	vbox.add_child(_fullscreen_card_flip_btn)


func _show_fullscreen_card(tex: Texture2D, title_str: String = "Carte") -> void:
	if tex == null:
		return
	_fullscreen_card_image.texture = tex
	_fullscreen_card_flip_btn.visible = false
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


# Show a flippable pair. tex_a is shown first; the button label is what the
# user clicks to switch (so when tex_a is up, label = "Voir <B> ↻").
func _show_fullscreen_card_flippable(tex_a: Texture2D, label_to_b: String,
		tex_b: Texture2D, label_to_a: String, title_str: String) -> void:
	if tex_a == null and tex_b == null:
		return
	# Fallback if one face is missing
	if tex_a == null:
		_show_fullscreen_card(tex_b, title_str)
		return
	if tex_b == null:
		_show_fullscreen_card(tex_a, title_str)
		return
	_fullscreen_card_tex_a = tex_a
	_fullscreen_card_tex_b = tex_b
	_fullscreen_card_label_to_a = label_to_a
	_fullscreen_card_label_to_b = label_to_b
	_fullscreen_card_image.texture = tex_a
	_fullscreen_card_flip_btn.text = label_to_b
	_fullscreen_card_flip_btn.visible = true
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


func _on_fullscreen_card_flip_pressed() -> void:
	if _fullscreen_card_image.texture == _fullscreen_card_tex_a:
		_fullscreen_card_image.texture = _fullscreen_card_tex_b
		_fullscreen_card_flip_btn.text = _fullscreen_card_label_to_a
	else:
		_fullscreen_card_image.texture = _fullscreen_card_tex_a
		_fullscreen_card_flip_btn.text = _fullscreen_card_label_to_b


func _popup_dialog_fullscreen(dlg: AcceptDialog) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	dlg.size = vp_size
	dlg.popup(Rect2i(Vector2i.ZERO, Vector2i(vp_size)))


# ─── Transgression catalog: per-card flip + image-click handlers ──────────────

func _flip_button_label(face: int) -> String:
	return "Voir Infamie ↻" if face == GameEnums.TransgressionFace.SCANDALE else "Voir Scandale ↻"


func _on_transgression_flip_pressed(img: TextureButton, btn: Button, tid: String) -> void:
	var cur: int = img.get_meta("face", GameEnums.TransgressionFace.SCANDALE)
	var nxt: int = GameEnums.TransgressionFace.INFAMIE if cur == GameEnums.TransgressionFace.SCANDALE else GameEnums.TransgressionFace.SCANDALE
	img.set_meta("face", nxt)
	img.texture_normal = CardImages.transgression(tid, nxt)
	btn.text = _flip_button_label(nxt)


func _on_transgression_image_clicked(img: TextureButton, tid: String, name_str: String) -> void:
	var cur: int = img.get_meta("face", GameEnums.TransgressionFace.SCANDALE)
	var tex_scandale: Texture2D = CardImages.transgression(tid, GameEnums.TransgressionFace.SCANDALE)
	var tex_infamie: Texture2D = CardImages.transgression(tid, GameEnums.TransgressionFace.INFAMIE)
	if cur == GameEnums.TransgressionFace.SCANDALE:
		_show_fullscreen_card_flippable(tex_scandale, "Voir Infamie ↻", tex_infamie, "Voir Scandale ↻", name_str)
	else:
		_show_fullscreen_card_flippable(tex_infamie, "Voir Scandale ↻", tex_scandale, "Voir Infamie ↻", name_str)


# ─── Status label: clickable → fullscreen liturgical card for current station ─

func _on_status_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_show_current_station_card()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_show_current_station_card()


func _show_current_station_card() -> void:
	if state == null or state.game_over:
		return
	var st: int = state.current_station
	var resp: Dictionary = LiturgicalResponseData.get_response(st)
	if resp.is_empty():
		return
	var resp_id: String = String(resp.get("id", ""))
	if resp_id == "":
		return
	var resp_name: String = String(resp.get("name", ""))
	var st_name: String = GameEnums.STATION_NAMES.get(st, "")
	var title_str: String = "%s — %s" % [st_name, resp_name] if st_name != "" else resp_name
	var tex_in_integro: Texture2D = CardImages.liturgy(resp_id, false)
	var tex_impedita: Texture2D = CardImages.liturgy(resp_id, true)
	_show_fullscreen_card_flippable(
		tex_in_integro, "Voir Impedita ↻",
		tex_impedita,   "Voir In Integro ↻",
		title_str
	)


func _on_liturgy_image_clicked() -> void:
	if _liturgy_image.texture_normal == null:
		return
	var resp_id: String = String(_liturgy_image.get_meta("resp_id", ""))
	if resp_id == "":
		_show_fullscreen_card(_liturgy_image.texture_normal, _liturgy_dialog.title)
		return
	var imp: bool = bool(_liturgy_image.get_meta("impedita", false))
	var name_str: String = String(_liturgy_image.get_meta("name", ""))
	var tex_in_integro: Texture2D = CardImages.liturgy(resp_id, false)
	var tex_impedita: Texture2D = CardImages.liturgy(resp_id, true)
	if imp:
		_show_fullscreen_card_flippable(tex_impedita, "Voir In Integro ↻", tex_in_integro, "Voir Impedita ↻", name_str)
	else:
		_show_fullscreen_card_flippable(tex_in_integro, "Voir Impedita ↻", tex_impedita, "Voir In Integro ↻", name_str)


func _on_endgame_image_clicked() -> void:
	if _endgame_image.texture_normal != null:
		_show_fullscreen_card(_endgame_image.texture_normal, "Exorcisme final")


func _on_provoquer_clicked(tid: String, origin: int) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.PROVOQUER, {"def_id": tid, "origin": origin})
	if not r.get("ok", false):
		state.add_log("[REFUSÉ] " + r.get("message", "?"))
	_refresh_all()


func _on_amplifier_clicked(tid: String) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.AMPLIFIER, {"def_id": tid})
	if not r.get("ok", false):
		state.add_log("[REFUSÉ] " + r.get("message", "?"))
	_refresh_all()


# ─── DRAG-TO-SCROLL HELPER ────────────────────────────────────────────────────

func _enable_drag_scroll(sc: ScrollContainer) -> void:
	# Adds drag-to-scroll to the given ScrollContainer (mouse + touch).
	# Children should set mouse_filter = MOUSE_FILTER_PASS so the events
	# bubble up to the scroll container's gui_input.
	var st := {"active": false, "start_y": 0.0, "start_scroll": 0, "captured": false}
	sc.set_meta("drag_state", st)
	sc.gui_input.connect(_on_drag_scroll_input.bind(sc))


func _on_drag_scroll_input(event: InputEvent, sc: ScrollContainer) -> void:
	var st: Dictionary = sc.get_meta("drag_state", {})
	if st.is_empty():
		return
	var begin: bool = false
	var end: bool = false
	var moved: bool = false
	var pos_y: float = 0.0
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			pos_y = mb.position.y
			if mb.pressed:
				begin = true
			else:
				end = true
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		pos_y = mm.position.y
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			moved = true
	elif event is InputEventScreenTouch:
		var stt: InputEventScreenTouch = event
		pos_y = stt.position.y
		if stt.pressed:
			begin = true
		else:
			end = true
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		pos_y = sd.position.y
		moved = true

	if begin:
		st["active"] = true
		st["start_y"] = pos_y
		st["start_scroll"] = sc.scroll_vertical
		st["captured"] = false
	elif end:
		st["active"] = false
		st["captured"] = false
	elif moved and st.get("active", false):
		var dy: float = pos_y - float(st["start_y"])
		if not st["captured"] and abs(dy) > SCROLL_DRAG_THRESHOLD:
			st["captured"] = true
		if st["captured"]:
			sc.scroll_vertical = int(float(st["start_scroll"]) - dy)
			sc.accept_event()


# ─── ZOOM / PAN ───────────────────────────────────────────────────────────────

func _on_btn_zoom_in() -> void:
	_apply_zoom(_zoom * ZOOM_STEP, stage.size * 0.5)


func _on_btn_zoom_out() -> void:
	_apply_zoom(_zoom / ZOOM_STEP, stage.size * 0.5)


func _on_btn_zoom_reset() -> void:
	_zoom = 1.0
	_zoom_layer.scale = Vector2.ONE
	_zoom_layer.position = Vector2.ZERO


func _apply_zoom(new_zoom: float, focus: Vector2) -> void:
	new_zoom = clamp(new_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, _zoom):
		return
	# Keep the world point under "focus" stationary on screen.
	var local: Vector2 = (focus - _zoom_layer.position) / _zoom
	_zoom = new_zoom
	_zoom_layer.scale = Vector2(new_zoom, new_zoom)
	_zoom_layer.position = focus - local * new_zoom
	_clamp_pan()


func _clamp_pan() -> void:
	var stage_size: Vector2 = stage.size
	var scaled: Vector2 = stage_size * _zoom
	var min_x: float = stage_size.x - scaled.x
	var min_y: float = stage_size.y - scaled.y
	var p: Vector2 = _zoom_layer.position
	if min_x >= 0.0:
		p.x = (stage_size.x - scaled.x) * 0.5
	else:
		p.x = clamp(p.x, min_x, 0.0)
	if min_y >= 0.0:
		p.y = (stage_size.y - scaled.y) * 0.5
	else:
		p.y = clamp(p.y, min_y, 0.0)
	_zoom_layer.position = p


func _on_stage_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(_zoom * ZOOM_STEP, mb.position)
			stage.accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(_zoom / ZOOM_STEP, mb.position)
			stage.accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			_pan_last = mb.position
			stage.accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_panning:
			_zoom_layer.position += mm.position - _pan_last
			_pan_last = mm.position
			_clamp_pan()
			stage.accept_event()
	elif event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		_apply_zoom(_zoom * mg.factor, mg.position)
		stage.accept_event()
	elif event is InputEventPanGesture:
		var pg: InputEventPanGesture = event
		if _zoom > 1.0:
			_zoom_layer.position -= pg.delta * 8.0
			_clamp_pan()
			stage.accept_event()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
			if _touches.size() < 2:
				_pinch_prev_dist = 0.0
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() == 2:
			var keys: Array = _touches.keys()
			var p1: Vector2 = _touches[keys[0]]
			var p2: Vector2 = _touches[keys[1]]
			var d: float = p1.distance_to(p2)
			var center: Vector2 = (p1 + p2) * 0.5
			if _pinch_prev_dist > 0.0 and d > 0.0:
				var factor: float = d / _pinch_prev_dist
				_apply_zoom(_zoom * factor, center)
			_pinch_prev_dist = d
			stage.accept_event()
		elif _touches.size() == 1 and _zoom > 1.0:
			_zoom_layer.position += sd.relative
			_clamp_pan()
			stage.accept_event()
