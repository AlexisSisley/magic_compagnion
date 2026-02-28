# SPRINT 2 - State Management Riverpod
## Analyse Business & Plan d'Execution - Zorro (Analyste Mugiwara)
**Date** : 26/02/2026
**Sprint** : S2 - State Management Riverpod
**Duree estimee** : 8.5 jours-dev
**Score qualite actuel** : 6.5/10 (post-Sprint 1)
**Score qualite cible** : 7.5/10

---

## 0. SYNTHESE EXECUTIVE

Le Sprint 2 est le plus risque de la roadmap. On migre l'integalite du data layer d'un modele procedural (instanciations manuelles, SharedPreferences directes) vers un systeme reactif centralise (Riverpod). C'est une operation a coeur ouvert : chaque service touche est un risque de regression sur les fonctionnalites utilisateur. La strategie progressive fichier par fichier est la seule approche raisonnable.

**Metriques cles identifiees dans la codebase** :
- **42 instanciations manuelles** de services reparties dans 21 fichiers (pages + widgets)
- **27 appels SharedPreferences.getInstance()** dans 13 fichiers (8 services + 5 pages)
- **13 services** au total, dont 2 singletons manuels (LocalCardService, OracleService)
- **0 Provider defini** malgre le ProviderScope en place dans main.dart
- **0 ConsumerWidget** dans toute la codebase

---

## 1. INVENTAIRE DETAILLE DE LA CODEBASE

### 1.1 Services et leur pattern actuel

| Service | Singleton ? | SharedPreferences | Instanciations | Fichiers consommateurs |
|---------|:-----------:|:-----------------:|:--------------:|:----------------------|
| CollectionService | Non | 4 appels | 6x | collection_page, card_search_page, card_detail_page, scan_history_page, deck_card_picker, set_list_page |
| DeckService | Non | 2 appels | 4x | deck_list_page, deck_detail_page, collection_page, card_detail_page |
| WishlistService | Non | 2 appels | 5x | collection_page, card_search_page, card_detail_page, deck_detail_page, wishlist_detail_page, collection_sets_tab |
| ProfileService | Non | 2 appels | 3x | profile_management_page, game_setup_modal, tournament_page |
| GameHistoryService | Non | 3 appels | 2x | life_counter_page, game_history_page |
| ScanHistoryService | Non | 3 appels | 2x | card_detail_page, scan_history_page |
| LocalCardService | Oui (factory) | 0 | 8x | scanner_page, card_search_page, card_detail_page, deck_list_page, deck_suggestions_tab, deck_card_picker, collection_page, player_zone, quick_add_view, collection_sets_tab, set_list_page |
| OracleService | Oui (factory) | 0 | 1x | magic_oracle_page |
| BackupService | Non | 2 appels | 2x | main.dart (AppShell), settings_page |
| GoogleDriveService | Non | 0 | 1x | main.dart (AppShell) |
| EdhrecService | Non | 0 | 1x | deck_suggestions_tab |
| SetService | Non | 0 | 2x | collection_sets_tab, set_list_page |
| ScryfallApi | Statique | 0 | N/A | Utilise en constantes, pas instancie |

### 1.2 Acces SharedPreferences directs dans les pages (hors services)

| Fichier | Nombre d'appels | Usage |
|---------|:--------------:|-------|
| life_counter_page.dart | 2 | Sauvegarde/chargement etat joueurs (playerCount, startingLife, player_*) |
| tournament_page.dart | 2 | Sauvegarde/chargement etat tournoi |
| card_search_page.dart | 1 | Lecture glossaryLang pour la langue API |
| card_detail_page.dart | 1 | Lecture glossaryLang |
| glossary_page.dart | 2 | Lecture/ecriture glossaryLang |

### 1.3 Problemes structurels identifies

**P1 - Pas de singleton = pas de cache partagee** :
Quand `CollectionPage` instancie `CollectionService()` et que `CardSearchPage` instancie son propre `CollectionService()`, chaque instance recharge independamment depuis SharedPreferences. Cela signifie :
- Aucune reactivite cross-pages (modifier la collection sur une page ne met pas a jour les autres)
- Gaspillage de I/O (JSON decode a chaque `loadCollection()`)
- Race conditions potentielles si deux services ecrivent en parallele

