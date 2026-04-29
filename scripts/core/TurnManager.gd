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

func _init(s: GameState, fresh_game: bool = true) -> void:
	state = s
	if fresh_game:
		_begin_station(state.current_station, true)


func active_player_must_act() -> bool:
	return not _pulse_actions_done[state.active_player]


func perform_action(action: int, kwargs: Dictionary = {}) -> Dictionary:
	if state.game_over:
		return ActionResolver.fail("Partie terminée.")
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
	# Advance to next station
	var next_station := state.current_station + 1
	state.current_station = next_station
	state.current_pulse = 1
	state.active_player = GameEnums.STATION_INITIATIVE[next_station]
	_begin_station(next_station, false)


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
	# Free exploitation for stations I-V
	if station != GameEnums.StationId.EXORCISME:
		_free_exploitation_phase()


func _free_exploitation_phase() -> void:
	# Initiative player picks first; auto-pick any controlled domain that yields the most.
	# Done deterministically here. UI may override by exposing manual choice.
	var order := [GameEnums.STATION_INITIATIVE[state.current_station], GameEnums.opponent(GameEnums.STATION_INITIATIVE[state.current_station])]
	for p in order:
		var best_d := -1
		var best_yield := -1
		for d_id in DomainData.DOMAINS:
			if state.controller_of(d_id) != p:
				continue
			var y := GameRules.production_of(state, d_id, p)
			if y > best_yield:
				best_yield = y
				best_d = d_id
		if best_d >= 0:
			ActionResolver.exploiter(state, p, best_d, true)


# --- For tests ---
func force_advance_to_exorcism() -> void:
	while state.current_station < GameEnums.StationId.EXORCISME and not state.game_over:
		state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
		_pulse_actions_done[GameEnums.PlayerId.RED] = true
		_pulse_actions_done[GameEnums.PlayerId.BLUE] = true
		_end_pulse()
