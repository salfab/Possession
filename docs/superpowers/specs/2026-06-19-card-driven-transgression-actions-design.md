# Carte-action unique pour Provoquer / Amplifier — Design

Date : 2026-06-19
Statut : validé (modèle A)

## Contexte et motivation

Aujourd'hui, provoquer ou amplifier une transgression se fait via **4 chemins
redondants**, et aucun ne montre la carte avant d'agir :

| Surface | Provoquer | Amplifier | Aperçu carte |
|---|---|---|---|
| Menu domaine (`DomainActionMenu._build_dynamic`) | cellule « Provoquer X en Y » | cellule « Amplifier X » | bouton « Carte » (ajouté récemment) |
| Panneau démon (`_build_player_panel`) | — | bouton inline « Amplifier » (`_on_panel_amplifier_clicked`) | tap → ouvre déjà la carte (`_on_player_transgression_clicked`) |
| Catalogue « Transgressions » (`_trans_dialog`) | bouton (`_on_provoquer_clicked`) | bouton (`_on_amplifier_clicked`) | — |
| Carte plein écran transgression | ❌ | ❌ | flip Scandale↔Infamie |

De plus, un audit (workflow `possession-demon-choice-audit`) a montré que **6
transgressions** dont le texte de carte impose un choix au démon sont résolues
en *auto / silencieux* pour l'humain (picker manquant) : **Intrigue, Mascarade,
Dogme, Dénonciation, Panique, Renoncement**. Persécution et Simonie ont déjà
reçu un picker obligatoire (`_show_demon_choice`).

## Objectif

Faire de la **carte plein écran la seule surface d'action** : le joueur ouvre
toujours la carte (depuis le menu domaine, le panneau démon ou le catalogue),
voit l'art + l'effet, puis provoque/amplifie depuis un bouton sur la carte —
exactement comme le bouton `Entraver` existe déjà sur la carte de liturgie
(`_fullscreen_card_entraver_btn` + `_update_fullscreen_entraver_button`). Les 4
chemins directs deviennent 1. C'est aussi le point naturel pour héberger tous
les choix par carte.

Non-objectifs : changer les règles des transgressions ; toucher au flux des
liturgies ; ajouter de nouveaux types de transgressions.

## Conception

### 1. Bouton d'action contextuel sur la carte de transgression

Réutiliser le patron du bouton `Entraver` (un bouton déjà présent dans le dialog
plein écran, montré/masqué selon le contexte par `_update_fullscreen_flip_button`
→ `_update_fullscreen_entraver_button`). Ajouter un bouton d'action transgression
(ou réutiliser un bouton générique) dont l'état est calculé à l'**ouverture** :

- Transgression NON possédée + `GameRules.can_provoquer(state, active, tid)` vrai
  depuis l'origine → **« Provoquer ici »** (libellé avec le domaine si pertinent).
- Scandale possédé par le joueur actif + `GameRules.can_amplifier(...)` vrai →
  **« Amplifier »**.
- Sinon → aucun bouton ; sous-titre discret avec la raison
  (`why_cannot_provoquer` / `why_cannot_amplifier`).

Une transgression est unique : si tu la possèdes tu ne peux pas la re-provoquer,
sinon tu ne peux pas l'amplifier → les deux états sont mutuellement exclusifs,
pas d'ambiguïté de bouton.

