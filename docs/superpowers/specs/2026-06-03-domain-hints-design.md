# Design — Hints d'avantages de domaine sur le plateau

Date : 2026-06-03
Statut : validé en brainstorming, prêt pour plan d'implémentation

## Problème

Sur le plateau, les bénéfices d'investir dans un domaine donné ne sont pas
clairs. Un joueur ne voit pas, d'un coup d'œil, ce que chaque domaine rapporte
ni pourquoi le viser. Le cas le plus trompeur : **Volonté ne produit aucune
Corruption** mais c'est le domaine de la condition de victoire — rien sur le
plateau ne le signale.

Le seul endroit qui expose une info de rendement aujourd'hui est le libellé
« Exploiter Désir (+2 Corruptions) » dans le menu d'action — donc seulement
après avoir tapé, et seulement pour l'action Exploiter.

## Objectif

Deux ajouts complémentaires :

- **A — Pastilles toujours visibles** : un indicateur de rendement permanent par
  domaine, lisible sans interaction.
- **C — Refonte du menu d'action** : remplacer la `PopupMenu` native (minimale et
  peu lisible) par un panneau habillé dont l'en-tête explique le « pourquoi
  investir » du domaine.

Les deux partagent la même source de vérité pour le texte d'avantage.

## Décisions de design (validées)

- **Densité des pastilles : minimale.** Rendement seul ; pas de mot-clé
  d'avantage sur le plateau (évite l'encombrement et le risque de troncature /
  glyphes manquants sur iPad). Le détail vit dans l'en-tête du menu.
- **Volonté = `★ Victoire`** (accent violet), jamais `0`.
- **Menu : variante grille 2×2** pour les 4 actions de base (grosses cibles
  tactiles), actions dynamiques (Provoquer / Amplifier) en liste dessous.
- **En-tête du menu** : nom · pastille de rendement · ligne d'avantage · bloc
  méta léger *Contrôle : R/V — Transgressions : n* (conservé).
- **Volonté insiste sur la victoire** dans sa ligne d'avantage : « Ne produit
  rien, mais scellé + transgressé = victoire automatique (Fiat Tenebris) ».
- **Pastilles statiques** : leur contenu ne dépend pas du joueur actif ni de
  l'état de partie → construites une fois, aucun coût par refresh.

### Hors scope (YAGNI)

- Le menu FAB reste une `PopupMenu` native (utilitaire / debug).
- Pas de réglage « masquer les hints ».
- Le gain dynamique exact reste affiché uniquement sur la ligne Exploiter du
  menu (les pastilles montrent la fourchette statique).

## Composants

### 1. `DomainData.advantage_text(d) -> String` (source unique)

Nouvel accesseur dans `scripts/data/DomainData.gd`, renvoyant la ligne
d'avantage I18n par domaine. Réutilisé par l'en-tête du menu. Backé par de
nouvelles clés `domain.hint.*` (FR/EN) dans `I18n.gd`.

Contenu cible (FR) :
- Ambition — « Produit 2 Corruptions. Requis pour déclencher des Transgressions. »
- Désir — « Produit 2 Corruptions (3 si transgressé). Active l'infamie « Appétit hérétique ». »
- Foi — « Produit 1 Corruption (2 si transgressé). Bonus d'Ascendant à l'Exorcisme. »
- Peur — « Produit 1 Corruption (2 si un domaine a été fissuré ce tour). »
- Volonté — « Ne produit rien, mais scellé + transgressé = victoire automatique (Fiat Tenebris). »

### 2. Pastilles de rendement (`DomainHintChip`)

- Nouveau `scripts/ui/DomainHintChip.gd` : `Control` à `_draw()` custom (même
  approche que `DomainBadges` pour contourner les glyphes manquants du build
  web). L'étoile de Volonté est un polygone dessiné, pas un caractère `★` ; le
  texte (`2–3 Corr.`, `Victoire`) reste de l'ASCII/latin sûr rendu via la
  police déjà configurée.
- Contenu via de nouvelles clés compactes `domain.chip.*` (FR/EN) :
  `2 Corr.` / `2–3 Corr.` / `1–2 Corr.` / `1–2 Corr.` / `Victoire`.
