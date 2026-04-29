extends Node
# Autoloaded singleton: GameEnums
# Centralised constants and enum-like dictionaries for the rules engine.

enum PlayerId { NONE = 0, RED = 1, BLUE = 2 }

enum DomainId { AMBITION = 0, DESIR = 1, FOI = 2, PEUR = 3, VOLONTE = 4 }

enum StationId { MURMURES = 0, TENTATION = 1, CHUTE = 2, CONFESSION = 3, OFFICE = 4, EXORCISME = 5 }

enum ActionId {
	INVESTIR,
	EXPLOITER,
	PROVOQUER,
	AMPLIFIER,
	SCELLER,
	FISSURER,
	ENTRAVER,
	PASSER,
}

enum TransgressionFace { NONE, SCANDALE, INFAMIE }

enum LiturgyMode { IN_INTEGRO, IMPEDITA }

const DOMAIN_NAMES := {
	DomainId.AMBITION: "Ambition",
	DomainId.DESIR: "Désir",
	DomainId.FOI: "Foi",
	DomainId.PEUR: "Peur",
	DomainId.VOLONTE: "Volonté",
}

const STATION_NAMES := {
	StationId.MURMURES: "I — Murmures",
	StationId.TENTATION: "II — Tentation",
	StationId.CHUTE: "III — Chute",
	StationId.CONFESSION: "IV — Confession",
	StationId.OFFICE: "V — Office sacré",
	StationId.EXORCISME: "VI — Exorcisme",
}

const STATION_PULSES := {
	StationId.MURMURES: 3,
	StationId.TENTATION: 4,
	StationId.CHUTE: 4,
	StationId.CONFESSION: 4,
	StationId.OFFICE: 5,
	StationId.EXORCISME: 3,
}

const STATION_INITIATIVE := {
	StationId.MURMURES: PlayerId.RED,
	StationId.TENTATION: PlayerId.BLUE,
	StationId.CHUTE: PlayerId.RED,
	StationId.CONFESSION: PlayerId.BLUE,
	StationId.OFFICE: PlayerId.RED,
	StationId.EXORCISME: PlayerId.BLUE,
}

# Used by Signe-de-croix and Confession tie-breakers (priority list closest to Volonté).
const VOLONTE_PROXIMITY_PRIORITY := [
	DomainId.VOLONTE,
	DomainId.FOI,
	DomainId.PEUR,
	DomainId.DESIR,
	DomainId.AMBITION,
]

const ACTION_NAMES := {
	ActionId.INVESTIR: "Investir",
	ActionId.EXPLOITER: "Exploiter",
	ActionId.PROVOQUER: "Provoquer",
	ActionId.AMPLIFIER: "Amplifier",
	ActionId.SCELLER: "Sceller",
	ActionId.FISSURER: "Fissurer",
	ActionId.ENTRAVER: "Entraver",
	ActionId.PASSER: "Passer",
}

const STARTING_CORRUPTION := 8


func opponent(p: int) -> int:
	if p == PlayerId.RED:
		return PlayerId.BLUE
	if p == PlayerId.BLUE:
		return PlayerId.RED
	return PlayerId.NONE


func player_name(p: int) -> String:
	match p:
		PlayerId.RED: return "Rouge"
		PlayerId.BLUE: return "Bleu"
		_: return "—"
