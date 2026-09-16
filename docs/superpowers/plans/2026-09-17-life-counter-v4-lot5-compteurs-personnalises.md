# Life Counter V4 — Lot 5 : Compteurs personnalisés — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Brancher `CounterType`, qui est modélisé et testé mais utilisé par rien, et rendre les compteurs créables depuis le tiroir du joueur.

**Architecture :** Aujourd'hui les compteurs sont manipulés par clés `String` codées en dur (`'poison'`, `'energy'`, `'commander_tax'`) répétées dans trois fichiers, et `GameSession.activeCounterIds` — écrit par `newGame` depuis `format.enabledCounterIds` — n'est lu par personne. Ce lot fait de `CounterType` la seule source de vérité : le tiroir rend les compteurs actifs de la session au lieu d'une liste figée, chaque compteur porte sa propre borne, la poignée conditionnelle résume n'importe quel compteur, et l'utilisateur peut en créer.

**Tech Stack :** Flutter 3.9.2, `flutter_riverpod` ^3.0.3, `shared_preferences` (persistance des types personnalisés, sur le modèle de `ProfileService`).

**Spec :** `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` — §3.5 (compteurs personnalisés), §2.2 (poignée conditionnelle), §2.7 (contenu du tiroir), §4 (lot 5).

**Base :** `main` à `309cff1` (lot 6 reverté, moitié socle du lot 4 mergée).

**Ce lot est indépendant de la disposition.** Il ne touche ni `AdaptiveGrid`, ni le placement des zones, ni la vue table. C'est la raison pour laquelle il peut avancer pendant que la disposition de table et le setup inline sont redessinés sur maquette.

---

## Global Constraints

1. **`git add` avec chemins explicites uniquement.** Jamais `git add -A`, jamais `git commit -a`. Le dépôt est partagé entre sessions.
2. **Les gestes se jouent, ils ne se simulent pas.** `tester.tap(...)`, jamais un appel direct au callback.
3. **Cible par clé quand tu testes un comportement ; cible par géométrie seulement quand la propriété testée EST la disposition.** Les deux erreurs symétriques ont produit des tests verts et mensongers sur ce projet.
4. **Pour chaque test, demande-toi quelle implémentation fautive le laisserait vert.** Trois exemples réels, tous rencontrés sur les lots précédents :
   - un test du bouton « − » vérifiait le *nombre* d'éléments, alors que le bug retirait le *mauvais* ;
   - un test d'assignation aurait pu vérifier « une valeur est apparue » alors que le bug l'écrivait au mauvais endroit ;
   - un test de non-recouvrement de taps était vert parce que les deux widgets **ne se recouvraient pas** à la taille d'écran du test.
   Ici le piège équivalent : un test qui vérifie « le compteur affiche 3 » reste vert si le delta a été appliqué au **mauvais compteur** ou au **mauvais joueur**. Utilise des compteurs et des joueurs distincts, et vérifie lequel a bougé **et que les autres n'ont pas bougé**.
5. **Une fixture qui ne contient qu'une valeur par défaut ne prouve rien sur les autres valeurs.** Un test de bornes qui n'utilise que des compteurs sans `maxValue` ne teste pas les bornes.
6. **Tout test de non-régression doit être vérifié discriminant** : casse temporairement le code qu'il protège, vérifie qu'il échoue — et de préférence qu'il échoue **seul** —, rétablis. Dis-le dans le rapport.
7. **Un test qui dépend d'une mise en scène doit échouer quand la mise en scène cesse d'être valable.** Patron acquis au lot 4 : si un test a besoin que deux éléments se recouvrent, il affirme le recouvrement **avant** d'agir, pour ne jamais redevenir silencieusement vide.
8. **`flutter test` EN ENTIER et `flutter analyze` à la fin de chaque tâche**, pas seulement les fichiers touchés. Une tâche du lot 4 a cassé un test hors de son périmètre (un faux de test qui implémentait une interface élargie) sans que personne le voie, parce que les exécutions étaient partielles. État de départ : **951 tests verts, 0 erreur, 0 warning**.
9. **Aucun nouveau geste global** sans validation explicite.
10. **Les tests de widgets se décrivent par leurs assertions dans ce plan, jamais en code verbatim.** Le code de test écrit de mémoire a produit six défauts de compilation sur les lots 1 et 2 ; les lots 3 et 4, passés aux intentions décrites, n'en ont eu aucun.
11. **Ce lot ne déplace pas de pixels dans la table.** S'il s'avérait qu'une tâche change la disposition d'une zone joueur, elle sort du périmètre et attend la maquette — voir « Hors périmètre ».

