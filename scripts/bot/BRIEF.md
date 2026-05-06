# Possession — Bot MCTS, brief de démarrage

Document à utiliser comme **premier message** d'une conversation Claude
Code neuve, dédiée au développement d'un bot pour le jeu Possession V1h.
Le code du jeu (règles, état, manager, UI) est déjà en place et stable
sur `main` ; il ne faut **pas** le toucher.

---

## 1. Contexte

Possession est un jeu de plateau de stratégie 2 joueurs en hot-seat,
développé en Godot 4 (GDScript) et déployé en PWA sur GitHub Pages.
Univers : deux démons (Rouge / Violet) corrompent un pape à travers
six Stations liturgiques. Détails : `print/README.md` et la version
courante des règles est figée par les commits **V1h** (cf. tag /
historique git récent).

Le jeu est **déterministe**, **à information parfaite**, **2 joueurs à
somme nulle** (la victoire d'un démon est la défaite de l'autre) avec
des Pulses dans chaque Station — un moteur de jeu MCTS-friendly.

## 2. Objectif

Implémenter un bot capable de jouer pour un démon (ou les deux), avec
une qualité de jeu raisonnable et un temps de décision compatible avec
mobile. Algorithme cible : **MCTS** (Monte-Carlo Tree Search avec UCT).

Mode hot-seat reste intact. Le bot est activé via une nouvelle
configuration `state.bot_for_player[player_id] = bot_instance` qui, si
présente, remplace l'attente d'input UI par un appel
`bot.pick_action(state)`.

## 3. Contraintes non-négociables