`_fullscreen_card_binding` (kind == "transgression") gagne un champ **origin**
(domaine d'origine pour la provocation) — `-1` quand la carte est ouverte pour
amplifier (l'amplification utilise l'origine de l'instance possédée).

### 2. Lanceurs → aperçu

- **Menu domaine** : taper une entrée provocable/amplifiable ouvre la carte avec
  le **domaine tapé comme origine**. Suppression des cellules directes
  « Provoquer/Amplifier » et du bouton « Carte ». La liste reste filtrée par
  `why_cannot_provoquer` / `transgression_origin_options` (inchangé).
- **Panneau démon** : ouvre déjà la carte au tap (`_on_player_transgression_clicked`).
  Suppression du bouton inline « Amplifier » (`_on_panel_amplifier_clicked` et le
  bouton dans `_build_player_panel` / `_refresh_player_transgression_panels`).
- **Catalogue** : taper une entrée ouvre la carte-action ; suppression de
  `_on_provoquer_clicked` / `_on_amplifier_clicked` et de leurs boutons.

### 3. Choix par carte (pickers obligatoires)

Le bouton « Provoquer ici » enchaîne les choix requis via le helper existant
`_show_demon_choice` (dialog exclusif, **pas de fermeture sans choisir**), puis
appelle `manager.perform_action(PROVOQUER, {def_id, origin, <extra>})`.

Une **table par-carte** centralise « quels choix avant de provoquer » :

| Carte | Choix (kwarg) | Candidats |
|---|---|---|
| Persécution | `target_domain` | domaines contestés où l'adversaire a ≥1 (déjà fait) |
| Simonie | `target_station` | Station courante / suivante (déjà fait) |
| Intrigue | `target_domain` | domaines que tu contrôles sans Domination nette, non scellés |
| Mascarade | `from_domain` + `to_domain` | source où tu as ≥1 ; destination non scellée par l'adversaire |
| Dogme | `target_station` | Station courante / suivante |
| Dénonciation | `target_domain` | domaines contrôlés par l'adversaire où tu as ≥1 |
| Panique | `target_domain` | domaines contestés |
| Renoncement | `target_domain` | domaines où l'adversaire a ≥1 |

Règle ≤1 candidat : si 0 → pas de picker (fallback / pool) ; si 1 → choix
implicite, pas de dialog. ≥2 → picker obligatoire.

Au passage, corriger la **validation** côté `ActionResolver._apply_scandal_effect`
pour les cartes que l'audit a signalées comme ne validant pas leur cible
(ex. Intrigue accepte n'importe quel `target_domain` sans vérifier
contrôle/scellé). La validation doit refléter le texte de la carte ; en cas de
cible invalide, repli documenté (fallback existant).

### 4. Origine

Modèle : **domaine tapé = origine**. On provoque toujours depuis le menu domaine
(le panneau démon et le catalogue servent à amplifier / prévisualiser). Pour les
cartes `origin_choice` (Simonie), le menu filtre déjà les origines légales via
`GameRules.transgression_origin_options`, donc le domaine tapé est toujours une
origine valide ; pas de picker d'origine séparé.

### 5. Cas limites

- Partie terminée, décision en attente, ou réponse liturgique en attente
  (`pending_liturgy`) → bouton d'action masqué (déjà gardé par `perform_action`).
- Carte ouverte en aperçu pur (ni provocable ni amplifiable) → flip seul.
- Fermeture du dialog carte = aucune action (l'action ne part que du bouton).

## Tests

- **Logique** (RulesTestRunner, vérifié par CI) : la validation par-carte et le
  passage de `target_domain` / `target_station` / `from_domain` / `to_domain`
  pour les 6 cartes à picker manquant — un test par carte (comme
  `_test_persecution_target`, `_test_simonie_entrave_target`).
- **UI** : pas de preview headless (Docker souvent down) → le rendu (bouton sur
  la carte, suppression des cellules/boutons, enchaînement des pickers) est
  vérifié sur le déploiement live par l'utilisateur, par lots.

## Phases d'implémentation (pour le plan)

1. **Bouton d'action sur la carte** : ajouter Provoquer/Amplifier à la carte de
   transgression (état + libellé + légalité), champ `origin` dans le binding,
   câblage vers le flux provoke/amplify existant (Persécution/Simonie chaînent
   déjà). Vérif live.
2. **Reroutage des lanceurs** : menu domaine (entrée → carte, retrait des
   cellules + bouton « Carte »), panneau démon (retrait inline « Amplifier »),
   catalogue (entrée → carte, retrait des boutons). Vérif live.
3. **Pickers manquants + validation** : table par-carte pour les 6 transgressions
   restantes, pickers obligatoires `_show_demon_choice`, validation
   `_apply_scandal_effect`, tests de règles. Vérif CI + live.

Chaque phase est un lot indépendant, poussé puis validé (CI pour la logique,
live pour l'UI).
