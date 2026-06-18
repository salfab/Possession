class_name ActionResolver
extends RefCounted
# All state mutations for player actions. Static methods.
# Each method returns a Dictionary {ok: bool, message: String} for UI feedback.

static func ok(msg: String) -> Dictionary:
	return {"ok": true, "message": msg}

static func fail(msg: String) -> Dictionary:
	return {"ok": false, "message": msg}

# --- Investir ---------------------------------------------------------------

static func investir(state: GameState, player: int, d_id: int) -> Dictionary:
	if not GameRules.can_investir(state, player, d_id):
		return fail("Investissement illégal.")
	state.add_corruption_pool(player, -1)
	state.set_corruption_in(d_id, player, state.corruption_in(d_id, player) + 1)
	state.add_log("%s investit 1 Corruption sur %s." % [GameEnums.player_name(player), GameEnums.DOMAIN_NAMES[d_id]])
	return ok("Investissement effectué.")

# --- Exploiter --------------------------------------------------------------

static func exploiter(state: GameState, player: int, d_id: int, free: bool = false) -> Dictionary:
	if not free and not GameRules.can_exploiter(state, player, d_id):
		return fail("Exploitation illégale.")
	if free and state.controller_of(d_id) != player:
		return fail("Exploitation gratuite : vous ne contrôlez pas ce Domaine.")
	var prod := GameRules.production_of(state, d_id, player)
	state.add_corruption_pool(player, prod)
	# Free or paid, an Exploit consumes the "once per station per domain"
	# privilege — you can't double-dip on the same Domain in the same Station.
	if player == GameEnums.PlayerId.RED:
		state.domain(d_id).exploited_by_red_this_station = true
	else:
		state.domain(d_id).exploited_by_blue_this_station = true
	var prefix := "Exploitation gratuite" if free else "Exploitation"
	state.add_log("%s — %s exploite %s : +%d Corruption." % [prefix, GameEnums.player_name(player), GameEnums.DOMAIN_NAMES[d_id], prod])
	return ok("+%d Corruption." % prod)

# --- Provoquer (Scandale) ---------------------------------------------------

static func provoquer(state: GameState, player: int, def_id: String, origin_choice: int = -1, extra: Dictionary = {}) -> Dictionary:
	if not GameRules.can_provoquer(state, player, def_id):
		return fail("Transgression illégale.")
	var def: Dictionary = TransgressionData.get_def(def_id)
	var origin: int = def.get("default_origin", 0)
	if def.get("origin_choice", false):
		var options: Array = def.get("domain_requirement", [])
		# The chosen origin must be a domain the player can actually provoke from
		# (controls it, or qualifies via the Appétit presence power) — otherwise
		# fall back to the first such domain. Stops a Scandale being dropped into
		# a required domain the opponent controls.
		if origin_choice in options and GameRules.can_provoke_from_domain(state, player, origin_choice):
			origin = origin_choice
		else:
			for d_id in options:
				if GameRules.can_provoke_from_domain(state, player, d_id):
					origin = d_id
					break
	# Provoking from a domain you don't control spends the once-per-Station
	# Appétit hérétique (Infamie) power.
	if state.controller_of(origin) != player:
		state.appetit_offcontrol_used_this_station[player] = true
	# Pay cost (with Népotisme discount tracked)
	var cost := GameRules.transgression_scandal_cost(state, player, def_id)
	state.add_corruption_pool(player, -cost)
	# Mark Népotisme used if this was the discounted Transgression of the Station
	if state.transgressions_provoked_this_station[player] == 0:
		state.nepotisme_used_this_station[player] = true
	state.transgressions_provoked_this_station[player] += 1
	# Create instance
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = def_id
	ti.owner = player
	ti.origin_domain = origin
	ti.face = GameEnums.TransgressionFace.SCANDALE
	state.domain(origin).scandals.append(ti)
	state.ascendant += (1 if player == GameEnums.PlayerId.RED else -1)
	state.add_log("%s provoque la Transgression « %s » (Scandale) en %s. +1 Ascendant." %
		[GameEnums.player_name(player), def["name"], GameEnums.DOMAIN_NAMES[origin]])
	# Per-card scandal effects
	_apply_scandal_effect(state, player, def_id, origin, extra)
	# Ambition/Foi infamy bonus from Trafic-de-charges
	_check_trafic_infamy_bonus(state, player, def_id, origin)
	return ok("Transgression provoquée.")

