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


func _ready() -> void:
	resized.connect(_on_resized)
	_configure_card_fonts()
	_apply_styles()
	_on_resized()
	I18n.locale_changed.connect(_refresh_text)
	_apply_binding()


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
	for f in [FONT_TITLE, FONT_BODY, FONT_FACE]:
		if not f.multichannel_signed_distance_field:
			f.multichannel_signed_distance_field = true
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
		lbl_text.text = String(resp.get(key, ""))


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


# Three-letter localised domain abbreviation that fits the small badge slot.
static func _short_domain(d_id: int) -> String:
	var name: String = String(GameEnums.DOMAIN_NAMES.get(d_id, "?"))
	# Strip diacritics in a quick-and-dirty way and uppercase the first 3 chars.
	if name.length() == 0:
		return "?"
	var ascii := name.replace("Ô", "O").replace("É", "E").replace("È", "E").replace("À", "A")
	ascii = ascii.replace("ô", "o").replace("é", "e").replace("è", "e").replace("à", "a").replace("ï", "i")
	return ascii.substr(0, 3).to_upper()
