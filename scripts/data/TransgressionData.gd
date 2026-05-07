extends Node
# Autoloaded singleton: TransgressionData
# Definitions of all 20 Transgressions (10 V1h + 10 Codex des Transgressions).
# Strings (name, scandal text, infamy text) are stored as I18n keys —
# call name_of() / scandal_text_of() / infamy_text_of() to get them in
# the current locale.

# ── V1h — cartes 01-10 ──────────────────────────────────────────────────────
const T_NEPOTISME    := "nepotisme"
const T_TRAFIC       := "trafic_charges"
const T_FESTIN       := "festin_obscene"
const T_FAVORI       := "favori_secret"
const T_SIMONIE      := "simonie"
const T_PROFANATION  := "profanation"
const T_PARANOIA     := "paranoia"
const T_PERSECUTION  := "persecution"
const T_PACTE        := "pacte_silencieux"
const T_ABDICATION   := "abdication_interieure"

# ── Codex des Transgressions — cartes 11-20 ─────────────────────────────────
const T_INTRIGUE     := "intrigue_consistoire"
const T_BULLE        := "bulle_vendue"
const T_MASCARADE    := "mascarade_velours"
const T_APPETIT      := "appetit_heretique"
const T_DOGME        := "dogme_renverse"
const T_RELIQUES     := "reliques_menteuses"
const T_DENONCIATION := "denonciation_anonyme"
const T_PANIQUE      := "panique_contagieuse"
const T_OBEISSANCE   := "obeissance_pervertie"
const T_RENONCEMENT  := "renoncement_noir"

const CATALOG := {
	T_NEPOTISME: {
		"id": T_NEPOTISME,
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_TRAFIC: {
		"id": T_TRAFIC,
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_FESTIN: {
		"id": T_FESTIN,
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 2,
		"amplification_cost": 3,
	},
	T_FAVORI: {
		"id": T_FAVORI,
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 2,
		"amplification_cost": 3,
	},
	T_SIMONIE: {
		"id": T_SIMONIE,
		"domain_requirement": [GameEnums.DomainId.FOI, GameEnums.DomainId.AMBITION],
		"origin_choice": true,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 3,
		"amplification_cost": 2,
	},
	T_PROFANATION: {
		"id": T_PROFANATION,
		"domain_requirement": [GameEnums.DomainId.FOI],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 3,
		"amplification_cost": 3,
	},
	T_PARANOIA: {
		"id": T_PARANOIA,
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_PERSECUTION: {
		"id": T_PERSECUTION,
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_PACTE: {
		"id": T_PACTE,
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 3,
	},
	T_ABDICATION: {
		"id": T_ABDICATION,
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 3,
	},
	# ── Codex ────────────────────────────────────────────────────────────────
	T_INTRIGUE: {
		"id": T_INTRIGUE,
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 2,
		"amplification_cost": 3,
	},
	T_BULLE: {
		"id": T_BULLE,
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 3,
		"amplification_cost": 2,
	},
	T_MASCARADE: {
		"id": T_MASCARADE,
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_APPETIT: {
		"id": T_APPETIT,
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 3,
		"amplification_cost": 3,
	},
	T_DOGME: {
		"id": T_DOGME,
		"domain_requirement": [GameEnums.DomainId.FOI],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 2,
		"amplification_cost": 3,
	},
	T_RELIQUES: {
		"id": T_RELIQUES,
		"domain_requirement": [GameEnums.DomainId.FOI],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 3,
		"amplification_cost": 2,
	},
	T_DENONCIATION: {
		"id": T_DENONCIATION,
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 2,
	},
	T_PANIQUE: {
		"id": T_PANIQUE,
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 3,
	},
	T_OBEISSANCE: {
		"id": T_OBEISSANCE,
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 3,
	},
	T_RENONCEMENT: {
		"id": T_RENONCEMENT,
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 2,
	},
}

# V1h — the 10 original cards used when Codex is disabled.
const ALL_IDS := [
	T_NEPOTISME, T_TRAFIC,
	T_FESTIN, T_FAVORI,
	T_SIMONIE, T_PROFANATION,
	T_PARANOIA, T_PERSECUTION,
	T_PACTE, T_ABDICATION,
]

# All 20 cards (V1h + Codex). Only used when codex_of_transgressions_enabled.
const ALL_IDS_EXTENDED := [
	T_NEPOTISME, T_TRAFIC, T_INTRIGUE, T_BULLE,
	T_FESTIN, T_FAVORI, T_MASCARADE, T_APPETIT,
	T_SIMONIE, T_PROFANATION, T_DOGME, T_RELIQUES,
	T_PARANOIA, T_PERSECUTION, T_DENONCIATION, T_PANIQUE,
	T_PACTE, T_ABDICATION, T_OBEISSANCE, T_RENONCEMENT,
]

# Codex setup pools: 4 cards per domain; setup picks 2 at random.
# Simonie is classed under Foi for Codex setup (plays from Foi or Ambition).
const CODEX_DOMAIN_GROUPS := {
	GameEnums.DomainId.AMBITION: [T_NEPOTISME, T_TRAFIC,    T_INTRIGUE,     T_BULLE],
	GameEnums.DomainId.DESIR:    [T_FESTIN,    T_FAVORI,    T_MASCARADE,    T_APPETIT],
	GameEnums.DomainId.FOI:      [T_SIMONIE,   T_PROFANATION,T_DOGME,       T_RELIQUES],
	GameEnums.DomainId.PEUR:     [T_PARANOIA,  T_PERSECUTION,T_DENONCIATION, T_PANIQUE],
	GameEnums.DomainId.VOLONTE:  [T_PACTE,     T_ABDICATION, T_OBEISSANCE,   T_RENONCEMENT],
}


func get_def(tid: String) -> Dictionary:
	# Compose a localised def on the fly so existing call sites that read
	# def["name"] / def["scandal_text"] / def["infamy_text"] keep working.
	var base: Dictionary = CATALOG.get(tid, {})
	if base.is_empty():
		return {}
	var result: Dictionary = base.duplicate()
	result["name"] = name_of(tid)
	result["scandal_text"] = scandal_text_of(tid)
	result["infamy_text"] = infamy_text_of(tid)
	return result


func name_of(tid: String) -> String:
	return I18n.t("transgression.%s.name" % tid)


func scandal_text_of(tid: String) -> String:
	return I18n.t("transgression.%s.scandal" % tid)


func infamy_text_of(tid: String) -> String:
	return I18n.t("transgression.%s.infamy" % tid)


func card_image_path(tid: String, face: int) -> String:
	# face: GameEnums.TransgressionFace.SCANDALE / INFAMIE
	var f := "scandale" if face == GameEnums.TransgressionFace.SCANDALE else "infamie"
	return "res://assets/cards/transgressions/%s_%s.jpg" % [tid, f]
