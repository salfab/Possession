extends Node
# Autoloaded singleton: CardImages
# Preloads all card textures so they're guaranteed to be packed into the
# Web/HTML5 export (Godot only includes assets that are explicitly referenced
# at compile time — runtime load(path) on .png files often fails on web
# because the resource isn't bundled).

const TRANSGRESSIONS := {
	"nepotisme_scandale":             preload("res://assets/cards/transgressions/nepotisme_scandale.png"),
	"nepotisme_infamie":              preload("res://assets/cards/transgressions/nepotisme_infamie.png"),
	"trafic_charges_scandale":        preload("res://assets/cards/transgressions/trafic_charges_scandale.png"),
	"trafic_charges_infamie":         preload("res://assets/cards/transgressions/trafic_charges_infamie.png"),
	"festin_obscene_scandale":        preload("res://assets/cards/transgressions/festin_obscene_scandale.png"),
	"festin_obscene_infamie":         preload("res://assets/cards/transgressions/festin_obscene_infamie.png"),
	"favori_secret_scandale":         preload("res://assets/cards/transgressions/favori_secret_scandale.png"),
	"favori_secret_infamie":          preload("res://assets/cards/transgressions/favori_secret_infamie.png"),
	"simonie_scandale":               preload("res://assets/cards/transgressions/simonie_scandale.png"),
	"simonie_infamie":                preload("res://assets/cards/transgressions/simonie_infamie.png"),
	"profanation_scandale":           preload("res://assets/cards/transgressions/profanation_scandale.png"),
	"profanation_infamie":            preload("res://assets/cards/transgressions/profanation_infamie.png"),
	"paranoia_scandale":              preload("res://assets/cards/transgressions/paranoia_scandale.png"),
	"paranoia_infamie":               preload("res://assets/cards/transgressions/paranoia_infamie.png"),
	"persecution_scandale":           preload("res://assets/cards/transgressions/persecution_scandale.png"),
	"persecution_infamie":            preload("res://assets/cards/transgressions/persecution_infamie.png"),
	"pacte_silencieux_scandale":      preload("res://assets/cards/transgressions/pacte_silencieux_scandale.png"),
	"pacte_silencieux_infamie":       preload("res://assets/cards/transgressions/pacte_silencieux_infamie.png"),
	"abdication_interieure_scandale": preload("res://assets/cards/transgressions/abdication_interieure_scandale.png"),
	"abdication_interieure_infamie":  preload("res://assets/cards/transgressions/abdication_interieure_infamie.png"),
}

const LITURGIES := {
	"signe_de_croix_in_integro":       preload("res://assets/cards/liturgies/signe_de_croix_in_integro.png"),
	"signe_de_croix_impedita":         preload("res://assets/cards/liturgies/signe_de_croix_impedita.png"),
	"examen_de_conscience_in_integro": preload("res://assets/cards/liturgies/examen_de_conscience_in_integro.png"),
	"examen_de_conscience_impedita":   preload("res://assets/cards/liturgies/examen_de_conscience_impedita.png"),
	"contrition_in_integro":           preload("res://assets/cards/liturgies/contrition_in_integro.png"),
	"contrition_impedita":             preload("res://assets/cards/liturgies/contrition_impedita.png"),
	"confession_in_integro":           preload("res://assets/cards/liturgies/confession_in_integro.png"),
	"confession_impedita":             preload("res://assets/cards/liturgies/confession_impedita.png"),
	"communion_in_integro":            preload("res://assets/cards/liturgies/communion_in_integro.png"),
	"communion_impedita":              preload("res://assets/cards/liturgies/communion_impedita.png"),
}

const EXORCISME_FINAL := preload("res://assets/cards/special/exorcisme_final.jpg")


func transgression(tid: String, face: int) -> Texture2D:
	var f: String = "scandale" if face == GameEnums.TransgressionFace.SCANDALE else "infamie"
	var key: String = "%s_%s" % [tid, f]
	return TRANSGRESSIONS.get(key)


func liturgy(response_id: String, impedita: bool) -> Texture2D:
	var mode: String = "impedita" if impedita else "in_integro"
	var key: String = "%s_%s" % [response_id, mode]
	return LITURGIES.get(key)


func exorcisme() -> Texture2D:
	return EXORCISME_FINAL
