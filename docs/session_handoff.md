# Session handoff — Possession V1g

## Projet

Jeu de plateau 2 joueurs hotseat (Godot 4.2.2 / GDScript 4, export Web/HTML5).
Deux démons s'affrontent pour posséder un pape. Moteur de règles pur séparé de
l'UI. CI/CD via GitHub Actions → GitHub Pages + itch.io optionnel.

**Repo:** `salfab/Possession`  
**Branch principale:** `main`  
**Dernier commit connu:** `c39dc05` — Fix CardImages named consts  

---

## Architecture du projet

```
scenes/
  Main.tscn          — scaffold minimal (Background ColorRect + BoardAspect)
scripts/
  core/
    GameEnums.gd      — enums : PlayerId, DomainId, StationId, TransgressionFace…
    GameState.gd      — état de partie, TransgressionInstance, PendingDecision
    GameRules.gd      — règles légales / why_cannot_*
    ActionResolver.gd — résolution des actions
    LiturgyResolver.gd
    EndGameResolver.gd
    TurnManager.gd    — pilote le déroulement des stations
    RulesTestRunner.gd
  data/
    CardImages.gd     — autoload singleton, preloads toutes les textures
    TransgressionData.gd — catalogue des 10 transgressions (CATALOG, ALL_IDS)
    DomainData.gd
    LiturgicalResponseData.gd
  ui/
    Main.gd           — UI complète construite procéduralement (tout en code)
  cli/
    run_tests.gd      — driver headless pour CI
assets/
  board.jpg                     577 KB (converti de PNG 3.3 MB)
  cards/
    transgressions/             20 PNG ~50 KB/fichier (cartes pré-composées RGB)
    liturgies/                  10 PNG ~55 KB/fichier (cartes pré-composées RGB)
    special/exorcisme_final.jpg 498 KB (converti de PNG 3.1 MB)
    illustrations/              15 JPG ~500 KB (exclus du pck, artwork source)
    templates/                  4 PNG RGBA (exclus du pck, templates chroma-key)
  fonts/                        3 TTF (exclus du pck)
tools/sources/                  backups PNG originaux (exclus du pck)
web_assets/
  coi-serviceworker.js          SharedArrayBuffer workaround pour GitHub Pages
  version-banner.html           bandeau debug (SHA, timestamp, reset SW, log)
export_presets.cfg              preset "Web", exclude_filter sur illustrations/
                                templates/fonts/tools
```

