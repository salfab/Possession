class_name TurnManager
extends RefCounted
# Orchestrates the flow of Stations and Pulses.
# It does NOT make action decisions; the UI calls perform_action() for the active player,
# and end_pulse_step() / end_station() to advance.

# A Pulse is structured: initiative player acts first (one action), then the other player acts.
# In this simplified model each pulse = each player makes exactly one action (Passer is always legal).
# Variable: state.active_player flips after each individual action until both have acted; then pulse ends.

var state: GameState
var _pulse_actions_done: Dictionary = {GameEnums.PlayerId.RED: false, GameEnums.PlayerId.BLUE: false}
var _pending_advance_to_station: int = -1   # set when waiting for Confession decisions

func _init(s: GameState, fresh_game: bool = true) -> void:
	state = s
	if fresh_game:
		_begin_station(state.current_station, true)


func active_player_must_act() -> bool:
	return not _pulse_actions_done[state.active_player]


func perform_action(action: int, kwargs: Dictionary = {}) -> Dictionary:
	if state.game_over:
		return ActionResolver.fail("Partie terminée.")
	if state.has_pending_decisions():
		return ActionResolver.fail("Une décision est en attente — résolvez-la d'abord.")
	if not active_player_must_act():
		return ActionResolver.fail("Ce joueur a déjà agi cette Pulsation.")
	var p := state.active_player
	var result: Dictionary
	match action:
		GameEnums.ActionId.INVESTIR:
			result = ActionResolver.investir(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.EXPLOITER:
			result = ActionResolver.exploiter(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.PROVOQUER:
			result = ActionResolver.provoquer(state, p, kwargs.get("def_id", ""), kwargs.get("origin", -1))
		GameEnums.ActionId.AMPLIFIER:
			result = ActionResolver.amplifier(state, p, kwargs.get("def_id", ""))
		GameEnums.ActionId.SCELLER:
			result = ActionResolver.sceller(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.FISSURER:
			result = ActionResolver.fissurer(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.ENTRAVER:
			result = ActionResolver.entraver(state, p, kwargs.get("station", -1))
		GameEnums.ActionId.PASSER:
			result = ActionResolver.passer(state, p)
		_:
			result = ActionResolver.fail("Action inconnue.")
	if result.get("ok", false):
		_pulse_actions_done[p] = true
		_advance_after_action()
	return result


func _advance_after_action() -> void:
	# Switch to the other player if they haven't acted yet.
	var other := GameEnums.opponent(state.active_player)
	if not _pulse_actions_done[other]:
		state.active_player = other
		return
	# Both acted -> end of pulse
	_end_pulse()


func _end_pulse() -> void:
	state.add_log("--- Fin de la Pulsation %d/%d (Station %s) ---" %
		[state.current_pulse, GameEnums.STATION_PULSES[state.current_station], GameEnums.STATION_NAMES[state.current_station]])
	_pulse_actions_done[GameEnums.PlayerId.RED] = false
	_pulse_actions_done[GameEnums.PlayerId.BLUE] = false
	if state.current_pulse < GameEnums.STATION_PULSES[state.current_station]:
		state.current_pulse += 1
		state.active_player = GameEnums.STATION_INITIATIVE[state.current_station]
	else:
		_end_station()


func _end_station() -> void:
	if state.current_station == GameEnums.StationId.EXORCISME:
		EndGameResolver.resolve_final_exorcism(state)
		return
	# Resolve liturgical response
	LiturgyResolver.resolve_station_response(state)
	# If the response queued any decisions (Confession), wait for them.
	if state.has_pending_decisions():
		_pending_advance_to_station = state.current_station + 1
		return
	_advance_to_station(state.current_station + 1)


func _advance_to_station(s: int) -> void:
	state.current_station = s
	state.current_pulse = 1
	state.active_player = GameEnums.STATION_INITIATIVE[s]
	_begin_station(s, false)


func _begin_station(station: int, _initial: bool) -> void:
	state.add_log("=== Début Station %s — Initiative %s ===" %
		[GameEnums.STATION_NAMES[station], GameEnums.player_name(GameEnums.STATION_INITIATIVE[station])])
	# Reset per-station flags
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		d.exploited_by_red_this_station = false
		d.exploited_by_blue_this_station = false
		d.was_fissured_this_station = false
	state.transgressions_provoked_this_station[GameEnums.PlayerId.RED] = 0
	state.transgressions_provoked_this_station[GameEnums.PlayerId.BLUE] = 0
	state.nepotisme_used_this_station[GameEnums.PlayerId.RED] = false
	state.nepotisme_used_this_station[GameEnums.PlayerId.BLUE] = false
	state.trafic_infamy_used_this_station[GameEnums.PlayerId.RED] = false
	state.trafic_infamy_used_this_station[GameEnums.PlayerId.BLUE] = false
	state.favori_used_this_station[GameEnums.PlayerId.RED] = false
	state.favori_used_this_station[GameEnums.PlayerId.BLUE] = false
	state.paranoia_used_this_station[GameEnums.PlayerId.RED] = false
	state.paranoia_used_this_station[GameEnums.PlayerId.BLUE] = false
	# Free exploitation for stations I-V (queued as pending decisions).
	if station != GameEnums.StationId.EXORCISME:
		_queue_free_exploitation_decisions()


func _queue_free_exploitation_decisions() -> void:
	# Initiative player picks first.
	var order: Array = [GameEnums.STATION_INITIATIVE[state.current_station], GameEnums.opponent(GameEnums.STATION_INITIATIVE[state.current_station])]
	for p in order:
		var options := []
		for d_id in DomainData.DOMAINS:
			if state.controller_of(d_id) == p:
				options.append(d_id)
		if options.is_empty():
			continue
		var dec := GameState.PendingDecision.new()
		dec.kind = "free_exploit"
		dec.player = p
		dec.picks_remaining = 1
		dec.data = {"options": options}
		state.pending_decisions.append(dec)


# UI calls this with a single dictionary describing the chosen pick.
# free_exploit: {"domain": <id>} or {"skip": true}
# confession:   {"kind": "lose2"} or {"kind": "penitence", "domain": <id>} or {"kind": "fissure", "domain": <id>}
func resolve_decision(picks: Dictionary) -> Dictionary:
	if not state.has_pending_decisions():
		return ActionResolver.fail("Aucune décision en attente.")
	var dec: GameState.PendingDecision = state.pending_decisions[0]
	var done := false
	if dec.kind == "free_exploit":
		if picks.get("skip", false):
			state.add_log("Exploitation gratuite ignorée par %s." % GameEnums.player_name(dec.player))
			done = true
		else:
			var d_exp: int = picks.get("domain", -1)
			if d_exp < 0 or d_exp not in dec.data.get("options", []):
				return ActionResolver.fail("Domaine invalide.")
			var r_exp := ActionResolver.exploiter(state, dec.player, d_exp, true)
			if not r_exp["ok"]:
				return r_exp
			done = true
	elif dec.kind == "confession":
		var k: String = picks.get("kind", "")
		var d_conf: int = picks.get("domain", -1)
		var r_conf := LiturgyResolver.apply_confession_pick(state, dec, k, d_conf)
		if not r_conf["ok"]:
			return r_conf
		done = r_conf.get("done", false)
	else:
		return ActionResolver.fail("Décision inconnue : %s" % dec.kind)
	if done:
		state.pending_decisions.pop_front()
	# If the queue is empty and we were waiting to advance the station, do it now.
	if not state.has_pending_decisions() and _pending_advance_to_station >= 0:
		var s := _pending_advance_to_station
		_pending_advance_to_station = -1
		_advance_to_station(s)
	return ActionResolver.ok("Décision résolue.")


# --- For tests / debug ---
func force_advance_to_exorcism() -> void:
	while state.current_station < GameEnums.StationId.EXORCISME and not state.game_over:
		_drain_pending_decisions()
		state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
		_pulse_actions_done[GameEnums.PlayerId.RED] = true
		_pulse_actions_done[GameEnums.PlayerId.BLUE] = true
		_end_pulse()
		_drain_pending_decisions()


# Auto-resolve pending decisions with sensible defaults (used by debug shortcuts).
func _drain_pending_decisions() -> void:
	while state.has_pending_decisions():
		var dec: GameState.PendingDecision = state.pending_decisions[0]
		if dec.kind == "free_exploit":
			var opts: Array = dec.data.get("options", [])
			if opts.is_empty():
				resolve_decision({"skip": true})
			else:
				resolve_decision({"domain": opts[0]})
		elif dec.kind == "confession":
			var avail := LiturgyResolver.available_confession_kinds(state, dec)
			if avail.is_empty():
				# Nothing applicable — pop without effect.
				state.pending_decisions.pop_front()
				if not state.has_pending_decisions() and _pending_advance_to_station >= 0:
					var s := _pending_advance_to_station
					_pending_advance_to_station = -1
					_advance_to_station(s)
			else:
				var pick := {"kind": avail[0]}
				if avail[0] != "lose2":
					for d_id in DomainData.DOMAINS:
						if state.controller_of(d_id) == dec.player and (avail[0] == "penitence" or state.domain(d_id).seal_owner == dec.player):
							pick["domain"] = d_id
							break
				resolve_decision(pick)
		else:
			break