---

## Ce que le code fait aujourd'hui (vérifié, pas supposé)

- `lib/models/counter_type.dart` — `CounterType` porte `id`, `name`, `emoji`, `color`, `isBuiltIn`, `maxValue` (nullable), plus `builtInCounters` : `poison` (maxValue 10), `energy`, `commander_tax`, `commander_damage`. **Aucun fichier de `lib/` ne l'importe.**
- `GameSession.activeCounterIds` est renseigné par `newGame` à partir de `format.enabledCounterIds` (`game_session.dart:157`), sérialisé, désérialisé — **et lu par personne**.
- `player_drawer.dart:15-25` code en dur `_counterLabels` et `_counterIcons` pour trois compteurs, et `:170` itère sur `_counterLabels.keys`.
- `life_counter_page.dart:1103-1107` construit la map passée au tiroir avec trois clés littérales.
- `conditional_handle.dart:13-32` — `CounterSummary` a quatre champs nommés fixes ; `isCalm` est leur conjonction. Un compteur personnalisé ne peut donc jamais apparaître sur la poignée.
- `game_session_notifier.dart:53-66` — `updateCounter` clampe à `0..99` en dur, **sans consulter `CounterType.maxValue`**.
- `PlayerState.counters` est un `Map<String, int>` libre : le modèle de données accepte déjà n'importe quelle clé.

**Conséquence visible aujourd'hui, et c'est un vrai défaut, pas une gêne théorique :** le preset Standard déclare `enabledCounterIds: ['poison', 'energy']` (`game_format.dart:128`), mais le tiroir affiche quand même « Taxe de commandant », parce qu'il ne lit jamais cette liste. La tâche 2 le corrige au passage.

---

## Décisions déjà arbitrées (ne pas rouvrir)

**D-1 — Les types personnalisés persistent globalement, pas par partie.**
Un compteur qu'on a créé une fois doit être proposé aux parties suivantes ; le recréer à chaque partie serait exactement la « gestion de presets » que §2.8 a écartée pour les tables. Persistance via `shared_preferences`, sur le modèle exact de `ProfileService`. `GameSession.customCounterIds` reste ce qu'il est : la liste des ids **actifs dans cette partie**, pas le catalogue.

**D-2 — Le tiroir affiche les compteurs actifs de la session, pas le catalogue complet.**
Sinon un joueur de Standard verrait la taxe de commandant. La source est `session.activeCounterIds`, résolue en `CounterType` via le catalogue (intégrés + personnalisés).

**D-3 — L'historique de partie ne reçoit pas les compteurs personnalisés dans ce lot.**
`PlayerHistorySnapshot` a des champs fixes `poison` / `energy` / `commanderTax` (`game_history_model.dart:85-108`). Les rendre génériques est une migration de modèle persisté, avec son propre risque, et §3.5 ne le demande pas. Les compteurs personnalisés vivent donc dans la partie et ne sont pas archivés.
*Coût si ce ruling est mauvais :* une statistique sur un compteur personnalisé est impossible tant que ce n'est pas fait. Aucune donnée n'est perdue en cours de partie ; seule l'archive est incomplète. Réversible par une migration ultérieure.

**D-4 — L'icône d'un compteur est un emoji, pas une `IconData`.**
`CounterType.emoji` existe déjà ; `IconData` ne se sérialise pas proprement et obligerait à un sélecteur d'icônes. Le tiroir passe donc à un rendu emoji pour **tous** les compteurs, y compris les intégrés — c'est ce qui permet à un compteur créé par l'utilisateur d'avoir une icône sans écran supplémentaire. La poignée conditionnelle utilise déjà des puces emoji (`conditional_handle.dart:74`), donc les deux surfaces deviennent cohérentes.

---

## File Structure

**Créés**
- `lib/services/counter_type_service.dart` — `CounterTypeService` : `loadCustomTypes()`, `saveCustomType(CounterType)`, `deleteCustomType(String id)`. Clé `shared_preferences` `'custom_counter_types'`. Calqué sur `ProfileService`.
- `lib/providers/counter_catalog_provider.dart` — expose le catalogue résolu (intégrés + personnalisés) et un `CounterType?` par id.
- `lib/widgets/life_counter/zone/counter_editor_dialog.dart` — création d'un compteur : nom, emoji, couleur, borne optionnelle.

