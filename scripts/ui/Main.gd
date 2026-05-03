extends Control
# Plateau visuel : image board.png en background, hotspots normalisés
# sur les 5 domaines, popup d'actions au clic.

const SAVE_PATH := "user://save_game.json"

# Positions normalisées (0..1) des centres de domaines sur l'image.
# À ajuster en regardant l'image board.png si nécessaire.
# Domain hotspot centres + half-extents, normalised to the board's
# AspectRatioContainer (1.333 ratio). The board image places the 5 niches in
# a quincunx, shifted right because the left ~22% of the canvas is the
# STATIONS column. Each stone niche is roughly 13% of board width × 22% of
# board height, so DOMAIN_HALF ≈ (0.065, 0.11).
# If the alignment is still off, toggle the "Hot" debug button in the
# bottom bar to see the hit areas overlaid in cyan.
const DOMAIN_POS := {
	GameEnums.DomainId.AMBITION: Vector2(0.530, 0.240),
	GameEnums.DomainId.FOI:      Vector2(0.345, 0.460),
	GameEnums.DomainId.VOLONTE:  Vector2(0.530, 0.500),
	GameEnums.DomainId.DESIR:    Vector2(0.710, 0.460),
	GameEnums.DomainId.PEUR:     Vector2(0.530, 0.685),
}
const DOMAIN_HALF := Vector2(0.080, 0.085)

# Liturgy banners — one per Station I-V plus the Exorcism, on the right edge
# of the board. Width spans from Désir's right border (0.710 + 0.080 = 0.790)
# to the board edge, keeping the source image's 2.667:1 aspect ratio
# (banner_w × 1.333 / banner_h ≈ 2.667). Click → opens the fullscreen
# liturgy view with an Entraver button (Station VI opens the endgame card —
# the Exorcism has no in_integro/impedita variant and can't be entravé).
const LITURGY_BANNER_POS := {
	GameEnums.StationId.MURMURES:   Vector2(0.880, 0.180),
	GameEnums.StationId.TENTATION:  Vector2(0.880, 0.300),
	GameEnums.StationId.CHUTE:      Vector2(0.880, 0.420),
	GameEnums.StationId.CONFESSION: Vector2(0.880, 0.540),
	GameEnums.StationId.OFFICE:     Vector2(0.880, 0.660),
	GameEnums.StationId.EXORCISME:  Vector2(0.880, 0.780),
}
const LITURGY_BANNER_HALF := Vector2(0.090, 0.045)

const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.25

const SCROLL_DRAG_THRESHOLD := 8.0

@onready var stage: Control = $BoardAspect/Stage
@onready var board_aspect: AspectRatioContainer = $BoardAspect

var state: GameState
var manager: TurnManager
var pending_action: int = -1
var pending_kwargs: Dictionary = {}

# Created in _build_overlays
var _zoom_layer: Control            # parent scaled/translated of board+hotspots
var _hotspots: Dictionary = {}      # domain_id -> Button
var _debug_hotspots: bool = false   # cyan outline overlay for calibration
var _domain_badges: Dictionary = {} # domain_id -> DomainBadges (drawn controller/sealed/penitence indicators)
var _domain_dots: Dictionary = {}   # domain_id -> CorruptionDots
var _liturgy_banners: Dictionary = {}       # station_id -> PanelContainer (placeholder)
var _liturgy_banner_labels: Dictionary = {} # station_id -> Label (inside panel)
var _domain_marker_rows: Dictionary = {} # domain_id -> HFlowContainer (owned-Transgression chips)
var _status_label: Label
var _ascendant_label: Label
var _action_popup: PopupMenu
var _selected_domain: int = -1
var _log_rtl: RichTextLabel
var _log_panel: PanelContainer
var _log_scroll: ScrollContainer
var _liturgy_dialog: AcceptDialog
var _liturgy_rtl: RichTextLabel
var _liturgy_card_thumb: Control      # Card.tscn wrapped + clickable
var _decision_dialog: AcceptDialog
var _decision_content: VBoxContainer
var _endgame_dialog: AcceptDialog
var _endgame_rtl: RichTextLabel
var _endgame_image: TextureButton
var _endgame_shown: bool = false
var _trans_dialog: AcceptDialog
var _trans_content: VBoxContainer
var _trans_scroll: ScrollContainer

# "Placed transgressions" summary dialog — opened by tapping any marker on
# a domain. Two columns, one per demon, listing every Transgression they
# have on the board. Each entry is clickable → fullscreen flippable card.
var _placed_dialog: AcceptDialog
var _placed_list_red: VBoxContainer
var _placed_list_blue: VBoxContainer

# Per-player owned-transgressions side panels (top/bottom in portrait,
# left/right in landscape). Each panel lists the names of the
# transgressions the player owns; tapping a name opens the fullscreen
# flippable card view.
var _player_panel_red: PanelContainer
var _player_panel_blue: PanelContainer
var _player_list_red: HFlowContainer
var _player_list_blue: HFlowContainer
var _player_reserve_red: Label
var _player_reserve_blue: Label

# Floating Action Button + the popup menu it opens. Replaces the previous
# row of buttons across the bottom of the screen.
var _fab: Button
var _fab_menu: PopupMenu

# Latches the most recently-shown Station id so _refresh_status can fire the
# intro animation only when the value actually changes (not on every refresh).
# -1 sentinel = "no station shown yet" → first station opens silently.
var _last_seen_station: int = -1
var _fullscreen_card_dialog: AcceptDialog
var _fullscreen_card_node: Card               # composed view (transgression / liturgy)
var _fullscreen_card_image: TextureRect       # static fallback (Exorcism)
var _fullscreen_card_aspect: AspectRatioContainer
var _fullscreen_card_flip_btn: Button
var _fullscreen_card_entraver_btn: Button
# Small popup that explains the targeting rule of a Liturgy. Triggered by
# tapping the badge slot on a fullscreen Liturgy card.
var _targeting_dialog: AcceptDialog
# Binding for the currently shown composed card.
# {"kind": "transgression", "tid": String, "face": int}
# {"kind": "liturgy", "station": int, "impedita": bool}
var _fullscreen_card_binding: Dictionary = {}

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
const POPUP_LABEL_KEYS := {
	GameEnums.ActionId.INVESTIR:  "action.investir",
	GameEnums.ActionId.EXPLOITER: "action.exploiter",
	GameEnums.ActionId.SCELLER:   "action.sceller",
	GameEnums.ActionId.FISSURER:  "action.fissurer",
}

# Domain-popup item ids ≥ these offsets are dynamic entries appended each
# time the popup opens. Both ranges sit well above the ActionId enum (0-7)
# to avoid collisions. We reserve 100 ids per kind, which is plenty (the
# game has 10 transgressions max).
const PROVOKE_ITEM_ID_BASE := 100
const AMPLIFY_ITEM_ID_BASE := 200


func _ready() -> void:
	_apply_theme()
	_build_overlays()
	I18n.locale_changed.connect(_relocalize)
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
	# Reset the station-intro latch so the splash doesn't fire when starting
	# a fresh game from mid-Exorcisme.
	_last_seen_station = -1
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

		# Two-row layout for the bottom strip of each Domain hotspot :
		#   Row A (top, ~6 % of board height) : transgression markers
		#       (Scandale circles, Infamie diamonds) and corruption squares.
		#   Row B (bottom, ~4 %)              : DomainBadges — controller /
		#       sealed / penitence drawn as primitives so they don't depend
		#       on font glyph coverage.
		# Both anchored as children of _zoom_layer so they zoom with the board.

		var chip_row := HFlowContainer.new()
		chip_row.anchor_left = pos.x - DOMAIN_HALF.x
		chip_row.anchor_right = pos.x + DOMAIN_HALF.x
		chip_row.anchor_top = pos.y + DOMAIN_HALF.y - 0.10
		chip_row.anchor_bottom = pos.y + DOMAIN_HALF.y - 0.04
		chip_row.offset_left = 0
		chip_row.offset_right = 0
		chip_row.offset_top = 0
		chip_row.offset_bottom = 0
		chip_row.alignment = HFlowContainer.ALIGNMENT_CENTER
		chip_row.add_theme_constant_override("h_separation", 4)
		chip_row.add_theme_constant_override("v_separation", 2)
		chip_row.mouse_filter = Control.MOUSE_FILTER_PASS
		_zoom_layer.add_child(chip_row)
		_domain_marker_rows[d_id] = chip_row

		# CorruptionDots is persistent — kept across refreshes — so it is
		# created here and re-attached at the end of the chip row whenever
		# _refresh_domain_markers rebuilds the marker chips.
		var dots := CorruptionDots.new()
		chip_row.add_child(dots)
		_domain_dots[d_id] = dots

		var badges_row := HBoxContainer.new()
		badges_row.anchor_left = pos.x - DOMAIN_HALF.x
		badges_row.anchor_right = pos.x + DOMAIN_HALF.x
		badges_row.anchor_top = pos.y + DOMAIN_HALF.y - 0.04
		badges_row.anchor_bottom = pos.y + DOMAIN_HALF.y
		badges_row.offset_left = 0
		badges_row.offset_right = 0
		badges_row.offset_top = 0
		badges_row.offset_bottom = 0
		badges_row.alignment = BoxContainer.ALIGNMENT_CENTER
		badges_row.add_theme_constant_override("separation", 6)
		badges_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zoom_layer.add_child(badges_row)

		var badges := DomainBadges.new()
		badges_row.add_child(badges)
		_domain_badges[d_id] = badges

	# Liturgy banners on the right edge — one per Station I-V, click → opens
	# the fullscreen liturgical card with an Entraver button.
	_build_liturgy_banners()

	# Top status bar (HUD — fixed, not zoomed)
	_status_label = Label.new()
	_status_label.anchor_left = 0.02
	_status_label.anchor_right = 0.98
	_status_label.anchor_top = 0.0
	_status_label.anchor_bottom = 0.08
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_status_label.tooltip_text = I18n.t("ui.tooltip.station_card")
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
		_action_popup.add_item(I18n.t(POPUP_LABEL_KEYS[aid]), aid)
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
	# Two-column "placed transgressions" summary opened by domain markers
	_build_placed_transgressions_dialog()


