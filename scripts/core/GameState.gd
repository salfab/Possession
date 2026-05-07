class_name GameState
extends RefCounted
# Pure data container for the rules engine.
# No UI access. Mutated only by ActionResolver / LiturgyResolver / EndGameResolver.

# --- Domain state -----------------------------------------------------------

class TransgressionInstance extends RefCounted:
	var def_id: String = ""
	var owner: int = GameEnums.PlayerId.NONE
	var origin_domain: int = 0
	var face: int = GameEnums.TransgressionFace.NONE

	func to_dict() -> Dictionary:
		return {
			"def_id": def_id, "owner": owner,
			"origin_domain": origin_domain, "face": face,
		}

	func from_dict(d: Dictionary) -> void:
		def_id = d.get("def_id", "")
		owner = d.get("owner", GameEnums.PlayerId.NONE)
		origin_domain = d.get("origin_domain", 0)
		face = d.get("face", GameEnums.TransgressionFace.NONE)


class DomainState extends RefCounted:
	var id: int = 0
	var red_corruption: int = 0
	var blue_corruption: int = 0
	var seal_owner: int = GameEnums.PlayerId.NONE  # NONE / RED / BLUE
	var scandals: Array = []   # Array of TransgressionInstance
	var infamies: Array = []   # Array of TransgressionInstance
	var penitence_until_station: int = -1   # StationId index up to which penitence applies, or -1
	var exploited_by_red_this_station: bool = false
	var exploited_by_blue_this_station: bool = false
	var cannot_be_sealed_until_exorcism: bool = false
	var was_fissured_this_station: bool = false

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"red_corruption": red_corruption,
			"blue_corruption": blue_corruption,
			"seal_owner": seal_owner,
			"scandals": scandals.map(func(t): return t.to_dict()),
			"infamies": infamies.map(func(t): return t.to_dict()),
			"penitence_until_station": penitence_until_station,
			"exploited_by_red_this_station": exploited_by_red_this_station,
			"exploited_by_blue_this_station": exploited_by_blue_this_station,
			"cannot_be_sealed_until_exorcism": cannot_be_sealed_until_exorcism,
			"was_fissured_this_station": was_fissured_this_station,
		}

	func from_dict(d: Dictionary) -> void:
		id = d.get("id", 0)
		red_corruption = d.get("red_corruption", 0)
		blue_corruption = d.get("blue_corruption", 0)
		seal_owner = d.get("seal_owner", GameEnums.PlayerId.NONE)
		penitence_until_station = d.get("penitence_until_station", -1)
		exploited_by_red_this_station = d.get("exploited_by_red_this_station", false)
		exploited_by_blue_this_station = d.get("exploited_by_blue_this_station", false)
		cannot_be_sealed_until_exorcism = d.get("cannot_be_sealed_until_exorcism", false)
		was_fissured_this_station = d.get("was_fissured_this_station", false)
		scandals = []
		for t in d.get("scandals", []):
			var ti = TransgressionInstance.new()
			ti.from_dict(t)
			scandals.append(ti)
		infamies = []
		for t in d.get("infamies", []):
			var ti = TransgressionInstance.new()
			ti.from_dict(t)
			infamies.append(ti)


class PendingEntrave extends RefCounted:
	var caster: int = GameEnums.PlayerId.NONE
	var target_station: int = 0

	func to_dict() -> Dictionary:
		return {"caster": caster, "target_station": target_station}

	func from_dict(d: Dictionary) -> void:
		caster = d.get("caster", GameEnums.PlayerId.NONE)
		target_station = d.get("target_station", 0)


# A decision the engine cannot resolve on its own and must defer to the UI.
# kind ∈ {"free_exploit", "confession"}
class PendingDecision extends RefCounted:
	var kind: String = ""
	var player: int = GameEnums.PlayerId.NONE
	var data: Dictionary = {}
	var picks_remaining: int = 1
	var picks_done: Array = []

	func to_dict() -> Dictionary:
		return {
			"kind": kind, "player": player, "data": data.duplicate(true),
			"picks_remaining": picks_remaining, "picks_done": picks_done.duplicate(),
		}

	func from_dict(d: Dictionary) -> void:
		kind = d.get("kind", "")
		player = d.get("player", GameEnums.PlayerId.NONE)
		data = d.get("data", {}).duplicate(true)
		picks_remaining = d.get("picks_remaining", 1)
		picks_done = d.get("picks_done", []).duplicate()


# --- GameState fields -------------------------------------------------------

