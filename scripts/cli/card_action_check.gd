extends RefCounted
# Headless check of the transgression card's contextual action button
# (Provoquer / Amplifier). Lives in its own class loaded via load() from
# run_ui_tests.gd : a script run directly as `--script` does NOT resolve autoload
# identifiers (GameEnums / TransgressionData) in its own body, but a load()'d
# class DOES — same reason RulesTestRunner can use them. Takes the already-built
# Main instance and returns {lines, pass, fail}.

func check(main) -> Dictionary:
	var lines: Array = []
	var passed := 0
	var failed := 0
	var btn = main._fullscreen_card_action_btn
	if btn == null:
		lines.append("SKIP  card-action : bouton non construit")
		return {"lines": lines, "pass": passed, "fail": failed}

	# Controlled state : RED controls AMBITION → can provoke Népotisme there.
	var s := GameState.new()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	s.active_player = GameEnums.PlayerId.RED
	main.state = s
	main.manager = TurnManager.new(s, false)

	# Provoke : valid origin → button shown.
	main._fullscreen_card_binding = {"kind": "transgression", "tid": TransgressionData.T_NEPOTISME,
		"face": GameEnums.TransgressionFace.SCANDALE, "origin": GameEnums.DomainId.AMBITION}
	main._update_fullscreen_action_button()
	if btn.visible:
		passed += 1
		lines.append("PASS  card-action : « Provoquer » visible (provocable + origine valide)")
	else:
		failed += 1
		lines.append("FAIL  card-action : « Provoquer » devrait être visible")

	# No origin → hidden (the reported bug : unowned transgression + no origin).
	main._fullscreen_card_binding["origin"] = -1
	main._update_fullscreen_action_button()
	if not btn.visible:
		passed += 1
		lines.append("PASS  card-action : bouton masqué sans origine (non possédée)")
	else:
		failed += 1
		lines.append("FAIL  card-action : bouton devrait être masqué sans origine")

	return {"lines": lines, "pass": passed, "fail": failed}
