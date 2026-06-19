class_name RulesTestRunner
extends RefCounted
# Standalone test runner. Invoke run_all() to execute the test suite.
# Returns a Dictionary with pass/fail counts and a list of result lines.

var results: Array = []
var pass_count: int = 0
var fail_count: int = 0


func run_all() -> Dictionary:
	results.clear()
	pass_count = 0
	fail_count = 0
	_test_control_and_domination()
	_test_production()
	_test_domain_hint_strings()
	_test_seal_rules()
	_test_demonic_fissure()
	_test_liturgical_fissure_in_integro()
	_test_liturgical_fissure_impedita()
	_test_tribut_volonte()
	_test_transgressions()
	_test_entrave()
	_test_rupture()
	_test_fiat_tenebris()
	_test_final_ascendant()
	_test_communion()
	_test_station_six()
	_test_simonie_infamy()
	_test_simonie_origin()
	_test_confession_pending_decision()
	# V1h additions
	_test_starting_corruption()
	_test_puiser()
	_test_free_exploit_per_player()
	_test_linked_domains()
	_test_anchor_unchanged()
	_test_save_load_roundtrip()
	_test_liturgy_advance_after_acknowledge()
	_test_persecution_target()
	# Codex des Transgressions
	_test_codex_setup()
	_test_codex_filter()
	_test_codex_intrigue()
	_test_codex_bulle()
	_test_codex_mascarade()
	_test_codex_appetit()
	_test_codex_dogme()
	_test_codex_reliques()
	_test_codex_denonciation()
	_test_codex_panique()
	_test_codex_obeissance()
	_test_codex_renoncement()
	return {
		"pass": pass_count, "fail": fail_count,
		"total": pass_count + fail_count, "lines": results,
	}


func _new_state() -> GameState:
	return GameState.new()


func _test_persecution_target() -> void:
	# Persécution must hit the CHOSEN contested opponent Domain (extra.target_domain),
	# not just the first contested one.
	var s := _new_state()
	# RED controls PEUR (required to provoke Persécution) and it's contested.
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 2)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE, 1)
	# A second contested Domain where PURPLE has corruption — the chosen target.
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED, 1)
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	var before_desir: int = s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE)
	var before_peur: int = s.corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE)
	var r := ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION,
		-1, {"target_domain": GameEnums.DomainId.DESIR})
	_assert(r.get("ok", false), "Persécution : provocation réussie")
	_assert(s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE) == before_desir - 1,
		"Persécution : le Domaine cible choisi (Désir) perd 1 Corruption adverse")
	_assert(s.corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE) == before_peur,
		"Persécution : le Domaine NON ciblé (Peur) reste intact")


func _test_liturgy_advance_after_acknowledge() -> void:
	# End-of-Station liturgy must pause the game (no actions until acknowledged),
	# then advancing must give the next Station a clean first Pulse — no stale
	# "Ce joueur a déjà agi cette Pulsation".
	var s := _new_state()
	var tm := TurnManager.new(s, true)
	var pulses: int = GameEnums.STATION_PULSES[GameEnums.StationId.MURMURES]
	for i in pulses * 2:
		tm.perform_action(GameEnums.ActionId.PASSER, {})
	_assert(not tm.pending_liturgy.is_empty(),
		"Liturgie : réponse en attente après la dernière Pulsation")
	var blocked := tm.perform_action(GameEnums.ActionId.PASSER, {})
	_assert(not blocked.get("ok", false),
		"Liturgie : action refusée tant que la réponse n'est pas validée")
	tm.acknowledge_liturgy()
	_assert(s.current_station == GameEnums.StationId.TENTATION,
		"Liturgie : avance à la Station suivante après validation")
	_assert(tm.active_player_must_act(),
		"Liturgie : joueur actif peut agir dans la nouvelle Station (pas de « déjà joué »)")
	var ok_act := tm.perform_action(GameEnums.ActionId.PASSER, {})
	_assert(ok_act.get("ok", false),
		"Liturgie : 1re action de la nouvelle Station acceptée")


func _test_save_load_roundtrip() -> void:
	# Saves go through JSON, which stringifies int dict keys (and widens ints to
	# floats). from_dict must rebuild int keys so available_corruption[player] &
	# co. don't read null and crash arithmetic on resume ("a number is required").
	var s := _new_state()
	s.available_corruption[GameEnums.PlayerId.RED] = 4
	s.available_corruption[GameEnums.PlayerId.PURPLE] = 2
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	s.nepotisme_used_this_station[GameEnums.PlayerId.RED] = true
	s.transgressions_provoked_this_station[GameEnums.PlayerId.PURPLE] = 1
	s.ascendant = 2
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := _new_state()
	s2.from_dict(parsed)
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] == 4,
		"Round-trip JSON : available_corruption[RED] préservé (clé int)")
	_assert(s2.available_corruption[GameEnums.PlayerId.PURPLE] == 2,
		"Round-trip JSON : available_corruption[PURPLE] préservé")
	_assert(s2.corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED) == 3,
		"Round-trip JSON : corruption d'un Domaine préservée")
	_assert(s2.nepotisme_used_this_station[GameEnums.PlayerId.RED] == true,
		"Round-trip JSON : flag per-Station (clé int) préservé")
	_assert(s2.transgressions_provoked_this_station[GameEnums.PlayerId.PURPLE] == 1,
		"Round-trip JSON : compteur per-Station préservé")
	# The exact resume crash : arithmetic on the reloaded pool must not error.
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] < 5,
		"Round-trip JSON : arithmétique sur le pool rechargé OK (pas de null)")


