class_name TurnManager
extends RefCounted
# Orchestrates the flow of Stations and Pulses.
# It does NOT make action decisions; the UI calls perform_action() for the active player,
# and end_pulse_step() / end_station() to advance.

# A Pulse is structured: initiative player acts first (one action), then the other player acts.
# In this simplified model each pulse = each player makes exactly one action (Passer is always legal).
# Variable: state.active_player flips after each individual action until both have acted; then pulse ends.

var state: GameState
var _pulse_actions_done: Dictionary = {GameEnums.PlayerId.RED: false, GameEnums.PlayerId.PURPLE: false}
var _pending_advance_to_station: int = -1   # set when waiting for Confession decisions
# Set after the liturgical response of a station resolves; the UI must
# acknowledge before the game advances to the next station.
var pending_liturgy: Dictionary = {}
var _bot_running: bool = false

# When true (headless tests / bot-vs-bot benchmarks), perform_action()
# drives the whole bot turn synchronously inside _check_bot_turn(). The
# Godot UI sets this to false so it can step the bot ONE action at a time
# (see step_bot_once()), pacing each move through a timer + refresh so the
# player can watch the AI play. Default true preserves headless behaviour.
var auto_bot: bool = true

# Last successful action applied via perform_action(), exposed so the UI's
# animation dispatcher can replay a tailored visual for it on the next
# refresh — works identically whether the action came from a human tap or
# from a bot's step_bot_once(). last_action is -1 when nothing is pending.
var last_action: int = -1
var last_kwargs: Dictionary = {}
var last_action_player: int = GameEnums.PlayerId.NONE

func _init(s: GameState, fresh_game: bool = true) -> void:
	state = s
	if fresh_game:
		_begin_station(state.current_station, true)


func active_player_must_act() -> bool:
	return not _pulse_actions_done[state.active_player]


