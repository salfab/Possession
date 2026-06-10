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
	"action.puiser":        {"fr": "Puiser dans l'Ombre", "en": "Draw from the Shadow"},

	# Card faces / liturgy modes
	"face.scandale":        {"fr": "Scandale", "en": "Scandal"},
	"face.infamie":         {"fr": "Infamie",  "en": "Infamy"},
	"liturgy.in_integro":   {"fr": "In Integro", "en": "In Integro"},
	"liturgy.impedita":     {"fr": "Impedita",   "en": "Impedita"},
	"liturgy.target_line":  {"fr": "Cible : %s", "en": "Target: %s"},
	# Targeting-rule descriptions — shown by tapping the badge slot on a
	# Liturgy card. They explain *how* the target is picked, since the
	# resolved target itself can shift between Stations as the board state
	# evolves.
	"liturgy.targeting.signe_de_croix": {
		"fr": "Le Domaine avec le plus d'Emprise totale. En cas d'égalité : priorité Volonté > Foi > Désir > Ambition > Peur.",
		"en": "The Domain with the most total Grip. On tie: priority Will > Faith > Desire > Ambition > Fear.",
	},
	"liturgy.targeting.examen_de_conscience": {
		"fr": "Ambition ou Désir, le Domaine avec le plus d'Emprise totale. Ambition en cas d'égalité.",
		"en": "Ambition or Desire, the Domain with the most total Grip. Ambition on tie.",
	},
	"liturgy.targeting.contrition": {
		"fr": "Le Domaine transgressé le plus grave : plus d'Infamies, puis plus de Scandales, puis plus d'Emprise. Aucune cible si aucun Domaine n'est transgressé (la Liturgie n'a alors aucun effet).",
		"en": "The most-serious transgressed Domain: most Infamies, then most Scandals, then most Grip. No target if no Domain is transgressed (the Liturgy then has no effect).",
	},
	"liturgy.targeting.confession": {
		"fr": "Le démon avec le plus de Transgressions placées. En cas d'égalité : démon avec Ascendant ; sinon, démon sans Initiative.",
		"en": "The demon with the most placed Transgressions. On tie: demon holding Ascendancy; otherwise the demon without Initiative.",
	},
	"liturgy.targeting.communion": {
		"fr": "Foi ou Volonté. Priorité : Domaine scellé > Domaine avec Infamie > Domaine avec le plus d'Emprise.",
		"en": "Faith or Will. Priority: Sealed Domain > Domain with an Infamy > Domain with the most Grip.",
	},
	"liturgy.targeting.exorcisme": {
		"fr": "Pas de cible — résolution finale du jeu (issue calculée à partir de l'état du plateau).",
		"en": "No target — final resolution of the game (outcome computed from board state).",
	},

	# UI — bottom bar
	"ui.btn.transgressions":{"fr": "Trans.",      "en": "Trans."},
	"ui.btn.new_game":      {"fr": "Nouvelle",    "en": "New game"},
	"ui.btn.next_station":  {"fr": "Station »",   "en": "Station »"},
	"ui.btn.pass":          {"fr": "Passer",      "en": "Pass"},
	"ui.btn.journal":       {"fr": "Journal",     "en": "Journal"},
	"ui.btn.glossary":      {"fr": "Glossaire",   "en": "Glossary"},
	"ui.btn.hotspots":      {"fr": "Zones",       "en": "Hotspots"},
	"ui.btn.arches":        {"fr": "Arches pénitence", "en": "Penitence arches"},
	"ui.btn.puiser":        {"fr": "Puiser",      "en": "Draw"},
	"ui.btn.puiser.tooltip":{"fr": "Puiser dans l'Ombre — gagner 1 Corruption (uniquement si réserve à 0)",
	                         "en": "Draw from the Shadow — gain 1 Corruption (only when your pool is empty)"},

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
	"ui.dialog.title.glossary":     {"fr": "Glossaire",                  "en": "Glossary"},
	"ui.dialog.title.resume":       {"fr": "Partie sauvegardée",         "en": "Saved game"},
	"ui.dialog.resume_message":     {"fr": "Une partie sauvegardée a été trouvée. Souhaitez-vous la reprendre ?",
	                                 "en": "A saved game was found. Would you like to resume it?"},
	"ui.dialog.resume_yes":         {"fr": "Reprendre",                  "en": "Resume"},
	"ui.dialog.resume_no":          {"fr": "Nouvelle partie",            "en": "New game"},
	"ui.dialog.title.new_game":     {"fr": "Nouvelle partie",            "en": "New game"},
	"ui.dialog.start":              {"fr": "Commencer",                  "en": "Start"},
	"ui.dialog.cancel":             {"fr": "Annuler",                    "en": "Cancel"},
	"ui.player.human":              {"fr": "Humain",                     "en": "Human"},
	"ui.player.ai":                 {"fr": "IA",                         "en": "AI"},
	"ui.dialog.title.targeting_rule":{"fr": "Règle de ciblage",           "en": "Targeting rule"},
	"ui.dialog.title.effect_detail":{"fr": "Détail de l'effet",          "en": "Effect detail"},
	"ui.tooltip.tap_for_targeting_rule":{"fr": "Toucher pour voir la règle de ciblage",
	                                    "en": "Tap to see the targeting rule"},
	"ui.tooltip.tap_for_effect_detail":{"fr": "Toucher pour voir le détail de l'effet",
	                                   "en": "Tap to see the detailed effect"},
	"ui.tooltip.liturgy_banner":   {"fr": "Toucher pour voir la carte de cette Liturgie",
	                                "en": "Tap to view this Liturgy card"},
	"ui.tooltip.exorcism_banner":  {"fr": "Toucher pour voir la carte de l'Exorcisme final",
	                                "en": "Tap to view the final Exorcism card"},

	# UI — labels / hints
	"ui.tooltip.click_to_zoom":     {"fr": "Cliquer pour agrandir",   "en": "Click to enlarge"},
	"ui.tooltip.station_card":      {"fr": "Cliquer pour voir la Réponse liturgique de la Station",
	                                 "en": "Click to view this Station's Liturgical Response"},
	"ui.tooltip.see_card":          {"fr": "Cliquer pour voir la carte", "en": "Click to view the card"},
	"ui.flip.see_infamy":           {"fr": "Voir Infamie",   "en": "View Infamy"},
	"ui.flip.see_scandal":          {"fr": "Voir Scandale",  "en": "View Scandal"},
	"ui.flip.see_impedita":         {"fr": "Voir Impedita",  "en": "View Impedita"},
	"ui.flip.see_in_integro":       {"fr": "Voir In Integro","en": "View In Integro"},
	"ui.flip.see_back":             {"fr": "Voir les règles","en": "View rules"},
	"ui.flip.see_front":            {"fr": "Voir la carte",  "en": "View card"},
	"ui.player_panel.title":        {"fr": "%s — Transgressions", "en": "%s — Transgressions"},
	"ui.player_panel.empty":        {"fr": "(aucune)", "en": "(none)"},
	"ui.player_panel.reserve":      {"fr": "Réserve : %d Corruption%s",
	                                 "en": "Pool: %d Corruption%s"},
	"ui.transgression.state.free": {"fr": "Libre (face Scandale)", "en": "Available (Scandal face)"},
	"ui.transgression.state.owned":{"fr": "%s · %s", "en": "%s · %s"}, # face · player
	"ui.transgression.btn.provoke":     {"fr": "Provoquer",              "en": "Provoke"},
	"ui.transgression.btn.provoke_in":  {"fr": "Provoquer (%s)",          "en": "Provoke (%s)"},
	"ui.transgression.btn.amplify":     {"fr": "Amplifier",              "en": "Amplify"},
	"ui.btn.entraver":                  {"fr": "Entraver",               "en": "Hinder"},
	# V1h positional cost — "%s" is the source Domain name, the action
	# always removes exactly 1 of the active demon's Corruptions from
	# that Domain on the board (no reserve cost). Used when only one
	# linked Domain is a legal payment source.
	"ui.btn.entraver_cost":             {"fr": "Entraver (-1 Corr. en %s)",
	                                     "en": "Hinder (-1 Corr. on %s)"},
	# When multiple linked Domains are legal payment sources — the UI
	# pops a picker after the click, no specific Domain in the label.
	"ui.btn.entraver_cost_generic":     {"fr": "Entraver (-1 Corruption)",
	                                     "en": "Hinder (-1 Corruption)"},
	"ui.btn.entraver.tooltip":          {"fr": "Retirer 1 de vos Corruptions d'un Domaine lié que vous contrôlez. La Réponse devient Impedita.",
	                                     "en": "Remove 1 of your Corruptions from a linked Domain you control. The Response becomes Impedita."},
	"ui.dialog.title.entrave_pick":     {"fr": "Entraver — choisir le Domaine", "en": "Hinder — choose the Domain"},
	"ui.dialog.entrave_pick_prompt":    {"fr": "Retirer 1 de vos Corruptions de :",
	                                     "en": "Remove 1 of your Corruptions from:"},
	"ui.liturgy.banner.in_integro":    {"fr": "%s\nIn Integro",          "en": "%s\nIn Integro"},
	"ui.liturgy.banner.impedita":      {"fr": "%s\nImpedita",            "en": "%s\nImpedita"},

	# ─── Banner cartouche text — ultra-minimal one-liners (or two), tuned to
	# fit the parchment area without wrapping more than 2 lines. Distinct
	# from the full liturgy.<id>.<mode> texts shown on the actual card.
	# Glyphs picked from the safest blocks (Basic Latin, General Punctuation,
	# Arrows) so they render on the iOS WebKit fallback fonts. ─────────────
	"banner.signe_de_croix.in_integro":      {"fr": "Brise Domination",       "en": "Break Domination"},
	"banner.signe_de_croix.impedita":        {"fr": "−1 Corr. au + dominant", "en": "−1 Corr. on top dominant"},
	"banner.examen_de_conscience.in_integro":{"fr": "Brise Dom. + bloque Sceau",
	                                          "en": "Break Dom. + bar Seal"},
	"banner.examen_de_conscience.impedita":  {"fr": "Bloque Sceau",           "en": "Bar Seal"},
	"banner.contrition.in_integro":          {"fr": "Fissure + Pénitence",    "en": "Crack + Penitence"},
	"banner.contrition.impedita":            {"fr": "Pénitence",              "en": "Penitence"},
	"banner.confession.in_integro":          {"fr": "2 pénitences / 3",       "en": "2 penitences / 3"},
	"banner.confession.impedita":            {"fr": "1 pénitence / 3",        "en": "1 penitence / 3"},
	"banner.communion.in_integro":           {"fr": "Fissure + bloque rescell.",
	                                          "en": "Crack + bar reseal"},
	"banner.communion.impedita":             {"fr": "Fissure ou Brise",       "en": "Crack or Break"},
	"banner.exorcisme.special":              {"fr": "Exorcisme final",        "en": "Final Exorcism"},
	"ui.popup.provoke_in":              {"fr": "Provoquer %s en %s",      "en": "Provoke %s in %s"},
	"ui.popup.amplify_in":              {"fr": "Amplifier %s en %s",      "en": "Amplify %s in %s"},
	"ui.popup.exploit_gain":            {"fr": "Exploiter %s  (+%d Corruption%s)",
	                                     "en": "Exploit %s  (+%d Corruption%s)"},
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

	# ── Codex des Transgressions — cartes 11-20 ─────────────────────────────
	"transgression.intrigue_consistoire.name":   {"fr": "Intrigue de consistoire", "en": "Consistory Intrigue"},
	"transgression.intrigue_consistoire.scandal":{"fr": "Choisissez un Domaine que vous contrôlez sans Domination nette et non scellé. Jusqu'à fin de Station, vous pouvez le Sceller sans Domination nette. Si aucune cible : +1 Corruption.",
	                                              "en": "Choose a Domain you control without Net Domination, not Sealed. Until end of Station, you may Seal it without Net Domination. No valid target: +1 Corruption."},
	"transgression.intrigue_consistoire.infamy": {"fr": "Une fois par Station, quand vous Scellez, vous pouvez ignorer l'interdiction permanente de Scellement (Communion). N'ignore jamais la Pénitence.",
	                                              "en": "Once per Station, when you Seal, you may ignore the permanent Seal prohibition (Communion). Never ignores Penitence."},

	"transgression.bulle_vendue.name":           {"fr": "Bulle vendue",          "en": "Sold Bull"},
	"transgression.bulle_vendue.scandal":        {"fr": "Retirez l'interdiction permanente de Scellement (Communion) d'un Domaine que vous contrôlez. Si aucune cible : +1 Corruption.",
	                                              "en": "Remove the permanent Seal prohibition (Communion) from a Domain you control. No target: +1 Corruption."},
	"transgression.bulle_vendue.infamy":         {"fr": "Une fois par Station, lorsqu'une Réponse liturgique interdit le Scellement d'un Domaine que vous contrôlez, vous pouvez ignorer cette interdiction en perdant 1 Ascendant.",
	                                              "en": "Once per Station, when a Liturgical Response would forbid Sealing a Domain you control, you may ignore it by losing 1 Ascendancy."},

	"transgression.mascarade_velours.name":      {"fr": "Mascarade de velours",   "en": "Velvet Masquerade"},
	"transgression.mascarade_velours.scandal":   {"fr": "Déplacez 1 de vos Corruptions depuis un Domaine vers un autre Domaine non scellé par l'autre démon.",
	                                              "en": "Move 1 of your Corruptions from one Domain to another not Sealed by the other demon."},
	"transgression.mascarade_velours.infamy":    {"fr": "Une fois par Station, quand une Réponse liturgique cible Désir, vous pouvez déplacer 1 de vos Corruptions depuis Désir vers un Domaine non scellé par l'autre démon, avant résolution.",
	                                              "en": "Once per Station, when a Liturgical Response targets Desire, you may move 1 of your Corruptions from Desire to a Domain not Sealed by the other demon, before resolution."},

	"transgression.appetit_heretique.name":      {"fr": "Appétit hérétique",      "en": "Heretical Appetite"},
	"transgression.appetit_heretique.scandal":   {"fr": "La prochaine Transgression que vous provoquez cette Station peut être jouée depuis un Domaine que vous ne contrôlez pas, si vous contrôlez Désir, avez ≥1 Corruption dans le Domaine requis, et ce Domaine n'est pas scellé par l'adversaire. Si non utilisé avant fin de Station : +1 Corruption.",
	                                              "en": "Your next Transgression this Station may be played from a Domain you don't control, if you control Desire, have ≥1 Corruption in the required Domain, and it isn't Sealed by the opponent. If unused at end of Station: +1 Corruption."},
	"transgression.appetit_heretique.infamy":    {"fr": "Une fois par Station, tant que vous contrôlez Désir, vous pouvez provoquer une Transgression depuis un Domaine que vous ne contrôlez pas, si vous y avez ≥1 Corruption (non scellé par l'adversaire).",
	                                              "en": "Once per Station, while controlling Desire, you may provoke a Transgression from a Domain you don't control if you have ≥1 Corruption there (not Sealed by the opponent)."},

	"transgression.dogme_renverse.name":         {"fr": "Dogme renversé",         "en": "Overturned Dogma"},
	"transgression.dogme_renverse.scandal":      {"fr": "Choisissez cette Station ou la prochaine. Si sa Réponse liturgique se résout In Integro, gagnez 2 Corruptions disponibles après résolution. Si Impedita, effet perdu.",
	                                              "en": "Choose this Station or the next. If its Liturgical Response resolves In Integro, gain 2 available Corruptions after resolution. If Impedita, effect lost."},
	"transgression.dogme_renverse.infamy":       {"fr": "Une fois par Station, après une Réponse liturgique In Integro, si vous contrôlez Foi, gagnez 1 Corruption disponible.",
	                                              "en": "Once per Station, after an In Integro Liturgical Response, if you control Faith, gain 1 available Corruption."},

	"transgression.reliques_menteuses.name":     {"fr": "Reliques menteuses",      "en": "False Relics"},
	"transgression.reliques_menteuses.scandal":  {"fr": "Choisissez un Domaine que vous contrôlez. Jusqu'à fin de la prochaine Station, la première Pénitence qu'il subirait est ignorée (les autres effets s'appliquent).",
	                                              "en": "Choose a Domain you control. Until end of the next Station, the first Penitence it would suffer is ignored (other effects still apply)."},
	"transgression.reliques_menteuses.infamy":   {"fr": "Une fois par Station, quand vous exploitez Foi, retirez une Pénitence ou une interdiction permanente de Scellement d'un Domaine que vous contrôlez. Sinon, Foi produit +1 Corruption.",
	                                              "en": "Once per Station, when you exploit Faith, remove a Penitence or permanent Seal prohibition from a Domain you control. Otherwise, Faith produces +1 Corruption."},

	"transgression.denonciation_anonyme.name":   {"fr": "Dénonciation anonyme",   "en": "Anonymous Denunciation"},
	"transgression.denonciation_anonyme.scandal":{"fr": "Choisissez un Domaine contrôlé par l'autre démon où vous avez ≥1 Corruption. Jusqu'à fin de Station, l'autre démon ne peut pas l'Exploiter. S'il l'a déjà Exploité, il perd 1 Corruption disponible. Si aucune cible : aucun effet.",
	                                              "en": "Choose a Domain controlled by the other demon where you have ≥1 Corruption. Until end of Station, the other demon cannot Exploit it. If already Exploited, the other demon loses 1 available Corruption. No valid target: no effect."},
	"transgression.denonciation_anonyme.infamy": {"fr": "Une fois par Station, quand vous investissez dans un Domaine contrôlé par l'autre démon, vous pouvez lui interdire d'Exploiter ce Domaine jusqu'à fin de Station.",
	                                              "en": "Once per Station, when you Invest in a Domain controlled by the other demon, you may forbid the other demon from Exploiting it until end of Station."},

	"transgression.panique_contagieuse.name":    {"fr": "Panique contagieuse",     "en": "Contagious Panic"},
	"transgression.panique_contagieuse.scandal": {"fr": "Choisissez un Domaine contesté. Chaque démon y ayant ≥1 Corruption y retire 1 Corruption et la déplace vers Peur, si Peur n'est pas scellée par son adversaire. Si aucun Domaine contesté : placez 1 de vos Corruptions disponibles sur Peur si possible.",
	                                              "en": "Choose a contested Domain. Each demon with ≥1 Corruption there removes 1 and moves it to Fear, if Fear isn't Sealed by their opponent. No contested Domain: place 1 of your available Corruptions on Fear if possible."},
	"transgression.panique_contagieuse.infamy":  {"fr": "Une fois par Station, quand un Domaine devient contesté, vous pouvez déplacer 1 de vos Corruptions entre Peur et ce Domaine (dans un sens ou l'autre). Destination interdite si scellée par l'adversaire.",
	                                              "en": "Once per Station, when a Domain becomes contested, you may move 1 of your Corruptions between Fear and that Domain (either direction). Destination forbidden if Sealed by the opponent."},

	"transgression.obeissance_pervertie.name":   {"fr": "Obéissance pervertie",   "en": "Perverted Obedience"},
	"transgression.obeissance_pervertie.scandal":{"fr": "À la prochaine Pulsation, vous agissez en premier, quelle que soit l'Initiative. L'Initiative officielle reste inchangée. Si aucune Pulsation ne reste cette Station, effet reporté à la première Pulsation de la prochaine Station.",
	                                              "en": "On the next Pulse, you act first regardless of Initiative. Official Initiative is unchanged. If no Pulse remains this Station, carry to the first Pulse of the next Station."},
	"transgression.obeissance_pervertie.infamy": {"fr": "Une fois par Station, au début de la première Pulsation, si vous contrôlez Volonté, vous agissez en premier (Initiative officielle inchangée).",
	                                              "en": "Once per Station, at the start of the first Pulse, if you control Will, you act first (official Initiative unchanged)."},

	"transgression.renoncement_noir.name":       {"fr": "Renoncement noir",        "en": "Dark Renunciation"},
	"transgression.renoncement_noir.scandal":    {"fr": "Retirez 1 de vos Corruptions d'un Domaine que vous contrôlez, puis gagnez 3 Corruptions disponibles. Si aucune cible : +1 Corruption.",
	                                              "en": "Remove 1 of your Corruptions from a Domain you control, then gain 3 available Corruptions. No target: +1 Corruption."},
	"transgression.renoncement_noir.infamy":     {"fr": "Une fois par Station, quand vous sacrifiez 1 Corruption d'un Domaine pour Entraver une Réponse liturgique, gagnez 1 Corruption disponible après l'Entrave.",
	                                              "en": "Once per Station, when you sacrifice 1 Corruption from a Domain to Hinder a Liturgical Response, gain 1 available Corruption after the Hinder."},

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
	"liturgy.contrition.in_integro":   {"fr": "Vise le Domaine transgressé le plus grave. Si scellé : Fissure liturgique (Sceau retiré + Domination brisée). Sinon : Brise la Domination. Puis Pénitence.",
	                                   "en": "Targets the most-serious transgressed Domain. If Sealed: Liturgical Crack (Seal removed + Domination broken). Otherwise: Break Domination. Then Penitence."},
	"liturgy.contrition.impedita":     {"fr": "Vise le Domaine transgressé le plus grave. Pénitence jusqu'à la fin de la prochaine Station.",
	                                   "en": "Targets the most-serious transgressed Domain. Penitence until the end of the next Station."},
	"liturgy.confession.name":         {"fr": "Confession", "en": "Confession"},
	"liturgy.confession.in_integro":   {"fr": "Le démon ciblé choisit DEUX pénitences différentes parmi 3 :\n• -2 Corruptions disponibles\n• Pénitence sur un Domaine contrôlé\n• Fissure d'un Sceau personnel",
	                                   "en": "The targeted demon chooses TWO different penitences out of 3:\n• -2 available Corruptions\n• Penitence on a controlled Domain\n• Crack a personal Seal"},
	"liturgy.confession.impedita":     {"fr": "Le démon ciblé choisit UNE pénitence parmi 3 :\n• -2 Corruptions disponibles\n• Pénitence sur un Domaine contrôlé\n• Fissure d'un Sceau personnel",
	                                   "en": "The targeted demon chooses ONE penitence out of 3:\n• -2 available Corruptions\n• Penitence on a controlled Domain\n• Crack a personal Seal"},
	"liturgy.communion.name":          {"fr": "Communion", "en": "Communion"},
	"liturgy.communion.in_integro":    {"fr": "Si scellé : Fissure liturgique. Puis interdit le rescellement avant l'Exorcisme.",
	                                   "en": "If Sealed: Liturgical Crack. Then forbids resealing before the Exorcism."},
	"liturgy.communion.impedita":      {"fr": "Si scellé : Fissure simple (Sceau retiré). Sinon : Brise la Domination.",
	                                   "en": "If Sealed: simple Crack (Seal removed). Otherwise: Break Domination."},

	# Exorcism — Station VI has no liturgical response and cannot be entravé.
	# This text fills the back side of the fullscreen Exorcism card so the
	# player can read both the Rupture conditions and the winner-determination
	# rules without leaving the card view.
	"liturgy.exorcisme.back": {
		"fr": "[font_size=32][b]Rupture de l'âme[/b][/font_size]\n[i]L'Exorcisme final échoue si les trois conditions sont remplies :[/i]\n\n[b]I — Profondeur[/b]\n3+ Infamies au total, ou Infamie en Foi / Volonté.\n\n[b]II — Étendue[/b]\n4+ Domaines transgressés.\n\n[b]III — Ancrage[/b]\n2+ Domaines scellés, ou Volonté scellée et transgressée.\n\n[color=#7a5a3a]———————[/color]\n\n[font_size=28][b]Démon vainqueur[/b][/font_size]\n[b]1.[/b] [b]Fiat Tenebris[/b] : Volonté scellée et transgressée par le même démon — il l'emporte.\n[b]2.[/b] Sinon, [b]Ascendant final[/b] avec bonus : +1 par Sceau (+1 si Volonté), +1 par Infamie contrôlée ou en Foi, bonus de pactes.\n[b]3.[/b] Égalité : Sceau de Volonté, puis contrôle de Volonté, puis Infamies, puis Domaines — sinon Possession instable.",
		"en": "[font_size=32][b]Soul Rupture[/b][/font_size]\n[i]The final Exorcism fails if all three conditions are met :[/i]\n\n[b]I — Depth[/b]\n3+ total Infamies, or any Infamy in Faith / Will.\n\n[b]II — Spread[/b]\n4+ transgressed Domains.\n\n[b]III — Anchor[/b]\n2+ Sealed Domains, or Will sealed and transgressed.\n\n[color=#7a5a3a]———————[/color]\n\n[font_size=28][b]Winning demon[/b][/font_size]\n[b]1.[/b] [b]Fiat Tenebris[/b] : Will sealed and transgressed by the same demon — that demon wins.\n[b]2.[/b] Otherwise, [b]final Ascendancy[/b] with bonuses : +1 per Seal (+1 for Will), +1 per controlled or Faith Infamy, pact bonuses.\n[b]3.[/b] Tie : Will's Seal, then Will's controller, then Infamies, then Domains — otherwise Unstable Possession.",
	},

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
	"err.puiser_only_when_empty":      {"fr": "Puiser dans l'Ombre n'est légal que si votre Réserve est à 0.",
	                                    "en": "Draw from the Shadow is only legal when your Pool is empty."},
	"log.puiser":                      {"fr": "%s puise dans l'Ombre : +1 Corruption disponible.",
	                                    "en": "%s draws from the Shadow: +1 available Corruption."},
	"err.no_corruption":               {"fr": "0 Corruption disponible",             "en": "0 available Corruption"},
	"err.cannot_fissure_own":          {"fr": "tu ne peux pas fissurer ton propre Sceau",
	                                    "en": "you cannot crack your own Seal"},
	"err.not_enough_corruption":       {"fr": "pas assez de Corruption (coût %d)",   "en": "not enough Corruption (cost %d)"},
	"err.entrave_exorcism":            {"fr": "L'Exorcisme ne peut pas être entravé.",
	                                    "en": "The Exorcism can't be hindered."},
	"err.entrave_past_station":        {"fr": "Cette Station est déjà passée.",
	                                    "en": "This Station has already passed."},
	"err.entrave_too_far":             {"fr": "Cette Station est trop éloignée (max +2).",
	                                    "en": "This Station is too far ahead (max +2)."},
	"err.entrave_no_linked_payment":   {"fr": "Aucun Domaine lié contrôlé avec une Corruption à dépenser.",
	                                    "en": "No controlled linked Domain with a Corruption to spend."},
	"err.entrave_already":             {"fr": "Cette Réponse est déjà entravée.",
	                                    "en": "This Response is already hindered."},
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
	"ui.decision.btn.exploit_gain":    {"fr": "Exploiter %s  (+%d Corruption%s)",
	                                    "en": "Exploit %s  (+%d Corruption%s)"},
	"ui.decision.btn.lose2":           {"fr": "Perdre 2 Corruptions disponibles",
	                                    "en": "Lose 2 available Corruptions"},
	"ui.decision.btn.fissure_own":     {"fr": "Fissurer mon Sceau sur %s",  "en": "Crack my own Seal on %s"},

	# Liturgy dialog inline labels
	"ui.liturgy.resolution_header":    {"fr": "Résolution :", "en": "Resolution:"},

	# Bottom bar — extra label keys for buttons re-rendered on locale change
	"ui.btn.zoom_out":                 {"fr": "−", "en": "−"},
	"ui.btn.zoom_in":                  {"fr": "+", "en": "+"},
	"ui.btn.zoom_reset":               {"fr": "⊙", "en": "⊙"},
	"ui.btn.zoom_out_label":           {"fr": "Dézoomer",     "en": "Zoom out"},
	"ui.btn.zoom_in_label":            {"fr": "Zoomer",       "en": "Zoom in"},
	"ui.btn.zoom_reset_label":         {"fr": "Recadrer",     "en": "Reset zoom"},
	"ui.fab.tooltip":                  {"fr": "Menu",         "en": "Menu"},
	"ui.fab.label":                    {"fr": "Menu",         "en": "Menu"},

	# DomainData yields (printed in domain tooltips/debug)
	"domain.yield.transgressed_2_3":   {"fr": "2 (3 si transgressé)",             "en": "2 (3 if Transgressed)"},
	"domain.yield.transgressed_1_2":   {"fr": "1 (2 si transgressé)",             "en": "1 (2 if Transgressed)"},
	"domain.yield.cracked_1_2":        {"fr": "1 (2 si Domaine fissuré ce tour)", "en": "1 (2 if Domain cracked this turn)"},

	# Glossary — surfaced via the FAB glossary item. One {name,def} pair
	# per term, kept short enough to scan in a single modal scroll.
	"glossary.domain.name":            {"fr": "Domaine",            "en": "Domain"},
	"glossary.domain.def":             {"fr": "Une des cinq sphères d'influence (Ambition, Désir, Foi, Peur, Volonté). Chaque Domaine accumule de la Corruption et peut être contrôlé, transgressé, scellé ou mis en Pénitence.",
	                                    "en": "One of the five spheres of influence (Ambition, Desire, Faith, Fear, Will). Each Domain accumulates Corruption and can be controlled, transgressed, sealed, or put in Penitence."},
	"glossary.emprise.name":           {"fr": "Emprise",            "en": "Grip"},
	"glossary.emprise.def":            {"fr": "La Corruption qu'un démon a posée dans un Domaine. Le démon avec la plus forte Emprise tient le Domaine ; un écart de 2 ou plus déclenche une Domination.",
	                                    "en": "The Corruption a demon has placed in a Domain. The demon with the most Grip holds the Domain ; a lead of 2 or more triggers a Domination."},
	"glossary.domination.name":        {"fr": "Domination",         "en": "Domination"},
	"glossary.domination.def":         {"fr": "État d'un Domaine où l'écart d'Emprise est ≥ 2. Le démon dominant verrouille certaines actions adverses tant qu'elle dure.",
	                                    "en": "Domain state where the Grip lead is ≥ 2. The dominating demon locks out certain opponent actions while it lasts."},
	"glossary.transgression.name":     {"fr": "Transgression",      "en": "Transgression"},
	"glossary.transgression.def":      {"fr": "Carte posée sur un Domaine pour appliquer son effet. Deux faces : Scandale (effet immédiat, peu coûteux) ou Infamie (effet plus fort, doit être Amplifiée).",
	                                    "en": "Card played on a Domain to apply its effect. Two faces : Scandal (cheaper, immediate) or Infamy (stronger, must be Amplified)."},
	"glossary.scandale.name":          {"fr": "Scandale",           "en": "Scandal"},
	"glossary.scandale.def":           {"fr": "Face initiale d'une Transgression — payée en Corruption disponible, marquée d'un cercle « S » sur le Domaine.",
	                                    "en": "Initial face of a Transgression — paid in available Corruption, marked with a circle « S » on the Domain."},
	"glossary.infamie.name":           {"fr": "Infamie",            "en": "Infamy"},
	"glossary.infamie.def":            {"fr": "Face Amplifiée d'une Transgression — coût supplémentaire, marquée d'un losange « I ». Compte pour la Profondeur de la Rupture.",
	                                    "en": "Amplified face of a Transgression — extra cost, marked with a diamond « I ». Counts towards the Depth of the Rupture."},
	"glossary.sceau.name":             {"fr": "Sceau",              "en": "Seal"},
	"glossary.sceau.def":              {"fr": "Verrou apposé par un démon sur un Domaine qu'il contrôle. Empêche l'autre démon de prendre le contrôle ou de transgresser ce Domaine. Représenté par un cadenas avec l'initiale du démon.",
	                                    "en": "Lock placed by a demon on a Domain it controls. Bars the other demon from taking control or transgressing it. Drawn as a padlock stamped with the demon's initial."},
	"glossary.penitence.name":         {"fr": "Pénitence",          "en": "Penitence"},
	"glossary.penitence.def":          {"fr": "État temporaire d'un Domaine après certaines Liturgies — le Domaine ne peut pas être scellé tant qu'il est en Pénitence.",
	                                    "en": "Temporary state of a Domain after certain Liturgies — the Domain cannot be Sealed while in Penitence."},
	"glossary.liturgie.name":          {"fr": "Liturgie",           "en": "Liturgy"},
	"glossary.liturgie.def":           {"fr": "Réponse de l'Église à la fin de chaque Station I-V. Cible un Domaine ou un démon selon une règle précise et applique un effet correctif.",
	                                    "en": "Response of the Church at the end of each Station I-V. Targets a Domain or a demon by a fixed rule and applies a corrective effect."},
	"glossary.in_integro.name":        {"fr": "In Integro",         "en": "In Integro"},
	"glossary.in_integro.def":         {"fr": "Face « pleine » d'une Liturgie : effet maximal. C'est la face par défaut, sauf si le démon a Entravé la Liturgie.",
	                                    "en": "« Full » face of a Liturgy : maximum effect. The default face unless the demon has Hindered the Liturgy."},
	"glossary.impedita.name":          {"fr": "Impedita",           "en": "Impedita"},
	"glossary.impedita.def":           {"fr": "Face « entravée » d'une Liturgie : effet réduit. Forcée par l'action Entraver (coûte de la Corruption) ou par l'Infamie Simonie sur Foi.",
	                                    "en": "« Hindered » face of a Liturgy : reduced effect. Forced by the Hinder action (costs Corruption) or by the Simony Infamy on Faith."},
	"glossary.rupture_ame.name":       {"fr": "Rupture de l'âme",   "en": "Soul Rupture"},
	"glossary.rupture_ame.def":        {"fr": "Condition de victoire des démons à l'Exorcisme final. Trois critères doivent être remplis : Profondeur (3+ Infamies, ou Foi/Volonté), Étendue (4+ Domaines transgressés), Ancrage (2+ Sceaux, ou Volonté scellée+transgressée).",
	                                    "en": "Demon victory condition at the final Exorcism. Three criteria must be met : Depth (3+ Infamies, or Faith/Will), Spread (4+ transgressed Domains), Anchor (2+ Seals, or Will sealed+transgressed)."},
	"glossary.fiat_tenebris.name":     {"fr": "Fiat Tenebris",      "en": "Fiat Tenebris"},
	"glossary.fiat_tenebris.def":      {"fr": "Victoire automatique : si la Volonté est scellée ET transgressée par le même démon au moment de l'Exorcisme, ce démon l'emporte.",
	                                    "en": "Automatic victory : if Will is sealed AND transgressed by the same demon at the Exorcism, that demon wins."},
	"glossary.ascendant.name":         {"fr": "Ascendant",          "en": "Ascendancy"},
	"glossary.ascendant.def":          {"fr": "Score signé qui suit la course entre les démons. Bonus à l'Exorcisme final selon Sceaux, Infamies dans Domaines contrôlés, Foi, et certaines Infamies spéciales (Pacte silencieux, Abdication intérieure).",
	                                    "en": "Signed score tracking the race between demons. Bonuses at the final Exorcism for Seals, Infamies in controlled Domains, Faith, and certain special Infamies (Silent Pact, Inner Abdication)."},
}