**P2 - LocalCardService est un singleton mais recharge partout** :
8 fichiers appellent `_localCardService.loadLocalData()` dans leur `initState`. Le garde `_isLoaded` empeche le double-chargement effectif, mais le pattern est fragile et verbose.

**P3 - SharedPreferences inline dans les pages** :
`life_counter_page.dart` fait 30+ appels `prefs.setInt/getString` directement. Ce pattern melange logique de persistence et logique d'affichage, rendant le code intestable.

---

## 2. USER STORIES DETAILLEES

### US-2.1 : Creer les Providers Riverpod pour les services core
**Tache roadmap** : #1 - Architecture, 2j, P1

**En tant que** developpeur,
**je veux** un fichier `lib/providers/` contenant les providers pour chaque service,
**afin de** pouvoir injecter les services via le widget tree Riverpod au lieu de les instancier manuellement.

**Criteres d'acceptation** :
- [ ] Repertoire `lib/providers/` cree avec les fichiers suivants :
  - `service_providers.dart` : Providers simples (stateless) pour les services utilitaires
  - `collection_provider.dart` : AsyncNotifierProvider pour CollectionService
  - `deck_provider.dart` : AsyncNotifierProvider pour DeckService
  - `wishlist_provider.dart` : AsyncNotifierProvider pour WishlistService
  - `profile_provider.dart` : AsyncNotifierProvider pour ProfileService
  - `game_history_provider.dart` : AsyncNotifierProvider pour GameHistoryService
  - `local_card_provider.dart` : Provider global pour LocalCardService
- [ ] Chaque Provider a un typage strict (pas de `dynamic`)
- [ ] Un barrel file `lib/providers/providers.dart` exporte tout
- [ ] Les services stateless (EdhrecService, SetService, BackupService, GoogleDriveService, ScanHistoryService, OracleService) utilisent des `Provider<T>` simples
- [ ] Le pattern singleton manuel de LocalCardService et OracleService est remplace par le singleton naturel Riverpod
- [ ] Aucune regression : l'app compile et fonctionne identiquement

**Notes techniques** :
```dart
// Exemple de structure attendue pour service_providers.dart
final edhrecServiceProvider = Provider<EdhrecService>((ref) => EdhrecService());
final setServiceProvider = Provider<SetService>((ref) => SetService());
final oracleServiceProvider = Provider<OracleService>((ref) => OracleService());
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());
final googleDriveServiceProvider = Provider<GoogleDriveService>((ref) => GoogleDriveService());
final scanHistoryServiceProvider = Provider<ScanHistoryService>((ref) => ScanHistoryService());
```

---

### US-2.2 : Migrer CollectionService vers AsyncNotifierProvider
**Tache roadmap** : #2 - Migration, 1j, P1

**En tant que** utilisateur,
**je veux** que ma collection soit reactive et partagee entre toutes les pages,
**afin que** l'ajout d'une carte depuis la recherche mette a jour immediatement la page Collection sans rechargement manuel.

**Criteres d'acceptation** :
- [ ] `CollectionNotifier` extends `AsyncNotifier<List<DeckCard>>`
- [ ] Le `build()` charge la collection depuis SharedPreferences (remplace `loadCollection()`)
- [ ] Chaque methode mutative (`upsertCardInCollection`, `clearCollection`, `importBatchCards`) met a jour le state via `state = AsyncValue.data(...)` apres persistence
- [ ] `recordDailyValue` et `getEvolutionSince` restent des methodes utilitaires sur le notifier
- [ ] `getAllUniqueTags` derive du state courant (plus besoin de re-lire SharedPreferences)
- [ ] Les 6 consommateurs actuels continuent de fonctionner
- [ ] L'ajout depuis `card_detail_page` se reflete dans `collection_page` sans navigation retour

**Risques specifiques** :
- `importBatchCards` fait des appels HTTP chunkes -- la methode doit notifier le state une seule fois a la fin, pas a chaque chunk
- `_upsertInMemory` est un helper prive qui modifie en place : le state Riverpod est immutable, donc il faut cloner la liste avant mutation

---

### US-2.3 : Migrer DeckService vers AsyncNotifierProvider
**Tache roadmap** : #3 - Migration, 1j, P1

