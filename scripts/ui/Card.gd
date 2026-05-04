extends Control
class_name Card
# Composes a card at runtime: illustration in the arch slot, template (with
# transparent arch) over it, then five Labels for title/cost/domain/effect/face.
# All children use normalised anchors so the design scales with the Control's
# size. The card is i18n-aware — it stashes the binding (transgression tid +
# face, or station + impedita flag) and re-renders text on locale_changed.
#
# Place a Card inside an AspectRatioContainer (ratio 720/1008 ≈ 0.7143) to
# preserve proportions when displayed at arbitrary sizes.

const FONT_TITLE := preload("res://assets/fonts/IMFellEnglishSC.ttf")
const FONT_BODY  := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const FONT_FACE  := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")

# Reference design resolution. Font sizes are calibrated for this width and
# scaled in _on_resized() so the look stays consistent at any actual size.
const REF_WIDTH := 720.0

@onready var illustration: TextureRect = $Illustration
@onready var template: TextureRect = $Template
@onready var lbl_title: Label = $Title
@onready var lbl_cost: Label = $Cost
@onready var lbl_domain: Label = $Domain
@onready var lbl_text: Label = $EffectText
@onready var lbl_face: Label = $FaceLabel

# Binding state — used by _refresh_text() so locale changes can re-render
# without the caller having to re-invoke setup_*.
var _kind: String = ""           # "transgression" | "liturgy"
var _tid: String = ""            # transgression def_id
var _face: int = GameEnums.TransgressionFace.SCANDALE
var _station: int = -1
var _impedita: bool = false
# Liturgy target — caller supplies one of these (the picker logic lives in
# LiturgyResolver and needs a GameState the Card doesn't have). Stored as ids
# rather than a pre-formatted string so locale_changed can re-render the
# abbreviation in the new language.
var _target_domain: int = -1     # DomainId, or -1 if not a domain target
var _target_player: int = -1     # PlayerId (>0), or -1 if not a player target

# Emitted when the user taps the small badge slot (lbl_domain) on a Liturgy
# card. Connect from the host UI to pop a panel describing the targeting
# rule for that Station — the rule itself stays in i18n
# (liturgy.targeting.<id>) so it's locale-aware.
signal target_info_requested(station: int)

# Emitted when the user taps the body-text slot (lbl_text). The host UI
# pops a high-contrast "effect detail" panel — useful when the parchment
# background hurts readability or when the rules text is ambiguous and
# benefits from a longer i18n variant (key suffix ".detail", with fallback
# to the base text when no detailed variant is shipped).
signal effect_info_requested

# Transparent overlays over the small badge / body-text slots that capture
# taps without blocking the card's other interactions (flip, zoom). Created
# at runtime so we don't need to edit the .tscn.
var _domain_btn: Button
var _effect_btn: Button


func _ready() -> void:
	resized.connect(_on_resized)
	_configure_card_fonts()
	_apply_styles()
	_setup_domain_btn()
	_setup_effect_btn()
	_on_resized()
	I18n.locale_changed.connect(_refresh_text)
	_apply_binding()


func _setup_domain_btn() -> void:
	_domain_btn = _make_overlay_button(lbl_domain)
	_domain_btn.pressed.connect(_on_domain_btn_pressed)


func _setup_effect_btn() -> void:
	_effect_btn = _make_overlay_button(lbl_text)
	_effect_btn.pressed.connect(_on_effect_btn_pressed)


# Builds a transparent Button that mirrors the anchors/offsets of `target`
# and adds it as a sibling, so a tap on the labelled area is captured as a
# Button press without obscuring the underlying Label visually.
func _make_overlay_button(target: Control) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.modulate = Color(1, 1, 1, 0)
	btn.anchor_left = target.anchor_left
	btn.anchor_top = target.anchor_top
	btn.anchor_right = target.anchor_right
	btn.anchor_bottom = target.anchor_bottom
	btn.offset_left = target.offset_left
	btn.offset_top = target.offset_top
	btn.offset_right = target.offset_right
	btn.offset_bottom = target.offset_bottom
	btn.visible = false
	add_child(btn)
	return btn


func _on_domain_btn_pressed() -> void:
	if _kind == "liturgy":
		target_info_requested.emit(_station)


func _on_effect_btn_pressed() -> void:
	if _kind == "liturgy" or _kind == "transgression":
		effect_info_requested.emit()


# Switch the three TTF FontFile resources to MSDF rendering. Without this,
# Godot rasterises glyphs at the requested pixel size, which on Retina /
# high-DPI displays (iPad in particular) shows subpixel anti-aliasing
# rainbow fringing on the calligraphic IM Fell typefaces. MSDF stores
# glyphs as a multichannel signed distance field that scales crisply at
# any size. Configured once globally — the const preloaded resources are
# shared across all Card instances.
static var _fonts_msdf_configured: bool = false


