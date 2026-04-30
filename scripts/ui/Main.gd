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
var _liturgy_dialog: AcceptDialog
var _liturgy_rtl: RichTextLabel
var _decision_dialog: AcceptDialog
var _decision_content: VBoxContainer

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
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _build_liturgy_dialog() -> void:
	_liturgy_dialog = AcceptDialog.new()
	_liturgy_dialog.exclusive = true
	_liturgy_dialog.title = "Réponse liturgique"
	_liturgy_dialog.ok_button_text = "Continuer"
	_liturgy_dialog.dialog_text = ""
	_liturgy_dialog.min_size = Vector2i(680, 460)
	_liturgy_dialog.confirmed.connect(_on_liturgy_acknowledged)
	add_child(_liturgy_dialog)
	# Custom RichTextLabel as the dialog content (replaces the default Label).
	_liturgy_rtl = RichTextLabel.new()
	_liturgy_rtl.bbcode_enabled = true
	_liturgy_rtl.fit_content = true
	_liturgy_rtl.scroll_active = true
	_liturgy_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.custom_minimum_size = Vector2(640, 360)
	_liturgy_rtl.add_theme_font_size_override("normal_font_size", 22)
	_liturgy_rtl.add_theme_font_size_override("bold_font_size", 24)
	_liturgy_dialog.add_child(_liturgy_rtl)


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

	var sc := ScrollContainer.new()
	_log_panel.add_child(sc)
	_log_rtl = RichTextLabel.new()
	_log_rtl.bbcode_enabled = true
	_log_rtl.fit_content = true
	_log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_rtl.add_theme_color_override("default_color", Color(0.95, 0.9, 0.75))
	_log_rtl.add_theme_font_size_override("normal_font_size", 18)
	sc.add_child(_log_rtl)


# ─── REFRESH ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_status()
	_refresh_overlays()
	_refresh_log()
	_maybe_show_liturgy_dialog()
	_maybe_show_decision_dialog()


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


func _refresh_log() -> void:
	if _log_rtl == null:
		return
	var lines: Array = state.log
	var max_lines := 60
	var start: int = max(0, lines.size() - max_lines)
	var s := ""
	for i in range(start, lines.size()):
		s += String(lines[i]) + "\n"
	_log_rtl.text = s


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
	# Disable items based on legality
	for idx in POPUP_ACTIONS.size():
		var aid: int = POPUP_ACTIONS[idx]
		var legal: bool = false
		if aid == GameEnums.ActionId.INVESTIR:
			legal = GameRules.can_investir(state, p, d_id)
		elif aid == GameEnums.ActionId.EXPLOITER:
			legal = GameRules.can_exploiter(state, p, d_id)
		elif aid == GameEnums.ActionId.SCELLER:
			legal = GameRules.can_sceller(state, p, d_id)
		elif aid == GameEnums.ActionId.FISSURER:
			legal = GameRules.can_fissurer(state, p, d_id)
		_action_popup.set_item_disabled(idx, not legal)
	# Position the popup near the touch
	var mp: Vector2 = get_viewport().get_mouse_position()
	_action_popup.position = Vector2i(int(mp.x), int(mp.y))
	_action_popup.size = Vector2i(320, 0)
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