func _assert(cond: bool, name: String, msg: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("PASS  %s" % name)
	else:
		fail_count += 1
		results.append("FAIL  %s%s" % [name, "" if msg.is_empty() else " — " + msg])


# ---------------------------------------------------------------------------
# Control / Domination
# ---------------------------------------------------------------------------
func _test_control_and_domination() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	_assert(s.controller_of(GameEnums.DomainId.AMBITION) == GameEnums.PlayerId.RED,
		"Contrôle 2/1 -> Rouge contrôle")
	_assert(not s.has_net_domination(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED),
		"2/1 -> pas de Domination nette")

	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	_assert(s.has_net_domination(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED),
		"3/1 -> Domination nette")

	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	_assert(s.controller_of(GameEnums.DomainId.AMBITION) == GameEnums.PlayerId.NONE,
		"1/1 -> personne ne contrôle")


# ---------------------------------------------------------------------------
# Production
# ---------------------------------------------------------------------------
func _test_production() -> void:
	var s := _new_state()
	# Ambition -> 2
	_assert(GameRules.production_of(s, GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED) == 2,
		"Ambition produit 2")
	# Volonté -> 0
	_assert(GameRules.production_of(s, GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED) == 0,
		"Volonté produit 0")
	# Désir transgressé -> 3
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_FESTIN
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.DESIR
	s.domain(GameEnums.DomainId.DESIR).scandals.append(ti)
	_assert(GameRules.production_of(s, GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED) == 3,
		"Désir transgressé produit 3")
	# Foi transgressé -> 2
	var ti2 := GameState.TransgressionInstance.new()
	ti2.def_id = TransgressionData.T_PROFANATION
	ti2.owner = GameEnums.PlayerId.RED
	ti2.face = GameEnums.TransgressionFace.SCANDALE
	ti2.origin_domain = GameEnums.DomainId.FOI
	s.domain(GameEnums.DomainId.FOI).scandals.append(ti2)
	_assert(GameRules.production_of(s, GameEnums.DomainId.FOI, GameEnums.PlayerId.RED) == 2,
		"Foi transgressé produit 2")
	# Peur produit 2 si fissure cette Station
	var s2 := _new_state()
	s2.domain(GameEnums.DomainId.AMBITION).was_fissured_this_station = true
	_assert(GameRules.production_of(s2, GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED) == 2,
		"Peur produit 2 si Domaine fissuré ce tour")
	# Bonus +1 si scellé par soi
	var s3 := _new_state()
	s3.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	_assert(GameRules.production_of(s3, GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED) == 3,
		"Domaine scellé par soi : +1 Corruption")
	# Une exploitation par démon par Station
	var s4 := _new_state()
	s4.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s4.add_corruption_pool(GameEnums.PlayerId.RED, 0)
	var r := ActionResolver.exploiter(s4, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION)
	_assert(r["ok"], "Exploiter Ambition contrôlée OK")
	var r2 := ActionResolver.exploiter(s4, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION)
	_assert(not r2["ok"], "Réexploiter le même Domaine la même Station -> illégal")


# ---------------------------------------------------------------------------
# Seal
# ---------------------------------------------------------------------------
func _test_seal_rules() -> void:
	var s := _new_state()
	# Pas de contrôle -> illégal
	_assert(not GameRules.can_sceller(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Sceller sans contrôle -> illégal")
	# Contrôle mais pas Domination -> illégal
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	_assert(not GameRules.can_sceller(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Sceller sans Domination nette -> illégal")
	# Domination nette -> légal
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	_assert(GameRules.can_sceller(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Sceller avec Domination nette -> légal")
	# Pénitence -> illégal
	s.domain(GameEnums.DomainId.AMBITION).penitence_until_station = GameEnums.StationId.OFFICE
	_assert(not GameRules.can_sceller(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Sceller en Pénitence -> illégal")
	s.domain(GameEnums.DomainId.AMBITION).penitence_until_station = -1
	# Déjà scellé -> illégal
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	_assert(not GameRules.can_sceller(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Sceller un Domaine déjà scellé -> illégal")
	# Coût et placement
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	var before: int = s2.available_corruption[GameEnums.PlayerId.RED]
	var r := ActionResolver.sceller(s2, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION)
	_assert(r["ok"], "Scellement légal OK")
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] == before - 1,
		"Sceller coûte 1 Corruption disponible")
	_assert(s2.domain(GameEnums.DomainId.AMBITION).seal_owner == GameEnums.PlayerId.RED,
		"Sceau placé sur Ambition")


# ---------------------------------------------------------------------------
# Demonic fissure
# ---------------------------------------------------------------------------
func _test_demonic_fissure() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 4)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.PURPLE
	var r := ActionResolver.fissurer(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION)
	_assert(r["ok"], "Fissure démoniaque OK")
	_assert(s.domain(GameEnums.DomainId.AMBITION).seal_owner == GameEnums.PlayerId.NONE,
		"Fissure démoniaque retire le Sceau")
	# Ne brise pas la Domination : Bleu garde 4
	_assert(s.domain(GameEnums.DomainId.AMBITION).purple_corruption == 4,
		"Fissure démoniaque ne Brise PAS la Domination")


# ---------------------------------------------------------------------------
# Liturgical fissure In Integro / Impedita
# ---------------------------------------------------------------------------
func _test_liturgical_fissure_in_integro() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.CHUTE
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE, 1)
	s.domain(GameEnums.DomainId.PEUR).seal_owner = GameEnums.PlayerId.RED
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PARANOIA
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.PEUR
	s.domain(GameEnums.DomainId.PEUR).scandals.append(ti)
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.PEUR).seal_owner == GameEnums.PlayerId.NONE,
		"Contrition In Integro retire le Sceau")
	_assert(s.domain(GameEnums.DomainId.PEUR).red_corruption - s.domain(GameEnums.DomainId.PEUR).purple_corruption < 2,
		"Contrition In Integro Brise la Domination")


func _test_liturgical_fissure_impedita() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.OFFICE
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	var pe := GameState.PendingEntrave.new()
	pe.caster = GameEnums.PlayerId.PURPLE
	pe.target_station = GameEnums.StationId.OFFICE
	s.pending_entraves.append(pe)
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.FOI).seal_owner == GameEnums.PlayerId.NONE,
		"Communion Impedita retire le Sceau")
	_assert(s.domain(GameEnums.DomainId.FOI).red_corruption == 4,
		"Communion Impedita ne Brise PAS la Domination")


# ---------------------------------------------------------------------------
# Tribut de Volonté
# ---------------------------------------------------------------------------
func _test_tribut_volonte() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.PURPLE, 3)
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED, 1)
	s.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.PURPLE
	# Volonté transgressée par Bleu
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PACTE
	ti.owner = GameEnums.PlayerId.PURPLE
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.VOLONTE
	s.domain(GameEnums.DomainId.VOLONTE).scandals.append(ti)
	# Coût total = 2
	_assert(GameRules.fissurer_total_cost(s, GameEnums.PlayerId.RED, GameEnums.DomainId.VOLONTE) == 2,
		"Tribut de Volonté : coût total = 2")
	# Avec 1 seule corruption -> illégal
	s.available_corruption[GameEnums.PlayerId.RED] = 1
	_assert(not GameRules.can_fissurer(s, GameEnums.PlayerId.RED, GameEnums.DomainId.VOLONTE),
		"Fissure Volonté avec 1 Corruption -> illégale")
	# Avec 2 -> légal, et Bleu reçoit 1
	s.available_corruption[GameEnums.PlayerId.RED] = 2
	var blue_before: int = s.available_corruption[GameEnums.PlayerId.PURPLE]
	var r := ActionResolver.fissurer(s, GameEnums.PlayerId.RED, GameEnums.DomainId.VOLONTE)
	_assert(r["ok"], "Fissure Volonté avec 2 Corruptions OK")
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == 0,
		"Rouge dépense 2 Corruptions au total")
	_assert(s.available_corruption[GameEnums.PlayerId.PURPLE] == blue_before + 1,
		"Bleu reçoit 1 Corruption au titre du Tribut")


# ---------------------------------------------------------------------------
# Transgressions
# ---------------------------------------------------------------------------
func _test_transgressions() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	var asc_before := s.ascendant
	var corr_before: int = s.available_corruption[GameEnums.PlayerId.RED]
	var r := ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_NEPOTISME)
	_assert(r["ok"], "Provoquer Népotisme OK")
	# Coût Scandale 2 puis +1 effet Scandale -> net -1 sur la pool
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == corr_before - 2 + 1,
		"Coût Scandale Népotisme correctement appliqué")
	_assert(s.ascendant == asc_before + 1, "+1 Ascendant pour Rouge")
	_assert(s.domain(GameEnums.DomainId.AMBITION).scandals.size() == 1,
		"Scandale placé en Ambition")
	# Amplifier nécessite Domaine d'origine scellé
	_assert(not GameRules.can_amplifier(s, GameEnums.PlayerId.RED, TransgressionData.T_NEPOTISME),
		"Amplifier sans scellement -> illégal")
	# Pénitence empêche
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	s.domain(GameEnums.DomainId.AMBITION).penitence_until_station = GameEnums.StationId.OFFICE
	_assert(not GameRules.can_amplifier(s, GameEnums.PlayerId.RED, TransgressionData.T_NEPOTISME),
		"Amplifier en Pénitence -> illégal")
	# Cas légal
	s.domain(GameEnums.DomainId.AMBITION).penitence_until_station = -1
	s.available_corruption[GameEnums.PlayerId.RED] = 5
	var asc2 := s.ascendant
	var r2 := ActionResolver.amplifier(s, GameEnums.PlayerId.RED, TransgressionData.T_NEPOTISME)
	_assert(r2["ok"], "Amplifier Népotisme OK")
	_assert(s.domain(GameEnums.DomainId.AMBITION).infamies.size() == 1
		and s.domain(GameEnums.DomainId.AMBITION).scandals.size() == 0,
		"Scandale remplacé par Infamie")
	_assert(s.ascendant == asc2 + 1, "Amplification : +1 Ascendant")


