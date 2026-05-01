extends Node
# Autoloaded singleton: CardImages
# Preloads all card textures + illustrations + templates so they are
# guaranteed to be packed into the Web/HTML5 export.

# ─── Templates ────────────────────────────────────────────────────────────────

const TPL_TRANS_SCANDALE := preload("res://assets/cards/templates/transgression_scandale.png")
const TPL_TRANS_INFAMIE  := preload("res://assets/cards/templates/transgression_infamie.png")
const TPL_LIT_IN_INTEGRO := preload("res://assets/cards/templates/liturgie_in_integro.png")
const TPL_LIT_IMPEDITA   := preload("res://assets/cards/templates/liturgie_impedita.png")

# ─── Illustrations (1196×1315 each, ratio 0.910) ──────────────────────────────

const ILLU_NEPOTISME             := preload("res://assets/cards/illustrations/nepotisme.png")
const ILLU_TRAFIC_CHARGES        := preload("res://assets/cards/illustrations/trafic_charges.png")
const ILLU_FESTIN_OBSCENE        := preload("res://assets/cards/illustrations/festin_obscene.png")
const ILLU_FAVORI_SECRET         := preload("res://assets/cards/illustrations/favori_secret.png")
const ILLU_SIMONIE               := preload("res://assets/cards/illustrations/simonie.png")
const ILLU_PROFANATION           := preload("res://assets/cards/illustrations/profanation.png")
const ILLU_PARANOIA              := preload("res://assets/cards/illustrations/paranoia.png")
const ILLU_PERSECUTION           := preload("res://assets/cards/illustrations/persecution.png")
const ILLU_PACTE_SILENCIEUX      := preload("res://assets/cards/illustrations/pacte_silencieux.png")
const ILLU_ABDICATION_INTERIEURE := preload("res://assets/cards/illustrations/abdication_interieure.png")

const ILLU_SIGNE_DE_CROIX        := preload("res://assets/cards/illustrations/signe_de_croix.png")
const ILLU_EXAMEN_DE_CONSCIENCE  := preload("res://assets/cards/illustrations/examen_de_conscience.png")
const ILLU_CONTRITION            := preload("res://assets/cards/illustrations/contrition.png")
const ILLU_CONFESSION            := preload("res://assets/cards/illustrations/confession.png")
const ILLU_COMMUNION             := preload("res://assets/cards/illustrations/communion.png")

const ILLU_EXORCISME_FINAL       := preload("res://assets/cards/special/exorcisme_final.png")

const ILLUSTRATIONS := {
	"nepotisme":             ILLU_NEPOTISME,
	"trafic_charges":        ILLU_TRAFIC_CHARGES,
	"festin_obscene":        ILLU_FESTIN_OBSCENE,
	"favori_secret":         ILLU_FAVORI_SECRET,
	"simonie":               ILLU_SIMONIE,
	"profanation":           ILLU_PROFANATION,
	"paranoia":              ILLU_PARANOIA,
	"persecution":           ILLU_PERSECUTION,
	"pacte_silencieux":      ILLU_PACTE_SILENCIEUX,
	"abdication_interieure": ILLU_ABDICATION_INTERIEURE,
	"signe_de_croix":        ILLU_SIGNE_DE_CROIX,
	"examen_de_conscience":  ILLU_EXAMEN_DE_CONSCIENCE,
	"contrition":            ILLU_CONTRITION,
	"confession":            ILLU_CONFESSION,
	"communion":             ILLU_COMMUNION,
}


# ─── Public API ───────────────────────────────────────────────────────────────

func transgression_template(face: int) -> Texture2D:
	if face == GameEnums.TransgressionFace.INFAMIE:
		return TPL_TRANS_INFAMIE
	return TPL_TRANS_SCANDALE


func liturgy_template(impedita: bool) -> Texture2D:
	return TPL_LIT_IMPEDITA if impedita else TPL_LIT_IN_INTEGRO


func illustration(id: String) -> Texture2D:
	return ILLUSTRATIONS.get(id)


func exorcism_image() -> Texture2D:
	return ILLU_EXORCISME_FINAL


# ─── Legacy compatibility (old composed-card images, kept for fallback) ───────

func transgression(_tid: String, _face: int) -> Texture2D:
	# Old API used pre-composed PNGs. Card.tscn now composes at runtime,
	# so this is only kept for callers that haven't migrated. Returns null;
	# callers should use Card.tscn + setup_transgression() instead.
	return null


func liturgy(_response_id: String, _impedita: bool) -> Texture2D:
	return null


func exorcisme() -> Texture2D:
	return ILLU_EXORCISME_FINAL
