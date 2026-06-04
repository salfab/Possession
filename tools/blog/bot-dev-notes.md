# Notes — article "Donner un cerveau aux démons"

## Ton voulu
Nonchalant, marrant, pas prise de tête, humble — mais qui assume ses accomplissements
funky sans fausse modestie. Le narrateur ne se prend pas au sérieux mais ce qu'il
fait est quand même bien cool. Penser : "tiens, j'ai fait un truc sympa, laisse-moi
te raconter" plutôt que "voici ma thèse de doctorat sur les algorithmes de recherche
arborescente".

Fil conducteur personnel à tisser dans l'article :
- École d'ingénieur → quelques algos d'IA vus en cours, il y a longtemps
- Seul souvenir solide : **MiniMax** (et pourquoi il ne passe pas à l'échelle)
- Monte Carlo vu dans un contexte inattendu : **estimation de user stories en Scrum**
  (avec une Scrum Master formidable à la Vaudoise — Monte Carlo pour remplacer les
  story points, l'idée que l'incertitude se *simule* plutôt que s'estime)
- Réseau de neurones : le grand mystère à élucider… peut-être dans un second article

---

## Moment 1 — Pourquoi pas MiniMax ?

Possession : ~30 coups légaux par pulsation, 46 demi-coups de profondeur totale.
MiniMax profondeur 4 = 30⁴ ≈ 800 000 nœuds. Même avec alpha-bêta, trop lent sur
mobile. Le jeu est trop buissonnant pour une recherche exhaustive.

**Angle article** : "J'ai sorti MiniMax de ma mémoire d'ingénieur — et j'ai réalisé
pourquoi il ne fonctionnerait pas ici."

---

## Moment 2 — Monte Carlo, ou comment jouer 500 parties dans sa tête

MCTS ne calcule pas tout : il *sample* des trajectoires aléatoires/heuristiques,
accumule des stats win/loss, et concentre les itérations sur les branches prometteuses
(formule UCT). Budget-time plutôt que profondeur fixe → "anytime", parfait mobile.

Connexion Scrum : dans les deux cas, on remplace une *estimation ponctuelle fragile*
par une *distribution de résultats simulés*. L'incertitude n'est plus niée, elle est
modélisée.

**Angle article** : le moment "ah mais c'est exactement la même idée que ce qu'on
faisait avec les user stories !"

---

## Moment 3 — L'architecture en couches

```
ActionEnumerator   → liste les coups légaux (20-50 par pulsation)
Eval               → score [-1, +1] d'un état (heuristique 5 composantes)
HeuristicBot       → greedy 1-ply : clone + évalue chaque coup, prend le meilleur
RandomBot          → sample uniforme (sert de plancher de test)
MCTSBot            → le vrai cerveau (à venir)
```

Chaque couche est testable indépendamment. `ActionEnumerator` seul permet déjà
de vérifier que les règles sont correctement encodées.

---

## Moment 4 — Tester sans UI

Godot 4 en mode `--headless` : le moteur charge le projet (autoloads, règles)
sans ouvrir de fenêtre. `BotTestRunner.run_all()` joue 100 parties
RandomBot vs RandomBot en pur GDScript — environ 30 secondes via Docker.

**Angle article** : "On n'a pas besoin d'une interface pour savoir si un bot joue
bien. On a besoin de statistiques."

---

## À compléter

- [x] 100 parties RandomBot vs RandomBot : toutes terminent (0 erreur)
- [x] Premier benchmark HeuristicBot vs RandomBot : HeuristicBot 10 %, RandomBot 0 %, Église 90 %
  - HeuristicBot gagne 100 % des matchups où un démon l'emporte
  - L'Église gagne 90 % des parties — normal : la Rupture est exigeante et le 1-ply ne planifie pas
  - Correction clé : `GameState.to_dict()` stockait les Dictionnaires par référence → le clone
    partageait `available_corruption` avec l'original → toutes les évaluations corrompaient l'état réel
  - Eval redesignée : composante Rupture explicite + infamies > scandales → AMPLIFIER vaut la peine
- [x] Tuning MCTS — trois leviers combinés :
  - `ROLLOUT_STATIONS 3→1` : après avoir joué un coup, on simule 1 tour de jeu aléatoire
    avant de poser un jugement (au lieu de 3). Pas parce que voir moins loin c'est mieux,
    mais parce que chaque simulation coûte du temps — avec 1 tour on en fait 2× plus dans
    le même budget : 34 → 71 itérations/200 ms.
  - **Eval-prior** : avant de lancer les simulations, on donne à chaque coup une "première
    impression" basée sur l'évaluation statique du plateau (1 visite virtuelle gratuite).
    Ça évite de gaspiller des essais sur des coups manifestement mauvais.
  - `C_UCT √2→0.7` : ce paramètre règle l'équilibre exploration/exploitation. Avec beaucoup
    de temps on explore large ; avec seulement 70 simulations, mieux vaut se concentrer sur
    ce qu'on a déjà appris. √2 ≈ 1.41 est la valeur "théorique infini" — 0.7 est calibré
    pour un budget serré.
- [x] Benchmark MCTSBot(R) vs HeuristicBot(B) sur 30 parties : Rouge 33% / Violet 13% / Église 53%
  - Baseline HeuristicBot vs Random : Rouge 4% / Violet 0% / Église 96%
  - L'Église perd sa domination : 96% → 53% quand MCTSBot joue
  - MCTSBot gagne 33% des parties contre un HeuristicBot — 8× plus que le greedy seul
- [x] 71 itérations MCTS en 200 ms sur Linux Docker (iPad probablement similaire sur M-series)
- [x] Impact du budget sur le taux de victoire :
  - 200 ms → ~30% victoires MCTSBot vs HeuristicBot
  - 2 000 ms → ~60% victoires (10× budget, 2× résultat — rendements décroissants)
  - Conclusion : 500 ms serait un bon compromis mobile (confort + performance)
- [ ] Mesurer les itérations réelles sur iPad (M-series vs Docker Linux x86)
- [ ] Anecdote : un truc que le bot a "découvert" qu'on n'avait pas anticipé
- [x] Codex des Transgressions — variante optionnelle (10 nouvelles cartes, 20 au total)
  - Architecture : `CodexSetup.setup(state, rng)` choisit 2 cartes par Domaine (5×4→5×2)
  - Chaque carte Codex accroche un ou deux systèmes du moteur sans toucher V1h :
    - Intrigue (11) : `can_sceller` bypass net-domination pour le Domaine d'origine
    - Bulle (12) : `acknowledge_liturgy` → +1 Corr. si non entravée
    - Mascarade (13) : `_begin_station` → redistribution automatique au début de chaque Station
    - Appétit (14) : `can_provoquer` → présence suffit (pas besoin de contrôle)
    - Dogme (15) : scandale place une Entrave gratuite ; infamy → +1 Corr. après chaque liturgie
    - Reliques (16) : `_contrition` + `apply_confession_pick` → Pénitence bloquée sur l'origine
    - Dénonciation (17) : `can_exploiter` → blocage Domaine par scandale (station) ou infamy (permanent)
    - Panique (18) : `production_of` → -1 production adversaire sur Domaine contesté
    - Obéissance (19) : `_pick_initiative` → override d'initiative ; scandale = station courante, infamy = permanent
    - Renoncement (20) : `entraver` → propriétaire gagne +1 Corr. à chaque Entrave adverse
  - 163 tests Rules + 12 nouveaux tests codex = 175/175 PASS (à vérifier après CI)
  - Benchmark Monte Carlo : V1h baseline vs N configurations codex aléatoires

## Péripétie technique (bon matériel pour l'article)

L'infra de test headless Godot est un labyrinthe : `preload()` au niveau
const dans un autoload → pas de chargeur image en mode headless → erreur
de compilation en cascade qui empêche TOUS les singletons de s'enregistrer
→ les tests ne tournent pas du tout, et CI "passait" en silence (faux positif
via tee qui avale le code de sortie de Godot). Fix : CardImages charge ses
textures paresseusement dans `_ready()`, guard `DisplayServer.get_name()`.
Bonus bug : drain auto des décisions de confession avait une boucle infinie
si le premier domaine contrôlé était déjà en pénitence. 135/135 maintenant.

---

## Idée de structure article 1 — "Donner un cerveau aux démons"

1. Le jeu et le défi ("les règles sont solides, reste à donner un cerveau aux démons")
2. MiniMax : pourquoi c'est insuffisant ici
3. La connexion Scrum / Monte Carlo (le moment de reconnaissance)
4. Comment MCTS fonctionne — les 4 étapes
5. L'architecture technique (sans noyer le lecteur)
6. Les résultats : est-ce que ça joue bien ?
7. Ce qu'on n'a pas fait (NN) — et pourquoi c'est OK pour l'instant
   (Note : faisable — soit via ONNX + GDExtension, soit poids JSON + forward pass GDScript pur ;
    mais MCTS suffit pour ce jeu et le NN serait un article entier à lui seul)

---

## Idée de structure article 2 — "Laisser les démons tester le jeu"

Thématique : le bot comme outil de design, pas seulement comme adversaire.

Angle : on veut ajouter des "modificateurs de liturgie" pour la rejouabilité
(tirés au setup, pas d'aléatoire en cours de partie — puzzle stratégique différent
à chaque partie). Comment savoir si un modificateur est équilibré ?
→ On fait jouer MCTSBot vs MCTSBot 100 parties avec le modificateur actif
→ On vérifie symétrie Rouge/Violet et plage Église raisonnable (30-70%)
→ Anecdote potentielle : un modificateur "anodin" que le bot a cassé en 50 parties

Fil conducteur : les studios AAA font ça avec des milliers de bots.
Ici on le fait en ~4 minutes de Docker sur un jeu indie solo.
Le bot qu'on a construit pour jouer devient un outil de QA gratuit.

---

## Étape — Sortir le bot du headless : le faire jouer DANS l'UI Godot

Jusqu'ici le bot ne vivait qu'en tests headless (`BotTestRunner`), piloté par
`TurnManager._check_bot_turn()` : une boucle `while` **synchrone** qui résout tout
le tour du bot d'un coup. Parfait pour benchmarker 100 parties en 4 min, inutilisable
pour *regarder* l'IA jouer — l'écran ne se rafraîchit jamais entre deux coups.

Le déclic : pour jouer contre l'IA depuis l'interface, il fallait d'abord un
**mécanisme de cadencement**. Et ce cadencement, c'est exactement ce qui rend les
animations utiles. Les deux features (anims + IA jouable) ne sont pas deux chantiers :
c'est le même.

Refactor minimal du core (une seule source de vérité pour la logique bot) :
- `TurnManager.auto_bot` (défaut `true`) — l'UI le passe à `false`.
- `step_bot_once()` — applique **un seul** coup bot (une décision drainée OU une action
  choisie) et retourne `true` s'il a agi. La boucle headless devient
  `while step_bot_once(): pass`, donc comportement identique en test.
- `bot_should_act()` — prédicat sans effet de bord : « le moteur attend-il un coup bot ? »
- `last_action` / `last_kwargs` / `last_action_player` — estampillés par `perform_action()`,
  pour qu'un dispatcher d'anim rejoue le coup, **humain ou bot, même chemin**.

Côté UI (`Main.gd`) :
- Dialogue de nouvelle partie : Humain / IA par camp (Rouge / Violet).
- `MCTSBot` câblé dans `state.bot_for_player` selon le choix.
- Un `Timer` one-shot joue un coup IA toutes les ~600 ms, refresh + anim entre chaque,
  ré-armé automatiquement en queue de `_refresh_all()` via `_maybe_resume_ai()`.
- Toast nominatif sur les coups de l'IA (« Violet — Investir ») : exception assumée à
  la règle « pas de toast sur succès » — il faut bien voir ce que l'adversaire fait.
- Config Humain/IA persistée dans la sauvegarde (format `{state, players}`, lecture
  rétro-compatible avec les vieilles sauvegardes bare-state).

Prochain jalon : une signature visuelle dédiée par type d'action (pose corruption,
entraver, provoquer, amplifier, puiser…) — le hook `_animate_action_feedback()` est
déjà le point d'accroche.

---

## Étape — Animations par type d'action (rendre les coups lisibles)

Phase 2 du même chantier : maintenant que l'IA joue dans l'UI avec un cadencement,
chaque coup mérite une signature visuelle — sinon on voit le plateau changer sans
savoir CE QUI s'est passé. Surtout en IA vs IA où ça défile.

`ActionEffect.gd` : un petit Control transitoire (plein-board dans le ZoomLayer, comme
les arches), qui se dessine en `_draw()` selon un `kind` et s'auto-détruit après ~0.55 s
(une tween anime `progress` 0→1). Une signature par action :
- Investir → corruption qui éclot (anneaux + points radiants) ;
- Exploiter → anneau qui converge vers l'intérieur ;
- Sceller → arc doré qui se referme en anneau plein ;
- Fissurer → éclats qui rayonnent ;
- Provoquer → salve de pointes ;
- Amplifier → deux anneaux d'écho déphasés ;
- Entraver → barre horizontale qui barre la bannière de Station ;
- Puiser → volutes sombres qui montent.

Point clé d'archi : tout passe par le MÊME hook `_animate_action_feedback()` branché en
queue de `_refresh_all()`, qui lit `manager.last_action`. Donc un coup humain et un coup
bot déclenchent exactement la même animation — zéro code spécifique au bot dans l'UI.
C'est le payoff du `last_action` posé en Phase 1.