func _build_liturgy_dialog() -> void:
	_liturgy_dialog = AcceptDialog.new()
	_liturgy_dialog.exclusive = true
	_liturgy_dialog.title = I18n.t("ui.dialog.title.liturgy")
	_liturgy_dialog.ok_button_text = I18n.t("ui.dialog.continue")
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

	# Composed card thumbnail (Card.tscn) on the left of the dialog. The
	# concrete content is set in _show_liturgy_dialog().
	_liturgy_card_thumb = _make_card_thumb(Vector2(180, 252))
	(_liturgy_card_thumb.get_meta("click_btn") as Button).pressed.connect(_on_liturgy_image_clicked)
	hbox.add_child(_liturgy_card_thumb)

	_liturgy_rtl = RichTextLabel.new()
	_liturgy_rtl.bbcode_enabled = true
	_liturgy_rtl.fit_content = true
	_liturgy_rtl.scroll_active = false
	_liturgy_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liturgy_rtl.custom_minimum_size = Vector2(200, 240)
	_liturgy_rtl.add_theme_font_size_override("normal_font_size", 22)
	_liturgy_rtl.add_theme_font_size_override("bold_font_size", 24)
	hbox.add_child(_liturgy_rtl)


func _build_debug_bar() -> void:
	# Single Floating Action Button bottom-right. Tap → PopupMenu with all
	# the actions that used to live in the bottom action bar (zoom, locale,
	# Trans., New game, next station, Puiser, Journal, Hotspots).
	# Replaces the previous full-width row of buttons because on iPad the
	# row pushed the playable area down too far.
	_fab = Button.new()
	_fab.text = "≡"
	_fab.add_theme_font_size_override("font_size", 32)
	_fab.tooltip_text = I18n.t("ui.fab.tooltip")
	_fab.set_meta("i18n_tooltip_key", "ui.fab.tooltip")
	_fab.anchor_left = 1.0
	_fab.anchor_top = 1.0
	_fab.anchor_right = 1.0
	_fab.anchor_bottom = 1.0
	_fab.offset_left = -76
	_fab.offset_top = -76
	_fab.offset_right = -12
	_fab.offset_bottom = -12
	# Round-ish look via a stylebox.
	var fab_sb := StyleBoxFlat.new()
	fab_sb.bg_color = Color(0.18, 0.06, 0.22, 0.95)
	fab_sb.set_corner_radius_all(32)
	fab_sb.border_color = Color(0.85, 0.65, 0.30)
	fab_sb.set_border_width_all(2)
	fab_sb.shadow_color = Color(0, 0, 0, 0.55)
	fab_sb.shadow_size = 8
	_fab.add_theme_stylebox_override("normal", fab_sb)
	_fab.add_theme_stylebox_override("hover", fab_sb)
	_fab.add_theme_stylebox_override("pressed", fab_sb)
	_fab.add_theme_stylebox_override("focus", fab_sb)
	_fab.pressed.connect(_on_fab_pressed)
	add_child(_fab)

	# PopupMenu that the FAB opens. Items are recreated on every popup so
	# the labels follow the current locale and "Puiser" can be toggled
	# disabled depending on the active player's Réserve.
	_fab_menu = PopupMenu.new()
	_fab_menu.id_pressed.connect(_on_fab_menu_pressed)
	add_child(_fab_menu)


# Stable item ids for the FAB popup. Same range as the popup at the top of
# the file (PROVOKE_ITEM_ID_BASE = 100), but we use 1000+ here so they
# never collide with anything else.
const FAB_ZOOM_OUT   := 1000
const FAB_ZOOM_RESET := 1001
const FAB_ZOOM_IN    := 1002
const FAB_LANG       := 1003
const FAB_TRANS      := 1004
const FAB_NEW_GAME   := 1005
const FAB_NEXT_ST    := 1006
const FAB_PUISER     := 1007
const FAB_JOURNAL    := 1008
const FAB_HOTSPOTS   := 1009


func _on_fab_pressed() -> void:
	_fab_menu.clear()
	_fab_menu.add_item("−  " + I18n.t("ui.btn.zoom_out_label"), FAB_ZOOM_OUT)
	_fab_menu.add_item("⊙  " + I18n.t("ui.btn.zoom_reset_label"), FAB_ZOOM_RESET)
	_fab_menu.add_item("+  " + I18n.t("ui.btn.zoom_in_label"), FAB_ZOOM_IN)
	_fab_menu.add_separator()
	_fab_menu.add_item(I18n.t("ui.btn.toggle_lang") + "  —  " + I18n.t("ui.btn.toggle_lang.tooltip"), FAB_LANG)
	_fab_menu.add_separator()
	_fab_menu.add_item(I18n.t("ui.btn.transgressions"), FAB_TRANS)
	_fab_menu.add_item(I18n.t("ui.btn.new_game"), FAB_NEW_GAME)
	_fab_menu.add_item(I18n.t("ui.btn.next_station"), FAB_NEXT_ST)
	# Puiser is shown but greyed when the active player still has Corruption.
	var puiser_idx := _fab_menu.get_item_count()
	_fab_menu.add_item(I18n.t("ui.btn.puiser") + "  —  " + I18n.t("ui.btn.puiser.tooltip"), FAB_PUISER)
	if state != null and not GameRules.can_puiser(state, state.active_player):
		_fab_menu.set_item_disabled(puiser_idx, true)
	_fab_menu.add_separator()
	_fab_menu.add_item(I18n.t("ui.btn.journal"), FAB_JOURNAL)
	_fab_menu.add_item(I18n.t("ui.btn.hotspots"), FAB_HOTSPOTS)
	# Position just above the FAB.
	var fab_pos := _fab.get_screen_position()
	var fab_size := _fab.size
	_fab_menu.position = Vector2i(int(fab_pos.x - 240), int(fab_pos.y - 360))
	_fab_menu.popup()


func _on_fab_menu_pressed(id: int) -> void:
	match id:
		FAB_ZOOM_OUT:   _on_btn_zoom_out()
		FAB_ZOOM_RESET: _on_btn_zoom_reset()
		FAB_ZOOM_IN:    _on_btn_zoom_in()
		FAB_LANG:       _on_btn_toggle_lang()
		FAB_TRANS:      _on_btn_transgressions()
		FAB_NEW_GAME:   _on_btn_new_game()
		FAB_NEXT_ST:    _on_btn_force_next_station()
		FAB_PUISER:     _on_btn_puiser()
		FAB_JOURNAL:    _on_btn_toggle_log()
		FAB_HOTSPOTS:   _on_btn_toggle_hotspots()


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
	_refresh_fab_highlight()
	_maybe_show_liturgy_dialog()
	_maybe_show_decision_dialog()
	_maybe_show_endgame_dialog()


# When Puiser dans l'Ombre is the active player's only legal action (Réserve
# at 0), tint the FAB so the user knows there's a forced action waiting in
# the menu. Otherwise restore the default styling.
func _refresh_fab_highlight() -> void:
	if _fab == null or state == null:
		return
	var puiser_legal: bool = (not state.game_over) \
		and (not state.has_pending_decisions()) \
		and GameRules.can_puiser(state, state.active_player)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(32)
	sb.set_border_width_all(2)
	sb.shadow_size = 8
	if puiser_legal:
		# Forced-action mode : crimson / gold halo, brighter ink.
		sb.bg_color = Color(0.30, 0.06, 0.12, 0.95)
		sb.border_color = Color(0.95, 0.55, 0.20)
		sb.shadow_color = Color(0.95, 0.55, 0.20, 0.55)
		_fab.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	else:
		sb.bg_color = Color(0.18, 0.06, 0.22, 0.95)
		sb.border_color = Color(0.85, 0.65, 0.30)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		_fab.remove_theme_color_override("font_color")
	for state_name in ["normal", "hover", "pressed", "focus"]:
		_fab.add_theme_stylebox_override(state_name, sb)


func _refresh_status() -> void:
	if state.game_over:
		_status_label.text = I18n.t("ui.game_over", [GameEnums.player_name(state.winner)])
		return
	var st: int = state.current_station
	var st_name: String = GameEnums.STATION_NAMES[st]
	var pulses: int = GameEnums.STATION_PULSES[st]
	var init_p: int = GameEnums.STATION_INITIATIVE[st]
	_status_label.text = I18n.t("ui.status_label.fmt", [
		st_name, state.current_pulse, pulses,
		GameEnums.player_name(state.active_player),
		GameEnums.player_name(init_p),
	])
	# Fire the intro animation when the station id actually changes.
	# _last_seen_station == -1 means we just booted the game — skip the
	# splash on the very first station so the intro doesn't fire on
	# new_game().
	if _last_seen_station >= 0 and st != _last_seen_station:
		_play_station_intro(st)
	_last_seen_station = st


