class_name MisselData
extends RefCounted
# Missel Corrompu — alternative targeting logic for liturgical responses I–V.
# Called by LiturgyResolver when GameState.missel_modifiers contains an entry
# for the current station. Effects (In Integro / Impedita) are NEVER changed.
# Station VI (Exorcisme) never has a modifier.

# modifier_id -> station + display name
const MODIFIERS := {
	"I-A":  {"station": GameEnums.StationId.MURMURES,  "name": "Signe purificateur"},
	"I-B":  {"station": GameEnums.StationId.MURMURES,  "name": "Signe sur la plaie"},
	"II-A": {"station": GameEnums.StationId.TENTATION, "name": "Examen de la chair"},
	"II-B": {"station": GameEnums.StationId.TENTATION, "name": "Examen des vanités"},
	"III-A":{"station": GameEnums.StationId.CHUTE,     "name": "Contrition des infâmes"},
	"III-B":{"station": GameEnums.StationId.CHUTE,     "name": "Contrition des scandales"},
	"IV-A": {"station": GameEnums.StationId.CONFESSION,"name": "Confession du plus orgueilleux"},
	"IV-B": {"station": GameEnums.StationId.CONFESSION,"name": "Confession du corrupteur"},
	"V-A":  {"station": GameEnums.StationId.OFFICE,    "name": "Communion de la Foi"},
	"V-B":  {"station": GameEnums.StationId.OFFICE,    "name": "Communion de la Volonté"},
}

# Returns the list of valid modifier_ids for a given station.
static func modifiers_for_station(station: int) -> Array:
	var result := []
	for id in MODIFIERS.keys():
		if MODIFIERS[id]["station"] == station:
			result.append(id)
	return result


# --- Domain target overrides (return DomainId, or -1 to fall back to V1h) ---

static func pick_target_domain(state: GameState, modifier_id: String) -> int:
	match modifier_id:
		"I-A":   return _signe_purificateur(state)
		"I-B":   return _signe_sur_la_plaie(state)
		"II-A":  return _examen_chair(state)
		"II-B":  return _examen_vanites(state)
		"III-A": return _contrition_infames(state)
		"III-B": return _contrition_scandales(state)
		"V-A":   return _communion_foi(state)
		"V-B":   return _communion_volonte(state)
	return -1  # not a domain-targeting modifier


# --- Player target overrides (return PlayerId, or -1 to fall back to V1h) ---

static func pick_target_player(state: GameState, modifier_id: String) -> int:
	match modifier_id:
		"IV-A": return _confession_orgueilleux(state)
		"IV-B": return _confession_corrupteur(state)
	return -1  # not a player-targeting modifier


# ── I-A  Signe purificateur ──────────────────────────────────────────────────
# Targets the unsealed domain with the most total corruption.
# Falls back to V1h if no unsealed domain has any corruption.
static func _signe_purificateur(state: GameState) -> int:
	var candidates := {}
	for d_id in DomainData.DOMAINS:
		if not state.is_sealed(d_id):
			var total := state.domain(d_id).red_corruption + state.domain(d_id).purple_corruption
			if total > 0:
				candidates[d_id] = total
	if candidates.is_empty():
		return -1  # fallback
	return _pick_max_volonte_priority(candidates)


# ── I-B  Signe sur la plaie ───────────────────────────────────────────────────
# Targets the transgressed domain with the most total corruption.
# Falls back to V1h if no transgressed domain has any corruption.
static func _signe_sur_la_plaie(state: GameState) -> int:
	var candidates := {}
	for d_id in DomainData.DOMAINS:
		if state.is_transgressed(d_id):
			var total := state.domain(d_id).red_corruption + state.domain(d_id).purple_corruption
			if total > 0:
				candidates[d_id] = total
	if candidates.is_empty():
		return -1  # fallback
	return _pick_max_volonte_priority(candidates)


# ── II-A  Examen de la chair ─────────────────────────────────────────────────
# Targets Désir if it has any corruption; otherwise Ambition.
static func _examen_chair(state: GameState) -> int:
	var desir := state.domain(GameEnums.DomainId.DESIR)
	if desir.red_corruption + desir.purple_corruption > 0:
		return GameEnums.DomainId.DESIR
	return GameEnums.DomainId.AMBITION


# ── II-B  Examen des vanités ─────────────────────────────────────────────────
# Targets Ambition if it has any corruption; otherwise Désir.
static func _examen_vanites(state: GameState) -> int:
	var amb := state.domain(GameEnums.DomainId.AMBITION)
	if amb.red_corruption + amb.purple_corruption > 0:
		return GameEnums.DomainId.AMBITION
	return GameEnums.DomainId.DESIR


# ── III-A  Contrition des infâmes ────────────────────────────────────────────
# Prioritises transgressed domains that contain at least 1 Infamy.
# Falls back to V1h if no domain has an Infamy.
static func _contrition_infames(state: GameState) -> int:
	var with_infamy := []
	for d_id in DomainData.DOMAINS:
		if state.domain(d_id).infamies.size() > 0:
			with_infamy.append(d_id)
	if with_infamy.is_empty():
		return -1  # fallback
	with_infamy.sort_custom(func(a, b): return _contrition_severity_gt(state, a, b))
	return with_infamy[0]