**En tant que** utilisateur,
**je veux** que mes decks soient reactifs et partages,
**afin que** la creation d'un deck depuis la collection mette a jour la liste des decks sans rechargement.

**Criteres d'acceptation** :
- [ ] `DeckNotifier` extends `AsyncNotifier<List<Deck>>`
- [ ] Le `build()` charge les decks depuis SharedPreferences
- [ ] `createNewDeck`, `deleteDeck`, `updateDeck` mettent a jour le state reactif
- [ ] `upsertCardInDeck` retourne le deck modifie ET met a jour le state global
- [ ] `changeCardVersion`, `moveCard`, `setCommander`, `unsetCommander`, `clearDeck` sont migrés
- [ ] Les 4 consommateurs (deck_list_page, deck_detail_page, collection_page, card_detail_page) fonctionnent
- [ ] La suppression d'un deck sur `deck_list_page` est immediatement visible (pas de double `_loadDecks()`)
- [ ] L'import de deck (texte) met a jour la liste en temps reel

**Risques specifiques** :
- `deck_detail_page` manipule un `_currentDeck` local qui est un objet mutable. Apres migration, il faut soit le deriver du provider global (watch), soit garder un state local synchronise.
- `upsertCardInDeck` ecrit puis relit les decks : en mode Riverpod, on modifie l'etat en memoire directement et on persiste en arriere-plan.

---

### US-2.4 : Migrer WishlistService, ProfileService, GameHistoryService
**Tache roadmap** : #4 - Migration, 1.5j, P1

**En tant que** utilisateur,
**je veux** que mes wishlists, profils et historique de parties soient reactifs,
**afin que** toutes les pages qui les utilisent soient toujours a jour.

**Criteres d'acceptation** :

**WishlistService** :
- [ ] `WishlistNotifier` extends `AsyncNotifier<List<Wishlist>>`
- [ ] La migration legacy (`_migrateLegacyData`) est geree dans le `build()`
- [ ] `createWishlist`, `deleteWishlist`, `renameWishlist`, `upsertCard`, `clearWishlistCards`, `setWishlistIcon` mettent a jour le state
- [ ] Les 5 consommateurs fonctionnent

**ProfileService** :
- [ ] `ProfileNotifier` extends `AsyncNotifier<List<Profile>>`
- [ ] `saveProfile`, `deleteProfile` mettent a jour le state
- [ ] Les 3 consommateurs (profile_management_page, game_setup_modal, tournament_page) fonctionnent
- [ ] La creation de profil dans game_setup_modal se reflete immediatement dans la liste

**GameHistoryService** :
- [ ] `GameHistoryNotifier` extends `AsyncNotifier<List<GameHistoryItem>>`
- [ ] `addGame`, `clearHistory` mettent a jour le state
- [ ] Les 2 consommateurs (life_counter_page, game_history_page) fonctionnent
- [ ] L'enregistrement d'une partie depuis life_counter est visible dans game_history_page sans rechargement

---

### US-2.5 : Charger LocalCardService au demarrage via Provider global
**Tache roadmap** : #5 - Optim, 0.5j, P1

**En tant que** utilisateur,
**je veux** que la base de donnees locale de cartes soit chargee une seule fois au demarrage,
**afin d'** eviter les 8 appels redondants a `loadLocalData()` et accelerer la navigation.

**Criteres d'acceptation** :
- [ ] `localCardServiceProvider` est un `FutureProvider<LocalCardService>` ou un `AsyncNotifierProvider` qui :
  - Instancie `LocalCardService()` (sans factory singleton)
  - Appelle `loadLocalData()` dans le build
  - Expose l'instance prete a l'emploi
- [ ] Le singleton factory est retire de LocalCardService
- [ ] Les 8+ fichiers qui appellent `_localCardService.loadLocalData()` dans initState ne le font plus
- [ ] L'app affiche un loading state tant que le provider n'est pas resolu
- [ ] Temps de premier affichage identique ou meilleur (pas de regression perf)

**Risques specifiques** :
- LocalCardService charge un fichier JSON de ~30MB (oracle-cards.json). Le chargement prend 2-3 secondes. Si on bloque le rendering, l'UX regresse. Il faut que le `FutureProvider` charge en background et que les pages `when()` gerent l'etat loading.
- `LocalCardService` utilise `compute()` pour le parsing : compatible avec Riverpod.

