# Hints d'avantages de domaine — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre lisibles sur le plateau les bénéfices d'investir dans chaque domaine, via des pastilles de rendement toujours visibles + un menu d'action refondu dont l'en-tête explique le « pourquoi investir ».

**Architecture:** Une source de vérité unique pour les textes (clés I18n + accesseurs `DomainData`). Une pastille custom-drawn par domaine, construite une fois (statique). Le menu natif `PopupMenu` est remplacé par un panneau `Control` parchemin (`DomainActionMenu`) qui se re-peuple à chaque ouverture et émet un signal routé vers la logique d'action existante. Aucune modification de `scripts/core/`.

**Tech Stack:** Godot 4.3 GDScript, autoloads `I18n` / `DomainData` / `TransgressionData`, classes `GameState` / `GameRules` / `GameEnums` / `Card`. Tests headless via `scripts/cli/run_tests.gd` (suite `RulesTestRunner`).

---

## Référence — Commande de test (Windows / Docker)

⚠️ La commande du CLAUDE.md échoue silencieusement sur cette machine (`$(pwd)` monte un volume vide). Utiliser **toujours** cette variante :

```bash
HOSTPWD=$(pwd -W) \
&& MSYS_NO_PATHCONV=1 docker run --rm -v "${HOSTPWD}:/project_src:ro" barichello/godot-ci:4.3 \
  bash -c "cp -r /project_src /tmp/proj && rm -rf /tmp/proj/.godot \
  && godot --headless --editor --path /tmp/proj --quit 2>/dev/null \
  && godot --headless --path /tmp/proj --script res://scripts/cli/run_tests.gd"
```

Succès = la sortie contient les lignes de tests + un résumé `=== N/N PASS, 0 FAIL ===`. Si on voit `Invalid project path`, le montage a échoué (vérifier `pwd -W`).

---

## Structure des fichiers

**Créés :**
- `scripts/ui/DomainHintChip.gd` — pastille de rendement custom-drawn (un nœud par domaine). Responsabilité unique : afficher le label compact + l'étoile de victoire.
- `scripts/ui/DomainActionMenu.gd` — panneau d'action refondu. Responsabilité unique : présenter l'en-tête + les actions d'un domaine et émettre le choix.

**Modifiés :**
- `scripts/data/I18n.gd` — nouvelles clés `domain.chip.*`, `domain.hint.*`, `ui.menu.*`.
- `scripts/data/DomainData.gd` — accesseurs `chip_label`, `advantage_text`, `is_victory_domain`.
- `scripts/core/RulesTestRunner.gd` — test `_test_domain_hint_strings`.
- `scripts/ui/Main.gd` — build des pastilles ; remplacement du câblage `_action_popup` par `DomainActionMenu` ; refresh des pastilles au changement de locale ; suppression du code mort du popup.

---

## Task 1 : Textes (I18n) + accesseurs DomainData

**Files:**
- Modify: `scripts/data/I18n.gd` (bloc `STRINGS`, après les clés `domain.volonte` ~ligne 54)
- Modify: `scripts/data/DomainData.gd`
- Modify: `scripts/core/RulesTestRunner.gd` (`run_all()` ~ligne 49 + nouvelle fonction)

- [ ] **Step 1 : Écrire le test qui échoue**