static func _configure_card_fonts() -> void:
	if _fonts_msdf_configured:
		return
	# Defensive fallback : if a card's i18n string ever contains a glyph
	# the IM Fell / Cinzel fonts don't carry (e.g. arrows, math operators,
	# checkmarks), Godot would render it as a tofu box. Pointing each
	# Card font's fallbacks chain at ThemeDB.fallback_font (NotoSans, very
	# broad Unicode coverage) means missing glyphs route through it
	# instead, on a per-glyph basis.
	#
	# Important : after toggling multichannel_signed_distance_field or
	# touching fallbacks, clear_cache() is required for the change to
	# take effect. Skipping this on f57eedf left the engine serving the
	# pre-MSDF bitmap cache, which on a high-DPI Windows tablet showed
	# up as the rainbow-fringed rendering MSDF was meant to fix.
	var fallback: Font = ThemeDB.fallback_font
	for f in [FONT_TITLE, FONT_BODY, FONT_FACE]:
		var dirty := false
		if not f.multichannel_signed_distance_field:
			f.multichannel_signed_distance_field = true
			dirty = true
		if fallback != null and f.fallbacks.is_empty():
			f.fallbacks = [fallback]
			dirty = true
		if dirty:
			f.clear_cache()
	_fonts_msdf_configured = true


func _apply_styles() -> void:
	_setup_label(lbl_title,  FONT_TITLE, 30, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_cost,   FONT_BODY,  56, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_domain, FONT_TITLE, 22, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_text,   FONT_BODY,  20, Color(0.16, 0.07, 0.03))
	_setup_label(lbl_face,   FONT_FACE,  26, Color(0.43, 0.08, 0.06))


