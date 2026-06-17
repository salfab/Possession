# CLAUDE.md — Possession

Instructions pour Claude Code sur ce projet. Valables sur toute machine, toute session.

---

## Projet en bref

Jeu de plateau 2 joueurs hotseat en Godot 4.3 GDScript. Deux démons (Rouge / Violet)
corrompent un pape à travers 6 Stations liturgiques. Déployé en PWA sur GitHub Pages
via CI GitHub Actions.

**Stack** : Godot 4.3 stable, no-threads variant (iOS Safari), GDScript pur, Web export,
service worker offline, I18n FR/EN (FR primary).

**Cible principale** : iPad / touchscreen. Tout ce qui casse le tap input est un bug
bloquant.

---

## Workflow git

- Travailler **directement sur `main`** — pas de feature branch, pas de PR ritual.
- Après chaque `git push`, **annoncer explicitement le SHA** poussé dans la réponse
  (format : `Pushé \`abc1234\`.`) — le user vérifie le deploy live avec ce hash.
- CI push → main : test GDScript + build Web + deploy GitHub Pages (~3-5 min).

---

## Lancer les tests

```bash
# Via Docker (Godot non installé localement) :
docker run --rm -v "$(pwd):/project_src:ro" barichello/godot-ci:4.3 \
  bash -c "cp -r /project_src /tmp/proj && rm -rf /tmp/proj/.godot \
  && godot --headless --editor --path /tmp/proj --quit 2>/dev/null \
  && godot --headless --path /tmp/proj --script res://scripts/cli/run_tests.gd \
  && godot --headless --path /tmp/proj --script res://scripts/cli/run_ui_tests.gd"
```

Deux suites : `run_tests.gd` (logique : rules engine + bot, pur `RefCounted`) et
`run_ui_tests.gd` (régression UI : instancie `Main` headless et vérifie les
invariants d'input des bannières liturgiques — panel `STOP`, `gui_input`
connecté, enfants `IGNORE`, panel non recouvert). Le CI lance les deux.

Le `--editor --quit` reconstruit le cache de class_name avant les tests.
Sans ça, les identifiants GDScript ne sont pas résolus en mode `--script`.

---

## Systèmes externes

- **Repo** : github.com/salfab/Possession (`main` = branche unique)
- **Live** : https://salfab.github.io/possession/
- **CI** : `.github/workflows/ci.yml` (`barichello/godot-ci:4.3`)
- **Reset SW** : bouton "Reset SW" dans le bandeau version en haut de page
- **Calibration** : `tools/banner_calibrate.py` (PIL/numpy), relancer après chaque
  swap d'artwork de bannière

---

## Pièges techniques à ne pas reproduire

### `emulate_mouse_from_touch` doit rester `false`
Dans `project.godot` : `[input_devices] pointing/emulate_mouse_from_touch=false`.
Ne pas ré-activer. Quand c'est `true`, chaque tap génère un ScreenTouch ET un
MouseButton synthétisé → double-fire dans tous les handlers. Commit `a50fc73`.

### `Window.content_scale_factor` en mode DISABLED = zoom visuel, pas HiDPI
Avec `content_scale_mode = DISABLED` (défaut), setter `content_scale_factor = 1.7`
agrandit les Labels et boutons de 1.7× → ils dépassent les bounds du dialog.
Ce n'est PAS un réglage HiDPI. Commits `28ae87d` révertés par `548ec3d`.

### `Card._configure_card_fonts()` doit tourner avant tout Label qui use ces fonts
`Card.FONT_TITLE / FONT_BODY / FONT_FACE` nécessitent une config runtime (MSDF +
fallbacks + clear_cache). Appeler `Card._configure_card_fonts()` au tout début de
`Main._ready()`, avant `_apply_theme()` et `_build_overlays()`. Commit `de4f67e`.

---

## Décisions de design à ne pas défaire

### Modales empilées sur la fullscreen card — intentionnel
`_targeting_dialog` et `_effect_detail_dialog` s'affichent PAR-DESSUS la card
fullscreen exprès (lisibilité texte + image visible derrière). Ne pas ajouter de
code qui ferme la card quand ces popups ouvrent.

### Pas de toast sur action acceptée (sauf exception)
`_handle_action_result` est silencieux sur succès par défaut — les changements du
board suffisent comme feedback. Toast ambre sur refus seulement. Ne pas ajouter de
toast "Action effectuée" générique. Commit `801e16d`.

### Principes visuels
- Accents **muted** (alpha 0.4-0.6), jamais saturés sauf emphasis forte.
- Dos de carte = vrai aspect carte (AspectRatioContainer 720/1008, parchemin, flip tween).
- Accessibilité = couleur **ET** indice non-couleur (lettre, glyphe, forme).

---

## Dev bot (MCTS)

Fichiers dans `scripts/bot/`. Contraintes absolues :
- **Ne pas toucher `scripts/core/` ni `scripts/data/`** sauf ajouts minimes documentés.
- GDScript pur, pas de threads, pas d'await, pas de réseau.
- Décision en < 500 ms sur iPad (cible 200 ms).

Architecture :
```
ActionEnumerator  → liste les coups légaux
Eval              → score [-1, +1] heuristique
HeuristicBot      → greedy 1-ply (baseline + rollout policy MCTS)
RandomBot         → plancher de test
MCTSBot           → cerveau principal (UCT, budget-time)
BotTestRunner     → tests + parties bot vs bot
```

**À chaque étape intéressante du dev bot, ajouter une note dans
`tools/blog/bot-dev-notes.md`** — sert de matière pour un article de blog.
