extends Node
# Autoloaded singleton: TransgressionData
# Definitions of the 10 V1g Transgressions.
# Each entry is a Dictionary; it acts as a static catalogue.
# Effects are referenced by id and resolved in ActionResolver.

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

# Each transgression definition:
# {
#   id, name, domain_requirement: Array[DomainId], origin_choice: bool,
#   default_origin: DomainId, scandal_cost: int, amplification_cost: int,
#   scandal_text, infamy_text
# }
const CATALOG := {
	T_NEPOTISME: {
		"id": T_NEPOTISME,
		"name": "Népotisme",
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 2,
		"amplification_cost": 2,
		"scandal_text": "Gagnez 1 Corruption disponible.",
		"infamy_text": "Tant que vous contrôlez Ambition, votre première Transgression de chaque Station coûte 1 Corruption de moins (min. 1).",
	},
	T_TRAFIC: {
		"id": T_TRAFIC,
		"name": "Trafic de charges",
		"domain_requirement": [GameEnums.DomainId.AMBITION],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.AMBITION,
		"scandal_cost": 2,
		"amplification_cost": 2,
		"scandal_text": "La prochaine Entrave que vous payez coûte 1 Corruption de moins (min. 1).",
		"infamy_text": "Une fois par Station, en provoquant une Transgression liée à Ambition ou Foi, gagnez 1 Corruption disponible.",
	},
	T_FESTIN: {
		"id": T_FESTIN,
		"name": "Festin obscène",
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 2,
		"amplification_cost": 3,
		"scandal_text": "Gagnez 2 Corruptions disponibles.",
		"infamy_text": "Quand vous exploitez Désir, gagnez 1 Corruption supplémentaire.",
	},
	T_FAVORI: {
		"id": T_FAVORI,
		"name": "Favori secret",
		"domain_requirement": [GameEnums.DomainId.DESIR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.DESIR,
		"scandal_cost": 2,
		"amplification_cost": 3,
		"scandal_text": "Placez 1 Corruption disponible sur Volonté (sinon, ignoré).",
		"infamy_text": "Une fois par Station, vous pouvez déplacer 1 de vos Corruptions de Désir vers Volonté.",
	},
	T_SIMONIE: {
		"id": T_SIMONIE,
		"name": "Simonie",
		"domain_requirement": [GameEnums.DomainId.FOI, GameEnums.DomainId.AMBITION],
		"origin_choice": true,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 3,
		"amplification_cost": 2,
		"scandal_text": "Placez une Entrave sur la Réponse liturgique de cette Station ou de la prochaine.",
		"infamy_text": "La prochaine Réponse liturgique qui cible Foi est automatiquement Impedita.",
	},
	T_PROFANATION: {
		"id": T_PROFANATION,
		"name": "Profanation",
		"domain_requirement": [GameEnums.DomainId.FOI],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.FOI,
		"scandal_cost": 3,
		"amplification_cost": 3,
		"scandal_text": "Retirez un Anneau de Pénitence d'un Domaine que vous contrôlez. Sinon, gagnez 1 Corruption disponible.",
		"infamy_text": "Foi contient une Infamie (peut remplir Profondeur).",
	},
	T_PARANOIA: {
		"id": T_PARANOIA,
		"name": "Paranoïa",
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 2,
		"scandal_text": "Fissurez un Domaine scellé par l'autre démon. Sinon, l'autre perd 1 Corruption disponible.",
		"infamy_text": "Une fois par Station, sur une Réponse liturgique, vous pouvez choisir entre les deux Domaines les plus éligibles.",
	},
	T_PERSECUTION: {
		"id": T_PERSECUTION,
		"name": "Persécution",
		"domain_requirement": [GameEnums.DomainId.PEUR],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.PEUR,
		"scandal_cost": 2,
		"amplification_cost": 2,
		"scandal_text": "Choisissez un Domaine contesté : l'autre démon y retire 1 Corruption. Sinon, il perd 1 Corruption disponible.",
		"infamy_text": "Quand vous Brisez la Domination dans un Domaine, l'autre démon y retire 1 Corruption supplémentaire.",
	},
	T_PACTE: {
		"id": T_PACTE,
		"name": "Pacte silencieux",
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 3,
		"scandal_text": "Placez 1 Corruption disponible sur Volonté (sinon ignoré).",
		"infamy_text": "À l'Exorcisme final, si vous contrôlez Volonté, gagnez +1 Ascendant.",
	},
	T_ABDICATION: {
		"id": T_ABDICATION,
		"name": "Abdication intérieure",
		"domain_requirement": [GameEnums.DomainId.VOLONTE],
		"origin_choice": false,
		"default_origin": GameEnums.DomainId.VOLONTE,
		"scandal_cost": 3,
		"amplification_cost": 3,
		"scandal_text": "Si vous contrôlez Volonté, gagnez 1 Corruption ; sinon, placez 1 Corruption sur Volonté (sinon ignoré).",
		"infamy_text": "À l'Exorcisme final, si Volonté est scellée par vous, +1 Ascendant supplémentaire.",
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
	return CATALOG.get(tid, {})

func name_of(tid: String) -> String:
	var d := get_def(tid)
	return d.get("name", "?")
