extends Node
# Autoloaded singleton: I18n
# Lightweight in-memory translation system. The full FR + EN tables live
# below as a single STRINGS dict (key → {fr, en}). At runtime the helper
# t() returns the current locale's value; UI code listens for
# locale_changed to refresh.
#
# Why not Godot's native CSV translations? It works fine but requires
# the editor to have imported the .csv into a Translation resource. The
# CI builds headless on a fresh checkout so we'd need to commit the
# generated .translation files; embedding the strings in code keeps
# everything in one place.

signal locale_changed

const DEFAULT_LOCALE := "fr"
const SUPPORTED_LOCALES := ["fr", "en"]

var current_locale: String = DEFAULT_LOCALE


func t(key: String, args: Array = []) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	var text: String = entry.get(current_locale, key)
	if args.is_empty():
		return text
	return text % args


func set_locale(loc: String) -> void:
	if not loc in SUPPORTED_LOCALES or loc == current_locale:
		return
	current_locale = loc
	locale_changed.emit()


func toggle_locale() -> void:
	set_locale("en" if current_locale == "fr" else "fr")


# ─── Translation table ────────────────────────────────────────────────────────

const STRINGS := {
	# Players
	"player.red":           {"fr": "Rouge",   "en": "Red"},
	"player.blue":          {"fr": "Violet",  "en": "Purple"},
	"player.none":          {"fr": "—",       "en": "—"},

	# Domains
	"domain.ambition":      {"fr": "Ambition", "en": "Ambition"},
	"domain.desir":         {"fr": "Désir",    "en": "Desire"},
	"domain.foi":           {"fr": "Foi",      "en": "Faith"},
	"domain.peur":          {"fr": "Peur",     "en": "Fear"},
	"domain.volonte":       {"fr": "Volonté",  "en": "Will"},

	# Stations (with their roman numerals so the prefix stays universal)
	"station.murmures":     {"fr": "I — Murmures",    "en": "I — Whispers"},
	"station.tentation":    {"fr": "II — Tentation",  "en": "II — Temptation"},
	"station.chute":        {"fr": "III — Chute",     "en": "III — Fall"},
	"station.confession":   {"fr": "IV — Confession", "en": "IV — Confession"},
	"station.office":       {"fr": "V — Office sacré","en": "V — Holy Office"},
	"station.exorcisme":    {"fr": "VI — Exorcisme",  "en": "VI — Exorcism"},

	# Actions
	"action.investir":      {"fr": "Investir",  "en": "Invest"},
	"action.exploiter":     {"fr": "Exploiter", "en": "Exploit"},
	"action.provoquer":     {"fr": "Provoquer", "en": "Provoke"},
	"action.amplifier":     {"fr": "Amplifier", "en": "Amplify"},
	"action.sceller":       {"fr": "Sceller",   "en": "Seal"},
	"action.fissurer":      {"fr": "Fissurer",  "en": "Crack"},
	"action.entraver":      {"fr": "Entraver",  "en": "Hinder"},
	"action.passer":        {"fr": "Passer",    "en": "Pass"},

	# Card faces / liturgy modes
	"face.scandale":        {"fr": "Scandale", "en": "Scandal"},
	"face.infamie":         {"fr": "Infamie",  "en": "Infamy"},
	"liturgy.in_integro":   {"fr": "In Integro", "en": "In Integro"},
	"liturgy.impedita":     {"fr": "Impedita",   "en": "Impedita"},

	# UI — bottom bar
	"ui.btn.transgressions":{"fr": "Trans.",      "en": "Trans."},
	"ui.btn.new_game":      {"fr": "Nouvelle",    "en": "New game"},
	"ui.btn.next_station":  {"fr": "Station →",   "en": "Station →"},
	"ui.btn.pass":          {"fr": "Passer",      "en": "Pass"},
	"ui.btn.journal":       {"fr": "Journal",     "en": "Journal"},

	# UI — dialogs
	"ui.dialog.continue":           {"fr": "Continuer",       "en": "Continue"},
	"ui.dialog.close":              {"fr": "Fermer",          "en": "Close"},
	"ui.dialog.new_game":           {"fr": "Nouvelle partie", "en": "New game"},
	"ui.dialog.skip_exploit":       {"fr": "Passer (ne pas exploiter)", "en": "Skip (don't exploit)"},
	"ui.dialog.must_choose":        {"fr": "(choix obligatoire)",       "en": "(choice required)"},
	"ui.dialog.title.liturgy":      {"fr": "Réponse liturgique",        "en": "Liturgical Response"},
	"ui.dialog.title.decision":     {"fr": "Décision",                  "en": "Decision"},
	"ui.dialog.title.endgame":      {"fr": "Exorcisme final",           "en": "Final Exorcism"},
	"ui.dialog.title.transgressions":{"fr": "Transgressions",           "en": "Transgressions"},
	"ui.dialog.title.card":         {"fr": "Carte",                     "en": "Card"},
	"ui.dialog.title.placed":       {"fr": "Transgressions posées",      "en": "Placed Transgressions"},

	# UI — labels / hints
	"ui.tooltip.click_to_zoom":     {"fr": "Cliquer pour agrandir",   "en": "Click to enlarge"},
	"ui.tooltip.station_card":      {"fr": "Cliquer pour voir la Réponse liturgique de la Station",
	                                 "en": "Click to view this Station's Liturgical Response"},
	"ui.tooltip.see_card":          {"fr": "Cliquer pour voir la carte", "en": "Click to view the card"},
	"ui.flip.see_infamy":           {"fr": "Voir Infamie ↻",   "en": "View Infamy ↻"},
	"ui.flip.see_scandal":          {"fr": "Voir Scandale ↻",  "en": "View Scandal ↻"},
	"ui.flip.see_impedita":         {"fr": "Voir Impedita ↻",  "en": "View Impedita ↻"},
	"ui.flip.see_in_integro":       {"fr": "Voir In Integro ↻","en": "View In Integro ↻"},
	"ui.player_panel.title":        {"fr": "%s — Transgressions", "en": "%s — Transgressions"},
	"ui.player_panel.empty":        {"fr": "(aucune)", "en": "(none)"},
	"ui.transgression.state.free": {"fr": "Libre (face Scandale)", "en": "Available (Scandal face)"},
	"ui.transgression.state.owned":{"fr": "%s · %s", "en": "%s · %s"}, # face · player
	"ui.transgression.btn.provoke":     {"fr": "Provoquer",              "en": "Provoke"},
	"ui.transgression.btn.provoke_in":  {"fr": "Provoquer (%s)",          "en": "Provoke (%s)"},
	"ui.transgression.btn.amplify":     {"fr": "Amplifier",              "en": "Amplify"},
	"ui.popup.provoke_in":              {"fr": "Provoquer %s en %s",      "en": "Provoke %s in %s"},
	"ui.status_label.fmt":              {"fr": "Station %s — Pulse %d/%d — Actif: %s — Init: %s",
	                                     "en": "Station %s — Pulse %d/%d — Active: %s — Init: %s"},
	"ui.game_over":                     {"fr": "PARTIE TERMINÉE — %s",   "en": "GAME OVER — %s"},
	"ui.transgressions_title.active":   {"fr": "Transgressions — Joueur actif : %s",
	                                     "en": "Transgressions — Active Player: %s"},

	# UI — language toggle button (always shows the OTHER language)
	"ui.btn.toggle_lang":               {"fr": "EN", "en": "FR"},
	"ui.btn.toggle_lang.tooltip":       {"fr": "Switch to English",  "en": "Passer en français"},

	# Mode strings used in liturgy dialogs
	"liturgy.mode_in_integro":          {"fr": "In Integro",        "en": "In Integro"},
	"liturgy.mode_impedita":            {"fr": "Impedita",          "en": "Impedita"},

	# Resolution / target prefixes shown in liturgy dialog
	"liturgy.target":                   {"fr": "Cible",             "en": "Target"},
	"liturgy.resolution":               {"fr": "Résolution",        "en": "Resolution"},
	"liturgy.no_effect":                {"fr": "(aucun effet)",     "en": "(no effect)"},
	"liturgy.station_end":              {"fr": "Fin de la Station %s", "en": "End of Station %s"},
	"liturgy.in_integro_full":          {"fr": "In Integro : %s", "en": "In Integro: %s"},
	"liturgy.impedita_full":            {"fr": "Impedita : %s", "en": "Impedita: %s"},

	# ─── Transgression names ─────────────────────────────────────────────────
	"transgression.nepotisme.name":     {"fr": "Népotisme",            "en": "Nepotism"},
	"transgression.trafic_charges.name":{"fr": "Trafic de charges",    "en": "Office Trafficking"},
	"transgression.festin_obscene.name":{"fr": "Festin obscène",       "en": "Obscene Feast"},
	"transgression.favori_secret.name": {"fr": "Favori secret",        "en": "Secret Favorite"},
	"transgression.simonie.name":       {"fr": "Simonie",              "en": "Simony"},
	"transgression.profanation.name":   {"fr": "Profanation",          "en": "Profanation"},
	"transgression.paranoia.name":      {"fr": "Paranoïa",             "en": "Paranoia"},
	"transgression.persecution.name":   {"fr": "Persécution",          "en": "Persecution"},
	"transgression.pacte_silencieux.name":{"fr": "Pacte silencieux",   "en": "Silent Pact"},
	"transgression.abdication_interieure.name":{"fr": "Abdication intérieure","en": "Inner Abdication"},

	# Transgression scandal / infamy texts
	"transgression.nepotisme.scandal":  {"fr": "Gagnez 1 Corruption disponible.",
	                                     "en": "Gain 1 available Corruption."},
	"transgression.nepotisme.infamy":   {"fr": "Tant que vous contrôlez Ambition, votre première Transgression de chaque Station coûte 1 Corruption de moins (min. 1).",
	                                     "en": "While you control Ambition, your first Transgression each Station costs 1 less Corruption (min. 1)."},
	"transgression.trafic_charges.scandal":{"fr": "La prochaine Entrave que vous payez coûte 1 Corruption de moins (min. 1).",
	                                       "en": "Your next Hinder costs 1 less Corruption (min. 1)."},
	"transgression.trafic_charges.infamy":{"fr": "Une fois par Station, en provoquant une Transgression liée à Ambition ou Foi, gagnez 1 Corruption disponible.",
	                                      "en": "Once per Station, when you provoke an Ambition- or Faith-linked Transgression, gain 1 available Corruption."},
	"transgression.festin_obscene.scandal":{"fr": "Gagnez 2 Corruptions disponibles.",
	                                       "en": "Gain 2 available Corruptions."},
	"transgression.festin_obscene.infamy":{"fr": "Quand vous exploitez Désir, gagnez 1 Corruption supplémentaire.",
	                                      "en": "When you exploit Desire, gain 1 extra Corruption."},
	"transgression.favori_secret.scandal":{"fr": "Placez 1 Corruption disponible sur Volonté (sinon, ignoré).",
	                                      "en": "Place 1 available Corruption on Will (otherwise ignored)."},
	"transgression.favori_secret.infamy":{"fr": "Une fois par Station, vous pouvez déplacer 1 de vos Corruptions de Désir vers Volonté.",
	                                     "en": "Once per Station, you may move 1 of your Corruptions from Desire to Will."},
	"transgression.simonie.scandal":   {"fr": "Placez une Entrave sur la Réponse liturgique de cette Station ou de la prochaine.",
	                                   "en": "Place a Hinder on this Station's or the next Station's Liturgical Response."},
	"transgression.simonie.infamy":    {"fr": "La prochaine Réponse liturgique qui cible Foi est automatiquement Impedita.",
	                                   "en": "The next Liturgical Response that targets Faith is automatically Impedita."},
	"transgression.profanation.scandal":{"fr": "Retirez un Anneau de Pénitence d'un Domaine que vous contrôlez. Sinon, gagnez 1 Corruption disponible.",
	                                    "en": "Remove a Penitence Ring from a Domain you control. Otherwise, gain 1 available Corruption."},
	"transgression.profanation.infamy":{"fr": "Foi contient une Infamie (peut remplir Profondeur).",
	                                   "en": "Faith contains an Infamy (may fill Depth)."},
	"transgression.paranoia.scandal":  {"fr": "Fissurez un Domaine scellé par l'autre démon. Sinon, l'autre perd 1 Corruption disponible.",
	                                   "en": "Crack a Domain sealed by the other demon. Otherwise, the other loses 1 available Corruption."},
	"transgression.paranoia.infamy":   {"fr": "Une fois par Station, sur une Réponse liturgique, vous pouvez choisir entre les deux Domaines les plus éligibles.",
	                                   "en": "Once per Station, on a Liturgical Response, you may choose between the two most eligible Domains."},
	"transgression.persecution.scandal":{"fr": "Choisissez un Domaine contesté : l'autre démon y retire 1 Corruption. Sinon, il perd 1 Corruption disponible.",
	                                    "en": "Choose a contested Domain: the other demon loses 1 Corruption there. Otherwise, they lose 1 available Corruption."},
	"transgression.persecution.infamy":{"fr": "Quand vous Brisez la Domination dans un Domaine, l'autre démon y retire 1 Corruption supplémentaire.",
	                                   "en": "When you Break Domination in a Domain, the other demon loses 1 extra Corruption there."},
	"transgression.pacte_silencieux.scandal":{"fr": "Placez 1 Corruption disponible sur Volonté (sinon ignoré).",
	                                         "en": "Place 1 available Corruption on Will (otherwise ignored)."},
	"transgression.pacte_silencieux.infamy":{"fr": "À l'Exorcisme final, si vous contrôlez Volonté, gagnez +1 Ascendant.",
	                                        "en": "At the Final Exorcism, if you control Will, gain +1 Ascendant."},
	"transgression.abdication_interieure.scandal":{"fr": "Si vous contrôlez Volonté, gagnez 1 Corruption ; sinon, placez 1 Corruption sur Volonté (sinon ignoré).",
	                                              "en": "If you control Will, gain 1 Corruption; otherwise, place 1 Corruption on Will (otherwise ignored)."},
	"transgression.abdication_interieure.infamy":{"fr": "À l'Exorcisme final, si Volonté est scellée par vous, +1 Ascendant supplémentaire.",
	                                             "en": "At the Final Exorcism, if Will is sealed by you, +1 extra Ascendant."},

	# Liturgical responses
	"liturgy.signe_de_croix.name":     {"fr": "Signe de croix",        "en": "Sign of the Cross"},
	"liturgy.signe_de_croix.in_integro":{"fr": "Brise la Domination dans le Domaine ciblé. Sinon, chaque démon y perd 1 Corruption disponible.",
	                                    "en": "Break Domination in the targeted Domain. Otherwise, each demon loses 1 available Corruption there."},
	"liturgy.signe_de_croix.impedita": {"fr": "Le démon avec le plus d'Emprise dans le Domaine ciblé perd 1 Corruption disponible.",
	                                   "en": "The demon with the most Grip in the targeted Domain loses 1 available Corruption."},
	"liturgy.examen_de_conscience.name":{"fr": "Examen de conscience","en": "Examination of Conscience"},
	"liturgy.examen_de_conscience.in_integro":{"fr": "Brise la Domination ; ce Domaine ne peut pas être scellé jusqu'à la fin de la prochaine Station.",
	                                          "en": "Break Domination; this Domain cannot be Sealed until the end of the next Station."},
	"liturgy.examen_de_conscience.impedita":{"fr": "Ce Domaine ne peut pas être scellé jusqu'à la fin de cette Station.",
	                                        "en": "This Domain cannot be Sealed until the end of this Station."},
	"liturgy.contrition.name":         {"fr": "Contrition", "en": "Contrition"},
	"liturgy.contrition.in_integro":   {"fr": "Si scellé : Fissure liturgique (Sceau retiré + Domination brisée). Sinon : Brise la Domination. Puis Pénitence.",
	                                   "en": "If Sealed: Liturgical Crack (Seal removed + Domination broken). Otherwise: Break Domination. Then Penitence."},
	"liturgy.contrition.impedita":     {"fr": "Mettez ce Domaine en Pénitence jusqu'à la fin de la prochaine Station.",
	                                   "en": "Put this Domain in Penitence until the end of the next Station."},
	"liturgy.confession.name":         {"fr": "Confession", "en": "Confession"},
	"liturgy.confession.in_integro":   {"fr": "Le démon ciblé choisit DEUX pénitences différentes parmi 3.",
	                                   "en": "The targeted demon chooses TWO different penitences out of 3."},
	"liturgy.confession.impedita":     {"fr": "Le démon ciblé choisit UNE pénitence parmi 3.",
	                                   "en": "The targeted demon chooses ONE penitence out of 3."},
	"liturgy.communion.name":          {"fr": "Communion", "en": "Communion"},
	"liturgy.communion.in_integro":    {"fr": "Si scellé : Fissure liturgique. Puis interdit le rescellement avant l'Exorcisme.",
	                                   "en": "If Sealed: Liturgical Crack. Then forbids resealing before the Exorcism."},
	"liturgy.communion.impedita":      {"fr": "Si scellé : Fissure simple (Sceau retiré). Sinon : Brise la Domination.",
	                                   "en": "If Sealed: simple Crack (Seal removed). Otherwise: Break Domination."},

	# GameRules error messages (why_cannot_*)
	"err.sealed_by_opponent":          {"fr": "scellé par l'adversaire",            "en": "sealed by the opponent"},
	"err.not_controlled":              {"fr": "non contrôlé par toi",                "en": "not controlled by you"},
	"err.already_exploited":           {"fr": "déjà exploité cette Station",         "en": "already exploited this Station"},
	"err.already_sealed":              {"fr": "déjà scellé",                          "en": "already Sealed"},
	"err.seal_forbidden_until_exorcism":{"fr": "Sceau interdit jusqu'à l'Exorcisme (Communion)",
	                                    "en": "Seal forbidden until the Exorcism (Communion)"},
	"err.in_penitence":                {"fr": "en Pénitence",                        "en": "in Penitence"},
	"err.not_sealed":                  {"fr": "pas scellé",                          "en": "not Sealed"},
	"err.already_owned_by":            {"fr": "déjà possédée par %s",                "en": "already owned by %s"},
	"err.no_scandale_owned":           {"fr": "tu ne possèdes pas cette Transgression en Scandale",
	                                    "en": "you don't own this Transgression as Scandal"},
	"err.origin_not_sealed":           {"fr": "Domaine d'origine (%s) non scellé par toi",
	                                    "en": "Origin Domain (%s) not Sealed by you"},
	"err.origin_in_penitence":         {"fr": "Domaine d'origine (%s) en Pénitence",
	                                    "en": "Origin Domain (%s) in Penitence"},
	"err.illegal_transgression":       {"fr": "Transgression illégale.",             "en": "Illegal Transgression."},
	"err.no_corruption":               {"fr": "0 Corruption disponible",             "en": "0 available Corruption"},
	"err.cannot_fissure_own":          {"fr": "tu ne peux pas fissurer ton propre Sceau",
	                                    "en": "you cannot crack your own Seal"},
	"err.not_enough_corruption":       {"fr": "pas assez de Corruption (coût %d)",   "en": "not enough Corruption (cost %d)"},
	"err.need_net_domination":         {"fr": "Domination nette ≥2 requise",         "en": "Net Domination ≥2 required"},
	"err.unknown_transgression":       {"fr": "Transgression inconnue",              "en": "Unknown Transgression"},
	"err.must_control_one_of":         {"fr": "doit contrôler : %s",                 "en": "must control: %s"},
	"glue.or":                         {"fr": " ou ",                                 "en": " or "},

	# Decision dialog
	"ui.decision.exploit_hint":        {"fr": "%s : choisis un domaine à exploiter, ou clique « Passer ».",
	                                    "en": "%s: choose a domain to exploit, or click \"Pass\"."},
	"ui.decision.penitence_hint":      {"fr": "%s doit choisir %d pénitence%s parmi 3 (mode %s).",
	                                    "en": "%s must choose %d penitence%s out of 3 (%s mode)."},
	"ui.decision.penitence_btn":       {"fr": "Pénitence : %s", "en": "Penitence: %s"},

	# Endgame dialog
	"ui.endgame.pope_saved":           {"fr": "Pape sauvé (aucun démon)", "en": "Pope saved (no demon)"},
	"ui.endgame.soul_rupture":         {"fr": "Rupture de l'âme :", "en": "Soul Rupture:"},
	"ui.endgame.complete_label":       {"fr": "Complète", "en": "Complete"},
	"ui.endgame.complete_yes":         {"fr": "OUI — l'exorcisme échoue", "en": "YES — the exorcism fails"},
	"ui.endgame.complete_no":          {"fr": "NON — l'exorcisme réussit", "en": "NO — the exorcism succeeds"},
	"ui.endgame.last_log_lines":       {"fr": "Résolution (dernières lignes du journal) :",
	                                    "en": "Resolution (last log lines):"},
	"ui.endgame.profondeur":           {"fr": "Profondeur",        "en": "Depth"},
	"ui.endgame.etendue":              {"fr": "Étendue",           "en": "Breadth"},
	"ui.endgame.ancrage":              {"fr": "Ancrage",           "en": "Anchor"},
	"ui.endgame.filled":               {"fr": "✓ remplie",         "en": "✓ filled"},
	"ui.endgame.filled_m":             {"fr": "✓ rempli",          "en": "✓ filled"},
	"ui.endgame.unfilled":             {"fr": "— non remplie",     "en": "— unfilled"},
	"ui.endgame.unfilled_m":           {"fr": "— non rempli",      "en": "— unfilled"},
	"ui.endgame.final_ascendant":      {"fr": "Ascendant final",   "en": "Final Ascendant"},

	# Logs
	"log.new_game":                    {"fr": "*** NOUVELLE PARTIE COMMENCÉE à %s ***",
	                                    "en": "*** NEW GAME STARTED at %s ***"},
	"log.pending_decision_unhandled":  {"fr": "[INFO] Une décision est en attente — non géré dans cette UI.",
	                                    "en": "[INFO] A decision is pending — not handled in this UI."},
	"log.decision_pending":            {"fr": "[INFO] Décision en attente — non géré.",
	                                    "en": "[INFO] Decision pending — not handled."},
	"log.refused":                     {"fr": "REFUSÉ", "en": "REFUSED"},

	# Penitence count plural marker (s for FR plurals; English uses "es" suffix in caller logic)
	"ui.decision.plural_s":            {"fr": "s", "en": "s"},

	"ui.decision.title.free_exploit":  {"fr": "Exploitation gratuite — %s", "en": "Free Exploit — %s"},
	"ui.decision.title.confession":    {"fr": "Confession — %s",            "en": "Confession — %s"},
	"ui.decision.btn.exploit":         {"fr": "Exploiter %s",               "en": "Exploit %s"},
	"ui.decision.btn.lose2":           {"fr": "Perdre 2 Corruptions disponibles",
	                                    "en": "Lose 2 available Corruptions"},
	"ui.decision.btn.fissure_own":     {"fr": "Fissurer mon Sceau sur %s",  "en": "Crack my own Seal on %s"},

	# Liturgy dialog inline labels
	"ui.liturgy.resolution_header":    {"fr": "Résolution :", "en": "Resolution:"},

	# Bottom bar — extra label keys for buttons re-rendered on locale change
	"ui.btn.zoom_out":                 {"fr": "−", "en": "−"},
	"ui.btn.zoom_in":                  {"fr": "+", "en": "+"},
	"ui.btn.zoom_reset":               {"fr": "⊙", "en": "⊙"},

	# DomainData yields (printed in domain tooltips/debug)
	"domain.yield.transgressed_2_3":   {"fr": "2 (3 si transgressé)",             "en": "2 (3 if Transgressed)"},
	"domain.yield.transgressed_1_2":   {"fr": "1 (2 si transgressé)",             "en": "1 (2 if Transgressed)"},
	"domain.yield.cracked_1_2":        {"fr": "1 (2 si Domaine fissuré ce tour)", "en": "1 (2 if Domain cracked this turn)"},
}