# Big station-name flash that fades in / scales up / holds / fades out.
# Used as a soft cue between Stations II-VI; the very first Station opens
# silently (the player has just hit "Nouvelle partie" and the title is
# visible in the status bar already).
func _play_station_intro(station_id: int) -> void:
	var lbl := Label.new()
	lbl.text = String(GameEnums.STATION_NAMES.get(station_id, ""))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.32
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 0.55
	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.55, 0.55)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	# Wait one frame so the label has a real size before we anchor the pivot.
	await get_tree().process_frame
	lbl.pivot_offset = lbl.size * 0.5
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(lbl, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func _refresh_overlays() -> void:
	for d_id in DOMAIN_POS.keys():
		if not _domain_badges.has(d_id):
			continue
		var d := state.domain(d_id)
		# Row A — chips (markers + corruption squares). _refresh_domain_markers
		# rebuilds the markers and updates the dots count.
		_refresh_domain_markers(d_id)
		# Row B — drawn badges (controller diamond / sealed padlock / penitence cross).
		var ctrl: int = state.controller_of(d_id)
		var ctrl_color: Color = Color(0, 0, 0, 0)
		var ctrl_letter: String = ""
		if ctrl != GameEnums.PlayerId.NONE:
			ctrl_color = GameEnums.player_color_light(ctrl)
			ctrl_letter = GameEnums.player_name(ctrl).substr(0, 1)
		(_domain_badges[d_id] as DomainBadges).set_state(
			ctrl_color, ctrl_letter, state.is_sealed(d_id), state.is_in_penitence(d_id))
	# Ascendant only (per-player Corruption pool now shown inside each
	# coloured player panel).
	_ascendant_label.text = "Asc %+d" % state.ascendant
	_refresh_liturgy_banners()


# ─── Domain transgression markers ─────────────────────────────────────────────

func _refresh_domain_markers(d_id: int) -> void:
	var row: HFlowContainer = _domain_marker_rows.get(d_id)
	var dots: CorruptionDots = _domain_dots.get(d_id)
	if row == null or dots == null:
		return
	# Detach the persistent CorruptionDots so it isn't queue_freed alongside
	# the transgression markers.
	if dots.get_parent() == row:
		row.remove_child(dots)
	for c in row.get_children():
		c.queue_free()
	if state == null:
		row.add_child(dots)
		return
	var d := state.domain(d_id)
	# Order : Scandale circles, then Infamie diamonds, then the corruption
	# squares at the very end — matches the user's preference for one row of
	# circles + diamonds + colour-tinted squares.
	for ti in d.scandals:
		row.add_child(_make_transgression_marker(ti, false))
	for ti in d.infamies:
		row.add_child(_make_transgression_marker(ti, true))
	dots.set_counts(d.red_corruption, d.blue_corruption)
	row.add_child(dots)


func _make_transgression_marker(ti: GameState.TransgressionInstance, infamy: bool) -> Control:
	var col: Color = GameEnums.player_color_light(ti.owner)
	var marker := TransgressionMarker.new(col, infamy)
	var face_key: String = "face.infamie" if infamy else "face.scandale"
	var name_str: String = TransgressionData.name_of(ti.def_id)
	marker.tooltip_text = "%s — %s (%s)" % [name_str, I18n.t(face_key), GameEnums.player_name(ti.owner)]
	# Capture by value for the lambda
	var captured_tid: String = ti.def_id
	var captured_name: String = name_str
	var captured_face_is_infamy: bool = infamy
	marker.pressed.connect(func(): _on_domain_marker_clicked(captured_tid, captured_name, captured_face_is_infamy))
	return marker


func _on_domain_marker_clicked(_tid: String, _name_str: String, _is_infamy: bool) -> void:
	# Tapping any marker (Scandale or Infamie, regardless of which one) opens
	# the same summary dialog: a two-column listing of every placed
	# Transgression, one column per demon. From there the player can click an
	# entry to see the actual card fullscreen.
	_show_placed_transgressions_dialog()


# ─── Liturgy banners (right edge of the board) ────────────────────────────────

func _build_liturgy_banners() -> void:
	for st in LITURGY_BANNER_POS:
		var pos: Vector2 = LITURGY_BANNER_POS[st]
		# Outer Control hosts the image (TextureRect filling the panel) + the
		# explanatory text Label overlaid on the cartouche area to the right.
		var panel := Control.new()
		panel.anchor_left = pos.x - LITURGY_BANNER_HALF.x
		panel.anchor_right = pos.x + LITURGY_BANNER_HALF.x
		panel.anchor_top = pos.y - LITURGY_BANNER_HALF.y
		panel.anchor_bottom = pos.y + LITURGY_BANNER_HALF.y
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_liturgy_banner_input.bind(st))
		panel.clip_contents = true

		# Background : either the painted banner image (when shipped) or a
		# stylebox placeholder. _refresh_liturgy_banners decides each frame
		# which is shown based on which textures resolve.
		var tex_rect := TextureRect.new()
		tex_rect.name = "Texture"
		tex_rect.anchor_right = 1.0
		tex_rect.anchor_bottom = 1.0
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(tex_rect)

		var fallback := PanelContainer.new()
		fallback.name = "Fallback"
		fallback.anchor_right = 1.0
		fallback.anchor_bottom = 1.0
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(fallback)

		# Label sits on top of both, anchored to the right cartouche : 90 %
		# of the banner's height (5 % top + 5 % bottom margin), 70 % of its
		# width on the right (small inset offsets for readability).
		var lbl := Label.new()
		lbl.anchor_left = 0.30
		lbl.anchor_right = 1.0
		lbl.anchor_top = 0.05
		lbl.anchor_bottom = 0.95
		lbl.offset_left = 6
		lbl.offset_right = -10
		lbl.offset_top = 0
		lbl.offset_bottom = 0
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.18, 0.10, 0.05))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.clip_contents = true
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(lbl)

		_zoom_layer.add_child(panel)
		_liturgy_banners[st] = panel
		_liturgy_banner_labels[st] = lbl


# Refreshes each banner's image / fallback styling and the cartouche text
# based on whether the response has been entraved (impedita) or not
# (in_integro). Called from _refresh_overlays.
func _refresh_liturgy_banners() -> void:
	for st in _liturgy_banners.keys():
		var panel: Control = _liturgy_banners[st]
		var lbl: Label = _liturgy_banner_labels[st]
		var tex_rect: TextureRect = panel.get_node("Texture") as TextureRect
		var fallback: PanelContainer = panel.get_node("Fallback") as PanelContainer
		# Station VI is the Exorcism — it has no LiturgicalResponse, no
		# in_integro/impedita, and can't be entravé. One fixed banner image
		# and one fixed cartouche line.
		var is_exorcism: bool = st == GameEnums.StationId.EXORCISME
		var entraved: bool = (not is_exorcism) and state != null and GameRules.is_response_entraved(state, st)
		var resp: Dictionary = LiturgicalResponseData.get_response(st)
		var resp_id: String = String(resp.get("id", ""))

		# Pick the banner image for the current state, fall back to the in-
		# integro variant if the impedita one isn't shipped yet.
		var mode: String = "impedita" if entraved else "in_integro"
		var path: String
		var alt_path: String = ""
		if is_exorcism:
			path = "res://assets/cards/liturgy_banners/exorcisme.webp"
		else:
			path = "res://assets/cards/liturgy_banners/%s_%s.webp" % [resp_id, mode]
			alt_path = "res://assets/cards/liturgy_banners/%s_in_integro.webp" % resp_id
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		elif alt_path != "" and ResourceLoader.exists(alt_path):
			tex = load(alt_path) as Texture2D

		if tex != null:
			tex_rect.texture = tex
			tex_rect.visible = true
			fallback.visible = false
		else:
			tex_rect.texture = null
			tex_rect.visible = false
			fallback.visible = true
			# Placeholder stylebox tinted by entrave state.
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(6)
			sb.set_content_margin_all(4)
			sb.set_border_width_all(2)
			if entraved:
				sb.bg_color = Color(0.20, 0.05, 0.08, 0.92)
				sb.border_color = Color(0.85, 0.25, 0.30)
			else:
				sb.bg_color = Color(0.06, 0.05, 0.04, 0.92)
				sb.border_color = Color(0.85, 0.65, 0.25)
			fallback.add_theme_stylebox_override("panel", sb)

		# Cartouche text — ultra-minimal one-liner, distinct from the full
		# liturgy.<id>.<mode> text shown on the card itself.
		var text_key: String = "banner.exorcisme.special" if is_exorcism else "banner.%s.%s" % [resp_id, mode]
		lbl.text = I18n.t(text_key)
		# Dim the parchment text a notch when impedita, to suggest "this is
		# the corrupted face".
		lbl.add_theme_color_override("font_color",
			Color(0.45, 0.10, 0.06) if entraved else Color(0.18, 0.10, 0.05))


# Tap or release on a banner — opens the fullscreen liturgical card view for
# that Station, with the Entraver button if the action is currently legal.
func _on_liturgy_banner_input(event: InputEvent, station: int) -> void:
	var pressed_release: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			pressed_release = true
	elif event is InputEventScreenTouch:
		var st_event: InputEventScreenTouch = event
		if not st_event.pressed:
			pressed_release = true
	if not pressed_release:
		return
	if state == null:
		return
	# Station VI has no liturgical response — show the static endgame card.
	if station == GameEnums.StationId.EXORCISME:
		var endgame_tex := CardImages.exorcisme()
		if endgame_tex != null:
			_show_fullscreen_card(endgame_tex, I18n.t("ui.dialog.title.endgame"))
		return
	var resp: Dictionary = LiturgicalResponseData.get_response(station)
	if resp.is_empty():
		return
	var resp_name: String = String(resp.get("name", "?"))
	var imp: bool = GameRules.is_response_entraved(state, station)
	_show_fullscreen_liturgy(station, imp, resp_name)


# ─── Placed transgressions dialog (two columns, one per demon) ────────────────

func _build_placed_transgressions_dialog() -> void:
	_placed_dialog = AcceptDialog.new()
	_placed_dialog.exclusive = true
	_placed_dialog.title = I18n.t("ui.dialog.title.placed")
	_placed_dialog.ok_button_text = I18n.t("ui.dialog.close")
	_placed_dialog.dialog_text = ""
	_placed_dialog.min_size = Vector2i(640, 480)
	add_child(_placed_dialog)
	_make_dialog_touch_friendly(_placed_dialog)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placed_dialog.add_child(hbox)

	var bundle_red: Dictionary = _build_placed_column(GameEnums.PlayerId.RED)
	var bundle_blue: Dictionary = _build_placed_column(GameEnums.PlayerId.BLUE)
	_placed_list_red = bundle_red["list"]
	_placed_list_blue = bundle_blue["list"]
	hbox.add_child(bundle_red["panel"])
	hbox.add_child(bundle_blue["panel"])


# Builds one column. Returns {panel, list} so the caller wires the panel into
# the parent container and stashes the list ref for later refresh.
func _build_placed_column(pid: int) -> Dictionary:
	var accent: Color = GameEnums.player_color_light(pid)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.08, 0.95)
	sb.border_color = accent
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = GameEnums.player_name(pid)
	title.set_meta("i18n_player_id", pid)
	title.add_theme_color_override("font_color", accent)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	return {"panel": panel, "list": list}


