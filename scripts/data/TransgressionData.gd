extends Node
# Autoloaded singleton: TransgressionData
# Definitions of the 10 V1g Transgressions.
# Strings (name, scandal text, infamy text) are stored as I18n keys —
# call name_of() / scandal_text_of() / infamy_text_of() to get them in
# the current locale.

const T_NEPOTISME := "nepotisme"
const T_TRAFIC := "trafic_charges"
const T_FESTIN := "festin_obscene"
const T_FAVORI := "favori_secret"
const T_SIMONIE := "simonie"
const T_PROFANATION := "profanation"
const T_PARANOIA := "paranoia"
const T_PERSECUTION := "persecution"
const T_PACTE := "pacte_silencieux"
const T_ABDICATION := "abdication_interieure"

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
}

const ALL_IDS := [
	T_NEPOTISME, T_TRAFIC,
	T_FESTIN, T_FAVORI,
	T_SIMONIE, T_PROFANATION,
	T_PARANOIA, T_PERSECUTION,
	T_PACTE, T_ABDICATION,
]


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