---

### US-2.6 : Refactorer les pages pour consommer les Providers
**Tache roadmap** : #6 - Migration, 2j, P1

**En tant que** developpeur,
**je veux** que toutes les pages consomment les providers Riverpod,
**afin de** beneficier de la reactivite et de l'injection de dependances.

**Criteres d'acceptation** :
- [ ] Les pages principales sont converties en `ConsumerStatefulWidget` :
  - `collection_page.dart` (4 services)
  - `deck_list_page.dart` (2 services)
  - `deck_detail_page.dart` (3 services)
  - `card_search_page.dart` (3 services)
  - `card_detail_page.dart` (5 services)
  - `life_counter_page.dart` (1 service + SharedPreferences)
  - `game_history_page.dart` (1 service)
  - `scanner_page.dart` (1 service)
  - `scan_history_page.dart` (2 services)
  - `settings_page.dart` (1 service)
  - `profile_management_page.dart` (1 service)
  - `tournament_page.dart` (1 service)
  - `magic_oracle_page.dart` (1 service)
  - `wishlist_detail_page.dart` (1 service)
- [ ] Les widgets sont convertis en `ConsumerStatefulWidget` :
  - `game_setup_modal.dart` (1 service)
  - `deck_suggestions_tab.dart` (2 services)
  - `deck_card_picker.dart` (2 services)
  - `collection_sets_tab.dart` (3 services)
  - `quick_add_view.dart` (1 service)
  - `player_zone.dart` (1 service)
  - `set_list_page.dart` (2 services)
- [ ] Chaque page utilise `ref.watch()` pour les donnees reactives et `ref.read()` pour les actions
- [ ] Les `FutureBuilder` manuels sont remplaces par `ref.watch(provider).when(...)` la ou c'est pertinent
- [ ] `MagicCompanionApp` (main.dart AppShell) convertie en `ConsumerStatefulWidget`

**Risques specifiques** :
- 21 fichiers a modifier = fort risque de regression croisee
- Les widgets qui recoivent des services en parametre (ex: `WishlistTab` recoit `wishlistService`) doivent etre refactores pour lire directement le provider

---

### US-2.7 : Retirer les instanciations manuelles de services
**Tache roadmap** : #7 - Cleanup, 0.5j, P1

**En tant que** developpeur,
**je veux** que toutes les lignes `final XxxService _xxxService = XxxService()` soient supprimees,
**afin d'** eliminer les instanciations orphelines et garantir que le DI passe exclusivement par Riverpod.

