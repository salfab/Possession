class_name MCTSBot
extends BotBase
# Flat UCB1 MCTS: treats each root action as a bandit arm,
# runs rollouts within a time budget, returns the most-visited arm.
# Rollouts use RandomBot up to ROLLOUT_STATIONS station-transitions deep,
# then score with Eval. Pure GDScript, no threads, fully synchronous.

const C_UCT: float = 1.41421356    # sqrt(2) — standard UCT exploration constant
const ROLLOUT_STATIONS: int = 3    # max station-transitions per rollout

var budget_ms: int = 200
var _rollout_bot := RandomBot.new()


func pick_action(state: GameState, player: int) -> Dictionary:
	var actions := ActionEnumerator.list(state, player)
	if actions.size() == 0:
		return {"action_id": GameEnums.ActionId.PASSER, "kwargs": {}}
	if actions.size() == 1:
		return actions[0]

	var n := actions.size()
	var visits: Array = []
	var totals: Array = []
	for _i in n:
		visits.append(0)
		totals.append(0.0)

	var start_ms := Time.get_ticks_msec()
	var total_visits := 0

	while Time.get_ticks_msec() - start_ms < budget_ms:
		var sel := _select_ucb1(visits, totals, n, total_visits)
		var value := _simulate(state, player, actions[sel])
		visits[sel] += 1
		totals[sel] += value
		total_visits += 1

	# Most-visited arm is the most reliable choice.
	# Tie-break by mean value; fall back to Eval if budget elapsed before first rollout.
	var best := _best_arm(visits, totals, n)
	if visits[best] == 0:
		return HeuristicBot.new().pick_action(state, player)
	return actions[best]


func _select_ucb1(visits: Array, totals: Array, n: int, total: int) -> int:
	var best_i := 0
	var best_ucb := -1e30
	var log_total := log(float(total + 1))
	for i in n:
		var ucb: float
		if visits[i] == 0:
			ucb = 1e30
		else:
			ucb = (totals[i] / visits[i]) + C_UCT * sqrt(log_total / visits[i])
		if ucb > best_ucb:
			best_ucb = ucb
			best_i = i
	return best_i


func _best_arm(visits: Array, totals: Array, n: int) -> int:
	var best := 0
	var best_mean := -1e30
	for i in n:
		var mean: float = totals[i] / float(max(visits[i], 1)) if visits[i] > 0 else -1e30
		if visits[i] > visits[best] or (visits[i] == visits[best] and mean > best_mean):
			best_mean = mean
			best = i
	return best


func _simulate(state: GameState, player: int, action: Dictionary) -> float:
	# Clone state — bot_for_player is NOT serialised, so the clone has none.
	var s := GameState.new()
	s.from_dict(state.to_dict())

	# Recreate TurnManager without re-running _begin_station.
	# Restore mid-pulse context: if active_player is not the initiative player,
	# the initiative player has already acted this pulse.
	var tm := TurnManager.new(s, false)
	var initiative: int = GameEnums.STATION_INITIATIVE[s.current_station]
	if s.active_player != initiative:
		tm._pulse_actions_done[initiative] = true

	# Apply the candidate action on the clone.
	var result := tm.perform_action(action["action_id"], action.get("kwargs", {}))
	if not result.get("ok", false):
		return Eval.score(s, player)

	# Shallow rollout: RandomBot for both sides, up to ROLLOUT_STATIONS transitions.
	s.bot_for_player[GameEnums.PlayerId.RED] = _rollout_bot
	s.bot_for_player[GameEnums.PlayerId.BLUE] = _rollout_bot
	tm._check_bot_turn()
	var turns := 0
	while not s.game_over and turns < ROLLOUT_STATIONS:
		if not tm.pending_liturgy.is_empty():
			tm.acknowledge_liturgy()
			turns += 1
		else:
			break

	return Eval.score(s, player)
