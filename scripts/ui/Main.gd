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
	GameEnums.DomainId.AMBITION: Vector2(0.269, 0.362),
	GameEnums.DomainId.FOI:      Vector2(0.687, 0.343),
	GameEnums.DomainId.VOLONTE:  Vector2(0.478, 0.230),
	GameEnums.DomainId.DESIR:    Vector2(0.288, 0.686),
	GameEnums.DomainId.PEUR:     Vector2(0.679, 0.658),
}
const DOMAIN_HALF := Vector2(0.080, 0.085)

# Per-zone half-extents override map. Populated from the in-game
# calibration mode (FAB → Hotspots) — Volonté is sized noticeably larger
# than the others to match its visual prominence on the new board.
const DOMAIN_HALF_OVERRIDES := {
	GameEnums.DomainId.AMBITION: Vector2(0.061, 0.102),
	GameEnums.DomainId.FOI:      Vector2(0.063, 0.082),
	GameEnums.DomainId.VOLONTE:  Vector2(0.080, 0.109),
	GameEnums.DomainId.DESIR:    Vector2(0.066, 0.084),
	GameEnums.DomainId.PEUR:     Vector2(0.047, 0.094),
}

# Domain name caption — independent zone with its own position + size,
# fully calibratable from FAB → Hotspots. Defaults: same centre as the
# Domain hotspot so on a fresh board the captions land on top of the
# painted niches ; the user reposition each caption to wherever the
# new artwork has space (typically just above or below the niche).
const DOMAIN_NAME_POS := {
	GameEnums.DomainId.AMBITION: Vector2(0.277, 0.497),
	GameEnums.DomainId.FOI:      Vector2(0.683, 0.497),
	GameEnums.DomainId.VOLONTE:  Vector2(0.479, 0.370),
	GameEnums.DomainId.DESIR:    Vector2(0.281, 0.798),
	GameEnums.DomainId.PEUR:     Vector2(0.690, 0.815),
}
const DOMAIN_NAME_HALF := Vector2(0.060, 0.020)
const DOMAIN_NAME_HALF_OVERRIDES := {
	GameEnums.DomainId.AMBITION: Vector2(0.062, 0.021),
	GameEnums.DomainId.FOI:      Vector2(0.066, 0.020),
	GameEnums.DomainId.VOLONTE:  Vector2(0.072, 0.019),
	GameEnums.DomainId.DESIR:    Vector2(0.061, 0.019),
	GameEnums.DomainId.PEUR:     Vector2(0.066, 0.021),
}

# Liturgy banners — one per Station I-V plus the Exorcism, on the right edge
# of the board. Width spans from Désir's right border (0.710 + 0.080 = 0.790)
# to the board edge, keeping the source image's 2.667:1 aspect ratio
# (banner_w × 1.333 / banner_h ≈ 2.667). Click → opens the fullscreen
# liturgy view with an Entraver button (Station VI opens the endgame card —
# the Exorcism has no in_integro/impedita variant and can't be entravé).
const LITURGY_BANNER_POS := {
	GameEnums.StationId.MURMURES:   Vector2(0.895, 0.114),
	GameEnums.StationId.TENTATION:  Vector2(0.892, 0.241),
	GameEnums.StationId.CHUTE:      Vector2(0.895, 0.366),
	GameEnums.StationId.CONFESSION: Vector2(0.893, 0.491),
	GameEnums.StationId.OFFICE:     Vector2(0.895, 0.619),
	GameEnums.StationId.EXORCISME:  Vector2(0.895, 0.747),
}
const LITURGY_BANNER_HALF := Vector2(0.090, 0.045)
# Same per-zone override pattern as DOMAIN_HALF_OVERRIDES — empty by
# default, dumped fully populated by the calibration tool when the user
# resizes individual banner slots.
const LITURGY_BANNER_HALF_OVERRIDES := {}

# Penitence arch markers — one ogival golden border per Domain, shown in
# game only while that Domain is in Penitence (state.is_in_penitence). The
# arch REUSES the Domain's existing zone rectangle (the hotspot bounds, which
# are already calibrated) as its left/right/top/bottom box ; the only
# arch-specific value is the apex RISE above the rectangle's top edge. So
# there is just one calibratable number per Domain.
#
# Calibrated rises (normalised, fraction of board height) — set in-game via
# FAB → "Arches pénitence" (drag the gold apex handle) and frozen here.
const PENITENCE_ARCH_RISE := {
	GameEnums.DomainId.AMBITION: 0.082,
	GameEnums.DomainId.FOI:      0.078,
	GameEnums.DomainId.VOLONTE:  0.087,
	GameEnums.DomainId.DESIR:    0.078,
	GameEnums.DomainId.PEUR:     0.040,
}

# Ascendant track painted on the bottom board band. The printed track is a
# very slight "smile" (curve), so it's defined by THREE on-curve points
# calibrated against the printed pips : left (-10), apex (0), right (+10).
# The pawn is placed by sampling the quadratic Bézier through them. All
# normalised board coordinates. Drag-calibrated via FAB → Hotspots.
const ASCENDANT_TRACK_LIMIT := 10
const ASCENDANT_TRACK_LEFT  := Vector2(0.178, 0.912)   # value -10
const ASCENDANT_TRACK_APEX  := Vector2(0.498, 0.937)   # value 0 (curve apex)
const ASCENDANT_TRACK_RIGHT := Vector2(0.812, 0.912)   # value +10
const ASCENDANT_PAWN_SIZE := Vector2(42, 52)
const _ASC_HANDLE_SIZE := 22.0

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

# ─── AI opponent ──────────────────────────────────────────────────────────────
# Per-side control: PlayerId -> PLAYER_HUMAN / PLAYER_AI, chosen at new game.
# Defaults to all-human (hotseat) so launch / endgame-replay behave as before.
const PLAYER_HUMAN := "human"
const PLAYER_AI := "ai"
const AI_STEP_DELAY := 0.6   # seconds between watched bot moves (legibility)
var _player_config: Dictionary = {
	GameEnums.PlayerId.RED: PLAYER_HUMAN,
	GameEnums.PlayerId.PURPLE: PLAYER_HUMAN,
}
# One-shot timer that paces bot moves: each timeout applies a single
# step_bot_once() so the player can watch the AI play instead of the whole
# turn resolving instantly. Created lazily in _ensure_ai_timer().
var _ai_timer: Timer

# Created in _build_overlays
var _zoom_layer: Control            # parent scaled/translated of board+hotspots
var _hotspots: Dictionary = {}      # domain_id -> Button
var _domain_name_labels: Dictionary = {}   # domain_id -> Label (board overlay)
var _domain_hint_chips: Dictionary = {}
var _debug_hotspots: bool = false   # cyan outline overlay for calibration

# Penitence arch overlay (golden ogival border per Domain). One PenitenceArch
# Control covers the whole board inside _zoom_layer (follows zoom/pan). The
# arch box is the Domain's zone rectangle (read live from the hotspot Button
# anchors each refresh) ; the only per-domain arch value is the apex rise,
# held in _arch_rise (seeded from PENITENCE_ARCH_RISE, mutated live by the
# single apex handle). _arch_calibrating forces all 5 arches visible + spawns
# one draggable apex handle each; off, only penitent Domains show.
var _arch_overlay: PenitenceArch
var _arch_rise: Dictionary = {}     # domain_id -> float (apex rise, normalised)
var _arch_calibrating: bool = false
var _arch_handles: Dictionary = {}  # domain_id -> apex handle Button
var _arch_labels: Dictionary = {}   # domain_id -> Label (name + live rise)
# Throttle for the live journal dump during an arch drag : drag motion fires
# many samples per second, and each _refresh_log() rebuilds the whole journal
# UI, so we coalesce to at most one journal write every _ARCH_LOG_INTERVAL ms.
# The per-arch live label still updates on every sample (cheap, no rebuild).
var _arch_log_last_ms: int = 0
const _ARCH_LOG_INTERVAL := 250

# Per-zone half-extents in normalised board coordinates. Initialised in
# _build_overlays from DOMAIN_HALF / LITURGY_BANNER_HALF (the global default)
# and DOMAIN_HALF_OVERRIDES / LITURGY_BANNER_HALF_OVERRIDES (per-zone tweaks).
# Mutated at runtime by the calibration tool when the user drags the corner
# handles to resize a zone, then dumped on toggle-off.
var _domain_half: Dictionary = {}
var _banner_half: Dictionary = {}
var _domain_name_half: Dictionary = {}
var _domain_badges: Dictionary = {} # domain_id -> DomainBadges (drawn controller/sealed/penitence indicators)
var _domain_dots: Dictionary = {}   # domain_id -> CorruptionDots
var _liturgy_banners: Dictionary = {}       # station_id -> PanelContainer (placeholder)
var _liturgy_banner_labels: Dictionary = {} # station_id -> Label (inside panel)
var _domain_marker_rows: Dictionary = {} # domain_id -> HFlowContainer (owned-Transgression chips)
var _ascendant_pawn: AscendantPawn
# Live (drag-calibrated) copies of the three track points, seeded from the
# consts. _position_ascendant_pawn reads these so the curve updates live while
# calibrating. Persisted back to source via the FAB → Hotspots dump.
var _asc_left: Vector2 = ASCENDANT_TRACK_LEFT
var _asc_apex: Vector2 = ASCENDANT_TRACK_APEX
var _asc_right: Vector2 = ASCENDANT_TRACK_RIGHT
var _asc_handles: Dictionary = {}   # "left"/"apex"/"right" -> Button
var _asc_pips: Array = []           # preview dots, one per integer value
var _status_label: Label
var _ascendant_label: Label
var _action_menu: DomainActionMenu
var _selected_domain: int = -1
var _log_rtl: RichTextLabel
var _log_panel: PanelContainer
var _log_scroll: ScrollContainer
# Toast surfaced at the top of the viewport on action result (refusal in
# particular — the journal is hidden by default).
var _action_toast: Panel
var _action_toast_label: Label
var _action_toast_tween: Tween
# In-game glossary popup, built lazily on first request.
var _glossary_dialog: AcceptDialog
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
# Card thumbnails (Card.tscn wrappers) keyed by transgression id. The
# Transgressions dialog rebuilds its item rows on every open because their
# state — face, provoke/amplify legality, hints — changes each turn. But the
# expensive part is instantiating Card.tscn (8 nodes + MSDF font config + text
# shaping), and that depends only on tid + face. So we keep the thumbnails
# alive across opens : _populate detaches them before freeing the old rows,
# then reattaches them into the freshly rebuilt rows. Eliminates ~10
# Card.tscn.instantiate() + _ready() per open — the hitch before the list shows.
var _trans_thumb_pool: Dictionary = {}

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
var _static_card_holder: AspectRatioContainer  # shared aspect for static front + back
var _fullscreen_card_image: TextureRect       # static fallback front (Exorcism)
var _fullscreen_card_back_panel: PanelContainer  # parchment back, child of _static_card_holder
var _fullscreen_card_back: RichTextLabel      # rich text drawn on the back parchment
var _fullscreen_card_aspect: AspectRatioContainer
var _fullscreen_card_flip_btn: Button
var _fullscreen_card_entraver_btn: Button
# Small popup that explains the targeting rule of a Liturgy. Triggered by
# tapping the badge slot on a fullscreen Liturgy card.
var _targeting_dialog: AcceptDialog
# Companion popup that re-renders the body-text effect in a high-contrast
# theme (Card body uses dark ink on parchment, which a few playtesters
# struggled to read). Optionally surfaces a longer ".detail" i18n variant
# when the rules text has been flagged as ambiguous.
var _effect_detail_dialog: AcceptDialog
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


func _ready() -> void:
	# Force the Card.FONT_* resources into their configured state (MSDF +
	# ThemeDB fallbacks + clear_cache) BEFORE anything in the scene tree
	# uses them. Card._configure_card_fonts() normally runs from a Card
	# instance's _ready(), which means any Label set up earlier with
	# add_theme_font_override pointing at FONT_BODY / FONT_TITLE would
	# render against the un-configured FontFile, then have its cached
	# glyph layout invalidated when the first Card later calls
	# clear_cache() — Godot 4's text server then errors out with
	# "Parameter fd is null" on the next ascent / descent query. Static
	# guard inside _configure_card_fonts keeps this idempotent.
	Card._configure_card_fonts()
	_apply_theme()
	_build_overlays()
	I18n.locale_changed.connect(_relocalize)
	new_game()
	# After the fresh-game refresh has run (so the UI is laid out), check
	# whether a save from a previous browser session exists and offer to
	# resume. Deferred a frame so the dialog overlays the freshly-painted
	# board rather than racing the layout pass.
	call_deferred("_maybe_offer_resume")


# Serialises the full GameState to user://save_game.json so an iPad
# refresh / accidental tab close doesn't wipe the in-progress game.
# JSON over an IndexedDB-backed FileAccess on the web export ; works
# cold-boot offline thanks to the SW cache.
func _save_game() -> void:
	if state == null:
		return
	if state.game_over:
		_delete_save()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	# Wrap the state with the human/AI player config so a resumed game keeps
	# its bots. Older saves stored the bare state dict; _load_game() detects
	# both shapes for backward compatibility.
	var payload := {
		"state": state.to_dict(),
		"players": {
			"red": _player_config.get(GameEnums.PlayerId.RED, PLAYER_HUMAN),
			"purple": _player_config.get(GameEnums.PlayerId.PURPLE, PLAYER_HUMAN),
		},
	}
	f.store_string(JSON.stringify(payload))
	f.close()


