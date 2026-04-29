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
	_test_confession_pending_decision()
	return {
		"pass": pass_count, "fail": fail_count,
		"total": pass_count + fail_count, "lines": results,
	}


func _new_state() -> GameState:
	return GameState.new()


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
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.BLUE, 1)
	_assert(s.controller_of(GameEnums.DomainId.AMBITION) == GameEnums.PlayerId.RED,
		"Contrôle 2/1 -> Rouge contrôle")
	_assert(not s.has_net_domination(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED),
		"2/1 -> pas de Domination nette")

	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 3)
	_assert(s.has_net_domination(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED),
		"3/1 -> Domination nette")

	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.BLUE, 1)
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
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.BLUE, 1)
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
	var before := s2.available_corruption[GameEnums.PlayerId.RED]
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
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.BLUE, 4)
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 1)
	s.domain(GameEnums.DomainId.AMBITION).seal_owner = GameEnums.PlayerId.BLUE
	var r := ActionResolver.fissurer(s, GameEnums.PlayerId.RED, GameEnums.DomainId.AMBITION)
	_assert(r["ok"], "Fissure démoniaque OK")
	_assert(s.domain(GameEnums.DomainId.AMBITION).seal_owner == GameEnums.PlayerId.NONE,
		"Fissure démoniaque retire le Sceau")
	# Ne brise pas la Domination : Bleu garde 4
	_assert(s.domain(GameEnums.DomainId.AMBITION).blue_corruption == 4,
		"Fissure démoniaque ne Brise PAS la Domination")


# ---------------------------------------------------------------------------
# Liturgical fissure In Integro / Impedita
# ---------------------------------------------------------------------------
func _test_liturgical_fissure_in_integro() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.CHUTE
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.BLUE, 1)
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
	_assert(s.domain(GameEnums.DomainId.PEUR).red_corruption - s.domain(GameEnums.DomainId.PEUR).blue_corruption < 2,
		"Contrition In Integro Brise la Domination")


func _test_liturgical_fissure_impedita() -> void:
	var s := _new_state()
	s.current_station = GameEnums.StationId.OFFICE
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.BLUE, 1)
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	var pe := GameState.PendingEntrave.new()
	pe.caster = GameEnums.PlayerId.BLUE
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
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.BLUE, 3)
	s.set_corruption_in(GameEnums.DomainId.VOLONTE, GameEnums.PlayerId.RED, 1)
	s.domain(GameEnums.DomainId.VOLONTE).seal_owner = GameEnums.PlayerId.BLUE
	# Volonté transgressée par Bleu
	var ti := GameState.TransgressionInstance.new()
	ti.def_id = TransgressionData.T_PACTE
	ti.owner = GameEnums.PlayerId.BLUE
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
	var blue_before := s.available_corruption[GameEnums.PlayerId.BLUE]
	var r := ActionResolver.fissurer(s, GameEnums.PlayerId.RED, GameEnums.DomainId.VOLONTE)
	_assert(r["ok"], "Fissure Volonté avec 2 Corruptions OK")
	_assert(s.available_corruption[GameEnums.PlayerId.RED] == 0,
		"Rouge dépense 2 Corruptions au total")
	_assert(s.available_corruption[GameEnums.PlayerId.BLUE] == blue_before + 1,
		"Bleu reçoit 1 Corruption au titre du Tribut")


# ---------------------------------------------------------------------------
# Transgressions
# ---------------------------------------------------------------------------
func _test_transgressions() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.AMBITION, GameEnums.PlayerId.RED, 2)
	var asc_before := s.ascendant
	var corr_before := s.available_corruption[GameEnums.PlayerId.RED]
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
	var s := _new_state()
	s.current_station = GameEnums.StationId.MURMURES
	s.available_corruption[GameEnums.PlayerId.RED] = 5
	# Entraver la Réponse actuelle coûte 1
	_assert(GameRules.entrave_cost(s, GameEnums.PlayerId.RED, GameEnums.StationId.MURMURES) == 1,
		"Entrave actuelle coûte 1")
	# Entraver dans 2 prochaines Stations coûte 2
	_assert(GameRules.entrave_cost(s, GameEnums.PlayerId.RED, GameEnums.StationId.TENTATION) == 2,
		"Entrave future coûte 2")
	# Pose
	var r := ActionResolver.entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.MURMURES)
	_assert(r["ok"], "Entrave actuelle OK")
	# Deuxième Entrave sur la même Station -> illégale
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.BLUE, GameEnums.StationId.MURMURES),
		"Pas de double Entrave sur une Réponse")
	# L'Exorcisme final ne peut pas être Entravé
	_assert(not GameRules.can_entraver(s, GameEnums.PlayerId.RED, GameEnums.StationId.EXORCISME),
		"L'Exorcisme final ne peut être Entravé")


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
	s6.domain(GameEnums.DomainId.DESIR).seal_owner = GameEnums.PlayerId.BLUE
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
	t9.owner = GameEnums.PlayerId.BLUE
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
	ti2.owner = GameEnums.PlayerId.BLUE
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
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.BLUE, 1)
	s.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	LiturgyResolver.resolve_station_response(s)
	_assert(s.domain(GameEnums.DomainId.FOI).seal_owner == GameEnums.PlayerId.NONE,
		"Communion In Integro : Sceau retiré")
	_assert(s.domain(GameEnums.DomainId.FOI).red_corruption - s.domain(GameEnums.DomainId.FOI).blue_corruption < 2,
		"Communion In Integro : Domination brisée")
	_assert(s.domain(GameEnums.DomainId.FOI).cannot_be_sealed_until_exorcism,
		"Communion In Integro : rescellement interdit avant l'Exorcisme")
	# Impedita -> Sceau retiré seulement, rescellement possible en Station VI
	var s2 := _new_state()
	s2.current_station = GameEnums.StationId.OFFICE
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.RED, 4)
	s2.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.BLUE, 1)
	s2.domain(GameEnums.DomainId.FOI).seal_owner = GameEnums.PlayerId.RED
	var pe := GameState.PendingEntrave.new()
	pe.caster = GameEnums.PlayerId.BLUE
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
	s.set_corruption_in(GameEnums.DomainId.FOI, GameEnums.PlayerId.BLUE, 1)
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
	# RED has a Scandale, BLUE has nothing -> RED is targeted.
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
