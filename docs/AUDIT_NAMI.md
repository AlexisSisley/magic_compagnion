# Audit Qualite - Magic Companion

> Genere le 26/02/2026 par Nami (Agent QA / Audit)
> Mis a jour le 26/02/2026 -- Audit approfondi avec analyse de code source

---

## 1. Resume Executif

**Score global : 5.5/10**

| Dimension         | Score | Poids | Detail                                                        |
|-------------------|-------|-------|---------------------------------------------------------------|
| Architecture      | 4/10  | 25%   | Riverpod fantome, SharedPrefs comme BDD, pas de DI            |
| Qualite de code   | 5/10  | 25%   | Anti-patterns, God Files, zero tests, print() partout         |
| Securite          | 7/10  | 15%   | Scope Drive minimal, secrets bien geres, donnees non chiffrees|
| Performance       | 6/10  | 15%   | Isolate pour search local, mais serialisation O(n) partout    |
| UX / Accessibilite| 6/10  | 10%   | Fonctionnellement riche, pas de mode offline, pas d'i18n      |
| DevOps            | 6/10  | 10%   | CI/CD existant mais incomplet, dependency overrides           |

**Metriques cles du projet** :
- **74 fichiers Dart** dans `lib/`
- **19 675 lignes de code** Dart total
- **12 services**, **10 modeles**, **19 pages**, **15+ widgets**
- **1 seul test** (qui ne compile pas)
- **17 appels print()** au lieu de logger
- **66 usages de firstWhere** (dont ~15 avec catch comme flow control)
- **152 appels Navigator.push/pop** (navigation imperative)
- **27 acces SharedPreferences** repartis dans 12 fichiers
- **125 valeurs de couleur hardcodees** (Color(0xFF...))
- **313 appels GoogleFonts.cinzel** (non centralise)

---

## 2. Architecture & Design Patterns

### 2.1 Constats Positifs

| Point fort                           | Detail                                                              |
|--------------------------------------|---------------------------------------------------------------------|
| Separation Models/Services/Pages     | Le projet suit une organisation claire par couche                   |
| Widgets reutilisables                | Bonne extraction des composants (ScryfallImage, PlayerZone, etc.)   |
| Singleton LocalCardService           | Cache en memoire + Isolate pour la recherche = performant           |
| Migration automatique Wishlist       | Passage du format legacy au multi-wishlists bien gere               |
| ScryfallApi centralise               | URLs et helpers regroupes dans une classe utilitaire dediee         |
| ProviderScope present                | L'infrastructure Riverpod est en place dans main.dart               |

### 2.2 Problemes Identifies

#### P1 - CRITIQUE : Riverpod declare mais non utilise

**Fichier** : `lib/main.dart` (ligne 46 : `ProviderScope`)
**Constat** : Flutter Riverpod (`^3.0.3`) est declare en dependance et `ProviderScope` wrape l'app, mais **aucun Provider n'est defini dans le projet**. Tous les services sont instancies manuellement dans chaque page/widget.

**Fichiers utilisant Riverpod** (12 fichiers importent le package, mais aucun ne definit de Provider) :
- Les imports sont presents dans `main.dart`, `deck_detail_page.dart`, `scanner_page.dart`, `collection_page.dart`, etc.
- Mais on retrouve partout : `final DeckService _deckService = DeckService();`

