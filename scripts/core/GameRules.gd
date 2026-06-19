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

# V1h : Entrave is positional, not reserve-based. The cost is always
# "remove 1 of your Corruptions from a controlled, linked Domain on the
# board" — there is no scaling with target_station distance and the
# active demon's available_corruption pool isn't touched. Kept the helper
# so legacy UI / log paths still resolve a number, but the value is now
# fixed at 1 (the Domain board cost) and the trafic discount no longer
# applies (the V1h cost cannot be reduced — there's no reserve to discount).
static func entrave_cost(_state: GameState, _player: int, _target_station: int) -> int:
	return 1

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
	if player == GameEnums.PlayerId.PURPLE and d.exploited_by_blue_this_station:
		return false
	# Dénonciation anonyme: scandale blocks a domain for opponent this station;
	# infamy permanently blocks origin domain.
	var opp: int = GameEnums.opponent(player)
	if state.denonciation_blocked_domain.get(opp, -1) == d_id:
		return false
	var den_owner: int = state.transgression_owner(TransgressionData.T_DENONCIATION)
	if den_owner != GameEnums.PlayerId.NONE and den_owner != player:
		var den_ti: GameState.TransgressionInstance = state.find_transgression_instance(den_owner, TransgressionData.T_DENONCIATION, GameEnums.TransgressionFace.INFAMIE)
		if den_ti != null and den_ti.origin_domain == d_id:
			return false
	return true

static func transgression_origin_options(state: GameState, player: int, def_id: String) -> Array:
	var def: Dictionary = TransgressionData.get_def(def_id)
	if def.get("origin_choice", false):
		# Only the required domains the player can actually provoke from (controls,
		# or qualifies via the Appétit presence power) — never the opponent's.
		var out: Array = []
		for d_id in def.get("domain_requirement", []):
			if can_provoke_from_domain(state, player, d_id):
				out.append(d_id)
		return out
	return [def.get("default_origin", 0)]

static func can_provoquer(state: GameState, player: int, def_id: String) -> bool:
	var def: Dictionary = TransgressionData.get_def(def_id)
	if def.is_empty():
		return false
	# Unique transgressions: nobody else owns it, and current player doesn't own it.
	var owner := state.transgression_owner(def_id)
	if owner != GameEnums.PlayerId.NONE:
		return false
	# Must be able to provoke from at least one required domain — by controlling
	# it, or via the Appétit hérétique (Infamie) presence power.
	var requirement: Array = def.get("domain_requirement", [])
	var qualifies := false
	for d_id in requirement:
		if can_provoke_from_domain(state, player, d_id):
			qualifies = true
			break
	if not qualifies:
		return false
	# Must afford the (possibly discounted) Scandale cost.
	var cost := transgression_scandal_cost(state, player, def_id)
	if state.available_corruption[player] < cost:
		return false
	return true

# A player may provoke a Transgression *from* domain `d_id` when they control it,
# OR via the Appétit hérétique (Infamie) power : while they control Désir, once
# per Station, they may provoke from a domain where they merely hold ≥1
# Corruption, provided the opponent hasn't sealed it. Mirrors the card text.
static func can_provoke_from_domain(state: GameState, player: int, d_id: int) -> bool:
	if state.controller_of(d_id) == player:
		return true
	# Off-control provoke via Appétit hérétique — two sources, same guards :
	#   • Infamie : permanent, but once per Station (appetit_offcontrol_used).
	#   • Scandale : a one-shot armed for the very next Transgression.
	var has_infamy: bool = state.find_transgression_instance(player, TransgressionData.T_APPETIT, GameEnums.TransgressionFace.INFAMIE) != null
	var infamy_path: bool = has_infamy and not state.appetit_offcontrol_used_this_station.get(player, false)
	var scandale_path: bool = state.appetit_scandale_armed.get(player, false)
	if not infamy_path and not scandale_path:
		return false
	if state.controller_of(GameEnums.DomainId.DESIR) != player:
		return false
	if state.corruption_in(d_id, player) < 1:
		return false
	var d := state.domain(d_id)
	if d != null and d.seal_owner == GameEnums.opponent(player):
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
	# Intrigue du Consistoire : can seal without net domination via either —
	#   • the Infamy (permanently, for its origin Domain), or
	#   • the Scandale (this Station only, for the chosen granted Domain).
	var intrigue_ti: GameState.TransgressionInstance = state.find_transgression_instance(player, TransgressionData.T_INTRIGUE, GameEnums.TransgressionFace.INFAMIE)
	var intrigue_bypass: bool = (intrigue_ti != null and intrigue_ti.origin_domain == d_id) \
		or state.intrigue_seal_grant.get(player, -1) == d_id
	if not intrigue_bypass and not state.has_net_domination(d_id, player):
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

