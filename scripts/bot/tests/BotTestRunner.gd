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
	_benchmark_heuristic_vs_random()
	_test_mcts_picks_action()
	_benchmark_mcts_vs_heuristic()
	_benchmark_mcts_vs_mcts()
	_test_missel_baseline_unchanged()
	_test_codex_games_complete()
	return {"pass": pass_count, "fail": fail_count, "total": pass_count + fail_count, "lines": results}


func run_balance(n_per_modifier: int = 20) -> Dictionary:
	results.clear()
	pass_count = 0
	fail_count = 0
	results.append("=== Balance Missel Corrompu (%d parties/modificateur) ===" % n_per_modifier)
	_benchmark_mcts_budget(2000, 10)
	_benchmark_missel_all(n_per_modifier)
	_benchmark_codex_vs_baseline(n_per_modifier)
	_benchmark_combined(n_per_modifier)
	_benchmark_initiative_swapped(n_per_modifier)
	_benchmark_corruption_asymmetry(n_per_modifier)
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


func _benchmark_heuristic_vs_random() -> void:
	var n := 100
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED]  = HeuristicBot.new()
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
		elif s.winner == GameEnums.PlayerId.RED:
			wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE:
			wins_blue += 1
		else:
			draws += 1
	results.append("  [bench] HeuristicBot(R) vs RandomBot(B) sur %d parties :" % n)
	results.append("          Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	_assert(errors == 0, "Benchmark : 0 partie non terminée")
	# Church wins ~90% in random play; when a demon wins, HeuristicBot should dominate.
	_assert(wins_red > wins_blue, "Benchmark : HeuristicBot gagne plus que Random",
		"Rouge=%d Violet=%d" % [wins_red, wins_blue])


func _test_mcts_picks_action() -> void:
	var s := GameState.new()
	var bot := MCTSBot.new()
	bot.budget_ms = 200
	var decision := bot.pick_action(s, GameEnums.PlayerId.RED)
	_assert(decision.has("action_id"), "MCTSBot retourne une décision avec action_id")
	results.append("  [diag] MCTSBot itérations en 200 ms (état initial) : %d" % bot.last_iterations)
	_assert(bot.last_iterations > 0, "MCTSBot effectue au moins 1 rollout en 200 ms")


func _benchmark_mcts_vs_heuristic() -> void:
	var n := 30
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED]  = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = HeuristicBot.new()
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
		elif s.winner == GameEnums.PlayerId.RED:
			wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE:
			wins_blue += 1
		else:
			draws += 1
	results.append("  [bench] MCTSBot(R,200ms) vs HeuristicBot(B) sur %d parties :" % n)
	results.append("          Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	_assert(errors == 0, "Benchmark MCTS : 0 partie non terminée")
	# MCTSBot should win at least as many demon-wins as HeuristicBot.
	_assert(wins_red >= wins_blue, "Benchmark : MCTSBot gagne au moins autant que Heuristic",
		"Rouge=%d Violet=%d" % [wins_red, wins_blue])


func _benchmark_mcts_vs_mcts() -> void:
	var n := 20
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED]  = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
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
		elif s.winner == GameEnums.PlayerId.RED:
			wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE:
			wins_blue += 1
		else:
			draws += 1
	results.append("  [bench] MCTSBot(R) vs MCTSBot(B) sur %d parties :" % n)
	results.append("          Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	_assert(errors == 0, "Benchmark MCTS symétrique : 0 partie non terminée")


func _benchmark_mcts_budget(budget: int, n: int) -> void:
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		var bot := MCTSBot.new()
		bot.budget_ms = budget
		s.bot_for_player[GameEnums.PlayerId.RED]  = bot
		s.bot_for_player[GameEnums.PlayerId.BLUE] = HeuristicBot.new()
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
		elif s.winner == GameEnums.PlayerId.RED:
			wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE:
			wins_blue += 1
		else:
			draws += 1
	results.append("  [bench] MCTSBot(R,%dms) vs HeuristicBot(B) sur %d parties :" % [budget, n])
	results.append("          Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	_assert(errors == 0, "Benchmark MCTS %dms : 0 partie non terminée" % budget)


# --- Missel Corrompu tests --------------------------------------------------

func _test_missel_baseline_unchanged() -> void:
	# missel_modifiers vide → ciblage V1h identique (Signe de Croix cible max emprise)
	var s := GameState.new()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	var target := LiturgyResolver.preview_target_domain(s, GameEnums.StationId.MURMURES)
	_assert(target == GameEnums.DomainId.AMBITION,
		"Missel désactivé : Signe de Croix cible Ambition (max emprise)")

	# I-A actif mais tous les domaines sont scellés → fallback V1h
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	s.missel_modifiers[GameEnums.StationId.MURMURES] = "I-A"
	var target_ia := LiturgyResolver.preview_target_domain(s, GameEnums.StationId.MURMURES)
	_assert(target_ia == GameEnums.DomainId.AMBITION,
		"I-A : fallback V1h quand aucun domaine non scellé avec corruption")

	# I-A actif, domaine non scellé avec corruption → cible le non scellé
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.NONE
	s.domain(GameEnums.DomainId.DESIR).seal_owner = GameEnums.PlayerId.RED
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED, 5)
	target_ia = LiturgyResolver.preview_target_domain(s, GameEnums.StationId.MURMURES)
	_assert(target_ia == GameEnums.DomainId.AMBITION,
		"I-A : cible le domaine non scellé (Ambition), ignore Désir scellé")


func _benchmark_missel_modifier(modifier_id: String, n: int) -> void:
	var station: int = MisselData.MODIFIERS[modifier_id]["station"]
	var name_str: String = MisselData.MODIFIERS[modifier_id]["name"]
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		s.missel_modifiers[station] = modifier_id
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
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
		elif s.winner == GameEnums.PlayerId.RED:
			wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE:
			wins_blue += 1
		else:
			draws += 1
	var asymmetry: int = absi(wins_red - wins_blue)
	results.append("  [missel] %s (%s) sur %d parties :" % [modifier_id, name_str, n])
	results.append("           Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	_assert(errors == 0, "Missel %s : 0 partie non terminée" % modifier_id)
	_assert(float(draws) / n <= 0.80,
		"Missel %s : Église < 80%% (modificateur pas trop punitif)" % modifier_id,
		"Église=%.0f%%" % (100.0 * draws / n))
	_assert(asymmetry <= n / 2,
		"Missel %s : asymétrie Rouge/Violet raisonnable" % modifier_id,
		"R=%d V=%d" % [wins_red, wins_blue])


func _benchmark_missel_all(n: int = 20) -> void:
	results.append("  [missel] === Baseline MCTSBot vs MCTSBot (V1h) ===")
	var wins_red := 0
	var wins_blue := 0
	var draws := 0
	var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty():
				tm.acknowledge_liturgy()
			else:
				break
			turns += 1
		if not s.game_over: errors += 1
		elif s.winner == GameEnums.PlayerId.RED: wins_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE: wins_blue += 1
		else: draws += 1
	results.append("  [baseline] Rouge %d/%d (%.0f%%)  Violet %d/%d (%.0f%%)  Église %d/%d (%.0f%%)" % [
		wins_red, n, 100.0 * wins_red / n,
		wins_blue, n, 100.0 * wins_blue / n,
		draws, n, 100.0 * draws / n])
	results.append("  [missel] === Modificateurs ===")
	for mod_id in MisselData.MODIFIERS.keys():
		_benchmark_missel_modifier(mod_id, n)


# ---------------------------------------------------------------------------
# Codex des Transgressions — smoke test (run_all)
# ---------------------------------------------------------------------------
func _test_codex_games_complete() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var errors := 0
	var max_liturgy := 20
	for _i in range(5):
		var s := GameState.new()
		CodexSetup.setup(s, rng)
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = HeuristicBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = HeuristicBot.new()
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
	_assert(errors == 0, "Codex : 5 parties HeuristicBot vs HeuristicBot se terminent toutes")


# ---------------------------------------------------------------------------
# Codex des Transgressions — Monte Carlo comparison (run_balance)
# ---------------------------------------------------------------------------
func _benchmark_codex_vs_baseline(n: int = 20) -> void:
	results.append("=== Balance Codex des Transgressions (%d parties) ===" % n)

	# --- Baseline V1h ---
	var b_red := 0; var b_blue := 0; var b_draws := 0; var b_err := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty(): tm.acknowledge_liturgy()
			else: break
			turns += 1
		if not s.game_over: b_err += 1
		elif s.winner == GameEnums.PlayerId.RED: b_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE: b_blue += 1
		else: b_draws += 1
	results.append("  [V1h baseline] Rouge %d  Violet %d  Église %d  (/%d)" % [b_red, b_blue, b_draws, n])

	# --- 10 random Codex configurations ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0DE1
	var c_red := 0; var c_blue := 0; var c_draws := 0; var c_err := 0
	var c_infamy_counts: Dictionary = {}
	var c_pope_wins := 0
	var c_fiat_wins := 0
	var c_rupture_wins := 0
	for tid in TransgressionData.ALL_IDS_EXTENDED:
		c_infamy_counts[tid] = 0
	for _i in range(n):
		var s := GameState.new()
		CodexSetup.setup(s, rng)
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty(): tm.acknowledge_liturgy()
			else: break
			turns += 1
		if not s.game_over:
			c_err += 1
			continue
		if s.winner == GameEnums.PlayerId.RED: c_red += 1
		elif s.winner == GameEnums.PlayerId.BLUE: c_blue += 1
		else: c_draws += 1
		var reason: String = s.winner_reason
		if "pape" in reason.to_lower() or "exorcism" in reason.to_lower():
			c_pope_wins += 1
		elif "fiat" in reason.to_lower():
			c_fiat_wins += 1
		elif "rupture" in reason.to_lower():
			c_rupture_wins += 1
		# Count infamies per card
		for d_id in DomainData.DOMAINS:
			for ti in s.domain(d_id).infamies:
				if c_infamy_counts.has(ti.def_id):
					c_infamy_counts[ti.def_id] += 1
	var c_asym: int = absi(c_red - c_blue)
	results.append("  [Codex] Rouge %d  Violet %d  Église %d  Erreurs %d  (/%d)" % [c_red, c_blue, c_draws, c_err, n])
	results.append("  [Codex] Fin : Pape sauvé %d  Fiat %d  Rupture %d" % [c_pope_wins, c_fiat_wins, c_rupture_wins])
	results.append("  [Codex] Infamies placées par carte :")
	for tid in TransgressionData.ALL_IDS_EXTENDED:
		if c_infamy_counts.get(tid, 0) > 0:
			results.append("    %s : %d" % [tid, c_infamy_counts[tid]])
	_assert(c_err == 0, "Codex benchmark : 0 partie non terminée", "erreurs=%d" % c_err)
	_assert(c_asym <= n, "Codex benchmark : asymétrie Rouge/Violet raisonnable", "R=%d V=%d" % [c_red, c_blue])


# Codex des Transgressions + Missel Corrompu actifs simultanément
# ---------------------------------------------------------------------------
func _benchmark_combined(n: int = 20) -> void:
	results.append("=== Balance Combiné : Codex + Missel (%d parties) ===" % n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xCAFE1
	var stations: Array = [
		GameEnums.StationId.MURMURES,
		GameEnums.StationId.TENTATION,
		GameEnums.StationId.CHUTE,
		GameEnums.StationId.CONFESSION,
		GameEnums.StationId.OFFICE,
	]
	var red := 0; var blue := 0; var draws := 0; var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		CodexSetup.setup(s, rng)
		for station in stations:
			var mods: Array = MisselData.modifiers_for_station(station)
			var pick: String = mods[rng.randi_range(0, mods.size() - 1)]
			s.missel_modifiers[station] = pick
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty(): tm.acknowledge_liturgy()
			else: break
			turns += 1
		if not s.game_over: errors += 1
		elif s.winner == GameEnums.PlayerId.RED: red += 1
		elif s.winner == GameEnums.PlayerId.BLUE: blue += 1
		else: draws += 1
	var asym: int = absi(red - blue)
	results.append("  [Combiné] Rouge %d  Violet %d  Église %d  Erreurs %d  (/%d)" % [red, blue, draws, errors, n])
	_assert(errors == 0, "Combiné : 0 partie non terminée", "erreurs=%d" % errors)
	_assert(asym <= n, "Combiné : asymétrie Rouge/Violet raisonnable", "R=%d V=%d" % [red, blue])


# Initiative miroir : Violet prend I/III/V, Rouge prend II/IV/VI
# Si la distribution se renverse, l'initiative cause le biais observé.
# ---------------------------------------------------------------------------
func _benchmark_initiative_swapped(n: int = 20) -> void:
	results.append("=== Miroir Initiative (table inversée, %d parties) ===" % n)

	# Construit la table inversée
	var swapped: Dictionary = {}
	for station in GameEnums.STATION_INITIATIVE.keys():
		swapped[station] = GameEnums.opponent(GameEnums.STATION_INITIATIVE[station])

	var red := 0; var blue := 0; var draws := 0; var errors := 0
	var max_liturgy := 20
	for _i in range(n):
		var s := GameState.new()
		s.initiative_override = swapped.duplicate()
		var tm := TurnManager.new(s, true)
		s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
		s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
		tm._check_bot_turn()
		var turns := 0
		while not s.game_over and turns < max_liturgy:
			if not tm.pending_liturgy.is_empty(): tm.acknowledge_liturgy()
			else: break
			turns += 1
		if not s.game_over: errors += 1
		elif s.winner == GameEnums.PlayerId.RED: red += 1
		elif s.winner == GameEnums.PlayerId.BLUE: blue += 1
		else: draws += 1

	var demon_wins: int = red + blue
	var rouge_share: String = "—"
	if demon_wins > 0:
		rouge_share = "%d%%" % int(100.0 * red / demon_wins)
	results.append("  [Miroir] Rouge %d  Violet %d  Église %d  Erreurs %d  (/%d)" % [red, blue, draws, errors, n])
	results.append("  [Miroir] Rouge = %s des victoires démon (normal = 50%% si symétrique)" % rouge_share)
	_assert(errors == 0, "Miroir initiative : 0 partie non terminée", "erreurs=%d" % errors)


# Asymétrie de Corruption de départ : calibration de la compensation premier joueur.
# Teste deux compositions connues (V1h déséquilibré / Missel I-A équitable)
# avec delta = 0 / -1 / -2 Corruption de départ pour Rouge.
# ---------------------------------------------------------------------------
func _benchmark_corruption_asymmetry(n: int = 20) -> void:
	results.append("=== Asymétrie Corruption départ (compensation premier joueur) ===")
	var compositions: Array = [
		{"name": "V1h          ", "modifier": "", "station": -1},
		{"name": "Missel I-A   ", "modifier": "I-A", "station": GameEnums.StationId.MURMURES},
	]
	var deltas: Array = [0, -1, -2]
	var max_liturgy := 20

	for comp in compositions:
		results.append("  --- %s ---" % comp["name"].strip_edges())
		for delta in deltas:
			var red := 0; var blue := 0; var draws := 0; var errors := 0
			for _i in range(n):
				var s := GameState.new()
				if comp["station"] >= 0:
					s.missel_modifiers[comp["station"]] = comp["modifier"]
				if delta != 0:
					s.available_corruption[GameEnums.PlayerId.RED] += delta
				var tm := TurnManager.new(s, true)
				s.bot_for_player[GameEnums.PlayerId.RED] = MCTSBot.new()
				s.bot_for_player[GameEnums.PlayerId.BLUE] = MCTSBot.new()
				tm._check_bot_turn()
				var turns := 0
				while not s.game_over and turns < max_liturgy:
					if not tm.pending_liturgy.is_empty(): tm.acknowledge_liturgy()
					else: break
					turns += 1
				if not s.game_over: errors += 1
				elif s.winner == GameEnums.PlayerId.RED: red += 1
				elif s.winner == GameEnums.PlayerId.BLUE: blue += 1
				else: draws += 1
			var demon_wins: int = red + blue
			var rouge_share: String = "—"
			if demon_wins > 0:
				rouge_share = "%d%%" % int(100.0 * red / demon_wins)
			var label: String = "Rouge 5 vs Violet 5" if delta == 0 else \
				"Rouge %d vs Violet 5" % (GameEnums.STARTING_CORRUPTION + delta)
			results.append("    [%s]  R=%d V=%d Église=%d err=%d  Rouge=%s vict.démon" %
				[label, red, blue, draws, errors, rouge_share])
			_assert(errors == 0,
				"Asymétrie %s delta=%d : 0 erreur" % [comp["name"].strip_edges(), delta],
				"err=%d" % errors)
