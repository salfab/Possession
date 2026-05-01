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