**Modifiés**
- `lib/widgets/life_counter/zone/player_drawer.dart` — rend les compteurs actifs depuis le catalogue ; `_counterLabels` et `_counterIcons` disparaissent ; bouton « Nouveau compteur ».
- `lib/pages/life_counter/life_counter_page.dart` — ne construit plus une map à trois clés littérales ; passe les compteurs actifs.
- `lib/widgets/life_counter/zone/conditional_handle.dart` — `CounterSummary` devient générique.
- `lib/widgets/life_counter/player_zone.dart` — construit le résumé générique.
- `lib/providers/game_session_notifier.dart` — `updateCounter` respecte `maxValue` ; ajout/retrait d'un compteur actif.
- `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md` — §3.5 amendée (tâche 5).

**Tests**
- `test/services/counter_type_service_test.dart`
- `test/providers/counter_catalog_provider_test.dart`
- `test/widgets/life_counter/zone/player_drawer_test.dart` (étendu)
- `test/widgets/life_counter/zone/conditional_handle_test.dart` (étendu)
- `test/providers/game_session_notifier_test.dart` (étendu)
- `test/pages/life_counter/custom_counters_integration_test.dart` (créé)

---

## Ordre et dépendances

1 → 2 → 3 → 4 → 5. La tâche 3 ne dépend que de la tâche 1 et peut être avancée si la tâche 2 bloque.

---

### Task 1 : Catalogue de compteurs — service et provider

**Files :**
- Create: `lib/services/counter_type_service.dart`, `lib/providers/counter_catalog_provider.dart`
- Test: `test/services/counter_type_service_test.dart`, `test/providers/counter_catalog_provider_test.dart`

**Interfaces :**
- Consumes : `CounterType` (`lib/models/counter_type.dart`, a déjà `toJson`/`fromJson` et `builtInCounters`) ; `SharedPreferences`.
- Produces :
  - `class CounterTypeService` — `Future<List<CounterType>> loadCustomTypes()`, `Future<void> saveCustomType(CounterType type)` (crée ou remplace par `id`), `Future<void> deleteCustomType(String id)`. Clé `'custom_counter_types'`.
  - `final counterTypeServiceProvider = Provider<CounterTypeService>(...)` dans `lib/providers/service_providers.dart` si c'est là que vivent les autres services — **va vérifier où `profileServiceProvider` est déclaré et fais pareil**.
  - `final counterCatalogProvider = FutureProvider<List<CounterType>>(...)` — `CounterType.builtInCounters` suivi des personnalisés.
  - Une fonction ou un provider résolvant un id en `CounterType?`.

**Contraintes :**
- `loadCustomTypes()` **ne lève jamais** : JSON illisible ou clé absente rendent une liste vide. Un enregistrement écrit par une version future ne doit pas empêcher l'application de démarrer. C'est la même règle que `loadLastTable()` du lot 4, pour la même raison.
- Un type personnalisé **ne peut pas usurper l'id d'un intégré**. `saveCustomType` avec `id == 'poison'` doit être refusé, pas silencieusement accepté — sinon le catalogue rend deux entrées pour le même id et le tiroir en affiche une au hasard.

- [ ] **Step 1 : Écrire les tests qui échouent.** Intentions :
  - Aller-retour `saveCustomType` → `loadCustomTypes` : `id`, `name`, `emoji`, `color`, `maxValue` conservés. **Utilise un `maxValue` non nul dans au moins un cas et nul dans un autre** — un catalogue testé uniquement avec `maxValue: null` ne prouve rien sur la tâche 3.
  - `saveCustomType` deux fois avec le même id remplace au lieu d'ajouter.
  - `deleteCustomType` retire, et retirer un id absent ne lève pas.
  - `loadCustomTypes` rend une liste vide sur clé absente, sur JSON invalide, et sur JSON valide auquel il manque un champ requis — **sans lever**.
  - `saveCustomType` avec l'id d'un intégré est refusé, et le catalogue ne contient toujours qu'une seule entrée pour cet id.
  - Le catalogue contient les quatre intégrés **plus** les personnalisés, et les intégrés arrivent en premier.
  - `SharedPreferences.setMockInitialValues({})`, comme les tests de `ProfileService` et de `GameSessionService`.
