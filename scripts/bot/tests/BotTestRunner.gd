class_name BotTestRunner
extends RefCounted

var results: Array = []
var pass_count: int = 0
var fail_count: int = 0


func run_all() -> Dictionary:
	results.clear()
	pass_count = 0
	fail_count = 0
	_test_action_enumeration_not_empty()
	_test_passer_always_present()
	_test_eval_terminal()
	_test_eval_approx_zero_sum()
	_test_heuristic_bot_picks_action()
	_test_random_bot_100_games()
	return {"pass": pass_count, "fail": fail_count, "total": pass_count + fail_count, "lines": results}


func _assert(cond: bool, name: String, msg: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("PASS  %s" % name)
	else:
		fail_count += 1
		results.append("FAIL  %s%s" % [name, "" if msg.is_empty() else " — " + msg])


func _test_action_enumeration_not_empty() -> void:
	var s := GameState.new()
	var actions := ActionEnumerator.list(s, GameEnums.PlayerId.RED)
	_assert(actions.size() > 0, "ActionEnumerator retourne des actions en début de partie")
	var investir_count := 0
	var passer_count := 0
	for a in actions:
		if a["action_id"] == GameEnums.ActionId.INVESTIR:
			investir_count += 1
		if a["action_id"] == GameEnums.ActionId.PASSER:
			passer_count += 1
	_assert(investir_count == 5, "Début de partie : 5 INVESTIR disponibles")
	_assert(passer_count == 1, "Début de partie : PASSER présent exactement une fois")


func _test_passer_always_present() -> void:
	var s := GameState.new()
	s.available_corruption[GameEnums.PlayerId.RED] = 0
	var actions := ActionEnumerator.list(s, GameEnums.PlayerId.RED)
	var has_passer := false
	var has_puiser := false
	for a in actions:
		if a["action_id"] == GameEnums.ActionId.PASSER:
			has_passer = true
		if a["action_id"] == GameEnums.ActionId.PUISER:
			has_puiser = true
	_assert(has_passer, "PASSER toujours présent même à 0 Corruption")
	_assert(has_puiser, "PUISER présent quand réserve == 0")


func _test_eval_terminal() -> void:
	var s := GameState.new()
	s.game_over = true
	s.winner = GameEnums.PlayerId.RED
	_assert(Eval.score(s, GameEnums.PlayerId.RED) == 1.0, "Eval terminal : gagnant = +1")
	_assert(Eval.score(s, GameEnums.PlayerId.BLUE) == -1.0, "Eval terminal : perdant = -1")
	s.winner = GameEnums.PlayerId.NONE
	_assert(Eval.score(s, GameEnums.PlayerId.RED) == 0.0, "Eval terminal : égalité = 0")


func _test_eval_approx_zero_sum() -> void:
	var s := GameState.new()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.BLUE, 3)
	var r := Eval.score(s, GameEnums.PlayerId.RED)
	var b := Eval.score(s, GameEnums.PlayerId.BLUE)
	_assert(absf(r + b) < 0.01, "Eval approx zero-sum (r+b ≈ 0)", "r=%f b=%f" % [r, b])


func _test_heuristic_bot_picks_action() -> void:
	var s := GameState.new()
	var bot := HeuristicBot.new()
	var decision := bot.pick_action(s, GameEnums.PlayerId.RED)
	_assert(decision.has("action_id"), "HeuristicBot retourne une décision avec action_id")


func _test_random_bot_100_games() -> void:
	var errors := 0
	var max_liturgy := 20
	for _i in range(100):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = RandomBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = RandomBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty():
				tm.acknowledge_liturgy()
			else:
				break
			turns += 1
		if not s.game_over:
			errors += 1
	_assert(errors == 0, "100 parties RandomBot vs RandomBot sans erreur",
		"erreurs : %d" % errors)