func _setup_label(lbl: Label, font: Font, base_size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", base_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.set_meta("base_size", base_size)


func _on_resized() -> void:
	# Scale label font sizes proportionally to the card's actual width.
	# Floor bumped from 6 → 12 so the text stays legible even on very small
	# thumbnail renders ; combined with MSDF this is crisp at any size.
	var s: float = max(0.1, size.x / REF_WIDTH)
	for lbl in [lbl_title, lbl_cost, lbl_domain, lbl_text, lbl_face]:
		var base: int = int(lbl.get_meta("base_size", 20))
		lbl.add_theme_font_size_override("font_size", max(12, int(round(base * s))))


# ─── Public setup methods ─────────────────────────────────────────────────────

func setup_transgression(tid: String, face: int) -> void:
	_kind = "transgression"
	_tid = tid
	_face = face
	if is_node_ready():
		_apply_binding()


func setup_liturgy(station_id: int, impedita: bool, target_domain: int = -1, target_player: int = -1) -> void:
	_kind = "liturgy"
	_station = station_id
	_impedita = impedita
	_target_domain = target_domain
	_target_player = target_player
	if is_node_ready():
		_apply_binding()


# Flip-with-animation variants — simulates a 3D rotation around the card's
# vertical axis on a 2D Control by combining several tweens running in
# parallel :
#   • scale.x : 1 → 0 → 1 (the card folds edge-on, then unfolds).
#   • scale.y : 1 → 0.82 → 1 (perspective foreshortening — the edges
#     that are turning away from the viewer appear shorter, as if
#     receding into the screen).
#   • rotation: 0 → 4° → 0 (slight tilt for a sense of motion / tumble).
#   • modulate: white → dim → white (the back of a real card sits in
#     comparative shadow when seen edge-on).
# The binding swap happens at mid-tween (when scale.x ≈ 0), so the new
# face un-flips toward the viewer.
const _FLIP_HALF_DURATION := 0.22
const _FLIP_TILT_DEG := 4.0
const _FLIP_DEPTH_SCALE := 0.82
const _FLIP_DIM := Color(0.78, 0.74, 0.78)

var _is_flipping: bool = false


func flip_to_transgression(tid: String, face: int) -> void:
	if not is_node_ready():
		setup_transgression(tid, face)
		return
	if _is_flipping:
		return
	_run_flip_tween(func(): setup_transgression(tid, face))


func flip_to_liturgy(station_id: int, impedita: bool, target_domain: int = -1, target_player: int = -1) -> void:
	if not is_node_ready():
		setup_liturgy(station_id, impedita, target_domain, target_player)
		return
	if _is_flipping:
		return
	_run_flip_tween(func(): setup_liturgy(station_id, impedita, target_domain, target_player))


func _run_flip_tween(swap_callback: Callable) -> void:
	_is_flipping = true
	pivot_offset = size * 0.5
	var dur := _FLIP_HALF_DURATION
	var tilt_rad := deg_to_rad(_FLIP_TILT_DEG)
	var tw := create_tween()
	# Phase 1 — fold to edge-on, with perspective shrink + slight tilt + dim.
	tw.tween_property(self, "scale:x", 0.0, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale:y", _FLIP_DEPTH_SCALE, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "rotation", tilt_rad, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "modulate", _FLIP_DIM, dur).set_trans(Tween.TRANS_SINE)
	# Swap the binding at the edge-on midpoint.
	tw.tween_callback(swap_callback)
	# Phase 2 — unfold the new face, restoring proportions and brightness.
	tw.tween_property(self, "scale:x", 1.0, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale:y", 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "rotation", 0.0, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "modulate", Color.WHITE, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _is_flipping = false)


# Applies the stored binding (kind + ids) to the on-screen nodes. Called by
# _ready(), the setup_* methods (when already in the tree), and by
# _refresh_text() via the locale_changed signal.
func _apply_binding() -> void:
	if _kind == "transgression":
		template.texture = CardImages.transgression_template(_face)
		illustration.texture = CardImages.illustration(_tid)
	elif _kind == "liturgy":
		template.texture = CardImages.liturgy_template(_impedita)
		var resp: Dictionary = LiturgicalResponseData.get_response(_station)
		if not resp.is_empty():
			illustration.texture = CardImages.illustration(String(resp.get("id", "")))
	# Badge tap target — only meaningful on Liturgy cards (the rule popup
	# describes how the response picks its Domain / demon). Hidden on
	# Transgressions, where the badge is a static domain requirement.
	if _domain_btn != null:
		_domain_btn.visible = _kind == "liturgy"
		if _kind == "liturgy":
			_domain_btn.tooltip_text = I18n.t("ui.tooltip.tap_for_targeting_rule")
	# Body-text tap target — re-shows the effect in a high-contrast popup
	# (and a longer wording when an i18n .detail variant is shipped).
	# Always available on Liturgy + Transgression cards.
	if _effect_btn != null:
		_effect_btn.visible = _kind == "liturgy" or _kind == "transgression"
		if _effect_btn.visible:
			_effect_btn.tooltip_text = I18n.t("ui.tooltip.tap_for_effect_detail")
	_refresh_text()


# Re-renders all the text labels in the current locale without touching the
# texture bindings. Safe to call before _ready (early-exits if labels aren't
# resolved yet).
func _refresh_text() -> void:
	if not is_node_ready():
		return
	if _kind == "transgression":
		var def: Dictionary = TransgressionData.get_def(_tid)
		if def.is_empty():
			return
		lbl_title.text = String(def.get("name", "?"))
		var requirement: Array = def.get("domain_requirement", [])
		if requirement.size() > 0:
			lbl_domain.text = _short_domain(int(requirement[0]))
		else:
			lbl_domain.text = "—"
		if _face == GameEnums.TransgressionFace.INFAMIE:
			lbl_face.text = I18n.t("face.infamie").to_upper()
			lbl_cost.text = str(int(def.get("amplification_cost", 0)))
			lbl_text.text = String(def.get("infamy_text", ""))
		else:
			lbl_face.text = I18n.t("face.scandale").to_upper()
			lbl_cost.text = str(int(def.get("scandal_cost", 0)))
			lbl_text.text = String(def.get("scandal_text", ""))
	elif _kind == "liturgy":
		var resp: Dictionary = LiturgicalResponseData.get_response(_station)
		if resp.is_empty():
			return
		lbl_title.text = String(resp.get("name", "?"))
		lbl_cost.text = "—"
		lbl_domain.text = _liturgy_target_text()
		lbl_face.text = (I18n.t("liturgy.impedita") if _impedita else I18n.t("liturgy.in_integro")).to_upper()
		var key: String = "text_impedita" if _impedita else "text_in_integro"
		# The body text uses generic phrasing ("le Domaine ciblé", "le démon
		# ciblé") because it's the same string regardless of target. Prepend a
		# concrete "Cible : <name>" line so the player sees who's actually hit
		# without having to decode the 3-letter badge.
		var body: String = String(resp.get(key, ""))
		var tgt_full: String = _liturgy_target_full()
		if tgt_full != "":
			body = I18n.t("liturgy.target_line", [tgt_full]) + "\n\n" + body
		lbl_text.text = body


# ─── Helpers ──────────────────────────────────────────────────────────────────

# Renders the small-badge slot for a Liturgy: a 3-letter domain abbreviation
# (e.g. "FOI"), or the uppercased player name for Confession (which targets a
# demon rather than a Domain), or "—" when neither was provided.
func _liturgy_target_text() -> String:
	if _target_domain >= 0:
		return _short_domain(_target_domain)
	if _target_player > 0:
		return GameEnums.player_name(_target_player).to_upper()
	return "—"


# Full localised target name for the body line ("Foi", "Volonté", "Rouge",
# "Violet"). Empty string when the target is unknown — the body is then shown
# as-is, with its generic "le Domaine ciblé" phrasing.
func _liturgy_target_full() -> String:
	if _target_domain >= 0:
		return String(GameEnums.DOMAIN_NAMES.get(_target_domain, ""))
	if _target_player > 0:
		return GameEnums.player_name(_target_player)
	return ""


# Three-letter localised domain abbreviation that fits the small badge slot.
static func _short_domain(d_id: int) -> String:
	var name: String = String(GameEnums.DOMAIN_NAMES.get(d_id, "?"))
	# Strip diacritics in a quick-and-dirty way and uppercase the first 3 chars.
	if name.length() == 0:
		return "?"
	var ascii := name.replace("Ô", "O").replace("É", "E").replace("È", "E").replace("À", "A")
	ascii = ascii.replace("ô", "o").replace("é", "e").replace("è", "e").replace("à", "a").replace("ï", "i")
	return ascii.substr(0, 3).to_upper()