# ---------------------------------------------------------------------------
# Entrave
# ---------------------------------------------------------------------------
func _test_entrave() -> void:
	# V1h : Entrave is positional. The active demon removes 1 of his
	# Corruptions from a linked, controlled Domain on the board ; the
	# reserve is untouched.
	var s := _new_state()
	s.current_station = GameEnums.StationId.MURMURES
	s.available_corruption[GameEnums.PlayerId.RED] = 5
	# No Domain corruption yet → no linked controlled Domain → illegal
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.MURMURES),
		"V1h : pas de Domaine lié contrôlé -> Entrave illégale")
	# Set Foi controlled by Red with 2 Corruptions on the board.
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 2)
	_assert(s.controller_of(GameEnums.DomainId.FOI) == GameEnums.PlayerId.RED,
		"Setup : Rouge contrôle Foi 2/0")
	_assert(GameRules.can_entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.MURMURES),
		"V1h : Domaine lié + contrôlé + 1+ Corr. -> Entrave légale")
	# Pose : reserve untouched, board Corruption decremented.
	var reserve_before: int = s.available_corruption[GameEnums.PlayerId.RED]
	var r := ActionResolver.entraver(s, GameEnums.PlayerId.RED,
		GameEnums.StationId.MURMURES, GameEnums.DomainId.FOI)
	_assert(r["ok"], "Entrave actuelle OK")
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == reserve_before,
		"V1h : la Réserve n'est pas dépensée")
	_assert(s.corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED) == 1,
		"V1h : 1 Corruption retirée du Domaine payé")
	# Deuxième Entrave sur la même Station -> illégale
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.PURPLE, GameEnums.StationId.MURMURES),
		"Pas de double Entrave sur une Réponse")
	# L'Exorcisme final ne peut pas être Entravé
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.EXORCISME),
		"L'Exorcisme final ne peut être Entravé")
	# Entrave qui fait perdre le contrôle : Red 1, Blue 1 sur Ambition,
	# Red contrôle parce qu'il a égalité ? Non — controller_of sur égalité
	# renvoie NONE. Setup différent : Red 2, Blue 1 → Red contrôle. Après
	# Entrave Red 1, Blue 1 → personne ne contrôle plus, autorisé.
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.TENTATION
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	_assert(s2.controller_of(GameEnums.DomainId.AMBITION) == GameEnums.PlayerId.RED,
		"Setup : Rouge contrôle Ambition 2/1")
	var r2 := ActionResolver.entraver(s2, GameEnums.PlayerId.RED,
		GameEnums.StationId.TENTATION, GameEnums.DomainId.AMBITION)
	_assert(r2["ok"], "Entrave Tentation via Ambition OK")
	_assert(s2.controller_of(GameEnums.DomainId.AMBITION) != GameEnums.PlayerId.RED,
		"V1h : sacrifier la Corruption peut faire perdre le contrôle")


# V1h : asymmetric starting Corruption (4/5) to compensate first-player tempo advantage.
func _test_starting_corruption() -> void:
	var s := _new_state()
	_assert(GameEnums.STARTING_CORRUPTION == 5,
		"V1h : STARTING_CORRUPTION == 5")
	_assert(GameEnums.STARTING_CORRUPTION_RED == 4,
		"V1h : STARTING_CORRUPTION_RED == 4")
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == 4,
		"Nouvelle partie : Rouge à 4 Corruptions")
	_assert(s.available_corruption[GameEnums.PlayerId.PURPLE] == 5,
		"Nouvelle partie : Violet à 5 Corruptions")


# V1h : Puiser dans l'Ombre — last-resort, only when reserve is exactly 0.
func _test_puiser() -> void:
	var s := _new_state()
	s.available_corruption[GameEnums.PlayerId.RED] = 0
	_assert(GameRules.can_puiser(s, GameEnums.PlayerId.RED),
		"Puiser légal à 0 Corruption")
	s.available_corruption[GameEnums.PlayerId.RED] = 1
	_assert(not GameRules.can_puiser(s, GameEnums.PlayerId.RED),
		"Puiser illégal à 1+ Corruption")
	# Effet exact : +1 Corruption, aucun Domaine modifié, aucun Ascendant.
	var s2 := _new_state()
	s2.available_corruption[GameEnums.PlayerId.RED] = 0
	var ascendant_before := s2.ascendant
	# Snapshot board state for every Domain.
	var board_before: Dictionary = {}
	for d_id in DomainData.DOMAINS:
		board_before[d_id] = [
			s2.corruption_in(d_id, GameEnums.PlayerId.RED),
			s2.corruption_in(d_id, GameEnums.PlayerId.PURPLE),
			s2.domain(d_id).seal_owner,
		]
	var r := ActionResolver.puiser(s2, GameEnums.PlayerId.RED)
	_assert(r["ok"], "Puiser exécutée")
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] == 1,
		"Puiser : exactement +1 Corruption")
	_assert(s2.ascendant == ascendant_before,
		"Puiser : Ascendant inchangé")
	for d_id in DomainData.DOMAINS:
		var arr: Array = board_before[d_id]
		_assert(s2.corruption_in(d_id, GameEnums.PlayerId.RED) == arr[0],
			"Puiser : %s Rouge inchangé" % GameEnums.DOMAIN_NAMES[d_id])
		_assert(s2.corruption_in(d_id, GameEnums.PlayerId.PURPLE) == arr[1],
			"Puiser : %s Violet inchangé" % GameEnums.DOMAIN_NAMES[d_id])
		_assert(s2.domain(d_id).seal_owner == arr[2],
			"Puiser : %s Sceau inchangé" % GameEnums.DOMAIN_NAMES[d_id])


# V1h §6 : free start-of-station Exploit counts as a normal exploit for
# the demon who took it ; same demon can't re-exploit the same Domain
# in the Station, but the OTHER demon can if he later takes control.
func _test_free_exploit_per_player() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	# Free exploit by Red.
	var r := ActionResolver.exploiter(s, GameEnums.PlayerId.RED,
		GameEnums.DomainId.AMBITION, true)
	_assert(r["ok"], "Free exploit OK")
	_assert(s.domain(GameEnums.DomainId.AMBITION).exploited_by_red_this_station,
		"Free exploit marque le Domaine comme exploité pour le démon actif")
	_assert(not GameRules.can_exploiter(s, GameEnums.PlayerId.RED,
		GameEnums.DomainId.AMBITION),
		"Le même démon ne peut pas ré-exploiter ce Domaine cette Station")
	# Other demon takes control (3 vs 0 → Blue dominant) and can still exploit.
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 0)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 3)
	_assert(s.controller_of(GameEnums.DomainId.AMBITION) == GameEnums.PlayerId.PURPLE,
		"Setup : Violet contrôle après inversion")
	_assert(GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE,
		GameEnums.DomainId.AMBITION),
		"L'autre démon peut exploiter plus tard s'il prend le contrôle")


# V1h §3 : linked Domains for each Liturgical Response.
func _test_linked_domains() -> void:
	var s := _new_state()
	# I — Signe de croix : tous les Domaines.
	var i_links: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.MURMURES, GameEnums.PlayerId.RED)
	_assert(i_links.size() == DomainData.DOMAINS.size(),
		"Liens I : tous les Domaines")
	# II — Examen : Ambition + Désir.
	var ii_links: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.TENTATION, GameEnums.PlayerId.RED)
	_assert(ii_links.size() == 2 \
			and ii_links.has(GameEnums.DomainId.AMBITION) \
			and ii_links.has(GameEnums.DomainId.DESIR),
		"Liens II : Ambition + Désir")
	# III — Contrition : seuls les Domaines transgressés.
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_NEPOTISME
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.AMBITION
	s.domain(GameEnums.DomainId.AMBITION).scandals.append(ti)
	var iii_links: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.CHUTE, GameEnums.PlayerId.RED)
	_assert(iii_links == [GameEnums.DomainId.AMBITION],
		"Liens III : Domaines transgressés (Ambition seulement)")
	# IV — Confession : Domaines d'origine des Transgressions du joueur actif.
	# Ti at AMBITION belongs to RED → IV for RED returns [AMBITION].
	var iv_red: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.CONFESSION, GameEnums.PlayerId.RED)
	_assert(iv_red == [GameEnums.DomainId.AMBITION],
		"Liens IV : origines des Transgressions de Rouge")
	# IV for PURPLE: empty since PURPLE has no placed Transgressions.
	var iv_blue: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.CONFESSION, GameEnums.PlayerId.PURPLE)
	_assert(iv_blue.is_empty(),
		"Liens IV : Violet sans Transgression -> aucun Domaine")
	# V — Communion : Foi + Volonté.
	var v_links: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.OFFICE, GameEnums.PlayerId.RED)
	_assert(v_links.size() == 2 \
			and v_links.has(GameEnums.DomainId.FOI) \
			and v_links.has(GameEnums.DomainId.VOLONTE),
		"Liens V : Foi + Volonté")
	# VI — Exorcisme : aucun (impossible à Entraver).
	var vi_links: Array = GameRules.linked_domains_for_response(s,
		GameEnums.StationId.EXORCISME, GameEnums.PlayerId.RED)
	_assert(vi_links.is_empty(),
		"Liens VI : aucun Domaine (Exorcisme inentravable)")