# --- Amplifier (Infamie) ----------------------------------------------------

static func amplifier(state: GameState, player: int, def_id: String) -> Dictionary:
	if not GameRules.can_amplifier(state, player, def_id):
		return fail("Amplification illégale.")
	var def: Dictionary = TransgressionData.get_def(def_id)
	var ti: GameState.TransgressionInstance = state.find_transgression_instance(player, def_id, GameEnums.TransgressionFace.SCANDALE)
	var d := state.domain(ti.origin_domain)
	state.add_corruption_pool(player, -int(def.get("amplification_cost", 0)))
	d.scandals.erase(ti)
	ti.face = GameEnums.TransgressionFace.INFAMIE
	d.infamies.append(ti)
	state.ascendant += (1 if player == GameEnums.PlayerId.RED else -1)
	state.add_log("%s amplifie « %s » en Infamie en %s. +1 Ascendant." %
		[GameEnums.player_name(player), def["name"], GameEnums.DOMAIN_NAMES[ti.origin_domain]])
	# Simonie Infamie : arme l'effet « prochaine Réponse ciblant Foi devient Impedita ».
	if def_id == TransgressionData.T_SIMONIE:
		state.foi_next_response_impedita = true
		state.add_log("Simonie Infamie : la prochaine Réponse ciblant Foi sera Impedita.")
	# Obéissance pervertie Infamie : permanent initiative override.
	if def_id == TransgressionData.T_OBEISSANCE:
		state.obeissance_acts_first[player] = true
		state.add_log("Infamie Obéissance pervertie : %s agit en premier pour toutes les Pulsations restantes." % GameEnums.player_name(player))
	return ok("Transgression amplifiée.")

# --- Sceller / Fissurer -----------------------------------------------------

static func sceller(state: GameState, player: int, d_id: int) -> Dictionary:
	if not GameRules.can_sceller(state, player, d_id):
		return fail("Scellement illégal.")
	state.add_corruption_pool(player, -1)
	state.domain(d_id).seal_owner = player
	state.add_log("%s scelle %s." % [GameEnums.player_name(player), GameEnums.DOMAIN_NAMES[d_id]])
	return ok("Domaine scellé.")

static func fissurer(state: GameState, player: int, d_id: int) -> Dictionary:
	if not GameRules.can_fissurer(state, player, d_id):
		return fail("Fissure illégale.")
	var d := state.domain(d_id)
	var seal_owner := d.seal_owner
	# Pay base cost
	state.add_corruption_pool(player, -1)
	# Tribut de Volonté if applicable
	if d_id == GameEnums.DomainId.VOLONTE and state.is_transgressed(d_id) and seal_owner != player:
		state.add_corruption_pool(player, -1)
		state.add_corruption_pool(seal_owner, 1)
		state.add_log("Tribut de Volonté : %s verse 1 Corruption à %s." %
			[GameEnums.player_name(player), GameEnums.player_name(seal_owner)])
	d.seal_owner = GameEnums.PlayerId.NONE
	d.was_fissured_this_station = true
	state.add_log("%s fissure %s (Sceau retiré, démoniaque)." % [GameEnums.player_name(player), GameEnums.DOMAIN_NAMES[d_id]])
	return ok("Sceau retiré.")

# --- Entraver ---------------------------------------------------------------

