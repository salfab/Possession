# Carte-action unique (Provoquer/Amplifier) — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (inline) ou subagent-driven-development. Étapes en cases `- [ ]`.

**Goal:** Faire de la carte plein écran le point d'action unique pour provoquer/amplifier une transgression, et supprimer les 4 chemins directs redondants.

**Architecture:** Réplique du bouton `Entraver` des liturgies : un bouton d'action contextuel sur la carte de transgression (état calculé à l'ouverture). Les lanceurs (menu domaine, panneau démon, catalogue) ne font qu'ouvrir la carte avec une origine. Les choix par-carte s'enchaînent via `_show_demon_choice` (déjà en place).

**Tech Stack:** Godot 4.3 GDScript. Tests logique : `RulesTestRunner` (CI). UI : pas de preview headless → vérif sur le live, par phase.

**Spec:** `docs/superpowers/specs/2026-06-19-card-driven-transgression-actions-design.md`

---

## File structure

- `scripts/ui/Main.gd` — bouton d'action sur la carte (`_fullscreen_card_action_btn` + `_update_fullscreen_action_button` + `_on_fullscreen_card_action_pressed`), champ `origin` dans `_fullscreen_card_binding`, signature `_show_fullscreen_transgression(tid, face, title, origin)`, reroutage des handlers de lanceurs, table de choix par-carte + nouveaux pickers.
- `scripts/ui/DomainActionMenu.gd` — entrées → ouvrent la carte (origine = domaine) ; retrait des cellules directes + bouton « Carte ».
- `scripts/core/ActionResolver.gd` — validation des cibles pour Intrigue/Mascarade/Dogme/Dénonciation/Panique/Renoncement.
- `scripts/core/RulesTestRunner.gd` — tests cible par-carte (phase 3).
- `scripts/data/I18n.gd` — libellés bouton action + titres/prompts des pickers.

---

## Phase 1 — Bouton d'action sur la carte

### Task 1.1 : bouton d'action contextuel + origine dans le binding

**Files:** Modify `scripts/ui/Main.gd` (zone carte plein écran ~4391‑4521), `scripts/data/I18n.gd`.

- [ ] **Step 1 — Déclarer le bouton** (près de `var _fullscreen_card_entraver_btn: Button` ~293) :
```gdscript
var _fullscreen_card_action_btn: Button   # Provoquer / Amplifier (transgression)
```

- [ ] **Step 2 — Créer le bouton** (après la création de `_fullscreen_card_entraver_btn`, ~4401) :
```gdscript
	_fullscreen_card_action_btn = Button.new()
	_fullscreen_card_action_btn.add_theme_font_size_override("font_size", 18)
	_fullscreen_card_action_btn.visible = false
	_fullscreen_card_action_btn.pressed.connect(_on_fullscreen_card_action_pressed)
	actions.add_child(_fullscreen_card_action_btn)
```

- [ ] **Step 3 — Origine dans le binding** : changer la signature
`_show_fullscreen_transgression(tid, face, title_str, origin: int = -1)` et stocker
`"origin": origin` dans `_fullscreen_card_binding`. Mettre à jour les appels
existants (preview demon panel = origin -1 ; menu/catalogue passeront le domaine en phase 2).

- [ ] **Step 4 — État du bouton** : dans `_update_fullscreen_flip_button`, brancher l'appel pour le cas `transgression` :
```gdscript
	if kind == "transgression":
		... (flip btn comme aujourd'hui) ...
		_fullscreen_card_entraver_btn.visible = false
		_update_fullscreen_action_button()
```
et ailleurs `_fullscreen_card_action_btn.visible = false`. Nouvelle fonction :
```gdscript
func _update_fullscreen_action_button() -> void:
	_fullscreen_card_action_btn.visible = false
	if state == null or state.game_over or manager == null:
		return
	if not manager.pending_liturgy.is_empty() or state.has_pending_decisions():
		return
	var tid: String = String(_fullscreen_card_binding.get("tid", ""))
	if tid == "":
		return
	var p: int = state.active_player
	# Amplifier si on possède ce Scandale et que c'est légal.
	if GameRules.can_amplifier(state, p, tid):
		_fullscreen_card_action_btn.text = I18n.t("ui.card.amplify")
		_fullscreen_card_action_btn.visible = true
		return
	# Sinon Provoquer si légal depuis l'origine connue.
	var origin: int = int(_fullscreen_card_binding.get("origin", -1))
	if origin >= 0 and GameRules.can_provoquer(state, p, tid) \
			and origin in GameRules.transgression_origin_options(state, p, tid):
		_fullscreen_card_action_btn.text = I18n.t("ui.card.provoke")
		_fullscreen_card_action_btn.visible = true
```

