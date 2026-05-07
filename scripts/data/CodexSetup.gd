class_name CodexSetup
extends RefCounted
# Codex des Transgressions setup helper.
# setup()        — random 2-per-domain selection (game use).
# setup_manual() — deterministic selection for tests.

static func setup(state: GameState, rng: RandomNumberGenerator) -> void:
	state.codex_of_transgressions_enabled = true
	state.codex_available = []
	for domain_id in TransgressionData.CODEX_DOMAIN_GROUPS.keys():
		var pool: Array = TransgressionData.CODEX_DOMAIN_GROUPS[domain_id].duplicate()
		for i in range(pool.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: String = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		state.codex_available.append(pool[0])
		state.codex_available.append(pool[1])


static func setup_manual(state: GameState, selected_ids: Array) -> void:
	state.codex_of_transgressions_enabled = true
	state.codex_available = selected_ids.duplicate()
