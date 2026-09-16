# Note pour la session du lot 4 — Setup

**Date :** 2026-09-16
**Émetteur :** session du lot 6 (table multijoueur)
**Destinataire :** la session qui exécutera le lot 4
**Spec :** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` §2.8 et §3.3

Le lot 4 démarre après le merge du lot 6. Voici ce qu'il trouvera changé, et les trois dettes qui l'attendent nommément.

---

## 1. La dette qui t'appartient, et que personne d'autre ne peut solder

### Le toggle « Timer de partie »

La spec V4 §3.2 l'a **délibérément reporté au lot 4** : le réglage existe dans `GameSetupModal` mais n'a jamais été transmis à la page. Le câbler à travers un modal que ce lot supprime aurait été du travail jeté. C'est maintenant à toi, et c'est écrit dans la spec, pas dans une liste de constats mineurs.

### Les parties « Standard » à deux comportements

**C'est le point le plus important de cette note.** Le lot 3 a corrigé un défaut réel : `maxCommanderDamage` valait 21 par défaut sans qu'aucun preset ne le surcharge, si bien qu'en Standard un joueur pouvait être déclaré mort par des dégâts de commandant qui n'existent pas dans ce format.

La correction ne s'applique qu'aux parties **neuves**. Une partie Standard sauvegardée avant le lot 3 garde `21` dans son snapshot et affiche encore la grille de commander damage. Deux parties du même format se comportent donc différemment selon leur date de création.

La session du lot 3 a explicitement renvoyé l'arbitrage ici, parce que c'est le lot qui refait le setup et la reprise de partie. Trois options, à trancher avec l'utilisateur :

1. **Migration au chargement** — le snapshot recalcule `maxCommanderDamage` depuis son format. Propre, mais écrase un réglage Custom volontaire.
2. **Migration seulement si le format n'est pas Custom** — plus sûr, plus de code.
3. **Ne rien faire** — les vieilles parties finissent, le problème s'éteint de lui-même. Défendable si la reprise en un tap (§2.8) ne ressuscite que la dernière partie.

Ne choisis pas seul : c'est un arbitrage produit, pas technique.

### Le réordonnancement par glisser-déposer

L'aperçu de glissement fige la zone à 130 px, ce qui rend le vrai geste intestable en widget test. Reporté depuis le lot 3, **passé en critère de sortie du lot 6** parce que ce lot place des zones sur quatre côtés. Si le lot 6 l'a soldé, cette ligne ne te concerne plus — vérifie le journal du lot 6 avant de t'en inquiéter.

---

## 2. Ce que le lot 6 change pour toi

Le lot 4 fait de la table **l'écran de configuration** (§2.8, setup inline). Il hérite donc directement de la géométrie du lot 6.

- **`seatsFor(playerCount)` (`lib/models/table_seat.dart`) décide de la disposition.** Ton setup inline doit y poser ses cases de joueur, pas réinventer un placement. Un « + » qui ajoute un joueur change le nombre de joueurs, donc **change les sièges de tout le monde** — c'est la propriété à éprouver en premier, et elle est visible : à 3 joueurs on est en face-à-face, à 4 tout le monde bascule sur les quatre côtés.
- **`AdaptiveGrid` ne décide plus rien.** Si tu as besoin d'une disposition particulière pour le setup, elle se décide dans `seatsFor`, jamais dans la grille.
- **La rotation initiale est posée par `GameSession.newGame`** depuis le siège. La rotation choisie par un joueur gagne ensuite et est persistée : ne l'écrase pas en repassant par le setup.
- **Le contrat de densité** (`lib/widgets/life_counter/layouts/density_tier.dart`) décide de ce qu'une zone affiche. En cran minimal, une zone n'affiche que les PV : si ton setup inline veut afficher un nom ou un sélecteur de profil dans la case, il devra le faire **hors** du contrat de densité, ou assumer qu'il disparaît à 7-8 joueurs.
- **La poignée ne descend jamais sous 30 px** et reste le seul point d'entrée du tiroir, quel que soit le cran. C'est une décision corrigée en cours de route, après que la première version de la spec du lot 6 proposait de la supprimer en cran minimal.

**Ce que le lot 6 ne touche pas :** `GameSetupModal`, `GameSetupController`, `StatsTab`, les profils, l'artwork Scryfall, la persistance Drift. Tout le périmètre du lot 4 est intact.

---

## 3. Les règles de travail que les lots 1 à 3 ont payées

Reprends-les telles quelles, elles ne sont pas négociables :

1. **`git add` avec chemins explicites.** Jamais `git add -A`, jamais `git commit -a`. Le dépôt est partagé entre sessions ; un `add -A` a failli embarquer les documents d'une autre session dans un commit de correction.
2. **Les gestes se jouent, ils ne se simulent pas.** `tester.tap(...)`, jamais un appel direct au callback. C'est ce qui a révélé qu'`EliminationOverlay` absorbait tous les gestes d'une zone éliminée — défaut invisible pendant tout le cycle V3.
3. **Un glissement se livre en incréments**, jamais en un `PointerMoveEvent` unique.
4. **Tout test de non-régression doit être vérifié discriminant** : casse temporairement le code qu'il protège, vérifie qu'il échoue, rétablis.
5. **Les tests de widgets se décrivent par leurs assertions dans les plans, pas en code verbatim.** Le code de test écrit de mémoire a produit **six défauts de compilation** sur les lots 1 et 2 ; le lot 3 est passé aux assertions décrites et n'en a eu aucun. Le plan du lot 6 lui-même en contenait deux, trouvés à la relecture — `GameSession.newGame(playerCount:)` alors que la factory prend `playerConfigs`, et `CriticalOverlay(level: 2)` alors que `level` est un `enum`.
6. **Aucun nouveau geste global** sans le demander d'abord. La surface de gestes de `life_dial.dart` a coûté trois rondes de correction et quatre constats Critical.

---

## 4. Si tu ne dois retenir qu'une chose

Sur trois lots, **aucun des défauts les plus coûteux n'a été trouvé par une revue de code.** Ils l'ont été en remplaçant un appel de callback par un vrai `tester.tap()`, en livrant un glissement en incréments plutôt qu'en un bloc, et en lisant une signature au lieu de l'écrire de mémoire.

Le lot 4 touche au setup, donc à des formulaires et à des listes — moins de surface tactile, mais exactement la même règle : ce que le test ne joue pas, il ne le prouve pas.
