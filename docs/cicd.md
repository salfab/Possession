# CI/CD — Possession V1g

Pipeline GitHub Actions complet : tests → export Web → publication itch.io et (en option) Netlify.

Fichier : [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

## Vue d'ensemble

```
push sur main / tag v*
└── job test          (Godot headless → run_tests.gd → exit code)
    └── job build-web (Godot headless --export-release "Web")
        ├── job deploy-itch     (butler push)
        └── job deploy-netlify  (opt-in)
```

Tous les jobs Godot tournent dans le conteneur Docker
[`barichello/godot-ci:4.2.2`](https://hub.docker.com/r/barichello/godot-ci),
qui contient l'éditeur headless **et** les export templates pour la version
correspondante.

## Déclencheurs

| Événement                | Effets                                  |
| ------------------------ | --------------------------------------- |
| `push` sur `main`        | tests + build + Pages + itch + Netlify(*)|
| `push` d'un tag `v*`     | identique                               |
| `pull_request`           | tests + build seulement                 |
| `workflow_dispatch`      | manuel : tests + build                  |

(*) Netlify n'est exécuté que si la repo variable `ENABLE_NETLIFY=true`.

## Tests headless

Le driver `scripts/cli/run_tests.gd` étend `SceneTree` :

```bash
godot --headless --path . --script res://scripts/cli/run_tests.gd
```

Il imprime une ligne `PASS` / `FAIL` par cas, puis `=== X/Y PASS, Z FAIL ===`,
et appelle `quit(1)` si au moins un test échoue. La CI fait également un
filet de sécurité avec `grep` sur la ligne de résumé.

## Export Web

```bash
godot --headless --path . --export-release "Web" export/index.html
```

Le preset `Web` est défini dans `export_presets.cfg`. La CI vérifie ensuite
la présence de `index.html`, `index.wasm` et `index.pck` avant d'archiver.

Un fichier `_headers` (Netlify) est ajouté pour servir `Cross-Origin-Opener-Policy`
et `Cross-Origin-Embedder-Policy`, requis par `SharedArrayBuffer`.

## Secrets et variables à configurer

Dans `Settings → Secrets and variables → Actions` du dépôt GitHub.

### Secrets (chiffrés)

| Nom                  | Utilisé par      | Comment l'obtenir                                              |
| -------------------- | ---------------- | -------------------------------------------------------------- |
| `BUTLER_API_KEY`     | `deploy-itch`    | <https://itch.io/user/settings/api-keys>                       |
| `NETLIFY_AUTH_TOKEN` | `deploy-netlify` | <https://app.netlify.com/user/applications#personal-access-tokens> |
| `NETLIFY_SITE_ID`    | `deploy-netlify` | Dans l'interface Netlify : Site settings → General → Site ID  |

### Variables (non chiffrées)

| Nom              | Exemple              | Notes                                              |
| ---------------- | -------------------- | -------------------------------------------------- |
| `ITCH_USER`      | `salfab`             | Nom d'utilisateur itch.io                          |
| `ITCH_GAME`     | `possession-v1g`     | Slug du projet itch.io                             |
| `ITCH_CHANNEL`   | `web`                | Channel butler. Optionnel, par défaut `web`.       |
| `ENABLE_NETLIFY` | `true`               | Mettre à `true` pour activer le job Netlify.       |

## Étapes pour activer GitHub Pages (le plus simple — zéro secret)

1. Sur GitHub : `Settings → Pages`.
2. Sous *Build and deployment → Source*, choisir **GitHub Actions**.
3. Pousser sur `main`. Le job `deploy-pages` publie le build.
4. L'URL apparaît dans la sortie du job (ex. `https://salfab.github.io/Possession/`)
   et dans `Settings → Pages` une fois le premier déploiement fait.

Pas de secret à configurer. C'est la solution recommandée pour avoir un lien
public le plus vite possible.

## Étapes pour activer la publication itch.io

1. Créer le projet sur itch.io en cochant *« This file will be played in the browser »*.
2. Récupérer une clé API depuis <https://itch.io/user/settings/api-keys>.
3. Dans GitHub : `Settings → Secrets and variables → Actions` :
   - ajouter le secret `BUTLER_API_KEY`,
   - ajouter les variables `ITCH_USER` et `ITCH_GAME`.
4. `git push` sur `main`. La CI déploiera la build sur le channel `web`.

Pour une release versionnée :

```bash
git tag v0.1.0
git push origin v0.1.0
```

Le tag déclenche le même pipeline et `butler push --userversion <sha>`
identifie la build dans l'historique itch.io.

## Étapes pour activer Netlify (optionnel)

1. Créer un site Netlify (drag-and-drop d'un build manuel suffit).
2. Récupérer le **Site ID** (dans Site settings → General).
3. Créer un **Personal access token** Netlify.
4. Dans GitHub :
   - secret `NETLIFY_AUTH_TOKEN`,
   - secret `NETLIFY_SITE_ID`,
   - variable `ENABLE_NETLIFY=true`.
5. Pousser sur `main` : la build est déployée en production sur Netlify.

## Lancer le pipeline localement

Reproduire les commandes du workflow :

```bash
# Tests
docker run --rm -v "$PWD":/project -w /project barichello/godot-ci:4.2.2 \
  godot --headless --path . --script res://scripts/cli/run_tests.gd

# Build
docker run --rm -v "$PWD":/project -w /project barichello/godot-ci:4.2.2 \
  bash -c 'mkdir -p export && godot --headless --path . --export-release "Web" export/index.html'

# Servir le résultat
cd export && python3 -m http.server 8000
```

## Évolutions prévues

- Cache des templates Godot sur runner non-conteneurisé si on quitte l'image
  `barichello`.
- Étape `lint` (gdlint via `pip install gdtoolkit`).
- Smoke-test Playwright sur la build Netlify pour vérifier que la canvas se
  charge.
