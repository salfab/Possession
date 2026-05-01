class_name GameRules
extends RefCounted
# Pure read-only legality / cost helpers. No mutation here.
# All "is X legal?" questions live here; ActionResolver applies the effects.

# --- Costs ------------------------------------------------------------------

static func transgression_scandal_cost(state: GameState, player: int, def_id: String) -> int:
	var def: Dictionary = TransgressionData.get_def(def_id)
	var cost: int = def.get("scandal_cost", 0)
	# Népotisme infamy: while the player controls Ambition, his first
	# Transgression of each Station costs 1 less, minimum 1.
	var owner_of_nep := state.transgression_owner(TransgressionData.T_NEPOTISME)
	if owner_of_nep == player:
		var nep_inst := state.find_transgression_instance(player, TransgressionData.T_NEPOTISME, GameEnums.TransgressionFace.INFAMIE)
		var controls_ambition := state.controller_of(GameEnums.DomainId.AMBITION) == player
		if nep_inst != null and controls_ambition and not state.nepotisme_used_this_station[player]:
			cost = max(1, cost - 1)
	return cost

static func entrave_cost(state: GameState, player: int, target_station: int) -> int:
	var base := 1 if target_station == state.current_station else 2
	if state.trafic_discount_pending.get(player, false):
		base = max(1, base - 1)
	return base

# --- Action legality --------------------------------------------------------

static func can_investir(state: GameState, player: int, d_id: int) -> bool:
	if state.available_corruption[player] < 1:
		return false
	if state.is_sealed(d_id) and state.domain(d_id).seal_owner != player:
		return false
	return true

static func can_exploiter(state: GameState, player: int, d_id: int) -> bool:
	if state.controller_of(d_id) != player:
		return false
	var d := state.domain(d_id)
	if player == GameEnums.PlayerId.RED and d.exploited_by_red_this_station:
		return false
	if player == GameEnums.PlayerId.BLUE and d.exploited_by_blue_this_station:
		return false
	return true

static func transgression_origin_options(player: int, def_id: String) -> Array:
	var def: Dictionary = TransgressionData.get_def(def_id)
	if def.get("origin_choice", false):
		return def.get("domain_requirement", []).duplicate()
	return [def.get("default_origin", 0)]

static func can_provoquer(state: GameState, player: int, def_id: String) -> bool:
	var def: Dictionary = TransgressionData.get_def(def_id)
	if def.is_empty():
		return false
	# Unique transgressions: nobody else owns it, and current player doesn't own it.
	var owner := state.transgression_owner(def_id)
	if owner != GameEnums.PlayerId.NONE:
		return false
	# Must control at least one of the required domains.
	var requirement: Array = def.get("domain_requirement", [])
	var controls_one := false
	for d_id in requirement:
		if state.controller_of(d_id) == player:
			controls_one = true
			break
	if not controls_one:
		return false
	# Must afford the (possibly discounted) Scandale cost.
	var cost := transgression_scandal_cost(state, player, def_id)
	if state.available_corruption[player] < cost:
		return false
	return true

static func can_amplifier(state: GameState, player: int, def_id: String) -> bool:
	var ti: GameState.TransgressionInstance = state.find_transgression_instance(player, def_id, GameEnums.TransgressionFace.SCANDALE)
	if ti == null:
		return false
	var origin: int = ti.origin_domain
	var d := state.domain(origin)
	if d.seal_owner != player:
		return false
	if state.is_in_penitence(origin):
		return false
	var def: Dictionary = TransgressionData.get_def(def_id)
	var cost: int = def.get("amplification_cost", 0)
	if state.available_corruption[player] < cost:
		return false
	return true

static func can_sceller(state: GameState, player: int, d_id: int) -> bool:
	if state.is_sealed(d_id):
		return false
	var d := state.domain(d_id)
	if d.cannot_be_sealed_until_exorcism and state.current_station < GameEnums.StationId.EXORCISME:
		return false
	if state.is_in_penitence(d_id):
		return false
	if state.controller_of(d_id) != player:
		return false
	if not state.has_net_domination(d_id, player):
		return false
	if state.available_corruption[player] < 1:
		return false
	return true

static func can_fissurer(state: GameState, player: int, d_id: int) -> bool:
	var d := state.domain(d_id)
	if d.seal_owner == GameEnums.PlayerId.NONE:
		return false
	if d.seal_owner == player:
		return false  # cannot fissure your own seal
	var cost := fissurer_total_cost(state, player, d_id)
	if state.available_corruption[player] < cost:
		return false
	return true

# Returns the total Corruption cost of a fissure, including Tribut de Volonté if applicable.
static func fissurer_total_cost(state: GameState, player: int, d_id: int) -> int:
	var cost := 1
	if d_id == GameEnums.DomainId.VOLONTE and state.is_sealed(d_id) and state.is_transgressed(d_id):
		var owner := state.domain(d_id).seal_owner
		if owner != player:
			cost += 1  # Tribut de Volonté
	return cost

static func can_entraver(state: GameState, player: int, target_station: int) -> bool:
	if target_station == GameEnums.StationId.EXORCISME:
		return false  # Exorcism cannot be entraved.
	if target_station < state.current_station:
		return false
	if target_station > state.current_station + 2:
		return false
	# Already entraved?
	for pe in state.pending_entraves:
		if pe.target_station == target_station:
			return false
	var cost := entrave_cost(state, player, target_station)
	if state.available_corruption[player] < cost:
		return false
	return true

static func is_response_entraved(state: GameState, station: int) -> bool:
	for pe in state.pending_entraves:
		if pe.target_station == station:
			return true
	return false


# --- Reasons (why an action is illegal — empty string means it's legal) -----