- [ ] **Step 5 — Handler** :
```gdscript
func _on_fullscreen_card_action_pressed() -> void:
	var tid: String = String(_fullscreen_card_binding.get("tid", ""))
	if tid == "":
		return
	var p: int = state.active_player
	_fullscreen_card_dialog.hide()
	if GameRules.can_amplifier(state, p, tid):
		var r := manager.perform_action(GameEnums.ActionId.AMPLIFIER, {"def_id": tid})
		_handle_action_result(r)
		_refresh_all()
		return
	var origin: int = int(_fullscreen_card_binding.get("origin", -1))
	_provoke_transgression(tid, origin)   # dispatch choix par-carte (Task 3.0)
```

- [ ] **Step 6 — i18n** (`scripts/data/I18n.gd`) :
```gdscript
	"ui.card.provoke": {"fr": "Provoquer ici", "en": "Provoke here"},
	"ui.card.amplify": {"fr": "Amplifier",    "en": "Amplify"},
```

- [ ] **Step 7 — Dispatch provoke générique** (Task 3.0, requis dès la phase 1) :
remplacer les routages spécifiques par un `_provoke_transgression(tid, origin)`
central qui aiguille Persécution/Simonie (déjà faits) et sinon provoque direct :
```gdscript
func _provoke_transgression(tid: String, origin: int) -> void:
	match tid:
		TransgressionData.T_PERSECUTION: _provoke_persecution(origin)
		TransgressionData.T_SIMONIE:     _provoke_simonie(origin)
		_:
			var r := manager.perform_action(GameEnums.ActionId.PROVOQUER, {"def_id": tid, "origin": origin})
			_handle_action_result(r)
			_refresh_all()
```

