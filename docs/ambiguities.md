# Ambiguïtés et TODO du prototype Possession V1g

Ce document liste les points où la spécification laisse une marge d'interprétation,
et les choix retenus dans ce prototype. À reprendre lors d'une future itération.

## 1. Cibles automatiques des Réponses liturgiques

Plusieurs Réponses (Signe de croix, Examen, Communion) prévoient un cas
« le démon sans Initiative choisit » en cas d'égalité après les départages
explicites. Pour le prototype, on choisit **automatiquement et déterministe**
en suivant la priorité fixe :

```
Volonté > Foi > Peur > Désir > Ambition
```

et, en cas d'égalité résiduelle, on prend le premier élément de la liste filtrée.

> TODO UI : exposer une boîte de dialogue lorsque la cible doit être choisie
> par un joueur humain.

## 2. Confession (Station IV) — choix des pénitences

Le démon ciblé doit en théorie choisir 1 ou 2 pénitences parmi 3.
Le prototype les choisit **automatiquement** dans l'ordre :
`perdre 2 Corruptions disponibles` → `mettre un Domaine en Pénitence`
→ `fissurer un Sceau personnel`. Cela donne au démon ciblé la pénitence
la moins coûteuse en priorité, mais ce n'est pas un choix joueur.

> TODO UI : modale de choix de pénitence pour le démon ciblé.

## 3. Exploitation gratuite en début de Station

Spec : « chaque démon peut exploiter gratuitement 1 Domaine qu'il contrôle ».
Le prototype choisit **automatiquement** le Domaine au plus haut rendement
(initiative en premier).

> TODO UI : interrompre l'animation pour proposer le choix manuel.

## 4. Initiative

L'initiative par Station est figée selon la liste donnée dans la spec
(R, B, R, B, R, B). Aucun mécanisme dynamique n'est implémenté à ce stade.

## 4bis. Simonie (Infamie) — câblé

Spec : « La prochaine Réponse liturgique qui cible Foi est automatiquement Impedita. »
**Implémenté** : l'amplification de Simonie arme le flag
`state.foi_next_response_impedita`. La prochaine Réponse qui cible Foi
consomme le flag et résout en mode Impedita.

## 2bis. Confession — câblé en interactif

Le démon ciblé reçoit une **PendingDecision** dans `state.pending_decisions`.
La modale UI propose les 3 pénitences applicables ; le démon clique 1 ou 2
fois (selon Impedita) et la résolution se poursuit. Tant que la décision
n'est pas résolue, la Station n'avance pas.

## 3bis. Exploitation gratuite — câblée en interactif

Au début de chaque Station I à V, deux **PendingDecision** `free_exploit`
sont mises en file (joueur initiative en premier). Chaque démon clique le
Domaine qu'il veut exploiter (ou « Passer »).

## 5. Trafic de charges (Scandale)

Spec : « la prochaine fois que vous Entravez une Réponse liturgique, réduisez son coût de 1 ».
Pour V1g, ce buff n'est pas restreint à une seule utilisation par Station ;
il est consommé à la **prochaine** Entrave payée, puis effacé.

## 6. Paranoïa (Infamie)

L'effet « choisir entre les deux Domaines les plus éligibles » nécessite une
interaction joueur. Le prototype ne l'expose pas encore — un TODO est posé.

> TODO : prompt manuel quand le porteur de l'Infamie Paranoïa est concerné.

## 7. Profanation (Infamie)

La spec indique « Pas d'effet actif supplémentaire nécessaire en prototype ».
On respecte cela : la simple présence de l'Infamie en Foi remplit Profondeur.

## 8. « Domaine fissuré ce tour » pour Peur

Le flag `was_fissured_this_station` est mis à `true` par toute fissure
(démoniaque, In Integro, Impedita, Paranoïa) dans la Station courante,
et reset au début de chaque Station.

## 9. Examen de conscience — interdiction de scellement

L'interdiction est modélisée via le champ `penitence_until_station`,
qui implique déjà « ne peut pas être scellé ». C'est un raccourci ; en V2
il faudrait peut-être un champ dédié `no_seal_until_station`.

## 10. Buff Foi (Ascendant final)

Implémenté : chaque Infamie possédée en Foi ajoute +1 au démon possesseur
(en plus du +1 déjà accordé pour une Infamie dans un Domaine contrôlé).
Cela peut donner +2 par Infamie en Foi si le démon contrôle Foi —
ce qui correspond à la lecture littérale du « +1 supplémentaire ».

## 11. Communion In Integro non scellé

La spec dit : « Brisez la Domination. Ce Domaine ne peut pas être scellé
avant l'Exorcisme final. » Cette interdiction est posée même si le Domaine
n'est pas scellé au moment de la Communion.

## 12. Sauvegarde web

`save_game()` / `load_game()` utilisent `user://save_game.json`.
Sur Web, Godot persiste cela dans IndexedDB du navigateur. Aucun export
de fichier vers le disque n'est exposé pour l'instant.
