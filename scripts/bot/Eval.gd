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
	var domination_diff := 0
	var sealed_diff := 0
	var infamy_diff := 0    # infamies > scandals: AMPLIFIER is always net positive
	var scandal_diff := 0
	var transgressed_count := 0  # Étendue progress (shared)

	for d_id in DomainData.DOMAINS:
		var ctrl := state.controller_of(d_id)
		if ctrl == player:
			ctrl_diff += 1
		elif ctrl == opp:
			ctrl_diff -= 1
		if state.has_net_domination(d_id, player):
			domination_diff += 1
		elif state.has_net_domination(d_id, opp):
			domination_diff -= 1
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
		for ti in state.domain(d_id).scandals:
			if ti.owner == player:
				scandal_diff += 1
			elif ti.owner == opp:
				scandal_diff -= 1
		if state.is_transgressed(d_id):
			transgressed_count += 1

	var corr_lead := float(state.available_corruption.get(player, 0) - state.available_corruption.get(opp, 0))

	# Rupture is the gate to any win — reward each condition met with a large bonus.
	# Symmetric but effective: completing a condition jumps this term by ~0.07,
	# far exceeding the marginal value of any other single action.
	var rupture := EndGameResolver.check_rupture(state)
	var rupture_conditions: float = float(
		(1 if rupture.profondeur else 0)
		+ (1 if rupture.etendue else 0)
		+ (1 if rupture.ancrage else 0))

	var s: float = (
		0.30 * tanh(rupture_conditions / 1.5)
		+ 0.12 * tanh(asc_signed / 5.0)
		+ 0.08 * tanh(float(ctrl_diff) / 5.0)
		+ 0.08 * tanh(float(domination_diff) / 3.0)
		+ 0.15 * tanh(float(sealed_diff) / 4.0)
		+ 0.15 * tanh(float(infamy_diff) / 4.0)
		+ 0.06 * tanh(float(scandal_diff) / 4.0)
		+ 0.05 * tanh(float(transgressed_count) / 4.0)
		+ 0.01 * tanh(corr_lead / 8.0)
	)
	return clampf(s, -1.0, 1.0)
