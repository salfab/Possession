extends Control
class_name Card
# Composes a card at runtime: template (with transparent arch) + illustration
# behind it + Labels for title/cost/domain/effect/face on top.
#
# Card root has an internal "design size" of 1060×1484 px (the original
# template resolution). All children are placed via normalized anchors so
# the card scales correctly when its parent gives it any other size.
# Wrap a Card instance in an AspectRatioContainer (ratio 0.7143) to keep
# the proportions when displayed at arbitrary sizes.

const FONT_TITLE := preload("res://assets/fonts/IMFellEnglishSC.ttf")
const FONT_BODY  := preload("res://assets/fonts/IMFellEnglish-Regular.ttf")
const FONT_FACE  := preload("res://assets/fonts/CinzelDecorative-Bold.ttf")

# Reference design resolution — fonts are sized for this. When the card is
# rendered smaller, we let Godot scale the Labels via custom_minimum_size
# tricks; in practice we just pass the size and Pillow-style autowrap kicks in.
const REF_WIDTH  := 1060.0
const REF_HEIGHT := 1484.0

@onready var illustration: TextureRect = $Illustration
@onready var template: TextureRect = $Template
@onready var lbl_title: Label = $Title
@onready var lbl_cost: Label = $Cost
@onready var lbl_domain: Label = $Domain
@onready var lbl_text: Label = $EffectText
@onready var lbl_face: Label = $FaceLabel


func _ready() -> void:
	resized.connect(_on_resized)
	_apply_styles()
	_on_resized()


func _apply_styles() -> void:
	# Base font sizes at REF resolution; will be scaled in _on_resized.
	_setup_label(lbl_title,  FONT_TITLE, 46, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_cost,   FONT_BODY,  80, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_domain, FONT_TITLE, 32, Color(0.20, 0.06, 0.04))
	_setup_label(lbl_text,   FONT_BODY,  30, Color(0.16, 0.07, 0.03))
	_setup_label(lbl_face,   FONT_FACE,  38, Color(0.43, 0.08, 0.06))


func _setup_label(lbl: Label, font: Font, size: int, color: Color) -> void:
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.set_meta("base_size", size)


func _on_resized() -> void:
	# Scale label font sizes proportionally to the card's actual width.
	var scale: float = max(0.1, size.x / REF_WIDTH)
	for lbl in [lbl_title, lbl_cost, lbl_domain, lbl_text, lbl_face]:
		var base: int = int(lbl.get_meta("base_size", 30))
		var new_size: int = max(6, int(round(base * scale)))
		lbl.add_theme_font_size_override("font_size", new_size)


# ─── Public setup methods ─────────────────────────────────────────────────────

func setup_transgression(tid: String, face: int) -> void:
	var def: Dictionary = TransgressionData.get_def(tid)
	if def.is_empty():
		return
	template.texture = CardImages.transgression_template(face)
	illustration.texture = CardImages.illustration(tid)
	lbl_title.text = String(def.get("name", "?"))
	var requirement: Array = def.get("domain_requirement", [])
	if requirement.size() > 0:
		lbl_domain.text = _short_domain(int(requirement[0]))
	else:
		lbl_domain.text = "—"

	if face == GameEnums.TransgressionFace.INFAMIE:
		lbl_face.text = "INFAMIE"
		lbl_cost.text = str(int(def.get("amplification_cost", 0)))
		lbl_text.text = String(def.get("infamy_text", ""))
	else:
		lbl_face.text = "SCANDALE"
		lbl_cost.text = str(int(def.get("scandal_cost", 0)))
		lbl_text.text = String(def.get("scandal_text", ""))


func setup_liturgy(station_id: int, impedita: bool) -> void:
	var resp: Dictionary = LiturgicalResponseData.get_response(station_id)
	if resp.is_empty():
		return
	template.texture = CardImages.liturgy_template(impedita)
	var liturgy_id: String = String(resp.get("id", ""))
	illustration.texture = CardImages.illustration(liturgy_id)
	lbl_title.text = String(resp.get("name", "?"))
	lbl_cost.text = "—"
	lbl_domain.text = "—"
	lbl_face.text = "IMPEDITA" if impedita else "IN INTEGRO"
	var key: String = "text_impedita" if impedita else "text_in_integro"
	lbl_text.text = String(resp.get(key, ""))


# ─── Helpers ──────────────────────────────────────────────────────────────────

static func _short_domain(d_id: int) -> String:
	match d_id:
		GameEnums.DomainId.AMBITION: return "AMB"
		GameEnums.DomainId.DESIR:    return "DES"
		GameEnums.DomainId.FOI:      return "FOI"
		GameEnums.DomainId.PEUR:     return "PEU"
		GameEnums.DomainId.VOLONTE:  return "VOL"
	return "?"
