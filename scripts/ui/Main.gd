extends Control
# Main UI controller. Builds the board procedurally and orchestrates action
# selection. The UI is intentionally minimal — placeholder text-driven.

var state: GameState
var manager: TurnManager

# Action selection state
var pending_action: int = -1
var pending_kwargs: Dictionary = {}

# Top-level UI nodes (created in _ready)
@onready var root_h: HBoxContainer = $Root
@onready var board_v: VBoxContainer = $Root/BoardArea
@onready var side_v: VBoxContainer = $Root/SideArea
@onready var log_label: RichTextLabel = $Root/SideArea/LogScroll/LogLabel
@onready var status_label: Label = $Root/BoardArea/StatusBar/StatusLabel
@onready var domains_grid: GridContainer = $Root/BoardArea/DomainsGrid
@onready var actions_box: HFlowContainer = $Root/BoardArea/ActionsBox
@onready var prompt_label: Label = $Root/BoardArea/PromptLabel
@onready var prompt_buttons: HFlowContainer = $Root/BoardArea/PromptButtons
@onready var debug_label: RichTextLabel = $Root/SideArea/DebugLabel
@onready var transgressions_box: VBoxContainer = $Root/SideArea/TransgressionsBox

const SAVE_PATH := "user://save_game.json"


func _ready() -> void:
	new_game()


func new_game() -> void:
	state = GameState.new()
	manager = TurnManager.new(state)
	pending_action = -1
	pending_kwargs.clear()
	_rebuild_all()


func _rebuild_all() -> void:
	_render_status()
	_render_domains()
	_render_actions()
	_render_prompt()
	_render_log()
	_render_debug()
	_render_transgressions()


# --- Status bar -----------------------------------------------------------

func _render_status() -> void:
	if state.game_over:
		status_label.text = "PARTIE TERMINÉE — Vainqueur : %s. %s" % [GameEnums.player_name(state.winner), state.winner_reason]
		return
	var st := GameEnums.STATION_NAMES[state.current_station]
	var p := GameEnums.STATION_PULSES[state.current_station]
	var init_p := GameEnums.STATION_INITIATIVE[state.current_station]
	status_label.text = "Station %s — Pulsation %d/%d — Joueur actif : %s — Initiative : %s — Ascendant : %d" % [
		st, state.current_pulse, p,
		GameEnums.player_name(state.active_player),
		GameEnums.player_name(init_p),
		state.ascendant,
	]


# --- Domains grid ---------------------------------------------------------

func _render_domains() -> void:
	for c in domains_grid.get_children():
		c.queue_free()
	for d_id in DomainData.DOMAINS:
		var panel := _make_domain_panel(d_id)
		domains_grid.add_child(panel)


func _make_domain_panel(d_id: int) -> PanelContainer:
	var d := state.domain(d_id)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 220)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [GameEnums.DOMAIN_NAMES[d_id], DomainData.production_label(d_id)]
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	v.add_child(name_label)
	var corr_label := Label.new()
	corr_label.text = "Rouge : %d   Bleu : %d" % [d.red_corruption, d.blue_corruption]
	v.add_child(corr_label)
	var ctrl := state.controller_of(d_id)
	var ctrl_label := Label.new()
	if ctrl == GameEnums.PlayerId.NONE:
		ctrl_label.text = "Contrôle : aucun"
	else:
		var dom := " (Domination nette)" if state.has_net_domination(d_id, ctrl) else ""
		ctrl_label.text = "Contrôle : %s%s" % [GameEnums.player_name(ctrl), dom]
	v.add_child(ctrl_label)
	if state.is_sealed(d_id):
		var seal := Label.new()
		seal.text = "[Sceau %s]" % GameEnums.player_name(d.seal_owner)
		seal.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		v.add_child(seal)
	if state.is_in_penitence(d_id):
		var pen := Label.new()
		pen.text = "Pénitence (Station %s)" % GameEnums.STATION_NAMES.get(d.penitence_until_station, "?")
		pen.add_theme_color_override("font_color", Color(0.6, 0.8, 1))
		v.add_child(pen)
	for ti in d.scandals:
		var sc := Label.new()
		sc.text = "  Scandale (%s) %s" % [GameEnums.player_name(ti.owner), TransgressionData.name_of(ti.def_id)]
		sc.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5) if ti.owner == GameEnums.PlayerId.RED else Color(0.6, 0.7, 1))
		v.add_child(sc)
	for ti in d.infamies:
		var inf := Label.new()
		inf.text = "  INFAMIE (%s) %s" % [GameEnums.player_name(ti.owner), TransgressionData.name_of(ti.def_id)]
		inf.add_theme_color_override("font_color", Color(1, 0.3, 0.3) if ti.owner == GameEnums.PlayerId.RED else Color(0.4, 0.5, 1))
		v.add_child(inf)
	# Click handler when a domain is being targeted
	var btn := Button.new()
	btn.text = "Sélectionner %s" % GameEnums.DOMAIN_NAMES[d_id]
	btn.pressed.connect(func(): _on_domain_selected(d_id))
	v.add_child(btn)
	return panel


