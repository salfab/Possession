class_name EndGameResolver
extends RefCounted
# Handles the Rupture de l'âme check, Fiat Tenebris and Ascendant tie-breakers.

class RuptureReport extends RefCounted:
	var profondeur: bool = false
	var etendue: bool = false
	var ancrage: bool = false
	var complete: bool = false


static func check_rupture(state: GameState) -> RuptureReport:
	var r := RuptureReport.new()
	# Profondeur
	var infamies_total := state.count_total_infamies()
	var foi_inf := state.domain(GameEnums.DomainId.FOI).infamies.size() > 0
	var vol_inf := state.domain(GameEnums.DomainId.VOLONTE).infamies.size() > 0
	r.profondeur = infamies_total >= 3 or foi_inf or vol_inf
	# Étendue
	r.etendue = state.count_transgressed_domains() >= 4
	# Ancrage
	var sealed_count := state.count_sealed_domains()
	var vol_sealed := state.is_sealed(GameEnums.DomainId.VOLONTE)
	var vol_transg := state.is_transgressed(GameEnums.DomainId.VOLONTE)
	r.ancrage = sealed_count >= 2 or (vol_sealed and vol_transg)
	r.complete = r.profondeur and r.etendue and r.ancrage
	return r

static func check_fiat_tenebris(state: GameState) -> int:
	# Returns the winning PlayerId or NONE.
	var d := state.domain(GameEnums.DomainId.VOLONTE)
	if d.seal_owner == GameEnums.PlayerId.NONE:
		return GameEnums.PlayerId.NONE
	if not state.is_transgressed(GameEnums.DomainId.VOLONTE):
		return GameEnums.PlayerId.NONE
	var sealer := d.seal_owner
	# Volonté must be transgressed by the same demon who sealed it.
	for ti in d.scandals:
		if ti.owner == sealer:
			return sealer
	for ti in d.infamies:
		if ti.owner == sealer:
			return sealer
	return GameEnums.PlayerId.NONE

# Apply final ascendant bonuses, mutates state.ascendant.
static func apply_final_ascendant_bonuses(state: GameState) -> void:
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		if d.seal_owner == GameEnums.PlayerId.RED:
			state.ascendant += 1
		elif d.seal_owner == GameEnums.PlayerId.PURPLE:
			state.ascendant -= 1
		# Volonté sealed bonus
		if d_id == GameEnums.DomainId.VOLONTE:
			if d.seal_owner == GameEnums.PlayerId.RED:
				state.ascendant += 1
			elif d.seal_owner == GameEnums.PlayerId.PURPLE:
				state.ascendant -= 1
		# Infamies in a domain controlled by you
		var ctrl := state.controller_of(d_id)
		if ctrl != GameEnums.PlayerId.NONE:
			for ti in d.infamies:
				if ti.owner == ctrl:
					state.ascendant += (1 if ctrl == GameEnums.PlayerId.RED else -1)
		# Foi infamy you possess: extra +1 (Buff Foi)
		if d_id == GameEnums.DomainId.FOI:
			for ti in d.infamies:
				state.ascendant += (1 if ti.owner == GameEnums.PlayerId.RED else -1)
		# Pacte silencieux infamy: +1 if controller of Volonté
		if d_id == GameEnums.DomainId.VOLONTE:
			for ti in d.infamies:
				if ti.def_id == TransgressionData.T_PACTE:
					if state.controller_of(GameEnums.DomainId.VOLONTE) == ti.owner:
						state.ascendant += (1 if ti.owner == GameEnums.PlayerId.RED else -1)
				if ti.def_id == TransgressionData.T_ABDICATION:
					if state.is_sealed(GameEnums.DomainId.VOLONTE) and state.domain(GameEnums.DomainId.VOLONTE).seal_owner == ti.owner:
						state.ascendant += (1 if ti.owner == GameEnums.PlayerId.RED else -1)