func _show_placed_transgressions_dialog() -> void:
	_populate_placed_transgressions_dialog()
	_popup_dialog_fullscreen(_placed_dialog)


func _populate_placed_transgressions_dialog() -> void:
	if _placed_list_red == null or _placed_list_blue == null:
		return
	for c in _placed_list_red.get_children():
		c.queue_free()
	for c in _placed_list_blue.get_children():
		c.queue_free()
	if state == null:
		return
	# Walk every domain, collect each placed instance with its face.
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		for ti in d.scandals:
			_add_placed_entry(ti, false, d_id)
		for ti in d.infamies:
			_add_placed_entry(ti, true, d_id)
	# Empty hint
	if _placed_list_red.get_child_count() == 0:
		_placed_list_red.add_child(_make_empty_hint())
	if _placed_list_blue.get_child_count() == 0:
		_placed_list_blue.add_child(_make_empty_hint())


func _add_placed_entry(ti: GameState.TransgressionInstance, infamy: bool, domain_id: int) -> void:
	var col_list: VBoxContainer = _placed_list_red if ti.owner == GameEnums.PlayerId.RED else _placed_list_blue
	var name_str: String = TransgressionData.name_of(ti.def_id)
	var face_str: String = I18n.t("face.infamie") if infamy else I18n.t("face.scandale")
	var dom_str: String = GameEnums.DOMAIN_NAMES.get(domain_id, "?")

	var btn := Button.new()
	btn.text = "%s\n%s · %s" % [name_str, face_str, dom_str]
	btn.add_theme_font_size_override("font_size", 20)
	btn.custom_minimum_size = Vector2(0, 64)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Tint the label with the face colour for quick scan.
	var fcol: Color = Color(1.0, 0.55, 1.0) if infamy else Color(1.0, 0.78, 0.45)
	btn.add_theme_color_override("font_color", fcol)
	btn.tooltip_text = I18n.t("ui.tooltip.see_card")
	var captured_tid: String = ti.def_id
	var captured_name: String = name_str
	var captured_is_infamy: bool = infamy
	btn.pressed.connect(func(): _open_placed_card(captured_tid, captured_name, captured_is_infamy))
	col_list.add_child(btn)


func _open_placed_card(tid: String, name_str: String, is_infamy: bool) -> void:
	var face: int = GameEnums.TransgressionFace.INFAMIE if is_infamy else GameEnums.TransgressionFace.SCANDALE
	_show_fullscreen_transgression(tid, face, name_str)


# ─── Per-player owned-transgressions side panels ──────────────────────────────

func _build_player_transgression_panels() -> void:
	var bundle_red: Dictionary = _build_player_panel(GameEnums.PlayerId.RED,  GameEnums.player_color_light(GameEnums.PlayerId.RED))
	var bundle_blue: Dictionary = _build_player_panel(GameEnums.PlayerId.BLUE, GameEnums.player_color_light(GameEnums.PlayerId.BLUE))
	_player_panel_red = bundle_red["panel"]
	_player_list_red = bundle_red["list"]
	_player_reserve_red = bundle_red["reserve"]
	_player_panel_blue = bundle_blue["panel"]
	_player_list_blue = bundle_blue["list"]
	_player_reserve_blue = bundle_blue["reserve"]
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
	title.text = I18n.t("ui.player_panel.title", [GameEnums.player_name(pid)])
	title.set_meta("i18n_player_id", pid)  # used by _relocalize to refresh
	title.add_theme_color_override("font_color", accent)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Available-Corruption pool. Refreshed in _refresh_player_transgression_panels.
	var reserve := Label.new()
	reserve.text = ""
	reserve.set_meta("i18n_reserve_pid", pid)
	reserve.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	reserve.add_theme_color_override("font_outline_color", Color.BLACK)
	reserve.add_theme_constant_override("outline_size", 3)
	reserve.add_theme_font_size_override("font_size", 18)
	reserve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(reserve)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 6)
	list.add_theme_constant_override("v_separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	return {"panel": panel, "list": list, "reserve": reserve}


func _layout_player_transgression_panels() -> void:
	if _player_panel_red == null or _player_panel_blue == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var portrait: bool = vp.y > vp.x
	# Push the board to the right in landscape so the left column has room
	# for the two player panels stacked vertically without overlapping the
	# board artwork. In portrait the board still fills the full width.
	if board_aspect != null:
		if portrait:
			board_aspect.anchor_left = 0.0
		else:
			board_aspect.anchor_left = 0.26
	if portrait:
		# Top strip (Red) and bottom strip (Blue), full width.
		# Sandwich between the status label (~0..0.08) and the ascendant
		# label (~0.78..0.86) / FAB at the bottom.
		_set_anchors(_player_panel_red,  0.0, 0.08, 1.0, 0.20, 4, 4, 0, -2)
		_set_anchors(_player_panel_blue, 0.0, 0.65, 1.0, 0.77, 4, -2, 0, 0)
	else:
		# Both panels on the LEFT, stacked vertically, with no overlap.
		# Width = 0..0.25 of viewport (≈ 256 px on a 1024-wide iPad).
		_set_anchors(_player_panel_red,  0.0, 0.04, 0.25, 0.50, 4, 4, -4, -2)
		_set_anchors(_player_panel_blue, 0.0, 0.50, 0.25, 0.96, 4, 2, -4, -4)


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
	# Available-Corruption pool, displayed inside each player's coloured panel.
	if _player_reserve_red != null:
		var n_r: int = state.available_corruption[GameEnums.PlayerId.RED]
		_player_reserve_red.text = I18n.t("ui.player_panel.reserve", [n_r, ("s" if n_r != 1 else "")])
	if _player_reserve_blue != null:
		var n_b: int = state.available_corruption[GameEnums.PlayerId.BLUE]
		_player_reserve_blue.text = I18n.t("ui.player_panel.reserve", [n_b, ("s" if n_b != 1 else "")])
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
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.tooltip_text = I18n.t("ui.tooltip.see_card")
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
	lbl.text = I18n.t("ui.player_panel.empty")
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	return lbl


func _on_player_transgression_clicked(tid: String, face: int, name_str: String) -> void:
	_show_fullscreen_transgression(tid, face, name_str)


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
		state.add_log(I18n.t("log.pending_decision_unhandled"))
		_refresh_log()
		return
	_selected_domain = d_id
	var p: int = state.active_player
	# Build labels enriched with the legality reason if illegal.
	for idx in POPUP_ACTIONS.size():
		var aid: int = POPUP_ACTIONS[idx]
		var why: String = ""
		var label_str: String
		if aid == GameEnums.ActionId.INVESTIR:
			why = GameRules.why_cannot_investir(state, p, d_id)
			label_str = "%s %s" % [I18n.t(POPUP_LABEL_KEYS[aid]), GameEnums.DOMAIN_NAMES[d_id]]
		elif aid == GameEnums.ActionId.EXPLOITER:
			why = GameRules.why_cannot_exploiter(state, p, d_id)
			# Show the actual gain so the player doesn't have to guess.
			var gain: int = GameRules.production_of(state, d_id, p)
			label_str = I18n.t("ui.popup.exploit_gain", [
				GameEnums.DOMAIN_NAMES[d_id], gain, ("s" if gain != 1 else ""),
			])
		elif aid == GameEnums.ActionId.SCELLER:
			why = GameRules.why_cannot_sceller(state, p, d_id)
			label_str = "%s %s" % [I18n.t(POPUP_LABEL_KEYS[aid]), GameEnums.DOMAIN_NAMES[d_id]]
		elif aid == GameEnums.ActionId.FISSURER:
			why = GameRules.why_cannot_fissurer(state, p, d_id)
			label_str = "%s %s" % [I18n.t(POPUP_LABEL_KEYS[aid]), GameEnums.DOMAIN_NAMES[d_id]]
		else:
			label_str = "%s %s" % [I18n.t(POPUP_LABEL_KEYS[aid]), GameEnums.DOMAIN_NAMES[d_id]]
		if why != "":
			label_str += "  —  " + why
		_action_popup.set_item_text(idx, label_str)
		_action_popup.set_item_disabled(idx, why != "")

	# Append dynamic entries (Provoquer / Amplifier) below the four base
	# actions. Item ids use distinct ranges to avoid colliding with the
	# ActionId enum.
	# Strip leftovers from a previous click first.
	while _action_popup.get_item_count() > POPUP_ACTIONS.size():
		_action_popup.remove_item(POPUP_ACTIONS.size())

	# Provokable: any Transgression the active player can legally provoke
	# using this domain as the origin.
	var provokable_tids: Array = []
	for tid in TransgressionData.ALL_IDS:
		if GameRules.why_cannot_provoquer(state, p, tid) != "":
			continue
		var origins: Array = GameRules.transgression_origin_options(p, tid)
		if d_id in origins:
			provokable_tids.append(tid)
	for i in provokable_tids.size():
		var tid: String = provokable_tids[i]
		var name_str: String = TransgressionData.name_of(tid)
		var label: String = I18n.t("ui.popup.provoke_in", [name_str, GameEnums.DOMAIN_NAMES[d_id]])
		_action_popup.add_item(label, PROVOKE_ITEM_ID_BASE + i)
	_action_popup.set_meta("provokable_tids", provokable_tids)
	_action_popup.set_meta("provoke_origin", d_id)

	# Amplifiable: any Scandale instance the active player owns whose origin
	# domain is this one and that's currently amplifiable (sealed by them,
	# not in penitence, enough Corruption).
	var amplifiable_tids: Array = []
	var dom: GameState.DomainState = state.domain(d_id)
	for ti in dom.scandals:
		if ti.owner != p:
			continue
		if GameRules.why_cannot_amplifier(state, p, ti.def_id) != "":
			continue
		amplifiable_tids.append(ti.def_id)
	for i in amplifiable_tids.size():
		var tid: String = amplifiable_tids[i]
		var name_str: String = TransgressionData.name_of(tid)
		var label: String = I18n.t("ui.popup.amplify_in", [name_str, GameEnums.DOMAIN_NAMES[d_id]])
		_action_popup.add_item(label, AMPLIFY_ITEM_ID_BASE + i)
	_action_popup.set_meta("amplifiable_tids", amplifiable_tids)

	# Position the popup near the touch
	var mp: Vector2 = get_viewport().get_mouse_position()
	_action_popup.position = Vector2i(int(mp.x), int(mp.y))
	_action_popup.size = Vector2i(540, 0)
	_action_popup.popup()


func _on_popup_action(action_id: int) -> void:
	if _selected_domain < 0:
		return
	var result: Dictionary
	if action_id >= AMPLIFY_ITEM_ID_BASE:
		var idx: int = action_id - AMPLIFY_ITEM_ID_BASE
		var tids: Array = _action_popup.get_meta("amplifiable_tids", [])
		if idx < 0 or idx >= tids.size():
			_selected_domain = -1
			return
		result = manager.perform_action(GameEnums.ActionId.AMPLIFIER, {"def_id": String(tids[idx])})
	elif action_id >= PROVOKE_ITEM_ID_BASE:
		var idx: int = action_id - PROVOKE_ITEM_ID_BASE
		var tids: Array = _action_popup.get_meta("provokable_tids", [])
		var origin: int = int(_action_popup.get_meta("provoke_origin", -1))
		if idx < 0 or idx >= tids.size() or origin < 0:
			_selected_domain = -1
			return
		result = manager.perform_action(GameEnums.ActionId.PROVOQUER, {"def_id": String(tids[idx]), "origin": origin})
	else:
		result = manager.perform_action(action_id, {"domain": _selected_domain})
	if not result.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), result.get("message", "?")])
	_selected_domain = -1
	_refresh_all()