# Reads the save file back into the current GameState. Returns false on
# any failure (no file, parse error, wrong shape) so the caller can fall
# back to a fresh game without crashing.
func _load_game() -> bool:
	if state == null:
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return false
	# New wrapped shape {state, players} vs legacy bare-state dict.
	var state_dict: Dictionary = parsed
	if parsed.has("state") and parsed["state"] is Dictionary:
		state_dict = parsed["state"]
		var players: Dictionary = parsed.get("players", {})
		_player_config = {
			GameEnums.PlayerId.RED: players.get("red", PLAYER_HUMAN),
			GameEnums.PlayerId.PURPLE: players.get("purple", PLAYER_HUMAN),
		}
	else:
		_player_config = {
			GameEnums.PlayerId.RED: PLAYER_HUMAN,
			GameEnums.PlayerId.PURPLE: PLAYER_HUMAN,
		}
	state.from_dict(state_dict)
	_apply_player_config()
	return true


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# If a save is on disk, prompt the user : Reprendre / Nouvelle partie.
# Confirm → load + refresh. Cancel → wipe the save and keep the fresh
# new_game() state that's already on screen. No save → no-op.
func _maybe_offer_resume() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = true
	dlg.title = I18n.t("ui.dialog.title.resume")
	dlg.dialog_text = I18n.t("ui.dialog.resume_message")
	dlg.ok_button_text = I18n.t("ui.dialog.resume_yes")
	dlg.add_cancel_button(I18n.t("ui.dialog.resume_no"))
	add_child(dlg)
	dlg.confirmed.connect(func():
		if _load_game():
			_refresh_all()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		_delete_save()
		dlg.queue_free()
	)
	dlg.popup_centered()


func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_font_size("font_size", "Button", 22)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 14)
	t.set_constant("h_separation", "PopupMenu", 14)
	t.set_font_size("font_size", "Label", 22)
	theme = t


func new_game(config: Dictionary = {}) -> void:
	state = GameState.new()
	manager = TurnManager.new(state)
	# The UI paces bot moves itself (one per timer tick) instead of letting
	# perform_action() resolve the whole bot turn synchronously.
	manager.auto_bot = false
	if not config.is_empty():
		_player_config = config.duplicate()
	_apply_player_config()
	pending_action = -1
	pending_kwargs.clear()
	_endgame_shown = false
	# Reset the station-intro latch so the splash doesn't fire when starting
	# a fresh game from mid-Exorcisme.
	_last_seen_station = -1
	_refresh_all()
	# AI may hold the initiative on the very first pulse — kick the stepper.
	_maybe_resume_ai()


# Wire state.bot_for_player from the current _player_config. PLAYER_AI sides
# get an MCTSBot (the main brain per the dev-bot brief); PLAYER_HUMAN sides
# are left absent so the UI surfaces their turns / decisions normally.
func _apply_player_config() -> void:
	if state == null:
		return
	state.bot_for_player.clear()
	for pid in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		if _player_config.get(pid, PLAYER_HUMAN) == PLAYER_AI:
			state.bot_for_player[pid] = MCTSBot.new()


func _has_ai_player() -> bool:
	return _player_config.get(GameEnums.PlayerId.RED, PLAYER_HUMAN) == PLAYER_AI \
		or _player_config.get(GameEnums.PlayerId.PURPLE, PLAYER_HUMAN) == PLAYER_AI


func _ensure_ai_timer() -> void:
	if _ai_timer != null:
		return
	_ai_timer = Timer.new()
	_ai_timer.one_shot = true
	_ai_timer.timeout.connect(_ai_tick)
	add_child(_ai_timer)


# Arm the step timer if (and only if) the engine is currently waiting on a
# bot's move. Called at the tail of every _refresh_all(), so the AI resumes
# automatically after a human action, after a liturgy acknowledgement, or
# after its own previous move — without each call site knowing about bots.
# No-op while a tick is already pending (timer running) so ticks don't stack.
func _maybe_resume_ai() -> void:
	if manager == null or state == null or manager.auto_bot:
		return
	if not manager.bot_should_act():
		return
	_ensure_ai_timer()
	if not _ai_timer.is_stopped():
		return
	_ai_timer.start(AI_STEP_DELAY)


# Apply exactly one bot move, then refresh (which animates the move via
# _animate_action_feedback and re-arms this timer through _maybe_resume_ai
# if the bot still has the turn). Persists after each accepted move so an
# iPad swipe-away mid AI-turn doesn't lose progress.
func _ai_tick() -> void:
	if manager == null or not manager.bot_should_act():
		return
	if manager.step_bot_once():
		_save_game()
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

	# Initialise the per-zone half-extents dicts. Each zone falls back to
	# the global DOMAIN_HALF / LITURGY_BANNER_HALF unless an entry sits in
	# the corresponding _OVERRIDES const (for hand-tuned zones, e.g. a
	# bigger Volonté niche).
	for d_id in DOMAIN_POS.keys():
		_domain_half[d_id] = DOMAIN_HALF_OVERRIDES.get(d_id, DOMAIN_HALF)
	for st in LITURGY_BANNER_POS.keys():
		_banner_half[st] = LITURGY_BANNER_HALF_OVERRIDES.get(st, LITURGY_BANNER_HALF)
	for d_id in DOMAIN_NAME_POS.keys():
		_domain_name_half[d_id] = DOMAIN_NAME_HALF_OVERRIDES.get(d_id, DOMAIN_NAME_HALF)

	# Hotspots and per-domain overlay labels — inside the ZoomLayer so they
	# stay aligned with the image when zooming/panning.
	for d_id in DOMAIN_POS.keys():
		var pos: Vector2 = DOMAIN_POS[d_id]
		var dh: Vector2 = _domain_half[d_id]
		var btn := Button.new()
		btn.flat = true
		btn.text = ""
		btn.anchor_left = pos.x - dh.x
		btn.anchor_right = pos.x + dh.x
		btn.anchor_top = pos.y - dh.y
		btn.anchor_bottom = pos.y + dh.y
		btn.offset_left = 0
		btn.offset_right = 0
		btn.offset_top = 0
		btn.offset_bottom = 0
		var did: int = d_id
		btn.pressed.connect(func(): _on_domain_clicked(did))
		# Drag handler — only active in calibration mode (FAB → Hotspots).
		# Reads InputEventMouseMotion / InputEventScreenDrag and slides
		# the button's anchors so we can re-position the click area
		# directly on the live board.
		btn.gui_input.connect(_on_hotspot_calibration_input.bind(did))
		_zoom_layer.add_child(btn)
		_hotspots[d_id] = btn

		# Domain name caption — INDEPENDENT zone (own DOMAIN_NAME_POS +
		# DOMAIN_NAME_HALF, fully calibratable from FAB → Hotspots, dumped
		# alongside the Domain hotspot positions). Built outside the per-
		# Domain loop body — see _build_domain_name_labels() right after.

		# Two-row layout for the bottom strip of each Domain hotspot :
		#   Row A (top, ~6 % of board height) : transgression markers
		#       (Scandale circles, Infamie diamonds) and corruption squares.
		#   Row B (bottom, ~4 %)              : DomainBadges — controller /
		#       sealed / penitence drawn as primitives so they don't depend
		#       on font glyph coverage.
		# Both anchored as children of _zoom_layer so they zoom with the board.

		var chip_row := HFlowContainer.new()
		chip_row.anchor_left = pos.x - dh.x
		chip_row.anchor_right = pos.x + dh.x
		chip_row.anchor_top = pos.y + dh.y - 0.10
		chip_row.anchor_bottom = pos.y + dh.y - 0.04
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
		badges_row.anchor_left = pos.x - dh.x
		badges_row.anchor_right = pos.x + dh.x
		badges_row.anchor_top = pos.y + dh.y - 0.04
		badges_row.anchor_bottom = pos.y + dh.y
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

	# Penitence arch overlay — single full-board Control above the hotspots
	# (added last among the board children so its strokes draw on top). Seed
	# the live rise map from the PENITENCE_ARCH_RISE const (the arch box itself
	# is derived from the hotspot anchors each refresh, not stored here).
	for d_id in PENITENCE_ARCH_RISE.keys():
		_arch_rise[d_id] = float(PENITENCE_ARCH_RISE[d_id])
	_arch_overlay = PenitenceArch.new()
	_arch_overlay.name = "PenitenceArchOverlay"
	_zoom_layer.add_child(_arch_overlay)

	_ascendant_pawn = AscendantPawn.new()
	_ascendant_pawn.name = "AscendantPawn"
	_zoom_layer.add_child(_ascendant_pawn)
	_position_ascendant_pawn(0)

	# Domain name caption labels — own POS / HALF, calibratable as
	# independent zones via FAB → Hotspots.
	_build_domain_name_labels()

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

	# Floating toast for action results (refusal in particular — the log
	# is hidden by default so refusals would otherwise be invisible).
	_build_action_toast()

	# Action menu (custom parchment panel, overlays the board + HUD)
	_action_menu = DomainActionMenu.new()
	_action_menu.action_chosen.connect(_on_menu_action)
	add_child(_action_menu)

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
	# Hamburger icon drawn in code (three horizontal bars) rather than a
	# Unicode glyph — both ≡ U+2261 and ☰ U+2630 tofu-ed on the embedded
	# font Godot ships with the web export, and ellipsis variants don't
	# read as "menu". Generating a tiny PNG-equivalent ImageTexture at
	# startup avoids shipping a Material Icons font (~80 kB) just for
	# this one button.
	_fab.text = ""
	_fab.icon = _make_hamburger_icon()
	_fab.expand_icon = true
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


# Stable item ids for the FAB popup — 1000+ so they never collide with the
# ActionId enum or any other id range in this file.
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
const FAB_GLOSSARY   := 1010
const FAB_ARCHES     := 1011


# Hamburger icon synthesised at startup so we don't depend on a Unicode
# glyph (which tofu'd on the embedded font some web-export builds use)
# and don't have to ship a dedicated icon font for one button. Three
# white horizontal bars on transparent, sized for a 28×28 button icon
# slot — Godot scales it down via expand_icon when the FAB is smaller.
func _make_hamburger_icon() -> ImageTexture:
	const W := 28
	const H := 28
	const BAR_THICKNESS := 4
	const BAR_LENGTH := 22
	const BAR_X := (W - BAR_LENGTH) / 2
	const ROWS = [6, 13, 20]   # vertical centre of each of the 3 bars
	const FG := Color(0.95, 0.94, 0.92)  # warm cream — matches button text colour elsewhere
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for cy in ROWS:
		var top: int = cy - BAR_THICKNESS / 2
		img.fill_rect(Rect2i(BAR_X, top, BAR_LENGTH, BAR_THICKNESS), FG)
	return ImageTexture.create_from_image(img)


func _on_fab_pressed() -> void:
	_fab_menu.clear()
	# Drop the glyph prefixes (− / ⊙) — they tofu on the embedded font
	# Godot ships in some web-export builds. The labels are descriptive
	# enough on their own ("Dézoomer", "Recadrer", "Zoomer") that we
	# don't need iconography here.
	_fab_menu.add_item(I18n.t("ui.btn.zoom_out_label"), FAB_ZOOM_OUT)
	_fab_menu.add_item(I18n.t("ui.btn.zoom_reset_label"), FAB_ZOOM_RESET)
	_fab_menu.add_item(I18n.t("ui.btn.zoom_in_label"), FAB_ZOOM_IN)
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
	_fab_menu.add_item(I18n.t("ui.btn.glossary"), FAB_GLOSSARY)
	_fab_menu.add_item(I18n.t("ui.btn.journal"), FAB_JOURNAL)
	_fab_menu.add_item(I18n.t("ui.btn.hotspots"), FAB_HOTSPOTS)
	_fab_menu.add_item(I18n.t("ui.btn.arches"), FAB_ARCHES)
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
		FAB_GLOSSARY:   _on_btn_glossary()
		FAB_JOURNAL:    _on_btn_toggle_log()
		FAB_HOTSPOTS:   _on_btn_toggle_hotspots()
		FAB_ARCHES:     _on_btn_toggle_arches()


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


# Top-centred toast used to surface action results (refusal mainly).
# Built once, hidden by default ; _flash_action_toast(text, kind) drives
# both the per-flash style and the fade-in / hold / fade-out tween.
func _build_action_toast() -> void:
	_action_toast = Panel.new()
	_action_toast.name = "ActionToast"
	_action_toast.anchor_left = 0.5
	_action_toast.anchor_right = 0.5
	_action_toast.anchor_top = 0.0
	_action_toast.offset_left = -260
	_action_toast.offset_right = 260
	_action_toast.offset_top = 24
	_action_toast.offset_bottom = 24 + 64
	_action_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_toast.modulate.a = 0.0
	_action_toast.visible = false
	add_child(_action_toast)

	_action_toast_label = Label.new()
	_action_toast_label.anchor_right = 1.0
	_action_toast_label.anchor_bottom = 1.0
	_action_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_toast_label.add_theme_font_size_override("font_size", 18)
	_action_toast_label.add_theme_constant_override("outline_size", 0)
	_action_toast.add_child(_action_toast_label)


