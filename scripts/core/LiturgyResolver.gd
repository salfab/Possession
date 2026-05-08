class_name LiturgyResolver
extends RefCounted
# Resolves the liturgical response of a Station (I to V).
# Station VI is handled by EndGameResolver, not here.
# All targeting tie-breakers use the simple priority defined in the spec;
# "demon without initiative chooses" cases default to a deterministic pick
# (the demon without initiative for that station) — the UI may expose a manual
# override later. See /docs/ambiguities.md.

static func resolve_station_response(state: GameState) -> Dictionary:
	var st: int = state.current_station
	var response: Dictionary = LiturgicalResponseData.get_response(st)
	if response.is_empty():
		return {"resolved": false}
	var entraved := GameRules.is_response_entraved(state, st)
	# Snapshot the target *before* mutating state — Communion in particular
	# changes the seal/emprise of the targeted Domain, which would change
	# what a re-run of the picker would say.
	var target_domain: int = preview_target_domain(state, st)
	var target_player: int = preview_target_player(state, st)
	# Simonie infamy: if the response targets Foi, force Impedita the next time.
	# This is checked *after* selecting the target.
	state.add_log("--- Réponse liturgique : %s (%s) ---" %
		[response["name"], "Impedita" if entraved else "In Integro"])
	var log_start: int = state.log.size()
	match st:
		GameEnums.StationId.MURMURES:
			_signe_de_croix(state, entraved)
		GameEnums.StationId.TENTATION:
			_examen(state, entraved)
		GameEnums.StationId.CHUTE:
			_contrition(state, entraved)
		GameEnums.StationId.CONFESSION:
			_confession(state, entraved)
		GameEnums.StationId.OFFICE:
			_communion(state, entraved)
	var produced: Array = []
	for i in range(log_start, state.log.size()):
		produced.append(String(state.log[i]))
	var desc_key := "text_impedita" if entraved else "text_in_integro"
	return {
		"resolved": true,
		"impedita": entraved,
		"station": st,
		"name": String(response["name"]),
		"description": String(response.get(desc_key, "")),
		"log_lines": produced,
		"target_domain": target_domain,
		"target_player": target_player,
	}


# --- Target preview (read-only) ---------------------------------------------
# Used by the UI (Card / Main) to show the would-be target on a Liturgy card
# before the resolver actually runs. Returns DomainId, or -1 when the station
# either targets a player (Confession) or has no valid target right now
# (Contrition with no transgressed Domain).
static func preview_target_domain(state: GameState, station: int) -> int:
	match station:
		GameEnums.StationId.MURMURES:
			return _pick_signe_target(state)
		GameEnums.StationId.TENTATION:
			return _pick_examen_target(state)
		GameEnums.StationId.CHUTE:
			return _pick_contrition_target(state)
		GameEnums.StationId.OFFICE:
			return _pick_communion_target(state)
		_:
			return -1


# Confession targets a player rather than a Domain. Returns PlayerId, or -1
# for any other station.
static func preview_target_player(state: GameState, station: int) -> int:
	if station == GameEnums.StationId.CONFESSION:
		return int(_pick_confession_target_player(state)["player"])
	return -1


# --- Targeting helpers ------------------------------------------------------

static func _without_initiative_player(state: GameState) -> int:
	var init_p: int = GameEnums.STATION_INITIATIVE.get(state.current_station, GameEnums.PlayerId.RED)
	return GameEnums.opponent(init_p)

static func _total_emprise(state: GameState, d_id: int) -> int:
	var d := state.domain(d_id)
	return d.red_corruption + d.purple_corruption

static func _pick_max(values: Dictionary, tie_breaker: Callable) -> int:
	# values: DomainId -> score. Returns chosen DomainId.
	var best := -1
	var best_score := -9999
	for d_id in values.keys():
		var s = values[d_id]
		if s > best_score:
			best_score = s
			best = d_id
	# Find tied
	var tied := []
	for d_id in values.keys():
		if values[d_id] == best_score:
			tied.append(d_id)
	if tied.size() == 1:
		return best
	return tie_breaker.call(tied)


