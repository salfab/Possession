class_name HeuristicBot
extends BotBase

func pick_action(state: GameState, player: int) -> Dictionary:
	var actions := ActionEnumerator.list(state, player)
	if actions.is_empty():
		return {"action_id": GameEnums.ActionId.PASSER, "kwargs": {}}
	var best_action: Dictionary = actions[0]
	var best_score := -999.0
	for action in actions:
		var clone := _apply_action(state, player, action)
		var s := Eval.score(clone, player)
		if s > best_score:
			best_score = s
			best_action = action
	return best_action


func _apply_action(state: GameState, player: int, action: Dictionary) -> GameState:
	var clone := GameState.new()
	clone.from_dict(state.to_dict())
	var action_id: int = action["action_id"]
	var kwargs: Dictionary = action.get("kwargs", {})
	match action_id:
		GameEnums.ActionId.INVESTIR:
			ActionResolver.investir(clone, player, kwargs.get("domain", -1))
		GameEnums.ActionId.EXPLOITER:
			ActionResolver.exploiter(clone, player, kwargs.get("domain", -1))
		GameEnums.ActionId.PROVOQUER:
			var extra: Dictionary = {}
			for key in ["target_domain", "from_domain", "to_domain", "target_station"]:
				if kwargs.has(key):
					extra[key] = kwargs[key]
			ActionResolver.provoquer(clone, player, kwargs.get("def_id", ""), kwargs.get("origin", -1), extra)
		GameEnums.ActionId.AMPLIFIER:
			ActionResolver.amplifier(clone, player, kwargs.get("def_id", ""))
		GameEnums.ActionId.SCELLER:
			ActionResolver.sceller(clone, player, kwargs.get("domain", -1))
		GameEnums.ActionId.FISSURER:
			ActionResolver.fissurer(clone, player, kwargs.get("domain", -1))
		GameEnums.ActionId.ENTRAVER:
			ActionResolver.entraver(clone, player, kwargs.get("station", -1), kwargs.get("payment_domain", -1))
		GameEnums.ActionId.PASSER:
			ActionResolver.passer(clone, player)
		GameEnums.ActionId.PUISER:
			ActionResolver.puiser(clone, player)
	return clone