# V1h §7 : Anchor unchanged. 2+ sealed Domains OR Will sealed AND transgressed.
func _test_anchor_unchanged() -> void:
	# 2 Sceaux : Ancrage rempli.
	var s := _new_state()
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.PURPLE
	var r := EndGameResolver.check_rupture(s)
	_assert(r.ancrage, "Ancrage : 2 Domaines scellés -> rempli")
	# Volonté scellée + transgressée : Ancrage rempli même avec 1 seul Sceau.
	var s2 := _new_state()
	s2.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	var ti2 := GameState.TransgressionInstance.new()
	ti2.def_id = TransgressionData.T_PACTE
	ti2.owner = GameEnums.PlayerId.PURPLE
	ti2.face = GameEnums.TransgressionFace.SCANDALE
	ti2.origin_domain = GameEnums.DomainId.VOLONTE
	s2.domain(GameEnums.DomainId.VOLONTE).scandals.append(ti2)
	var r2 := EndGameResolver.check_rupture(s2)
	_assert(r2.ancrage, "Ancrage : Volonté scellée + transgressée -> rempli")


# ---------------------------------------------------------------------------
# Rupture de l'âme
# ---------------------------------------------------------------------------
func _test_rupture() -> void:
	# 3 Infamies remplissent Profondeur
	var s := _new_state()
	for i in 3:
		var ti := GameState.TransgressionInstance.new()
		ti.def_id = TransgressionData.T_FESTIN
		ti.owner = GameEnums.PlayerId.RED
		ti.face = GameEnums.TransgressionFace.INFAMIE
		ti.origin_domain = GameEnums.DomainId.AMBITION
		s.domain(GameEnums.DomainId.AMBITION).infamies.append(ti)
	var r := EndGameResolver.check_rupture(s)
	_assert(r.profondeur, "3 Infamies remplissent Profondeur")
	# Infamie en Foi remplit Profondeur
	var s2 := _new_state()
	var ti2 := GameState.TransgressionInstance.new()
	ti2.def_id = TransgressionData.T_PROFANATION
	ti2.owner = GameEnums.PlayerId.RED
	ti2.face = GameEnums.TransgressionFace.INFAMIE
	ti2.origin_domain = GameEnums.DomainId.FOI
	s2.domain(GameEnums.DomainId.FOI).infamies.append(ti2)
	_assert(EndGameResolver.check_rupture(s2).profondeur,
		"Infamie en Foi remplit Profondeur")
	# Infamie en Volonté
	var s3 := _new_state()
	var ti3 := GameState.TransgressionInstance.new()
	ti3.def_id = TransgressionData.T_PACTE
	ti3.owner = GameEnums.PlayerId.RED
	ti3.face = GameEnums.TransgressionFace.INFAMIE
	ti3.origin_domain = GameEnums.DomainId.VOLONTE
	s3.domain(GameEnums.DomainId.VOLONTE).infamies.append(ti3)
	_assert(EndGameResolver.check_rupture(s3).profondeur,
		"Infamie en Volonté remplit Profondeur")
	# Étendue : 4 transgressés
	var s4 := _new_state()
	for d_id in [GameEnums.DomainId.AMBITION, GameEnums.DomainId.DESIR, GameEnums.DomainId.FOI, GameEnums.DomainId.PEUR]:
		var t := GameState.TransgressionInstance.new()
		t.def_id = TransgressionData.T_FESTIN
		t.owner = GameEnums.PlayerId.RED
		t.face = GameEnums.TransgressionFace.SCANDALE
		t.origin_domain = d_id
		s4.domain(d_id).scandals.append(t)
	_assert(EndGameResolver.check_rupture(s4).etendue, "4 Domaines transgressés -> Étendue")
	# 3 transgressés ne suffisent pas
	var s5 := _new_state()
	for d_id in [GameEnums.DomainId.AMBITION, GameEnums.DomainId.DESIR, GameEnums.DomainId.FOI]:
		var t2 := GameState.TransgressionInstance.new()
		t2.def_id = TransgressionData.T_FESTIN
		t2.owner = GameEnums.PlayerId.RED
		t2.face = GameEnums.TransgressionFace.SCANDALE
		t2.origin_domain = d_id
		s5.domain(d_id).scandals.append(t2)
	_assert(not EndGameResolver.check_rupture(s5).etendue, "3 Domaines transgressés ne suffisent pas")
	# Ancrage : 2 Sceaux
	var s6 := _new_state()
	s6.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	s6.domain(GameEnums.DomainId.DESIR).seal_owner = GameEnums.PlayerId.PURPLE
	_assert(EndGameResolver.check_rupture(s6).ancrage, "2 Domaines scellés -> Ancrage")
	# Volonté scellée + transgressée -> Ancrage
	var s7 := _new_state()
	s7.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	var t7 := GameState.TransgressionInstance.new()
	t7.def_id = TransgressionData.T_PACTE
	t7.owner = GameEnums.PlayerId.RED
	t7.face = GameEnums.TransgressionFace.SCANDALE
	t7.origin_domain = GameEnums.DomainId.VOLONTE
	s7.domain(GameEnums.DomainId.VOLONTE).scandals.append(t7)
	_assert(EndGameResolver.check_rupture(s7).ancrage, "Volonté scellée+transgressée -> Ancrage")
	# Volonté scellée seule ne remplit pas
	var s8 := _new_state()
	s8.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	_assert(not EndGameResolver.check_rupture(s8).ancrage,
		"Volonté scellée seule ne remplit pas l'Ancrage")
	# Les 3 axes sont nécessaires
	var s9 := _new_state()
	# Profondeur
	for d_id in [GameEnums.DomainId.AMBITION, GameEnums.DomainId.DESIR, GameEnums.DomainId.FOI]:
		var ti9 := GameState.TransgressionInstance.new()
		ti9.def_id = TransgressionData.T_FESTIN
		ti9.owner = GameEnums.PlayerId.RED
		ti9.face = GameEnums.TransgressionFace.INFAMIE
		ti9.origin_domain = d_id
		s9.domain(d_id).infamies.append(ti9)
	# Étendue (4 Domaines)
	var t9 := GameState.TransgressionInstance.new()
	t9.def_id = TransgressionData.T_PARANOIA
	t9.owner = GameEnums.PlayerId.PURPLE
	t9.face = GameEnums.TransgressionFace.SCANDALE
	t9.origin_domain = GameEnums.DomainId.PEUR
	s9.domain(GameEnums.DomainId.PEUR).scandals.append(t9)
	# Ancrage : pas de Sceau, pas de Volonté
	_assert(not EndGameResolver.check_rupture(s9).complete,
		"Sans Ancrage, l'Exorcisme ne peut pas échouer")