- **Godot 4.3 + GDScript pur**. Pas de GDExtension, pas de C#, pas de
  threads (l'export web no-thread iOS Safari est la cible).
- **Pas de toucher à `scripts/core/`** ni à `scripts/data/`. Le bot
  consomme ces APIs en lecture, sans les modifier. Si un signal /
  helper manque, on ajoute un getter pur dans une nouvelle classe
  `BotInterface` ; on n'altère pas l'existant.
- **Décision en moins de 500 ms** sur iPad récent (cible 200 ms ; un
  budget temps configurable, MCTS étant anytime).
- **Aucune dépendance réseau**. L'IA tourne 100 % côté client.
- **Aucun changement à la logique de jeu** : si le bot perd parce qu'il
  joue mal, on l'améliore ; on ne change pas les règles pour le faire
  gagner.

## 4. Reading list (tout est dans `scripts/`)

Avant d'écrire une seule ligne, lis dans cet ordre :

1. `scripts/core/GameEnums.gd` — enums centraux (DomainId, StationId,
   PlayerId, ActionId, STATION_PULSES, STARTING_CORRUPTION).
2. `scripts/core/GameState.gd` — structure d'état complète + sérialisation
   (`to_dict` / `from_dict`, **clé pour le clonage MCTS**).
3. `scripts/core/GameRules.gd` — fonctions de légalité (`can_*`),
   `linked_domains_for_response`, `entrave_payment_options`,
   `production_of`. Aucune mutation ici, parfait pour le bot.
4. `scripts/core/ActionResolver.gd` — toutes les mutations d'état
   (`investir`, `exploiter`, `provoquer`, `amplifier`, `sceller`,
   `fissurer`, `entraver(...payment_domain)`, `passer`, `puiser`).
5. `scripts/core/TurnManager.gd` — boucle Pulse / Station / fin de
   partie. Inclut `perform_action(action_id, kwargs)` qui est l'API
   que le bot doit invoquer.
6. `scripts/core/LiturgyResolver.gd` — résolution de fin de Station
   (Liturgie, sceaux fissurés, pénitences, etc.).
7. `scripts/core/EndGameResolver.gd` — Soul Rupture, Fiat Tenebris,
   Ascendant final, tie-breaks.
8. `scripts/data/TransgressionData.gd` + `scripts/data/LiturgicalResponseData.gd`
   — catalogues lus par les helpers ci-dessus.
9. `scripts/core/RulesTestRunner.gd` — modèle pour les tests à écrire.

Ne lis PAS `scripts/ui/` — sauf si tu veux comprendre comment
`TurnManager.perform_action` est consommé (Main.gd, autour de
`_on_btn_pressed_*`). Pour le bot, l'UI est invisible.

## 5. Architecture cible

```
scripts/bot/
├── BRIEF.md              ← ce document
├── BotBase.gd            ← interface abstraite
├── ActionEnumerator.gd   ← liste les actions légales pour un état + un joueur
├── Eval.gd               ← fonction d'évaluation statique (heuristique)
├── HeuristicBot.gd       ← baseline rapide, sert de rollout policy MCTS
├── MCTSBot.gd            ← le vrai cerveau
└── tests/
    └── BotTestRunner.gd  ← tests unitaires + parties bot vs bot pour benchmark
```

**`BotBase.gd`** :

```gdscript
class_name BotBase
extends RefCounted

# Returns {action_id: GameEnums.ActionId, kwargs: Dictionary}.
# Pure function : doesn't mutate state, doesn't call perform_action.
# The caller (TurnManager) does the perform.
func pick_action(state: GameState, player: int) -> Dictionary:
    push_error("BotBase.pick_action must be overridden")
    return {}
```

**`ActionEnumerator.gd`** : pour chaque type d'action, génère la liste
exhaustive des `(ActionId, kwargs)` légaux pour `(state, player)` :
- `INVESTIR` × 5 Domaines (filtre par `can_investir`)
- `EXPLOITER` × 5 Domaines
- `PROVOQUER` × 10 Transgressions × choix d'origine si applicable
- `AMPLIFIER` × Transgressions Scandale du joueur
- `SCELLER` × 5 Domaines
- `FISSURER` × Domaines scellés par l'adversaire
- `ENTRAVER` × Stations entravábles × choix de Domaine de paiement
  (utiliser `GameRules.entrave_payment_options`)
- `PASSER` (toujours)
- `PUISER` si `state.available_corruption[player] == 0`

Sortie typique : 20-50 actions légales par Pulse.

**`Eval.gd`** : score d'un état du point de vue d'un joueur, en `float`
borné par `[-1, +1]` (= probabilité approximative de gagner). Comme
heuristique de départ :

```
eval(state, player) =
    + 0.30 * tanh(ascendant_signed_for(player) / 5)
    + 0.25 * (controlled_domains_diff / 5)
    + 0.20 * (sealed_domains_diff_self_minus_opponent / 5)
    + 0.15 * (infamies_self_minus_opponent / 4)
    + 0.10 * tanh(corruption_lead / 8)
```

Tu ajustes les pondérations avec des parties bot vs bot.

À l'état terminal (Station VI résolue) : retourne `+1` si le joueur a
gagné, `-1` sinon, `0` en cas de Possession Instable (égalité).

**`HeuristicBot.gd`** : choisit l'action qui maximise `Eval` après une
seule profondeur (greedy 1-ply). Sert deux rôles :
- baseline pour mesurer les progrès du MCTS (« le MCTS doit battre
  l'heuristique 70 %+ du temps en bot vs bot »),
- rollout policy pour le MCTS (rollouts pseudo-aléatoires biaisés vers
  l'heuristique).

**`MCTSBot.gd`** : le cœur. Algorithme classique avec ces choix :

- **Sélection** : UCT, `Q(s,a) + C * sqrt(ln(N(s)) / N(s,a))`, `C = sqrt(2)`
  (à tuner).
- **Expansion** : crée un nouveau noeud par action légale non-explorée.
- **Simulation** : rollout via `HeuristicBot` jusqu'à terminal OU
  profondeur max (e.g. 30 actions). À la profondeur max, retourne
  `Eval` au lieu d'un score terminal.
- **Backpropagation** : update visits + value sur la chaîne de noeuds.
  Negamax sur les sommes (chaque joueur maximise son propre eval).
- **Budget** : `time_budget_ms` configurable (défaut 200 ms), boucle
  `while Time.get_ticks_msec() - start < budget` pour garder l'anytime.
- **Clonage d'état** : `GameState.from_dict(other.to_dict())` ou un
  `clone()` ad hoc à ajouter dans `GameState` si la sérialisation est
  trop coûteuse (à mesurer avant d'optimiser).

Sortie : action avec le plus de visites (pas le meilleur Q — visite-
count est plus stable).

## 6. Hook dans TurnManager

Une seule modif dans `scripts/core/TurnManager.gd` (à proposer en PR
séparée, pas dans le commit du bot lui-même) :

```gdscript
# state.bot_for_player : Dictionary[int -> BotBase] — vide en mode
# hot-seat humain, contient un bot par joueur en mode contre-l'ordi.
if state.bot_for_player.has(state.active_player):
    var bot: BotBase = state.bot_for_player[state.active_player]
    var decision := bot.pick_action(state, state.active_player)
    perform_action(decision.action_id, decision.kwargs)
```

Ajouter `var bot_for_player: Dictionary = {}` dans GameState. Ne pas
sérialiser ce champ (c'est du runtime, pas du save state).

## 7. Tests à écrire

`scripts/bot/tests/BotTestRunner.gd` :

- `_test_action_enumeration_completeness` — pour un état donné, le
  count d'actions légales matche un calcul main.
- `_test_eval_signed` — `Eval(state, RED) == -Eval(state, BLUE)` pour
  un état terminal et pour un état mid-game (zero-sum).
- `_test_heuristic_beats_random_90pct` — 100 parties HeuristicBot vs
  RandomBot, attend ≥ 90 % de victoires.
- `_test_mcts_beats_heuristic_70pct` — 50 parties MCTSBot (200 ms)
  vs HeuristicBot, attend ≥ 70 %.
- `_test_decision_under_budget` — toute décision rend en ≤ 600 ms (un
  peu de marge sur le budget cible 200 ms).

Le `RandomBot` est trivial à écrire (`pick_action` = sample uniforme
de `ActionEnumerator.list(state, player)`) et utile uniquement comme
adversaire de test.

## 8. Jalons

| Jalon | Contenu | Critère de fin |
|---|---|---|
| **J1 — Plomberie** | BotBase, ActionEnumerator, RandomBot, hook TurnManager | `RandomBot` joue 100 parties sans erreur, durée moyenne < 5 s |
| **J2 — Heuristique** | Eval.gd, HeuristicBot.gd, tests | HeuristicBot bat RandomBot ≥ 90 % |
| **J3 — MCTS basique** | MCTSBot v1 avec rollouts heuristiques | MCTSBot (200 ms) bat HeuristicBot ≥ 60 % |
| **J4 — MCTS tuning** | Tuner C, profondeur de rollout, biais d'expansion | ≥ 70 % vs HeuristicBot ; décision < 500 ms iPad |
| **J5 — UI mode "vs ordi"** | Dialog "Nouvelle partie → contre l'ordi", sélection difficulté | Optionnel, hors-périmètre du dev bot pur |

## 9. Ce qu'il NE faut PAS faire

- ❌ Pas de modification de `scripts/core/` ou `scripts/data/`. Si un
  helper manque, ajoute-le dans `scripts/bot/`.
- ❌ Pas de threads, pas d'`await`, pas de coroutine cross-frame —
  l'iOS no-thread variant ne supporte pas. Tout en synchrone, dans le
  même frame.
- ❌ Pas de réseau, pas d'API externe (pas de Claude API à runtime).
- ❌ Pas de NN, pas de PyTorch / TensorFlow / ONNX. Pure GDScript.
- ❌ Pas de modification du code de calibration (`scripts/ui/Main.gd`
  zones), pas de modification du print kit, pas de modification des
  cartes. Tout ça est gelé pour cette session.
- ❌ Pas de "j'ai changé une règle pour rendre l'IA meilleure". L'IA
  s'adapte aux règles, pas l'inverse.

## 10. Démarrage

Démarre la conversation en lisant les 9 fichiers de la section 4, dans
l'ordre. Confirme que tu as compris l'API `GameState` / `TurnManager`
en résumant en 5 lignes le flow d'une Pulse. Puis attaque J1 (plomberie)
en proposant le diff avant de l'écrire.

Travaille directement sur `main` (pas de feature branch — c'est la
préférence du repo). Annonce le SHA poussé après chaque commit.

---

Bon courage. Le jeu est solide, les règles V1h sont testées, l'API est
propre. Reste à donner un cerveau aux démons.