# --- Actions --------------------------------------------------------------

func _render_actions() -> void:
	for c in actions_box.get_children():
		c.queue_free()
	if state.game_over:
		return
	# When a decision is pending, normal actions are disabled.
	if state.has_pending_decisions():
		var hint := Label.new()
		hint.text = "(Décision en attente — voir le panneau ci-dessous.)"
		actions_box.add_child(hint)
		return
	var p := state.active_player
	var actions := [
		[GameEnums.ActionId.INVESTIR, "Investir"],
		[GameEnums.ActionId.EXPLOITER, "Exploiter"],
		[GameEnums.ActionId.PROVOQUER, "Provoquer Transgression"],
		[GameEnums.ActionId.AMPLIFIER, "Amplifier Transgression"],
		[GameEnums.ActionId.SCELLER, "Sceller"],
		[GameEnums.ActionId.FISSURER, "Fissurer"],
		[GameEnums.ActionId.ENTRAVER, "Entraver"],
		[GameEnums.ActionId.PASSER, "Passer"],
	]
	for a in actions:
		var btn := Button.new()
		btn.text = a[1]
		btn.disabled = not _is_action_potentially_legal(a[0], p)
		btn.pressed.connect(func(): _on_action_chosen(a[0]))
		actions_box.add_child(btn)


func _is_action_potentially_legal(action: int, p: int) -> bool:
	# Returns true if the action could be legal for SOME target.
	match action:
		GameEnums.ActionId.INVESTIR:
			if state.available_corruption[p] < 1: return false
			for d_id in DomainData.DOMAINS:
				if GameRules.can_investir(state, p, d_id): return true
			return false
		GameEnums.ActionId.EXPLOITER:
			for d_id in DomainData.DOMAINS:
				if GameRules.can_exploiter(state, p, d_id): return true
			return false
		GameEnums.ActionId.PROVOQUER:
			for tid in TransgressionData.ALL_IDS:
				if GameRules.can_provoquer(state, p, tid): return true
			return false
		GameEnums.ActionId.AMPLIFIER:
			for tid in TransgressionData.ALL_IDS:
				if GameRules.can_amplifier(state, p, tid): return true
			return false
		GameEnums.ActionId.SCELLER:
			for d_id in DomainData.DOMAINS:
				if GameRules.can_sceller(state, p, d_id): return true
			return false
		GameEnums.ActionId.FISSURER:
			for d_id in DomainData.DOMAINS:
				if GameRules.can_fissurer(state, p, d_id): return true
			return false
		GameEnums.ActionId.ENTRAVER:
			for st_id in [state.current_station, state.current_station + 1, state.current_station + 2]:
				if GameRules.can_entraver(state, p, st_id): return true
			return false
		GameEnums.ActionId.PASSER:
			return true
	return false


func _on_action_chosen(action: int) -> void:
	pending_action = action
	pending_kwargs.clear()
	if action == GameEnums.ActionId.PASSER:
		_commit_action()
		return
	_render_prompt()


# --- Prompt panel ---------------------------------------------------------