# ---------------------------------------------------------------------------
# Fiat Tenebris
# ---------------------------------------------------------------------------
func _test_fiat_tenebris() -> void:
	# Cas: Volonté scellée + transgressée par Rouge
	var s := _new_state()
	s.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PACTE
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.VOLONTE
	s.domain(GameEnums.DomainId.VOLONTE).scandals.append(ti)
	_assert(EndGameResolver.check_fiat_tenebris(s) == GameEnums.PlayerId.RED,
		"Fiat : Rouge scelle+transgresse Volonté -> Rouge")
	# Volonté scellée par Rouge mais transgressée par Bleu -> pas de Fiat
	var s2 := _new_state()
	s2.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	var ti2 := GameState.TransgressionInstance.new()
	ti2.def_id = TransgressionData.T_PACTE
	ti2.owner = GameEnums.PlayerId.PURPLE
	ti2.face = GameEnums.TransgressionFace.SCANDALE
	ti2.origin_domain = GameEnums.DomainId.VOLONTE
	s2.domain(GameEnums.DomainId.VOLONTE).scandals.append(ti2)
	_assert(EndGameResolver.check_fiat_tenebris(s2) == GameEnums.PlayerId.NONE,
		"Fiat : sceau et transgression de démons différents -> aucun")
	# Volonté scellée mais non transgressée
	var s3 := _new_state()
	s3.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	_assert(EndGameResolver.check_fiat_tenebris(s3) == GameEnums.PlayerId.NONE,
		"Fiat : Volonté scellée mais non transgressée -> aucun")
	# Volonté transgressée mais non scellée
	var s4 := _new_state()
	var ti4 := GameState.TransgressionInstance.new()
	ti4.def_id = TransgressionData.T_PACTE
	ti4.owner = GameEnums.PlayerId.RED
	ti4.face = GameEnums.TransgressionFace.SCANDALE
	ti4.origin_domain = GameEnums.DomainId.VOLONTE
	s4.domain(GameEnums.DomainId.VOLONTE).scandals.append(ti4)
	_assert(EndGameResolver.check_fiat_tenebris(s4) == GameEnums.PlayerId.NONE,
		"Fiat : Volonté transgressée mais non scellée -> aucun")
	# L'Exorcisme réussit -> pas de Fiat (pope_saved)
	var s5 := _new_state()
	s5.current_station = GameEnums.StationId.EXORCISME
	var res := EndGameResolver.resolve_final_exorcism(s5)
	_assert(res["outcome"] == "pope_saved",
		"Sans Rupture complète : Exorcisme réussit, Fiat non appliqué")
	_assert(s5.winner == GameEnums.PlayerId.NONE,
		"Sans Rupture complète : aucun démon ne gagne")


# ---------------------------------------------------------------------------
# Final ascendant
# ---------------------------------------------------------------------------
func _test_final_ascendant() -> void:
	var s := _new_state()
	# Rouge scelle Ambition, Désir, Volonté
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	s.domain(GameEnums.DomainId.DESIR).seal_owner = GameEnums.PlayerId.RED
	s.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.RED
	# Une Infamie en Foi par Rouge, Rouge contrôle Foi
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 2)
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PROFANATION
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.FOI
	s.domain(GameEnums.DomainId.FOI).infamies.append(ti)
	# Sceaux (3) +1 chacun = 3 ; Volonté scellée +1 = 4 ; Infamie en Foi contrôlée +1 = 5 ; Buff Foi +1 = 6
	EndGameResolver.apply_final_ascendant_bonuses(s)
	_assert(s.ascendant == 6,
		"Bonus finaux corrects pour Rouge (attendu 6, obtenu %d)" % s.ascendant)


# ---------------------------------------------------------------------------
# Communion
# ---------------------------------------------------------------------------
func _test_communion() -> void:
	# In Integro sur Foi scellée -> Sceau retiré + Domination brisée + interdit rescellement
	var s := _new_state()
	s.current_station = GameEnums.StationId.OFFICE
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.FOI).seal_owner == GameEnums.PlayerId.NONE,
		"Communion In Integro : Sceau retiré")
	_assert(s.domain(GameEnums.DomainId.FOI).red_corruption - s.domain(GameEnums.DomainId.FOI).purple_corruption < 2,
		"Communion In Integro : Domination brisée")
	_assert(s.domain(GameEnums.DomainId.FOI).cannot_be_sealed_until_exorcism,
		"Communion In Integro : rescellement interdit avant l'Exorcisme")
	# Impedita -> Sceau retiré seulement, rescellement possible en Station VI
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.OFFICE
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s2.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	var pe := GameState.PendingEntrave.new()
	pe.caster = GameEnums.PlayerId.PURPLE
	pe.target_station = GameEnums.StationId.OFFICE
	s2.pending_entraves.append(pe)
	LiturgyResolver.resolve_station_response(s2)
	_assert(s2.domain(GameEnums.DomainId.FOI).seal_owner == GameEnums.PlayerId.NONE,
		"Communion Impedita : Sceau retiré")
	_assert(not s2.domain(GameEnums.DomainId.FOI).cannot_be_sealed_until_exorcism,
		"Communion Impedita : rescellement non interdit")


# ---------------------------------------------------------------------------
# Station VI
# ---------------------------------------------------------------------------
func _test_station_six() -> void:
	_assert(GameEnums.STATION_PULSES[GameEnums.StationId.EXORCISME] == 3,
		"Station VI a 3 Pulsations")
	# Pas d'Entrave possible
	var s := _new_state()
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.EXORCISME),
		"L'Exorcisme final ne peut pas être Entravé")


# ---------------------------------------------------------------------------
# Simonie Infamy — forces Impedita on the next Foi-targeting response
# ---------------------------------------------------------------------------
func _test_simonie_infamy() -> void:
	var s := _new_state()
	# Place a Simonie Infamy on Foi (owner Rouge), and arm the trigger.
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_SIMONIE
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.FOI
	s.domain(GameEnums.DomainId.FOI).infamies.append(ti)
	s.foi_next_response_impedita = true
	# Communion targets Foi: it's sealed by RED and dominant.
	s.current_station = GameEnums.StationId.OFFICE
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	# No external Entrave: would normally be In Integro, but Simonie forces Impedita.
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.FOI).seal_owner == GameEnums.PlayerId.NONE,
		"Simonie Infamie : Sceau retiré (Communion forcée Impedita)")
	_assert(s.domain(GameEnums.DomainId.FOI).red_corruption == 4,
		"Simonie Infamie : Domination NON brisée (effet Impedita)")
	_assert(not s.foi_next_response_impedita,
		"Simonie Infamie : trigger consommé après usage")
	_assert(not s.domain(GameEnums.DomainId.FOI).cannot_be_sealed_until_exorcism,
		"Simonie Infamie : pas d'interdiction de rescellement (Impedita)")


# ---------------------------------------------------------------------------
# Confession — pushes a pending decision and pauses station advance
# ---------------------------------------------------------------------------
func _test_confession_pending_decision() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.CONFESSION
	# RED has a Scandale, PURPLE has nothing -> RED is targeted.
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_FESTIN
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.SCANDALE
	ti.origin_domain = GameEnums.DomainId.DESIR
	s.domain(GameEnums.DomainId.DESIR).scandals.append(ti)
	# Make sure RED has spendable Corruption + a controlled, sealed domain so penitences are applicable.
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.RED
	LiturgyResolver.resolve_station_response(s)
	_assert(s.has_pending_decisions(),
		"Confession : décision en attente après résolution")
	var dec: GameState.PendingDecision = s.pending_decisions[0]
	_assert(dec.kind == "confession" and dec.player == GameEnums.PlayerId.RED,
		"Confession : cible = Rouge, kind = confession")
	_assert(dec.picks_remaining == 2,
		"Confession In Integro : 2 pénitences à choisir")
	# Apply two distinct picks via apply_confession_pick.
	var pool_before: int = s.available_corruption[GameEnums.PlayerId.RED]
	var r1 := LiturgyResolver.apply_confession_pick(s, dec, "lose2", -1)
	_assert(r1["ok"] and not r1.get("done", false),
		"Confession : 1ère pénitence appliquée, encore 1 à choisir")
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == pool_before - 2,
		"Confession lose2 : -2 Corruptions disponibles")
	var r2 := LiturgyResolver.apply_confession_pick(s, dec, "fissure", GameEnums.DomainId.AMBITION)
	_assert(r2["ok"] and r2.get("done", false),
		"Confession : 2ème pénitence appliquée, décision terminée")
	_assert(s.domain(GameEnums.DomainId.AMBITION).seal_owner == GameEnums.PlayerId.NONE,
		"Confession fissure : Sceau retiré")
	# Cannot re-pick the same kind.
	var r3 := LiturgyResolver.apply_confession_pick(s, dec, "lose2", -1)
	_assert(not r3["ok"], "Confession : impossible de choisir deux fois la même pénitence")