# ─── DEBUG BUTTONS ────────────────────────────────────────────────────────────

func _on_btn_new_game() -> void:
	new_game()
	state.add_log(I18n.t("log.new_game", [Time.get_time_string_from_system()]))
	_refresh_log()


func _on_btn_force_next_station() -> void:
	if state.game_over:
		return
	state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
	manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
	manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
	manager._end_pulse()
	_refresh_all()


# Puiser dans l'Ombre — only legal when the active player's available
# Corruption pool is at 0. The button is disabled the rest of the time so
# the player can't trivially skip a turn — they have to either act or
# exhaust their Réserve first.
func _on_btn_puiser() -> void:
	if state == null or state.game_over:
		return
	if state.has_pending_decisions():
		state.add_log(I18n.t("log.decision_pending"))
		_refresh_log()
		return
	var result := manager.perform_action(GameEnums.ActionId.PUISER, {})
	if not result.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), result.get("message", "?")])
	_refresh_all()


func _on_btn_toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		_refresh_log()


# Debug toggle — paints each domain hotspot with a translucent cyan
# stylebox so the user can see where the click areas actually are. Useful
# for re-calibrating DOMAIN_POS / DOMAIN_HALF against the board artwork.
func _on_btn_toggle_hotspots() -> void:
	_debug_hotspots = not _debug_hotspots
	for d_id in _hotspots:
		var btn: Button = _hotspots[d_id]
		btn.flat = not _debug_hotspots
		if _debug_hotspots:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.2, 1.0, 1.0, 0.25)
			sb.border_color = Color(0.0, 1.0, 1.0, 1.0)
			sb.set_border_width_all(2)
			btn.add_theme_stylebox_override("normal",  sb)
			btn.add_theme_stylebox_override("hover",   sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_stylebox_override("focus",   sb)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_stylebox_override("focus")


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
	var mode_str: String = I18n.t("liturgy.impedita") if imp else I18n.t("liturgy.in_integro")
	var mode_color: String = "#e88" if imp else "#8e8"

	var details := ""
	for l in lines:
		details += "• " + String(l) + "\n"
	if details == "":
		details = I18n.t("liturgy.no_effect")

	_liturgy_dialog.title = I18n.t("liturgy.station_end", [st_name])
	# Composed card thumbnail. Clicking it pops it open fullscreen with flip
	# (see _on_liturgy_image_clicked, which reads back from the meta).
	var resp_id: String = String(LiturgicalResponseData.get_response(st).get("id", ""))
	var has_card: bool = resp_id != ""
	_liturgy_card_thumb.visible = has_card
	# Read the snapshot taken before resolution mutated the state.
	var t_dom: int = int(info.get("target_domain", -1))
	var t_pl: int = int(info.get("target_player", -1))
	if has_card:
		(_liturgy_card_thumb.get_meta("card_node") as Card).setup_liturgy(st, imp, t_dom, t_pl)
	_liturgy_card_thumb.set_meta("station", st)
	_liturgy_card_thumb.set_meta("impedita", imp)
	_liturgy_card_thumb.set_meta("name", resp_name)
	_liturgy_card_thumb.set_meta("target_domain", t_dom)
	_liturgy_card_thumb.set_meta("target_player", t_pl)
	# Text panel
	_liturgy_rtl.clear()
	_liturgy_rtl.append_text("[font_size=30][b]%s[/b][/font_size]\n" % resp_name)
	_liturgy_rtl.append_text("[font_size=22][color=%s][b]%s[/b][/color][/font_size]\n\n" % [mode_color, mode_str])
	_liturgy_rtl.append_text("[i]%s[/i]\n\n" % desc)
	_liturgy_rtl.append_text("[b]%s[/b]\n" % I18n.t("ui.liturgy.resolution_header"))
	_liturgy_rtl.append_text(details)

	_popup_dialog_fullscreen(_liturgy_dialog)


func _on_liturgy_acknowledged() -> void:
	manager.acknowledge_liturgy()
	_refresh_all()


# ─── DECISION DIALOG (free_exploit, confession) ───────────────────────────────

func _build_decision_dialog() -> void:
	_decision_dialog = AcceptDialog.new()
	_decision_dialog.exclusive = true
	_decision_dialog.title = I18n.t("ui.dialog.title.decision")
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
	_popup_dialog_fullscreen(_decision_dialog)


func _populate_decision_dialog(dec: GameState.PendingDecision) -> void:
	for c in _decision_content.get_children():
		c.queue_free()

	if dec.kind == "free_exploit":
		_decision_dialog.title = I18n.t("ui.decision.title.free_exploit", [GameEnums.player_name(dec.player)])
		_decision_dialog.ok_button_text = I18n.t("ui.dialog.skip_exploit")
		_decision_dialog.get_ok_button().disabled = false
		var hint := Label.new()
		hint.text = I18n.t("ui.decision.exploit_hint", [GameEnums.player_name(dec.player)])
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		_decision_content.add_child(hint)
		var options: Array = dec.data.get("options", [])
		for d_id in options:
			var did: int = d_id
			var btn := Button.new()
			# Show the actual Corruption gain so the player can choose informed.
			var gain: int = GameRules.production_of(state, d_id, dec.player)
			btn.text = I18n.t("ui.decision.btn.exploit_gain", [
				GameEnums.DOMAIN_NAMES[d_id], gain, ("s" if gain != 1 else ""),
			])
			btn.custom_minimum_size = Vector2(0, 56)
			btn.add_theme_font_size_override("font_size", 22)
			btn.pressed.connect(func(): _on_decision_pick({"domain": did}))
			_decision_content.add_child(btn)

	elif dec.kind == "confession":
		_decision_dialog.title = I18n.t("ui.decision.title.confession", [GameEnums.player_name(dec.player)])
		_decision_dialog.ok_button_text = I18n.t("ui.dialog.must_choose")
		_decision_dialog.get_ok_button().disabled = true
		var imp: bool = dec.data.get("impedita", false)
		var n: int = dec.picks_remaining
		var s_plural: String = I18n.t("ui.decision.plural_s") if n > 1 else ""
		var mode_label: String = I18n.t("liturgy.impedita") if imp else I18n.t("liturgy.in_integro")
		var hint := Label.new()
		hint.text = I18n.t("ui.decision.penitence_hint", [
			GameEnums.player_name(dec.player), n, s_plural, mode_label,
		])
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		_decision_content.add_child(hint)
		var avail: Array = LiturgyResolver.available_confession_kinds(state, dec)
		if "lose2" in avail:
			var btn := Button.new()
			btn.text = I18n.t("ui.decision.btn.lose2")
			btn.custom_minimum_size = Vector2(0, 56)
			btn.add_theme_font_size_override("font_size", 22)
			btn.pressed.connect(func(): _on_decision_pick({"kind": "lose2"}))
			_decision_content.add_child(btn)
		if "penitence" in avail:
			for d_id in DomainData.DOMAINS:
				if state.controller_of(d_id) == dec.player and not state.is_in_penitence(d_id):
					var did: int = d_id
					var btn := Button.new()
					btn.text = I18n.t("ui.decision.penitence_btn", [GameEnums.DOMAIN_NAMES[d_id]])
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
					btn.text = I18n.t("ui.decision.btn.fissure_own", [GameEnums.DOMAIN_NAMES[d_id]])
					btn.custom_minimum_size = Vector2(0, 56)
					btn.add_theme_font_size_override("font_size", 22)
					btn.pressed.connect(func(): _on_decision_pick({"kind": "fissure", "domain": did}))
					_decision_content.add_child(btn)


func _on_decision_pick(picks: Dictionary) -> void:
	# Hide first so the AcceptDialog "confirmed" signal is NOT emitted.
	_decision_dialog.hide()
	var r := manager.resolve_decision(picks)
	if not r.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), r.get("message", "?")])
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
		state.add_log("[%s] %s" % [I18n.t("log.refused"), r.get("message", "?")])
	_refresh_all()


# ─── ENDGAME DIALOG (Exorcisme final) ─────────────────────────────────────────