# V1h : Entrave is positional. The active demon picks a Domain that is
# (1) linked to the targeted Liturgical Response, (2) controlled by him,
# (3) containing at least 1 of his Corruptions ; and removes 1 Corruption
# from that Domain on the board. The reserve is untouched. Sacrificing
# this Corruption may cost the demon control of the Domain — that's
# allowed, V1h spec §2.
#
# payment_domain = -1 means "let the resolver auto-pick from the legal
# options" (used when there's only one valid Domain, or as a fallback).
static func entraver(state: GameState, player: int, target_station: int, payment_domain: int = -1) -> Dictionary:
	if not GameRules.can_entraver(state, player, target_station):
		return fail("Entrave illégale.")
	var options: Array = GameRules.entrave_payment_options(state, player, target_station)
	if payment_domain < 0:
		# Auto-pick the first legal Domain when the caller didn't
		# specify one (e.g. tests or one-Domain situations).
		payment_domain = options[0]
	if not options.has(payment_domain):
		return fail("Domaine choisi invalide pour cette Entrave.")
	# Remove 1 of the player's Corruptions from the chosen Domain.
	state.set_corruption_in(payment_domain, player,
		state.corruption_in(payment_domain, player) - 1)
	# Trafic-de-charges discount (Scandale effect) is now a no-op for V1h
	# Entrave — the cost is fixed at 1 board Corruption regardless. Clear
	# the pending flag so it doesn't sit forever (the player can spend it
	# on whatever the next Trafic-coupled action becomes in a future patch).
	if state.trafic_discount_pending.get(player, false):
		state.trafic_discount_pending[player] = false
	var pe := GameState.PendingEntrave.new()
	pe.caster = player
	pe.target_station = target_station
	state.pending_entraves.append(pe)
	state.add_log("%s entrave la Réponse de la Station %s (-1 Corruption en %s)." %
		[GameEnums.player_name(player), GameEnums.STATION_NAMES[target_station], GameEnums.DOMAIN_NAMES[payment_domain]])
	# Renoncement noir infamy: opponent of the one who placed the Entrave gains +1 Corruption.
	var ren_owner: int = state.transgression_owner(TransgressionData.T_RENONCEMENT)
	if ren_owner != GameEnums.PlayerId.NONE and ren_owner != player:
		var ren_ti: GameState.TransgressionInstance = state.find_transgression_instance(ren_owner, TransgressionData.T_RENONCEMENT, GameEnums.TransgressionFace.INFAMIE)
		if ren_ti != null:
			state.add_corruption_pool(ren_owner, 1)
			state.add_log("Infamie Renoncement noir : %s gagne +1 Corruption." % GameEnums.player_name(ren_owner))
	return ok("Entrave posée.")

# --- Passer -----------------------------------------------------------------

static func passer(state: GameState, player: int) -> Dictionary:
	state.add_log("%s passe." % GameEnums.player_name(player))
	return ok("Passé.")

# --- Puiser dans l'Ombre ---------------------------------------------------
# Last-resort safety net so a 0-Corruption player isn't stuck Pass-ing for
# the rest of the Station. Only legal when their pool is at 0; grants 1
# available Corruption.
static func puiser(state: GameState, player: int) -> Dictionary:
	if not GameRules.can_puiser(state, player):
		return fail(I18n.t("err.puiser_only_when_empty"))
	state.add_corruption_pool(player, 1)
	state.add_log(I18n.t("log.puiser", [GameEnums.player_name(player)]))
	return ok("+1 Corruption.")

# --- Helpers : Briser la Domination ----------------------------------------

# Reduce dominant player's corruption in d_id until net domination is broken (< 2 lead).
static func break_domination(state: GameState, d_id: int) -> void:
	var d := state.domain(d_id)
	if d == null:
		return
	var lead: int = abs(d.red_corruption - d.purple_corruption)
	if lead < 2:
		return
	var dominant := GameEnums.PlayerId.RED if d.red_corruption > d.purple_corruption else GameEnums.PlayerId.PURPLE
	# Reduce dominant by (lead - 1) so the gap becomes 1.
	var to_remove: int = lead - 1
	if dominant == GameEnums.PlayerId.RED:
		d.red_corruption = max(0, d.red_corruption - to_remove)
	else:
		d.purple_corruption = max(0, d.purple_corruption - to_remove)
	state.add_log("Briser la Domination en %s (-%d à %s)." %
		[GameEnums.DOMAIN_NAMES[d_id], to_remove, GameEnums.player_name(dominant)])
	# Persécution infamy: when YOU break domination here, the OTHER demon also loses
	# 1 Corruption in the domain (handled at caller level if relevant).

