extends RefCounted
# Headless check of the transgression card's contextual action button
# (Provoquer / Amplifier). Lives in its own class loaded via load() from
# run_ui_tests.gd : a script run directly as `--script` does NOT resolve autoload
# identifiers (GameEnums / TransgressionData) in its own body, but a load()'d
# class DOES — same reason RulesTestRunner can use them. Takes the already-built
# Main instance and returns {lines, pass, fail}.
#
# Phase 2 : the button is no longer hidden when the action is unavailable — it
# stays visible but greyed (modulate < 1) and tappable, exposing the reason via
# `_fullscreen_action_reason` (delivered as a toast on tap). It is hidden ONLY
# when there is no action to offer at all (no Scandale owned + no origin).

func check(main) -> Dictionary:
	var lines: Array = []
	var passed := 0
	var failed := 0
	var btn = main._fullscreen_card_action_btn
	if btn == null:
		lines.append("SKIP  card-action : bouton non construit")
		return {"lines": lines, "pass": passed, "fail": failed}

	# 1. Provoke with a valid origin → button shown and ACTIVE (no reason).
	var s := GameState.new()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	s.active_player = GameEnums.PlayerId.RED
	main.state = s
	main.manager = TurnManager.new(s, false)
	main._fullscreen_card_binding = {"kind": "transgression", "tid": TransgressionData.T_NEPOTISME,
		"face": GameEnums.TransgressionFace.SCANDALE, "origin": GameEnums.DomainId.AMBITION}
	main._update_fullscreen_action_button()
	if btn.visible and main._fullscreen_action_kind == "provoke" and main._fullscreen_action_reason == "":
		passed += 1
		lines.append("PASS  card-action : « Provoquer » actif (provocable + origine valide)")
	else:
		failed += 1
		lines.append("FAIL  card-action : « Provoquer » devrait être actif")

	# 2. No origin and no Scandale owned → hidden (no action to offer).
	main._fullscreen_card_binding["origin"] = -1
	main._update_fullscreen_action_button()
	if not btn.visible:
		passed += 1
		lines.append("PASS  card-action : bouton masqué sans origine ni Scandale possédé")
	else:
		failed += 1
		lines.append("FAIL  card-action : bouton devrait être masqué")

	# 3. Provoke UNAVAILABLE (controls origin but can't afford) → visible, greyed,
	#    with a reason (the touch-friendly tap-to-explain state).
	var s2 := GameState.new()
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s2.available_corruption[GameEnums.PlayerId.RED] = 0
	s2.active_player = GameEnums.PlayerId.RED
	main.state = s2
	main.manager = TurnManager.new(s2, false)
	main._fullscreen_card_binding = {"kind": "transgression", "tid": TransgressionData.T_NEPOTISME,
		"face": GameEnums.TransgressionFace.SCANDALE, "origin": GameEnums.DomainId.AMBITION}
	main._update_fullscreen_action_button()
	if btn.visible and main._fullscreen_action_kind == "provoke" and main._fullscreen_action_reason != "" \
			and btn.modulate.a < 1.0:
		passed += 1
		lines.append("PASS  card-action : « Provoquer » grisé + raison quand indisponible (Corruption)")
	else:
		failed += 1
		lines.append("FAIL  card-action : « Provoquer » devrait être grisé avec une raison")

	# 4. Amplify UNAVAILABLE (owns the Scandale but origin not sealed) → greyed + reason.
	var s3 := GameState.new()
	s3.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s3.available_corruption[GameEnums.PlayerId.RED] = 10
	s3.active_player = GameEnums.PlayerId.RED
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_NEPOTISME
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.AMBITION
	s3.domain(GameEnums.DomainId.AMBITION).scandals.append(ti)
	main.state = s3
	main.manager = TurnManager.new(s3, false)
	main._fullscreen_card_binding = {"kind": "transgression", "tid": TransgressionData.T_NEPOTISME,
		"face": GameEnums.TransgressionFace.SCANDALE, "origin": -1}
	main._update_fullscreen_action_button()
	if btn.visible and main._fullscreen_action_kind == "amplify" and main._fullscreen_action_reason != "":
		passed += 1
		lines.append("PASS  card-action : « Amplifier » grisé + raison quand origine non scellée")
	else:
		failed += 1
		lines.append("FAIL  card-action : « Amplifier » devrait être grisé avec une raison")

	return {"lines": lines, "pass": passed, "fail": failed}
