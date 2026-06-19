class_name ActionEnumerator
extends RefCounted

static func list(state: GameState, player: int) -> Array:
	var actions: Array = []

	for d_id in DomainData.DOMAINS:
		if GameRules.can_investir(state, player, d_id):
			actions.append({"action_id": GameEnums.ActionId.INVESTIR, "kwargs": {"domain": d_id}})

	for d_id in DomainData.DOMAINS:
		if GameRules.can_exploiter(state, player, d_id):
			actions.append({"action_id": GameEnums.ActionId.EXPLOITER, "kwargs": {"domain": d_id}})

	# Transgression pool: codex filters to codex_available when active, else V1h set.
	var trans_ids: Array
	if state.codex_of_transgressions_enabled:
		trans_ids = state.codex_available
	else:
		trans_ids = TransgressionData.ALL_IDS

	for def_id in trans_ids:
		if not GameRules.can_provoquer(state, player, def_id):
			continue
		var def: Dictionary = TransgressionData.CATALOG.get(def_id, {})
		if def.get("origin_choice", false):
			# Cards with origin choice (e.g. Simonie): one action per controlled requirement domain.
			for d_id in def.get("domain_requirement", []):
				if state.controller_of(d_id) == player:
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": {"def_id": def_id, "origin": d_id}})
		else:
			var base: Dictionary = {"def_id": def_id, "origin": -1}
			_append_provoquer_variants(state, player, def_id, base, actions)

	for d_id in DomainData.DOMAINS:
		for ti in state.domain(d_id).scandals:
			if ti.owner == player and GameRules.can_amplifier(state, player, ti.def_id):
				actions.append({"action_id": GameEnums.ActionId.AMPLIFIER, "kwargs": {"def_id": ti.def_id}})

	for d_id in DomainData.DOMAINS:
		if GameRules.can_sceller(state, player, d_id):
			actions.append({"action_id": GameEnums.ActionId.SCELLER, "kwargs": {"domain": d_id}})

	for d_id in DomainData.DOMAINS:
		if GameRules.can_fissurer(state, player, d_id):
			actions.append({"action_id": GameEnums.ActionId.FISSURER, "kwargs": {"domain": d_id}})

	for offset in range(3):
		var target: int = state.current_station + offset
		if target > GameEnums.StationId.EXORCISME:
			break
		if GameRules.can_entraver(state, player, target):
			for pd in GameRules.entrave_payment_options(state, player, target):
				actions.append({"action_id": GameEnums.ActionId.ENTRAVER, "kwargs": {"station": target, "payment_domain": pd}})

	actions.append({"action_id": GameEnums.ActionId.PASSER, "kwargs": {}})

	if GameRules.can_puiser(state, player):
		actions.append({"action_id": GameEnums.ActionId.PUISER, "kwargs": {}})

	return actions


# Append PROVOQUER action variants for cards that need secondary choices.
static func _append_provoquer_variants(state: GameState, player: int, def_id: String, base: Dictionary, actions: Array) -> void:
	var opp: int = GameEnums.opponent(player)
	match def_id:
		TransgressionData.T_INTRIGUE:
			# One variant per domain (opponent loses 1 corruption there, or +1 to self if none).
			for d_id in DomainData.DOMAINS:
				var k: Dictionary = base.duplicate()
				k["target_domain"] = d_id
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})

		TransgressionData.T_MASCARADE:
			# Move 1 corruption: from_domain × to_domain where player has ≥1 in from.
			var added: bool = false
			for fd in DomainData.DOMAINS:
				if state.corruption_in(fd, player) < 1:
					continue
				for td in DomainData.DOMAINS:
					if td == fd:
						continue
					var k: Dictionary = base.duplicate()
					k["from_domain"] = fd
					k["to_domain"] = td
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})
					added = true
			if not added:
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})

		TransgressionData.T_DOGME:
			# Free entrave on current+1 or current+2 (not already entraved, not Exorcisme).
			var added_d: bool = false
			for offset in [1, 2]:
				var ts: int = state.current_station + offset
				if ts > GameEnums.StationId.OFFICE:
					break
				if not GameRules.is_response_entraved(state, ts):
					var k: Dictionary = base.duplicate()
					k["target_station"] = ts
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})
					added_d = true
			if not added_d:
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})

		TransgressionData.T_DENONCIATION:
			# One variant per domain (blocks opponent's exploitation of that domain).
			for d_id in DomainData.DOMAINS:
				var k: Dictionary = base.duplicate()
				k["target_domain"] = d_id
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})

		TransgressionData.T_PANIQUE:
			# Prefer contested domains; fall back to any domain.
			var contested: Array = []
			for d_id in DomainData.DOMAINS:
				if state.is_contested(d_id):
					contested.append(d_id)
			if contested.is_empty():
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})
			else:
				for d_id in contested:
					var k: Dictionary = base.duplicate()
					k["target_domain"] = d_id
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})

		TransgressionData.T_PERSECUTION:
			# One variant per contested domain where the opponent has ≥1 corruption.
			var added_per: bool = false
			for d_id in DomainData.DOMAINS:
				if state.is_contested(d_id) and state.corruption_in(d_id, opp) >= 1:
					var k: Dictionary = base.duplicate()
					k["target_domain"] = d_id
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})
					added_per = true
			if not added_per:
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})

		TransgressionData.T_RENONCEMENT:
			# One variant per domain where opponent has ≥1 corruption.
			var added_r: bool = false
			for d_id in DomainData.DOMAINS:
				if state.corruption_in(d_id, opp) >= 1:
					var k: Dictionary = base.duplicate()
					k["target_domain"] = d_id
					actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": k})
					added_r = true
			if not added_r:
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})

		_:
			# No secondary choice needed.
			actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": base.duplicate()})