static func why_cannot_investir(state: GameState, player: int, d_id: int) -> String:
	if state.available_corruption[player] < 1:
		return I18n.t("err.no_corruption")
	if state.is_sealed(d_id) and state.domain(d_id).seal_owner != player:
		return I18n.t("err.sealed_by_opponent")
	return ""


static func why_cannot_exploiter(state: GameState, player: int, d_id: int) -> String:
	if state.controller_of(d_id) != player:
		return I18n.t("err.not_controlled")
	var d := state.domain(d_id)
	if player == GameEnums.PlayerId.RED and d.exploited_by_red_this_station:
		return I18n.t("err.already_exploited")
	if player == GameEnums.PlayerId.BLUE and d.exploited_by_blue_this_station:
		return I18n.t("err.already_exploited")
	return ""


static func why_cannot_sceller(state: GameState, player: int, d_id: int) -> String:
	if state.is_sealed(d_id):
		return I18n.t("err.already_sealed")
	var d := state.domain(d_id)
	if d.cannot_be_sealed_until_exorcism and state.current_station < GameEnums.StationId.EXORCISME:
		return I18n.t("err.seal_forbidden_until_exorcism")
	if state.is_in_penitence(d_id):
		return I18n.t("err.in_penitence")
	if state.controller_of(d_id) != player:
		return I18n.t("err.not_controlled")
	if not state.has_net_domination(d_id, player):
		return I18n.t("err.need_net_domination")
	if state.available_corruption[player] < 1:
		return I18n.t("err.no_corruption")
	return ""


static func why_cannot_fissurer(state: GameState, player: int, d_id: int) -> String:
	var d := state.domain(d_id)
	if d.seal_owner == GameEnums.PlayerId.NONE:
		return I18n.t("err.not_sealed")
	if d.seal_owner == player:
		return I18n.t("err.cannot_fissure_own")
	var cost := fissurer_total_cost(state, player, d_id)
	if state.available_corruption[player] < cost:
		return I18n.t("err.not_enough_corruption", [cost])
	return ""


static func why_cannot_provoquer(state: GameState, player: int, def_id: String) -> String:
	var def: Dictionary = TransgressionData.get_def(def_id)
	if def.is_empty():
		return I18n.t("err.unknown_transgression")
	var owner := state.transgression_owner(def_id)
	if owner != GameEnums.PlayerId.NONE:
		return I18n.t("err.already_owned_by", [GameEnums.player_name(owner)])
	var requirement: Array = def.get("domain_requirement", [])
	var controls_one := false
	for d_id in requirement:
		if state.controller_of(d_id) == player:
			controls_one = true
			break
	if not controls_one:
		var names := ""
		var sep: String = I18n.t("glue.or")
		for d_id in requirement:
			if names != "":
				names += sep
			names += GameEnums.DOMAIN_NAMES[d_id]
		return I18n.t("err.must_control_one_of", [names])
	var cost := transgression_scandal_cost(state, player, def_id)
	if state.available_corruption[player] < cost:
		return I18n.t("err.not_enough_corruption", [cost])
	return ""


static func why_cannot_amplifier(state: GameState, player: int, def_id: String) -> String:
	var ti: GameState.TransgressionInstance = state.find_transgression_instance(player, def_id, GameEnums.TransgressionFace.SCANDALE)
	if ti == null:
		return I18n.t("err.no_scandale_owned")
	var origin: int = ti.origin_domain
	var d := state.domain(origin)
	if d.seal_owner != player:
		return I18n.t("err.origin_not_sealed", [GameEnums.DOMAIN_NAMES[origin]])
	if state.is_in_penitence(origin):
		return I18n.t("err.origin_in_penitence", [GameEnums.DOMAIN_NAMES[origin]])
	var def: Dictionary = TransgressionData.get_def(def_id)
	var cost: int = def.get("amplification_cost", 0)
	if state.available_corruption[player] < cost:
		return I18n.t("err.not_enough_corruption", [cost])
	return ""


# Last-resort safety net so a player with an empty Corruption pool isn't
# soft-locked into Passer for the rest of the Station. Only legal when the
# active player's Réserve is at 0 — gaining Corruption normally has to come
# from Exploiter / Provoquer side effects.
static func can_puiser(state: GameState, player: int) -> bool:
	return state.available_corruption[player] == 0


static func why_cannot_puiser(state: GameState, player: int) -> String:
	if state.available_corruption[player] > 0:
		return I18n.t("err.puiser_only_when_empty")
	return ""


# --- Misc helpers -----------------------------------------------------------

static func production_of(state: GameState, d_id: int, player: int) -> int:
	var base := 0
	match d_id:
		GameEnums.DomainId.AMBITION:
			base = 2
		GameEnums.DomainId.DESIR:
			base = 3 if state.is_transgressed(d_id) else 2
		GameEnums.DomainId.FOI:
			base = 2 if state.is_transgressed(d_id) else 1
		GameEnums.DomainId.PEUR:
			var any_fissured := false
			for did in DomainData.DOMAINS:
				if state.domain(did).was_fissured_this_station:
					any_fissured = true
					break
			base = 2 if any_fissured else 1
		GameEnums.DomainId.VOLONTE:
			base = 0
	# Self-sealed bonus
	if state.is_sealed(d_id) and state.domain(d_id).seal_owner == player:
		base += 1
	# Festin obscène infamy: +1 when exploiting Désir.
	if d_id == GameEnums.DomainId.DESIR:
		var owner := state.transgression_owner(TransgressionData.T_FESTIN)
		if owner == player:
			var ti := state.find_transgression_instance(player, TransgressionData.T_FESTIN, GameEnums.TransgressionFace.INFAMIE)
			if ti != null:
				base += 1
	return base
