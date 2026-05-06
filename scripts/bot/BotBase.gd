class_name BotBase
extends RefCounted

func pick_action(state: GameState, player: int) -> Dictionary:
	push_error("BotBase.pick_action must be overridden")
	return {}