static func resolve_ascendant_winner(state: GameState) -> Dictionary:
	apply_final_ascendant_bonuses(state)
	if state.ascendant > 0:
		return {"winner": GameEnums.PlayerId.RED, "reason": "Ascendant final favorable à Rouge."}
	if state.ascendant < 0:
		return {"winner": GameEnums.PlayerId.PURPLE, "reason": "Ascendant final favorable à Bleu."}
	# Zero ascendant tie-breakers
	var vol := state.domain(GameEnums.DomainId.VOLONTE)
	if vol.seal_owner != GameEnums.PlayerId.NONE:
		return {"winner": vol.seal_owner, "reason": "Égalité d'Ascendant : Volonté scellée par le vainqueur."}
	var ctrl := state.controller_of(GameEnums.DomainId.VOLONTE)
	if ctrl != GameEnums.PlayerId.NONE:
		return {"winner": ctrl, "reason": "Égalité d'Ascendant : contrôle de Volonté."}
	# Most infamies
	var red_inf := 0
	var blue_inf := 0
	for d_id in DomainData.DOMAINS:
		for ti in state.domain(d_id).infamies:
			if ti.owner == GameEnums.PlayerId.RED:
				red_inf += 1
			elif ti.owner == GameEnums.PlayerId.PURPLE:
				blue_inf += 1
	if red_inf > blue_inf:
		return {"winner": GameEnums.PlayerId.RED, "reason": "Égalité d'Ascendant : plus d'Infamies pour Rouge."}
	if blue_inf > red_inf:
		return {"winner": GameEnums.PlayerId.PURPLE, "reason": "Égalité d'Ascendant : plus d'Infamies pour Bleu."}
	# Most domains controlled
	var red_ctrl := 0
	var blue_ctrl := 0
	for d_id in DomainData.DOMAINS:
		var c := state.controller_of(d_id)
		if c == GameEnums.PlayerId.RED:
			red_ctrl += 1
		elif c == GameEnums.PlayerId.PURPLE:
			blue_ctrl += 1
	if red_ctrl > blue_ctrl:
		return {"winner": GameEnums.PlayerId.RED, "reason": "Égalité d'Ascendant : plus de Domaines contrôlés par Rouge."}
	if blue_ctrl > red_ctrl:
		return {"winner": GameEnums.PlayerId.PURPLE, "reason": "Égalité d'Ascendant : plus de Domaines contrôlés par Bleu."}
	return {"winner": GameEnums.PlayerId.NONE, "reason": "Possession instable — aucun gagnant."}


static func resolve_final_exorcism(state: GameState) -> Dictionary:
	# Returns: { outcome: "pope_saved" | "demon_wins", winner, reason, rupture: RuptureReport }
	var rupture := check_rupture(state)
	if not rupture.complete:
		state.add_log("L'Exorcisme final RÉUSSIT — le pape est sauvé. Les démons perdent.")
		state.game_over = true
		state.winner = GameEnums.PlayerId.NONE
		state.winner_reason = "Exorcisme réussi (Rupture incomplète)."
		return {"outcome": "pope_saved", "winner": GameEnums.PlayerId.NONE, "reason": state.winner_reason, "rupture": rupture}
	state.add_log("L'Exorcisme final ÉCHOUE — la Rupture de l'âme est complète.")
	# Fiat Tenebris check
	var fiat := check_fiat_tenebris(state)
	if fiat != GameEnums.PlayerId.NONE:
		state.add_log("FIAT TENEBRIS — %s possède immédiatement le pape." % GameEnums.player_name(fiat))
		state.game_over = true
		state.winner = fiat
		state.winner_reason = "Fiat Tenebris : Volonté scellée et transgressée par le même démon."
		return {"outcome": "demon_wins", "winner": fiat, "reason": state.winner_reason, "rupture": rupture}
	# Otherwise resolve Ascendant.
	var res := resolve_ascendant_winner(state)
	state.game_over = true
	state.winner = res["winner"]
	state.winner_reason = res["reason"]
	state.add_log("Départage final : %s. %s" % [GameEnums.player_name(state.winner), state.winner_reason])
	return {"outcome": "demon_wins", "winner": state.winner, "reason": state.winner_reason, "rupture": rupture}