# --- Per-card SCANDALE effects ---------------------------------------------

static func _apply_scandal_effect(state: GameState, player: int, def_id: String, origin: int, extra: Dictionary = {}) -> void:
	match def_id:
		TransgressionData.T_NEPOTISME:
			state.add_corruption_pool(player, 1)
			state.add_log("Effet Scandale Népotisme : +1 Corruption.")
		TransgressionData.T_TRAFIC:
			state.trafic_discount_pending[player] = true
			state.add_log("Effet Scandale Trafic de charges : prochaine Entrave -1 Corruption.")
		TransgressionData.T_FESTIN:
			state.add_corruption_pool(player, 2)
			state.add_log("Effet Scandale Festin obscène : +2 Corruptions.")
		TransgressionData.T_FAVORI:
			if state.available_corruption[player] >= 1:
				state.add_corruption_pool(player, -1)
				state.set_corruption_in(GameEnums.DomainId.VOLONTE, player,
					state.corruption_in(GameEnums.DomainId.VOLONTE, player) + 1)
				state.add_log("Effet Scandale Favori secret : 1 Corruption placée sur Volonté.")
			else:
				state.add_log("Effet Scandale Favori secret ignoré (pas de Corruption disponible).")
		TransgressionData.T_SIMONIE:
			# Place an Entrave on this Station's response, or the next.
			# Default to current station if not entraved yet, else next.
			var target := state.current_station
			if GameRules.is_response_entraved(state, target) or target == GameEnums.StationId.EXORCISME:
				target = min(state.current_station + 1, GameEnums.StationId.OFFICE)
			if target != GameEnums.StationId.EXORCISME and not GameRules.is_response_entraved(state, target):
				var pe := GameState.PendingEntrave.new()
				pe.caster = player
				pe.target_station = target
				state.pending_entraves.append(pe)
				state.add_log("Effet Scandale Simonie : Entrave posée sur la Station %s." % GameEnums.STATION_NAMES[target])
		TransgressionData.T_PROFANATION:
			# Remove a Penitence ring on a domain you control if any, else +1 Corruption.
			var removed := false
			for d_id in DomainData.DOMAINS:
				if state.controller_of(d_id) == player and state.is_in_penitence(d_id):
					state.domain(d_id).penitence_until_station = -1
					state.add_log("Effet Scandale Profanation : Pénitence retirée de %s." % GameEnums.DOMAIN_NAMES[d_id])
					removed = true
					break
			if not removed:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Profanation : +1 Corruption (aucune Pénitence à retirer).")
		TransgressionData.T_PARANOIA:
			var opp := GameEnums.opponent(player)
			var fissured := false
			for d_id in DomainData.DOMAINS:
				if state.is_sealed(d_id) and state.domain(d_id).seal_owner == opp:
					state.domain(d_id).seal_owner = GameEnums.PlayerId.NONE
					state.domain(d_id).was_fissured_this_station = true
					state.add_log("Effet Scandale Paranoïa : Sceau retiré de %s." % GameEnums.DOMAIN_NAMES[d_id])
					fissured = true
					break
			if not fissured:
				state.add_corruption_pool(opp, -1)
				state.add_log("Effet Scandale Paranoïa : %s perd 1 Corruption disponible." % GameEnums.player_name(opp))
		TransgressionData.T_PERSECUTION:
			var opp2 := GameEnums.opponent(player)
			var contested_dom := -1
			for d_id in DomainData.DOMAINS:
				if state.is_contested(d_id):
					contested_dom = d_id
					break
			if contested_dom >= 0:
				state.set_corruption_in(contested_dom, opp2, state.corruption_in(contested_dom, opp2) - 1)
				state.add_log("Effet Scandale Persécution : %s perd 1 Corruption en %s." % [GameEnums.player_name(opp2), GameEnums.DOMAIN_NAMES[contested_dom]])
			else:
				state.add_corruption_pool(opp2, -1)
				state.add_log("Effet Scandale Persécution : %s perd 1 Corruption disponible." % GameEnums.player_name(opp2))
		TransgressionData.T_PACTE:
			if state.available_corruption[player] >= 1:
				state.add_corruption_pool(player, -1)
				state.set_corruption_in(GameEnums.DomainId.VOLONTE, player,
					state.corruption_in(GameEnums.DomainId.VOLONTE, player) + 1)
				state.add_log("Effet Scandale Pacte silencieux : 1 Corruption placée sur Volonté.")
			else:
				state.add_log("Effet Scandale Pacte silencieux ignoré (pas de Corruption disponible).")
		TransgressionData.T_ABDICATION:
			if state.controller_of(GameEnums.DomainId.VOLONTE) == player:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Abdication intérieure : +1 Corruption.")
			elif state.available_corruption[player] >= 1:
				state.add_corruption_pool(player, -1)
				state.set_corruption_in(GameEnums.DomainId.VOLONTE, player,
					state.corruption_in(GameEnums.DomainId.VOLONTE, player) + 1)
				state.add_log("Effet Scandale Abdication intérieure : 1 Corruption placée sur Volonté.")
			else:
				state.add_log("Effet Scandale Abdication intérieure ignoré.")
		# ── Codex ──────────────────────────────────────────────────────────────
		TransgressionData.T_INTRIGUE:
			# Chosen target_domain: opponent loses 1 corruption there; if 0, self +1.
			var tgt_i: int = extra.get("target_domain", -1)
			if tgt_i >= 0:
				var opp_i: int = GameEnums.opponent(player)
				var opp_has: int = state.corruption_in(tgt_i, opp_i)
				if opp_has >= 1:
					state.set_corruption_in(tgt_i, opp_i, opp_has - 1)
					state.add_log("Effet Scandale Intrigue du Consistoire : %s perd 1 Corruption en %s." % [GameEnums.player_name(opp_i), GameEnums.DOMAIN_NAMES[tgt_i]])
				else:
					state.add_corruption_pool(player, 1)
					state.add_log("Effet Scandale Intrigue du Consistoire : +1 Corruption (adversaire absent en %s)." % GameEnums.DOMAIN_NAMES[tgt_i])
			else:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Intrigue du Consistoire : +1 Corruption (aucune cible).")
		TransgressionData.T_BULLE:
			state.add_corruption_pool(player, 2)
			state.add_log("Effet Scandale Bulle vendue : +2 Corruptions.")
		TransgressionData.T_MASCARADE:
			# Move 1 corruption from from_domain to to_domain (both must be valid).
			var fd: int = extra.get("from_domain", -1)
			var td: int = extra.get("to_domain", -1)
			if fd >= 0 and td >= 0 and fd != td and state.corruption_in(fd, player) >= 1:
				state.set_corruption_in(fd, player, state.corruption_in(fd, player) - 1)
				state.set_corruption_in(td, player, state.corruption_in(td, player) + 1)
				state.add_log("Effet Scandale Mascarade de velours : 1 Corruption déplacée de %s vers %s." % [GameEnums.DOMAIN_NAMES[fd], GameEnums.DOMAIN_NAMES[td]])
			else:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Mascarade de velours : +1 Corruption (déplacement invalide).")
		TransgressionData.T_APPETIT:
			state.add_corruption_pool(player, 1)
			state.add_log("Effet Scandale Appétit hérétique : +1 Corruption.")
		TransgressionData.T_DOGME:
			# Free entrave on target_station; fallback +1 Corruption.
			var ts_d: int = extra.get("target_station", -1)
			if ts_d >= 0 and ts_d != GameEnums.StationId.EXORCISME and not GameRules.is_response_entraved(state, ts_d):
				var pe_d := GameState.PendingEntrave.new()
				pe_d.caster = player
				pe_d.target_station = ts_d
				state.pending_entraves.append(pe_d)
				state.add_log("Effet Scandale Dogme renversé : Entrave gratuite sur Station %s." % GameEnums.STATION_NAMES[ts_d])
			else:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Dogme renversé : +1 Corruption (aucune Station à entraver).")
		TransgressionData.T_RELIQUES:
			# Remove one penitence from a controlled domain; fallback +1 Corruption.
			var removed_r := false
			for d_id_r in DomainData.DOMAINS:
				if state.controller_of(d_id_r) == player and state.is_in_penitence(d_id_r):
					state.domain(d_id_r).penitence_until_station = -1
					state.add_log("Effet Scandale Reliques menteuses : Pénitence retirée de %s." % GameEnums.DOMAIN_NAMES[d_id_r])
					removed_r = true
					break
			if not removed_r:
				state.add_corruption_pool(player, 1)
				state.add_log("Effet Scandale Reliques menteuses : +1 Corruption (aucune Pénitence à retirer).")
		TransgressionData.T_DENONCIATION:
			# Block opponent from exploiting target_domain this station.
			var tgt_den: int = extra.get("target_domain", -1)
			if tgt_den >= 0:
				state.denonciation_blocked_domain[player] = tgt_den
				state.add_log("Effet Scandale Dénonciation anonyme : %s ne peut pas exploiter %s cette Station." % [GameEnums.player_name(GameEnums.opponent(player)), GameEnums.DOMAIN_NAMES[tgt_den]])
			else:
				state.add_log("Effet Scandale Dénonciation anonyme : aucune cible choisie.")
		TransgressionData.T_PANIQUE:
			# Chosen contested domain: opponent loses 1 from pool. Fallback if no contested domain.
			var tgt_pan: int = extra.get("target_domain", -1)
			var opp_pan: int = GameEnums.opponent(player)
			if tgt_pan >= 0 and state.is_contested(tgt_pan):
				state.add_corruption_pool(opp_pan, -1)
				state.add_log("Effet Scandale Panique contagieuse : %s perd 1 Corruption disponible (Domaine contesté %s)." % [GameEnums.player_name(opp_pan), GameEnums.DOMAIN_NAMES[tgt_pan]])
			else:
				state.add_corruption_pool(opp_pan, -1)
				state.add_log("Effet Scandale Panique contagieuse : %s perd 1 Corruption disponible." % GameEnums.player_name(opp_pan))
		TransgressionData.T_OBEISSANCE:
			state.add_corruption_pool(player, 1)
			state.obeissance_acts_first[player] = true
			state.add_log("Effet Scandale Obéissance pervertie : +1 Corruption, initiative cette Station.")
		TransgressionData.T_RENONCEMENT:
			# Remove 1 of opponent's corruptions from target_domain.
			var tgt_ren: int = extra.get("target_domain", -1)
			var opp_ren: int = GameEnums.opponent(player)
			if tgt_ren >= 0 and state.corruption_in(tgt_ren, opp_ren) >= 1:
				state.set_corruption_in(tgt_ren, opp_ren, state.corruption_in(tgt_ren, opp_ren) - 1)
				state.add_log("Effet Scandale Renoncement noir : %s perd 1 Corruption en %s." % [GameEnums.player_name(opp_ren), GameEnums.DOMAIN_NAMES[tgt_ren]])
			else:
				state.add_log("Effet Scandale Renoncement noir : aucune Corruption à retirer.")

static func _check_trafic_infamy_bonus(state: GameState, player: int, def_id: String, origin: int) -> void:
	# Trafic de charges Infamy: once/Station, when provoking a Transgression linked to
	# Ambition or Foi, gain 1 Corruption.
	var trafic_inst := state.find_transgression_instance(player, TransgressionData.T_TRAFIC, GameEnums.TransgressionFace.INFAMIE)
	if trafic_inst == null:
		return
	if state.trafic_infamy_used_this_station[player]:
		return
	if origin == GameEnums.DomainId.AMBITION or origin == GameEnums.DomainId.FOI:
		state.add_corruption_pool(player, 1)
		state.trafic_infamy_used_this_station[player] = true
		state.add_log("Bonus Infamie Trafic de charges : +1 Corruption.")