# V1h : returns the list of Domain ids "linked" to a Liturgical Response.
# Used by the Entrave action — to Hinder a Response, the active demon
# must remove 1 of his Corruptions from one of these linked Domains
# that he ALSO controls. Mirrors the rules card per Station :
#   I (Signe de croix)        : every Domain.
#   II (Examen de conscience) : Ambition + Désir.
#   III (Contrition)          : the currently-transgressed Domains.
#   IV (Confession)           : the origin Domains of the active demon's
#                               own placed Transgressions.
#   V (Communion)             : Foi + Volonté.
#   VI (Exorcisme final)      : none — the Exorcism cannot be Hindered.
static func linked_domains_for_response(state: GameState, station: int, player: int) -> Array:
	match station:
		GameEnums.StationId.MURMURES:
			return DomainData.DOMAINS.duplicate()
		GameEnums.StationId.TENTATION:
			return [GameEnums.DomainId.AMBITION, GameEnums.DomainId.DESIR]
		GameEnums.StationId.CHUTE:
			var transgressed: Array = []
			for d_id in DomainData.DOMAINS:
				if state.is_transgressed(d_id):
					transgressed.append(d_id)
			return transgressed
		GameEnums.StationId.CONFESSION:
			var origins: Dictionary = {}
			for d_id in DomainData.DOMAINS:
				var d := state.domain(d_id)
				for ti in d.scandals + d.infamies:
					if ti.owner == player:
						origins[ti.origin_domain] = true
			return origins.keys()
		GameEnums.StationId.OFFICE:
			return [GameEnums.DomainId.FOI, GameEnums.DomainId.VOLONTE]
		GameEnums.StationId.EXORCISME:
			return []
	return []


# V1h : returns the subset of linked Domains the active demon could
# legally pay 1 Corruption from to Hinder this Response — linked AND
# controlled by the player AND containing at least 1 of the player's
# Corruptions. Empty list means Entrave is illegal regardless of the
# target Station distance.
static func entrave_payment_options(state: GameState, player: int, target_station: int) -> Array:
	var out: Array = []
	for d_id in linked_domains_for_response(state, target_station, player):
		if state.controller_of(d_id) != player:
			continue
		if state.corruption_in(d_id, player) < 1:
			continue
		out.append(d_id)
	return out


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
	# V1h : need at least one linked Domain controlled by the player with
	# 1+ of his Corruptions on it, instead of the old reserve-based check.
	if entrave_payment_options(state, player, target_station).is_empty():
		return false
	return true


# Same checks as can_entraver, but returning the user-facing reason string
# (empty string = legal). Used to drive disabled-button tooltips.
static func why_cannot_entraver(state: GameState, player: int, target_station: int) -> String:
	if target_station == GameEnums.StationId.EXORCISME:
		return I18n.t("err.entrave_exorcism")
	if target_station < state.current_station:
		return I18n.t("err.entrave_past_station")
	if target_station > state.current_station + 2:
		return I18n.t("err.entrave_too_far")
	for pe in state.pending_entraves:
		if pe.target_station == target_station:
			return I18n.t("err.entrave_already")
	if entrave_payment_options(state, player, target_station).is_empty():
		return I18n.t("err.entrave_no_linked_payment")
	return ""

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
	if player == GameEnums.PlayerId.PURPLE and d.exploited_by_blue_this_station:
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


static func why_cannot_amplifier(state: GameState, player: int, def_id: String, cached_ti: GameState.TransgressionInstance = null) -> String:
	# cached_ti lets callers that already hold the player's Scandale instance
	# (e.g. iterating a domain's scandals) skip the find_transgression_instance
	# scan — same result, no O(domains×transgressions) lookup.
	var ti: GameState.TransgressionInstance = cached_ti if cached_ti != null else state.find_transgression_instance(player, def_id, GameEnums.TransgressionFace.SCANDALE)
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
	# Panique contagieuse infamy: opponent loses 1 production when exploiting a contested domain.
	var panique_owner: int = state.transgression_owner(TransgressionData.T_PANIQUE)
	if panique_owner != GameEnums.PlayerId.NONE and panique_owner != player:
		var panique_ti: GameState.TransgressionInstance = state.find_transgression_instance(panique_owner, TransgressionData.T_PANIQUE, GameEnums.TransgressionFace.INFAMIE)
		if panique_ti != null and state.is_contested(d_id):
			base = max(0, base - 1)
	return base