**Autoloads (ordre d'initialisation) :**
GameEnums → DomainData → TransgressionData → LiturgicalResponseData → CardImages

---

## État actuel de l'UI (Main.gd)

UI entièrement procédurale (pas de .tscn pour les overlays), gothique sombre :
- Header : noms joueurs, bouton Sauvegarder
- Barre d'ascendant (split ColorRect rouge/bleu)
- Ressources (corruption disponible + sur domaines par joueur)
- Prompt de statut + log journal (scrollable, drag-to-scroll)
- Actions : boutons contextuels selon les règles
- Grille de domaines responsive (1/2/3 colonnes selon largeur)
- Sidebar à onglets : Journal | Transgressions | Règles debug
- Zoom/pan sur le plateau (pinch + scroll souris)
- Dialogs modaux : liturgie, décision, fin de partie, transgressions, vue carte plein écran

**Composants clés :**
```
_liturgy_dialog      — AcceptDialog avec TextureButton (carte liturgique)
_trans_dialog        — AcceptDialog avec ScrollContainer + VBoxContainer
_trans_scroll        — ScrollContainer drag-to-scroll
_trans_content       — VBoxContainer (1 PanelContainer par transgression)
_decision_dialog     — AcceptDialog pour PendingDecision
_endgame_dialog      — AcceptDialog (exorcisme final)
_fullscreen_card_dialog — AcceptDialog (TextureRect grande carte)
```

---

## CardImages.gd — détail important

**Problème rencontré :** dans Godot 4.2 export web, les `preload()` inline dans
un dict littéral `const` peuvent silencieusement évaluer à `null` au runtime
(les ressources sont dans le .pck mais inaccessibles via le dict).

**Fix appliqué (c39dc05) :** chaque preload est déclaré comme const nommé
(`_T_NEPOTISME_SCANDALE`, etc.) puis référencé dans le dict `TRANSGRESSIONS`.

```gdscript
# Pattern correct (fix)
const _T_NEPOTISME_SCANDALE := preload("res://assets/cards/transgressions/nepotisme_scandale.png")
const TRANSGRESSIONS: Dictionary = {
    "nepotisme_scandale": _T_NEPOTISME_SCANDALE,
    ...
}

# Pattern problématique (ne pas réutiliser)
const TRANSGRESSIONS := {
    "nepotisme_scandale": preload("res://assets/cards/transgressions/nepotisme_scandale.png"),
    ...
}
```

Une `push_warning` est ajoutée dans `transgression()` si la clé manque — elle
apparaît dans le log de la version-banner (bouton jaune "i").

---

## Taille du pck (critique pour le web)

wasm-instantiate échoue si le pck dépasse ~10-15 MB sur mobile/navigateurs lents.

**Assets dans le pck (commit actuel) :**
- `assets/board.jpg` — 577 KB
- `assets/cards/transgressions/*.png` — 20 × ~55 KB = ~1.1 MB
- `assets/cards/liturgies/*.png` — 10 × ~55 KB = ~550 KB
- `assets/cards/special/exorcisme_final.jpg` — 498 KB
- Scripts + scènes — ~200 KB
- **Total estimé : ~2.9 MB** ✓

**Exclus du pck (exclude_filter) :**
`assets/cards/illustrations/*, assets/cards/templates/*, assets/fonts/*, tools/*`

---

## Fonctionnement des cartes

### Cartes pré-composées (état actuel)

Les 20 cartes transgressions et 10 liturgies sont des PNG 900×1260 RGB
pré-composées (texte + illustration intégrés). Créées offline via Pillow.

`CardImages.transgression(tid, face)` → clé `"tid_scandale"` ou `"tid_infamie"`  
`CardImages.liturgy(response_id, impedita)` → clé `"response_id_in_integro"` ou `"response_id_impedita"`

### Card.tscn (prochaine étape — NON DÉPLOYÉE)

Un premier jet de Card.tscn a été développé (commit `18057a3`) puis revert
(`3c3fca9`) parce que le pck était trop lourd (~80 MB). L'architecture prévue :

```
Card (Control)
  ├── IllustrationRect (TextureRect)  ← illustration JPG en cover dans zone arche
  ├── TemplateRect (TextureRect RGBA) ← template chroma-keyé en overlay
  └── Labels positionnés par anchors normalisés
       title (300,85,770,190), cost (70,80,260,265), domain (820,130,985,215)
       arch (130,200,925,1080), text (215,1102,855,1320), face (320,1360,750,1420)
```

Fontes : IM Fell English (Regular + SC) + Cinzel Decorative Bold
→ dans `assets/fonts/` (exclus du pck, à réintégrer si Card.tscn reprend)

---

## Templates RGBA

4 templates chroma-keyés (fond vert → alpha), dans `assets/cards/templates/` :
- `transgression_scandale.png` — fond parchemin clair, arche gothique
- `transgression_infamie.png` — fond plus sombre
- `liturgie_in_integro.png`
- `liturgie_impedita.png`

Pipeline d'extraction Python : `tools/extract_arch_alpha.py`  
Clé : greenness = G - max(R,B) → alpha = clip((150 - greenness) * 255/100, 0, 255)  
Attention : cast en `float32` avant multiplication (sinon overflow int16).

Slots calibrés pour 1060×1484 :
```python
SLOTS = {
    "title":  (300, 85,  770, 190),
    "cost":   (70,  80,  260, 265),
    "domain": (820, 130, 985, 215),
    "arch":   (130, 200, 925, 1080),
    "text":   (215, 1102, 855, 1320),
    "face":   (320, 1360, 750, 1420),
}
```

---

## Règles V1g implémentées

- 5 Domaines : Ambition, Désir, Foi, Peur, Volonté
- 10 Transgressions (CATALOG dans TransgressionData.gd)
- 5 Réponses liturgiques : Signe de Croix, Examen de Conscience, Contrition,
  Confession, Communion
- 6 Stations : Murmures, Tentation, Chute, Confession, Office sacré, Exorcisme
- Actions : Investir, Exploiter, Provoquer, Amplifier, Sceller, Fissurer,
  Entraver, Passer
- Méchaniques : Corruption, Domination, Profondeur/Étendue/Ancrage, Fiat Tenebris,
  Tribut de Volonté, Rupture de l'âme, Exorcisme final, Ascendant
- Décisions en attente (PendingDecision) pour Confession, exploitation gratuite,
  Simonie Infamie (foi_next_response_impedita)

---

## Version banner (debug)

Injecté dans index.html par CI. Affiche SHA+timestamp du build. Boutons :
- **Reset SW + cache** → désinscrire tous les SW + vider tous les caches → reload
- **× / i** → fermer/rouvrir le bandeau
- Log auto : console.log/warn/error + window.onerror → visible dans le bandeau

**À faire après chaque nouveau déploiement :** cliquer "Reset SW + cache" pour
que le navigateur charge le nouveau .pck et non le cache.

---

## CI/CD

Workflow `.github/workflows/ci.yml` :
1. **test** — `godot --headless --script run_tests.gd` (règles)
2. **build-web** — `godot --headless --export-release "Web" export/index.html`
3. **deploy-pages** — GitHub Pages (sur push main ou tag v*)
4. **deploy-itch** — butler push (si secrets BUTLER_API_KEY, ITCH_USER, ITCH_GAME)
5. **deploy-netlify** — opt-in via var ENABLE_NETLIFY=true

Image Docker : `barichello/godot-ci:4.2.2`

---

## Tâches restantes connues

### Fix en cours
- [ ] **Vérifier que les images apparaissent** dans la liste des transgressions
  après le déploiement de `c39dc05`. Tester avec Reset SW + cache puis ouvrir
  "Transgressions". Si le push_warning s'affiche dans le log, le fix named-const
  n'a pas suffi → investiguer côté VRAM compression (voir ci-dessous).

### Si les images n'apparaissent toujours pas
Piste : `vram_texture_compression/for_desktop=true` génère du S3TC qui peut
échouer silencieusement sur certains navigateurs/mobiles. Solutions alternatives :
- Désactiver VRAM compression (`for_desktop=false`) → textures plus lourdes en VRAM
- Activer Basis Universal → transcoding S3TC/ETC2 à la volée (nécessite Godot 4.3+)
- Créer des `.import` override files pour les cartes avec `compress/mode=0` (lossless)

### Prochaines features

1. **Réintégrer Card.tscn** (composition runtime) — maintenant que le pck est ~3 MB,
   on a la marge pour ajouter templates + fontes (< 2 MB supplémentaires).
   - Copier les fontes dans assets/fonts/ et les retirer de l'exclude_filter
   - Restaurer Card.tscn et Card.gd (voir commit `18057a3` comme référence)
   - CardImages.gd : ajouter preloads des illustrations JPG + templates PNG
   - Main.gd : remplacer TextureButton par instanciation Card.tscn dans
     `_make_transgression_card` et `_build_liturgy_dialog`

2. **UX mobile** — la grille de domaines est responsive mais les polices
   système sont petites sur mobile. Avec les fontes IM Fell English intégrées,
   l'aspect gothique sera meilleur.

3. **Tests règles manquants** — vérifier couverture de tous les edge cases
   Abdication Intérieure, Pacte Silencieux à l'Exorcisme final.

---

## Commandes utiles

```bash
# Vérifier l'état du dernier déploiement
git log --oneline -5

# Taille totale des assets dans le pck (approximation)
du -sh assets/board.jpg assets/cards/transgressions/ assets/cards/liturgies/ assets/cards/special/

# Voir les fichiers exclus du pck
grep exclude_filter export_presets.cfg

# Push vers main (déclenche CI)
git push -u origin main
```