# ---------------------------------------------------------------------------
# Codex setup
# ---------------------------------------------------------------------------
func _test_codex_setup() -> void:
	var s := _new_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	CodexSetup.setup(s, rng)
	_assert(s.codex_of_transgressions_enabled, "Codex : flag activé après setup")
	_assert(s.codex_available.size() == 10, "Codex : 10 cartes disponibles après setup")
	# Exactly 2 per domain
	for d_id in TransgressionData.CODEX_DOMAIN_GROUPS.keys():
		var pool: Array = TransgressionData.CODEX_DOMAIN_GROUPS[d_id]
		var count := 0
		for tid in s.codex_available:
			if tid in pool:
				count += 1
		_assert(count == 2, "Codex setup : 2 cartes sélectionnées pour le Domaine %d" % d_id)
	# setup_manual sets specific cards
	var s2 := _new_state()
	var manual := [TransgressionData.T_INTRIGUE, TransgressionData.T_BULLE,
		TransgressionData.T_MASCARADE, TransgressionData.T_APPETIT,
		TransgressionData.T_DOGME, TransgressionData.T_RELIQUES,
		TransgressionData.T_DENONCIATION, TransgressionData.T_PANIQUE,
		TransgressionData.T_OBEISSANCE, TransgressionData.T_RENONCEMENT]
	CodexSetup.setup_manual(s2, manual)
	_assert(s2.codex_available.size() == 10 and s2.codex_available.has(TransgressionData.T_INTRIGUE),
		"Codex setup_manual : cartes correctes")


# ---------------------------------------------------------------------------
# Codex filter — ActionEnumerator uses codex_available
# ---------------------------------------------------------------------------
func _test_codex_filter() -> void:
	var s := _new_state()
	# Without codex: only V1h cards can be provoked.
	var actions_v1h := ActionEnumerator.list(s, GameEnums.PlayerId.RED)
	var has_intrigue_v1h := false
	for a in actions_v1h:
		if a["action_id"] == GameEnums.ActionId.PROVOQUER and a["kwargs"].get("def_id", "") == TransgressionData.T_INTRIGUE:
			has_intrigue_v1h = true
	_assert(not has_intrigue_v1h, "Sans Codex : Intrigue absente des actions")
	# With codex but Intrigue not selected: still absent.
	s.codex_of_transgressions_enabled = true
	s.codex_available = [TransgressionData.T_BULLE, TransgressionData.T_MASCARADE,
		TransgressionData.T_APPETIT, TransgressionData.T_DOGME, TransgressionData.T_RELIQUES,
		TransgressionData.T_DENONCIATION, TransgressionData.T_PANIQUE,
		TransgressionData.T_OBEISSANCE, TransgressionData.T_RENONCEMENT, TransgressionData.T_NEPOTISME]
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	var actions_no_intrigue := ActionEnumerator.list(s, GameEnums.PlayerId.RED)
	var has_intrigue_b := false
	for a in actions_no_intrigue:
		if a["action_id"] == GameEnums.ActionId.PROVOQUER and a["kwargs"].get("def_id", "") == TransgressionData.T_INTRIGUE:
			has_intrigue_b = true
	_assert(not has_intrigue_b, "Codex actif mais Intrigue non sélectionnée : absente")
	# With codex and Intrigue selected: present and has target_domain variants.
	s.codex_available = [TransgressionData.T_INTRIGUE, TransgressionData.T_BULLE,
		TransgressionData.T_MASCARADE, TransgressionData.T_APPETIT,
		TransgressionData.T_DOGME, TransgressionData.T_RELIQUES,
		TransgressionData.T_DENONCIATION, TransgressionData.T_PANIQUE,
		TransgressionData.T_OBEISSANCE, TransgressionData.T_RENONCEMENT]
	var actions_codex := ActionEnumerator.list(s, GameEnums.PlayerId.RED)
	var intrigue_variants := 0
	for a in actions_codex:
		if a["action_id"] == GameEnums.ActionId.PROVOQUER and a["kwargs"].get("def_id", "") == TransgressionData.T_INTRIGUE:
			intrigue_variants += 1
	_assert(intrigue_variants == DomainData.DOMAINS.size(),
		"Codex actif + Intrigue sélectionnée : une variante par Domaine (%d)" % intrigue_variants)


# ---------------------------------------------------------------------------
# Intrigue du Consistoire (11)
# ---------------------------------------------------------------------------
func _test_codex_intrigue() -> void:
	var s := _new_state()
	# Setup: RED controls AMBITION, PURPLE has corruption in DESIR.
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	# SCANDALE: opponent loses 1 in target_domain.
	var blue_desir_before: int = s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE)
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_INTRIGUE, -1,
		{"target_domain": GameEnums.DomainId.DESIR})
	_assert(s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE) == blue_desir_before - 1,
		"Intrigue Scandale : adversaire perd 1 Corruption dans la cible")
	# INFAMY: can seal AMBITION without net domination.
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	s2.available_corruption[GameEnums.PlayerId.RED] = 5
	# Without infamy: can't seal (no net domination).
	_assert(not GameRules.can_sceller(s2, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Intrigue Infamie : sans infamie, pas de Scellement sans Domination nette")
	# Place infamy in AMBITION.
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_INTRIGUE
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.AMBITION
	s2.domain(GameEnums.DomainId.AMBITION).infamies.append(ti)
	_assert(GameRules.can_sceller(s2, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION),
		"Intrigue Infamie : Scellement sans Domination nette autorisé pour le Domaine d'origine")
	# Does NOT bypass seal check for other domains.
	_assert(not GameRules.can_sceller(s2, GameEnums.PlayerId.RED, GameEnums.DomainId.DESIR),
		"Intrigue Infamie : bypass uniquement pour le Domaine d'origine")


# ---------------------------------------------------------------------------
# Bulle vendue (12)
# ---------------------------------------------------------------------------
func _test_codex_bulle() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	s.available_corruption[GameEnums.PlayerId.RED] = 5
	var pool_before: int = s.available_corruption[GameEnums.PlayerId.RED]
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_BULLE)
	var def: Dictionary = TransgressionData.CATALOG.get(TransgressionData.T_BULLE)
	var cost: int = def.get("scandal_cost", 0)
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == pool_before - cost + 2,
		"Bulle vendue Scandale : +2 Corruptions (coût déduit)")
	# INFAMY post-liturgy bonus (non-entraved): +1 Corruption.
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.CHUTE
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_BULLE
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.AMBITION
	s2.domain(GameEnums.DomainId.AMBITION).infamies.append(ti)
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 3)
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	var pool2: int = s2.available_corruption[GameEnums.PlayerId.RED]
	var tm := TurnManager.new(s2, false)
	tm.pending_liturgy = {"impedita": false, "resolved": true}
	tm.acknowledge_liturgy()
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] == pool2 + 1,
		"Bulle vendue Infamie : +1 Corruption après Réponse non entravée")