# --- I — Signe de croix -----------------------------------------------------

static func _pick_signe_target(state: GameState) -> int:
	var mod: String = state.missel_modifiers.get(GameEnums.StationId.MURMURES, "")
	if mod != "":
		var override := MisselData.pick_target_domain(state, mod)
		if override != -1:
			return override
	var totals := {}
	for d_id in DomainData.DOMAINS:
		totals[d_id] = _total_emprise(state, d_id)
	return _pick_max(totals, func(tied):
		for v in GameEnums.VOLONTE_PROXIMITY_PRIORITY:
			if v in tied:
				return v
		return tied[0]
	)


static func _signe_de_croix(state: GameState, impedita: bool) -> void:
	var target := _pick_signe_target(state)
	state.add_log("Cible : %s." % GameEnums.DOMAIN_NAMES[target])
	impedita = _maybe_force_impedita(state, target, impedita)
	if impedita:
		# Most-emprise player loses 1 available corruption.
		var d := state.domain(target)
		if d.red_corruption > d.purple_corruption:
			state.add_corruption_pool(GameEnums.PlayerId.RED, -1)
			state.add_log("Impedita : Rouge perd 1 Corruption disponible.")
		elif d.purple_corruption > d.red_corruption:
			state.add_corruption_pool(GameEnums.PlayerId.PURPLE, -1)
			state.add_log("Impedita : Bleu perd 1 Corruption disponible.")
		else:
			state.add_log("Impedita : égalité, aucun effet.")
	else:
		var d := state.domain(target)
		var lead: int = abs(d.red_corruption - d.purple_corruption)
		if lead >= 2:
			ActionResolver.break_domination(state, target)
		else:
			# No domination -> each demon with corruption here loses 1 available corruption.
			if d.red_corruption > 0:
				state.add_corruption_pool(GameEnums.PlayerId.RED, -1)
			if d.purple_corruption > 0:
				state.add_corruption_pool(GameEnums.PlayerId.PURPLE, -1)
			state.add_log("In Integro : pas de Domination, chaque démon présent perd 1 Corruption disponible.")


# --- II — Examen de conscience ---------------------------------------------

static func _pick_examen_target(state: GameState) -> int:
	var mod: String = state.missel_modifiers.get(GameEnums.StationId.TENTATION, "")
	if mod != "":
		var override := MisselData.pick_target_domain(state, mod)
		if override != -1:
			return override
	var candidates := [GameEnums.DomainId.AMBITION, GameEnums.DomainId.DESIR]
	var totals := {}
	for d_id in candidates:
		totals[d_id] = _total_emprise(state, d_id)
	return _pick_max(totals, func(tied): return GameEnums.DomainId.AMBITION if GameEnums.DomainId.AMBITION in tied else tied[0])


static func _examen(state: GameState, impedita: bool) -> void:
	var target := _pick_examen_target(state)
	state.add_log("Cible : %s." % GameEnums.DOMAIN_NAMES[target])
	impedita = _maybe_force_impedita(state, target, impedita)
	var d := state.domain(target)
	if not impedita:
		ActionResolver.break_domination(state, target)
		d.cannot_be_sealed_until_exorcism = false  # not permanent
		d.penitence_until_station = -1
		# "ne peut pas être scellé jusqu'à la fin de la prochaine Station"
		var until: int = min(state.current_station + 1, GameEnums.StationId.OFFICE)
		_set_no_seal_until(state, target, until)
		state.add_log("In Integro : %s ne peut pas être scellé jusqu'à la fin de la Station %s." %
			[GameEnums.DOMAIN_NAMES[target], GameEnums.STATION_NAMES[until]])
	else:
		_set_no_seal_until(state, target, state.current_station)
		state.add_log("Impedita : %s ne peut pas être scellé jusqu'à la fin de cette Station." %
			GameEnums.DOMAIN_NAMES[target])