Dans `scripts/core/RulesTestRunner.gd`, ajouter la fonction de test (après `_test_production()` par exemple, n'importe où dans le fichier) :

```gdscript
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
		_assert(DomainData.chip_label(d) != "" and not DomainData.chip_label(d).begins_with("domain.chip."),
			"hint.chip_label.en[%d]" % d, "label EN manquant")
		_assert(DomainData.advantage_text(d) != "" and not DomainData.advantage_text(d).begins_with("domain.hint."),
			"hint.advantage_text.en[%d]" % d, "texte EN manquant")
	I18n.set_locale("fr")
```

Et l'enregistrer dans `run_all()`, juste après `_test_production()` (ligne 16) :

```gdscript
	_test_production()
	_test_domain_hint_strings()
```

- [ ] **Step 2 : Lancer les tests pour vérifier l'échec**

Run : commande Docker de référence ci-dessus.
Expected : FAIL sur `hint.chip_label[...]` / `hint.advantage_text[...]` (les fonctions `chip_label` / `advantage_text` n'existent pas encore → erreur de parse de `RulesTestRunner`, ou si elles compilent, retour de clé non traduite). Si erreur de parse, c'est attendu : passer au Step 3.

- [ ] **Step 3 : Ajouter les clés I18n**

Dans `scripts/data/I18n.gd`, après la ligne `"domain.volonte": ...` (~54), insérer :

```gdscript
	# Domain hint chips — compact yield labels shown on the board
	"domain.chip.ambition": {"fr": "2 Corr.",   "en": "2 Corr."},
	"domain.chip.desir":    {"fr": "2–3 Corr.", "en": "2–3 Corr."},
	"domain.chip.foi":      {"fr": "1–2 Corr.", "en": "1–2 Corr."},
	"domain.chip.peur":     {"fr": "1–2 Corr.", "en": "1–2 Corr."},
	"domain.chip.volonte":  {"fr": "Victoire",  "en": "Victory"},

	# Domain advantage lines ("why invest") — shown in the action menu header
	"domain.hint.ambition": {"fr": "Produit 2 Corruptions. Requis pour déclencher des Transgressions.",
		"en": "Produces 2 Corruptions. Required to trigger Transgressions."},
	"domain.hint.desir":    {"fr": "Produit 2 Corruptions (3 si transgressé). Active l'infamie « Appétit hérétique ».",
		"en": "Produces 2 Corruptions (3 if Transgressed). Enables the “Heretical Appetite” infamy."},
	"domain.hint.foi":      {"fr": "Produit 1 Corruption (2 si transgressé). Bonus d'Ascendant à l'Exorcisme.",
		"en": "Produces 1 Corruption (2 if Transgressed). Ascendant bonus at the Exorcism."},
	"domain.hint.peur":     {"fr": "Produit 1 Corruption (2 si un domaine a été fissuré ce tour).",
		"en": "Produces 1 Corruption (2 if a Domain was cracked this turn)."},
	"domain.hint.volonte":  {"fr": "Ne produit rien, mais scellé + transgressé = victoire automatique (Fiat Tenebris).",
		"en": "Produces nothing, but Sealed + Transgressed = automatic victory (Fiat Tenebris)."},

	# Action menu (custom DomainActionMenu)
	"ui.menu.meta":  {"fr": "Contrôle : %s — Transgressions : %d", "en": "Control: %s — Transgressions: %d"},
	"ui.menu.gain":  {"fr": "+%d Corr.", "en": "+%d Corr."},
	"ui.menu.provoke_section": {"fr": "Provoquer ici", "en": "Provoke here"},
	"ui.menu.amplify_section": {"fr": "Amplifier",     "en": "Amplify"},
```

- [ ] **Step 4 : Ajouter les accesseurs DomainData**

Dans `scripts/data/DomainData.gd`, à la fin du fichier, ajouter :

```gdscript
const _CHIP_KEYS := {
	GameEnums.DomainId.AMBITION: "domain.chip.ambition",
	GameEnums.DomainId.DESIR:    "domain.chip.desir",
	GameEnums.DomainId.FOI:      "domain.chip.foi",
	GameEnums.DomainId.PEUR:     "domain.chip.peur",
	GameEnums.DomainId.VOLONTE:  "domain.chip.volonte",
}
const _HINT_KEYS := {
	GameEnums.DomainId.AMBITION: "domain.hint.ambition",
	GameEnums.DomainId.DESIR:    "domain.hint.desir",
	GameEnums.DomainId.FOI:      "domain.hint.foi",
	GameEnums.DomainId.PEUR:     "domain.hint.peur",
	GameEnums.DomainId.VOLONTE:  "domain.hint.volonte",
}

# Compact yield label for the always-visible board chip (Volonté = "Victoire").
func chip_label(d: int) -> String:
	return I18n.t(String(_CHIP_KEYS.get(d, "")))

# One-line "why invest" advantage text for the action menu header.
func advantage_text(d: int) -> String:
	return I18n.t(String(_HINT_KEYS.get(d, "")))

# Volonté is the victory domain (Fiat Tenebris) — drives the violet accent
# and star glyph on its chip instead of a Corruption count.
func is_victory_domain(d: int) -> bool:
	return d == GameEnums.DomainId.VOLONTE
```

- [ ] **Step 5 : Lancer les tests pour vérifier le succès**

Run : commande Docker de référence.
Expected : `_test_domain_hint_strings` PASS (3×5 + 1 assertions), résumé `=== N/N PASS, 0 FAIL ===`.

- [ ] **Step 6 : Commit**

```bash
git add scripts/data/I18n.gd scripts/data/DomainData.gd scripts/core/RulesTestRunner.gd
git commit -m "Hints domaine : textes I18n + accesseurs DomainData"
```

---

## Task 2 : Pastille custom-drawn `DomainHintChip`

**Files:**
- Create: `scripts/ui/DomainHintChip.gd`

Pas de test unitaire (rendu visuel) : la validation est la compilation + le passage des tests existants. Le rendu réel est vérifié en Task 3.

- [ ] **Step 1 : Écrire la classe**

Créer `scripts/ui/DomainHintChip.gd` :

```gdscript
class_name DomainHintChip
extends Control
# Always-visible per-domain yield hint, drawn as a custom pill so it does not
# depend on web-font glyph coverage (same rationale as DomainBadges — the web
# build's bundled font misses some symbol glyphs on certain devices). Content
# is STATIC : set once at board build via set_domain(), never refreshed per
# frame. Re-call set_domain() on locale change to pick up FR/EN.

const PAD_X := 9.0
const PAD_Y := 3.0
const FONT_SIZE := 16
const GOLD := Color(0.79, 0.63, 0.29)      # producing domains
const VIOLET := Color(0.69, 0.42, 0.81)    # Volonté / victory
const INK := Color(0.10, 0.07, 0.03)       # text on the pill
const STAR_GAP := 5.0

var _label: String = ""
var _is_victory: bool = false
var _fill: Color = GOLD
var _style: StyleBoxFlat

func _init() -> void:
	# The chip never eats taps — the domain hotspot underneath must stay
	# tappable to open the action menu.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_domain(d: int) -> void:
	_label = DomainData.chip_label(d)
	_is_victory = DomainData.is_victory_domain(d)
	_fill = VIOLET if _is_victory else GOLD
	_style = StyleBoxFlat.new()
	_style.bg_color = _fill
	_style.set_corner_radius_all(int(FONT_SIZE * 0.6))
	_style.border_color = Color(0.04, 0.02, 0.01, 0.85)
	_style.set_border_width_all(1)
	_update_min_size()
	queue_redraw()

func _star_size() -> float:
	return float(FONT_SIZE) if _is_victory else 0.0

func _update_min_size() -> void:
	var f := ThemeDB.fallback_font
	var ts := f.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var star_w := (_star_size() + STAR_GAP) if _is_victory else 0.0
	custom_minimum_size = Vector2(ts.x + star_w + PAD_X * 2.0, FONT_SIZE + PAD_Y * 2.0)

func _draw() -> void:
	if _style == null:
		return
	var sz := size
	draw_style_box(_style, Rect2(Vector2.ZERO, sz))
	var f := ThemeDB.fallback_font
	var x := PAD_X
	var cy := sz.y * 0.5
	if _is_victory:
		_draw_star(Vector2(x + _star_size() * 0.5, cy), _star_size() * 0.5)
		x += _star_size() + STAR_GAP
	# Baseline approximation mirrors DomainBadges' draw_string usage.
	draw_string(f, Vector2(x, cy + FONT_SIZE * 0.35), _label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)

func _draw_star(c: Vector2, r: float) -> void:
	# Five-pointed star as a 10-vertex polygon (drawn, not a ★ glyph, to dodge
	# missing-glyph tofu on the web build).
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + float(i) * PI / 5.0
		var rad := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, INK)
```

- [ ] **Step 2 : Vérifier la compilation**

Run : commande Docker de référence (l'étape `--editor --quit` reconstruit le cache de `class_name`, donc `DomainHintChip` sera résolu).
Expected : pas d'erreur de parse ; résumé `=== N/N PASS, 0 FAIL ===` (mêmes compteurs qu'en Task 1).

- [ ] **Step 3 : Commit**

```bash
git add scripts/ui/DomainHintChip.gd
git commit -m "Hints domaine : pastille de rendement custom-drawn"
```

---

## Task 3 : Brancher les pastilles sur le plateau

**Files:**
- Modify: `scripts/ui/Main.gd` — déclaration d'un dict membre ; `_build_domain_name_labels()` (~1097) ; fonction de relocalisation (~3642).

- [ ] **Step 1 : Déclarer le dict membre**

Dans `scripts/ui/Main.gd`, près des autres dicts d'overlay de domaine (à côté de `_domain_name_labels` — chercher sa déclaration `var _domain_name_labels`), ajouter :

```gdscript
var _domain_hint_chips: Dictionary = {}
```

- [ ] **Step 2 : Créer une pastille par domaine**

Dans `_build_domain_name_labels()` (`scripts/ui/Main.gd` ~1097), à l'intérieur de la boucle `for d_id in DOMAIN_NAME_POS.keys():`, juste après la ligne `_domain_name_labels[d_id] = name_label` (~1126), ajouter :

```gdscript
		# Always-visible yield chip, centred in a thin anchored box just above
		# the name caption. CenterContainer keeps the chip at its intrinsic
		# (pixel) size instead of stretching it with the board.
		var chip_box := CenterContainer.new()
		chip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip_box.anchor_left = npos.x - nh.x
		chip_box.anchor_right = npos.x + nh.x
		chip_box.anchor_top = npos.y - nh.y - 0.055
		chip_box.anchor_bottom = npos.y - nh.y - 0.012
		chip_box.offset_left = 0
		chip_box.offset_right = 0
		chip_box.offset_top = 0
		chip_box.offset_bottom = 0
		var chip := DomainHintChip.new()
		chip.set_domain(d_id)
		chip_box.add_child(chip)
		_zoom_layer.add_child(chip_box)
		_domain_hint_chips[d_id] = chip
```

- [ ] **Step 3 : Rafraîchir les pastilles au changement de locale**

Dans la fonction de relocalisation (`scripts/ui/Main.gd` ~3642, celle qui boucle sur `_domain_name_labels`), juste après cette boucle (après le bloc qui met à jour `lbl.text`, ~ligne 3645), ajouter :

```gdscript
	# Chips carry FR/EN text → re-apply on locale toggle.
	for d_id in _domain_hint_chips.keys():
		var chip: DomainHintChip = _domain_hint_chips[d_id]
		if is_instance_valid(chip):
			chip.set_domain(d_id)
```

- [ ] **Step 4 : Vérifier la compilation + tests**

Run : commande Docker de référence.
Expected : pas d'erreur de parse ; résumé `=== N/N PASS, 0 FAIL ===`.

- [ ] **Step 5 : Vérification visuelle live**

Lancer le jeu (éditeur Godot ou déploiement) et confirmer :
- Une pastille au-dessus de chaque cartouche de nom de domaine.
- Ambition `2 Corr.`, Désir `2–3 Corr.`, Foi/Peur `1–2 Corr.` (or), Volonté `★ Victoire` (violet, étoile dessinée).
- Les pastilles ne bloquent pas le tap sur le domaine (le menu s'ouvre toujours).
- Les pastilles zooment/pannent avec le plateau.

- [ ] **Step 6 : Commit**

```bash
git add scripts/ui/Main.gd
git commit -m "Hints domaine : pastilles de rendement sur le plateau"
```

---

## Task 4 : Menu d'action refondu `DomainActionMenu`

**Files:**
- Create: `scripts/ui/DomainActionMenu.gd`

- [ ] **Step 1 : Écrire la classe**

Créer `scripts/ui/DomainActionMenu.gd` :

```gdscript
class_name DomainActionMenu
extends Control
# Custom replacement for the native PopupMenu opened on domain tap. A parchment
# panel : header (name + yield pill + "why invest" line + control/transgression
# meta), a 2x2 grid of the four base actions, and a list of dynamic
# Provoquer/Amplifier entries below.
#
# Stateless re-population : open_for() rebuilds the body on every open. Cheap —
# it's a tap-triggered modal, never refreshed per frame. Owns the action list
# and label keys that used to live in Main.gd.

signal action_chosen(payload: Dictionary)
# payload variants :
#   {"kind": Kind.BASE,    "action_id": int}                 # ActionId
#   {"kind": Kind.PROVOKE, "tid": String, "origin": int}
#   {"kind": Kind.AMPLIFY, "tid": String}

enum Kind { BASE, PROVOKE, AMPLIFY }

const ACTIONS := [
	GameEnums.ActionId.INVESTIR,
	GameEnums.ActionId.EXPLOITER,
	GameEnums.ActionId.SCELLER,
	GameEnums.ActionId.FISSURER,
]
const LABEL_KEYS := {
	GameEnums.ActionId.INVESTIR:  "action.investir",
	GameEnums.ActionId.EXPLOITER: "action.exploiter",
	GameEnums.ActionId.SCELLER:   "action.sceller",
	GameEnums.ActionId.FISSURER:  "action.fissurer",
}

const GOLD := Color(0.79, 0.63, 0.29)
const VIOLET := Color(0.69, 0.42, 0.81)
const TXT := Color(0.91, 0.84, 0.66)
const TXT_DIM := Color(0.60, 0.54, 0.42)
const GAIN := Color(0.62, 0.79, 0.54)
const REFUSE := Color(0.79, 0.54, 0.54)

var _panel: PanelContainer
var _content: VBoxContainer
var _pending_at: Vector2 = Vector2.ZERO

func _init() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # invisible/closed = pass-through
	visible = false

func _ready() -> void:
	# Scrim : full-rect input catcher so a tap outside the panel closes it.
	var scrim := Control.new()
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.custom_minimum_size = Vector2(320, 0)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 0)
	_panel.add_child(_content)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.05, 0.99)
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	return sb

func _on_scrim_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) \
			or (ev is InputEventScreenTouch and ev.pressed):
		close()

func close() -> void:
	visible = false

func open_for(d_id: int, state: GameState, player: int, at: Vector2) -> void:
	_rebuild(d_id, state, player)
	# Ensure we render on top of sibling Controls (board + HUD).
	if get_parent() != null:
		get_parent().move_child(self, -1)
	visible = true
	_pending_at = at
	# Wait one frame so the panel's container layout (and thus its size) is
	# resolved before we clamp it inside the viewport.
	await get_tree().process_frame
	_place_panel()

func _place_panel() -> void:
	var vp := get_viewport_rect().size
	var ps := _panel.size
	var p := _pending_at
	p.x = clampf(p.x, 8.0, maxf(8.0, vp.x - ps.x - 8.0))
	p.y = clampf(p.y, 8.0, maxf(8.0, vp.y - ps.y - 8.0))
	_panel.position = p

# ─── Build ────────────────────────────────────────────────────────────────

func _rebuild(d_id: int, state: GameState, player: int) -> void:
	for c in _content.get_children():
		c.queue_free()
	_content.add_child(_build_header(d_id, state))
	_content.add_child(_build_grid(d_id, state, player))
	var dyn := _build_dynamic(d_id, state, player)
	if dyn != null:
		_content.add_child(dyn)

func _margins(node: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(node)
	return m

func _build_header(d_id: int, state: GameState) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_lbl := Label.new()
	name_lbl.text = String(GameEnums.DOMAIN_NAMES.get(d_id, ""))
	name_lbl.add_theme_font_override("font", Card.FONT_TITLE)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	var pill := Label.new()
	pill.text = DomainData.chip_label(d_id)
	pill.add_theme_font_size_override("font_size", 14)
	pill.add_theme_color_override("font_color", Color(0.10, 0.07, 0.03))
	pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = VIOLET if DomainData.is_victory_domain(d_id) else GOLD
	psb.set_corner_radius_all(10)
	psb.set_content_margin(SIDE_LEFT, 9)
	psb.set_content_margin(SIDE_RIGHT, 9)
	psb.set_content_margin(SIDE_TOP, 2)
	psb.set_content_margin(SIDE_BOTTOM, 2)
	pill.add_theme_stylebox_override("normal", psb)
	row.add_child(pill)
	box.add_child(row)

	var adv := Label.new()
	adv.text = DomainData.advantage_text(d_id)
	adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv.add_theme_font_size_override("font_size", 14)
	adv.add_theme_color_override("font_color", Color(0.76, 0.69, 0.52))
	box.add_child(adv)

	var meta := Label.new()
	var ctrl: int = state.controller_of(d_id)
	var ctrl_txt: String = (GameEnums.player_name(ctrl)
		if ctrl != GameEnums.PlayerId.NONE else I18n.t("player.none"))
	var dom: GameState.DomainState = state.domain(d_id)
	var trans_n: int = dom.scandals.size() + dom.infamies.size()
	meta.text = I18n.t("ui.menu.meta", [ctrl_txt, trans_n])
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", TXT_DIM)
	box.add_child(meta)

	return _margins(box, 12, 11)

func _build_grid(d_id: int, state: GameState, player: int) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for aid in ACTIONS:
		var why: String = _why_cannot(aid, state, player, d_id)
		var enabled: bool = why == ""
		var sub: String = ""
		var sub_col: Color = GAIN
		if aid == GameEnums.ActionId.EXPLOITER and enabled:
			sub = I18n.t("ui.menu.gain", [GameRules.production_of(state, d_id, player)])
		elif not enabled:
			sub = why
			sub_col = REFUSE
		grid.add_child(_make_cell(I18n.t(String(LABEL_KEYS[aid])), sub, sub_col,
			enabled, _emit_base.bind(aid)))
	return _margins(grid, 10, 4)

func _build_dynamic(d_id: int, state: GameState, player: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var added := false

	# Provokable : any Transgression legally provocable with this domain as origin.
	var prov := VBoxContainer.new()
	prov.add_theme_constant_override("separation", 4)
	for tid in TransgressionData.ALL_IDS:
		if GameRules.why_cannot_provoquer(state, player, tid) != "":
			continue
		if d_id in GameRules.transgression_origin_options(player, tid):
			var lbl := I18n.t("ui.popup.provoke_in",
				[TransgressionData.name_of(tid), GameEnums.DOMAIN_NAMES[d_id]])
			prov.add_child(_make_cell(lbl, "", GAIN, true, _emit_provoke.bind(tid, d_id)))
			added = true
	if prov.get_child_count() > 0:
		box.add_child(_section_label("ui.menu.provoke_section"))
		box.add_child(prov)

	# Amplifiable : Scandales the player owns whose origin is this domain.
	var amp := VBoxContainer.new()
	amp.add_theme_constant_override("separation", 4)
	var dom: GameState.DomainState = state.domain(d_id)
	for ti in dom.scandals:
		if ti.owner != player:
			continue
		if GameRules.why_cannot_amplifier(state, player, ti.def_id) != "":
			continue
		var lbl := I18n.t("ui.popup.amplify_in",
			[TransgressionData.name_of(ti.def_id), GameEnums.DOMAIN_NAMES[d_id]])
		amp.add_child(_make_cell(lbl, "", GAIN, true, _emit_amplify.bind(ti.def_id)))
		added = true
	if amp.get_child_count() > 0:
		box.add_child(_section_label("ui.menu.amplify_section"))
		box.add_child(amp)

	if not added:
		return null
	return _margins(box, 10, 6)

func _section_label(key: String) -> Label:
	var l := Label.new()
	l.text = I18n.t(key)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", TXT_DIM)
	return l

func _make_cell(title: String, sub: String, sub_col: Color, enabled: bool,
		on_tap: Callable) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _cell_style(enabled))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", TXT if enabled else TXT_DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 12)
		s.add_theme_color_override("font_color", sub_col)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(s)
	pc.add_child(_margins(v, 10, 8))
	# Disabled cells swallow the tap (STOP, no handler) so poking them neither
	# acts nor closes the menu.
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	if enabled:
		pc.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and ev.pressed) \
					or (ev is InputEventScreenTouch and ev.pressed):
				on_tap.call())
	return pc

func _cell_style(enabled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.13, 0.08) if enabled else Color(0.13, 0.10, 0.07)
	sb.border_color = GOLD if enabled else Color(0.35, 0.29, 0.18, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb

func _why_cannot(aid: int, state: GameState, player: int, d_id: int) -> String:
	match aid:
		GameEnums.ActionId.INVESTIR:  return GameRules.why_cannot_investir(state, player, d_id)
		GameEnums.ActionId.EXPLOITER: return GameRules.why_cannot_exploiter(state, player, d_id)
		GameEnums.ActionId.SCELLER:   return GameRules.why_cannot_sceller(state, player, d_id)
		GameEnums.ActionId.FISSURER:  return GameRules.why_cannot_fissurer(state, player, d_id)
	return ""

func _emit_base(aid: int) -> void:
	close()
	action_chosen.emit({"kind": Kind.BASE, "action_id": aid})

func _emit_provoke(tid: String, origin: int) -> void:
	close()
	action_chosen.emit({"kind": Kind.PROVOKE, "tid": tid, "origin": origin})

func _emit_amplify(tid: String) -> void:
	close()
	action_chosen.emit({"kind": Kind.AMPLIFY, "tid": tid})
```

- [ ] **Step 2 : Vérifier la compilation**

Run : commande Docker de référence.
Expected : pas d'erreur de parse ; résumé `=== N/N PASS, 0 FAIL ===` (la classe n'est pas encore instanciée — on valide juste qu'elle compile et que le cache `class_name` la résout).

- [ ] **Step 3 : Commit**

```bash
git add scripts/ui/DomainActionMenu.gd
git commit -m "Hints domaine : panneau d'action refondu (DomainActionMenu)"
```

---

## Task 5 : Brancher `DomainActionMenu` dans Main, retirer le PopupMenu

**Files:**
- Modify: `scripts/ui/Main.gd` — déclaration (~112) ; création (~505) ; `_on_domain_clicked` (~1695) ; `_on_popup_action` (~1786) ; relocalisation (~3656).

- [ ] **Step 1 : Remplacer la déclaration du champ**

Dans `scripts/ui/Main.gd` ~ligne 112, remplacer :

```gdscript
var _action_popup: PopupMenu
```

par :

```gdscript
var _action_menu: DomainActionMenu
```

- [ ] **Step 2 : Remplacer la création du popup**

Dans `scripts/ui/Main.gd` ~505-509, remplacer le bloc :

```gdscript
	# Action popup
	_action_popup = PopupMenu.new()
	for aid in POPUP_ACTIONS:
		_action_popup.add_item(I18n.t(POPUP_LABEL_KEYS[aid]), aid)
	_action_popup.id_pressed.connect(_on_popup_action)
	add_child(_action_popup)
```

par :

```gdscript
	# Action menu (custom parchment panel, overlays the board + HUD)
	_action_menu = DomainActionMenu.new()
	_action_menu.action_chosen.connect(_on_menu_action)
	add_child(_action_menu)
```

- [ ] **Step 3 : Réécrire `_on_domain_clicked`**

Dans `scripts/ui/Main.gd`, remplacer tout le corps de `_on_domain_clicked` (de la ligne `func _on_domain_clicked(d_id: int) -> void:` ~1695 jusqu'à la fin de la fonction, avant `func _on_popup_action` ~1786) par :

```gdscript
func _on_domain_clicked(d_id: int) -> void:
	# Calibration mode swallows taps so a drag-to-move gesture doesn't also
	# fire the action menu (only the gui_input drag handler should react).
	if _debug_hotspots:
		return
	if state.game_over:
		return
	if state.has_pending_decisions():
		state.add_log(I18n.t("log.pending_decision_unhandled"))
		_refresh_log()
		return
	_selected_domain = d_id
	var at: Vector2 = get_viewport().get_mouse_position()
	_action_menu.open_for(d_id, state, state.active_player, at)
```

- [ ] **Step 4 : Remplacer `_on_popup_action` par `_on_menu_action`**

Dans `scripts/ui/Main.gd`, remplacer toute la fonction `_on_popup_action` (~1786-1809) par :

```gdscript
func _on_menu_action(payload: Dictionary) -> void:
	if _selected_domain < 0:
		return
	var result: Dictionary
	match int(payload.get("kind", -1)):
		DomainActionMenu.Kind.BASE:
			result = manager.perform_action(int(payload["action_id"]),
				{"domain": _selected_domain})
		DomainActionMenu.Kind.PROVOKE:
			result = manager.perform_action(GameEnums.ActionId.PROVOQUER,
				{"def_id": String(payload["tid"]), "origin": int(payload["origin"])})
		DomainActionMenu.Kind.AMPLIFY:
			result = manager.perform_action(GameEnums.ActionId.AMPLIFIER,
				{"def_id": String(payload["tid"])})
		_:
			_selected_domain = -1
			return
	_handle_action_result(result)
	_selected_domain = -1
	_refresh_all()
```

- [ ] **Step 5 : Retirer le bloc de relocalisation du popup**

Dans `scripts/ui/Main.gd` ~3655-3659, supprimer le bloc :

```gdscript
	# Action popup
	if _action_popup != null:
		for idx in POPUP_ACTIONS.size():
			var aid: int = POPUP_ACTIONS[idx]
			_action_popup.set_item_text(idx, I18n.t(POPUP_LABEL_KEYS[aid]))
```

(Le menu custom se re-peuple à chaque ouverture → il prend la locale courante automatiquement, aucune relocalisation nécessaire.)

- [ ] **Step 6 : Vérifier la compilation + tests**

Run : commande Docker de référence.
Expected : pas d'erreur de parse ; résumé `=== N/N PASS, 0 FAIL ===`.

- [ ] **Step 7 : Vérification visuelle live**

Lancer le jeu et confirmer :
- Tap sur un domaine → le panneau parchemin s'ouvre près du doigt, borné à l'écran.
- En-tête : nom + pastille de rendement + ligne d'avantage + ligne *Contrôle / Transgressions*.
- Grille 2×2 : Investir / Exploiter / Sceller / Fissurer ; Exploiter affiche `+N Corr.` ; actions illégales grisées avec la raison.
- Provoquer / Amplifier listés dessous quand disponibles.
- Tap sur une action → l'action s'exécute (même comportement qu'avant), le menu se ferme.
- Tap en dehors du panneau → ferme sans rien faire.
- Toggle FR/EN → la prochaine ouverture est dans la bonne langue.

- [ ] **Step 8 : Commit**

```bash
git add scripts/ui/Main.gd
git commit -m "Hints domaine : branche DomainActionMenu, retire le PopupMenu d'action"
```

---

## Task 6 : Nettoyage du code mort

**Files:**
- Modify: `scripts/ui/Main.gd` — constantes `POPUP_ACTIONS` / `POPUP_LABEL_KEYS` / `PROVOKE_ITEM_ID_BASE` / `AMPLIFY_ITEM_ID_BASE` (~203-221).

- [ ] **Step 1 : Vérifier qu'il ne reste aucune référence**

Run :
```bash
grep -n "POPUP_ACTIONS\|POPUP_LABEL_KEYS\|PROVOKE_ITEM_ID_BASE\|AMPLIFY_ITEM_ID_BASE\|_action_popup\|_on_popup_action" scripts/ui/Main.gd
```
Expected : aucune ligne. (Si une référence subsiste hors du `_fab_menu`, c'est un oubli des tasks précédentes — la corriger avant de supprimer les constantes.)

Note : `_fab_menu` reste une `PopupMenu` native (utilitaire) — ne pas toucher à sa création ni aux constantes de thème `PopupMenu` (`_apply_theme` ~318-320), qui le stylent encore.

- [ ] **Step 2 : Supprimer les constantes mortes**

Dans `scripts/ui/Main.gd`, supprimer le bloc `const POPUP_ACTIONS := [ ... ]`, `const POPUP_LABEL_KEYS := { ... }`, `const PROVOKE_ITEM_ID_BASE := 100` et `const AMPLIFY_ITEM_ID_BASE := 200` (~203-221), ainsi que leur commentaire de tête. (Ces définitions vivent désormais dans `DomainActionMenu`.)

- [ ] **Step 3 : Vérifier la compilation + tests**

Run : commande Docker de référence.
Expected : pas d'erreur de parse ; résumé `=== N/N PASS, 0 FAIL ===`.

- [ ] **Step 4 : Commit**

```bash
git add scripts/ui/Main.gd
git commit -m "Hints domaine : nettoie les constantes du PopupMenu retiré"
```

---

## Notes de suivi

- Ajouter une note d'avancement dans `tools/blog/bot-dev-notes.md` n'est **pas** requis ici (feature UI, pas dev bot).
- Pistes de polish hors scope (à proposer plus tard si désiré) : icônes dessinées dans la grille d'actions, animation d'ouverture/fermeture du panneau, réglage « masquer les hints ».
