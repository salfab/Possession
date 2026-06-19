extends RefCounted
# Headless check : the new-game dialog options (Codex / Missel) actually configure
# the fresh GameState through new_game(config), and DON'T leak into _player_config.
# load()'d from run_ui_tests so autoload identifiers (GameEnums) resolve in the body.

func check(main) -> Dictionary:
	var lines: Array = []
	var passed := 0
	var failed := 0

	# Both modules ON.
	main.new_game({
		GameEnums.PlayerId.RED: "human",
		GameEnums.PlayerId.PURPLE: "human",
		"codex": true, "missel": true,
	})
	var s = main.state
	if s.codex_of_transgressions_enabled and s.codex_available.size() == 10:
		passed += 1
		lines.append("PASS  new-game : Codex activé (10 cartes)")
	else:
		failed += 1
		lines.append("FAIL  new-game : Codex devrait être activé avec 10 cartes")
	if s.missel_modifiers.size() == 5:
		passed += 1
		lines.append("PASS  new-game : Missel activé (5 modificateurs)")
	else:
		failed += 1
		lines.append("FAIL  new-game : Missel devrait poser 5 modificateurs (obtenu %d)" % s.missel_modifiers.size())
	# The string option keys must NOT pollute _player_config (Human/AI only).
	if not main._player_config.has("codex") and not main._player_config.has("missel"):
		passed += 1
		lines.append("PASS  new-game : options absentes de _player_config")
	else:
		failed += 1
		lines.append("FAIL  new-game : _player_config ne doit pas contenir codex/missel")

	# Both modules OFF → vanilla game.
	main.new_game({
		GameEnums.PlayerId.RED: "human",
		GameEnums.PlayerId.PURPLE: "human",
		"codex": false, "missel": false,
	})
	var s2 = main.state
	if not s2.codex_of_transgressions_enabled and s2.missel_modifiers.is_empty():
		passed += 1
		lines.append("PASS  new-game : modules désactivés → partie vanilla")
	else:
		failed += 1
		lines.append("FAIL  new-game : modules off devraient donner une partie vanilla")

	return {"lines": lines, "pass": passed, "fail": failed}