# We model "cannot be sealed until end of station X" with the existing penitence_until_station
# field for the prototype. Penitence already implies "cannot be sealed".
static func _set_no_seal_until(state: GameState, d_id: int, station_inclusive: int) -> void:
	var d := state.domain(d_id)
	d.penitence_until_station = max(d.penitence_until_station, station_inclusive)


# --- III — Contrition ------------------------------------------------------

# Most "serious" transgressed domain: most infamies, then scandals, then total emprise.
# Returns -1 if no domain is transgressed.
static func _pick_contrition_target(state: GameState) -> int:
	var mod: String = state.missel_modifiers.get(GameEnums.StationId.CHUTE, "")
	if mod != "":
		var override := MisselData.pick_target_domain(state, mod)
		if override != -1:
			return override
	var transgressed := []
	for d_id in DomainData.DOMAINS:
		if state.is_transgressed(d_id):
			transgressed.append(d_id)
	if transgressed.is_empty():
		return -1
	transgressed.sort_custom(func(a, b):
		var da := state.domain(a)
		var db := state.domain(b)
		if da.infamies.size() != db.infamies.size():
			return da.infamies.size() > db.infamies.size()
		if da.scandals.size() != db.scandals.size():
			return da.scandals.size() > db.scandals.size()
		return _total_emprise(state, a) > _total_emprise(state, b))
	return transgressed[0]


static func _contrition(state: GameState, impedita: bool) -> void:
	var target := _pick_contrition_target(state)
	if target == -1:
		state.add_log("Contrition : aucun Domaine transgressé, pas d'effet.")
		return
	state.add_log("Cible : %s." % GameEnums.DOMAIN_NAMES[target])
	impedita = _maybe_force_impedita(state, target, impedita)
	var d := state.domain(target)
	if not impedita:
		if state.is_sealed(target):
			d.seal_owner = GameEnums.PlayerId.NONE
			d.was_fissured_this_station = true
			state.add_log("Fissure liturgique In Integro : Sceau retiré.")
		ActionResolver.break_domination(state, target)
		var until: int = min(state.current_station + 1, GameEnums.StationId.OFFICE)
		if not _is_shielded_from_penitence(state, target):
			d.penitence_until_station = max(d.penitence_until_station, until)
			state.add_log("Pénitence jusqu'à la Station %s." % GameEnums.STATION_NAMES[until])
	else:
		var until: int = min(state.current_station + 1, GameEnums.StationId.OFFICE)
		if not _is_shielded_from_penitence(state, target):
			d.penitence_until_station = max(d.penitence_until_station, until)
			state.add_log("Impedita : Pénitence jusqu'à la Station %s." % GameEnums.STATION_NAMES[until])


# --- IV — Confession --------------------------------------------------------

# Returns {"player": PlayerId, "total_transgressions": int}.
# When total is 0 the resolution short-circuits with no effect, but a target
# is still provided (the demon-without-initiative on tie) so the UI can label
# the card.
static func _pick_confession_target_player(state: GameState) -> Dictionary:
	var mod: String = state.missel_modifiers.get(GameEnums.StationId.CONFESSION, "")
	if mod != "":
		var override := MisselData.pick_target_player(state, mod)
		if override != -1:
			var total := 0
			for d_id in DomainData.DOMAINS:
				var d := state.domain(d_id)
				for ti in d.scandals:
					if ti.owner == override:
						total += 1
				for ti in d.infamies:
					if ti.owner == override:
						total += 1
			return {"player": override, "total_transgressions": total}
	var counts := {GameEnums.PlayerId.RED: 0, GameEnums.PlayerId.PURPLE: 0}
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		for ti in d.scandals:
			counts[ti.owner] += 1
		for ti in d.infamies:
			counts[ti.owner] += 1
	var target_player: int
	if counts[GameEnums.PlayerId.RED] > counts[GameEnums.PlayerId.PURPLE]:
		target_player = GameEnums.PlayerId.RED
	elif counts[GameEnums.PlayerId.PURPLE] > counts[GameEnums.PlayerId.RED]:
		target_player = GameEnums.PlayerId.PURPLE
	else:
		# Tie -> demon with most Ascendant, then demon without initiative.
		if state.ascendant > 0:
			target_player = GameEnums.PlayerId.RED
		elif state.ascendant < 0:
			target_player = GameEnums.PlayerId.PURPLE
		else:
			target_player = _without_initiative_player(state)
	return {
		"player": target_player,
		"total_transgressions": counts[GameEnums.PlayerId.RED] + counts[GameEnums.PlayerId.PURPLE],
	}


