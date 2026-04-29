# Possession V1g — Fiat Tenebris

Prototype Godot 4.x du jeu de plateau **Possession**, jouable en hotseat à 2 joueurs
humains, exportable HTML5/Web. **Pas d'IA, pas de réseau, pas de bots.**

## Lancement dans Godot

1. Installer Godot **4.2+** (version GDScript ; pas C#).
2. Ouvrir ce projet (`project.godot`).
3. Appuyer sur **F5** ou cliquer sur ▶︎.
4. La scène principale est `scenes/Main.tscn`.

## Comment jouer une partie

- Le jeu démarre sur la **Station I — Murmures**, Initiative Rouge.
- Les actions disponibles sont affichées en bas du plateau central.
  Les actions illégales sont automatiquement désactivées.
- À chaque Pulsation, le démon avec l'Initiative agit, puis l'autre.
- Au début de chaque Station I à V, chaque démon **exploite gratuitement** un
  Domaine qu'il contrôle (auto-sélection : meilleur rendement).
- À la fin de chaque Station I à V, la **Réponse liturgique** se résout
  automatiquement (In Integro par défaut, Impedita si elle a été Entravée).
- À la fin de la Station VI, l'**Exorcisme final** se déclenche :
  Rupture de l'âme → Fiat Tenebris → Ascendant.

Les boutons debug en haut permettent de :

- démarrer une nouvelle partie ;
- forcer la Station ou l'Exorcisme suivants ;
- ajouter +1 Corruption au joueur actif ;
- lancer la suite de tests ;
- sauvegarder / charger.

## Lancer les tests

Deux options :

1. **Bouton « Lancer tests »** dans l'UI principale : la sortie est ajoutée au journal.
2. **Scène dédiée** : ouvrir `scenes/TestRunner.tscn` et l'exécuter (F6).

Le runner produit, pour chaque cas :

```
PASS  <nom du test>
FAIL  <nom du test> — <message>
```

et un résumé `X/Y PASS — Z FAIL`.

## Export Web

Voir [docs/deploy_web.md](docs/deploy_web.md).

## CI/CD

Pipeline GitHub Actions complet : tests headless → export Web → publication
automatique sur itch.io (et Netlify en option). Voir [docs/cicd.md](docs/cicd.md)
pour la configuration des secrets et variables.

## Architecture

```
project.godot
icon.svg
export_presets.cfg
README.md
/scenes        # Main.tscn, TestRunner.tscn, panneaux placeholder
/scripts
  /core        # GameEnums, GameState, GameRules, ActionResolver,
               # LiturgyResolver, EndGameResolver, TurnManager, RulesTestRunner
  /data        # DomainData, TransgressionData, LiturgicalResponseData
  /ui          # Main.gd (UI principale procédurale) + stubs
/resources
/tests         # placeholder pour scénarios de tests scriptés futurs
/docs          # deploy_web.md, ambiguities.md
/export        # cible de l'export Web
```

Le **moteur de règles est totalement séparé de l'UI** : `Main.gd` ne lit
le `GameState` qu'en lecture, et toute mutation passe par
`TurnManager.perform_action()`.

## TODO / ambiguïtés

Voir [docs/ambiguities.md](docs/ambiguities.md).