func _build_endgame_dialog() -> void:
	_endgame_dialog = AcceptDialog.new()
	_endgame_dialog.exclusive = true
	_endgame_dialog.title = I18n.t("ui.dialog.title.endgame")
	_endgame_dialog.ok_button_text = I18n.t("ui.dialog.new_game")
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
	_endgame_image.custom_minimum_size = Vector2(160, 224)
	_endgame_image.texture_normal = CardImages.exorcisme()
	_endgame_image.tooltip_text = I18n.t("ui.tooltip.click_to_zoom")
	_endgame_image.pressed.connect(_on_endgame_image_clicked)
	hbox.add_child(_endgame_image)

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(220, 240)
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
	var winner_str: String = GameEnums.player_name(state.winner) if state.winner != GameEnums.PlayerId.NONE else I18n.t("ui.endgame.pope_saved")
	var fmt_filled := func(b: bool, masc: bool) -> String:
		var key := ("ui.endgame.filled_m" if masc else "ui.endgame.filled") if b else ("ui.endgame.unfilled_m" if masc else "ui.endgame.unfilled")
		var color := "#8e8" if b else "#888"
		return "[color=%s]%s[/color]" % [color, I18n.t(key)]
	var s := ""
	s += "[font_size=30][b]%s[/b][/font_size]\n\n" % winner_str
	s += "[i]%s[/i]\n\n" % state.winner_reason
	s += "[b]%s[/b]\n" % I18n.t("ui.endgame.soul_rupture")
	s += "  • %s : %s\n" % [I18n.t("ui.endgame.profondeur"), fmt_filled.call(rupture.profondeur, false)]
	s += "  • %s : %s\n" % [I18n.t("ui.endgame.etendue"), fmt_filled.call(rupture.etendue, false)]
	s += "  • %s : %s\n" % [I18n.t("ui.endgame.ancrage"), fmt_filled.call(rupture.ancrage, true)]
	var complete_color := "#8e8" if rupture.complete else "#e88"
	var complete_msg := I18n.t("ui.endgame.complete_yes") if rupture.complete else I18n.t("ui.endgame.complete_no")
	s += "  • [b]%s : [color=%s]%s[/color][/b]\n\n" % [I18n.t("ui.endgame.complete_label"), complete_color, complete_msg]
	s += "[b]%s :[/b] %+d\n\n" % [I18n.t("ui.endgame.final_ascendant"), state.ascendant]
	s += "[b]%s[/b]\n" % I18n.t("ui.endgame.last_log_lines")
	var lines: Array = state.log
	var last_n: int = min(12, lines.size())
	for i in range(lines.size() - last_n, lines.size()):
		s += "  • " + String(lines[i]) + "\n"
	_endgame_rtl.clear()
	_endgame_rtl.append_text(s)
	_popup_dialog_fullscreen(_endgame_dialog)


func _on_endgame_acknowledged() -> void:
	new_game()


# ─── TRANSGRESSIONS DIALOG ────────────────────────────────────────────────────

func _build_transgressions_dialog() -> void:
	_trans_dialog = AcceptDialog.new()
	_trans_dialog.exclusive = true
	_trans_dialog.title = I18n.t("ui.dialog.title.transgressions")
	_trans_dialog.ok_button_text = I18n.t("ui.dialog.close")
	_trans_dialog.dialog_text = ""
	_trans_dialog.min_size = Vector2i(720, 520)
	add_child(_trans_dialog)
	_make_dialog_touch_friendly(_trans_dialog)
	_trans_scroll = ScrollContainer.new()
	_trans_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trans_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trans_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Phone-safe minimum: SIZE_EXPAND_FILL grows it on bigger screens.
	_trans_scroll.custom_minimum_size = Vector2(280, 320)
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
	_popup_dialog_fullscreen(_trans_dialog)


func _populate_transgressions_dialog() -> void:
	for c in _trans_content.get_children():
		c.queue_free()
	var p: int = state.active_player
	_trans_dialog.title = I18n.t("ui.transgressions_title.active", [GameEnums.player_name(p)])
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

	# Outer layout: top row (card image + status / flip), then a wide
	# action row at the bottom of the item.
	var item_vbox := VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 10)
	item_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(item_vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_vbox.add_child(top_row)

	# Determine current face (Scandale by default; Infamie if any owner amplified it).
	var owner: int = state.transgression_owner(tid)
	var face: int = GameEnums.TransgressionFace.SCANDALE
	if owner != GameEnums.PlayerId.NONE:
		var inf_inst: GameState.TransgressionInstance = state.find_transgression_instance(owner, tid, GameEnums.TransgressionFace.INFAMIE)
		if inf_inst != null:
			face = GameEnums.TransgressionFace.INFAMIE

	# Card thumbnail — composed at runtime so text follows the locale.
	var captured_name: String = String(def.get("name", ""))
	var captured_tid: String = tid
	var img: Control = _make_card_thumb(Vector2(240, 336))
	img.set_meta("face", face)
	img.set_meta("tid", tid)
	(img.get_meta("card_node") as Card).setup_transgression(tid, face)
	(img.get_meta("click_btn") as Button).pressed.connect(
		_on_transgression_image_clicked.bind(img, captured_tid, captured_name))
	top_row.add_child(img)

	# Right column next to the image: status badge + flip button + (if any)
	# the "why disabled" hint.
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_row.add_child(info_vbox)

	# Header for the row : just the transgression's localised name. The
	# face / owner state used to be spelled out here ("Libre (face Scandale)"
	# / "Infamie · Rouge") but the card thumbnail and action buttons already
	# convey that — duplicating it as the row title was redundant.
	var state_lbl := Label.new()
	state_lbl.text = String(def.get("name", "?"))
	state_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	state_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	state_lbl.add_theme_constant_override("outline_size", 4)
	state_lbl.add_theme_font_size_override("font_size", 30)
	state_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(state_lbl)

	# Flip Scandale ↔ Infamie thumbnail
	var flip_btn := Button.new()
	flip_btn.add_theme_font_size_override("font_size", 22)
	flip_btn.custom_minimum_size = Vector2(0, 56)
	flip_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	flip_btn.text = _flip_button_label(face)
	flip_btn.pressed.connect(_on_transgression_flip_pressed.bind(img, flip_btn, tid))
	# Note: img here is the Control wrapper from _make_card_thumb;
	# _on_transgression_flip_pressed reads img.get_meta("face") / "card_node".
	info_vbox.add_child(flip_btn)

	var why_prov: String = GameRules.why_cannot_provoquer(state, player, tid)
	var why_amp: String = GameRules.why_cannot_amplifier(state, player, tid)

	if why_prov != "" or why_amp != "":
		var hint := Label.new()
		var bits := ""
		if why_prov != "":
			bits += "%s : %s" % [I18n.t("ui.transgression.btn.provoke"), why_prov]
		if why_amp != "":
			if bits != "":
				bits += "\n"
			bits += "%s : %s" % [I18n.t("ui.transgression.btn.amplify"), why_amp]
		hint.text = bits
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 22)
		hint.add_theme_color_override("font_color", Color(0.85, 0.55, 0.55))
		info_vbox.add_child(hint)

	# Push the info column's contents to the top so the image height defines
	# the row, not random expansion of buttons inside the info column.
	var info_spacer := Control.new()
	info_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(info_spacer)

	# Action row at the BOTTOM of the item — full width, big targets.
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_vbox.add_child(action_row)

	var origins: Array = GameRules.transgression_origin_options(player, tid)
	for origin_d in origins:
		var btn := Button.new()
		var origin_int: int = origin_d
		if origins.size() > 1:
			btn.text = I18n.t("ui.transgression.btn.provoke_in", [GameEnums.DOMAIN_NAMES[origin_d]])
		else:
			btn.text = I18n.t("ui.transgression.btn.provoke")
		btn.disabled = (why_prov != "")
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.add_theme_font_size_override("font_size", 26)
		btn.custom_minimum_size = Vector2(0, 72)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.tooltip_text = why_prov
		btn.pressed.connect(func(): _on_provoquer_clicked(tid, origin_int))
		action_row.add_child(btn)

	var amp_btn := Button.new()
	amp_btn.text = I18n.t("ui.transgression.btn.amplify")
	amp_btn.disabled = (why_amp != "")
	amp_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	amp_btn.add_theme_font_size_override("font_size", 26)
	amp_btn.custom_minimum_size = Vector2(0, 72)
	amp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amp_btn.tooltip_text = why_amp
	amp_btn.pressed.connect(func(): _on_amplifier_clicked(tid))
	action_row.add_child(amp_btn)

	# Let drag events bubble up to the parent ScrollContainer (Labels and
	# basic Controls default to MOUSE_FILTER_STOP, which would swallow the
	# drag and prevent the dialog from scrolling by drag).
	_set_pass_through(panel)

	return panel


# Builds a clickable card thumbnail at the given minimum size: AspectRatio-
# Container holding a Card.tscn instance, with an invisible Button on top
# capturing click input.
# Caller wires the click handler via wrapper.get_meta("click_btn").pressed.
# Caller calls setup_* on wrapper.get_meta("card_node").
# mouse_filter = PASS so drag-to-scroll still bubbles up to a parent
# ScrollContainer.
func _make_card_thumb(min_size: Vector2) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = min_size
	wrapper.mouse_filter = Control.MOUSE_FILTER_PASS

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 720.0 / 1008.0
	aspect.anchor_right = 1.0
	aspect.anchor_bottom = 1.0
	aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(aspect)

	var card: Card = preload("res://scenes/Card.tscn").instantiate()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE  # pass clicks through to overlay
	aspect.add_child(card)

	var btn := Button.new()
	btn.flat = true
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.tooltip_text = I18n.t("ui.tooltip.click_to_zoom")
	wrapper.add_child(btn)

	wrapper.set_meta("card_node", card)
	wrapper.set_meta("click_btn", btn)
	return wrapper


func _set_pass_through(node: Node) -> void:
	if node is Control:
		var c: Control = node
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_pass_through(child)


