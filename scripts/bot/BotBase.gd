class_name BotBase
extends RefCounted

func pick_action(state: GameState, player: int) -> Dictionary:
	push_error("BotBase.pick_action must be overridden")
	return {}


# Pick which free-exploitation domain to take among `options` (Array[int] of
# DomainId). Returns the chosen DomainId, or -1 to skip. Greedy 1-ply over a
# state clone using the same Eval the MCTS rollout/leaf uses : free exploit is
# a pure-gain action, so the highest-eval domain is the strongest pick, and
# evaluating ≤5 clones stays far under the 500 ms budget (a full per-option
# MCTS would blow it). Pure — no await / no threads.
func pick_free_exploit(state: GameState, player: int, options: Array) -> int:
	if options.is_empty():
		return -1
	var best_domain: int = -1
	# Baseline = skipping (state unchanged) ; any positive-value exploit beats it.
	var best_score := Eval.score(state, player)
	for d_id in options:
		var clone := GameState.new()
		clone.from_dict(state.to_dict())
		var r := ActionResolver.exploiter(clone, player, d_id, true)
		if not r.get("ok", false):
			continue
		var s := Eval.score(clone, player)
		if s > best_score:
			best_score = s
			best_domain = d_id
	return best_domain
