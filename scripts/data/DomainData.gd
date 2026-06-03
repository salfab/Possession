extends Node
# Autoloaded singleton: DomainData
# Static descriptors for the 5 Domaines.

const DOMAINS := [
	GameEnums.DomainId.AMBITION,
	GameEnums.DomainId.DESIR,
	GameEnums.DomainId.FOI,
	GameEnums.DomainId.PEUR,
	GameEnums.DomainId.VOLONTE,
]

func name_of(d: int) -> String:
	return GameEnums.DOMAIN_NAMES.get(d, "?")

func production_label(d: int) -> String:
	match d:
		GameEnums.DomainId.AMBITION: return "2 Corruptions"
		GameEnums.DomainId.DESIR: return I18n.t("domain.yield.transgressed_2_3")
		GameEnums.DomainId.FOI: return I18n.t("domain.yield.transgressed_1_2")
		GameEnums.DomainId.PEUR: return I18n.t("domain.yield.cracked_1_2")
		GameEnums.DomainId.VOLONTE: return "0"
		_: return "—"


const _CHIP_KEYS := {
	GameEnums.DomainId.AMBITION: "domain.chip.ambition",
	GameEnums.DomainId.DESIR:    "domain.chip.desir",
	GameEnums.DomainId.FOI:      "domain.chip.foi",
	GameEnums.DomainId.PEUR:     "domain.chip.peur",
	GameEnums.DomainId.VOLONTE:  "domain.chip.volonte",
}

const _HINT_KEYS := {
	GameEnums.DomainId.AMBITION: "domain.hint.ambition",
	GameEnums.DomainId.DESIR:    "domain.hint.desir",
	GameEnums.DomainId.FOI:      "domain.hint.foi",
	GameEnums.DomainId.PEUR:     "domain.hint.peur",
	GameEnums.DomainId.VOLONTE:  "domain.hint.volonte",
}

# Compact yield label for the always-visible board chip (Volonté = "Victoire").
func chip_label(d: int) -> String:
	return I18n.t(String(_CHIP_KEYS.get(d, "")))

# One-line "why invest" advantage text for the action menu header.
func advantage_text(d: int) -> String:
	return I18n.t(String(_HINT_KEYS.get(d, "")))

# Volonté is the victory domain (Fiat Tenebris) — drives the violet accent
# and star glyph on its chip instead of a Corruption count.
func is_victory_domain(d: int) -> bool:
	return d == GameEnums.DomainId.VOLONTE
