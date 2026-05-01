extends Node
# Autoloaded singleton: CardImages
# Preloads all card textures so they're guaranteed to be packed into the
# Web/HTML5 export. Cards stored as JPG (same format as the working
# board.jpg) — PNG textures were rendering blank in the web build on
# some GPU/driver combos with VRAM compression enabled.
#
# Named consts instead of inline preload() inside dict literals to avoid
# a Godot 4.2 web-export quirk where inlined preloads in const dicts can
# silently evaluate to null.

# ─── Transgressions ───────────────────────────────────────────────────────────

const _T_NEPOTISME_SCANDALE             := preload("res://assets/cards/transgressions/nepotisme_scandale.jpg")
const _T_NEPOTISME_INFAMIE              := preload("res://assets/cards/transgressions/nepotisme_infamie.jpg")
const _T_TRAFIC_CHARGES_SCANDALE        := preload("res://assets/cards/transgressions/trafic_charges_scandale.jpg")
const _T_TRAFIC_CHARGES_INFAMIE         := preload("res://assets/cards/transgressions/trafic_charges_infamie.jpg")
const _T_FESTIN_OBSCENE_SCANDALE        := preload("res://assets/cards/transgressions/festin_obscene_scandale.jpg")
const _T_FESTIN_OBSCENE_INFAMIE         := preload("res://assets/cards/transgressions/festin_obscene_infamie.jpg")
const _T_FAVORI_SECRET_SCANDALE         := preload("res://assets/cards/transgressions/favori_secret_scandale.jpg")
const _T_FAVORI_SECRET_INFAMIE          := preload("res://assets/cards/transgressions/favori_secret_infamie.jpg")
const _T_SIMONIE_SCANDALE               := preload("res://assets/cards/transgressions/simonie_scandale.jpg")
const _T_SIMONIE_INFAMIE                := preload("res://assets/cards/transgressions/simonie_infamie.jpg")
const _T_PROFANATION_SCANDALE           := preload("res://assets/cards/transgressions/profanation_scandale.jpg")
const _T_PROFANATION_INFAMIE            := preload("res://assets/cards/transgressions/profanation_infamie.jpg")
const _T_PARANOIA_SCANDALE              := preload("res://assets/cards/transgressions/paranoia_scandale.jpg")
const _T_PARANOIA_INFAMIE               := preload("res://assets/cards/transgressions/paranoia_infamie.jpg")
const _T_PERSECUTION_SCANDALE           := preload("res://assets/cards/transgressions/persecution_scandale.jpg")
const _T_PERSECUTION_INFAMIE            := preload("res://assets/cards/transgressions/persecution_infamie.jpg")
const _T_PACTE_SILENCIEUX_SCANDALE      := preload("res://assets/cards/transgressions/pacte_silencieux_scandale.jpg")
const _T_PACTE_SILENCIEUX_INFAMIE       := preload("res://assets/cards/transgressions/pacte_silencieux_infamie.jpg")
const _T_ABDICATION_INTERIEURE_SCANDALE := preload("res://assets/cards/transgressions/abdication_interieure_scandale.jpg")
const _T_ABDICATION_INTERIEURE_INFAMIE  := preload("res://assets/cards/transgressions/abdication_interieure_infamie.jpg")

# ─── Liturgies ────────────────────────────────────────────────────────────────

const _L_SIGNE_DE_CROIX_IN_INTEGRO        := preload("res://assets/cards/liturgies/signe_de_croix_in_integro.jpg")
const _L_SIGNE_DE_CROIX_IMPEDITA          := preload("res://assets/cards/liturgies/signe_de_croix_impedita.jpg")
const _L_EXAMEN_DE_CONSCIENCE_IN_INTEGRO  := preload("res://assets/cards/liturgies/examen_de_conscience_in_integro.jpg")
const _L_EXAMEN_DE_CONSCIENCE_IMPEDITA    := preload("res://assets/cards/liturgies/examen_de_conscience_impedita.jpg")
const _L_CONTRITION_IN_INTEGRO            := preload("res://assets/cards/liturgies/contrition_in_integro.jpg")
const _L_CONTRITION_IMPEDITA              := preload("res://assets/cards/liturgies/contrition_impedita.jpg")
const _L_CONFESSION_IN_INTEGRO            := preload("res://assets/cards/liturgies/confession_in_integro.jpg")
const _L_CONFESSION_IMPEDITA              := preload("res://assets/cards/liturgies/confession_impedita.jpg")
const _L_COMMUNION_IN_INTEGRO             := preload("res://assets/cards/liturgies/communion_in_integro.jpg")
const _L_COMMUNION_IMPEDITA               := preload("res://assets/cards/liturgies/communion_impedita.jpg")