# Pulse a coloured panel at the top of the viewport with `text`.
# `kind` drives the palette : "refused" (warm amber) / "accepted"
# (muted green). Cancels any in-flight tween so consecutive actions
# don't queue up.
func _flash_action_toast(text: String, kind: String) -> void:
	if _action_toast == null or text == "":
		return
	var sb := StyleBoxFlat.new()
	var fg: Color
	match kind:
		"refused":
			sb.bg_color = Color(0.32, 0.20, 0.06, 0.94)
			sb.border_color = Color(0.86, 0.62, 0.20)
			fg = Color(1.00, 0.92, 0.78)
		"accepted":
			sb.bg_color = Color(0.10, 0.22, 0.14, 0.94)
			sb.border_color = Color(0.40, 0.70, 0.45)
			fg = Color(0.86, 1.00, 0.88)
		_:
			sb.bg_color = Color(0.10, 0.10, 0.10, 0.94)
			sb.border_color = Color(0.40, 0.40, 0.40)
			fg = Color(1.00, 1.00, 1.00)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_action_toast.add_theme_stylebox_override("panel", sb)
	_action_toast_label.text = text
	_action_toast_label.add_theme_color_override("font_color", fg)
	_action_toast.visible = true
	if _action_toast_tween != null and _action_toast_tween.is_valid():
		_action_toast_tween.kill()
	_action_toast.modulate.a = 0.0
	_action_toast_tween = create_tween()
	_action_toast_tween.tween_property(_action_toast, "modulate:a", 1.0, 0.15)
	var hold: float = 1.4 if kind == "accepted" else 2.4
	_action_toast_tween.tween_interval(hold)
	_action_toast_tween.tween_property(_action_toast, "modulate:a", 0.0, 0.30)
	_action_toast_tween.tween_callback(func(): _action_toast.visible = false)


# Centralised handler for action results : logs + toasts. Call after
# every manager.perform_action(...). Pass an optional success_text to
# also flash a green toast on accept (default : silent on accept since
# the board itself updates).
func _handle_action_result(result: Dictionary, success_text: String = "") -> void:
	if not result.get("ok", false):
		var msg: String = String(result.get("message", "?"))
		if state != null:
			state.add_log("[%s] %s" % [I18n.t("log.refused"), msg])
		_flash_action_toast(msg, "refused")
		return
	# Successful action — persist the new state so a refresh / iPad swipe
	# away doesn't lose progress. _save_game itself short-circuits on
	# game_over (it deletes the save instead).
	_save_game()
	if success_text != "":
		_flash_action_toast(success_text, "accepted")


# ─── REFRESH ──────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_refresh_status()
	_refresh_overlays()
	_refresh_log()
	_refresh_player_transgression_panels()
	_refresh_active_player_highlight()
	_refresh_fab_highlight()
	_animate_state_deltas()
	_animate_action_feedback()
	_maybe_show_liturgy_dialog()
	_maybe_show_decision_dialog()
	_maybe_show_endgame_dialog()
	_maybe_resume_ai()


# Per-domain board snapshot kept between refreshes so _animate_state_deltas
# can spot what actually changed and flash only the affected slots.
var _prev_board_state: Dictionary = {}
# Domains whose snapshot changed in the most recent _animate_state_deltas
# pass. _animate_action_feedback reads it to anchor effects for actions whose
# kwargs don't carry an explicit domain (e.g. Amplifier).
var _last_changed_domains: Array = []


func _snapshot_board_state() -> Dictionary:
	var snap: Dictionary = {}
	if state == null:
		return snap
	for d_id in DOMAIN_POS.keys():
		var d := state.domain(d_id)
		snap[d_id] = {
			"red": d.red_corruption,
			"blue": d.purple_corruption,
			"seal": d.seal_owner,
			"scandals": d.scandals.size(),
			"infamies": d.infamies.size(),
			"controller": state.controller_of(d_id),
			"penitence": state.is_in_penitence(d_id),
		}
	return snap


# Compare the previous snapshot to the current one ; for every Domain
# that actually changed, brighten the chip row + drawn badges briefly so
# the eye is drawn there. Works for any state change (corruption +/-,
# seal placed/lifted, transgression posed/removed, penitence) without
# needing per-event hooks. First call after launch (snapshot empty) is
# a no-op so we don't flash the initial layout.
func _animate_state_deltas() -> void:
	if state == null:
		return
	var curr: Dictionary = _snapshot_board_state()
	_last_changed_domains = []
	if not _prev_board_state.is_empty():
		for d_id in curr.keys():
			if not _prev_board_state.has(d_id):
				continue
			if _prev_board_state[d_id] != curr[d_id]:
				_last_changed_domains.append(d_id)
				_flash_domain(d_id)
				# Domain just entered Penitence → trace its golden arch in.
				var was_pen: bool = bool((_prev_board_state[d_id] as Dictionary).get("penitence", false))
				var now_pen: bool = bool((curr[d_id] as Dictionary).get("penitence", false))
				if now_pen and not was_pen:
					_spawn_penitence_reveal(d_id)
	_prev_board_state = curr


func _flash_domain(d_id: int) -> void:
	var targets: Array = []
	if _domain_marker_rows.has(d_id):
		targets.append(_domain_marker_rows[d_id])
	if _domain_badges.has(d_id):
		targets.append(_domain_badges[d_id])
	for t in targets:
		var node := t as CanvasItem
		if node == null:
			continue
		node.modulate = Color(1.6, 1.6, 1.6, 1.0)
		var tw := create_tween()
		tw.tween_property(node, "modulate", Color.WHITE, 0.45) \
			.set_trans(Tween.TRANS_EXPO) \
			.set_ease(Tween.EASE_OUT)


# Normalised board centre of a Domain (live hotspot bounds, falls back to the
# DOMAIN_POS const) — used to anchor action effects on the board.
func _domain_center(d_id: int) -> Vector2:
	var btn: Button = _hotspots.get(d_id)
	if btn != null and is_instance_valid(btn):
		return Vector2((btn.anchor_left + btn.anchor_right) * 0.5, (btn.anchor_top + btn.anchor_bottom) * 0.5)
	return DOMAIN_POS.get(d_id, Vector2(0.5, 0.5))


func _banner_center(st: int) -> Vector2:
	return LITURGY_BANNER_POS.get(st, Vector2(0.9, 0.5))


# Spawn a short, self-freeing ActionEffect at a normalised board position.
func _spawn_action_effect(center_norm: Vector2, kind: String, col: Color) -> void:
	if _zoom_layer == null:
		return
	var fx := ActionEffect.new()
	fx.center = center_norm
	fx.kind = kind
	fx.color = col
	_zoom_layer.add_child(fx)
	fx.play()


# Trace the Domain's golden arch contour as it enters Penitence (a brilliant
# gold reveal that fades to the steady PenitenceArch underneath). Reuses the
# live arch geometry, so it follows the calibrated zone rectangle + rise.
func _spawn_penitence_reveal(d_id: int) -> void:
	if _zoom_layer == null:
		return
	var g := _arch_geom(d_id)
	if g.is_empty():
		return
	var fx := ActionEffect.new()
	fx.kind = "penitence"
	fx.arch = g
	_zoom_layer.add_child(fx)
	fx.play(0.85)


# Per-action visual signature, replayed once per accepted move. Reads the
# record TurnManager stamps on perform_action() so it fires identically for
# human taps and for bot moves applied via step_bot_once(). Each action type
# gets its own ActionEffect (drawn shape + colour) anchored on the board ;
# the changed-domain flash from _animate_state_deltas runs alongside. Consumes
# the record so unrelated refreshes don't replay it.
func _animate_action_feedback() -> void:
	if manager == null:
		return
	var action: int = manager.last_action
	if action < 0:
		return
	var who: int = manager.last_action_player
	var kwargs: Dictionary = manager.last_kwargs
	manager.consume_last_action()
	var col: Color = GameEnums.player_color_light(who) if who != GameEnums.PlayerId.NONE else Color.WHITE
	var d: int = int(kwargs.get("domain", -1))
	match action:
		GameEnums.ActionId.INVESTIR:
			if d >= 0:
				_spawn_action_effect(_domain_center(d), "place", col)
		GameEnums.ActionId.EXPLOITER:
			if d >= 0:
				_spawn_action_effect(_domain_center(d), "exploit", col)
		GameEnums.ActionId.SCELLER:
			if d >= 0:
				_spawn_action_effect(_domain_center(d), "seal", Color(0.92, 0.78, 0.35, 1.0))
		GameEnums.ActionId.FISSURER:
			if d >= 0:
				_spawn_action_effect(_domain_center(d), "crack", Color(0.85, 0.80, 0.72, 1.0))
		GameEnums.ActionId.PROVOQUER:
			var pd: int = int(kwargs.get("origin", kwargs.get("target_domain", -1)))
			if pd < 0 and not _last_changed_domains.is_empty():
				pd = int(_last_changed_domains[0])
			if pd >= 0:
				_spawn_action_effect(_domain_center(pd), "spike", col)
		GameEnums.ActionId.AMPLIFIER:
			if not _last_changed_domains.is_empty():
				_spawn_action_effect(_domain_center(int(_last_changed_domains[0])), "amplify", col)
		GameEnums.ActionId.ENTRAVER:
			var st: int = int(kwargs.get("station", -1))
			if st >= 0:
				_spawn_action_effect(_banner_center(st), "hinder", col)
		GameEnums.ActionId.PUISER:
			_spawn_action_effect(Vector2(0.5, 0.92), "shadow", Color(0.45, 0.30, 0.55, 1.0))
		_:
			pass
	# Announce bot moves so a watching human knows what the AI just played.
	# Human moves stay silent on success (the board change is the feedback)
	# per the project's no-success-toast rule.
	if state != null and state.bot_for_player.has(who):
		var key: String = GameEnums.ACTION_NAME_KEYS.get(action, "")
		var action_name: String = I18n.t(key) if key != "" else "?"
		_flash_action_toast("%s — %s" % [GameEnums.player_name(who), action_name], "accepted")


# Whose turn is it ? Active player's panel gets a brighter border + heavier
# shadow ; the other one drops to ~35 % alpha so it visually recedes. Means
# even with two panels stacked next to each other, a glance at the column
# tells you who's playing without having to read the status bar.
func _refresh_active_player_highlight() -> void:
	if _player_panel_red == null or _player_panel_blue == null or state == null:
		return
	var active: int = state.active_player
	_apply_player_panel_style(_player_panel_red, GameEnums.PlayerId.RED, active == GameEnums.PlayerId.RED)
	_apply_player_panel_style(_player_panel_blue, GameEnums.PlayerId.PURPLE, active == GameEnums.PlayerId.PURPLE)


func _apply_player_panel_style(panel: PanelContainer, pid: int, is_active: bool) -> void:
	var accent: Color = GameEnums.player_color_light(pid)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.08, 0.95)
	if is_active:
		sb.border_color = accent
		sb.set_border_width_all(4)
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.60)
		sb.shadow_size = 12
	else:
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.35)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
		sb.shadow_size = 4
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)


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
		# Seal owner can differ from controller (a Seal placed earlier may
		# survive a domination flip). Pass the owner's colour + initial so
		# the badge can paint the padlock in the right hue and stamp R / V
		# inside it for colour-blind discrimination.
		var seal_color := Color(0.86, 0.72, 0.30)
		var seal_letter := ""
		if state.is_sealed(d_id):
			var so: int = state.domain(d_id).seal_owner
			if so != GameEnums.PlayerId.NONE:
				seal_color = GameEnums.player_color_light(so)
				seal_letter = GameEnums.player_name(so).substr(0, 1)
		(_domain_badges[d_id] as DomainBadges).set_state(
			ctrl_color, ctrl_letter, state.is_sealed(d_id), state.is_in_penitence(d_id),
			seal_color, seal_letter)
	# Ascendant only (per-player Corruption pool now shown inside each
	# coloured player panel).
	_ascendant_label.text = "Asc %+d" % state.ascendant
	_refresh_ascendant_pawn()
	_refresh_liturgy_banners()
	_refresh_penitence_arches()


func _refresh_ascendant_pawn() -> void:
	if _ascendant_pawn == null or not is_instance_valid(_ascendant_pawn):
		return
	_ascendant_pawn.set_value(state.ascendant)
	_position_ascendant_pawn(state.ascendant)


# Quadratic Bézier through the three track points : left at t=0, apex at
# t=0.5, right at t=1. The control point is derived so the apex lies exactly
# on the curve at its midpoint (so the value-0 pawn sits on the apex handle).
func _asc_curve_point(t: float) -> Vector2:
	var ctrl: Vector2 = _asc_apex * 2.0 - (_asc_left + _asc_right) * 0.5
	var u: float = 1.0 - t
	return _asc_left * (u * u) + ctrl * (2.0 * u * t) + _asc_right * (t * t)


func _ascendant_t_for(value: int) -> float:
	var clamped := clampi(value, -ASCENDANT_TRACK_LIMIT, ASCENDANT_TRACK_LIMIT)
	return (float(clamped) + float(ASCENDANT_TRACK_LIMIT)) / float(ASCENDANT_TRACK_LIMIT * 2)


func _position_ascendant_pawn(value: int) -> void:
	if _ascendant_pawn == null:
		return
	var p := _asc_curve_point(_ascendant_t_for(value))
	_ascendant_pawn.anchor_left = p.x
	_ascendant_pawn.anchor_right = p.x
	_ascendant_pawn.anchor_top = p.y
	_ascendant_pawn.anchor_bottom = p.y
	_ascendant_pawn.offset_left = -ASCENDANT_PAWN_SIZE.x * 0.5
	_ascendant_pawn.offset_right = ASCENDANT_PAWN_SIZE.x * 0.5
	# Bottom point sits on the painted track pip.
	_ascendant_pawn.offset_top = -ASCENDANT_PAWN_SIZE.y
	_ascendant_pawn.offset_bottom = 0
	_ascendant_pawn.queue_redraw()


# ─── Ascendant track calibration (hooked into FAB → Hotspots) ─────────────────
# Three draggable handles (left / apex / right) reshape the live curve; a row
# of preview pips shows where each integer value lands so the user can match
# the printed "smile". The three points are dumped with the zone calibration.

func _asc_point(key: String) -> Vector2:
	match key:
		"left":  return _asc_left
		"apex":  return _asc_apex
		"right": return _asc_right
	return Vector2.ZERO


