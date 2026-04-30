extends Node
# Autoloaded singleton: LiturgicalResponseData
# Static descriptors for the 5 liturgical responses (Stations I to V).

const SIGNE_DE_CROIX := "signe_de_croix"
const EXAMEN := "examen_de_conscience"
const CONTRITION := "contrition"
const CONFESSION := "confession"
const COMMUNION := "communion"

const RESPONSES := {
	GameEnums.StationId.MURMURES: {
		"id": SIGNE_DE_CROIX,
		"name": "Signe de croix",
		"text_in_integro": "Brise la Domination dans le Domaine ciblé. Sinon, chaque démon y perd 1 Corruption disponible.",
		"text_impedita": "Le démon avec le plus d'Emprise dans le Domaine ciblé perd 1 Corruption disponible.",
	},
	GameEnums.StationId.TENTATION: {
		"id": EXAMEN,
		"name": "Examen de conscience",
		"text_in_integro": "Brise la Domination ; ce Domaine ne peut pas être scellé jusqu'à la fin de la prochaine Station.",
		"text_impedita": "Ce Domaine ne peut pas être scellé jusqu'à la fin de cette Station.",
	},
	GameEnums.StationId.CHUTE: {
		"id": CONTRITION,
		"name": "Contrition",
		"text_in_integro": "Si scellé : Fissure liturgique (Sceau retiré + Domination brisée). Sinon : Brise la Domination. Puis Pénitence.",
		"text_impedita": "Mettez ce Domaine en Pénitence jusqu'à la fin de la prochaine Station.",
	},
	GameEnums.StationId.CONFESSION: {
		"id": CONFESSION,
		"name": "Confession",
		"text_in_integro": "Le démon ciblé choisit DEUX pénitences différentes parmi 3.",
		"text_impedita": "Le démon ciblé choisit UNE pénitence parmi 3.",
	},
	GameEnums.StationId.OFFICE: {
		"id": COMMUNION,
		"name": "Communion",
		"text_in_integro": "Si scellé : Fissure liturgique. Puis interdit le rescellement avant l'Exorcisme.",
		"text_impedita": "Si scellé : Fissure simple (Sceau retiré). Sinon : Brise la Domination.",
	},
}

func get_response(station: int) -> Dictionary:
	return RESPONSES.get(station, {})

func card_image_path(station: int, impedita: bool) -> String:
	var resp: Dictionary = get_response(station)
	if resp.is_empty():
		return ""
	var id: String = String(resp.get("id", ""))
	var mode: String = "impedita" if impedita else "in_integro"
	return "res://assets/cards/liturgies/%s_%s.png" % [id, mode]
