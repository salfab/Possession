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

	for def_id in TransgressionData.ALL_IDS:
		if GameRules.can_provoquer(state, player, def_id):
			var def: Dictionary = TransgressionData.CATALOG.get(def_id, {})
			if def.get("origin_choice", false):
				for d_id in def.get("domain_requirement", []):
					if state.controller_of(d_id) == player:
						actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": {"def_id": def_id, "origin": d_id}})
			else:
				actions.append({"action_id": GameEnums.ActionId.PROVOQUER, "kwargs": {"def_id": def_id, "origin": -1}})

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