func _asc_set_point(key: String, v: Vector2) -> void:
	match key:
		"left":  _asc_left = v
		"apex":  _asc_apex = v
		"right": _asc_right = v


func _build_ascendant_calibration() -> void:
	for key in ["left", "apex", "right"]:
		_build_asc_handle(key)
	# One preview pip per integer value (-10..+10).
	if _asc_pips.is_empty():
		for i in (ASCENDANT_TRACK_LIMIT * 2 + 1):
			var dot := Panel.new()
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var dsb := StyleBoxFlat.new()
			dsb.bg_color = Color(1.0, 0.95, 0.55, 0.85)
			dsb.border_color = Color(0, 0, 0, 0.7)
			dsb.set_border_width_all(1)
			dsb.set_corner_radius_all(3)
			dot.add_theme_stylebox_override("panel", dsb)
			_zoom_layer.add_child(dot)
			_asc_pips.append(dot)
	_refresh_ascendant_calibration()


func _build_asc_handle(key: String) -> void:
	if _asc_handles.has(key):
		return
	var handle := Button.new()
	handle.text = ""
	handle.custom_minimum_size = Vector2(_ASC_HANDLE_SIZE, _ASC_HANDLE_SIZE)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	# Round handle ; apex is violet (the victory accent), endpoints cyan — shape
	# is identical so the colour is the only cue, but they sit far apart.
	var sb := StyleBoxFlat.new()
	sb.bg_color = (Color(0.69, 0.42, 0.81, 0.95) if key == "apex"
		else Color(0.20, 1.0, 1.0, 0.90))
	sb.border_color = Color(0, 0, 0, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(_ASC_HANDLE_SIZE))
	handle.add_theme_stylebox_override("normal",  sb)
	handle.add_theme_stylebox_override("hover",   sb)
	handle.add_theme_stylebox_override("pressed", sb)
	handle.add_theme_stylebox_override("focus",   sb)
	handle.gui_input.connect(_on_asc_handle_input.bind(key))
	_zoom_layer.add_child(handle)
	_asc_handles[key] = handle


func _refresh_ascendant_calibration() -> void:
	for key in _asc_handles.keys():
		var h: Button = _asc_handles[key]
		if h == null or not is_instance_valid(h):
			continue
		var p := _asc_point(key)
		h.anchor_left = p.x
		h.anchor_right = p.x
		h.anchor_top = p.y
		h.anchor_bottom = p.y
		h.offset_left = -_ASC_HANDLE_SIZE / 2.0
		h.offset_top = -_ASC_HANDLE_SIZE / 2.0
		h.offset_right = _ASC_HANDLE_SIZE / 2.0
		h.offset_bottom = _ASC_HANDLE_SIZE / 2.0
	var n: int = _asc_pips.size()
	for i in n:
		var dot: Panel = _asc_pips[i]
		if dot == null or not is_instance_valid(dot):
			continue
		var pp := _asc_curve_point(float(i) / float(maxi(1, n - 1)))
		dot.anchor_left = pp.x
		dot.anchor_right = pp.x
		dot.anchor_top = pp.y
		dot.anchor_bottom = pp.y
		dot.offset_left = -3.0
		dot.offset_top = -3.0
		dot.offset_right = 3.0
		dot.offset_bottom = 3.0
	# Preview the pawn at its live value on the reshaped curve.
	if _ascendant_pawn != null and is_instance_valid(_ascendant_pawn) and state != null:
		_position_ascendant_pawn(state.ascendant)


func _teardown_ascendant_calibration() -> void:
	for key in _asc_handles.keys():
		var h: Button = _asc_handles[key]
		if h != null and is_instance_valid(h):
			h.queue_free()
	_asc_handles.clear()
	for dot in _asc_pips:
		if dot != null and is_instance_valid(dot):
			dot.queue_free()
	_asc_pips.clear()
	if _ascendant_pawn != null and is_instance_valid(_ascendant_pawn) and state != null:
		_position_ascendant_pawn(state.ascendant)


func _on_asc_handle_input(event: InputEvent, key: String) -> void:
	if not _debug_hotspots:
		return
	var delta: Vector2 = Vector2.ZERO
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		delta = mm.relative
	elif event is InputEventScreenDrag:
		delta = (event as InputEventScreenDrag).relative
	else:
		return
	if delta == Vector2.ZERO:
		return
	var screen_size: Vector2 = _zoom_layer.size * _zoom_layer.scale
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	var d := Vector2(delta.x / screen_size.x, delta.y / screen_size.y)
	_asc_set_point(key, _asc_point(key) + d)
	_refresh_ascendant_calibration()


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
	dots.set_counts(d.red_corruption, d.purple_corruption)
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

func _build_domain_name_labels() -> void:
	# Each Domain caption is a standalone Label parented to _zoom_layer
	# with its own anchored bounding box driven by DOMAIN_NAME_POS +
	# _domain_name_half. Default mouse_filter=IGNORE so taps pass through
	# to the painted board ; the calibration tool flips it to STOP when
	# the user enters Hotspots mode so the Label can capture drag events.
	for d_id in DOMAIN_NAME_POS.keys():
		var npos: Vector2 = DOMAIN_NAME_POS[d_id]
		var nh: Vector2 = _domain_name_half[d_id]
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = String(GameEnums.DOMAIN_NAMES.get(d_id, ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", Card.FONT_TITLE)
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
		name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.01))
		name_label.add_theme_constant_override("outline_size", 6)
		name_label.anchor_left = npos.x - nh.x
		name_label.anchor_right = npos.x + nh.x
		name_label.anchor_top = npos.y - nh.y
		name_label.anchor_bottom = npos.y + nh.y
		name_label.offset_left = 0
		name_label.offset_right = 0
		name_label.offset_top = 0
		name_label.offset_bottom = 0
		name_label.gui_input.connect(_on_zone_body_drag.bind(_zone_kind_domain_name(), d_id))
		_zoom_layer.add_child(name_label)
		_domain_name_labels[d_id] = name_label
		# Always-visible yield chip, centred in a thin anchored box just above
		# the name caption. CenterContainer keeps the chip at its intrinsic
		# (pixel) size instead of stretching it with the board.
		var chip_box := CenterContainer.new()
		chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_box.anchor_left = npos.x - nh.x
		chip_box.anchor_right = npos.x + nh.x
		chip_box.anchor_top = npos.y - nh.y - 0.055
		chip_box.anchor_bottom = npos.y - nh.y - 0.012
		chip_box.offset_left = 0
		chip_box.offset_right = 0
		chip_box.offset_top = 0
		chip_box.offset_bottom = 0
		var chip := DomainHintChip.new()
		chip.set_domain(d_id)
		chip_box.add_child(chip)
		_zoom_layer.add_child(chip_box)
		_domain_hint_chips[d_id] = chip


func _build_liturgy_banners() -> void:
	for st in LITURGY_BANNER_POS:
		var pos: Vector2 = LITURGY_BANNER_POS[st]
		var bh: Vector2 = _banner_half[st]
		# Outer Control hosts the image (TextureRect filling the panel) + the
		# explanatory text Label overlaid on the cartouche area to the right.
		var panel := Control.new()
		panel.anchor_left = pos.x - bh.x
		panel.anchor_right = pos.x + bh.x
		panel.anchor_top = pos.y - bh.y
		panel.anchor_bottom = pos.y + bh.y
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_liturgy_banner_input.bind(st))
		panel.clip_contents = true
		# Tooltip — desktop hover hint that the banner is tappable.
		# Mobile users discover via the (now-systematic) outline below.
		panel.tooltip_text = (I18n.t("ui.tooltip.exorcism_banner")
			if st == GameEnums.StationId.EXORCISME
			else I18n.t("ui.tooltip.liturgy_banner"))

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

		# Outline systématique sur chaque banner — discreet sepia for the
		# five Liturgies, slightly more saturated red-violet for the
		# Exorcism so Station VI still reads as the endgame outlier of the
		# column. Painted as a transparent-fill Panel so the underlying
		# banner artwork stays visible ; a hairline edge that shouts
		# « tappable » to a mobile user without a hover state.
		var border := Panel.new()
		border.name = "Border"
		border.anchor_right = 1.0
		border.anchor_bottom = 1.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0, 0, 0, 0)
		if st == GameEnums.StationId.EXORCISME:
			bsb.border_color = Color(0.32, 0.18, 0.24, 0.85)
		else:
			bsb.border_color = Color(0.28, 0.20, 0.10, 0.55)
		bsb.set_border_width_all(2)
		bsb.set_corner_radius_all(3)
		border.add_theme_stylebox_override("panel", bsb)
		panel.add_child(border)

		# Label sits on top of both, anchored to the parchment cartouche
		# zone — values determined by tools/banner_calibrate.py over the
		# 10 shipped banner masters (mean cartouche bbox L=0.39 T=0.09
		# R=0.93 B=0.89, nudged 1 % inward so the text tucks comfortably
		# even on the loosest banner). Re-run the script if the artwork
		# changes.
		var lbl := Label.new()
		lbl.anchor_left = 0.40
		lbl.anchor_right = 0.92
		lbl.anchor_top = 0.10
		lbl.anchor_bottom = 0.89
		lbl.offset_left = 6
		lbl.offset_right = -10
		lbl.offset_top = 0
		lbl.offset_bottom = 0
		# Match the body-text styling of Card.tscn : IMFellEnglish-Regular
		# at 20 pt, dark-ink colour. The banner cartouche reads as the
		# printed page underneath the same liturgy that the card represents,
		# so using the same calligraphic font + size keeps the visual
		# continuity between banner and card. Safe to use Card.FONT_BODY
		# directly here because Main._ready() now calls
		# Card._configure_card_fonts() upfront (idempotent guard inside),
		# so MSDF + fallbacks are wired before this Label requests a
		# glyph layout — no "Parameter fd is null" errors from the text
		# server racing with a deferred clear_cache().
		lbl.add_theme_font_override("font", Card.FONT_BODY)
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", Color(0.16, 0.07, 0.03))
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
# Multi-touch suppressed : if a second finger lands during the gesture
# (the user is trying to pinch-zoom the board), we abort the tap so the
# release of the first finger doesn't false-trigger the dialog.
var _banner_touches: Dictionary = {}
var _banner_was_multi: bool = false
# Same emulate_mouse_from_touch dedupe story as the fullscreen card —
# a tap on a tablet would otherwise both fire ScreenTouch + a synthesised
# MouseButton, opening the dialog twice.
var _banner_last_touch_ms: int = -1


func _on_liturgy_banner_input(event: InputEvent, station: int) -> void:
	# Calibration mode short-circuit : when the user is in FAB → Hotspots,
	# any drag on a banner panel becomes a move-the-zone gesture rather
	# than a tap-opens-dialog gesture. The body-drag helper consumes the
	# event when relevant ; we still let the rest of the handler run for
	# the click flow when calibration is off.
	if _debug_hotspots:
		_on_zone_body_drag(event, _zone_kind_banner(), station)
		return
	var pressed_release: bool = false
	if event is InputEventMouseButton:
		if _banner_last_touch_ms >= 0 and \
				Time.get_ticks_msec() - _banner_last_touch_ms < _MOUSE_AFTER_TOUCH_GRACE_MS:
			return
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			pressed_release = true
	elif event is InputEventScreenTouch:
		var st_event: InputEventScreenTouch = event
		_banner_last_touch_ms = Time.get_ticks_msec()
		if st_event.pressed:
			_banner_touches[st_event.index] = st_event.position
			if _banner_touches.size() >= 2:
				_banner_was_multi = true
			return
		_banner_touches.erase(st_event.index)
		if not _banner_touches.is_empty():
			# Other fingers still down — wait for the last release before
			# deciding tap vs. pinch.
			return
		# Final release : only treat as tap if the gesture was single-finger
		# throughout. Pinch always reaches here with _banner_was_multi true.
		var was_single: bool = not _banner_was_multi
		_banner_was_multi = false
		if not was_single:
			return
		pressed_release = true
	if not pressed_release:
		return
	if state == null:
		return
	# Station VI has no liturgical response — show the static endgame card,
	# with a text-only back side describing the Rupture / winner-determination
	# rules (since the Exorcism can't be entravé but does need explaining).
	if station == GameEnums.StationId.EXORCISME:
		var endgame_tex := CardImages.exorcisme()
		if endgame_tex != null:
			_show_fullscreen_card(endgame_tex, I18n.t("ui.dialog.title.endgame"), I18n.t("liturgy.exorcisme.back"))
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
	var bundle_blue: Dictionary = _build_placed_column(GameEnums.PlayerId.PURPLE)
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
	var bundle_blue: Dictionary = _build_player_panel(GameEnums.PlayerId.PURPLE, GameEnums.player_color_light(GameEnums.PlayerId.PURPLE))
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
		var n_b: int = state.available_corruption[GameEnums.PlayerId.PURPLE]
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
	# Calibration mode swallows taps so a drag-to-move gesture doesn't also
	# fire the action menu (only the gui_input drag handler should react).
	if _debug_hotspots:
		return
	if state.game_over:
		return
	if state.has_pending_decisions():
		state.add_log(I18n.t("log.pending_decision_unhandled"))
		_refresh_log()
		return
	_selected_domain = d_id
	var at: Vector2 = get_viewport().get_mouse_position()
	_action_menu.open_for(d_id, state, state.active_player, at)


