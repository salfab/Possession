class_name Eval
extends RefCounted

static func score(state: GameState, player: int) -> float:
	if state.game_over:
		if state.winner == player:
			return 1.0
		if state.winner == GameEnums.PlayerId.NONE:
			return 0.0
		return -1.0

	var opp := GameEnums.opponent(player)

	var asc_signed := float(state.ascendant) if player == GameEnums.PlayerId.RED else float(-state.ascendant)

	var ctrl_diff := 0
	var sealed_diff := 0
	var infamy_diff := 0
	for d_id in DomainData.DOMAINS:
		var ctrl := state.controller_of(d_id)
		if ctrl == player:
			ctrl_diff += 1
		elif ctrl == opp:
			ctrl_diff -= 1
		var seal := state.domain(d_id).seal_owner
		if seal == player:
			sealed_diff += 1
		elif seal == opp:
			sealed_diff -= 1
		for ti in state.domain(d_id).infamies:
			if ti.owner == player:
				infamy_diff += 1
			elif ti.owner == opp:
				infamy_diff -= 1

	var corr_lead := float(state.available_corruption.get(player, 0) - state.available_corruption.get(opp, 0))

	var s: float = (
		0.30 * tanh(asc_signed / 5.0)
		+ 0.25 * tanh(float(ctrl_diff) / 5.0)
		+ 0.20 * tanh(float(sealed_diff) / 5.0)
		+ 0.15 * tanh(float(infamy_diff) / 4.0)
		+ 0.10 * tanh(corr_lead / 8.0)
	)
	return clampf(s, -1.0, 1.0)