# ─── Special ──────────────────────────────────────────────────────────────────

const EXORCISME_FINAL := preload("res://assets/cards/special/exorcisme_final.jpg")

# ─── Lookup tables (built from the named consts above) ────────────────────────

const TRANSGRESSIONS: Dictionary = {
	"nepotisme_scandale":             _T_NEPOTISME_SCANDALE,
	"nepotisme_infamie":              _T_NEPOTISME_INFAMIE,
	"trafic_charges_scandale":        _T_TRAFIC_CHARGES_SCANDALE,
	"trafic_charges_infamie":         _T_TRAFIC_CHARGES_INFAMIE,
	"festin_obscene_scandale":        _T_FESTIN_OBSCENE_SCANDALE,
	"festin_obscene_infamie":         _T_FESTIN_OBSCENE_INFAMIE,
	"favori_secret_scandale":         _T_FAVORI_SECRET_SCANDALE,
	"favori_secret_infamie":          _T_FAVORI_SECRET_INFAMIE,
	"simonie_scandale":               _T_SIMONIE_SCANDALE,
	"simonie_infamie":                _T_SIMONIE_INFAMIE,
	"profanation_scandale":           _T_PROFANATION_SCANDALE,
	"profanation_infamie":            _T_PROFANATION_INFAMIE,
	"paranoia_scandale":              _T_PARANOIA_SCANDALE,
	"paranoia_infamie":               _T_PARANOIA_INFAMIE,
	"persecution_scandale":           _T_PERSECUTION_SCANDALE,
	"persecution_infamie":            _T_PERSECUTION_INFAMIE,
	"pacte_silencieux_scandale":      _T_PACTE_SILENCIEUX_SCANDALE,
	"pacte_silencieux_infamie":       _T_PACTE_SILENCIEUX_INFAMIE,
	"abdication_interieure_scandale": _T_ABDICATION_INTERIEURE_SCANDALE,
	"abdication_interieure_infamie":  _T_ABDICATION_INTERIEURE_INFAMIE,
}

const LITURGIES: Dictionary = {
	"signe_de_croix_in_integro":       _L_SIGNE_DE_CROIX_IN_INTEGRO,
	"signe_de_croix_impedita":         _L_SIGNE_DE_CROIX_IMPEDITA,
	"examen_de_conscience_in_integro": _L_EXAMEN_DE_CONSCIENCE_IN_INTEGRO,
	"examen_de_conscience_impedita":   _L_EXAMEN_DE_CONSCIENCE_IMPEDITA,
	"contrition_in_integro":           _L_CONTRITION_IN_INTEGRO,
	"contrition_impedita":             _L_CONTRITION_IMPEDITA,
	"confession_in_integro":           _L_CONFESSION_IN_INTEGRO,
	"confession_impedita":             _L_CONFESSION_IMPEDITA,
	"communion_in_integro":            _L_COMMUNION_IN_INTEGRO,
	"communion_impedita":              _L_COMMUNION_IMPEDITA,
}


func transgression(tid: String, face: int) -> Texture2D:
	var f: String = "scandale" if face == GameEnums.TransgressionFace.SCANDALE else "infamie"
	var key: String = "%s_%s" % [tid, f]
	var tex: Texture2D = TRANSGRESSIONS.get(key)
	if tex == null:
		push_warning("CardImages.transgression: missing key '%s' (face=%d)" % [key, face])
	return tex


func liturgy(response_id: String, impedita: bool) -> Texture2D:
	var mode: String = "impedita" if impedita else "in_integro"
	var key: String = "%s_%s" % [response_id, mode]
	return LITURGIES.get(key)


func exorcisme() -> Texture2D:
	return EXORCISME_FINAL
