extends Node
# Autoloaded singleton: CardImages
#
# Cards are now composed at runtime by scenes/Card.tscn from three layers :
#
#   1. illustration JPG      — rendered inside the template's transparent arch
#   2. template WebP (RGBA)  — parchment frame with chroma-keyed arch
#   3. five Labels           — title, cost, domain, effect text, face name
#
# This file holds the raw texture references. Strings on the cards (names,
# rule texts, face badges) come from I18n via Card.gd and re-render when
# the user toggles language.
#
# Textures are loaded lazily in _ready() rather than via preload() so this
# script compiles cleanly in headless/test mode (no rendering driver means
# no image resource loaders at parse time).
#
# Inline preload() inside const dict literals is avoided because of a
# Godot 4.2 web-export quirk where they sometimes evaluate to null.

# ─── Templates (chroma-keyed parchment frames, RGBA) ──────────────────────────

var TPL_TRANS_SCANDALE: Texture2D
var TPL_TRANS_INFAMIE: Texture2D
var TPL_LIT_IN_INTEGRO: Texture2D
var TPL_LIT_IMPEDITA: Texture2D

# ─── Illustrations (one per Transgression + one per Liturgical Response) ──────

var ILLUSTRATIONS: Dictionary = {}

# ─── Special ──────────────────────────────────────────────────────────────────

var EXORCISME_FINAL: Texture2D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	TPL_TRANS_SCANDALE = load("res://assets/cards/templates/transgression_scandale.webp")
	TPL_TRANS_INFAMIE  = load("res://assets/cards/templates/transgression_infamie.webp")
	TPL_LIT_IN_INTEGRO = load("res://assets/cards/templates/liturgie_in_integro.webp")
	TPL_LIT_IMPEDITA   = load("res://assets/cards/templates/liturgie_impedita.webp")
	ILLUSTRATIONS = {
		"nepotisme":             load("res://assets/cards/illustrations/nepotisme.jpg"),
		"trafic_charges":        load("res://assets/cards/illustrations/trafic_charges.jpg"),
		"festin_obscene":        load("res://assets/cards/illustrations/festin_obscene.jpg"),
		"favori_secret":         load("res://assets/cards/illustrations/favori_secret.jpg"),
		"simonie":               load("res://assets/cards/illustrations/simonie.jpg"),
		"profanation":           load("res://assets/cards/illustrations/profanation.jpg"),
		"paranoia":              load("res://assets/cards/illustrations/paranoia.jpg"),
		"persecution":           load("res://assets/cards/illustrations/persecution.jpg"),
		"pacte_silencieux":      load("res://assets/cards/illustrations/pacte_silencieux.jpg"),
		"abdication_interieure": load("res://assets/cards/illustrations/abdication_interieure.jpg"),
		"signe_de_croix":        load("res://assets/cards/illustrations/signe_de_croix.jpg"),
		"examen_de_conscience":  load("res://assets/cards/illustrations/examen_de_conscience.jpg"),
		"contrition":            load("res://assets/cards/illustrations/contrition.jpg"),
		"confession":            load("res://assets/cards/illustrations/confession.jpg"),
		"communion":             load("res://assets/cards/illustrations/communion.jpg"),
	}
	EXORCISME_FINAL = load("res://assets/cards/special/exorcisme_final.jpg")


func transgression_template(face: int) -> Texture2D:
	return TPL_TRANS_INFAMIE if face == GameEnums.TransgressionFace.INFAMIE else TPL_TRANS_SCANDALE


func liturgy_template(impedita: bool) -> Texture2D:
	return TPL_LIT_IMPEDITA if impedita else TPL_LIT_IN_INTEGRO


func illustration(name: String) -> Texture2D:
	return ILLUSTRATIONS.get(name)


func exorcisme() -> Texture2D:
	return EXORCISME_FINAL