func _render_prompt() -> void:
	for c in prompt_buttons.get_children():
		c.queue_free()
	# A pending decision (free exploit / confession) takes priority over actions.
	if state.has_pending_decisions():
		_render_decision_prompt()
		return
	if pending_action < 0:
		prompt_label.text = "Choisissez une action."
		return
	var p := state.active_player
	match pending_action:
		GameEnums.ActionId.INVESTIR:
			prompt_label.text = "Investir : choisissez un Domaine."
			for d_id in DomainData.DOMAINS:
				if GameRules.can_investir(state, p, d_id):
					_add_prompt_button(GameEnums.DOMAIN_NAMES[d_id], func(): _commit_action({"domain": d_id}))
		GameEnums.ActionId.EXPLOITER:
			prompt_label.text = "Exploiter : choisissez un Domaine contrôlé."
			for d_id in DomainData.DOMAINS:
				if GameRules.can_exploiter(state, p, d_id):
					_add_prompt_button(GameEnums.DOMAIN_NAMES[d_id], func(): _commit_action({"domain": d_id}))
		GameEnums.ActionId.SCELLER:
			prompt_label.text = "Sceller : choisissez un Domaine."
			for d_id in DomainData.DOMAINS:
				if GameRules.can_sceller(state, p, d_id):
					_add_prompt_button(GameEnums.DOMAIN_NAMES[d_id], func(): _commit_action({"domain": d_id}))
		GameEnums.ActionId.FISSURER:
			prompt_label.text = "Fissurer : choisissez un Domaine scellé adverse."
			for d_id in DomainData.DOMAINS:
				if GameRules.can_fissurer(state, p, d_id):
					var cost := GameRules.fissurer_total_cost(state, p, d_id)
					_add_prompt_button("%s (coût %d)" % [GameEnums.DOMAIN_NAMES[d_id], cost],
						func(): _commit_action({"domain": d_id}))
		GameEnums.ActionId.PROVOQUER:
			prompt_label.text = "Provoquer une Transgression."
			for tid in TransgressionData.ALL_IDS:
				if GameRules.can_provoquer(state, p, tid):
					var cost := GameRules.transgression_scandal_cost(state, p, tid)
					_add_prompt_button("%s (coût %d)" % [TransgressionData.name_of(tid), cost],
						func(): _commit_action({"def_id": tid}))
		GameEnums.ActionId.AMPLIFIER:
			prompt_label.text = "Amplifier une Transgression."
			for tid in TransgressionData.ALL_IDS:
				if GameRules.can_amplifier(state, p, tid):
					var def: Dictionary = TransgressionData.get_def(tid)
					_add_prompt_button("%s (coût %d)" % [def["name"], int(def["amplification_cost"])],
						func(): _commit_action({"def_id": tid}))
		GameEnums.ActionId.ENTRAVER:
			prompt_label.text = "Entraver : choisissez la Réponse à entraver."
			for st_id in [state.current_station, state.current_station + 1, state.current_station + 2]:
				if GameRules.can_entraver(state, p, st_id):
					var cost := GameRules.entrave_cost(state, p, st_id)
					_add_prompt_button("%s (coût %d)" % [GameEnums.STATION_NAMES[st_id], cost],
						func(): _commit_action({"station": st_id}))
	_add_prompt_button("Annuler", func(): _cancel_pending())