# ── III-B  Contrition des scandales ─────────────────────────────────────────
# Prioritises transgressed domains by Scandals first (reversed from V1h).
# Falls back to V1h if no domain has a Scandal.
static func _contrition_scandales(state: GameState) -> int:
	var with_scandal := []
	for d_id in DomainData.DOMAINS:
		if state.domain(d_id).scandals.size() > 0:
			with_scandal.append(d_id)
	if with_scandal.is_empty():
		return -1  # fallback
	with_scandal.sort_custom(func(a, b):
		var da := state.domain(a)
		var db := state.domain(b)
		if da.scandals.size() != db.scandals.size():
			return da.scandals.size() > db.scandals.size()
		if da.infamies.size() != db.infamies.size():
			return da.infamies.size() > db.infamies.size()
		return (da.red_corruption + da.purple_corruption) > (db.red_corruption + db.purple_corruption)
	)
	return with_scandal[0]


# ── IV-A  Confession du plus orgueilleux ─────────────────────────────────────
# Targets the demon favoured by Ascendant. Falls back to V1h if Ascendant = 0.
static func _confession_orgueilleux(state: GameState) -> int:
	if state.ascendant > 0:
		return GameEnums.PlayerId.RED
	if state.ascendant < 0:
		return GameEnums.PlayerId.PURPLE
	return -1  # fallback to V1h (most transgressions)


# ── IV-B  Confession du corrupteur ───────────────────────────────────────────
# Targets the demon with the most Infamies; ties broken by total transgressions,
# then Ascendant, then non-initiative.
static func _confession_corrupteur(state: GameState) -> int:
	var red_inf := 0
	var blue_inf := 0
	var red_total := 0
	var blue_total := 0
	for d_id in DomainData.DOMAINS:
		var d := state.domain(d_id)
		for ti in d.infamies:
			if ti.owner == GameEnums.PlayerId.RED:
				red_inf += 1
			else:
				blue_inf += 1
		for ti in d.scandals:
			if ti.owner == GameEnums.PlayerId.RED:
				red_total += 1
			else:
				blue_total += 1
	red_total += red_inf
	blue_total += blue_inf
	if red_inf != blue_inf:
		return GameEnums.PlayerId.RED if red_inf > blue_inf else GameEnums.PlayerId.PURPLE
	if red_total != blue_total:
		return GameEnums.PlayerId.RED if red_total > blue_total else GameEnums.PlayerId.PURPLE
	if state.ascendant != 0:
		return GameEnums.PlayerId.RED if state.ascendant > 0 else GameEnums.PlayerId.PURPLE
	return -1  # fallback (non-initiative)


# ── V-A  Communion de la Foi ─────────────────────────────────────────────────
# Targets Foi if Foi is "active" (has any presence); otherwise Volonté.
static func _communion_foi(state: GameState) -> int:
	if _domain_is_active(state, GameEnums.DomainId.FOI):
		return GameEnums.DomainId.FOI
	return GameEnums.DomainId.VOLONTE


# ── V-B  Communion de la Volonté ─────────────────────────────────────────────
# Targets Volonté if Volonté is "active"; otherwise Foi.
static func _communion_volonte(state: GameState) -> int:
	if _domain_is_active(state, GameEnums.DomainId.VOLONTE):
		return GameEnums.DomainId.VOLONTE
	return GameEnums.DomainId.FOI


# --- Shared helpers ---------------------------------------------------------

# A domain is "active" if it has corruption, a seal, any transgression,
# a penitence marker, or a no-seal-until flag.
static func _domain_is_active(state: GameState, d_id: int) -> bool:
	var d := state.domain(d_id)
	return (d.red_corruption + d.purple_corruption > 0
		or d.seal_owner != GameEnums.PlayerId.NONE
		or d.scandals.size() > 0
		or d.infamies.size() > 0
		or d.penitence_until_station >= state.current_station
		or d.cannot_be_sealed_until_exorcism)


# Volonté-proximity tie-breaker: Volonté > Foi > Peur > Désir > Ambition.
static func _pick_max_volonte_priority(candidates: Dictionary) -> int:
	var best := -1
	var best_score := -1
	for d_id in candidates.keys():
		if candidates[d_id] > best_score:
			best_score = candidates[d_id]
			best = d_id
	var tied := []
	for d_id in candidates.keys():
		if candidates[d_id] == best_score:
			tied.append(d_id)
	if tied.size() == 1:
		return best
	for v in GameEnums.VOLONTE_PROXIMITY_PRIORITY:
		if v in tied:
			return v
	return tied[0]


# Severity comparator for Contrition (more infamies > more scandals > more emprise).
static func _contrition_severity_gt(state: GameState, a: int, b: int) -> bool:
	var da := state.domain(a)
	var db := state.domain(b)
	if da.infamies.size() != db.infamies.size():
		return da.infamies.size() > db.infamies.size()
	if da.scandals.size() != db.scandals.size():
		return da.scandals.size() > db.scandals.size()
	return (da.red_corruption + da.purple_corruption) > (db.red_corruption + db.purple_corruption)