# Make AcceptDialog buttons comfortable for fat fingers on a phone, and force
# the window into a behaviour that respects the size we hand to popup(...).
# Apply after add_child(dlg) so the OK button exists.
func _make_dialog_touch_friendly(dlg: AcceptDialog) -> void:
	# wrap_controls = true (the default) makes the Window auto-shrink to its
	# content's minimum size, which silently overrides the size we hand to
	# popup_centered_ratio / popup(rect). Force it off so popup-helper sizes
	# actually stick.
	dlg.wrap_controls = false
	# Drop the window decoration (title bar + corner X). On phones the title
	# bar visually reads as "extra margin at the top of the modal", and the
	# OK button at the bottom does the same close job as the X. Saves ~48 px
	# of vertical space too, which is what was getting clipped on small
	# screens.
	dlg.borderless = true
	var ok_btn: Button = dlg.get_ok_button()
	if ok_btn != null:
		ok_btn.add_theme_font_size_override("font_size", 24)
		ok_btn.custom_minimum_size = Vector2(160, 64)


# ─── FULLSCREEN CARD VIEWER ───────────────────────────────────────────────────

func _build_fullscreen_card_dialog() -> void:
	_fullscreen_card_dialog = AcceptDialog.new()
	_fullscreen_card_dialog.exclusive = true
	_fullscreen_card_dialog.title = I18n.t("ui.dialog.title.card")
	_fullscreen_card_dialog.ok_button_text = I18n.t("ui.dialog.close")
	_fullscreen_card_dialog.dialog_text = ""
	_fullscreen_card_dialog.min_size = Vector2i(360, 440)
	add_child(_fullscreen_card_dialog)
	_make_dialog_touch_friendly(_fullscreen_card_dialog)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_fullscreen_card_dialog.add_child(vbox)

	# Composed card (Card.tscn) keeps proportions via an AspectRatioContainer.
	_fullscreen_card_aspect = AspectRatioContainer.new()
	_fullscreen_card_aspect.ratio = 720.0 / 1008.0
	_fullscreen_card_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fullscreen_card_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Tap or swipe anywhere on the card area triggers the flip.
	_fullscreen_card_aspect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fullscreen_card_aspect.gui_input.connect(_on_fullscreen_card_input)
	vbox.add_child(_fullscreen_card_aspect)
	_fullscreen_card_node = preload("res://scenes/Card.tscn").instantiate()
	_fullscreen_card_aspect.add_child(_fullscreen_card_node)
	# Tapping the small badge slot ("FOI", "ROUGE"…) on a Liturgy card pops
	# a panel describing how the response picks its target — useful since
	# the resolved target shifts with the board state.
	_fullscreen_card_node.target_info_requested.connect(_on_card_target_info_requested)

	# TextureRect fallback used for cards we still ship pre-composed (Exorcism).
	_fullscreen_card_image = TextureRect.new()
	_fullscreen_card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fullscreen_card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fullscreen_card_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fullscreen_card_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fullscreen_card_image.custom_minimum_size = Vector2(200, 280)
	_fullscreen_card_image.visible = false
	vbox.add_child(_fullscreen_card_image)

	# Action row : flip + entraver. Both are shown / hidden per binding by
	# _update_fullscreen_buttons.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	vbox.add_child(actions)

	_fullscreen_card_flip_btn = Button.new()
	_fullscreen_card_flip_btn.add_theme_font_size_override("font_size", 18)
	_fullscreen_card_flip_btn.visible = false
	_fullscreen_card_flip_btn.pressed.connect(_on_fullscreen_card_flip_pressed)
	actions.add_child(_fullscreen_card_flip_btn)

	_fullscreen_card_entraver_btn = Button.new()
	_fullscreen_card_entraver_btn.add_theme_font_size_override("font_size", 18)
	_fullscreen_card_entraver_btn.visible = false
	_fullscreen_card_entraver_btn.pressed.connect(_on_fullscreen_card_entraver_pressed)
	actions.add_child(_fullscreen_card_entraver_btn)


# Static-image fallback (used by Exorcism only).
func _show_fullscreen_card(tex: Texture2D, title_str: String = "Carte") -> void:
	if tex == null:
		return
	_fullscreen_card_aspect.visible = false
	_fullscreen_card_image.visible = true
	_fullscreen_card_image.texture = tex
	_fullscreen_card_flip_btn.visible = false
	_fullscreen_card_binding = {}
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


func _show_fullscreen_transgression(tid: String, face: int, title_str: String) -> void:
	_fullscreen_card_aspect.visible = true
	_fullscreen_card_image.visible = false
	_fullscreen_card_node.setup_transgression(tid, face)
	_fullscreen_card_binding = {"kind": "transgression", "tid": tid, "face": face}
	_update_fullscreen_flip_button()
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


func _show_fullscreen_liturgy(station: int, impedita: bool, title_str: String, target_domain: int = -2, target_player: int = -2) -> void:
	_fullscreen_card_aspect.visible = true
	_fullscreen_card_image.visible = false
	# Sentinel -2 = "not provided" → compute from current state. -1 means the
	# caller deliberately passed "no target". Banner clicks before resolution
	# rely on the sentinel; the post-resolution thumb passes through the
	# snapshot taken before mutation.
	if target_domain == -2 and target_player == -2:
		target_domain = LiturgyResolver.preview_target_domain(state, station) if state != null else -1
		target_player = LiturgyResolver.preview_target_player(state, station) if state != null else -1
	_fullscreen_card_node.setup_liturgy(station, impedita, target_domain, target_player)
	_fullscreen_card_binding = {
		"kind": "liturgy", "station": station, "impedita": impedita,
		"target_domain": target_domain, "target_player": target_player,
	}
	_update_fullscreen_flip_button()
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


# Sets the flip button label to "switch to the other face" wording for the
# currently-displayed face. Always shows the button when a binding is active.
func _update_fullscreen_flip_button() -> void:
	if _fullscreen_card_binding.is_empty():
		_fullscreen_card_flip_btn.visible = false
		_fullscreen_card_entraver_btn.visible = false
		return
	var kind: String = _fullscreen_card_binding.get("kind", "")
	if kind == "transgression":
		var face: int = int(_fullscreen_card_binding.get("face", GameEnums.TransgressionFace.SCANDALE))
		_fullscreen_card_flip_btn.text = I18n.t("ui.flip.see_infamy") if face == GameEnums.TransgressionFace.SCANDALE else I18n.t("ui.flip.see_scandal")
		_fullscreen_card_flip_btn.visible = true
		_fullscreen_card_entraver_btn.visible = false
	elif kind == "liturgy":
		var imp: bool = bool(_fullscreen_card_binding.get("impedita", false))
		_fullscreen_card_flip_btn.text = I18n.t("ui.flip.see_in_integro") if imp else I18n.t("ui.flip.see_impedita")
		_fullscreen_card_flip_btn.visible = true
		_update_fullscreen_entraver_button()
	else:
		_fullscreen_card_flip_btn.visible = false
		_fullscreen_card_entraver_btn.visible = false


# Show the Entraver button when the binding is a liturgy AND the active
# player can legally hinder that Station's response. Disabled (with a
# tooltip explaining why) when illegal but otherwise relevant. Hidden
# entirely if it would never be useful (e.g. game over, or this isn't
# a liturgy view).
func _update_fullscreen_entraver_button() -> void:
	if state == null or state.game_over:
		_fullscreen_card_entraver_btn.visible = false
		return
	var st: int = int(_fullscreen_card_binding.get("station", -1))
	if st < 0:
		_fullscreen_card_entraver_btn.visible = false
		return
	var p: int = state.active_player
	var why: String = GameRules.why_cannot_entraver(state, p, st)
	var legal: bool = (why == "")
	# If already entraved, no point showing — the action would always be
	# illegal here. Hide rather than show a perpetually-grey button.
	if GameRules.is_response_entraved(state, st):
		_fullscreen_card_entraver_btn.visible = false
		return
	_fullscreen_card_entraver_btn.visible = true
	var cost: int = GameRules.entrave_cost(state, p, st)
	var cs: String = "s" if cost > 1 else ""
	_fullscreen_card_entraver_btn.text = I18n.t("ui.btn.entraver_cost", [cost, cs])
	_fullscreen_card_entraver_btn.disabled = not legal
	_fullscreen_card_entraver_btn.tooltip_text = why


func _on_fullscreen_card_entraver_pressed() -> void:
	if state == null or _fullscreen_card_binding.is_empty():
		return
	var st: int = int(_fullscreen_card_binding.get("station", -1))
	if st < 0:
		return
	var result := manager.perform_action(GameEnums.ActionId.ENTRAVER, {"station": st})
	if not result.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), result.get("message", "?")])
	else:
		# Reflect the new state on the binding, the banner, and the
		# button row of the open dialog.
		_fullscreen_card_binding["impedita"] = true
		var t_dom: int = int(_fullscreen_card_binding.get("target_domain", -1))
		var t_pl: int = int(_fullscreen_card_binding.get("target_player", -1))
		_fullscreen_card_node.flip_to_liturgy(st, true, t_dom, t_pl)
		_update_fullscreen_flip_button()
	_refresh_all()


# Tap or swipe anywhere on the fullscreen card area flips it. We treat any
# left-mouse / touch release as "user wants to flip" — both quick taps and
# horizontal swipes count, since all of them mean the same thing here.
var _fullscreen_card_press_pos: Vector2 = Vector2.INF


func _on_fullscreen_card_input(event: InputEvent) -> void:
	if _fullscreen_card_binding.is_empty():
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_fullscreen_card_press_pos = mb.position
		elif _fullscreen_card_press_pos != Vector2.INF:
			_fullscreen_card_press_pos = Vector2.INF
			_on_fullscreen_card_flip_pressed()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_fullscreen_card_press_pos = st.position
		elif _fullscreen_card_press_pos != Vector2.INF:
			_fullscreen_card_press_pos = Vector2.INF
			_on_fullscreen_card_flip_pressed()