func _add_prompt_button(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	prompt_buttons.add_child(b)


func _render_decision_prompt() -> void:
	var dec = state.pending_decisions[0]
	if dec.kind == "free_exploit":
		var opts: Array = dec.data.get("options", [])
		prompt_label.text = "Exploitation gratuite — %s : choisissez un Domaine que vous contrôlez." % GameEnums.player_name(dec.player)
		for d_id in opts:
			var prod := GameRules.production_of(state, d_id, dec.player)
			_add_prompt_button("%s (+%d)" % [GameEnums.DOMAIN_NAMES[d_id], prod],
				func(): _resolve_decision({"domain": d_id}))
		_add_prompt_button("Passer", func(): _resolve_decision({"skip": true}))
	elif dec.kind == "confession":
		var impedita: bool = dec.data.get("impedita", false)
		prompt_label.text = "Confession (%s) — %s : choisissez %d pénitence(s) %s. Déjà choisies : %s" % [
			"Impedita" if impedita else "In Integro",
			GameEnums.player_name(dec.player),
			dec.picks_remaining,
			"différente(s)" if not impedita else "",
			", ".join(dec.picks_done) if dec.picks_done.size() > 0 else "—",
		]
		var avail := LiturgyResolver.available_confession_kinds(state, dec)
		if "lose2" in avail:
			_add_prompt_button("Perdre 2 Corruptions disponibles",
				func(): _resolve_decision({"kind": "lose2"}))
		if "penitence" in avail:
			for d_id in DomainData.DOMAINS:
				if state.controller_of(d_id) == dec.player and not state.is_in_penitence(d_id):
					_add_prompt_button("Pénitence sur %s" % GameEnums.DOMAIN_NAMES[d_id],
						func(): _resolve_decision({"kind": "penitence", "domain": d_id}))
		if "fissure" in avail:
			for d_id in DomainData.DOMAINS:
				if state.controller_of(d_id) == dec.player and state.is_sealed(d_id) and state.domain(d_id).seal_owner == dec.player:
					_add_prompt_button("Fissurer son Sceau sur %s" % GameEnums.DOMAIN_NAMES[d_id],
						func(): _resolve_decision({"kind": "fissure", "domain": d_id}))
		if avail.is_empty():
			# No applicable penitence available — let the player skip.
			_add_prompt_button("(Aucune pénitence applicable — passer)",
				func(): _force_pop_decision())


func _resolve_decision(picks: Dictionary) -> void:
	var r := manager.resolve_decision(picks)
	if not r.get("ok", false):
		state.add_log("[DÉCISION REFUSÉE] " + r.get("message", "?"))
	_rebuild_all()


func _force_pop_decision() -> void:
	# Used when no penitence is applicable; pop and continue.
	if state.has_pending_decisions():
		state.pending_decisions.pop_front()
		# If we were waiting to advance and the queue is now empty, do it.
		if not state.has_pending_decisions() and manager._pending_advance_to_station >= 0:
			var s = manager._pending_advance_to_station
			manager._pending_advance_to_station = -1
			manager._advance_to_station(s)
	_rebuild_all()


func _cancel_pending() -> void:
	pending_action = -1
	pending_kwargs.clear()
	_render_prompt()


func _on_domain_selected(d_id: int) -> void:
	# Currently used as a shortcut to set the kwarg when a button is more convenient.
	if pending_action in [GameEnums.ActionId.INVESTIR, GameEnums.ActionId.EXPLOITER,
		GameEnums.ActionId.SCELLER, GameEnums.ActionId.FISSURER]:
		_commit_action({"domain": d_id})


func _commit_action(kw: Dictionary = {}) -> void:
	var action := pending_action
	pending_action = -1
	var result := manager.perform_action(action, kw)
	if not result.get("ok", false):
		state.add_log("[ACTION REFUSÉE] " + result.get("message", "?"))
	_rebuild_all()


# --- Side panels ----------------------------------------------------------

func _render_log() -> void:
	var lines := state.log
	var max_lines := 40
	var start := max(0, lines.size() - max_lines)
	var s := ""
	for i in range(start, lines.size()):
		s += String(lines[i]) + "\n"
	log_label.text = s
	log_label.scroll_to_line(log_label.get_line_count())


func _render_debug() -> void:
	var rep := EndGameResolver.check_rupture(state)
	var transg := []
	for d_id in DomainData.DOMAINS:
		if state.is_transgressed(d_id):
			transg.append(GameEnums.DOMAIN_NAMES[d_id])
	var sealed_list := []
	for d_id in DomainData.DOMAINS:
		if state.is_sealed(d_id):
			sealed_list.append("%s (%s)" % [GameEnums.DOMAIN_NAMES[d_id], GameEnums.player_name(state.domain(d_id).seal_owner)])
	var vol := state.domain(GameEnums.DomainId.VOLONTE)
	var fiat := EndGameResolver.check_fiat_tenebris(state)
	var s := "[b]DEBUG RÈGLES[/b]\n"
	s += "Rouge : %d Corruptions disponibles\n" % state.available_corruption[GameEnums.PlayerId.RED]
	s += "Bleu : %d Corruptions disponibles\n" % state.available_corruption[GameEnums.PlayerId.BLUE]
	s += "Profondeur : %s\n" % ("✓" if rep.profondeur else "✗")
	s += "Étendue : %s\n" % ("✓" if rep.etendue else "✗")
	s += "Ancrage : %s\n" % ("✓" if rep.ancrage else "✗")
	s += "Rupture complète : %s\n" % ("✓" if rep.complete else "✗")
	s += "Fiat Tenebris possible : %s\n" % (GameEnums.player_name(fiat) if fiat != GameEnums.PlayerId.NONE else "non")
	s += "Volonté scellée par : %s\n" % GameEnums.player_name(vol.seal_owner)
	var transg_by := []
	for ti in vol.scandals + vol.infamies:
		transg_by.append(GameEnums.player_name(ti.owner))
	s += "Volonté transgressée par : %s\n" % (", ".join(transg_by) if transg_by.size() > 0 else "—")
	s += "Domaines transgressés : %s\n" % (", ".join(transg) if transg.size() > 0 else "—")
	s += "Domaines scellés : %s\n" % (", ".join(sealed_list) if sealed_list.size() > 0 else "—")
	debug_label.text = s


func _render_transgressions() -> void:
	for c in transgressions_box.get_children():
		c.queue_free()
	for player in [GameEnums.PlayerId.RED, GameEnums.PlayerId.BLUE]:
		var lbl := Label.new()
		lbl.text = "[%s] Transgressions :" % GameEnums.player_name(player)
		lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if player == GameEnums.PlayerId.RED else Color(0.5, 0.6, 1))
		transgressions_box.add_child(lbl)
		var any := false
		for d_id in DomainData.DOMAINS:
			var d := state.domain(d_id)
			for ti in d.scandals:
				if ti.owner == player:
					var l := Label.new()
					l.text = "  • %s — Scandale en %s" % [TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]]
					transgressions_box.add_child(l)
					any = true
			for ti in d.infamies:
				if ti.owner == player:
					var l2 := Label.new()
					l2.text = "  • %s — INFAMIE en %s" % [TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]]
					transgressions_box.add_child(l2)
					any = true
		if not any:
			var none := Label.new()
			none.text = "  (aucune)"
			transgressions_box.add_child(none)


