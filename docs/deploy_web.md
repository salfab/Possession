# Publication Web — Possession V1g

Ce projet est conçu pour être exporté en **HTML5 / WebAssembly** depuis Godot 4.x.

## 1. Exporter depuis Godot

1. Ouvrez le projet dans **Godot 4.2 ou plus récent** (GDScript uniquement).
2. Téléchargez les *Export Templates* via `Éditeur → Gérer les modèles d'exportation…`.
3. Allez dans `Projet → Exporter…`.
4. Sélectionnez le preset `Web (Runnable)` (déjà configuré dans `export_presets.cfg`).
5. Cliquez sur `Exporter le projet…` et choisissez `export/index.html` comme destination.

## 2. Fichiers produits

L'export Web produit, à côté de `index.html` :

```
index.html
index.js
index.wasm
index.pck
index.icon.png
index.apple-touch-icon.png
index.audio.worklet.js
```

Servez l'ensemble du dossier — pas seulement `index.html`.

## 3. Test local

Le navigateur exige des en-têtes COOP/COEP pour faire tourner WebAssembly à threads.
Le plus simple est :

```bash
cd export
python3 -m http.server 8000
```

Puis ouvrir <http://127.0.0.1:8000/>.

> Si le jeu n'affiche pas (Worker error), c'est probablement un problème de COOP/COEP.
> Dans ce cas, utilisez l'option « Threads support: Disabled » dans le preset (déjà configuré
> ici), ou déployez derrière un serveur qui ajoute :
>
> ```
> Cross-Origin-Opener-Policy: same-origin
> Cross-Origin-Embedder-Policy: require-corp
> ```

## 4. Publication

### GitHub Pages

```bash
cd export
git init
git add .
git commit -m "Possession V1g web build"
git branch -M gh-pages
git remote add origin https://github.com/<user>/<repo>.git
git push -u origin gh-pages
```

Puis activez Pages depuis `gh-pages` dans les Settings.

### itch.io

1. Zippez le contenu de `export/`.
2. Uploadez le ZIP sur itch.io en cochant *« This file will be played in the browser »*.
3. Renseignez `index.html` comme point d'entrée.

### Netlify

`netlify deploy --dir=export --prod`

## 4bis. Publication automatique (CI/CD)

Le pipeline GitHub Actions (`.github/workflows/ci.yml`) publie automatiquement
sur itch.io à chaque push sur `main` ou tag `v*`, et optionnellement sur Netlify.

Voir [docs/cicd.md](cicd.md) pour la liste des secrets et variables à configurer.

## 5. Limitations connues

- Pas de réseau, pas de matchmaking, pas de bots.
- Sauvegarde locale dans le `userdata` du navigateur uniquement (`user://save_game.json`).
- Le rendu utilise `gl_compatibility` pour maximiser la compatibilité navigateur.
- Pas de C# : GDScript uniquement.
- Sur iOS Safari, l'audio peut nécessiter une interaction utilisateur initiale.
