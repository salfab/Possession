extends Node
# Autoloaded singleton: LiturgicalResponseData
# Static descriptors for the 5 liturgical responses (Stations I to V).
# Strings are I18n keys — call name_of() / text_in_integro_of() /
# text_impedita_of() to read them in the current locale.

const SIGNE_DE_CROIX := "signe_de_croix"
const EXAMEN := "examen_de_conscience"
const CONTRITION := "contrition"
const CONFESSION := "confession"
const COMMUNION := "communion"

const RESPONSES := {
	GameEnums.StationId.MURMURES:   {"id": SIGNE_DE_CROIX},
	GameEnums.StationId.TENTATION:  {"id": EXAMEN},
	GameEnums.StationId.CHUTE:      {"id": CONTRITION},
	GameEnums.StationId.CONFESSION: {"id": CONFESSION},
	GameEnums.StationId.OFFICE:     {"id": COMMUNION},
}


func get_response(station: int) -> Dictionary:
	# Compose a localised response on the fly so existing call sites that read
	# resp["name"] / resp["text_in_integro"] / resp["text_impedita"] keep working.
	var base: Dictionary = RESPONSES.get(station, {})
	if base.is_empty():
		return {}
	var rid: String = String(base.get("id", ""))
	return {
		"id": rid,
		"name": name_of(rid),
		"text_in_integro": text_in_integro_of(rid),
		"text_impedita": text_impedita_of(rid),
	}


func name_of(rid: String) -> String:
	return I18n.t("liturgy.%s.name" % rid)


func text_in_integro_of(rid: String) -> String:
	return I18n.t("liturgy.%s.in_integro" % rid)


func text_impedita_of(rid: String) -> String:
	return I18n.t("liturgy.%s.impedita" % rid)


func card_image_path(station: int, impedita: bool) -> String:
	var resp: Dictionary = RESPONSES.get(station, {})
	if resp.is_empty():
		return ""
	var id: String = String(resp.get("id", ""))
	var mode: String = "impedita" if impedita else "in_integro"
	return "res://assets/cards/liturgies/%s_%s.jpg" % [id, mode]