**Impact** :
- Pas de reactivite sur les donnees partagees (collection, decks, profils)
- Chaque page recharge les donnees independamment depuis SharedPreferences
- Pas de cache cross-pages (une modification dans un ecran n'est pas refletee dans un autre)
- Dependance inutile qui alourdit le bundle

**Recommandation** : Migrer les services vers des Providers Riverpod (AsyncNotifierProvider) pour centraliser l'etat.

---

#### P2 - CRITIQUE : SharedPreferences comme base de donnees

**Fichiers concernes** (12 fichiers, 27 acces) :
- `collection_service.dart` : 4 acces (collection + historique de valeur)
- `deck_service.dart` : 2 acces
- `wishlist_service.dart` : 3 acces
- `game_history_service.dart` : 3 acces
- `profile_service.dart` : 2 acces
- `scan_history_service.dart` : 3 acces
- `backup_service.dart` : 2 acces
- `card_search_page.dart` : 1 acces (preferences langue)
- `card_detail_page.dart` : 1 acces
- `glossary_page.dart` : 2 acces
- `tournament_page.dart` : 2 acces
- `life_counter_page.dart` : 2 acces

**Pattern type (collection_service.dart lignes 13-25)** :
```dart
Future<List<DeckCard>> loadCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final String? collectionJson = prefs.getString(_collectionKey);
    if (collectionJson == null) return [];
    final List<dynamic> decodedList = json.decode(collectionJson) as List;
    return decodedList.map((jsonItem) => DeckCard.fromJson(jsonItem)).toList();
}
```

**Impact** :
- Chaque CRUD deserialise TOUTE la collection, modifie, puis re-serialise tout
- Pas de requetes indexees (recherche en O(n) sur la collection entiere)
- Risque de corruption si crash pendant ecriture (pas de transactions)
- Limite de taille (~1MB sur certains Android)
- CollectionService charge tout pour modifier 1 carte

**Recommandation** : Migrer vers `drift` (SQLite type-safe) ou `isar` (NoSQL rapide).

---

#### P3 - MAJEUR : Pas d'injection de dependances

**Constat** : Les services sont instancies directement dans les widgets :
```dart
// deck_detail_page.dart ligne 39-41
final DeckService _deckService = DeckService();
final CollectionService _collectionService = CollectionService();
final WishlistService _wishlistService = WishlistService();
```

**Prevalence** : Ce pattern est reproduit dans quasi toutes les pages :
- `card_search_page.dart` : instancie CollectionService + WishlistService
- `deck_list_page.dart` : instancie DeckService
- `collection_page.dart` : instancie CollectionService + WishlistService
- `main.dart` : instancie GoogleDriveService + BackupService

**Impact** :
- Impossible de mocker les services pour les tests unitaires
- Couplage fort entre UI et services
- Services recrees a chaque instanciation de page (sauf les singletons)

**Recommandation** : Utiliser Riverpod comme conteneur d'injection.

---

#### P4 - MAJEUR : Anti-pattern firstWhere/catch

**Fichiers concernes** :
- `collection_service.dart` (ligne 46)
- `deck_service.dart` (ligne 79)
- `wishlist_service.dart` (ligne 127)
- `deck_detail_page.dart` (lignes 148, 165-168, 306-312, 751-754)
- Nombreux autres fichiers (66 occurrences de firstWhere au total)

**Pattern recurrent** :
```dart
// collection_service.dart lignes 46-76
try {
  final existingCard = collection.firstWhere(
    (c) => c.scryfallId == scryfallId && c.isFoil == isFoil
  );
  // mise a jour...
} catch (e) {
  // creation... (catch traite StateError comme "pas trouve")
}
```

**Impact** :
- Exceptions utilisees comme flow control (cout performance, lisibilite degradee)
- Le catch generique masque des erreurs reelles (NullPointerException, etc.)
- 37 catch generiques identifies dans le projet

**Recommandation** :
```dart
final index = collection.indexWhere((c) => c.scryfallId == scryfallId && c.isFoil == isFoil);
if (index != -1) {
  // mise a jour...
} else {
  // creation...
}
```

---

#### P5 - MAJEUR : Navigation imperative sans routeur

**Constat** : 152 appels `Navigator.push/pop/pushReplacement` repartis dans 30 fichiers.

**Exemples (main.dart)** :
```dart
// Ligne 389 - Navigation vers l'historique
Navigator.push(context, MaterialPageRoute(builder: (context) => const GameHistoryPage()));
// Ligne 397 - Navigation vers les tournois
Navigator.push(context, MaterialPageRoute(builder: (context) => TournamentPage()));
// Ligne 407 - Navigation vers l'oracle
Navigator.push(context, MaterialPageRoute(builder: (context) => const MagicOraclePage()));
```

**Fichiers les plus concernes** :
- `main.dart` : 23 appels Navigator
- `card_detail_page.dart` : 11 appels
- `deck_card_list_tab.dart` : 10 appels
- `deck_list_page.dart` : 9 appels
- `wishlist_tab.dart` : 9 appels
- `game_setup_modal.dart` : 9 appels

**Impact** :
- Pas de deep linking possible
- Navigation non testable
- Code duplique (meme pattern `MaterialPageRoute` partout)
- Pas de transition unifiee

**Recommandation** : Adopter `go_router` pour la navigation declarative.

---

#### P6 - MODERE : Services non-singleton (sauf 2)

**Singletons actuels** :
- `LocalCardService` : `factory LocalCardService() => _instance;` (correct)
- `OracleService` : `factory OracleService() => _instance;` (correct)

**Non-singletons** (recrees a chaque usage) :
- `CollectionService`, `DeckService`, `WishlistService`
- `BackupService`, `GoogleDriveService`
- `ProfileService`, `GameHistoryService`, `ScanHistoryService`
- `SetService`, `EdhrecService`

**Impact** :
- SharedPreferences rechargees a chaque instanciation
- Pas de cache partage entre les pages
- Incoherence dans le pattern

**Recommandation** : Unifier via Riverpod providers (singleton par defaut).

---

## 3. Qualite du Code

### C1 - CRITIQUE : Tests inexistants

**Fichier** : `test/widget_test.dart`
**Constat** : Le seul fichier de test reference `MyApp()` (ligne 16) -- une classe qui n'existe plus (renommee `MagicCompanionApp`). Le test ne compile pas.

```dart
// test/widget_test.dart ligne 16
await tester.pumpWidget(const MyApp()); // ERREUR : MyApp n'existe pas
```

**Couverture** : **0%** (0 test valide sur 19 675 lignes de code)

**Recommandation** : Priorite absolue -- ecrire des tests unitaires pour les services (CollectionService, DeckService, WishlistService).

---

### C2 - MAJEUR : Usage de print() au lieu d'un logger

**17 appels `print()` repartis dans 11 fichiers** :

| Fichier | Nb | Exemples |
|---------|-----|----------|
| `google_drive_service.dart` | 3 | `print("Erreur Google Sign In: $e")`, `print("Sauvegarde Drive mise a jour")` |
| `scanner_page.dart` | 3 | Print dans le flow de scan |
| `backup_service.dart` | 2 | `print("Erreur restauration JSON: $e")`, `print("Erreur import fichier: $e")` |
| `edhrec_service.dart` | 2 | `print("Erreur EDHRec ($slug)")`, `print("Exception EDHRec: $e")` |
| `main.dart` | 1 | `print("Debut sauvegarde automatique Drive...")` |
| `oracle_service.dart` | 1 | `print("Erreur Oracle: $e")` |
| `wishlist_service.dart` | 1 | `print("Erreur migration wishlist: $e")` |
| `set_service.dart` | 1 | |
| `card_detail_page.dart` | 1 | |
| `glossary_page.dart` | 1 | |
| `collection_page.dart` | 1 | |

**Note** : `analysis_options.yaml` a la regle `avoid_print` commentee (ligne 24).

**Impact** :
- Pas de niveaux de log (debug, info, warning, error)
- Prints visibles en production (fuite d'information potentielle)
- Pas de desactivation conditionnelle

**Recommandation** : Activer `avoid_print` dans les rules d'analyse. Utiliser `dart:developer` `log()` ou le package `logger`.

---

### C3 - MAJEUR : Duplication de code dans les services

**Pattern upsert identique dans 3 fichiers** :

| Fichier | Methode | Lignes |
|---------|---------|--------|
| `collection_service.dart` | `_upsertInMemory()` | 44-77 |
| `deck_service.dart` | `upsertCardInDeck()` | 57-108 |
| `wishlist_service.dart` | `upsertCard()` | 107-157 |

Les 3 methodes suivent exactement le meme schema :
1. `try { firstWhere() -> mise a jour quantite }`
2. `catch { creation nouvelle carte }`
3. Gestion des tags, isFoil, quantite

**Impact** :
- Bugfix a faire 3 fois
- Risque de divergence (la version deck gere les boards, la collection non)

**Recommandation** : Extraire un mixin `CardListOperationsMixin` avec une methode generique `upsertCard<T>`.

---

### C4 - MODERE : Constantes dupliquees et hardcodees

**Couleurs hardcodees** : 125 occurrences de `Color(0xFF...)` reparties dans 44 fichiers.
- `Color(0xFF1A1A1A)` est le background principal, repete dans quasi chaque fichier
- `Colors.yellow.shade800` utilise comme accent partout

**GoogleFonts** : 313 appels `GoogleFonts.cinzel` repartis dans 47 fichiers, sans centralisation.

**Recommandation** : Creer `lib/theme/app_theme.dart` avec un ThemeData complet et des extensions de theme.

---

### C5 - MAJEUR : God Files (>500 lignes)

| Fichier | Lignes | Responsabilites melangees |
|---------|--------|--------------------------|
| `set_detail_page.dart` | **998** | Chargement API, filtres, tri, selection batch, ajout collection/wishlist, stats |
| `deck_detail_page.dart` | **856** | 6 onglets, chargement Scryfall, prix, partage image/texte, commandant, validation |
| `card_search_page.dart` | **838** | Recherche locale + API, pagination, filtres, wishlist selector, collection toggle |
| `deck_card_picker.dart` | **780** | Recherche, selection multiple, preview |
| `card_detail_page.dart` | **779** | Detail carte, ajout collection/wishlist/deck, rulings |
| `deck_list_page.dart` | **732** | Liste decks, CRUD, import, export, picker couleurs |
| `collection_list_tab.dart` | **715** | Liste collection, filtres, tri, tags, export |
| `player_zone.dart` | **671** | Compteurs vie/poison/commander, image picker, rotation, skin |
| `deck_stats_tab.dart` | **612** | Graphiques multiples (courbe mana, repartition type, etc.) |
| `scanner_page.dart` | **529** | Camera, ML Kit, reconnaissance, resultats |
| `collection_page.dart` | **524** | 3 onglets, chargement, calcul prix total |
| `game_setup_modal.dart` | **505** | Configuration partie, profils, couleurs, commandants |

**Impact** : 12 fichiers depassent 500 lignes. La logique metier, les appels reseau, la gestion d'etat et l'UI sont tous melanges dans le meme State.

---

### C6 - MODERE : Code mort et ignore directives

**Fichiers concernes** :
- `deck_detail_page.dart` ligne 44 : `// ignore: unused_field` sur `_isValidating`
- `card_search_page.dart` ligne 62 : `// ignore: unused_field` sur `_manaRegex`
- `test/widget_test.dart` : Reference `MyApp()` qui n'existe plus

**TODOs** : 1 seul TODO trouve dans tout le projet (`collection_page.dart`).

**Recommandation** : Supprimer le code mort. Configurer `analysis_options.yaml` pour interdire les `unused_field`.

---

## 4. Securite

### S1 - Gestion de secrets : ATTENTION

**Constat** :
- `firebase_options.dart` contient les cles API Firebase en clair (genere par FlutterFire CLI -- c'est le pattern standard)
- **ALERTE** : `keystore_base64.txt` et `upload-keystore.jks` sont presents a la racine du projet. Le `.gitignore` les exclut (`*.jks`, `keystore_base64.txt`), mais leur presence locale est un risque
- `functions/service-account.json` est present dans le dossier functions (meme si `service-account.json` est dans le `.gitignore` racine, la regle ne couvre pas le sous-dossier)
- Les secrets CI/CD sont bien stockes dans GitHub Secrets (`PLAY_STORE_UPLOAD_KEY`, `KEYSTORE_KEY_ALIAS`, etc.)

**Recommandation** : Verifier que `functions/service-account.json` n'est pas commit. Ajouter `**/service-account.json` au `.gitignore`.

### S2 - Google Drive : scope minimal

**Fichier** : `google_drive_service.dart` (ligne 9)
**Constat positif** : Le scope utilise est `driveFileScope` (acces uniquement aux fichiers crees par l'app). C'est la bonne pratique -- pas d'acces a tout le Drive.

### S3 - Donnees utilisateur non chiffrees localement

**Constat** : SharedPreferences stocke toutes les donnees en clair (collection, profils, historique de parties).
**Evaluation** : Pour une app de jeu de cartes, le risque est acceptable. Les donnees ne sont pas sensibles (pas de tokens d'authentification, pas d'infos personnelles au-dela du prenom).

### S4 - Rate limiting API

**Constat mitige** :
- `collection_service.dart` ligne 150 : `Future.delayed(Duration(milliseconds: 100))` entre les batch Scryfall -- correct
- `deck_detail_page.dart` ligne 118 : `Future.delayed(Duration(milliseconds: 50))` -- correct
- `set_detail_page.dart` ligne 102 : `Future.delayed(Duration(milliseconds: 50))` -- correct
- **Mais** : Les recherches unitaires (`card_search_page.dart`) n'ont aucun throttling
- **Aucun interceptor global** : Chaque fichier gere son propre delai

**Recommandation** : Centraliser via un interceptor Dio avec throttle global (max 10 req/sec comme demande par Scryfall).

---

## 5. Performance

### PERF1 - CRITIQUE : Serialisation complete a chaque operation

**Constat** : Chaque `upsert` dans les services :
1. Obtient `SharedPreferences.getInstance()` (appel async)
2. Lit la string JSON complete
3. Decode tout en `List<dynamic>`
4. Mappe vers les objets Dart
5. Cherche l'element (O(n))
6. Modifie
7. Re-serialise tout en JSON
8. Sauvegarde la string complete

Pour une collection de 500 cartes, chaque modification recharge et resauvegarde l'integralite.

### PERF2 - BON : Chargement de la base locale

**Constat positif** : `LocalCardService` utilise `compute()` (Isolate) pour :
- Le parsing initial du JSON (~27 000 cartes)
- La recherche avec filtres

**Constat negatif** : Le fichier `oracle-cards.json` est embarque dans les assets. Il ne se met jamais a jour sans un rebuild de l'app.

### PERF3 - MODERE : Pas de cache HTTP

**Constat** : Les appels API Scryfall (hors images) n'utilisent aucun cache.
- `card_search_page.dart` : Chaque recherche API refait un appel reseau
- `set_detail_page.dart` : Toutes les cartes d'un set sont re-telechargees a chaque visite
- `deck_detail_page.dart` : Les donnees Scryfall sont re-telechargees a chaque ouverture du deck

**Note** : Le package `dio` est declare en dependance (`^5.9.0`) mais **non utilise dans le code**. Tous les appels reseau utilisent `http` directement.

**Recommandation** : Migrer vers Dio avec `dio_cache_interceptor` pour le cache et le rate limiting.

### PERF4 - BON : Images bien gerees

**Constat positif** : `cached_network_image` est declare en dependance et un widget `ScryfallImage` centralise le chargement des images avec cache disque.

---

## 6. UX / Accessibilite

### UX1 - Pas de mode offline explicite

**Constat** : `connectivity_plus` est importe dans `card_search_page.dart` pour verifier la connectivite avant un appel API. Mais :
- Pas d'indicateur visuel de l'etat de connexion
- Pas de banner "mode offline"
- Le fallback vers la recherche locale existe mais l'utilisateur n'est pas clairement informe

### UX2 - Pas d'i18n

**Constat** : L'app est en francais avec les locales FR configurees. Toutes les chaines sont hardcodees dans le code Dart (centaines de strings). Pas de fichiers ARB.
**Evaluation** : Non bloquant si l'app reste FR uniquement.

### UX3 - Chargement initial non centralise

**Constat** : `LocalCardService.loadLocalData()` est appele dans `initState` de `CardSearchPage` (ligne 70-71) et potentiellement dans d'autres pages. Le chargement n'est pas fait au demarrage de l'app.

**Recommandation** : Charger dans `main()` ou via un Provider Riverpod au boot.

---

## 7. DevOps & Build

### DEV1 - CI/CD existant mais incomplet

**Fichiers presents** :
- `.github/workflows/build-main.yml` : Build + release GitHub + Firebase App Distribution
- `.github/workflows/release.yml`
- `.github/workflows/retro-doc.yml`

**Constat positif** : Un pipeline CI/CD existe. Il fait :
- Lint backend Python (flake8)
- Semantic versioning automatique
- Build APK release
- Upload sur GitHub Releases
- Deploy sur Firebase App Distribution

**Constat negatif** :
- **Aucun test Flutter n'est execute** dans le pipeline (`flutter test` absent)
- Pas de `flutter analyze` dans le pipeline
- Pas de verification de couverture de tests

**Recommandation** : Ajouter `flutter analyze` et `flutter test --coverage` au pipeline.

### DEV2 - Dependency overrides

**Fichier** : `pubspec.yaml` (lignes 120-122)
```yaml
dependency_overrides:
  google_mlkit_commons: 0.11.0
  google_mlkit_text_recognition: 0.15.0
```
**Constat** : Override force pour resoudre un conflit de versions ML Kit.

### DEV3 - Version figee dans pubspec mais dynamique en CI

**Constat** : `pubspec.yaml` indique `version: 1.0.0+1` (jamais mis a jour) mais le pipeline CI utilise `PaulHatch/semantic-version` pour calculer la version dynamiquement au build.

**Recommandation** : Acceptable si la version dans pubspec n'est jamais utilisee directement.

### DEV4 - Package dio declare mais inutilise

**Constat** : `dio: ^5.9.0` est dans les dependances mais **aucun fichier** ne l'importe. Tous les appels HTTP utilisent le package `http`.

**Recommandation** : Soit migrer vers Dio (recommande pour interceptors, cache, retry), soit retirer la dependance.

---

## 8. Documentation

### DOC1 - README par defaut

**Fichier** : `README.md`
**Constat** : Le README est le template par defaut de Flutter. Pas d'informations sur le projet.

### DOC2 - Architecture documentee mais potentiellement obsolete

**Fichier** : `ARCHITECTURE.md`
**Constat** : Genere automatiquement par un pipeline retro-doc. A verifier la coherence avec le code actuel.

### DOC3 - Docs specifiques generees

**Fichiers** :
- `docs/DOCUMENTATION.md` : Documentation interne
- `docs/SCRYFALL_API_REFERENCE.md` : Reference API Scryfall
- `docs/AUDIT_NAMI.md` : Cet audit
- `docs/ROADMAP_MUGIWARA.md` : Plan d'action

---

## 9. Plan d'Action Prioritise

### Phase 1 - Fondations (Critiques, 2-3 semaines)

| # | Action                                  | Priorite | Effort | Impact |
|---|----------------------------------------|----------|--------|--------|
| 1 | Corriger le test existant (`MyApp` -> `MagicCompanionApp`) | P0 | 0.5j | Haut |
| 2 | Corriger l'anti-pattern firstWhere/catch dans les 3 services + pages | P1 | 1.5j | Moyen |
| 3 | Activer `avoid_print` + configurer `analysis_options.yaml` strict | P1 | 0.5j | Moyen |
| 4 | Nettoyer le code mort (unused fields, imports) | P2 | 0.5j | Faible |
| 5 | Extraire les constantes dupliquees dans `lib/theme/` | P2 | 1j | Faible |

### Phase 2 - Robustesse (Majeures, 3-4 semaines)

| # | Action                                          | Priorite | Effort | Impact   |
|---|-------------------------------------------------|----------|--------|----------|
| 6 | Migrer vers Riverpod (state management reel) | P1 | 5j | Tres Haut |
| 7 | Ecrire les tests unitaires des services | P1 | 3j | Tres Haut |
| 8 | Remplacer SharedPreferences par une DB locale (drift/isar) | P1 | 5j | Tres Haut |
| 9 | Migrer de `http` vers `Dio` (+ retirer package inutilise) | P2 | 2j | Haut |
| 10| Ajouter `flutter analyze` + `flutter test` au pipeline CI | P1 | 0.5j | Haut |

### Phase 3 - Optimisation (Moderees, 2-3 semaines)

| # | Action                                          | Priorite | Effort | Impact   |
|---|-------------------------------------------------|----------|--------|----------|
| 11| Implementer `go_router` pour la navigation declarative | P2 | 3j | Haut |
| 12| Ajouter le cache HTTP (Dio interceptor) | P2 | 1j | Moyen |
| 13| Implementer le rate limiting API global | P2 | 1j | Moyen |
| 14| Ajouter un systeme de logging structure | P2 | 1j | Moyen |
| 15| Extraire la logique upsert dupliquee en helper | P3 | 1j | Faible |

### Phase 4 - Evolution (Ameliorations, a planifier)

| # | Action                                          | Priorite | Effort | Impact   |
|---|-------------------------------------------------|----------|--------|----------|
| 16| Refactorer les 12 God Files en controllers + UI pure | P2 | 8j | Haut |
| 17| Mecanisme de mise a jour base locale (oracle-cards.json) | P2 | 3j | Haut |
| 18| Widget tests composants critiques | P3 | 3j | Moyen |
| 19| Mode offline explicite (banner, fallback gracieux) | P3 | 2j | Moyen |
| 20| Verifier `functions/service-account.json` non commit | P1 | 0.25j | Haut (secu) |

---

## 10. Metriques Cles

| Metrique                      | Valeur Actuelle     | Cible Recommandee    |
|-------------------------------|---------------------|----------------------|
| Fichiers Dart (lib/)          | 74                  | -                    |
| Lignes de code                | 19 675              | -                    |
| Couverture de tests           | 0% (test casse)     | >60%                 |
| Fichiers > 500 lignes         | 12                  | 0                    |
| Appels print()                | 17                  | 0                    |
| catch generiques              | 37                  | 0                    |
| Navigator.push/pop            | 152                 | 0 (go_router)        |
| Acces SharedPreferences       | 27 (12 fichiers)    | 0 (via DAL)          |
| Providers Riverpod actifs     | 0                   | >8                   |
| Pipeline CI execute tests     | Non                 | Oui                  |
| Dependencies directes         | 25                  | A auditer            |
| Dependencies inutilisees      | 1 (dio)             | 0                    |
| Lint warnings (estime)        | ~20-30              | 0                    |