var domains: Dictionary = {}        # DomainId -> DomainState
var available_corruption: Dictionary = {  # PlayerId -> int
	GameEnums.PlayerId.RED: GameEnums.STARTING_CORRUPTION,
	GameEnums.PlayerId.BLUE: GameEnums.STARTING_CORRUPTION,
}
var ascendant: int = 0   # Tug-of-war: positive = RED, negative = BLUE
var current_station: int = GameEnums.StationId.MURMURES
var current_pulse: int = 1
var active_player: int = GameEnums.PlayerId.RED
var pending_entraves: Array = []   # Array[PendingEntrave]
var pending_decisions: Array = []  # Array[PendingDecision] — UI must resolve these
var transgressions_provoked_this_station: Dictionary = {  # PlayerId -> int count
	GameEnums.PlayerId.RED: 0,
	GameEnums.PlayerId.BLUE: 0,
}
var trafic_discount_pending: Dictionary = {  # PlayerId -> bool
	GameEnums.PlayerId.RED: false,
	GameEnums.PlayerId.BLUE: false,
}
var nepotisme_used_this_station: Dictionary = {  # PlayerId -> bool
	GameEnums.PlayerId.RED: false,
	GameEnums.PlayerId.BLUE: false,
}
var trafic_infamy_used_this_station: Dictionary = {
	GameEnums.PlayerId.RED: false,
	GameEnums.PlayerId.BLUE: false,
}
var favori_used_this_station: Dictionary = {
	GameEnums.PlayerId.RED: false,
	GameEnums.PlayerId.BLUE: false,
}
var paranoia_used_this_station: Dictionary = {
	GameEnums.PlayerId.RED: false,
	GameEnums.PlayerId.BLUE: false,
}
var foi_next_response_impedita: bool = false  # Simonie infamy effect
var missel_modifiers: Dictionary = {}  # StationId -> String modifier_id; empty = V1h strict
var log: Array = []
var game_over: bool = false
var winner: int = GameEnums.PlayerId.NONE
var winner_reason: String = ""
var bot_for_player: Dictionary = {}


func _init() -> void:
	for d_id in DomainData.DOMAINS:
		var ds := DomainState.new()
		ds.id = d_id
		domains[d_id] = ds


# --- Convenience accessors --------------------------------------------------

func domain(d_id: int) -> DomainState:
	return domains.get(d_id)

func corruption_in(d_id: int, player: int) -> int:
	var d := domain(d_id)
	if d == null:
		return 0
	return d.red_corruption if player == GameEnums.PlayerId.RED else d.blue_corruption

func set_corruption_in(d_id: int, player: int, v: int) -> void:
	var d := domain(d_id)
	if d == null:
		return
	if player == GameEnums.PlayerId.RED:
		d.red_corruption = max(0, v)
	else:
		d.blue_corruption = max(0, v)

func add_corruption_pool(player: int, n: int) -> void:
	available_corruption[player] = max(0, available_corruption.get(player, 0) + n)

func add_log(s: String) -> void:
	log.append(s)


# --- Logical predicates -----------------------------------------------------

func controller_of(d_id: int) -> int:
	var d := domain(d_id)
	if d == null:
		return GameEnums.PlayerId.NONE
	if d.red_corruption > d.blue_corruption:
		return GameEnums.PlayerId.RED
	if d.blue_corruption > d.red_corruption:
		return GameEnums.PlayerId.BLUE
	return GameEnums.PlayerId.NONE

func has_net_domination(d_id: int, player: int) -> bool:
	var d := domain(d_id)
	if d == null:
		return false
	if player == GameEnums.PlayerId.RED:
		return d.red_corruption - d.blue_corruption >= 2
	if player == GameEnums.PlayerId.BLUE:
		return d.blue_corruption - d.red_corruption >= 2
	return false

func is_transgressed(d_id: int) -> bool:
	var d := domain(d_id)
	if d == null:
		return false
	return d.scandals.size() + d.infamies.size() > 0

func is_sealed(d_id: int) -> bool:
	var d := domain(d_id)
	return d != null and d.seal_owner != GameEnums.PlayerId.NONE

func is_in_penitence(d_id: int) -> bool:
	var d := domain(d_id)
	if d == null:
		return false
	return d.penitence_until_station >= current_station

func is_contested(d_id: int) -> bool:
	var d := domain(d_id)
	if d == null:
		return false
	return d.red_corruption > 0 and d.blue_corruption > 0

func count_transgressed_domains() -> int:
	var n := 0
	for d_id in DomainData.DOMAINS:
		if is_transgressed(d_id):
			n += 1
	return n