static func _confession(state: GameState, impedita: bool) -> void:
	var pick := _pick_confession_target_player(state)
	var target_player: int = int(pick["player"])
	state.add_log("Cible : %s." % GameEnums.player_name(target_player))
	if int(pick["total_transgressions"]) == 0:
		state.add_log("Confession : aucune Transgression, pas d'effet.")
		return
	# Push a pending decision. The UI prompts target_player to pick N distinct
	# penitences. TurnManager waits for the queue to empty before advancing.
	var dec := GameState.PendingDecision.new()
	dec.kind = "confession"
	dec.player = target_player
	dec.picks_remaining = 1 if impedita else 2
	dec.data = {"impedita": impedita}
	state.pending_decisions.append(dec)


# Apply one confession penitence chosen by the targeted player.
# kind: "lose2" | "penitence" | "fissure"
# domain_id: required for "penitence" and "fissure", -1 for "lose2".
static func apply_confession_pick(state: GameState, dec: GameState.PendingDecision, kind: String, domain_id: int) -> Dictionary:
	if dec.kind != "confession":
		return {"ok": false, "message": "Décision incorrecte."}
	if kind in dec.picks_done:
		return {"ok": false, "message": "Pénitence déjà choisie."}
	var target_player := dec.player
	match kind:
		"lose2":
			if state.available_corruption[target_player] < 2:
				return {"ok": false, "message": "Pas assez de Corruptions disponibles."}
			state.add_corruption_pool(target_player, -2)
			state.add_log("Pénitence : %s perd 2 Corruptions disponibles." % GameEnums.player_name(target_player))
		"penitence":
			if state.controller_of(domain_id) != target_player or state.is_in_penitence(domain_id):
				return {"ok": false, "message": "Pénitence : Domaine invalide."}
			var until: int = min(state.current_station + 1, GameEnums.StationId.OFFICE)
			var d := state.domain(domain_id)
			if not _is_shielded_from_penitence(state, domain_id):
				d.penitence_until_station = max(d.penitence_until_station, until)
			state.add_log("Pénitence : %s mis en Pénitence." % GameEnums.DOMAIN_NAMES[domain_id])
		"fissure":
			var d2 := state.domain(domain_id)
			if state.controller_of(domain_id) != target_player or d2.seal_owner != target_player:
				return {"ok": false, "message": "Fissure : Sceau personnel requis."}
			d2.seal_owner = GameEnums.PlayerId.NONE
			d2.was_fissured_this_station = true
			state.add_log("Pénitence : Sceau retiré de %s." % GameEnums.DOMAIN_NAMES[domain_id])
		_:
			return {"ok": false, "message": "Kind inconnu."}
	dec.picks_done.append(kind)
	dec.picks_remaining -= 1
	return {"ok": true, "message": "Pénitence appliquée.", "done": dec.picks_remaining <= 0}


# Returns the kinds the target player can still pick (excluding already picked).
static func available_confession_kinds(state: GameState, dec: GameState.PendingDecision) -> Array:
	var p := dec.player
	var kinds := []
	if "lose2" not in dec.picks_done and state.available_corruption[p] >= 2:
		kinds.append("lose2")
	if "penitence" not in dec.picks_done:
		for d_id in DomainData.DOMAINS:
			if state.controller_of(d_id) == p and not state.is_in_penitence(d_id):
				kinds.append("penitence"); break
	if "fissure" not in dec.picks_done:
		for d_id in DomainData.DOMAINS:
			if state.controller_of(d_id) == p and state.is_sealed(d_id) and state.domain(d_id).seal_owner == p:
				kinds.append("fissure"); break
	return kinds