# --- Debug buttons --------------------------------------------------------

func _on_btn_new_game() -> void: new_game()
func _on_btn_force_next_station() -> void:
	if state.game_over: return
	state.current_pulse = GameEnums.STATION_PULSES[state.current_station]
	# Mark both players done and wrap up
	manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
	manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
	manager._end_pulse()
	_rebuild_all()
func _on_btn_force_exorcism() -> void:
	if state.game_over: return
	manager.force_advance_to_exorcism()
	# Then resolve the exorcism finale
	state.current_pulse = GameEnums.STATION_PULSES[GameEnums.StationId.EXORCISME]
	manager._pulse_actions_done[GameEnums.PlayerId.RED] = true
	manager._pulse_actions_done[GameEnums.PlayerId.BLUE] = true
	manager._end_pulse()
	_rebuild_all()
func _on_btn_add_corruption() -> void:
	if state.game_over: return
	state.add_corruption_pool(state.active_player, 1)
	state.add_log("[DEBUG] +1 Corruption à %s." % GameEnums.player_name(state.active_player))
	_rebuild_all()
func _on_btn_run_tests() -> void:
	var runner := RulesTestRunner.new()
	var res := runner.run_all()
	state.add_log("=== TESTS : %d/%d PASS, %d FAIL ===" % [res["pass"], res["total"], res["fail"]])
	for line in res["lines"]:
		state.add_log(String(line))
	_render_log()
func _on_btn_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		state.add_log("[DEBUG] Sauvegarde impossible.")
		_render_log()
		return
	f.store_string(JSON.stringify(state.to_dict()))
	f.close()
	state.add_log("[DEBUG] Sauvegarde effectuée : %s" % SAVE_PATH)
	_render_log()
func _on_btn_load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		state.add_log("[DEBUG] Pas de sauvegarde à charger.")
		_render_log()
		return
	var txt := f.get_as_text()
	f.close()
	var d = JSON.parse_string(txt)
	if d == null:
		state.add_log("[DEBUG] Sauvegarde corrompue.")
		_render_log()
		return
	state = GameState.new()
	state.from_dict(d)
	manager = TurnManager.new(state, false)
	_rebuild_all()