- [ ] **Step 2 :** lancer, vérifier l'échec pour la bonne raison.
- [ ] **Step 3 :** implémenter.
- [ ] **Step 4 :** `flutter test` complet + `flutter analyze`.
- [ ] **Step 5 :** commit, chemins explicites.

---

### Task 2 : Le tiroir rend les compteurs actifs de la session

**Files :**
- Modify: `lib/widgets/life_counter/zone/player_drawer.dart`, `lib/pages/life_counter/life_counter_page.dart`
- Test: `test/widgets/life_counter/zone/player_drawer_test.dart` (étendu)

**Interfaces :**
- Consumes : le catalogue de la tâche 1 ; `GameSession.activeCounterIds`.
- Produces : `showPlayerDrawer` prend désormais la **liste des `CounterType` actifs** et la map de valeurs, au lieu de s'appuyer sur ses constantes internes. `_counterLabels` et `_counterIcons` sont supprimés.

**Ce que cette tâche corrige au passage :** le preset Standard déclare `enabledCounterIds: ['poison', 'energy']`, mais le tiroir affiche aujourd'hui « Taxe de commandant » parce qu'il ne lit jamais cette liste. C'est un défaut visible en jeu, pas une dette théorique.

**Rendu :** chaque ligne affiche l'emoji du `CounterType`, son nom, sa valeur, et les boutons ±. Les cibles tactiles font au moins 48×48 — contrainte acquise au lot 4, sur un écran qu'on utilise à plusieurs autour d'une table.

- [ ] **Step 1 : tests qui échouent.** Intentions :
  - Un tiroir monté avec les compteurs actifs `['poison', 'energy']` affiche **exactement** deux lignes de compteur, et **pas** la taxe de commandant. Test de non-régression du défaut Standard ; vérifie-le discriminant.
  - Un tiroir monté avec un compteur **personnalisé** dans les actifs affiche son nom et son emoji.
  - **Le test qui compte le plus :** taper « + » sur la ligne du **deuxième** compteur émet `onCounterDelta` avec **l'id de ce compteur-là**, et pas celui du premier. Cible par clé (`ValueKey('counter_row_<id>')`). Un test qui vérifie seulement « un delta a été émis » resterait vert si toutes les lignes émettaient l'id de la première — c'est exactement le motif qui a coûté une ronde au lot 4 sur le bouton « − ».
  - L'ordre d'affichage suit `activeCounterIds`, pas l'ordre du catalogue.
  - Les lignes existantes du tiroir (grille de dégâts de commandant, actions monarque / éliminer / réinitialiser) sont **inchangées** : leurs tests actuels doivent rester verts sans retouche. S'ils demandent une retouche, dis-le dans ton rapport plutôt que de les réécrire.
- [ ] **Step 2–4 :** rouge, implémentation, vert.
- [ ] **Step 5 :** `flutter test` complet + `flutter analyze`, puis commit.

---

### Task 3 : Chaque compteur porte sa propre borne et son propre résumé

**Files :**
- Modify: `lib/providers/game_session_notifier.dart`, `lib/widgets/life_counter/zone/conditional_handle.dart`, `lib/widgets/life_counter/player_zone.dart`
- Test: `test/providers/game_session_notifier_test.dart`, `test/widgets/life_counter/zone/conditional_handle_test.dart` (étendus)

Deux changements qui disent la même chose : **c'est la définition du compteur qui gouverne son comportement, plus une constante écrite ailleurs.**

**3a — `maxValue` respecté à l'écriture.** `updateCounter` (`game_session_notifier.dart:53`) clampe aujourd'hui à `0..99` en dur. Le plafond doit venir de `CounterType.maxValue` quand il existe, et rester `99` quand il vaut `null`. Le plancher reste `0`.
Le doc-comment existant explique pourquoi le clamp vit dans le notifier et non chez l'appelant — **garde ce raisonnement, il est juste** : c'est le seul chemin d'écriture, et le tiroir ne clampe que sa copie d'affichage.

**Intentions de test :** `poison` (`maxValue: 10`) sature à 10, pas à 99 ; un compteur sans `maxValue` sature toujours à 99 ; un compteur personnalisé avec `maxValue: 3` sature à 3 ; le plancher `0` tient dans les trois cas. **Le cas « sature à 99 » est le test discriminant du cas « sature à 10 »** : sans lui, remplacer le plafond par une constante 10 passerait inaperçu.