**Criteres d'acceptation** :
- [ ] 0 instanciation manuelle de service restante dans `lib/pages/` et `lib/widgets/`
- [ ] 0 instanciation de service dans `lib/main.dart` (AppShell)
- [ ] Grep `= XxxService()` retourne 0 resultat dans tout `lib/` (sauf dans les providers eux-memes)
- [ ] Les singletons manuels (`static final _instance`) sont retires de LocalCardService et OracleService
- [ ] Analyse statique passe sans warning supplementaire
- [ ] Les tests existants (s'ils existent) continuent de passer

---

## 3. RISQUES BUSINESS

### R1 - Regression UX critique (Probabilite: HAUTE, Impact: CRITIQUE)
**Description** : La migration de 42 instanciations dans 21 fichiers represente un risque majeur de regression. Un oubli dans la migration d'un `setState(() => _loadData())` en `ref.invalidate()` peut rendre une page silencieusement cassee (donnees jamais rechargees).
**Mitigation** :
- Migration fichier par fichier avec test manuel de chaque page apres conversion
- Checklist de smoke test par page (voir section 5)
- Garder les services originaux intacts jusqu'a validation complete de chaque migration

### R2 - Perte de donnees pendant la migration (Probabilite: FAIBLE, Impact: CRITIQUE)
**Description** : Les services ecrivent dans SharedPreferences. Si un bug dans le nouveau Notifier ecrase l'etat avec une liste vide avant chargement, les donnees utilisateur sont perdues.
**Mitigation** :
- Ne jamais initialiser le state avec `AsyncValue.data([])` dans le `build()` avant le chargement effectif
- Utiliser `AsyncValue.loading()` comme etat initial par defaut (behavior Riverpod natif)
- Ajouter un garde : si la collection chargee est vide ET que SharedPreferences contient une cle non-null, logger un warning

### R3 - Performance degradee au demarrage (Probabilite: MOYENNE, Impact: HAUTE)
**Description** : Si tous les AsyncNotifiers se chargent en parallele au demarrage via des `ref.watch()` eagerly, le startup peut ralentir (multiple JSON.decode en parallele).
**Mitigation** :
- Les providers doivent etre lazy (comportement Riverpod par defaut) : ils ne chargent que quand une page les watch
- Seul `localCardServiceProvider` est charge pro-activement au demarrage (car utilise partout)
- Mesurer le temps de demarrage avant/apres migration

### R4 - Complexite de deck_detail_page (Probabilite: HAUTE, Impact: MOYENNE)
**Description** : `deck_detail_page.dart` est le fichier le plus complexe (856 lignes), utilise 3 services, et manipule un objet `_currentDeck` mutable localement. La synchronisation entre le state local et le provider global Deck est delicate.
**Mitigation** :
- Option A : deck_detail_page derive son `_currentDeck` d'un `ref.watch(deckProvider).select((decks) => decks.firstWhere(...))` -- fully reactive
- Option B (recommandee) : garder un state local synchronise via `ref.listen()`, qui est moins disruptif et preserve le pattern de mutation locale
- Tester specifiquement : creation/suppression de carte, changement de version, drag-and-drop entre boards

### R5 - Breaking changes dans les widgets enfants (Probabilite: MOYENNE, Impact: MOYENNE)
**Description** : Certains widgets recoivent des services en parametre constructeur :
- `WishlistTab` recoit `wishlistService` en prop
- `_ManualSearchModal` recoit `localCardService` en prop
Si on retire ces props, il faut que le widget soit lui-meme un `ConsumerWidget` et lise le provider.
**Mitigation** :
- Phase transitoire : garder les props ET injecter via provider, puis retirer les props dans la tache #7
- Ou bien : convertir les widgets enfants en ConsumerWidget dans la meme PR que leur parent

### R6 - Race condition SharedPreferences (Probabilite: FAIBLE, Impact: HAUTE)
**Description** : Actuellement, chaque service recharge SharedPreferences a chaque operation. Avec Riverpod, l'etat est en memoire et persiste en arriere-plan. Si deux notifiers ecrivent des cles differentes en parallele, pas de probleme. Mais `BackupService` lit TOUTES les cles pour generer un backup. Si le backup se declenche pendant une ecriture, il peut lire un etat inconsistant.
**Mitigation** :
- `BackupService` devrait lire depuis les providers plutot que depuis SharedPreferences directement (mais c'est Sprint 3+)
- Pour ce sprint : laisser BackupService lire depuis SharedPreferences (les notifiers persistent toujours vers SP)

---

## 4. NON-FUNCTIONAL REQUIREMENTS (NFRs)

### NFR-1 : Retrocompatibilite des donnees
- Les cles SharedPreferences existantes (`user_collection`, `user_decks`, `user_wishlists_v2`, `user_profiles`, `game_history`, `scan_history`) ne doivent PAS changer
- La migration legacy wishlist (`_oldWishlistKey` -> `_wishlistsKey`) doit continuer a fonctionner
- Un utilisateur qui met a jour l'app ne doit perdre AUCUNE donnee

### NFR-2 : Performance
- Le temps de demarrage cold start ne doit pas augmenter de plus de 200ms
- La navigation entre pages ne doit pas montrer de latence supplementaire perceptible
- Le parsing JSON (oracle-cards.json, ~30MB) continue d'utiliser `compute()` sur un isolate
- Les operateurs `ref.watch()` ne doivent pas causer de rebuilds excessifs (utiliser `.select()` pour les listes)

### NFR-3 : UX inchangee
- Aucun changement visuel pour l'utilisateur
- Les indicateurs de chargement (CircularProgressIndicator) restent aux memes endroits
- Les SnackBars de feedback restent identiques
- Les Easter Eggs restent fonctionnels (Star Wars, Harry Potter, LOTR)

### NFR-4 : Maintenabilite
- Chaque provider dans son propre fichier (pas de fichier monstre)
- Documentation dartdoc minimale sur chaque provider public
- Naming convention : `xxxProvider` pour les Provider simples, `xxxNotifierProvider` pour les AsyncNotifierProvider
- Barrel file `providers.dart` pour faciliter les imports

### NFR-5 : Testabilite
- Les providers doivent etre overridables dans les tests (Riverpod le permet nativement)
- Les services ne doivent plus avoir de dependance cachee vers SharedPreferences (elle sera injectee via un provider si necessaire dans un sprint futur)

---

## 5. STRATEGIE DE MIGRATION : PROGRESSIVE (BOTTOM-UP)

### Pourquoi pas Big Bang ?
Un Big Bang (tout migrer d'un coup) est tente car les taches sont interdependantes. Mais avec 21 fichiers, 42 instanciations et 0 test automatise, c'est une recette pour un bug impossible a debugger. La strategie progressive permet :
- De valider chaque etape independamment
- De reverter une seule tache en cas de probleme
- De livrer incrementalement (chaque commit est deployable)

### Architecture de migration en 4 phases

```
Phase 1 : FONDATION (Taches #1 + #5)
    Creer les providers, charger LocalCardService au boot
    --> App compile, aucun consommateur ne change

Phase 2 : SERVICES CORE (Taches #2 + #3 + #4)
    Migrer les services vers AsyncNotifier, un par un
    --> Les services ont un dual-mode : ancien + nouveau

Phase 3 : CONSOMMATEURS (Tache #6)
    Refactorer les pages, une par une
    --> Chaque page bascule sur le provider

Phase 4 : NETTOYAGE (Tache #7)
    Retirer les instanciations manuelles
    --> Codebase propre, 0 instanciation manuelle
```

---

## 6. ORDRE D'EXECUTION OPTIMAL

### Phase 1 : Fondation (2.5j)

#### Etape 1.1 : Creer les providers stateless (0.5j)
**Fichiers crees** :
- `lib/providers/service_providers.dart`
- `lib/providers/providers.dart` (barrel)

**Contenu** : Providers simples pour les 6 services stateless :
```
EdhrecService, SetService, OracleService, BackupService, GoogleDriveService, ScanHistoryService
```

**Validation** : `flutter analyze` passe, app compile sans changement visible.

#### Etape 1.2 : Creer le provider LocalCardService (0.5j)
**Fichier** : `lib/providers/local_card_provider.dart`

**Pattern** :
```dart
final localCardServiceProvider = FutureProvider<LocalCardService>((ref) async {
  final service = LocalCardService(); // sans factory singleton
  await service.loadLocalData();
  return service;
});
```

**Validation** : Le provider se resout correctement. Aucune page ne le consomme encore.

#### Etape 1.3 : Creer les AsyncNotifier providers (squelettes) (1.5j)
**Fichiers** :
- `lib/providers/collection_provider.dart`
- `lib/providers/deck_provider.dart`
- `lib/providers/wishlist_provider.dart`
- `lib/providers/profile_provider.dart`
- `lib/providers/game_history_provider.dart`

**Pattern pour chaque** :
1. Creer la classe `XxxNotifier extends AsyncNotifier<List<Model>>`
2. Implementer `build()` qui appelle la methode de chargement du service
3. Implementer chaque methode publique du service comme methode du Notifier
4. Chaque methode mutative : modifie en memoire, persiste en background, met a jour state
5. Declarer le `xxxNotifierProvider`

**Validation** : Chaque provider peut etre instancie isolement. Les services originaux restent intacts.

---

### Phase 2 : Migration des consommateurs - ordre par risque croissant (2j)

L'ordre est crucial. On commence par les pages les plus simples (peu de services) pour valider le pattern, puis on attaque les complexes.

#### Vague 1 : Pages a 1 service (0.5j)
1. `settings_page.dart` -> ConsumerStatefulWidget (BackupService)
2. `magic_oracle_page.dart` -> ConsumerStatefulWidget (OracleService)
3. `game_history_page.dart` -> ConsumerStatefulWidget (GameHistoryService)
4. `profile_management_page.dart` -> ConsumerStatefulWidget (ProfileService)
5. `wishlist_detail_page.dart` -> ConsumerStatefulWidget (WishlistService)

**Smoke test** : Ouvrir chaque page, verifier le chargement, faire une action CRUD.

#### Vague 2 : Pages a 2 services (0.5j)
6. `life_counter_page.dart` -> ConsumerStatefulWidget (GameHistoryService + SharedPreferences direct)
7. `scan_history_page.dart` -> ConsumerStatefulWidget (ScanHistoryService + CollectionService)
8. `scanner_page.dart` -> ConsumerStatefulWidget (LocalCardService)
9. `deck_list_page.dart` -> ConsumerStatefulWidget (DeckService + LocalCardService)
10. `tournament_page.dart` -> ConsumerStatefulWidget (ProfileService)

**Smoke test** : Navigation, CRUD, donnees persistees.

#### Vague 3 : Pages a 3+ services (0.75j)
11. `card_search_page.dart` -> ConsumerStatefulWidget (LocalCardService + CollectionService + WishlistService)
12. `card_detail_page.dart` -> ConsumerStatefulWidget (5 services -- le plus charge)
13. `collection_page.dart` -> ConsumerStatefulWidget (4 services)
14. `deck_detail_page.dart` -> ConsumerStatefulWidget (3 services -- le plus complexe)

**Smoke test** : Test complet du cycle ajout/modif/suppression cross-pages.

#### Vague 4 : Widgets enfants (0.25j)
15. `game_setup_modal.dart` -> ConsumerStatefulWidget
16. `deck_suggestions_tab.dart` -> ConsumerStatefulWidget
17. `deck_card_picker.dart` -> ConsumerStatefulWidget
18. `collection_sets_tab.dart` -> ConsumerStatefulWidget
19. `quick_add_view.dart` -> ConsumerStatefulWidget
20. `player_zone.dart` -> ConsumerStatefulWidget
21. `set_list_page.dart` -> ConsumerStatefulWidget

**Attention** : `WishlistTab` dans `collection_page.dart` recoit `wishlistService` en constructeur. Il faut le convertir ET retirer le parametre.

---

### Phase 3 : Migration AppShell + nettoyage (0.5j)

#### Etape 3.1 : Migrer AppShell dans main.dart (0.25j)
- Convertir `AppShell` en `ConsumerStatefulWidget`
- Remplacer `GoogleDriveService()` et `BackupService()` par `ref.read()`
- Tester le cycle connexion Drive -> backup auto -> restauration

#### Etape 3.2 : Cleanup final (0.25j)
- Supprimer toutes les lignes `final XxxService _xxxService = XxxService()`
- Retirer le pattern singleton de `LocalCardService` (`static final _instance` + `factory`)
- Retirer le pattern singleton de `OracleService`
- Lancer `flutter analyze`
- Grep `= XxxService()` -> 0 resultat (sauf providers)

---

### Phase 4 : Validation integrale (0.5j)

#### Checklist de smoke test par feature

| Feature | Actions a tester | Page(s) |
|---------|-----------------|---------|
| Collection | Charger, ajouter carte, modifier quantite, toggle foil, tags, import masse, vider | collection_page, card_detail_page, card_search_page |
| Decks | Lister, creer, supprimer (swipe), ouvrir detail, ajouter carte, changer version, drag boards, import texte | deck_list_page, deck_detail_page |
| Wishlists | Charger onglet, creer wishlist, ajouter carte, renommer, supprimer, exporter depuis deck | collection_page (tab), wishlist_detail_page, card_search_page, deck_detail_page |
| Profils | Creer profil, editer, supprimer, assigner commandant, partenaire | profile_management_page, game_setup_modal |
| Life Counter | Config partie (nb joueurs, format), compteur, degats commandant, timer, fin de partie, historique | life_counter_page, game_history_page |
| Scanner | Camera, recherche manuelle, historique scans, ajout collection | scanner_page, scan_history_page |
| Recherche | Recherche locale, API, filtres, toggle collection/wishlist | card_search_page, card_detail_page |
| Backup | Export JSON, import JSON, backup Drive auto, restauration Drive | settings_page, main.dart (drawer) |
| Suggestions | Charger suggestions EDHRec, affichage enrichi | deck_suggestions_tab |
| Tournoi | Creer tournoi, jouer rounds | tournament_page |

#### Test de reactivite cross-pages (NOUVEAU -- specifique Sprint 2)
| Scenario | Resultat attendu |
|----------|-----------------|
| Ajouter carte a collection depuis card_detail, revenir sur collection_page | Carte visible sans pull-to-refresh |
| Creer un deck depuis collection_page (selection -> "Ajouter au Deck") | Deck visible dans deck_list_page |
| Ajouter carte a wishlist depuis card_search_page, aller dans collection_page onglet Wishlists | Carte visible |
| Enregistrer fin de partie sur life_counter, ouvrir historique | Partie visible |
| Creer profil depuis game_setup_modal, aller sur profile_management_page | Profil visible |
| Supprimer un deck sur deck_list_page, aller dans collection_page (qui affiche les decks) | Deck absent |

---

## 7. MATRICE DE DEPENDANCES DES TACHES

```
Tache #1 (Providers) -----> Tache #2 (CollectionService)
                     \----> Tache #3 (DeckService)
                      \---> Tache #4 (Wishlist+Profile+GameHistory)
                       \--> Tache #5 (LocalCardService)

Taches #2,#3,#4,#5 -------> Tache #6 (Refactorer pages)

Tache #6 -----------------> Tache #7 (Cleanup)
```

**Chemin critique** : #1 -> #2 -> #6 (pages Collection) -> #7
**Taches parallelisables** : #2, #3, #4, #5 peuvent etre faites en parallele (par le meme dev, juste dans des commits separes)

---

## 8. DEFINITION OF DONE DU SPRINT

- [ ] `flutter analyze` retourne 0 warning supplementaire
- [ ] `flutter build apk` reussit sans erreur
- [ ] 0 ligne `final XxxService _xxxService = XxxService()` dans lib/ (hors providers/)
- [ ] 0 appel `SharedPreferences.getInstance()` dans les 5 services migres (Collection, Deck, Wishlist, Profile, GameHistory) -- les pages `life_counter_page`, `tournament_page`, `glossary_page`, `card_search_page`, `card_detail_page` peuvent garder leurs appels directs pour ce sprint (a migrer en Sprint 3)
- [ ] La reactivite cross-pages fonctionne pour les 6 scenarios decrits en section 6
- [ ] Aucune regression UX visible
- [ ] Score qualite objectif : 7.5/10

---

## 9. ESTIMATION REVISEE

| Tache | Estimation roadmap | Estimation revisee | Justification |
|-------|:-----------------:|:-----------------:|---------------|
| #1 Providers | 2j | 2.5j | 5 AsyncNotifiers avec methodes completes + barrel + LocalCard provider |
| #2 CollectionService | 1j | 0.75j | Service bien structure, pattern clair |
| #3 DeckService | 1j | 1j | Service plus complexe (9 methodes publiques, mutations imbriquees) |
| #4 Wishlist+Profile+GameHistory | 1.5j | 1.25j | 3 services simples, pattern repetitif une fois #2 valide |
| #5 LocalCardService | 0.5j | 0.5j | Principalement un FutureProvider |
| #6 Refactorer pages | 2j | 2.5j | 21 fichiers. deck_detail_page seul peut prendre 0.5j |
| #7 Cleanup | 0.5j | 0.25j | Mecanique une fois #6 fait |
| **TOTAL** | **8.5j** | **8.75j** | Delta minimal, estimation initiale realiste |

**Note** : Les taches #2, #3, #4 sont fusionnables avec #1 car creer le provider sans le tester est futile. En pratique, la Phase 1 (fondation) inclut deja la migration des services. L'estimation revisee le reflete.

---

## 10. CRITERES DE ROLLBACK

Si a n'importe quel moment pendant le sprint :
1. **Une perte de donnees** est detectee --> Rollback immediat au dernier commit stable
2. **Plus de 3 regressions UX** sont detectees sur une seule tache --> Pause, investigation, potentiel re-design du provider concerne
3. **Le temps de demarrage** depasse +500ms --> Optimiser le loading strategy avant de continuer

---

*Rapport genere par Zorro, analyste business de l'equipage Mugiwara.*
*Methodologie : Lecture complete de la codebase (13 services, 25 pages, 21 widgets), grep exhaustif des patterns d'instanciation et SharedPreferences, analyse des dependances croisees entre fichiers.*