func perform_action(action: int, kwargs: Dictionary = {}) -> Dictionary:
	if state.game_over:
		return ActionResolver.fail("Partie terminée.")
	if not pending_liturgy.is_empty():
		return ActionResolver.fail("Réponse liturgique en attente — validez-la d'abord.")
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
			var extra_kwargs: Dictionary = {}
			for key in ["target_domain", "from_domain", "to_domain", "target_station"]:
				if kwargs.has(key):
					extra_kwargs[key] = kwargs[key]
			result = ActionResolver.provoquer(state, p, kwargs.get("def_id", ""), kwargs.get("origin", -1), extra_kwargs)
		GameEnums.ActionId.AMPLIFIER:
			result = ActionResolver.amplifier(state, p, kwargs.get("def_id", ""))
		GameEnums.ActionId.SCELLER:
			result = ActionResolver.sceller(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.FISSURER:
			result = ActionResolver.fissurer(state, p, kwargs.get("domain", -1))
		GameEnums.ActionId.ENTRAVER:
			result = ActionResolver.entraver(state, p,
				kwargs.get("station", -1),
				kwargs.get("payment_domain", -1))
		GameEnums.ActionId.PASSER:
			result = ActionResolver.passer(state, p)
		GameEnums.ActionId.PUISER:
			result = ActionResolver.puiser(state, p)
		_:
			result = ActionResolver.fail("Action inconnue.")
	if result.get("ok", false):
		last_action = action
		last_kwargs = kwargs.duplicate(true)
		last_action_player = p
		_pulse_actions_done[p] = true
		_advance_after_action()
	return result


# Clears the last-action record so a subsequent refresh that isn't tied to
# a fresh action won't replay its animation. The UI calls this once it has
# consumed last_action via its animation dispatcher.
func consume_last_action() -> void:
	last_action = -1
	last_kwargs = {}
	last_action_player = GameEnums.PlayerId.NONE


func _advance_after_action() -> void:
	# Switch to the other player if they haven't acted yet.
	var other := GameEnums.opponent(state.active_player)
	if not _pulse_actions_done[other]:
		state.active_player = other
		_check_bot_turn()
		return
	# Both acted -> end of pulse
	_end_pulse()


func _end_pulse() -> void:
	state.add_log("--- Fin de la Pulsation %d/%d (Station %s) ---" %
		[state.current_pulse, GameEnums.STATION_PULSES[state.current_station], GameEnums.STATION_NAMES[state.current_station]])
	_pulse_actions_done[GameEnums.PlayerId.RED] = false
	_pulse_actions_done[GameEnums.PlayerId.PURPLE] = false
	if state.current_pulse < GameEnums.STATION_PULSES[state.current_station]:
		state.current_pulse += 1
		state.active_player = _pick_initiative()
	else:
		_end_station()


func _end_station() -> void:
	if state.current_station == GameEnums.StationId.EXORCISME:
		EndGameResolver.resolve_final_exorcism(state)
		return
	# Resolve liturgical response and pause: the UI must acknowledge the
	# response (full-screen dialog) before we advance to the next station.
	pending_liturgy = LiturgyResolver.resolve_station_response(state)
	# The Entrave on this Station's response is now spent — drop it so it doesn't
	# linger in pending_entraves and wrongly entrave a later response.
	var kept: Array = []
	for pe in state.pending_entraves:
		if pe.target_station != state.current_station:
			kept.append(pe)
	state.pending_entraves = kept
	_pending_advance_to_station = state.current_station + 1


func acknowledge_liturgy() -> void:
	var was_entraved: bool = pending_liturgy.get("impedita", false)
	pending_liturgy = {}
	# Bulle vendue infamy: +1 Corruption after each non-entraved liturgy.
	# Dogme renversé infamy: +1 Corruption after each liturgy.
	for p in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		var bulle_ti: GameState.TransgressionInstance = state.find_transgression_instance(p, TransgressionData.T_BULLE, GameEnums.TransgressionFace.INFAMIE)
		if bulle_ti != null and not was_entraved:
			state.add_corruption_pool(p, 1)
			state.add_log("Infamie Bulle vendue : %s gagne +1 Corruption (Réponse non entravée)." % GameEnums.player_name(p))
		var dogme_ti: GameState.TransgressionInstance = state.find_transgression_instance(p, TransgressionData.T_DOGME, GameEnums.TransgressionFace.INFAMIE)
		if dogme_ti != null:
			state.add_corruption_pool(p, 1)
			state.add_log("Infamie Dogme renversé : %s gagne +1 Corruption." % GameEnums.player_name(p))
	_try_advance_after_liturgy()
	_check_bot_turn()


func _try_advance_after_liturgy() -> void:
	if not pending_liturgy.is_empty():
		return
	if state.has_pending_decisions():
		return
	if _pending_advance_to_station < 0:
		return
	var s := _pending_advance_to_station
	_pending_advance_to_station = -1
	_advance_to_station(s)


func _advance_to_station(s: int) -> void:
	state.current_station = s
	state.current_pulse = 1
	_begin_station(s, false)
	state.active_player = _pick_initiative()


func _begin_station(station: int, _initial: bool) -> void:
	state.add_log("=== Début Station %s — Initiative %s ===" %
		[GameEnums.STATION_NAMES[station], GameEnums.player_name(GameEnums.STATION_INITIATIVE[station])])
	# A new Station is always a fresh first Pulse — clear the per-pulse action
	# flags so a stale "already acted" can't block the new Station's first move
	# (defence-in-depth alongside the pending_liturgy guard in perform_action).
	_pulse_actions_done[GameEnums.PlayerId.RED] = false
	_pulse_actions_done[GameEnums.PlayerId.PURPLE] = false
	# Reset per-station flags
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		d.exploited_by_red_this_station = false
		d.exploited_by_blue_this_station = false
		d.was_fissured_this_station = false
	state.transgressions_provoked_this_station[GameEnums.PlayerId.RED] = 0
	state.transgressions_provoked_this_station[GameEnums.PlayerId.PURPLE] = 0
	state.nepotisme_used_this_station[GameEnums.PlayerId.RED] = false
	state.nepotisme_used_this_station[GameEnums.PlayerId.PURPLE] = false
	state.trafic_infamy_used_this_station[GameEnums.PlayerId.RED] = false
	state.trafic_infamy_used_this_station[GameEnums.PlayerId.PURPLE] = false
	state.favori_used_this_station[GameEnums.PlayerId.RED] = false
	state.favori_used_this_station[GameEnums.PlayerId.PURPLE] = false
	state.paranoia_used_this_station[GameEnums.PlayerId.RED] = false
	state.paranoia_used_this_station[GameEnums.PlayerId.PURPLE] = false
	state.appetit_offcontrol_used_this_station[GameEnums.PlayerId.RED] = false
	state.appetit_offcontrol_used_this_station[GameEnums.PlayerId.PURPLE] = false
	# Dénonciation scandale block is station-scoped: reset at station start.
	state.denonciation_blocked_domain[GameEnums.PlayerId.RED] = -1
	state.denonciation_blocked_domain[GameEnums.PlayerId.PURPLE] = -1
	# Intrigue scandale grant (seal without net domination) is station-scoped.
	state.intrigue_seal_grant[GameEnums.PlayerId.RED] = -1
	state.intrigue_seal_grant[GameEnums.PlayerId.PURPLE] = -1
	# Obéissance: scandale flag resets each station; re-activate for infamy holders.
	state.obeissance_acts_first[GameEnums.PlayerId.RED] = false
	state.obeissance_acts_first[GameEnums.PlayerId.PURPLE] = false
	for p in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		if state.find_transgression_instance(p, TransgressionData.T_OBEISSANCE, GameEnums.TransgressionFace.INFAMIE) != null:
			state.obeissance_acts_first[p] = true
	# Mascarade de velours infamy: auto-move 1 corruption at station start.
	if station != GameEnums.StationId.EXORCISME:
		_apply_mascarade_effect()
	# Free exploitation for stations I-V (queued as pending decisions).
	if station != GameEnums.StationId.EXORCISME:
		_queue_free_exploitation_decisions()


func _pick_initiative() -> int:
	if state.obeissance_acts_first.get(GameEnums.PlayerId.RED, false):
		return GameEnums.PlayerId.RED
	if state.obeissance_acts_first.get(GameEnums.PlayerId.PURPLE, false):
		return GameEnums.PlayerId.PURPLE
	if state.initiative_override.has(state.current_station):
		return state.initiative_override[state.current_station]
	return GameEnums.STATION_INITIATIVE[state.current_station]


func _apply_mascarade_effect() -> void:
	for p in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		var ti: GameState.TransgressionInstance = state.find_transgression_instance(p, TransgressionData.T_MASCARADE, GameEnums.TransgressionFace.INFAMIE)
		if ti == null:
			continue
		# Auto-move 1 corruption from domain with most to domain with fewest.
		var best_from: int = -1
		var best_count: int = 0
		var best_to: int = -1
		var worst_count: int = 9999
		for d_id in DomainData.DOMAINS:
			var c: int = state.corruption_in(d_id, p)
			if c > best_count:
				best_count = c
				best_from = d_id
			if c < worst_count:
				worst_count = c
				best_to = d_id
		if best_from >= 0 and best_to >= 0 and best_from != best_to and best_count >= 1:
			state.set_corruption_in(best_from, p, state.corruption_in(best_from, p) - 1)
			state.set_corruption_in(best_to, p, state.corruption_in(best_to, p) + 1)
			state.add_log("Infamie Mascarade de velours : %s déplace 1 Corruption de %s vers %s." %
				[GameEnums.player_name(p), GameEnums.DOMAIN_NAMES[best_from], GameEnums.DOMAIN_NAMES[best_to]])


func _queue_free_exploitation_decisions() -> void:
	# Initiative player picks first.
	var _init_player: int = state.initiative_override.get(state.current_station, GameEnums.STATION_INITIATIVE[state.current_station])
	var order: Array = [_init_player, GameEnums.opponent(_init_player)]
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
	# If the queue is empty and we were waiting to advance the station, try.
	# (Will no-op if the liturgy dialog hasn't been acknowledged yet.)
	_try_advance_after_liturgy()
	_check_bot_turn()
	return ActionResolver.ok("Décision résolue.")


# --- For tests / debug ---
func force_advance_to_exorcism() -> void:
	while state.current_station < GameEnums.StationId.EXORCISME and not state.game_over:
		_drain_pending_decisions()
		state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
		_pulse_actions_done[GameEnums.PlayerId.RED] = true
		_pulse_actions_done[GameEnums.PlayerId.PURPLE] = true
		_end_pulse()
		if not pending_liturgy.is_empty():
			acknowledge_liturgy()
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
				_try_advance_after_liturgy()
			else:
				var pick := {"kind": avail[0]}
				if avail[0] != "lose2":
					pick["domain"] = _find_confession_domain(dec.player, avail[0])
				resolve_decision(pick)
		else:
			break


func _check_bot_turn() -> void:
	# Headless / bot-vs-bot path: drive the whole bot turn synchronously.
	# The Godot UI sets auto_bot = false and instead calls step_bot_once()
	# itself, one move per timer tick, so each move can be animated.
	if not auto_bot:
		return
	if _bot_running:
		return
	_bot_running = true
	while step_bot_once():
		pass
	_bot_running = false


# True when the next thing the engine is waiting on is a bot's move (an
# action by a bot-controlled active player, or a pending decision owned by
# a bot). Side-effect-free — the UI uses it to decide whether to arm its
# step timer without actually mutating state.
func bot_should_act() -> bool:
	if state.has_pending_decisions():
		return state.bot_for_player.has(state.pending_decisions[0].player)
	if state.game_over or not pending_liturgy.is_empty():
		return false
	if not active_player_must_act():
		return false
	return state.bot_for_player.has(state.active_player)


# Applies exactly ONE bot move (one drained decision, or one chosen action)
# and returns true if it did something. Returns false when it's not a bot's
# turn / nothing is actionable — the single source of truth for bot play,
# shared by the synchronous _check_bot_turn() loop above and the UI's paced
# stepping. Re-entrancy from perform_action() -> _check_bot_turn() is a
# no-op here because auto_bot is false in the UI and _bot_running guards
# the headless loop.
func step_bot_once() -> bool:
	if state.has_pending_decisions():
		var dec: GameState.PendingDecision = state.pending_decisions[0]
		if not state.bot_for_player.has(dec.player):
			return false
		_drain_one_for_bot(dec)
		return true
	if state.game_over or not pending_liturgy.is_empty():
		return false
	if not active_player_must_act():
		return false
	if not state.bot_for_player.has(state.active_player):
		return false
	var bot: BotBase = state.bot_for_player[state.active_player]
	var decision := bot.pick_action(state, state.active_player)
	var result := perform_action(decision["action_id"], decision.get("kwargs", {}))
	return result.get("ok", false)


func _drain_one_for_bot(dec: GameState.PendingDecision) -> void:
	if dec.kind == "free_exploit":
		var opts: Array = dec.data.get("options", [])
		if opts.is_empty():
			resolve_decision({"skip": true})
		else:
			# Let the owning bot evaluate each option (greedy 1-ply Eval) and
			# pick the best domain, or skip — instead of blindly taking opts[0].
			var bot: BotBase = state.bot_for_player.get(dec.player)
			var chosen: int = bot.pick_free_exploit(state, dec.player, opts) if bot != null else int(opts[0])
			if chosen < 0:
				resolve_decision({"skip": true})
			else:
				resolve_decision({"domain": chosen})
	elif dec.kind == "confession":
		var avail := LiturgyResolver.available_confession_kinds(state, dec)
		if avail.is_empty():
			state.pending_decisions.pop_front()
			_try_advance_after_liturgy()
		else:
			var pick := {"kind": avail[0]}
			if avail[0] != "lose2":
				pick["domain"] = _find_confession_domain(dec.player, avail[0])
			resolve_decision(pick)
	else:
		state.pending_decisions.pop_front()


func _find_confession_domain(player: int, kind: String) -> int:
	for d_id in DomainData.DOMAINS:
		if state.controller_of(d_id) != player:
			continue
		if kind == "penitence" and not state.is_in_penitence(d_id):
			return d_id
		if kind == "fissure" and state.is_sealed(d_id) and state.domain(d_id).seal_owner == player:
			return d_id
	return -1