**3b — `CounterSummary` devient générique.** Aujourd'hui quatre champs nommés fixes, donc un compteur personnalisé ne peut jamais apparaître sur la poignée. Il faut une collection de paires (`CounterType`, valeur) non nulles, plus le pire dégât de commandant qui reste à part — ce n'est pas un compteur de `PlayerState.counters` mais un maximum sur `commanderDamageReceived`.

`isCalm` devient « aucune valeur non nulle et aucun dégât de commandant ». **`reservedHeight = 30.0` ne change pas** : la hauteur est réservée en permanence, calme ou non, pour que le chiffre de PV ne saute pas en cours de partie.

**Intentions de test :** une poignée avec un compteur personnalisé non nul n'est pas calme et affiche sa puce ; `isCalm` reste vrai quand tous les compteurs sont à zéro **même s'il y en a beaucoup** ; la puce du pire dégât de commandant est inchangée. Et un test de non-régression sur la hauteur réservée, **vérifié discriminant**.

> **Attention au débordement :** la poignée fait 30 px de haut et affichait au plus quatre puces. Avec des compteurs personnalisés il peut y en avoir davantage. Décide de ce qui se passe au-delà de ce qui tient — et **écris le test qui fixe ta décision**. Ne laisse pas le cas se résoudre par un débordement de `Row`. Consigne ton choix dans ton rapport.

- [ ] **Step 1 :** écrire les tests de 3a et 3b, vérifier qu'ils échouent.
- [ ] **Step 2 :** implémenter 3a, puis 3b.
- [ ] **Step 3 :** `flutter test` complet + `flutter analyze`.
- [ ] **Step 4 :** commit — un commit par sous-partie, chemins explicites.

---

### Task 4 : Créer et retirer un compteur depuis le tiroir

**Files :**
- Create: `lib/widgets/life_counter/zone/counter_editor_dialog.dart`
- Modify: `lib/widgets/life_counter/zone/player_drawer.dart`, `lib/providers/game_session_notifier.dart`
- Test: `test/widgets/life_counter/zone/player_drawer_test.dart` (étendu)

**Interfaces :**
- Produces :
  - `CounterEditorDialog` — nom, emoji, couleur, borne optionnelle. Rend un `CounterType?` (`null` si annulé).
  - Sur le notifier : de quoi ajouter un id à `activeCounterIds` **et** à `customCounterIds`, et de quoi l'en retirer.

**Décisions de conception à prendre par l'implémenteur, chacune à fixer par un test et à consigner au rapport :**
1. Retirer un compteur actif efface-t-il sa valeur chez les joueurs, ou la conserve-t-il au cas où on le réactive ? **Ma préférence : conserver** — l'effacement est destructif et irréversible en cours de partie, la conservation ne coûte que quelques octets dans le snapshot. Écris le test qui le fixe.
2. Créer un compteur l'active-t-il immédiatement dans la partie en cours ? (Probablement oui : on le crée parce qu'on en a besoin maintenant.)
3. Que fait-on d'un nom vide, d'un emoji vide, ou d'un nom déjà pris ?

**Contraintes :**
- Un compteur **intégré** ne peut pas être supprimé du catalogue. Il peut être retiré des compteurs actifs de la partie.
- La création passe par `CounterTypeService.saveCustomType` (tâche 1), qui refuse déjà d'usurper l'id d'un intégré.
- Cibles tactiles ≥ 48×48.

- [ ] **Step 1 : tests qui échouent.** Intentions :
  - Taper « Nouveau compteur », remplir, valider : le compteur apparaît dans le tiroir **avec son nom et son emoji**, et un « + » sur sa ligne émet **son** id.
  - Annuler le dialogue ne crée rien.
  - Le compteur créé est persisté : un nouveau catalogue chargé depuis le service le contient.
  - Retirer un compteur le fait disparaître du tiroir — et, selon la décision 1, sa valeur est conservée ou effacée, **prouvé par une valeur non nulle avant retrait** et pas par un compteur à zéro qui ne distinguerait pas les deux comportements.
  - Le retrait d'un intégré du catalogue est refusé.
- [ ] **Step 2–4 :** rouge, implémentation, vert.
- [ ] **Step 5 :** `flutter test` complet + `flutter analyze`, puis commit.

---

### Task 5 : Intégration bout-en-bout, et amendement de la spec

**Files :**
- Create: `test/pages/life_counter/custom_counters_integration_test.dart`
- Modify: `docs/superpowers/specs/2026-09-15-life-counter-v4-design.md`