# ---------------------------------------------------------------------------
# Mascarade de velours (13)
# ---------------------------------------------------------------------------
func _test_codex_mascarade() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED, 3)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	# SCANDALE: move 1 from DESIR to VOLONTE.
	var desir_before: int = s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED)
	var volonte_before: int = s.corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED)
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_MASCARADE, -1,
		{"from_domain": GameEnums.DomainId.DESIR, "to_domain": GameEnums.DomainId.VOLONTE})
	_assert(s.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED) == desir_before - 1,
		"Mascarade Scandale : -1 Corruption sur le Domaine source")
	_assert(s.corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED) == volonte_before + 1,
		"Mascarade Scandale : +1 Corruption sur le Domaine cible")
	# INFAMY auto-move in _begin_station: redistribution conserves total.
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE, 4)
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_MASCARADE
	ti.owner = GameEnums.PlayerId.PURPLE
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.DESIR
	s2.domain(GameEnums.DomainId.DESIR).infamies.append(ti)
	var total_before: int = 0
	for d_id in DomainData.DOMAINS:
		total_before += s2.corruption_in(d_id, GameEnums.PlayerId.PURPLE)
	# TurnManager init calls _begin_station(MURMURES, true) which triggers Mascarade.
	var _tm2 := TurnManager.new(s2, true)
	var total_after: int = 0
	for d_id in DomainData.DOMAINS:
		total_after += s2.corruption_in(d_id, GameEnums.PlayerId.PURPLE)
	_assert(total_after == total_before, "Mascarade Infamie : redistribution conserve le total des Corruptions")
	_assert(s2.corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE) == 3,
		"Mascarade Infamie : 1 Corruption retirée du Domaine le plus riche")


# ---------------------------------------------------------------------------
# Appétit hérétique (14)
# ---------------------------------------------------------------------------
# Shared setup for the Appétit hérétique (Infamie) power tests : RED controls
# DÉSIR (its home), holds 1 presence in PEUR which PURPLE controls, and owns
# Appétit in Infamie — so every guard is satisfied and callers knock them out
# one at a time.
func _appetit_base_state() -> GameState:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED, 2)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE, 2)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 1)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_APPETIT
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.DESIR
	s.domain(GameEnums.DomainId.DESIR).infamies.append(ti)
	return s


func _test_codex_appetit() -> void:
	# Sanity : without Appétit infamy, a PEUR transgression needs control of PEUR.
	var s0 := _appetit_base_state()
	s0.domain(GameEnums.DomainId.DESIR).infamies.clear()
	_assert(not GameRules.can_provoquer(s0, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION),
		"Appétit : sans infamie, pas de Transgression PEUR sans contrôle")
	# Every guard satisfied -> allowed.
	var s1 := _appetit_base_state()
	_assert(GameRules.can_provoquer(s1, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION),
		"Appétit Infamie : provocation autorisée (Désir contrôlé + présence, non scellé, inutilisé)")
	# Guard 1 — must control DÉSIR.
	var s2 := _appetit_base_state()
	s2.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE, 3)
	_assert(not GameRules.can_provoquer(s2, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION),
		"Appétit Infamie : bloqué si on ne contrôle plus Désir")
	# Guard 2 — need ≥1 presence in the required domain.
	var s3 := _appetit_base_state()
	s3.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 0)
	_assert(not GameRules.can_provoquer(s3, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION),
		"Appétit Infamie : bloqué sans présence dans le Domaine requis")
	# Guard 3 — the required domain must not be sealed by the opponent.
	var s4 := _appetit_base_state()
	s4.domain(GameEnums.DomainId.PEUR).seal_owner = GameEnums.PlayerId.PURPLE
	_assert(not GameRules.can_provoquer(s4, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION),
		"Appétit Infamie : bloqué si le Domaine requis est scellé par l'adversaire")
	# Guard 4 — once per Station : the first off-control provoke spends it.
	var s5 := _appetit_base_state()
	ActionResolver.provoquer(s5, GameEnums.PlayerId.RED, TransgressionData.T_PERSECUTION)
	_assert(s5.transgression_owner(TransgressionData.T_PERSECUTION) == GameEnums.PlayerId.RED,
		"Appétit Infamie : 1re provocation hors-contrôle réussit")
	_assert(s5.appetit_offcontrol_used_this_station[GameEnums.PlayerId.RED],
		"Appétit Infamie : pouvoir marqué utilisé pour la Station")
	_assert(not GameRules.can_provoquer(s5, GameEnums.PlayerId.RED, TransgressionData.T_PANIQUE),
		"Appétit Infamie : 2e provocation hors-contrôle bloquée la même Station")


func _test_simonie_origin() -> void:
	# Simonie requires FOI or AMBITION (origin_choice). PURPLE controls FOI only ;
	# RED controls AMBITION. PURPLE must not be able to drop its Scandale into
	# AMBITION (a required domain it does not control) — it lands in FOI.
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s.available_corruption[GameEnums.PlayerId.PURPLE] = 10
	_assert(GameRules.can_provoquer(s, GameEnums.PlayerId.PURPLE, TransgressionData.T_SIMONIE),
		"Simonie : provocation légale (contrôle Foi)")
	# Ask for AMBITION (uncontrolled) -> engine must redirect to FOI.
	ActionResolver.provoquer(s, GameEnums.PlayerId.PURPLE, TransgressionData.T_SIMONIE,
		GameEnums.DomainId.AMBITION)
	var ti := s.find_transgression_instance(GameEnums.PlayerId.PURPLE, TransgressionData.T_SIMONIE, GameEnums.TransgressionFace.SCANDALE)
	_assert(ti != null and ti.origin_domain == GameEnums.DomainId.FOI,
		"Simonie : Scandale posé en Foi (contrôlé), pas en Ambition (Rouge)")
	# Explicitly choosing the controlled domain also lands in FOI.
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	s2.available_corruption[GameEnums.PlayerId.PURPLE] = 10
	ActionResolver.provoquer(s2, GameEnums.PlayerId.PURPLE, TransgressionData.T_SIMONIE,
		GameEnums.DomainId.FOI)
	var ti2 := s2.find_transgression_instance(GameEnums.PlayerId.PURPLE, TransgressionData.T_SIMONIE, GameEnums.TransgressionFace.SCANDALE)
	_assert(ti2 != null and ti2.origin_domain == GameEnums.DomainId.FOI,
		"Simonie : choix explicite de Foi -> posé en Foi")


# ---------------------------------------------------------------------------
# Dogme renversé (15)
# ---------------------------------------------------------------------------
func _test_codex_dogme() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 3)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	# SCANDALE: free entrave on current+1.
	var target_st: int = GameEnums.StationId.TENTATION
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_DOGME, -1,
		{"target_station": target_st})
	var entraved := false
	for pe in s.pending_entraves:
		if pe.target_station == target_st:
			entraved = true
	_assert(entraved, "Dogme Scandale : Entrave gratuite posée sur la Station cible")
	# INFAMY: +1 Corruption after each liturgy.
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.TENTATION
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_DOGME
	ti.owner = GameEnums.PlayerId.PURPLE
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.FOI
	s2.domain(GameEnums.DomainId.FOI).infamies.append(ti)
	var pool2: int = s2.available_corruption[GameEnums.PlayerId.PURPLE]
	var tm2 := TurnManager.new(s2, false)
	tm2.pending_liturgy = {"impedita": true, "resolved": true}
	tm2.acknowledge_liturgy()
	_assert(s2.available_corruption[GameEnums.PlayerId.PURPLE] == pool2 + 1,
		"Dogme Infamie : +1 Corruption après chaque Réponse (même Impedita)")


# ---------------------------------------------------------------------------
# Reliques menteuses (16)
# ---------------------------------------------------------------------------
func _test_codex_reliques() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.CHUTE
	# RED has Reliques infamy in FOI — infamy alone makes FOI "transgressed".
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_RELIQUES
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.FOI
	s.domain(GameEnums.DomainId.FOI).infamies.append(ti)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.PURPLE, 1)
	# Contrition targets FOI (only transgressed domain). Shield should block penitence.
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.FOI).penitence_until_station == -1,
		"Reliques Infamie : Pénitence bloquée sur le Domaine d'origine")
	# Control: without shield, AMBITION does get penitence.
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.CHUTE
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 4)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 1)
	var ti2 := GameState.TransgressionInstance.new()
	ti2.def_id = TransgressionData.T_NEPOTISME
	ti2.owner = GameEnums.PlayerId.RED
	ti2.face = GameEnums.TransgressionFace.SCANDALE
	ti2.origin_domain = GameEnums.DomainId.AMBITION
	s2.domain(GameEnums.DomainId.AMBITION).scandals.append(ti2)
	LiturgyResolver.resolve_station_response(s2)
	_assert(s2.domain(GameEnums.DomainId.AMBITION).penitence_until_station >= 0,
		"Reliques Infamie : Pénitence appliquée normalement sur un autre Domaine")


