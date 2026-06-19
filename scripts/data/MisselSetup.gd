class_name MisselSetup
extends RefCounted
# Missel Corrompu setup helper (mirrors CodexSetup).
# setup() — assigns one random modifier to each Station that has variants
# (I–V ; the Exorcisme never has one). Game use ; takes an RNG for determinism.

static func setup(state: GameState, rng: RandomNumberGenerator) -> void:
	state.missel_modifiers = {}
	# Collect the distinct Stations that own modifiers, then pick one at random
	# (A or B) for each — derived from MisselData so it tracks any future change.
	var stations := {}
	for mid in MisselData.MODIFIERS.keys():
		stations[MisselData.MODIFIERS[mid]["station"]] = true
	for st in stations.keys():
		var mods: Array = MisselData.modifiers_for_station(st)
		if mods.is_empty():
			continue
		state.missel_modifiers[st] = mods[rng.randi_range(0, mods.size() - 1)]