func _on_menu_action(payload: Dictionary) -> void:
	if _selected_domain < 0:
		return
	var result: Dictionary
	match int(payload.get("kind", -1)):
		DomainActionMenu.Kind.BASE:
			result = manager.perform_action(int(payload["action_id"]),
				{"domain": _selected_domain})
		DomainActionMenu.Kind.PROVOKE:
			result = manager.perform_action(GameEnums.ActionId.PROVOQUER,
				{"def_id": String(payload["tid"]), "origin": int(payload["origin"])})
		DomainActionMenu.Kind.AMPLIFY:
			result = manager.perform_action(GameEnums.ActionId.AMPLIFIER,
				{"def_id": String(payload["tid"])})
		_:
			_selected_domain = -1
			return
	_handle_action_result(result)
	_selected_domain = -1
	_refresh_all()


# ─── DEBUG BUTTONS ────────────────────────────────────────────────────────────

func _on_btn_new_game() -> void:
	# Offer the human/AI side picker first; the actual start happens in
	# _start_new_game() once the player confirms their choice.
	_show_new_game_dialog()


# Small modal letting the player set each side to Human or AI before
# starting. Built lazily; reused across new-game requests. Pre-selects the
# previous game's config so repeat starts are one tap.
func _show_new_game_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.exclusive = true
	dlg.title = I18n.t("ui.dialog.title.new_game")
	dlg.ok_button_text = I18n.t("ui.dialog.start")
	dlg.add_cancel_button(I18n.t("ui.dialog.cancel"))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	dlg.add_child(box)

	var picks: Dictionary = {}
	for pid in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := Label.new()
		name_lbl.text = GameEnums.player_name(pid)
		name_lbl.custom_minimum_size = Vector2(160, 0)
		name_lbl.add_theme_color_override("font_color", GameEnums.player_color_light(pid))
		row.add_child(name_lbl)
		var opt := OptionButton.new()
		opt.add_item(I18n.t("ui.player.human"), 0)   # idx 0 -> PLAYER_HUMAN
		opt.add_item(I18n.t("ui.player.ai"), 1)       # idx 1 -> PLAYER_AI
		opt.selected = 1 if _player_config.get(pid, PLAYER_HUMAN) == PLAYER_AI else 0
		row.add_child(opt)
		picks[pid] = opt
		box.add_child(row)

	add_child(dlg)
	dlg.confirmed.connect(func():
		var config := {}
		for pid in picks.keys():
			config[pid] = PLAYER_AI if (picks[pid] as OptionButton).selected == 1 else PLAYER_HUMAN
		_start_new_game(config)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered()


func _start_new_game(config: Dictionary) -> void:
	# Manual new-game wipes any persisted save so the next refresh starts
	# fresh too (otherwise the resume prompt would offer the *previous*
	# game's state on next launch).
	_delete_save()
	new_game(config)
	state.add_log(I18n.t("log.new_game", [Time.get_time_string_from_system()]))
	_refresh_log()


func _on_btn_force_next_station() -> void:
	if state.game_over:
		return
	state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
	manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
	manager._pulse_actions_done[GameEnums.PlayerId.PURPLE] = true
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
	_handle_action_result(result)
	_refresh_all()


func _on_btn_toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		_refresh_log()


# Pop a modal listing the key terms (Domaine, Emprise, Sceau, etc.) so a
# new player can look up vocabulary without leaving the game.
# Built lazily on first request — the body text comes from i18n keys
# under glossary.* and is reformatted on every open in the current
# locale (in case the user toggled FR <-> EN since last open).
func _on_btn_glossary() -> void:
	if _glossary_dialog == null:
		_glossary_dialog = AcceptDialog.new()
		_glossary_dialog.exclusive = true
		_glossary_dialog.ok_button_text = I18n.t("ui.dialog.close")
		add_child(_glossary_dialog)
		_make_dialog_touch_friendly(_glossary_dialog)
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = false
		rtl.scroll_active = true
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rtl.add_theme_font_size_override("normal_font_size", 18)
		rtl.add_theme_font_size_override("bold_font_size", 22)
		rtl.name = "GlossaryRTL"
		_glossary_dialog.add_child(rtl)
	var rtl: RichTextLabel = _glossary_dialog.get_node("GlossaryRTL")
	rtl.clear()
	# Pull each glossary term from i18n. Format : "[b]Term[/b] — definition."
	# Keeps the schema flat so adding a term means one new pair of keys.
	const TERMS := [
		"domain", "emprise", "domination",
		"transgression", "scandale", "infamie",
		"sceau", "penitence",
		"liturgie", "in_integro", "impedita",
		"rupture_ame", "fiat_tenebris", "ascendant",
	]
	for k in TERMS:
		var label_key: String = "glossary." + k + ".name"
		var def_key: String = "glossary." + k + ".def"
		rtl.append_text("[b]%s[/b] — %s\n\n" % [I18n.t(label_key), I18n.t(def_key)])
	_glossary_dialog.title = I18n.t("ui.dialog.title.glossary")
	_popup_dialog_fullscreen(_glossary_dialog)


# ─── CALIBRATION MODE ─────────────────────────────────────────────────────────
#
# Toggleable from the FAB → Hotspots menu. Paints every "zone" on the live
# board with a translucent cyan overlay, lets the user drag the body to move
# the centre AND drag four corner handles to resize symmetrically (centre
# preserved). Each zone shows its name + (cx, cy) + (half_x × half_y) on a
# floating label so the values being calibrated are always visible.
#
# Two zone kinds participate :
#   - "domain" : the five Domain hotspots (Ambition / Désir / Foi / Peur /
#     Volonté). Identifier = GameEnums.DomainId enum value.
#   - "banner" : the six Liturgy banner panels (Stations I-V + Exorcisme).
#     Identifier = GameEnums.StationId enum value.
#
# Toggling off dumps a fully-populated, paste-ready block with the four
# constants — DOMAIN_POS, DOMAIN_HALF_OVERRIDES, LITURGY_BANNER_POS,
# LITURGY_BANNER_HALF_OVERRIDES — into an OS.alert and into the journal.
# Reload the game with the pasted values for a permanent calibration.

# (kind, id) array key → Label showing the zone's name + position + size.
var _calibration_labels: Dictionary = {}
# (kind, id) array key → Array[Button] of 4 corner resize handles.
var _calibration_handles: Dictionary = {}

const _CAL_HANDLE_SIZE := 24
const _CAL_CORNER_TL := 0
const _CAL_CORNER_TR := 1
const _CAL_CORNER_BL := 2
const _CAL_CORNER_BR := 3
const _CAL_MIN_HALF := 0.005   # smallest sensible half-extent in normalised coords


func _on_btn_toggle_hotspots() -> void:
	_debug_hotspots = not _debug_hotspots
	for zk in _all_calibration_zones():
		var kind: String = zk[0]
		var id: int = zk[1]
		var node: Control = _zone_node(kind, id)
		if node == null:
			continue
		if _debug_hotspots:
			_apply_zone_overlay(node)
			_ensure_calibration_label(kind, id)
			_build_corner_handles(kind, id)
		else:
			_remove_zone_overlay(node)
			_remove_calibration_label(kind, id)
			_destroy_corner_handles(kind, id)
	if _debug_hotspots:
		_build_ascendant_calibration()
	else:
		_teardown_ascendant_calibration()
		_dump_calibration_for_paste()


# ─── Zone abstraction ─────────────────────────────────────────────────────────

func _zone_key(kind: String, id: int) -> Array:
	return [kind, id]


func _zone_node(kind: String, id: int) -> Control:
	if kind == "domain":
		return _hotspots.get(id)
	if kind == "banner":
		return _liturgy_banners.get(id)
	if kind == "domain_name":
		return _domain_name_labels.get(id)
	return null


func _zone_name(kind: String, id: int) -> String:
	if kind == "domain":
		return String(GameEnums.DOMAIN_NAMES.get(id, "?"))
	if kind == "banner":
		var st_name: String = String(GameEnums.STATION_NAMES.get(id, "?"))
		return "Bandeau %s" % st_name
	if kind == "domain_name":
		return "Nom %s" % String(GameEnums.DOMAIN_NAMES.get(id, "?"))
	return "?"


func _all_calibration_zones() -> Array:
	# Order : 5 Domains, then 5 Domain-name captions, then 6 Banners.
	# Mirrors the dump order so labels read top-to-bottom in the same
	# sequence in the OS.alert.
	var out: Array = []
	for d_id in DOMAIN_POS.keys():
		out.append([_zone_kind_domain(), d_id])
	for d_id in DOMAIN_NAME_POS.keys():
		out.append([_zone_kind_domain_name(), d_id])
	for st in LITURGY_BANNER_POS.keys():
		out.append([_zone_kind_banner(), st])
	return out


func _zone_kind_domain() -> String:
	return "domain"


func _zone_kind_banner() -> String:
	return "banner"


func _zone_kind_domain_name() -> String:
	return "domain_name"


# Read the zone's *current* centre from the live overlay node — so that
# mid-calibration drags are reflected immediately rather than reading a
# stale const.
func _zone_pos(kind: String, id: int) -> Vector2:
	var n: Control = _zone_node(kind, id)
	if n == null:
		return Vector2.ZERO
	return Vector2((n.anchor_left + n.anchor_right) * 0.5,
		(n.anchor_top + n.anchor_bottom) * 0.5)


func _zone_half(kind: String, id: int) -> Vector2:
	var n: Control = _zone_node(kind, id)
	if n == null:
		return Vector2.ZERO
	return Vector2((n.anchor_right - n.anchor_left) * 0.5,
		(n.anchor_bottom - n.anchor_top) * 0.5)


# ─── Cyan overlay on each zone ────────────────────────────────────────────────

func _apply_zone_overlay(node: Control) -> void:
	if node is Button:
		var btn: Button = node
		btn.flat = false
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 1.0, 1.0, 0.25)
		sb.border_color = Color(0.0, 1.0, 1.0, 1.0)
		sb.set_border_width_all(2)
		btn.add_theme_stylebox_override("normal",  sb)
		btn.add_theme_stylebox_override("hover",   sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus",   sb)
		return
	# Non-Button zones (banners + domain-name captions) — switch mouse_filter
	# to STOP so drag events reach the gui_input handler, stash the previous
	# value as meta to restore on exit. Then drop a transparent Panel child
	# on top to draw the cyan border + tint.
	if not node.has_meta("calibration_prev_mouse_filter"):
		node.set_meta("calibration_prev_mouse_filter", node.mouse_filter)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	var existing := node.get_node_or_null("CalibrationOverlay")
	if existing != null:
		return
	var overlay := Panel.new()
	overlay.name = "CalibrationOverlay"
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 1.0, 1.0, 0.25)
	sb.border_color = Color(0.0, 1.0, 1.0, 1.0)
	sb.set_border_width_all(2)
	overlay.add_theme_stylebox_override("panel", sb)
	node.add_child(overlay)


func _remove_zone_overlay(node: Control) -> void:
	if node is Button:
		var btn: Button = node
		btn.flat = true
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_stylebox_override("focus")
		return
	# Restore the original mouse_filter (banners default to STOP, domain
	# names default to IGNORE). Without this the domain-name labels would
	# stay tappable after exiting calibration and start absorbing taps that
	# should reach the painted board.
	if node.has_meta("calibration_prev_mouse_filter"):
		node.mouse_filter = node.get_meta("calibration_prev_mouse_filter")
		node.remove_meta("calibration_prev_mouse_filter")
	var existing := node.get_node_or_null("CalibrationOverlay")
	if existing != null and is_instance_valid(existing):
		existing.queue_free()


# ─── Floating zone label (name + pos + size) ──────────────────────────────────