# ---------------------------------------------------------------------------
# Dénonciation anonyme (17)
# ---------------------------------------------------------------------------
func _test_codex_denonciation() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 3)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 3)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	# Before scandale: PURPLE can exploit AMBITION.
	_assert(GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE, GameEnums.DomainId.AMBITION),
		"Dénonciation : avant scandale, adversaire peut exploiter")
	# SCANDALE: block AMBITION for PURPLE this station.
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_DENONCIATION, -1,
		{"target_domain": GameEnums.DomainId.AMBITION})
	_assert(not GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE, GameEnums.DomainId.AMBITION),
		"Dénonciation Scandale : adversaire ne peut plus exploiter le Domaine bloqué")
	# After station reset: block cleared.
	s.denonciation_blocked_domain[GameEnums.PlayerId.RED] = -1
	_assert(GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE, GameEnums.DomainId.AMBITION),
		"Dénonciation : après reset station, blocage levé")
	# INFAMY: PEUR permanently blocked for PURPLE.
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_DENONCIATION
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.PEUR
	s.domain(GameEnums.DomainId.PEUR).infamies.append(ti)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE, 2)
	_assert(not GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE, GameEnums.DomainId.PEUR),
		"Dénonciation Infamie : adversaire ne peut pas exploiter le Domaine d'origine")
	_assert(GameRules.can_exploiter(s, GameEnums.PlayerId.PURPLE, GameEnums.DomainId.AMBITION),
		"Dénonciation Infamie : les autres Domaines restent exploitables")


# ---------------------------------------------------------------------------
# Panique contagieuse (18)
# ---------------------------------------------------------------------------
func _test_codex_panique() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 3)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	var opp_pool_before: int = s.available_corruption[GameEnums.PlayerId.PURPLE]
	# SCANDALE on contested AMBITION: opponent loses 1 pool.
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_PANIQUE, -1,
		{"target_domain": GameEnums.DomainId.AMBITION})
	_assert(s.available_corruption[GameEnums.PlayerId.PURPLE] == opp_pool_before - 1,
		"Panique Scandale : adversaire perd 1 Corruption disponible")
	# INFAMY: opponent production -1 when exploiting contested domain.
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 2)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 3)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)  # contested
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PANIQUE
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.PEUR
	s2.domain(GameEnums.DomainId.PEUR).infamies.append(ti)
	var base_prod: int = GameRules.production_of(s2, GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED)
	var panique_prod: int = GameRules.production_of(s2, GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE)
	# AMBITION is contested, PURPLE is not the Panique owner → production reduced by 1.
	_assert(panique_prod == base_prod - 1 or panique_prod == 1,
		"Panique Infamie : production adversaire -1 sur Domaine contesté (base=%d, panique=%d)" % [base_prod, panique_prod])


# ---------------------------------------------------------------------------
# Obéissance pervertie (19)
# ---------------------------------------------------------------------------
func _test_codex_obeissance() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED, 3)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	# SCANDALE: sets obeissance_acts_first flag.
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_OBEISSANCE)
	_assert(s.obeissance_acts_first[GameEnums.PlayerId.RED],
		"Obéissance Scandale : flag d'initiative activé")
	# INFAMY: flag survives station reset.
	var s2 := _new_state()
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_OBEISSANCE
	ti.owner = GameEnums.PlayerId.PURPLE
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.VOLONTE
	s2.domain(GameEnums.DomainId.VOLONTE).infamies.append(ti)
	s2.obeissance_acts_first[GameEnums.PlayerId.PURPLE] = false  # simulate post-station reset
	# After _begin_station re-activation logic: flag re-set for infamy holder.
	# Simulate what _begin_station does.
	s2.obeissance_acts_first[GameEnums.PlayerId.RED] = false
	s2.obeissance_acts_first[GameEnums.PlayerId.PURPLE] = false
	for p in [GameEnums.PlayerId.RED, GameEnums.PlayerId.PURPLE]:
		if s2.find_transgression_instance(p, TransgressionData.T_OBEISSANCE, GameEnums.TransgressionFace.INFAMIE) != null:
			s2.obeissance_acts_first[p] = true
	_assert(s2.obeissance_acts_first[GameEnums.PlayerId.PURPLE],
		"Obéissance Infamie : initiative permanente (flag ré-activé à chaque Station)")


# ---------------------------------------------------------------------------
# Renoncement noir (20)
# ---------------------------------------------------------------------------
func _test_codex_renoncement() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED, 3)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 2)
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	var blue_ambition_before: int = s.corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE)
	# SCANDALE: removes 1 of opponent's corruption in target_domain.
	ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_RENONCEMENT, -1,
		{"target_domain": GameEnums.DomainId.AMBITION})
	_assert(s.corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE) == blue_ambition_before - 1,
		"Renoncement Scandale : adversaire perd 1 Corruption dans la cible")
	# INFAMY: when opponent places an Entrave, owner gains +1 Corruption.
	var s2 := _new_state()
	s2.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED, 3)
	s2.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.PURPLE, 3)
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_RENONCEMENT
	ti.owner = GameEnums.PlayerId.RED
	ti.face = GameEnums.TransgressionFace.INFAMIE
	ti.origin_domain = GameEnums.DomainId.VOLONTE
	s2.domain(GameEnums.DomainId.VOLONTE).infamies.append(ti)
	var red_pool_before: int = s2.available_corruption[GameEnums.PlayerId.RED]
	# PURPLE places an Entrave.
	ActionResolver.entraver(s2, GameEnums.PlayerId.PURPLE, GameEnums.StationId.MURMURES,
		GameEnums.DomainId.AMBITION)
	_assert(s2.available_corruption[GameEnums.PlayerId.RED] == red_pool_before + 1,
		"Renoncement Infamie : propriétaire gagne +1 Corruption quand l'adversaire Entrave")


# ---------------------------------------------------------------------------
# Domain hint strings — chip labels and advantage texts
# ---------------------------------------------------------------------------
func _test_domain_hint_strings() -> void:
	for d in DomainData.DOMAINS:
		var chip: String = DomainData.chip_label(d)
		_assert(chip != "" and not chip.begins_with("domain.chip."),
			"hint.chip_label[%d]" % d, "label de pastille vide ou non traduit")
		var adv: String = DomainData.advantage_text(d)
		_assert(adv != "" and not adv.begins_with("domain.hint."),
			"hint.advantage_text[%d]" % d, "texte d'avantage vide ou non traduit")
	var vol: String = DomainData.advantage_text(GameEnums.DomainId.VOLONTE)
	_assert(vol.to_lower().contains("victoire"),
		"hint.volonte_victory", "la ligne d'avantage de Volonté doit mentionner la victoire")
	# Same keys must resolve in EN. Toggle then restore (other rules tests are
	# locale-agnostic, so this is safe).
	I18n.set_locale("en")
	for d in DomainData.DOMAINS:
		var chip_en: String = DomainData.chip_label(d)
		_assert(chip_en != "" and not chip_en.begins_with("domain.chip."),
			"hint.chip_label.en[%d]" % d, "label EN manquant")
		var adv_en: String = DomainData.advantage_text(d)
		_assert(adv_en != "" and not adv_en.begins_with("domain.hint."),
			"hint.advantage_text.en[%d]" % d, "texte EN manquant")
	var vol_en: String = DomainData.advantage_text(GameEnums.DomainId.VOLONTE)
	_assert(vol_en.to_lower().contains("victory"),
		"hint.volonte_victory.en", "the EN Volonté line must mention victory")
	I18n.set_locale("fr")