- Style : pastille pleine accent or pour les domaines producteurs, accent
  violet pour Volonté (cohérent avec le code couleur joueur Violet).
- **Positionnement** : ancré sur les coords normalisées existantes
  `DOMAIN_NAME_POS` (+ offset vertical au-dessus du cartouche), converties en
  pixels par le même chemin que les labels de nom. Calibrable depuis le mode
  Hotspots déjà en place ; pas de nouvelle infrastructure de calibration.
- Construites une seule fois lors du build du plateau dans `Main.gd`.

### 3. Menu d'action refondu (`DomainActionMenu`)

- Nouveau `scripts/ui/DomainActionMenu.gd` (+ `.tscn` si utile) : panneau
  `PanelContainer`/`Control` parchemin remplaçant `_action_popup`.
- API : `open_for(d_id, state, player, screen_pos)` — (re)peuple à l'ouverture,
  se positionne près du tap, borné au viewport ; tap à l'extérieur ferme.
- Émet un signal `action_chosen(payload)` ; `Main.gd` réutilise la logique
  existante de `_on_popup_action` pour router vers `manager.perform_action(...)`.
- Structure :
  - **En-tête** : `GameEnums.DOMAIN_NAMES[d]` · pastille rendement (même label
    compact `domain.chip.*` que le plateau) · `DomainData.advantage_text(d)` · méta
    *Contrôle* (`state.controller_of`) + *Transgressions* (compte sur
    `state.domain(d)`).
  - **Grille 2×2** : Investir / Exploiter / Sceller / Fissurer. Désactivé +
    raison via `GameRules.why_cannot_*`. Exploiter affiche le gain réel via
    `GameRules.production_of`.
  - **Liste dynamique** : Provoquer (par Transgression, origine = ce domaine) et
    Amplifier (Scandales possédés) — logique reprise telle quelle de
    `_on_domain_clicked`.

## Flux de données

```
domain.chip.* (I18n)           ──► pastille plateau (statique)
                               └─► pastille rendement de l'en-tête du menu
DomainData.advantage_text(d)  ──► en-tête du menu (ligne "pourquoi")
GameRules.production_of(...)   ──► ligne Exploiter (gain dynamique)
GameRules.why_cannot_*(...)    ──► état désactivé + raison des actions
state.controller_of / domain() ──► méta en-tête
```

Aucune modification de `scripts/core/`. Les seuls ajouts de données sont dans
`scripts/data/` (`DomainData` accesseur + `I18n` clés).

## Fichiers touchés

- `scripts/ui/Main.gd` — build des pastilles ; remplacement du câblage
  `_action_popup` par `DomainActionMenu` ; `_on_domain_clicked` appelle
  `open_for` ; `_on_popup_action` branché sur le signal du menu.
- `scripts/ui/DomainHintChip.gd` — **nouveau**.
- `scripts/ui/DomainActionMenu.gd` (+ `.tscn` éventuel) — **nouveau**.
- `scripts/data/DomainData.gd` — `advantage_text(d)`.
- `scripts/data/I18n.gd` — clés `domain.chip.*` et `domain.hint.*` (FR/EN).

## Gestion des cas limites

- **Décisions en attente / fin de partie / mode calibration** : `open_for` ne
  s'ouvre pas (même gardes que `_on_domain_clicked` aujourd'hui).
- **Menu près du bord** : position bornée au viewport.
- **Glyphes web** : pastilles custom-drawn ; aucune dépendance à des caractères
  hors latin de base.
- **Volonté `0`** : remplacé par `★ Victoire` dans la pastille et ligne
  d'avantage dédiée dans le menu.

## Tests

- Headless (`run_tests.gd`) : `DomainData.advantage_text(d)` non-vide pour les 5
  domaines ; mapping label de pastille non-vide pour les 5 ; les clés I18n
  référencées existent en FR et EN.
- UI : validée par compilation du build + passage des tests existants, puis
  vérification visuelle live sur le déploiement (pastilles lisibles, menu
  ouvert/fermé, actions désactivées avec raison).