func _ensure_calibration_label(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	if _calibration_labels.has(key):
		_refresh_calibration_label(kind, id)
		return
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_layer.add_child(lbl)
	_calibration_labels[key] = lbl
	_refresh_calibration_label(kind, id)


func _remove_calibration_label(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	var lbl: Label = _calibration_labels.get(key)
	if lbl != null and is_instance_valid(lbl):
		lbl.queue_free()
	_calibration_labels.erase(key)


func _refresh_calibration_label(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	var lbl: Label = _calibration_labels.get(key)
	if lbl == null:
		return
	var pos: Vector2 = _zone_pos(kind, id)
	var half: Vector2 = _zone_half(kind, id)
	var name_str: String = _zone_name(kind, id)
	lbl.text = "%s\n(%.3f, %.3f)\n%.3f × %.3f" % [name_str, pos.x, pos.y, half.x, half.y]
	# Centre the label inside the zone.
	lbl.anchor_left = pos.x - half.x
	lbl.anchor_right = pos.x + half.x
	lbl.anchor_top = pos.y - half.y
	lbl.anchor_bottom = pos.y + half.y
	lbl.offset_left = 0
	lbl.offset_right = 0
	lbl.offset_top = 0
	lbl.offset_bottom = 0


# ─── Corner resize handles ────────────────────────────────────────────────────

func _build_corner_handles(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	if _calibration_handles.has(key):
		return
	var handles: Array = []
	for corner in [_CAL_CORNER_TL, _CAL_CORNER_TR, _CAL_CORNER_BL, _CAL_CORNER_BR]:
		var handle := Button.new()
		handle.text = ""
		handle.custom_minimum_size = Vector2(_CAL_HANDLE_SIZE, _CAL_HANDLE_SIZE)
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.85, 0.0, 0.95)
		sb.border_color = Color(0.4, 0.30, 0.0, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(_CAL_HANDLE_SIZE / 2)
		handle.add_theme_stylebox_override("normal",  sb)
		handle.add_theme_stylebox_override("hover",   sb)
		handle.add_theme_stylebox_override("pressed", sb)
		handle.add_theme_stylebox_override("focus",   sb)
		_position_corner_handle(handle, kind, id, corner)
		handle.gui_input.connect(_on_corner_handle_input.bind(kind, id, corner))
		_zoom_layer.add_child(handle)
		handles.append(handle)
	_calibration_handles[key] = handles


func _position_corner_handle(handle: Button, kind: String, id: int, corner: int) -> void:
	var pos: Vector2 = _zone_pos(kind, id)
	var half: Vector2 = _zone_half(kind, id)
	var ax: float = pos.x - half.x
	var ay: float = pos.y - half.y
	if corner == _CAL_CORNER_TR or corner == _CAL_CORNER_BR:
		ax = pos.x + half.x
	if corner == _CAL_CORNER_BL or corner == _CAL_CORNER_BR:
		ay = pos.y + half.y
	handle.anchor_left = ax
	handle.anchor_right = ax
	handle.anchor_top = ay
	handle.anchor_bottom = ay
	handle.offset_left = -_CAL_HANDLE_SIZE / 2.0
	handle.offset_top = -_CAL_HANDLE_SIZE / 2.0
	handle.offset_right = _CAL_HANDLE_SIZE / 2.0
	handle.offset_bottom = _CAL_HANDLE_SIZE / 2.0


func _refresh_corner_handles(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	var handles: Array = _calibration_handles.get(key, [])
	for i in range(handles.size()):
		var h: Button = handles[i]
		if is_instance_valid(h):
			_position_corner_handle(h, kind, id, i)


func _destroy_corner_handles(kind: String, id: int) -> void:
	var key: Array = _zone_key(kind, id)
	var handles: Array = _calibration_handles.get(key, [])
	for h in handles:
		if is_instance_valid(h):
			h.queue_free()
	_calibration_handles.erase(key)


# ─── Drag handlers ────────────────────────────────────────────────────────────

# Generic body-drag handler. Consumed by both Domain hotspot buttons (via
# _on_hotspot_calibration_input below, kept for backwards-compat with the
# existing bound connection in _build_overlays) and by liturgy banner panels
# (called early in _on_liturgy_banner_input).
func _on_zone_body_drag(event: InputEvent, kind: String, id: int) -> bool:
	# Returns true if the event was consumed as a calibration drag.
	if not _debug_hotspots:
		return false
	var delta: Vector2 = Vector2.ZERO
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return false
		delta = mm.relative
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		delta = sd.relative
	else:
		return false
	if delta == Vector2.ZERO:
		return false
	var screen_size: Vector2 = _zoom_layer.size * _zoom_layer.scale
	if screen_size.x <= 0 or screen_size.y <= 0:
		return false
	var dx: float = delta.x / screen_size.x
	var dy: float = delta.y / screen_size.y
	var node: Control = _zone_node(kind, id)
	if node == null:
		return false
	node.anchor_left += dx
	node.anchor_right += dx
	node.anchor_top += dy
	node.anchor_bottom += dy
	_refresh_corner_handles(kind, id)
	_refresh_calibration_label(kind, id)
	return true


# Connected on every Domain hotspot Button at build time. Kept as the
# entry point so the existing `bind(did)` connection still works.
func _on_hotspot_calibration_input(event: InputEvent, d_id: int) -> void:
	_on_zone_body_drag(event, _zone_kind_domain(), d_id)


# Symmetric corner resize. Dragging a corner outward grows the zone ;
# dragging inward shrinks it. Centre is preserved.
func _on_corner_handle_input(event: InputEvent, kind: String, id: int, corner: int) -> void:
	if not _debug_hotspots:
		return
	var delta: Vector2 = Vector2.ZERO
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		delta = mm.relative
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		delta = sd.relative
	else:
		return
	if delta == Vector2.ZERO:
		return
	var screen_size: Vector2 = _zoom_layer.size * _zoom_layer.scale
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	var dx: float = delta.x / screen_size.x
	var dy: float = delta.y / screen_size.y
	# half_x grows when the corner moves outward in x, shrinks otherwise.
	# Same logic in y, signs depend on which corner is being dragged.
	var half_dx: float = dx
	var half_dy: float = dy
	if corner == _CAL_CORNER_TL or corner == _CAL_CORNER_BL:
		half_dx = -dx
	if corner == _CAL_CORNER_TL or corner == _CAL_CORNER_TR:
		half_dy = -dy
	var node: Control = _zone_node(kind, id)
	if node == null:
		return
	var pos: Vector2 = _zone_pos(kind, id)
	var half: Vector2 = _zone_half(kind, id)
	half.x = max(_CAL_MIN_HALF, half.x + half_dx)
	half.y = max(_CAL_MIN_HALF, half.y + half_dy)
	node.anchor_left   = pos.x - half.x
	node.anchor_right  = pos.x + half.x
	node.anchor_top    = pos.y - half.y
	node.anchor_bottom = pos.y + half.y
	# Persist into the per-zone half map so the dump reads the new value.
	if kind == _zone_kind_domain():
		_domain_half[id] = half
	elif kind == _zone_kind_domain_name():
		_domain_name_half[id] = half
	else:
		_banner_half[id] = half
	_refresh_corner_handles(kind, id)
	_refresh_calibration_label(kind, id)


# ─── Paste-ready dump on toggle-off ───────────────────────────────────────────

func _dump_calibration_for_paste() -> void:
	# Snapshot current state from the live overlay nodes (drag may have moved
	# them) plus the per-zone half maps (resize updates them on each delta).
	# Six blocks total :
	#   DOMAIN_POS / DOMAIN_HALF_OVERRIDES (5 entries each)
	#   DOMAIN_NAME_POS / DOMAIN_NAME_HALF_OVERRIDES (5 entries each)
	#   LITURGY_BANNER_POS / LITURGY_BANNER_HALF_OVERRIDES (6 entries each)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("const DOMAIN_POS := {")
	for d_id in DOMAIN_POS.keys():
		var pos: Vector2 = _zone_pos(_zone_kind_domain(), d_id)
		lines.append("\tGameEnums.DomainId.%s: Vector2(%.3f, %.3f)," %
			[_domain_id_to_enum_name(d_id), pos.x, pos.y])
	lines.append("}")
	lines.append("")
	lines.append("const DOMAIN_HALF_OVERRIDES := {")
	for d_id in DOMAIN_POS.keys():
		var half: Vector2 = _zone_half(_zone_kind_domain(), d_id)
		lines.append("\tGameEnums.DomainId.%s: Vector2(%.3f, %.3f)," %
			[_domain_id_to_enum_name(d_id), half.x, half.y])
	lines.append("}")
	lines.append("")
	lines.append("const DOMAIN_NAME_POS := {")
	for d_id in DOMAIN_NAME_POS.keys():
		var pos_n: Vector2 = _zone_pos(_zone_kind_domain_name(), d_id)
		lines.append("\tGameEnums.DomainId.%s: Vector2(%.3f, %.3f)," %
			[_domain_id_to_enum_name(d_id), pos_n.x, pos_n.y])
	lines.append("}")
	lines.append("")
	lines.append("const DOMAIN_NAME_HALF_OVERRIDES := {")
	for d_id in DOMAIN_NAME_POS.keys():
		var half_n: Vector2 = _zone_half(_zone_kind_domain_name(), d_id)
		lines.append("\tGameEnums.DomainId.%s: Vector2(%.3f, %.3f)," %
			[_domain_id_to_enum_name(d_id), half_n.x, half_n.y])
	lines.append("}")
	lines.append("")
	lines.append("const LITURGY_BANNER_POS := {")
	for st in LITURGY_BANNER_POS.keys():
		var pos2: Vector2 = _zone_pos(_zone_kind_banner(), st)
		lines.append("\tGameEnums.StationId.%s: Vector2(%.3f, %.3f)," %
			[_station_id_to_enum_name(st), pos2.x, pos2.y])
	lines.append("}")
	lines.append("")
	lines.append("const LITURGY_BANNER_HALF_OVERRIDES := {")
	for st in LITURGY_BANNER_POS.keys():
		var half2: Vector2 = _zone_half(_zone_kind_banner(), st)
		lines.append("\tGameEnums.StationId.%s: Vector2(%.3f, %.3f)," %
			[_station_id_to_enum_name(st), half2.x, half2.y])
	lines.append("}")
	lines.append("")
	lines.append("const ASCENDANT_TRACK_LEFT  := Vector2(%.3f, %.3f)" % [_asc_left.x, _asc_left.y])
	lines.append("const ASCENDANT_TRACK_APEX  := Vector2(%.3f, %.3f)" % [_asc_apex.x, _asc_apex.y])
	lines.append("const ASCENDANT_TRACK_RIGHT := Vector2(%.3f, %.3f)" % [_asc_right.x, _asc_right.y])

	var block: String = ""
	for ln in lines:
		block += ln + "\n"
	# print() goes to stdout, which on the HTML5 export lands in the
	# browser DevTools console. From there it's a clean copy-paste with
	# correct tabs / Vector2 syntax / closing braces — much more reliable
	# than trying to copy out of the OS.alert (which on Safari can
	# truncate / mangle special characters). Bracket the block with two
	# clear sentinels so it's easy to find in a busy console log.
	#
	# IMPORTANT : ONE console.log entry, not one per line. Godot's
	# print() goes through emscripten's stdout pipe, which on web splits
	# the string on every newline and emits a separate console.log for
	# each — Chrome then re-stamps the "Possession/:216" source prefix
	# on every line and the round-trip copy-paste picks up the prefixes.
	# Bypass print() and invoke window.console.log directly via the
	# JavaScript bridge : a single string in, a single entry out, prefix
	# only on the first visible line of the entry. Falls back to print()
	# on desktop / when JavaScriptBridge isn't available (editor runs).
	var full_dump: String = "\n========== POSSESSION CALIBRATION DUMP — BEGIN ==========\n" \
		+ block \
		+ "========== POSSESSION CALIBRATION DUMP — END ============\n"
	if OS.has_feature("web"):
		var console_obj: Variant = JavaScriptBridge.get_interface("console")
		if console_obj != null:
			console_obj.log(full_dump)
		else:
			print(full_dump)
	else:
		print(full_dump)
	if state != null:
		state.add_log("[Calibration] Nouvelles valeurs :")
		for ln in lines:
			state.add_log(ln)
		_refresh_log()
	OS.alert(block + "\n(Bloc également imprimé dans la console DevTools du navigateur — F12 → Console.)",
		"Calibration — coller dans Main.gd")


# ─── Penitence arch calibration ───────────────────────────────────────────────
# The arch reuses the Domain's zone rectangle (the hotspot Button anchors,
# already calibrated via FAB → Hotspots) as its box ; the only thing we
# calibrate here is the apex RISE above the rectangle's top edge — one value
# per Domain, one draggable handle each (top-centre, vertical drag). On
# toggle-off we dump a paste-ready PENITENCE_ARCH_RISE block.
const _ARCH_HANDLE_SIZE := 26
const _ARCH_MAX_RISE := 0.40   # clamp so the apex can't shoot off the board


# Arch geometry for one Domain, derived live from its zone rectangle (hotspot
# anchors) plus the calibrated rise. Returns {} if the hotspot isn't built.
func _arch_geom(d_id: int) -> Dictionary:
	var btn: Button = _hotspots.get(d_id)
	if btn == null or not is_instance_valid(btn):
		return {}
	var left: float = btn.anchor_left
	var right: float = btn.anchor_right
	var top: float = btn.anchor_top
	var bottom: float = btn.anchor_bottom
	return {
		"cx": (left + right) * 0.5,
		"hw": (right - left) * 0.5,
		"top": top,
		"bottom": bottom,
		"rise": float(_arch_rise.get(d_id, 0.05)),
	}


func _refresh_penitence_arches() -> void:
	# Feed the overlay live geometry (zone rect + rise) and decide which arches
	# it paints : in calibration mode every arch shows ; otherwise only Domains
	# currently in Penitence.
	if _arch_overlay == null:
		return
	var geom: Dictionary = {}
	var vis: Dictionary = {}
	for d_id in _arch_rise.keys():
		var g := _arch_geom(d_id)
		if g.is_empty():
			continue
		geom[d_id] = g
		if _arch_calibrating:
			vis[d_id] = true
		elif state != null and state.is_in_penitence(d_id):
			vis[d_id] = true
	_arch_overlay.set_arches(geom)
	_arch_overlay.set_visible_ids(vis)


func _on_btn_toggle_arches() -> void:
	_arch_calibrating = not _arch_calibrating
	if _arch_calibrating:
		for d_id in _arch_rise.keys():
			_build_arch_handle(d_id)
			_ensure_arch_label(d_id)
	else:
		for d_id in _arch_rise.keys():
			_destroy_arch_handle(d_id)
			_remove_arch_label(d_id)
		_dump_arches_for_paste()
	# Recompute visibility (all arches in calib mode, penitent only otherwise)
	# and force a redraw of the overlay.
	_refresh_penitence_arches()
	if _arch_overlay != null:
		_arch_overlay.queue_redraw()


# Apex handle position : top-centre of the zone rectangle, raised by `rise`.
# Vertical drag changes the rise (see _on_arch_handle_input).
func _arch_apex_pos(d_id: int) -> Vector2:
	var g := _arch_geom(d_id)
	if g.is_empty():
		return Vector2(0.5, 0.5)
	return Vector2(float(g["cx"]), float(g["top"]) - float(g["rise"]))


func _build_arch_handle(d_id: int) -> void:
	if _arch_handles.has(d_id):
		return
	var handle := Button.new()
	handle.text = ""
	handle.custom_minimum_size = Vector2(_ARCH_HANDLE_SIZE, _ARCH_HANDLE_SIZE)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	# Square bright-gold apex handle (shape + colour cue per the accessibility
	# rule). It's the only handle now : vertical drag sets the arch height.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.95, 0.55, 0.95)
	sb.border_color = Color(0.5, 0.40, 0.0, 1.0)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	handle.add_theme_stylebox_override("normal",  sb)
	handle.add_theme_stylebox_override("hover",   sb)
	handle.add_theme_stylebox_override("pressed", sb)
	handle.add_theme_stylebox_override("focus",   sb)
	handle.gui_input.connect(_on_arch_handle_input.bind(d_id))
	_zoom_layer.add_child(handle)
	_arch_handles[d_id] = handle
	_position_arch_handle(handle, d_id)


func _position_arch_handle(handle: Button, d_id: int) -> void:
	var apex := _arch_apex_pos(d_id)
	# Keep the handle on-board (grabbable) even if a tall rise pushes the true
	# apex above the top edge — the arch itself is still drawn at the real apex.
	var hy: float = maxf(apex.y, 0.015)
	handle.anchor_left = apex.x
	handle.anchor_right = apex.x
	handle.anchor_top = hy
	handle.anchor_bottom = hy
	handle.offset_left = -_ARCH_HANDLE_SIZE / 2.0
	handle.offset_top = -_ARCH_HANDLE_SIZE / 2.0
	handle.offset_right = _ARCH_HANDLE_SIZE / 2.0
	handle.offset_bottom = _ARCH_HANDLE_SIZE / 2.0


func _refresh_arch_handles(d_id: int) -> void:
	var h: Button = _arch_handles.get(d_id)
	if h != null and is_instance_valid(h):
		_position_arch_handle(h, d_id)


func _destroy_arch_handle(d_id: int) -> void:
	var h: Button = _arch_handles.get(d_id)
	if h != null and is_instance_valid(h):
		h.queue_free()
	_arch_handles.erase(d_id)


func _ensure_arch_label(d_id: int) -> void:
	if _arch_labels.has(d_id):
		_refresh_arch_label(d_id)
		return
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_layer.add_child(lbl)
	_arch_labels[d_id] = lbl
	_refresh_arch_label(d_id)


func _remove_arch_label(d_id: int) -> void:
	var lbl: Label = _arch_labels.get(d_id)
	if lbl != null and is_instance_valid(lbl):
		lbl.queue_free()
	_arch_labels.erase(d_id)


func _refresh_arch_label(d_id: int) -> void:
	var lbl: Label = _arch_labels.get(d_id)
	if lbl == null:
		return
	var g := _arch_geom(d_id)
	if g.is_empty():
		return
	var name_str: String = String(GameEnums.DOMAIN_NAMES.get(d_id, "?"))
	lbl.text = "%s\nrise %.3f" % [name_str, float(g["rise"])]
	# Anchor the label across the zone rectangle (centred on it).
	var cx: float = float(g["cx"])
	var hw: float = float(g["hw"])
	lbl.anchor_left = cx - hw
	lbl.anchor_right = cx + hw
	lbl.anchor_top = float(g["top"])
	lbl.anchor_bottom = float(g["bottom"])
	lbl.offset_left = 0
	lbl.offset_top = 0
	lbl.offset_right = 0
	lbl.offset_bottom = 0


func _on_arch_handle_input(event: InputEvent, d_id: int) -> void:
	if not _arch_calibrating:
		return
	var delta: Vector2 = Vector2.ZERO
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		delta = mm.relative
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		delta = sd.relative
	else:
		return
	if delta.y == 0.0:
		return
	var screen_size: Vector2 = _zoom_layer.size * _zoom_layer.scale
	if screen_size.y <= 0:
		return
	var dy: float = delta.y / screen_size.y
	# The apex sits at top - rise, so dragging the handle UP (negative dy)
	# raises it → bigger rise ; dragging DOWN flattens the arch.
	var new_rise: float = clampf(float(_arch_rise.get(d_id, 0.05)) - dy, 0.0, _ARCH_MAX_RISE)
	_arch_rise[d_id] = new_rise
	_refresh_penitence_arches()
	_refresh_arch_handles(d_id)
	_refresh_arch_label(d_id)
	# Live-dump the full set to the journal on every change so the user can
	# copy the current coordinates at any time without leaving the mode.
	_log_arches_live()


# Lightweight live log : appends the current PENITENCE_ARCH_RISE values to the
# journal panel so the user reads up-to-date rises while still dragging.
func _log_arches_live() -> void:
	if state == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _arch_log_last_ms < _ARCH_LOG_INTERVAL:
		return
	_arch_log_last_ms = now
	state.add_log("[Arches] " + _arch_block_oneline())
	_refresh_log()


# One-line compact representation for the live journal feedback.
func _arch_block_oneline() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for d_id in _arch_rise.keys():
		parts.append("%s %.3f" % [_domain_id_to_enum_name(d_id), float(_arch_rise[d_id])])
	return " ".join(parts)


# Full paste-ready PENITENCE_ARCH_RISE block, same delivery as the hotspot
# dump : a single console.log entry on web (clean copy-paste) plus the journal
# + OS.alert. Paste it over the PENITENCE_ARCH_RISE const to freeze the values.
func _dump_arches_for_paste() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("const PENITENCE_ARCH_RISE := {")
	for d_id in _arch_rise.keys():
		lines.append("\tGameEnums.DomainId.%s: %.3f," % [
			_domain_id_to_enum_name(d_id), float(_arch_rise[d_id])])
	lines.append("}")
	var block: String = ""
	for ln in lines:
		block += ln + "\n"
	var full_dump: String = "\n========== POSSESSION ARCH DUMP — BEGIN ==========\n" \
		+ block \
		+ "========== POSSESSION ARCH DUMP — END ============\n"
	if OS.has_feature("web"):
		var console_obj: Variant = JavaScriptBridge.get_interface("console")
		if console_obj != null:
			console_obj.log(full_dump)
		else:
			print(full_dump)
	else:
		print(full_dump)
	if state != null:
		state.add_log("[Arches] Nouvelles valeurs :")
		for ln in lines:
			state.add_log(ln)
		_refresh_log()
	OS.alert(block + "\n(Bloc également imprimé dans la console DevTools du navigateur — F12 → Console.)",
		"Arches pénitence — coller dans Main.gd")


# Map DomainId int → constant name. Used to emit the
# `GameEnums.DomainId.FOI` form rather than the numeric value in the
# paste-ready block, so the dumped block is human-readable.
func _domain_id_to_enum_name(d_id: int) -> String:
	match d_id:
		GameEnums.DomainId.AMBITION: return "AMBITION"
		GameEnums.DomainId.DESIR:    return "DESIR"
		GameEnums.DomainId.FOI:      return "FOI"
		GameEnums.DomainId.PEUR:     return "PEUR"
		GameEnums.DomainId.VOLONTE:  return "VOLONTE"
	return "UNKNOWN"


# Same idea for StationId — used in the LITURGY_BANNER_POS /
# LITURGY_BANNER_HALF_OVERRIDES dump so the keys stay readable.
func _station_id_to_enum_name(st: int) -> String:
	match st:
		GameEnums.StationId.MURMURES:   return "MURMURES"
		GameEnums.StationId.TENTATION:  return "TENTATION"
		GameEnums.StationId.CHUTE:      return "CHUTE"
		GameEnums.StationId.CONFESSION: return "CONFESSION"
		GameEnums.StationId.OFFICE:     return "OFFICE"
		GameEnums.StationId.EXORCISME:  return "EXORCISME"
	return "UNKNOWN"


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
	_save_game()
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
	_handle_action_result(r)
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
	_handle_action_result(r)
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
	# Detach the pooled thumbnails first so the queue_free below frees the old
	# item rows WITHOUT taking the (reusable) Card thumbnails down with them.
	# They get reparented into the freshly built rows by _make_transgression_card.
	for tid in _trans_thumb_pool:
		var thumb: Control = _trans_thumb_pool[tid]
		if is_instance_valid(thumb) and thumb.get_parent() != null:
			thumb.get_parent().remove_child(thumb)
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

	# Card thumbnail — pooled across dialog opens (see _trans_thumb_pool) and
	# re-bound to the current face. Composed at runtime so text follows locale.
	var img: Control = _get_or_make_trans_thumb(tid)
	img.set_meta("face", face)
	(img.get_meta("card_node") as Card).setup_transgression(tid, face)
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


# Returns the pooled card thumbnail for `tid`, building it on first request.
# The thumbnail (a Card.tscn wrapper from _make_card_thumb) is expensive to
# build and depends only on tid, so it survives across Transgressions-dialog
# opens. The click→zoom handler is wired once here ; it re-derives the card
# name from `tid` at click time, so a locale switch between opens can't leave
# a stale window title bound into the connection.
func _get_or_make_trans_thumb(tid: String) -> Control:
	if _trans_thumb_pool.has(tid):
		return _trans_thumb_pool[tid]
	var img: Control = _make_card_thumb(Vector2(240, 336))
	img.set_meta("tid", tid)
	(img.get_meta("click_btn") as Button).pressed.connect(
		_on_transgression_image_clicked.bind(img, tid))
	_trans_thumb_pool[tid] = img
	return img


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
	# Tapping the body text re-renders the effect in a high-contrast popup,
	# pulling a longer .detail variant when one's been shipped in i18n.
	_fullscreen_card_node.effect_info_requested.connect(_on_card_effect_info_requested)

	# Static-card holder : both faces of the Exorcism live inside a single
	# AspectRatioContainer (720/1008, the card's printed ratio) so they
	# share size + pivot, which lets the flip animation feel like turning a
	# real card. Parent of _fullscreen_card_image (front) and the back
	# parchment panel (back).
	_static_card_holder = AspectRatioContainer.new()
	_static_card_holder.ratio = 720.0 / 1008.0
	_static_card_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_static_card_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_static_card_holder.visible = false
	# Tap anywhere on the static card area flips it, same as the composed
	# Card.tscn path. We piggy-back on the existing _on_fullscreen_card_input
	# handler — it dispatches by binding.kind and routes "static" through
	# the dedicated tween.
	_static_card_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	_static_card_holder.gui_input.connect(_on_fullscreen_card_input)
	vbox.add_child(_static_card_holder)

	# Front : painted texture, anchored full-bleed inside the holder.
	_fullscreen_card_image = TextureRect.new()
	_fullscreen_card_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fullscreen_card_image.stretch_mode = TextureRect.STRETCH_SCALE
	_fullscreen_card_image.anchor_right = 1.0
	_fullscreen_card_image.anchor_bottom = 1.0
	# Pass clicks through so taps flip the card (handled on the holder).
	_fullscreen_card_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fullscreen_card_image.visible = false
	_static_card_holder.add_child(_fullscreen_card_image)

	# Back : parchment-styled PanelContainer holding a RichText. Same outer
	# shape as the painted front, with IM Fell typography and dark ink so
	# it reads as the actual back of the card rather than a separate panel.
	_fullscreen_card_back_panel = PanelContainer.new()
	_fullscreen_card_back_panel.anchor_right = 1.0
	_fullscreen_card_back_panel.anchor_bottom = 1.0
	var back_sb := StyleBoxFlat.new()
	back_sb.bg_color = Color(0.86, 0.78, 0.62)              # parchment
	back_sb.border_color = Color(0.42, 0.28, 0.16)          # umber border
	back_sb.set_border_width_all(4)
	back_sb.set_corner_radius_all(14)
	back_sb.set_content_margin_all(24)
	_fullscreen_card_back_panel.add_theme_stylebox_override("panel", back_sb)
	_fullscreen_card_back_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fullscreen_card_back_panel.visible = false
	_static_card_holder.add_child(_fullscreen_card_back_panel)

	_fullscreen_card_back = RichTextLabel.new()
	_fullscreen_card_back.bbcode_enabled = true
	_fullscreen_card_back.fit_content = false
	_fullscreen_card_back.scroll_active = false
	# Same passthrough rationale as the front : a tap on the rules text
	# flips the card back, rather than being swallowed by the label.
	_fullscreen_card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fullscreen_card_back.add_theme_color_override("default_color", Color(0.16, 0.07, 0.03))
	_fullscreen_card_back.add_theme_font_override("normal_font", Card.FONT_BODY)
	_fullscreen_card_back.add_theme_font_override("bold_font", Card.FONT_TITLE)
	_fullscreen_card_back.add_theme_font_size_override("normal_font_size", 24)
	_fullscreen_card_back.add_theme_font_size_override("bold_font_size", 28)
	_fullscreen_card_back_panel.add_child(_fullscreen_card_back)

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
func _show_fullscreen_card(tex: Texture2D, title_str: String = "Carte", back_text: String = "") -> void:
	if tex == null:
		return
	_fullscreen_card_aspect.visible = false
	_static_card_holder.visible = true
	# Reset any leftover flip transform from a previous open.
	_static_card_holder.scale = Vector2.ONE
	_static_card_holder.rotation = 0.0
	_static_card_holder.modulate = Color.WHITE
	_fullscreen_card_image.visible = true
	_fullscreen_card_image.texture = tex
	_fullscreen_card_back_panel.visible = false
	# Cards that don't have a meaningful "other side" pass back_text == ""
	# and stay un-flippable. When a back text is provided (Exorcism : the
	# front is the painted card, the back is the winner-determination
	# ruleset), the binding becomes {kind:"static", face:"front", ...}
	# so the flip button is offered.
	if back_text == "":
		_fullscreen_card_flip_btn.visible = false
		_fullscreen_card_entraver_btn.visible = false
		_fullscreen_card_binding = {}
	else:
		_fullscreen_card_back.text = back_text
		_fullscreen_card_binding = {
			"kind": "static",
			"face": "front",
			"texture": tex,
			"back_text": back_text,
			"title": title_str,
		}
		_update_fullscreen_flip_button()
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


func _show_fullscreen_transgression(tid: String, face: int, title_str: String) -> void:
	_fullscreen_card_aspect.visible = true
	_static_card_holder.visible = false
	_fullscreen_card_node.setup_transgression(tid, face)
	_fullscreen_card_binding = {"kind": "transgression", "tid": tid, "face": face}
	_update_fullscreen_flip_button()
	_fullscreen_card_dialog.title = title_str
	_popup_dialog_fullscreen(_fullscreen_card_dialog)


func _show_fullscreen_liturgy(station: int, impedita: bool, title_str: String, target_domain: int = -2, target_player: int = -2) -> void:
	_fullscreen_card_aspect.visible = true
	_static_card_holder.visible = false
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
	elif kind == "static":
		# Static-image card with a textual back side (Exorcism). Flip toggles
		# image ↔ rules text ; entraver never applies.
		var face: String = String(_fullscreen_card_binding.get("face", "front"))
		_fullscreen_card_flip_btn.text = I18n.t("ui.flip.see_back") if face == "front" else I18n.t("ui.flip.see_front")
		_fullscreen_card_flip_btn.visible = true
		_fullscreen_card_entraver_btn.visible = false
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
	# V1h : the button label depends on how many legal payment Domains
	# the active demon has. One option → name it ; multiple → generic
	# label, the picker dialog will let them choose ; zero is impossible
	# here because `legal == true` already guarantees the option set.
	var options: Array = GameRules.entrave_payment_options(state, p, st)
	if options.size() == 1:
		var dom_str: String = String(GameEnums.DOMAIN_NAMES.get(options[0], "?"))
		_fullscreen_card_entraver_btn.text = I18n.t("ui.btn.entraver_cost", [dom_str])
	else:
		_fullscreen_card_entraver_btn.text = I18n.t("ui.btn.entraver_cost_generic")
	_fullscreen_card_entraver_btn.disabled = not legal
	_fullscreen_card_entraver_btn.tooltip_text = why if not legal else I18n.t("ui.btn.entraver.tooltip")


func _on_fullscreen_card_entraver_pressed() -> void:
	if state == null or _fullscreen_card_binding.is_empty():
		return
	var st: int = int(_fullscreen_card_binding.get("station", -1))
	if st < 0:
		return
	var p: int = state.active_player
	var options: Array = GameRules.entrave_payment_options(state, p, st)
	if options.is_empty():
		return
	if options.size() == 1:
		_do_entraver(st, options[0])
	else:
		_show_entrave_payment_picker(st, options)


func _do_entraver(station: int, payment_domain: int) -> void:
	var result := manager.perform_action(GameEnums.ActionId.ENTRAVER,
		{"station": station, "payment_domain": payment_domain})
	_handle_action_result(result)
	if result.get("ok", false):
		# Reflect the new state on the binding, the banner, and the
		# button row of the open dialog.
		_fullscreen_card_binding["impedita"] = true
		var t_dom: int = int(_fullscreen_card_binding.get("target_domain", -1))
		var t_pl: int = int(_fullscreen_card_binding.get("target_player", -1))
		_fullscreen_card_node.flip_to_liturgy(station, true, t_dom, t_pl)
		_update_fullscreen_flip_button()
	_refresh_all()


# V1h : when several linked Domains qualify as payment sources, ask the
# user which one to drain. Each option becomes a button in the dialog ;
# clicking commits the Entrave with that payment_domain. Cancel closes
# the dialog without acting.
func _show_entrave_payment_picker(station: int, options: Array) -> void:
	var dlg := AcceptDialog.new()
	dlg.exclusive = true
	dlg.title = I18n.t("ui.dialog.title.entrave_pick")
	dlg.dialog_text = I18n.t("ui.dialog.entrave_pick_prompt")
	dlg.ok_button_text = I18n.t("ui.dialog.close")
	add_child(dlg)
	for d_id in options:
		var dom_str: String = String(GameEnums.DOMAIN_NAMES.get(d_id, "?"))
		var btn := dlg.add_button(dom_str, true, "pick_%d" % int(d_id))
		var captured_d: int = int(d_id)
		var captured_dlg := dlg
		var captured_st := station
		btn.pressed.connect(func():
			captured_dlg.hide()
			captured_dlg.queue_free()
			_do_entraver(captured_st, captured_d)
		)
	dlg.popup_centered()


# Tap or swipe anywhere on the fullscreen card area flips it. We treat any
# left-mouse / touch release as "user wants to flip" — both quick taps and
# horizontal swipes count, since all of them mean the same thing here.
# Multi-touch is filtered out : if a second finger ever lands during the
# gesture, we don't flip on the eventual release. Lets a pinch-zoom
# attempt on the card ride through cleanly even if the user's index
# fingers happen to start on the card area.
var _fullscreen_card_press_pos: Vector2 = Vector2.INF
var _fullscreen_card_touches: Dictionary = {}
var _fullscreen_card_was_multi: bool = false
# emulate_mouse_from_touch is on by default in Godot, so a tap on a
# touchscreen fires *both* an InputEventScreenTouch and a synthesised
# InputEventMouseButton. Without dedupe, both branches below would each
# flip the card → the visible state ends back at the starting face for
# every tap, looking like nothing happened. Stash the timestamp of the
# last touch handled and skip mouse events that arrive within 250 ms.
var _fullscreen_card_last_touch_ms: int = -1
const _MOUSE_AFTER_TOUCH_GRACE_MS := 250


func _on_fullscreen_card_input(event: InputEvent) -> void:
	if _fullscreen_card_binding.is_empty():
		return
	if event is InputEventMouseButton:
		# Drop the synthesised mouse event that mirrors a finger tap.
		if _fullscreen_card_last_touch_ms >= 0 and \
				Time.get_ticks_msec() - _fullscreen_card_last_touch_ms < _MOUSE_AFTER_TOUCH_GRACE_MS:
			return
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
		_fullscreen_card_last_touch_ms = Time.get_ticks_msec()
		if st.pressed:
			_fullscreen_card_touches[st.index] = st.position
			if _fullscreen_card_touches.size() >= 2:
				_fullscreen_card_was_multi = true
			return
		_fullscreen_card_touches.erase(st.index)
		# Wait until every finger is up before deciding — multi-touch on
		# release of the first finger would otherwise still trigger.
		if not _fullscreen_card_touches.is_empty():
			return
		var was_single: bool = not _fullscreen_card_was_multi
		_fullscreen_card_was_multi = false
		if was_single:
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


# Re-renders the currently-shown card's effect text in a high-contrast
# popup. Reads the binding off _fullscreen_card_binding rather than taking
# parameters, since that's the source of truth for what's on screen.
# Looks up an optional ".detail" suffix in i18n first (longer wording for
# rules that proved ambiguous in playtesting) and falls back to the base
# text otherwise.
func _on_card_effect_info_requested() -> void:
	if _fullscreen_card_binding.is_empty():
		return
	var kind: String = _fullscreen_card_binding.get("kind", "")
	var base_key: String = ""
	if kind == "liturgy":
		var resp_id: String = String(LiturgicalResponseData.get_response(int(_fullscreen_card_binding.get("station", -1))).get("id", ""))
		if resp_id == "":
			return
		var mode: String = "impedita" if bool(_fullscreen_card_binding.get("impedita", false)) else "in_integro"
		base_key = "liturgy.%s.%s" % [resp_id, mode]
	elif kind == "transgression":
		var tid: String = String(_fullscreen_card_binding.get("tid", ""))
		if tid == "":
			return
		var face_str: String = "infamy" if int(_fullscreen_card_binding.get("face", GameEnums.TransgressionFace.SCANDALE)) == GameEnums.TransgressionFace.INFAMIE else "scandal"
		base_key = "transgression.%s.%s" % [tid, face_str]
	else:
		return

	var detail_key: String = base_key + ".detail"
	var detail_text: String = I18n.t(detail_key)
	# I18n.t falls back to the key itself when the entry is missing — that's
	# our cue to use the regular body text instead.
	var text: String = detail_text if detail_text != detail_key else I18n.t(base_key)

	if _effect_detail_dialog == null:
		_effect_detail_dialog = AcceptDialog.new()
		_effect_detail_dialog.exclusive = true
		_effect_detail_dialog.ok_button_text = I18n.t("ui.dialog.close")
		_effect_detail_dialog.wrap_controls = false
		add_child(_effect_detail_dialog)
		var ok_btn: Button = _effect_detail_dialog.get_ok_button()
		if ok_btn != null:
			ok_btn.add_theme_font_size_override("font_size", 22)
		var dlg_lbl: Label = _effect_detail_dialog.get_label()
		if dlg_lbl != null:
			dlg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dlg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dlg_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_effect_detail_dialog.title = I18n.t("ui.dialog.title.effect_detail")
	_effect_detail_dialog.dialog_text = text
	_effect_detail_dialog.popup_centered_clamped(Vector2i(620, 360))


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
	elif kind == "static":
		_flip_static_card()
		return  # _flip_static_card calls _update_fullscreen_flip_button at end of tween
	_update_fullscreen_flip_button()


# Mirrors Card._run_flip_tween for the static-card holder (Exorcism). Same
# perspective trick — scale.x 1→0→1 to fold edge-on, scale.y compression +
# slight rotation + dim modulate for depth — with the binding swap and
# child-visibility toggle happening at the edge-on midpoint.
const _STATIC_FLIP_HALF_DURATION := 0.22
const _STATIC_FLIP_TILT_DEG := 4.0
const _STATIC_FLIP_DEPTH_SCALE := 0.82
const _STATIC_FLIP_DIM := Color(0.78, 0.74, 0.78)
var _static_is_flipping: bool = false


func _flip_static_card() -> void:
	if _static_is_flipping:
		return
	if _fullscreen_card_binding.is_empty():
		return
	_static_is_flipping = true
	var face: String = String(_fullscreen_card_binding.get("face", "front"))
	var nxt: String = "back" if face == "front" else "front"
	_static_card_holder.pivot_offset = _static_card_holder.size * 0.5
	var dur := _STATIC_FLIP_HALF_DURATION
	var tilt_rad := deg_to_rad(_STATIC_FLIP_TILT_DEG)
	var tw := create_tween()
	# Phase 1 — fold to edge-on.
	tw.tween_property(_static_card_holder, "scale:x", 0.0, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_static_card_holder, "scale:y", _STATIC_FLIP_DEPTH_SCALE, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_static_card_holder, "rotation", tilt_rad, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_static_card_holder, "modulate", _STATIC_FLIP_DIM, dur).set_trans(Tween.TRANS_SINE)
	# Mid-tween : swap which face is shown and persist the binding.
	tw.tween_callback(func():
		_fullscreen_card_binding["face"] = nxt
		_fullscreen_card_image.visible = nxt == "front"
		_fullscreen_card_back_panel.visible = nxt == "back"
		_update_fullscreen_flip_button()
	)
	# Phase 2 — unfold the new face.
	tw.tween_property(_static_card_holder, "scale:x", 1.0, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_static_card_holder, "scale:y", 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_static_card_holder, "rotation", 0.0, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_static_card_holder, "modulate", Color.WHITE, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _static_is_flipping = false)


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


func _on_transgression_image_clicked(img: Control, tid: String) -> void:
	var cur: int = img.get_meta("face", GameEnums.TransgressionFace.SCANDALE)
	var name_str: String = String(TransgressionData.get_def(tid).get("name", ""))
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
		_show_fullscreen_card(_endgame_image.texture_normal, I18n.t("ui.dialog.title.endgame"), I18n.t("liturgy.exorcisme.back"))


func _on_provoquer_clicked(tid: String, origin: int) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.PROVOQUER, {"def_id": tid, "origin": origin})
	_handle_action_result(r)
	_refresh_all()


func _on_amplifier_clicked(tid: String) -> void:
	_trans_dialog.hide()
	var r := manager.perform_action(GameEnums.ActionId.AMPLIFIER, {"def_id": tid})
	_handle_action_result(r)
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
	# Domain caption labels overlaid on the board — re-read GameEnums.DOMAIN_NAMES
	# (which itself goes through I18n) so a FR / EN toggle updates "Faith"
	# back to "Foi" etc. without rebuilding the overlay.
	for d_id in _domain_name_labels.keys():
		var lbl: Label = _domain_name_labels[d_id]
		if is_instance_valid(lbl):
			lbl.text = String(GameEnums.DOMAIN_NAMES.get(d_id, ""))
	# Chips carry FR/EN text → re-apply on locale toggle.
	for d_id in _domain_hint_chips.keys():
		var chip: DomainHintChip = _domain_hint_chips[d_id]
		if is_instance_valid(chip):
			chip.set_domain(d_id)
	# FAB label + tooltip — items inside the popup are recreated on each
	# open so they pick up the current locale automatically.
	if _fab != null:
		var lk: String = _fab.get_meta("i18n_label_key", "")
		if lk != "":
			_fab.text = I18n.t(lk)
		var tk: String = _fab.get_meta("i18n_tooltip_key", "")
		if tk != "":
			_fab.tooltip_text = I18n.t(tk)
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
		_relocalize_placed_column_title(_placed_list_blue, GameEnums.PlayerId.PURPLE)
	# Status label tooltip
	if _status_label != null:
		_status_label.tooltip_text = I18n.t("ui.tooltip.station_card")
	# Player panel titles (rebuild text from the stored player id)
	if _player_panel_red != null and is_instance_valid(_player_panel_red):
		_relocalize_player_panel_title(_player_panel_red, GameEnums.PlayerId.RED)
	if _player_panel_blue != null and is_instance_valid(_player_panel_blue):
		_relocalize_player_panel_title(_player_panel_blue, GameEnums.PlayerId.PURPLE)
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
