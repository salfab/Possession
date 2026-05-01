extends Node
# Autoloaded singleton: CardImages
#
# Cards are now composed at runtime by scenes/Card.tscn from three layers :
#
#   1. illustration JPG      — rendered inside the template's transparent arch
#   2. template WebP (RGBA)  — parchment frame with chroma-keyed arch
#   3. five Labels           — title, cost, domain, effect text, face name
#
# This file holds the raw texture preloads. Strings on the cards (names,
# rule texts, face badges) come from I18n via Card.gd and re-render when
# the user toggles language.
#
# Inline preload() inside const dict literals is avoided because of a
# Godot 4.2 web-export quirk where they sometimes evaluate to null.

# ─── Templates (chroma-keyed parchment frames, RGBA) ──────────────────────────

const TPL_TRANS_SCANDALE := preload("res://assets/cards/templates/transgression_scandale.webp")
const TPL_TRANS_INFAMIE  := preload("res://assets/cards/templates/transgression_infamie.webp")
const TPL_LIT_IN_INTEGRO := preload("res://assets/cards/templates/liturgie_in_integro.webp")
const TPL_LIT_IMPEDITA   := preload("res://assets/cards/templates/liturgie_impedita.webp")

# ─── Illustrations (one per Transgression + one per Liturgical Response) ──────

const _ILL_NEPOTISME             := preload("res://assets/cards/illustrations/nepotisme.jpg")
const _ILL_TRAFIC_CHARGES        := preload("res://assets/cards/illustrations/trafic_charges.jpg")
const _ILL_FESTIN_OBSCENE        := preload("res://assets/cards/illustrations/festin_obscene.jpg")
const _ILL_FAVORI_SECRET         := preload("res://assets/cards/illustrations/favori_secret.jpg")
const _ILL_SIMONIE               := preload("res://assets/cards/illustrations/simonie.jpg")
const _ILL_PROFANATION           := preload("res://assets/cards/illustrations/profanation.jpg")
const _ILL_PARANOIA              := preload("res://assets/cards/illustrations/paranoia.jpg")
const _ILL_PERSECUTION           := preload("res://assets/cards/illustrations/persecution.jpg")
const _ILL_PACTE_SILENCIEUX      := preload("res://assets/cards/illustrations/pacte_silencieux.jpg")
const _ILL_ABDICATION_INTERIEURE := preload("res://assets/cards/illustrations/abdication_interieure.jpg")
const _ILL_SIGNE_DE_CROIX        := preload("res://assets/cards/illustrations/signe_de_croix.jpg")
const _ILL_EXAMEN_DE_CONSCIENCE  := preload("res://assets/cards/illustrations/examen_de_conscience.jpg")
const _ILL_CONTRITION            := preload("res://assets/cards/illustrations/contrition.jpg")
const _ILL_CONFESSION            := preload("res://assets/cards/illustrations/confession.jpg")
const _ILL_COMMUNION             := preload("res://assets/cards/illustrations/communion.jpg")

const ILLUSTRATIONS: Dictionary = {
	"nepotisme":             _ILL_NEPOTISME,
	"trafic_charges":        _ILL_TRAFIC_CHARGES,
	"festin_obscene":        _ILL_FESTIN_OBSCENE,
	"favori_secret":         _ILL_FAVORI_SECRET,
	"simonie":               _ILL_SIMONIE,
	"profanation":           _ILL_PROFANATION,
	"paranoia":              _ILL_PARANOIA,
	"persecution":           _ILL_PERSECUTION,
	"pacte_silencieux":      _ILL_PACTE_SILENCIEUX,
	"abdication_interieure": _ILL_ABDICATION_INTERIEURE,
	"signe_de_croix":        _ILL_SIGNE_DE_CROIX,
	"examen_de_conscience":  _ILL_EXAMEN_DE_CONSCIENCE,
	"contrition":            _ILL_CONTRITION,
	"confession":            _ILL_CONFESSION,
	"communion":             _ILL_COMMUNION,
}

# ─── Special — endgame Exorcisme card (still pre-composed; only one card,
# so the win in flexibility from runtime composition wouldn't justify
# adding a sixth template + extra slots). ──────────────────────────────────────

const EXORCISME_FINAL := preload("res://assets/cards/special/exorcisme_final.jpg")


func transgression_template(face: int) -> Texture2D:
	return TPL_TRANS_INFAMIE if face == GameEnums.TransgressionFace.INFAMIE else TPL_TRANS_SCANDALE


func liturgy_template(impedita: bool) -> Texture2D:
	return TPL_LIT_IMPEDITA if impedita else TPL_LIT_IN_INTEGRO


func illustration(name: String) -> Texture2D:
	return ILLUSTRATIONS.get(name)


func exorcisme() -> Texture2D:
	return EXORCISME_FINAL