- [ ] **Step 8 — Commit + push + CI + vérif live** : ouvrir une carte transgression depuis le panneau démon (amplifiable) → bouton « Amplifier » présent et fonctionnel. (Provoquer testé en phase 2 quand le menu passe l'origine.)
```bash
git add scripts/ui/Main.gd scripts/data/I18n.gd
git commit -m "Carte transgression : bouton d'action Provoquer/Amplifier contextuel"
```

---

## Phase 2 — Reroutage des lanceurs

### Task 2.1 : menu domaine → ouvre la carte

**Files:** Modify `scripts/ui/DomainActionMenu.gd`, `scripts/ui/Main.gd`.

- [ ] **Step 1** — Dans `DomainActionMenu._build_dynamic`, remplacer chaque cellule
« Provoquer/Amplifier » (et le wrapper `_action_plus_preview`) par une cellule simple
qui émet un aperçu avec contexte d'action. Réutiliser `action_chosen` avec un
nouveau `Kind.PREVIEW` portant `{tid, origin}` (origin = `d_id`), pour provoke ;
pour amplify, `{tid, origin:-1}`. Supprimer le helper `_action_plus_preview`,
`_emit_preview`, le signal `card_preview_requested` (remplacés par l'aperçu-action).

- [ ] **Step 2** — Dans `Main._on_menu_action`, le cas PREVIEW :
```gdscript
		DomainActionMenu.Kind.PREVIEW:
			_show_fullscreen_transgression(String(payload["tid"]),
				GameEnums.TransgressionFace.SCANDALE, TransgressionData.name_of(String(payload["tid"])),
				int(payload.get("origin", -1)))
			_selected_domain = -1
			return
```
Retirer le handler `_on_domain_card_preview` et sa connexion (remplacés).

- [ ] **Step 3 — Commit + push + CI + vérif live** : taper une transgression dans le menu domaine → la carte s'ouvre avec « Provoquer ici » → provoque depuis la carte.
```bash
git add scripts/ui/DomainActionMenu.gd scripts/ui/Main.gd
git commit -m "Menu domaine : les entrées ouvrent la carte-action (retrait des cellules directes)"
```

### Task 2.2 : panneau démon → retrait du bouton inline Amplifier

- [ ] **Step 1** — Dans `_refresh_player_transgression_panels` / `_build_player_panel`, retirer le bouton inline « Amplifier » et la branche `can_amplifier`. Le tap sur la transgression ouvre déjà la carte (`_on_player_transgression_clicked`), qui montre maintenant « Amplifier ». Supprimer `_on_panel_amplifier_clicked` s'il n'est plus référencé.
- [ ] **Step 2 — Commit + push + vérif live**.

### Task 2.3 : catalogue → ouvre la carte

- [ ] **Step 1** — Dans `_build_trans_dialog`, les boutons provoquer/amplifier deviennent « ouvrir la carte » (origin -1 si pas de domaine ; le bouton Amplifier de la carte gère l'amplification). Supprimer `_on_provoquer_clicked` / `_on_amplifier_clicked` s'ils ne sont plus référencés. (Note : provoquer depuis le catalogue sans domaine n'est pas le chemin nominal — la carte ne montrera « Provoquer ici » que si une origine est connue ; sinon seul Amplifier/aperçu.)
- [ ] **Step 2 — Commit + push + vérif live**.

---

## Phase 3 — Pickers manquants + validation

Pour chaque carte ci-dessous : (a) picker obligatoire via `_show_demon_choice`
chaîné dans `_provoke_transgression` (match) ; (b) `ActionResolver._apply_scandal_effect`
valide la cible selon le texte ; (c) un test `RulesTestRunner`. Candidats ≤1 →
pas de dialog.

### Task 3.1 : Panique (target_domain = domaine contesté)

- [ ] **Step 1 — Test** (`RulesTestRunner`) :
```gdscript
func _test_panique_target() -> void:
	var s := _new_state()
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.RED, 2)
	s.set_corruption_in(GameEnums.DomainId.PEUR, GameEnums.PlayerId.PURPLE, 1)  # RED contrôle PEUR (requis) + contesté
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.RED, 1)
	s.set_corruption_in(GameEnums.DomainId.DESIR, GameEnums.PlayerId.PURPLE, 1)  # contesté
	s.available_corruption[GameEnums.PlayerId.RED] = 10
	var before := s.available_corruption[GameEnums.PlayerId.PURPLE]
	var r := ActionResolver.provoquer(s, GameEnums.PlayerId.RED, TransgressionData.T_PANIQUE, -1, {"target_domain": GameEnums.DomainId.DESIR})
	_assert(r.get("ok", false), "Panique : provocation OK")
	# (effet : selon le code actuel, l'adversaire perd 1 du pool ; on vérifie au minimum que la cible n'invalide pas)
	_assert(s.available_corruption[GameEnums.PlayerId.PURPLE] == before - 1, "Panique : effet appliqué")
```
- [ ] **Step 2** — Picker dans `_provoke_transgression` :
```gdscript
		TransgressionData.T_PANIQUE:
			_provoke_with_domain_choice(tid, origin, _contested_domains())
```
avec helpers (Task 3.7).
- [ ] **Step 3** — Vérifier/ajuster la validation `_apply_scandal_effect` T_PANIQUE.
- [ ] **Step 4 — Commit**.

### Task 3.2–3.6 : Intrigue, Mascarade, Dogme, Dénonciation, Renoncement

Même structure (test + picker + validation + commit). Candidats par carte :
- **Intrigue** : `target_domain` = domaines que le joueur contrôle SANS Domination nette et non scellés (valider dans `_apply_scandal_effect`, qui aujourd'hui ne valide pas).
- **Mascarade** : `from_domain` (≥1 au joueur) + `to_domain` (non scellé par l'adversaire) → deux pickers enchaînés.
- **Dogme** : `target_station` = courante / suivante (réutiliser le helper Simonie de station).
- **Dénonciation** : `target_domain` = contrôlé par l'adversaire où le joueur a ≥1.
- **Renoncement** : `target_domain` = où l'adversaire a ≥1.

### Task 3.7 : helpers de choix génériques + i18n

- [ ] Helpers : `_provoke_with_domain_choice(tid, origin, candidates: Array)` et
`_provoke_with_station_choice(tid, origin, candidates)` qui construisent les options
{label, value} et appellent `_show_demon_choice(...)` → `perform_action(PROVOQUER, {def_id, origin, target_domain/target_station})`. Et `_contested_domains()`, `_opp_domains_with_corruption()`, etc.
- [ ] i18n : `ui.dialog.title.<card>_pick` + prompt par carte (réutiliser génériques si possible).
- [ ] Commit final.

---

## Self-review

- **Couverture spec** : bouton carte (Task 1.1) ✓ ; reroutage menu/panneau/catalogue (2.1‑2.3) ✓ ; choix par-carte + 6 pickers (3.1‑3.7) ✓ ; origine = domaine tapé (Task 1.1 step 3 + 2.1) ✓ ; cas limites (1.1 step 4 : game_over/pending) ✓.
- **Placeholders** : Task 3.2‑3.6 référencent la structure de 3.1 explicitement (candidats listés) ; le code complet de chaque sera écrit à l'exécution depuis la table — acceptable car structure identique et candidats précisés.
- **Cohérence types** : `_show_fullscreen_transgression(tid, face, title, origin)`, `_provoke_transgression(tid, origin)`, `_fullscreen_card_binding["origin"]` cohérents partout.
