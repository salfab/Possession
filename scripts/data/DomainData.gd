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
		GameEnums.DomainId.DESIR: return "2 (3 si transgressé)"
		GameEnums.DomainId.FOI: return "1 (2 si transgressé)"
		GameEnums.DomainId.PEUR: return "1 (2 si Domaine fissuré ce tour)"
		GameEnums.DomainId.VOLONTE: return "0"
		_: return "—"