# --- V — Communion ---------------------------------------------------------

static func _pick_communion_target(state: GameState) -> int:
	var mod: String = state.missel_modifiers.get(GameEnums.StationId.OFFICE, "")
	if mod != "":
		var override := MisselData.pick_target_domain(state, mod)
		if override != -1:
			return override
	var candidates := [GameEnums.DomainId.FOI, GameEnums.DomainId.VOLONTE]
	# Priority: sealed > has infamy > most emprise > demon-without-initiative chooses.
	var sealed_c := []
	var infamy_c := []
	for d_id in candidates:
		if state.is_sealed(d_id):
			sealed_c.append(d_id)
		elif state.domain(d_id).infamies.size() > 0:
			infamy_c.append(d_id)
	if sealed_c.size() == 1:
		return sealed_c[0]
	if sealed_c.size() == 2:
		return _pick_max(_emprise_dict(state, sealed_c), func(tied): return tied[0])
	if infamy_c.size() == 1:
		return infamy_c[0]
	if infamy_c.size() == 2:
		return _pick_max(_emprise_dict(state, infamy_c), func(tied): return tied[0])
	return _pick_max(_emprise_dict(state, candidates), func(tied): return tied[0])


static func _communion(state: GameState, impedita: bool) -> void:
	var target := _pick_communion_target(state)
	state.add_log("Cible : %s." % GameEnums.DOMAIN_NAMES[target])
	impedita = _maybe_force_impedita(state, target, impedita)
	var d := state.domain(target)
	if not impedita:
		if state.is_sealed(target):
			d.seal_owner = GameEnums.PlayerId.NONE
			d.was_fissured_this_station = true
			state.add_log("Fissure liturgique In Integro : Sceau retiré.")
			ActionResolver.break_domination(state, target)
		else:
			ActionResolver.break_domination(state, target)
		d.cannot_be_sealed_until_exorcism = true
		state.add_log("In Integro : %s ne peut pas être (re)scellé avant l'Exorcisme final." % GameEnums.DOMAIN_NAMES[target])
	else:
		if state.is_sealed(target):
			d.seal_owner = GameEnums.PlayerId.NONE
			d.was_fissured_this_station = true
			state.add_log("Fissure simple Impedita : Sceau retiré.")
		else:
			ActionResolver.break_domination(state, target)


static func _emprise_dict(state: GameState, lst: Array) -> Dictionary:
	var d := {}
	for x in lst:
		d[x] = _total_emprise(state, x)
	return d


# --- Reliques menteuses infamy: shield a domain from penitence --------------
# Returns true when penitence should be blocked (and logs the interception).
static func _is_shielded_from_penitence(state: GameState, d_id: int) -> bool:
	var owner: int = state.transgression_owner(TransgressionData.T_RELIQUES)
	if owner == GameEnums.PlayerId.NONE:
		return false
	var ti: GameState.TransgressionInstance = state.find_transgression_instance(owner, TransgressionData.T_RELIQUES, GameEnums.TransgressionFace.INFAMIE)
	if ti == null or ti.origin_domain != d_id:
		return false
	state.add_log("Reliques menteuses : Pénitence annulée sur %s." % GameEnums.DOMAIN_NAMES[d_id])
	return true


# --- Simonie infamy: force Impedita on a Foi-targeting response -------------
# Returns the (possibly forced) impedita flag and consumes the trigger.
static func _maybe_force_impedita(state: GameState, target_domain: int, impedita: bool) -> bool:
	if target_domain == GameEnums.DomainId.FOI and state.foi_next_response_impedita:
		state.foi_next_response_impedita = false
		state.add_log("Simonie Infamie consommée : Réponse forcée Impedita.")
		return true
	return impedita
