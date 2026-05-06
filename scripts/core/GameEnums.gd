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
	PUISER,
}

enum TransgressionFace { NONE, SCANDALE, INFAMIE }

enum LiturgyMode { IN_INTEGRO, IMPEDITA }

# ─── Player visual identity (single source of truth) ──────────────────────────
# PlayerId.BLUE keeps its enum name (changing it would touch ~30 files), but
# its visual identity is now violet/purple. All UI code reads from these
# tables — never hardcode a player colour again.

const PLAYER_COLORS := {
	PlayerId.RED:  Color(0.92, 0.30, 0.32),  # warm crimson
	PlayerId.BLUE: Color(0.65, 0.40, 0.95),  # demonic violet
}

# Lighter accent variants for badges, ascendant bars, glow effects.
const PLAYER_COLORS_LIGHT := {
	PlayerId.RED:  Color(1.00, 0.55, 0.55),
	PlayerId.BLUE: Color(0.78, 0.55, 1.00),
}

# Translation keys — call I18n.t() to get the localised string.
const PLAYER_NAME_KEYS := {
	PlayerId.RED:  "player.red",
	PlayerId.BLUE: "player.blue",
}

const DOMAIN_NAME_KEYS := {
	DomainId.AMBITION: "domain.ambition",
	DomainId.DESIR:    "domain.desir",
	DomainId.FOI:      "domain.foi",
	DomainId.PEUR:     "domain.peur",
	DomainId.VOLONTE:  "domain.volonte",
}

const STATION_NAME_KEYS := {
	StationId.MURMURES:   "station.murmures",
	StationId.TENTATION:  "station.tentation",
	StationId.CHUTE:      "station.chute",
	StationId.CONFESSION: "station.confession",
	StationId.OFFICE:     "station.office",
	StationId.EXORCISME:  "station.exorcisme",
}

const ACTION_NAME_KEYS := {
	ActionId.INVESTIR:  "action.investir",
	ActionId.EXPLOITER: "action.exploiter",
	ActionId.PROVOQUER: "action.provoquer",
	ActionId.AMPLIFIER: "action.amplifier",
	ActionId.SCELLER:   "action.sceller",
	ActionId.FISSURER:  "action.fissurer",
	ActionId.ENTRAVER:  "action.entraver",
	ActionId.PASSER:    "action.passer",
	ActionId.PUISER:    "action.puiser",
}

# Backwards-compat dynamic dicts (built lazily — always reflect current locale).
# Existing call sites that did `GameEnums.DOMAIN_NAMES[d]` keep working; they
# now resolve through I18n at access time.
var DOMAIN_NAMES: Dictionary:
	get:
		var d := {}
		for k in DOMAIN_NAME_KEYS:
			d[k] = I18n.t(DOMAIN_NAME_KEYS[k])
		return d

var STATION_NAMES: Dictionary:
	get:
		var d := {}
		for k in STATION_NAME_KEYS:
			d[k] = I18n.t(STATION_NAME_KEYS[k])
		return d

var ACTION_NAMES: Dictionary:
	get:
		var d := {}
		for k in ACTION_NAME_KEYS:
			d[k] = I18n.t(ACTION_NAME_KEYS[k])
		return d

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

# V1h : starting reserve dropped from 8 to 5 to tighten the early-game
# tempo. The Entrave action also no longer pays from the reserve
# (it's positional now — see GameRules.linked_domains_for_response),
# so 5 is enough for the typical Investir / Provoquer opening lines.
const STARTING_CORRUPTION := 5


func opponent(p: int) -> int:
	if p == PlayerId.RED:
		return PlayerId.BLUE
	if p == PlayerId.BLUE:
		return PlayerId.RED
	return PlayerId.NONE


func player_name(p: int) -> String:
	return I18n.t(PLAYER_NAME_KEYS.get(p, "player.none"))


func player_color(p: int) -> Color:
	return PLAYER_COLORS.get(p, Color.WHITE)


func player_color_light(p: int) -> Color:
	return PLAYER_COLORS_LIGHT.get(p, Color.WHITE)
