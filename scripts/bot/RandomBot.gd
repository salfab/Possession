class_name RandomBot
extends BotBase

func pick_action(state: GameState, player: int) -> Dictionary:
	var actions := ActionEnumerator.list(state, player)
	if actions.is_empty():
		return {"action_id": GameEnums.ActionId.PASSER, "kwargs": {}}
	return actions[randi() % actions.size()]