# Pops a small modal explaining how the response at this Station picks its
# target. Built lazily on first use ; the body text comes from the
# liturgy.targeting.<id> i18n keys so it's localised. For Station VI the
# response is the final Exorcism — we still surface a one-liner because the
# resp_id lookup won't find anything in LiturgicalResponseData.
func _on_card_target_info_requested(station: int) -> void:
	var resp_id: String = ""
	if station == GameEnums.StationId.EXORCISME:
		resp_id = "exorcisme"
	else:
		resp_id = String(LiturgicalResponseData.get_response(station).get("id", ""))
	if resp_id == "":
		return
	if _targeting_dialog == null:
		_targeting_dialog = AcceptDialog.new()
		_targeting_dialog.exclusive = true
		_targeting_dialog.ok_button_text = I18n.t("ui.dialog.close")
		# Force a max width by capping wrap_controls and pinning min_size.
		# Without this, the internal Label measures its single-line width
		# and the Window grows past the viewport on a long rule string.
		_targeting_dialog.wrap_controls = false
		add_child(_targeting_dialog)
		# Bump the OK button for touch ; keep the title bar (we don't apply
		# the full _make_dialog_touch_friendly here because the popup is much
		# smaller than a fullscreen modal and the title carries information).
		var ok_btn: Button = _targeting_dialog.get_ok_button()
		if ok_btn != null:
			ok_btn.add_theme_font_size_override("font_size", 22)
		# AcceptDialog ships a single Label for dialog_text with no autowrap
		# by default, which on a phone-narrow window pushes long sentences
		# off-screen. Force smart word wrap so the rule reflows inside the
		# popup width.
		var dlg_lbl: Label = _targeting_dialog.get_label()
		if dlg_lbl != null:
			dlg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dlg_lbl.custom_minimum_size = Vector2(0, 0)
			dlg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dlg_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_targeting_dialog.title = I18n.t("ui.dialog.title.targeting_rule")
	_targeting_dialog.dialog_text = I18n.t("liturgy.targeting." + resp_id)
	# Smaller than the fullscreen card it sits on — the rule is a couple of
	# lines and the popup shouldn't occlude the card the player was reading.
	_targeting_dialog.popup_centered_clamped(Vector2i(560, 280))


func _on_fullscreen_card_flip_pressed() -> void:
	if _fullscreen_card_binding.is_empty():
		return
	var kind: String = _fullscreen_card_binding.get("kind", "")
	if kind == "transgression":
		var cur: int = int(_fullscreen_card_binding.get("face", GameEnums.TransgressionFace.SCANDALE))
		var nxt: int = GameEnums.TransgressionFace.INFAMIE if cur == GameEnums.TransgressionFace.SCANDALE else GameEnums.TransgressionFace.SCANDALE
		_fullscreen_card_binding["face"] = nxt
		_fullscreen_card_node.flip_to_transgression(String(_fullscreen_card_binding.get("tid", "")), nxt)
	elif kind == "liturgy":
		var imp: bool = not bool(_fullscreen_card_binding.get("impedita", false))
		_fullscreen_card_binding["impedita"] = imp
		var t_dom: int = int(_fullscreen_card_binding.get("target_domain", -1))
		var t_pl: int = int(_fullscreen_card_binding.get("target_player", -1))
		_fullscreen_card_node.flip_to_liturgy(int(_fullscreen_card_binding.get("station", 0)), imp, t_dom, t_pl)
	_update_fullscreen_flip_button()


func _popup_dialog_fullscreen(dlg: AcceptDialog) -> void:
	# Make sure no static min_size held over from the build pushes the
	# window past the viewport.
	dlg.min_size = Vector2i.ZERO
	# Use popup_centered_ratio(1.0) — for embedded dialogs this is the
	# documented way to size the window to a fraction of the parent
	# viewport. Setting size + popup(Rect2i) by hand seemed to be ignored
	# (margin tweaks didn't move anything on screen), which suggests Godot
	# applies its own layout pass when embedded.
	dlg.popup_centered_ratio(1.0)


# ─── Transgression catalog: per-card flip + image-click handlers ──────────────

func _flip_button_label(face: int) -> String:
	return I18n.t("ui.flip.see_infamy") if face == GameEnums.TransgressionFace.SCANDALE else I18n.t("ui.flip.see_scandal")


func _on_transgression_flip_pressed(img: Control, btn: Button, tid: String) -> void:
	var cur: int = img.get_meta("face", GameEnums.TransgressionFace.SCANDALE)
	var nxt: int = GameEnums.TransgressionFace.INFAMIE if cur == GameEnums.TransgressionFace.SCANDALE else GameEnums.TransgressionFace.SCANDALE
	img.set_meta("face", nxt)
	(img.get_meta("card_node") as Card).flip_to_transgression(tid, nxt)
	btn.text = _flip_button_label(nxt)


func _on_transgression_image_clicked(img: Control, tid: String, name_str: String) -> void:
	var cur: int = img.get_meta("face", GameEnums.TransgressionFace.SCANDALE)
	_show_fullscreen_transgression(tid, cur, name_str)


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
	var resp_name: String = String(resp.get("name", ""))
	var st_name: String = GameEnums.STATION_NAMES.get(st, "")
	var title_str: String = "%s — %s" % [st_name, resp_name] if st_name != "" else resp_name
	_show_fullscreen_liturgy(st, false, title_str)


func _on_liturgy_image_clicked() -> void:
	if not _liturgy_card_thumb.visible:
		return
	var st: int = int(_liturgy_card_thumb.get_meta("station", -1))
	if st < 0:
		return
	var imp: bool = bool(_liturgy_card_thumb.get_meta("impedita", false))
	var name_str: String = String(_liturgy_card_thumb.get_meta("name", ""))
	var t_dom: int = int(_liturgy_card_thumb.get_meta("target_domain", -1))
	var t_pl: int = int(_liturgy_card_thumb.get_meta("target_player", -1))
	_show_fullscreen_liturgy(st, imp, name_str, t_dom, t_pl)


func _on_endgame_image_clicked() -> void:
	if _endgame_image.texture_normal != null:
		_show_fullscreen_card(_endgame_image.texture_normal, I18n.t("ui.dialog.title.endgame"))


func _on_provoquer_clicked(tid: String, origin: int) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.PROVOQUER, {"def_id": tid, "origin": origin})
	if not r.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), r.get("message", "?")])
	_refresh_all()


func _on_amplifier_clicked(tid: String) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.AMPLIFIER, {"def_id": tid})
	if not r.get("ok", false):
		state.add_log("[%s] %s" % [I18n.t("log.refused"), r.get("message", "?")])
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

func _on_btn_toggle_lang() -> void:
	I18n.toggle_locale()


# Re-apply localised text to widgets that were created once at startup.
# Dynamic widgets (created on dialog popup or panel refresh) re-localise
# automatically when they're recreated.
func _relocalize() -> void:
	# FAB tooltip — items inside the popup are recreated on each open so they
	# pick up the current locale automatically.
	if _fab != null:
		var tk: String = _fab.get_meta("i18n_tooltip_key", "")
		if tk != "":
			_fab.tooltip_text = I18n.t(tk)
	# Action popup
	if _action_popup != null:
		for idx in POPUP_ACTIONS.size():
			var aid: int = POPUP_ACTIONS[idx]
			_action_popup.set_item_text(idx, I18n.t(POPUP_LABEL_KEYS[aid]))
	# Static dialog titles + ok button text
	if _liturgy_dialog != null:
		_liturgy_dialog.title = I18n.t("ui.dialog.title.liturgy")
		_liturgy_dialog.ok_button_text = I18n.t("ui.dialog.continue")
	if _decision_dialog != null:
		_decision_dialog.title = I18n.t("ui.dialog.title.decision")
	if _endgame_dialog != null:
		_endgame_dialog.title = I18n.t("ui.dialog.title.endgame")
		_endgame_dialog.ok_button_text = I18n.t("ui.dialog.new_game")
	if _trans_dialog != null:
		_trans_dialog.title = I18n.t("ui.dialog.title.transgressions")
		_trans_dialog.ok_button_text = I18n.t("ui.dialog.close")
	if _fullscreen_card_dialog != null:
		_fullscreen_card_dialog.title = I18n.t("ui.dialog.title.card")
		_fullscreen_card_dialog.ok_button_text = I18n.t("ui.dialog.close")
	if _placed_dialog != null:
		_placed_dialog.title = I18n.t("ui.dialog.title.placed")
		_placed_dialog.ok_button_text = I18n.t("ui.dialog.close")
		# Column titles (just the player name, no "— Transgressions" suffix)
		_relocalize_placed_column_title(_placed_list_red, GameEnums.PlayerId.RED)
		_relocalize_placed_column_title(_placed_list_blue, GameEnums.PlayerId.BLUE)
	# Status label tooltip
	if _status_label != null:
		_status_label.tooltip_text = I18n.t("ui.tooltip.station_card")
	# Player panel titles (rebuild text from the stored player id)
	if _player_panel_red != null and is_instance_valid(_player_panel_red):
		_relocalize_player_panel_title(_player_panel_red, GameEnums.PlayerId.RED)
	if _player_panel_blue != null and is_instance_valid(_player_panel_blue):
		_relocalize_player_panel_title(_player_panel_blue, GameEnums.PlayerId.BLUE)
	# Cascading refresh for content that depends on locale
	if state != null:
		_refresh_all()


func _relocalize_player_panel_title(panel: PanelContainer, pid: int) -> void:
	for child in panel.get_children():
		_recursively_update_player_title(child, pid)


func _relocalize_placed_column_title(list: VBoxContainer, pid: int) -> void:
	if list == null:
		return
	# list is the inner VBox; walk up to its sibling Label (the title) which
	# also lives in the column's outer VBox.
	var col_vbox: Node = list.get_parent().get_parent() if list.get_parent() != null else null
	if col_vbox == null:
		return
	for child in col_vbox.get_children():
		if child is Label and child.has_meta("i18n_player_id"):
			(child as Label).text = GameEnums.player_name(pid)
			return


func _recursively_update_player_title(node: Node, pid: int) -> void:
	if node is Label and node.has_meta("i18n_player_id"):
		var lbl: Label = node
		lbl.text = I18n.t("ui.player_panel.title", [GameEnums.player_name(pid)])
		return
	for c in node.get_children():
		_recursively_update_player_title(c, pid)


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