func count_sealed_domains() -> int:
	var n := 0
	for d_id in DomainData.DOMAINS:
		if is_sealed(d_id):
			n += 1
	return n

func count_total_infamies() -> int:
	var n := 0
	for d_id in DomainData.DOMAINS:
		n += domain(d_id).infamies.size()
	return n

func find_transgression_instance(player: int, def_id: String, face: int) -> TransgressionInstance:
	for d_id in DomainData.DOMAINS:
		var d := domain(d_id)
		var pile: Array = d.scandals if face == GameEnums.TransgressionFace.SCANDALE else d.infamies
		for ti in pile:
			if ti.owner == player and ti.def_id == def_id:
				return ti
	return null

func owns_transgression(player: int, def_id: String) -> bool:
	for d_id in DomainData.DOMAINS:
		var d := domain(d_id)
		for ti in d.scandals:
			if ti.owner == player and ti.def_id == def_id:
				return true
		for ti in d.infamies:
			if ti.owner == player and ti.def_id == def_id:
				return true
	return false

func transgression_owner(def_id: String) -> int:
	for d_id in DomainData.DOMAINS:
		var d := domain(d_id)
		for ti in d.scandals:
			if ti.def_id == def_id:
				return ti.owner
		for ti in d.infamies:
			if ti.def_id == def_id:
				return ti.owner
	return GameEnums.PlayerId.NONE


# --- Serialization ----------------------------------------------------------

func has_pending_decisions() -> bool:
	return pending_decisions.size() > 0


func to_dict() -> Dictionary:
	var d_ser := {}
	for d_id in domains.keys():
		d_ser[d_id] = domains[d_id].to_dict()
	return {
		"domains": d_ser,
		"available_corruption": available_corruption.duplicate(),
		"ascendant": ascendant,
		"current_station": current_station,
		"current_pulse": current_pulse,
		"active_player": active_player,
		"pending_entraves": pending_entraves.map(func(p): return p.to_dict()),
		"pending_decisions": pending_decisions.map(func(p): return p.to_dict()),
		"transgressions_provoked_this_station": transgressions_provoked_this_station.duplicate(),
		"trafic_discount_pending": trafic_discount_pending.duplicate(),
		"nepotisme_used_this_station": nepotisme_used_this_station.duplicate(),
		"trafic_infamy_used_this_station": trafic_infamy_used_this_station.duplicate(),
		"favori_used_this_station": favori_used_this_station.duplicate(),
		"paranoia_used_this_station": paranoia_used_this_station.duplicate(),
		"foi_next_response_impedita": foi_next_response_impedita,
		"missel_modifiers": missel_modifiers.duplicate(),
		"log": log.duplicate(),
		"game_over": game_over,
		"winner": winner,
		"winner_reason": winner_reason,
	}

func from_dict(d: Dictionary) -> void:
	domains.clear()
	for d_id in d.get("domains", {}).keys():
		var ds := DomainState.new()
		ds.from_dict(d["domains"][d_id])
		domains[int(d_id)] = ds
	available_corruption = d.get("available_corruption", available_corruption)
	ascendant = d.get("ascendant", 0)
	current_station = d.get("current_station", 0)
	current_pulse = d.get("current_pulse", 1)
	active_player = d.get("active_player", GameEnums.PlayerId.RED)
	pending_entraves = []
	for p in d.get("pending_entraves", []):
		var pe := PendingEntrave.new()
		pe.from_dict(p)
		pending_entraves.append(pe)
	pending_decisions = []
	for p in d.get("pending_decisions", []):
		var pd := PendingDecision.new()
		pd.from_dict(p)
		pending_decisions.append(pd)
	transgressions_provoked_this_station = d.get("transgressions_provoked_this_station", transgressions_provoked_this_station)
	trafic_discount_pending = d.get("trafic_discount_pending", trafic_discount_pending)
	nepotisme_used_this_station = d.get("nepotisme_used_this_station", nepotisme_used_this_station)
	trafic_infamy_used_this_station = d.get("trafic_infamy_used_this_station", trafic_infamy_used_this_station)
	favori_used_this_station = d.get("favori_used_this_station", favori_used_this_station)
	paranoia_used_this_station = d.get("paranoia_used_this_station", paranoia_used_this_station)
	foi_next_response_impedita = d.get("foi_next_response_impedita", false)
	missel_modifiers = d.get("missel_modifiers", {}).duplicate()
	log = d.get("log", [])
	game_over = d.get("game_over", false)
	winner = d.get("winner", GameEnums.PlayerId.NONE)
	winner_reason = d.get("winner_reason", "")