**Intentions du test d'intégration :** depuis une partie en cours, ouvrir le tiroir d'un joueur **désigné par sa clé d'identité** (`ValueKey('player_zone_<playerId>')` — l'ordre de l'arbre n'est pas l'ordre d'affichage), créer un compteur, l'incrémenter par de vrais taps, vérifier que la puce apparaît sur la poignée de **ce joueur-là et pas d'un autre**, saturer sa borne, puis vérifier que la valeur survit à un aller-retour `toJson`/`fromJson` de la session.

Ce dernier point est celui qui manquerait le plus : un compteur personnalisé qui disparaît au rechargement après un plantage serait invisible en test unitaire.

**Utilise des `pump()` bornés, jamais `pumpAndSettle`,** dès qu'une zone est en alerte — `CriticalOverlay` boucle indéfiniment au niveau létal.

**Amendement de la spec §3.5 :** remplacer la description au futur par ce que le lot a réellement livré, et y consigner les quatre décisions arbitrées ci-dessus, en particulier **D-3** (les compteurs personnalisés ne sont pas archivés dans l'historique) qui est une limite qu'un lecteur doit pouvoir trouver sans lire ce plan.

- [ ] **Step 1 :** écrire le test, le lancer, constater les échecs réels.
- [ ] **Step 2 :** corriger ce qu'il révèle, et **rapporter chaque défaut trouvé**. Si ce test ne trouve rien, dis-le : ce serait le premier de ce projet.
- [ ] **Step 3 :** amender la spec.
- [ ] **Step 4 :** `flutter test` complet + `flutter analyze`, puis commit.

---

## Hors périmètre de ce lot

**La disposition.** Ce lot ne touche pas au placement des zones. Si une tâche s'avérait devoir changer la mise en page d'une zone joueur, elle sort du périmètre et attend la maquette en cours d'arbitrage — le lot 6 a été reverté pour avoir traité une refonte visuelle comme un problème de correction, avec 1028 tests verts et aucun pixel regardé.

**L'archivage des compteurs personnalisés** (D-3) : `PlayerHistorySnapshot` garde ses champs fixes.

**La découpe de `life_counter_page.dart`.** Toujours pas faite, toujours assignée à aucun lot par §4, et le fichier dépasse 1680 lignes. Reste le lot 7 proposé.

---

## Dettes reportées qui ne doivent pas se perdre

Ces constats viennent du lot 4 et vivent aujourd'hui dans un journal SDD **git-ignoré**. Ils sont recopiés ici pour survivre.

- **P-1 — l'édition et la suppression de profil ne sont câblées nulle part.** `GameSetupNotifier.updateProfile` n'a aucun appelant dans `lib/`. Dans `GameSetupModal`, on éditait un profil par appui long (`game_setup_modal.dart:273`). **Toute suppression future de cette modale doit d'abord inventorier ses capacités et vérifier que chacune a atterri ailleurs**, sinon l'utilisateur perd l'édition de profil sans qu'aucun test ne le signale — on ne teste pas un flux qui n'existe plus.
- **Le toggle « Timer de partie »** (spec §3.2, reporté depuis le lot 1) n'est toujours pas câblé. `GameSetupState.timerEnabled` et `LastTable.timerEnabled` existent et l'attendent.
- **La route vers `StatsTab`** (spec §3.3, « reçoit enfin une route ») n'existe toujours pas. 308 lignes de page et 267 lignes de tests sans point d'entrée.
- **`_migrateLegacyOrder` reste une heuristique de forme** dans `GameSession.fromJson`. Le marqueur de version qui devait la remplacer (`rotationsMigrated`) est parti avec le revert du lot 6 ; il est récupérable sur `lot6-archive`.
- **D-1 du lot 4 reste valide :** on ne migre pas les anciens snapshots Standard portant `maxCommanderDamage: 21`. Un 21 réglé à la main est indistinguable d'un 21 hérité de l'ancien preset.

---

## Critères de sortie du lot

- `flutter test` vert dans son intégralité, `flutter analyze` sans erreur ni avertissement.
- `CounterType` est importé et utilisé par du code de `lib/`, et plus aucune map de compteurs codée en dur ne subsiste dans `player_drawer.dart` ni `life_counter_page.dart`.
- Une partie Standard n'affiche plus la taxe de commandant.
- Un compteur créé survit à la fermeture de l'application et à un rechargement de session.
- Le test d'intégration bout-en-bout passe.
