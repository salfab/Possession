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
	_build_overlays()
	new_game()


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
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_font_size_override("font_size", 14)
		_zoom_layer.add_child(lbl)
		_domain_labels[d_id] = lbl

	# Top status bar (HUD — fixed, not zoomed)
	_status_label = Label.new()
	_status_label.anchor_left = 0.05
	_status_label.anchor_right = 0.95
	_status_label.anchor_top = 0.0
	_status_label.anchor_bottom = 0.05
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 4)
	_status_label.add_theme_font_size_override("font_size", 16)
	stage.add_child(_status_label)

	# Ascendant label over the bottom bar
	_ascendant_label = Label.new()
	_ascendant_label.anchor_left = 0.4
	_ascendant_label.anchor_right = 0.6
	_ascendant_label.anchor_top = 0.92
	_ascendant_label.anchor_bottom = 0.99
	_ascendant_label.offset_left = 0
	_ascendant_label.offset_right = 0
	_ascendant_label.offset_top = 0
	_ascendant_label.offset_bottom = 0
	_ascendant_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascendant_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ascendant_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_ascendant_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_ascendant_label.add_theme_constant_override("outline_size", 4)
	_ascendant_label.add_theme_font_size_override("font_size", 18)
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


func _build_debug_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 0.92
	bar.anchor_bottom = 1.0
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 0
	bar.offset_bottom = -4
	bar.alignment = BoxContainer.ALIGNMENT_END
	bar.add_theme_constant_override("separation", 6)
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
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(a[1])
		bar.add_child(btn)


func _build_log_panel() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.anchor_left = 0.6
	_log_panel.anchor_right = 1.0
	_log_panel.anchor_top = 0.05
	_log_panel.anchor_bottom = 0.9
	_log_panel.offset_left = 0
	_log_panel.offset_right = -8
	_log_panel.offset_top = 0
	_log_panel.offset_bottom = 0
	_log_panel.visible = false
	add_child(_log_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.85)
	sb.border_color = Color(0.8, 0.7, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	_log_panel.add_theme_stylebox_override("panel", sb)

	var sc := ScrollContainer.new()
	_log_panel.add_child(sc)
	_log_rtl = RichTextLabel.new()
	_log_rtl.bbcode_enabled = true
	_log_rtl.fit_content = true
	_log_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_rtl.add_theme_color_override("default_color", Color(0.95, 0.9, 0.75))
	_log_rtl.add_theme_font_size_override("normal_font_size", 11)
	sc.add_child(_log_rtl)


# ─── REFRESH ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_status()
	_refresh_overlays()
	_refresh_log()


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
	_action_popup.size = Vector2i(220, 0)
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
