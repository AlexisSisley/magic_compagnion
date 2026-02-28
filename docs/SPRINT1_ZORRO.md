# Sprint 1 "Fondations" -- Analyse Business Detaillee

> Redige le 26/02/2026 par Zorro (Analyste Business, Equipage Mugiwara)
> Projet : Magic Companion (Flutter)
> Sources : Audit Nami (5.5/10), Roadmap Mugiwara, analyse de code source directe

---

## 0. Resume Executif

Le Sprint 1 est le socle de toute la suite. Sans lui, aucun test n'est possible, aucun refactoring n'est securise, et le pipeline CI reste un tigre de papier. Les 9 taches identifiees representent **5.75 jours-homme** et visent un objectif unique : **rendre la codebase auditable, testable et securisee**.

Ce document detaille chaque tache sous forme de User Story avec criteres d'acceptation verifiables, identifie les risques business, pose les NFRs, et definit l'ordre d'execution optimal.

**Constat terrain apres inspection du code** :
- **88 blocs `catch` generiques** recenses (plus que les 37 de l'estimation initiale -- les pages + widgets + services cumules)
- **18 appels `print()`** confirmes dans 12 fichiers
- **7 champs marques `// ignore: unused_field`** dans 7 fichiers distincts
- **125 valeurs `Color(0xFF...)` hardcodees** dans 44 fichiers
- **313 appels `GoogleFonts.cinzel`** dans 47 fichiers
- **`functions/service-account.json` contient une cle privee Firebase en clair** sur le disque (cle GCP completa avec private_key)
- Le `.gitignore` contient `service-account.json` (pattern global) -- la regle EXISTE mais il faut verifier l'historique Git

---

## 1. User Stories Detaillees

---

### US-1 : Corriger widget_test.dart
**Priorite** : P0 | **Effort** : 0.5 jour | **Type** : Fix

**En tant que** developpeur,
**je veux** que le test par defaut compile et s'execute avec succes,
**afin que** `flutter test` ne soit pas bloque des la premiere commande et que la CI puisse valider un baseline.

**Contexte technique** :
- `test/widget_test.dart` (ligne 16) reference `const MyApp()` alors que la classe s'appelle `MagicCompanionApp` (definie dans `lib/main.dart` ligne 52)
- Le test actuel est un smoke test "Counter increments" qui ne correspond plus a l'app (l'app n'a pas de compteur "+1")
- Ce test est le SEUL fichier de test du projet

**Criteres d'acceptation** :
1. `flutter test` s'execute sans erreur de compilation
2. Le test reference `MagicCompanionApp` (pas `MyApp`)
3. Le test est soit un vrai smoke test minimal (verification que l'app se lance), soit un placeholder explicitement commente avec un TODO
4. Le test passe en vert (exit code 0)

**Notes** :
- Ce test necessitera probablement un mock de Firebase (Firebase.initializeApp est appele dans main). Deux options : (a) tester un widget isole, ou (b) ajouter `setupFirebaseForTest()`. L'option (a) est recommandee pour le Sprint 1.
- Ne pas sous-estimer : le test actuel ne peut PAS juste remplacer `MyApp` par `MagicCompanionApp` car le widget n'a plus de bouton "+" ni de compteur. Le test doit etre **reecrit**.

**Definition of Done** : `flutter test` exit code 0 en local ET dans le pipeline CI.

---

### US-2 : Corriger l'anti-pattern firstWhere/catch dans les services
**Priorite** : P1 | **Effort** : 1 jour | **Type** : Refactor

**En tant que** developpeur,
**je veux** que les appels `firstWhere` dans les services utilisent le parametre `orElse` au lieu d'un bloc try/catch comme mecanisme de flow control,
**afin que** le code soit idiomatique, lisible, et que les vraies exceptions ne soient pas masquees.

**Contexte technique (releve direct du code)** :

Fichier `lib/services/collection_service.dart` (lignes 45-76) -- pattern actuel :
```dart
try {
  final existingCard = collection.firstWhere(
    (c) => c.scryfallId == scryfallId && c.isFoil == isFoil
  );
  // ... modification
} catch (e) {
  // ... creation nouvelle carte (catch = "not found")
}
```

Meme pattern dans :
- `lib/services/deck_service.dart` lignes 78-105 (methode `upsertCardInDeck`)
- `lib/services/wishlist_service.dart` lignes 126-154 (methode `upsertCard`)

Autres `firstWhere` sans `orElse` dans les services (risque d'exception non geree) :
- `deck_service.dart` lignes 68, 153, 166, 181 : `decks.firstWhere((d) => d.id == deckId)` -- lance `StateError` si le deck n'existe pas

**Criteres d'acceptation** :
1. Tous les `firstWhere` dans `collection_service.dart`, `deck_service.dart`, `wishlist_service.dart` utilisent `orElse: () => null` (via `.cast<T?>().firstWhere(...)`) ou sont remplaces par `.where(...).firstOrNull` (Dart 3 collection extension)
2. Le pattern try/catch-comme-flow-control est elimine des 3 services
3. Les `firstWhere` sur `decks.firstWhere((d) => d.id == deckId)` (4 occurrences dans deck_service.dart) gerent le cas "deck non trouve" explicitement (soit orElse, soit throw custom DeckNotFoundException)
4. Aucune regression fonctionnelle : ajouter/modifier/supprimer des cartes dans collection, deck, et wishlist fonctionne toujours
5. `flutter analyze` ne remonte aucun nouveau warning dans ces 3 fichiers

**Metriques de verification** :
- 0 bloc `try { firstWhere } catch` restant dans `lib/services/`
- Les 10 occurrences de `firstWhere` dans les services sont toutes traitees

---

### US-3 : Corriger les catch generiques dans les pages et widgets
**Priorite** : P1 | **Effort** : 1 jour | **Type** : Refactor

**En tant que** developpeur,
**je veux** que les blocs `catch` dans les pages et widgets attrapent des types d'exception specifiques ou, a minima, loguent l'erreur de facon utile,
**afin que** les bugs silencieux soient detectables et que les erreurs inattendues remontent correctement.

**Contexte technique** :
L'analyse du code revele **88 blocs `catch` au total** repartis dans 36 fichiers. La ventilation :
- **Services** : 16 catch (traites en US-2 pour les firstWhere, le reste dans cette US)
- **Pages** : 40 catch (dans 14 fichiers)
- **Widgets** : 32 catch (dans 12 fichiers)

Exemples les plus problematiques (catch vides ou commentaires vagues) :
- `lib/pages/cards/card_detail_page.dart` ligne 176 : `} catch (e) { }` (erreur completement avalee)
- `lib/pages/cards/card_detail_page.dart` ligne 734 : `} catch(e) {}` (idem)
- `lib/pages/decks/deck_detail_page.dart` ligne 754 : `} catch(e) {}` (idem)
- `lib/widgets/decks/deck_card_list_tab.dart` ligne 64 : `try { await launchUrl(...); } catch (e) { /* */ }` (echec silencieux d'ouverture URL)
- `lib/widgets/collection/collection_list_tab.dart` ligne 399 : `try { scryfallCard = widget.fullCardData.firstWhere(...); } catch(e){}` (anti-pattern firstWhere/catch dans un widget aussi)
- `lib/pages/wishlists/wishlist_detail_page.dart` lignes 95, 132, 167 : catch vides multiples

**Criteres d'acceptation** :
1. **Catch vides** (`catch (e) {}` ou `catch (e) { /* */ }`) : soit supprimes si l'erreur est sans consequence (avec commentaire justifiant), soit remplaces par un log explicite (`log('Context: $e')`)
2. **Catch generiques dans les appels API/HTTP** : attrapent `HttpException`, `FormatException`, `TimeoutException` selon le cas
3. **Catch pour les firstWhere dans pages/widgets** (au moins 8 occurrences) : convertis en `firstOrNull` ou `.where().firstOrNull`
4. Le nombre de `catch (e) {}` (catch vide) passe de ~20 a 0
5. Le nombre de `catch (e)` generiques non qualifies diminue d'au moins 50%
6. `flutter analyze` clean sur les fichiers modifies

**Strategie de traitement recommandee** (par ordre de gravite) :
- **Priorite haute** : catch vides (12+ occurrences) -> log ou suppression
- **Priorite moyenne** : catch firstWhere dans widgets (8+ occurrences) -> firstOrNull
- **Priorite basse** : catch generiques avec message deja present -> ajouter le type d'exception

---

### US-4 : Activer avoid_print et regles strictes dans analysis_options.yaml
**Priorite** : P1 | **Effort** : 0.5 jour | **Type** : DevOps

**En tant que** tech lead,
**je veux** que l'analyse statique Flutter soit configuree avec des regles strictes et que `avoid_print` soit active,
**afin que** le linter intercepte les mauvaises pratiques avant qu'elles n'atteignent le repository.

**Contexte technique** :
- Fichier actuel `analysis_options.yaml` (ligne 10) : utilise le package obsolete `flutter_lints` (`package:flutter_lints/flutter.yaml`) -- le standard actuel est `flutter_lints` v6 ou mieux `package:lints/recommended.yaml`
- La regle `avoid_print` est commentee (ligne 24) : `# avoid_print: false`
- Aucune regle supplementaire n'est activee
- Le `pubspec.yaml` (ligne 75) declare `flutter_lints: ^6.0.0` mais l'include dans analysis_options reference l'ancien format

**Criteres d'acceptation** :
1. `analysis_options.yaml` utilise `include: package:flutter_lints/flutter.yaml` (confirme compatible avec la version 6 declaree) OU migre vers `package:lints/recommended.yaml`
2. La regle `avoid_print: true` est activee (decommentee et forcee a true)
3. Les regles suivantes sont activees :
   - `prefer_const_constructors`
   - `prefer_const_declarations`
   - `prefer_final_locals`
   - `avoid_empty_else`
   - `no_duplicate_case_values`
   - `prefer_is_empty`
   - `unnecessary_null_checks`
4. `flutter analyze` s'execute (meme s'il remonte des warnings a corriger -- les corriger est couvert par US-3, US-5 et US-6)
5. Le fichier est bien forme et ne casse pas le tooling IDE

**Dependance** : Cette US doit etre faite AVANT US-5 (remplacement des print) pour que le linter les detecte tous.

**Attention** : L'activation de `prefer_const_constructors` risque de generer un tres grand nombre de warnings dans la codebase. Evaluer si on active cette regle en "warning" plutot qu'en "error", ou si on la reporte au Sprint 2.

---

### US-5 : Remplacer les print() par dart:developer log()
**Priorite** : P2 | **Effort** : 0.5 jour | **Type** : Cleanup

**En tant que** developpeur,
**je veux** que tous les `print()` soient remplaces par `log()` de `dart:developer`,
**afin que** les messages de debug n'apparaissent pas en production et soient filtrables par categorie.

**Contexte technique** :
18 appels `print()` recenses dans 12 fichiers :

| Fichier | Nb | Exemple |
|---|---|---|
| `lib/pages/scans/scanner_page.dart` | 3 | `print("Erreur Init Camera: $e")` |
| `lib/services/google_drive_service.dart` | 3 | `print("Erreur Google Sign In: $e")`, `print("Sauvegarde Drive mise a jour")`, `print("Nouvelle sauvegarde Drive creee")` |
| `lib/services/backup_service.dart` | 2 | `print("Erreur restauration JSON: $e")`, `print("Erreur import fichier: $e")` |
| `lib/services/edhrec_service.dart` | 2 | `print("Erreur EDHRec: $e")`, `print("Exception EDHRec: $e")` |
| `lib/main.dart` | 1 | `print("Debut sauvegarde automatique Drive...")` |
| `lib/pages/glossary/glossary_page.dart` | 1 | `print("Erreur de chargement du glossaire: $e")` |
| `lib/pages/collections/collection_page.dart` | 1 | `print("Erreur ajout carte $id : $e")` |
| `lib/services/wishlist_service.dart` | 1 | `print("Erreur migration wishlist: $e")` |
| `lib/services/set_service.dart` | 1 | `print("Erreur SetService: $e")` |
| `lib/services/oracle_service.dart` | 1 | `print("Erreur Oracle: $e")` |
| `lib/pages/cards/card_detail_page.dart` | 1 | `print("Erreur API Search: $e")` |

Note : Certains fichiers utilisent deja `log()` correctement (ex: `collection_page.dart` ligne 139 : `log('Erreur API: $e')`, `deck_list_page.dart` ligne 281 : `log("Erreur import: $e")`). Le pattern existe deja dans le projet -- il faut juste l'uniformiser.

**Criteres d'acceptation** :
1. 0 appel `print()` dans `lib/` (hors fichiers generes)
2. Chaque ancien `print()` est remplace par `log('message', name: 'NomDuService')` avec import `dart:developer`
3. Les messages informatifs (pas des erreurs) comme "Sauvegarde Drive creee" utilisent `log()` avec un `name` adequat
4. Les messages d'erreur incluent l'objet d'erreur : `log('Erreur: $e', name: 'BackupService', error: e)`
5. `flutter analyze` ne remonte pas de violation `avoid_print`

**Dependance** : US-4 doit etre terminee (avoid_print active) pour que le linter valide cette US.

---

### US-6 : Nettoyer le code mort
**Priorite** : P2 | **Effort** : 0.5 jour | **Type** : Cleanup

**En tant que** developpeur,
**je veux** que le code mort et les champs inutilises soient supprimes,
**afin que** la codebase soit lisible et que les warnings d'analyse soient a zero.

**Contexte technique** :
7 annotations `// ignore: unused_field` ou `// ignore: unused_local_variable` detectees :

| Fichier | Ligne | Champ mort | Analyse |
|---|---|---|---|
| `lib/pages/decks/deck_detail_page.dart` | 45 | `bool _isValidating = false` | Setted a true/false aux lignes 619/621 MAIS de facon synchrone dans un setState, jamais lu par le build(). Le flag n'a aucun effet visuel. **SUPPRIMER** le champ et les 2 lignes setState. |
| `lib/pages/cards/card_search_page.dart` | 62 | `RegExp _manaRegex` | Declare avec `// ignore: unused_field`. Jamais reference ailleurs dans le fichier. **SUPPRIMER**. |
| `lib/pages/cards/card_detail_page.dart` | 69 | `String _currentDisplayLang = 'fr'` | Declare avec `// ignore: unused_field`. Probable vestige d'une feature i18n non terminee. **SUPPRIMER** ou **CREER UN TICKET** pour la feature. |
| `lib/pages/wishlists/wishlist_detail_page.dart` | 27 | `CollectionService _collectionService` | Instancie mais jamais utilise. **SUPPRIMER**. |
| `lib/pages/scans/scanner_page.dart` | 30 | `bool _isInitializing = false` | Declare avec `// ignore: unused_field`. Verrou non branche. **SUPPRIMER** (ou l'utiliser si le bug de double-init existe). |
| `lib/widgets/decks/deck_financial_sheet.dart` | 34 | `double totalProxySaving = 0.0` | Variable locale declaree, incrementee mais jamais lue. **SUPPRIMER** ou **AFFICHER** dans l'UI. |
| `lib/widgets/decks/deck_suggestions_tab.dart` | 34 | `String? _errorMsg` | Declare mais jamais affiche dans le build. **SUPPRIMER** ou **AFFICHER** dans l'UI (meilleur UX si erreur visible). |

**Criteres d'acceptation** :
1. Toutes les annotations `// ignore: unused_field` et `// ignore: unused_local_variable` sont supprimees
2. Les champs correspondants sont soit supprimes, soit correctement utilises
3. `flutter analyze` ne remonte aucun warning `unused_field`, `unused_local_variable`, `unused_element` dans ces fichiers
4. Aucune regression fonctionnelle (les champs supprimes n'etaient pas lus)

---

### US-7 : Extraire les constantes dupliquees dans lib/theme/
**Priorite** : P2 | **Effort** : 1 jour | **Type** : Refactor

**En tant que** developpeur,
**je veux** que les couleurs et styles de police dupliques soient centralises dans un dossier `lib/theme/`,
**afin que** toute modification du design se fasse en un seul endroit et que la coherence visuelle soit garantie.

**Contexte technique** :
- **125 occurrences** de `Color(0xFF...)` reparties dans **44 fichiers**
- **313 occurrences** de `GoogleFonts.cinzel` reparties dans **47 fichiers**
- **58 occurrences** de `Colors.yellow.shade800` reparties dans **26 fichiers**
- Couleur de fond principale `Color(0xFF1A1A1A)` utilisee dans au moins 5 fichiers directement (main.dart, settings_page, etc.)
- Le dossier `lib/theme/` n'existe pas encore

Constantes candidates a l'extraction :
```
Color(0xFF1A1A1A)       -> AppColors.background         (fond principal)
Colors.yellow.shade800   -> AppColors.accent             (couleur d'accent)
Colors.black             -> AppColors.surface            (surfaces)
Colors.white54           -> AppColors.textSecondary      (texte secondaire)
Colors.white70           -> AppColors.textPrimary        (texte principal)
Colors.white10           -> AppColors.divider            (separateurs)
GoogleFonts.cinzel(...)  -> AppFonts.title(...)          (police titres)
```

**Criteres d'acceptation** :
1. Le dossier `lib/theme/` est cree avec au minimum :
   - `app_colors.dart` : classe abstraite avec toutes les couleurs en `static const`
   - `app_fonts.dart` : classe abstraite avec les styles de police
2. Au minimum les **5 couleurs les plus utilisees** sont extraites et referencees dans au moins les fichiers `main.dart` et les services principaux
3. Au minimum **10 fichiers** utilisent les nouvelles constantes (les plus accessibles)
4. La migration est progressive : on ne force PAS les 44 fichiers d'un coup (risque de regression)
5. Le `ThemeData` dans `main.dart` reference les constantes `AppColors`
6. `flutter analyze` clean

**Attention** : Cette US est la plus a risque de regression visuelle. Chaque remplacement doit etre verifie visuellement. Privilegier un remplacement "inside-out" : d'abord `main.dart` et les services, puis les pages les plus simples, puis les widgets.

**Ce qui est HORS SCOPE Sprint 1** : La migration complete des 313 `GoogleFonts.cinzel` (estimee a Sprint 7/backlog pour l'i18n).

---

### US-8 : Verifier que functions/service-account.json n'est pas commit
**Priorite** : P1 (URGENTE) | **Effort** : 0.25 jour | **Type** : Securite

**En tant que** responsable securite,
**je veux** m'assurer que le fichier `functions/service-account.json` contenant la cle privee Firebase n'est pas versionne dans Git,
**afin que** les credentials GCP ne soient pas exposes publiquement.

**Contexte technique** :
- Le fichier `functions/service-account.json` **EXISTE physiquement** sur le disque
- Il contient une **cle privee RSA complete** (champ `private_key`) pour le service account `firebase-adminsdk-fbsvc@magic-companion-rag.iam.gserviceaccount.com`
- Il contient le `project_id`, `client_email`, `private_key_id`
- Le `.gitignore` contient la regle `service-account.json` (ligne 44) qui matche ce fichier **par son nom** (pattern global, pas par chemin)
- **A VERIFIER** : si le fichier a deja ete commit dans l'historique Git AVANT l'ajout de la regle .gitignore

**Criteres d'acceptation** :
1. Verifier via `git ls-files -- functions/service-account.json` que le fichier n'est PAS track
2. Verifier via `git log --all -- functions/service-account.json` que le fichier n'a JAMAIS ete commit dans l'historique
3. **Si le fichier est/a ete commit** :
   - Le retirer du tracking (`git rm --cached functions/service-account.json`)
   - Considerer l'utilisation de `git filter-branch` ou `BFG Repo-Cleaner` pour purger l'historique
   - **REVOQUER immediatement la cle** dans la console Firebase/GCP (la cle est compromise si l'historique est public)
   - Generer une nouvelle cle de service account
4. Ajouter la regle explicite `functions/service-account.json` (avec le chemin complet) dans `.gitignore` en plus du pattern global
5. Documenter dans un commentaire `.gitignore` pourquoi cette regle est critique

**Risque business** : Si le repo est public ou le devient un jour, une cle Firebase exposee permet a un attaquant d'acceder au backend Firebase (Cloud Functions, Firestore, etc.) du projet. Meme si le repo est prive, c'est une violation des bonnes pratiques GCP.

---

### US-9 : Ajouter flutter analyze + flutter test au pipeline CI
**Priorite** : P1 | **Effort** : 0.5 jour | **Type** : DevOps

**En tant que** tech lead,
**je veux** que le pipeline CI execute `flutter analyze` et `flutter test` avant chaque build,
**afin que** les regressions de qualite et les tests casses bloquent le merge.

**Contexte technique** :
- Le workflow actuel (`.github/workflows/build-main.yml`) execute : checkout, Flutter setup, `flutter pub get`, unzip assets, build APK, release GitHub, deploy Firebase
- **Il n'execute PAS** `flutter analyze` ni `flutter test`
- Le workflow `release.yml` (branches `release/**`) n'execute pas non plus d'analyse/tests
- Le workflow `retro-doc.yml` est un pipeline de documentation (hors scope)

**Criteres d'acceptation** :
1. Le workflow `build-main.yml` inclut une etape `flutter analyze --fatal-infos` (ou `--fatal-warnings` au minimum) AVANT le build
2. Le workflow `build-main.yml` inclut une etape `flutter test` AVANT le build
3. Les deux etapes sont en `fail-fast` : si l'analyse ou les tests echouent, le build ne se lance PAS
4. L'etape `flutter test` fonctionne (ce qui implique que US-1 doit etre terminee AVANT)
5. (Optionnel mais recommande) Le workflow `release.yml` integre aussi ces etapes
6. Le pipeline reste fonctionnel (pas de regression sur le build existant)

**Proposition d'implementation** :
Ajouter apres l'etape "Install dependencies" et avant le build :
```yaml
- name: Run Flutter Analyze
  run: flutter analyze --fatal-warnings

- name: Run Flutter Tests
  run: flutter test
```

**Dependance forte** : US-1 (test qui compile) DOIT etre terminee avant, sinon `flutter test` echouera toujours.
**Dependance faible** : US-4 (regles strictes) devrait etre terminee avant pour que `flutter analyze` soit significatif, mais ce n'est pas bloquant.

---

## 2. Risques Business

| # | Risque | Probabilite | Impact | Mitigation | US liee |
|---|--------|-------------|--------|------------|---------|
| R1 | **Cle Firebase deja exposee dans l'historique Git** | Moyenne | **CRITIQUE** | Verifier l'historique Git immediatement. Si compromise : revoquer, regenerer, purger. | US-8 |
| R2 | **US-1 sous-estimee** : le test ne peut pas juste renommer MyApp, il faut gerer Firebase init + rewrite complet | Haute | Moyen | Prevoir un mock Firebase ou un test minimal qui ne lance pas l'app complete. Budget reel : 0.5-1j. | US-1 |
| R3 | **US-3 sous-estimee** : 88 catch reels vs 37 estimes initialement | Haute | Faible | Prioriser les catch vides (les plus dangereux) et les firstWhere/catch. Accepter que les catch "inoffensifs" soient traites en Sprint 2. | US-3 |
| R4 | **US-7 cause des regressions visuelles** : remplacer des couleurs hardcodees peut casser le rendu sur certains ecrans | Moyenne | Moyen | Migration progressive. Tester visuellement chaque ecran modifie. Limiter a 10 fichiers en Sprint 1. | US-7 |
| R5 | **US-4 genere trop de warnings** : activer les regles strictes pourrait reveler des centaines de violations | Haute | Faible | Activer les regles en mode "warning" (pas "error") dans un premier temps. Ne bloquer le CI que sur `--fatal-warnings`, pas `--fatal-infos`. | US-4 |
| R6 | **Scope creep** : en corrigeant les catch, on decouvre d'autres problemes et on est tente de les fixer | Moyenne | Moyen | Discipline : toute correction hors scope est un ticket pour le Sprint 2. Pas de "tant qu'on y est". | US-2, US-3 |
| R7 | **Pas de tests pour valider les refactorings** : les US-2/US-3 modifient la logique metier sans filet de securite | Haute | Haut | Executer US-1 + US-9 en premier. Si possible, ecrire 2-3 tests manuels rapides pour collection/deck/wishlist upsert. | US-2, US-3 |
| R8 | **Le pipeline CI echoue a cause de l'unzip assets** : `flutter test` pourrait avoir besoin des assets JSON decompresses | Moyenne | Faible | S'assurer que l'etape `flutter test` est placee APRES l'etape "Unzip Data Files" dans le workflow. | US-9 |

---

## 3. Non-Functional Requirements (NFRs)

### NFR-1 : Temps d'execution de l'analyse statique
`flutter analyze` doit s'executer en **moins de 60 secondes** dans le pipeline CI. Si les regles strictes ralentissent significativement l'analyse, revoir la configuration.

### NFR-2 : Zero warning critique en fin de Sprint
A la fin du Sprint 1, `flutter analyze` ne doit remonter **aucun warning de niveau "error"** ni **aucune violation `avoid_print`**. Les warnings de niveau "info" sont acceptes (seront traites au Sprint 2).

### NFR-3 : Retrocompatibilite des donnees
Les modifications des services (US-2) ne doivent **en aucun cas** modifier le format de serialisation JSON des collections, decks ou wishlists. Les donnees existantes des utilisateurs doivent rester lisibles apres le refactoring.

### NFR-4 : Pas de regression UX
Les modifications de US-7 (constantes de couleurs) ne doivent introduire **aucune difference visuelle perceptible** par l'utilisateur. Le rendu avant/apres doit etre pixel-identical sur les ecrans modifies.

### NFR-5 : Securite des credentials
Apres US-8, aucun fichier contenant des credentials (cles privees, tokens, mots de passe) ne doit etre present dans le repository Git (ni dans le working tree track, ni dans l'historique). Le `.gitignore` doit couvrir tous les patterns de fichiers sensibles.

### NFR-6 : Pipeline CI stable
Le pipeline CI modifie (US-9) doit avoir un taux de succes de **100%** sur les commits propres (pas de tests flaky, pas de timeouts aleatoires). Le temps total du pipeline ne doit pas augmenter de plus de **2 minutes**.

### NFR-7 : Maintenabilite du code
Apres le Sprint 1, tout nouveau code doit se conformer aux regles du `analysis_options.yaml` mis a jour. Aucun nouveau `// ignore:` ne doit etre introduit sans justification en commentaire et approbation en code review.

---

## 4. Prioritisation et Dependances

### 4.1 Graphe de Dependances

```
US-8 (Securite cle)          [INDEPENDANT - FAIRE EN PREMIER]
  |
  v
US-1 (Fix test)              [INDEPENDANT]
  |
  v
US-4 (analysis_options)      [INDEPENDANT, mais avant US-5]
  |
  +---> US-5 (print -> log)  [DEPEND DE US-4]
  |
  +---> US-6 (code mort)     [INDEPENDANT, beneficie de US-4]
  |
  v
US-2 (firstWhere services)   [INDEPENDANT, beneficie de US-4]
  |
  v
US-3 (catch generiques)      [DEPEND de US-2 pour les services, INDEPENDANT pour pages/widgets]
  |
  v
US-7 (theme/constantes)      [INDEPENDANT, mais en dernier car plus risque]
  |
  v
US-9 (CI analyze + test)     [DEPEND de US-1, US-4, US-5 pour passer en vert]
```

### 4.2 Ordre d'Execution Recommande

| Jour | Matin | Apres-midi | Justification |
|------|-------|------------|---------------|
| **J1** | **US-8** : Verifier service-account.json + securiser | **US-1** : Corriger/reecrire widget_test.dart | Securite d'abord. Test = prerequis pour tout. |
| **J2** | **US-4** : Activer regles strictes analysis_options | **US-5** : Remplacer 18 print() par log() | Les regles detectent les print. On les fixe dans la foulee. |
| **J2.5** | **US-6** : Nettoyer les 7 champs morts | -- | Profiter de l'analyse active pour valider. |
| **J3** | **US-2** : Refactorer firstWhere/catch dans les 3 services | -- (suite US-2) | 10 occurrences firstWhere dans les services. |
| **J4** | **US-3** : Corriger les catch generiques (pages/widgets) | -- (suite US-3) | 88 catch, prioriser les catch vides. |
| **J5** | **US-7** : Extraire constantes dans lib/theme/ | **US-9** : Ajouter analyze + test au CI | Theme en progressif. CI en dernier = validation finale. |

### 4.3 Definition des Jalons

| Jalon | Critere de validation | Jour |
|-------|----------------------|------|
| **M1 - Securite OK** | `functions/service-account.json` non track, cle rotee si necessaire | J1 |
| **M2 - Test baseline** | `flutter test` passe en vert (1 test minimal) | J1 |
| **M3 - Linter actif** | `flutter analyze` s'execute avec regles strictes, 0 violation `avoid_print` | J2.5 |
| **M4 - Services propres** | 0 anti-pattern firstWhere/catch dans les 3 services | J3 |
| **M5 - Sprint 1 Done** | Pipeline CI vert (analyze + test + build) sur la branche main | J5 |

---

## 5. Metriques de Succes du Sprint

| Metrique | Avant Sprint 1 | Objectif Fin Sprint 1 | Methode de mesure |
|----------|----------------|----------------------|-------------------|
| `flutter test` exit code | Erreur compilation | 0 (succes) | CI pipeline |
| Violations `avoid_print` | 18 | 0 | `flutter analyze` |
| Blocs `catch (e) {}` vides | ~20 | 0 | Grep sur la codebase |
| Anti-patterns firstWhere/catch | ~15 | 0 (services), <5 (widgets) | Grep sur la codebase |
| Annotations `// ignore: unused_` | 7 | 0 | Grep sur la codebase |
| Pipeline CI teste le code | Non | Oui | Presence des steps dans workflow |
| Fichiers utilisant AppColors | 0 | >10 | Grep `AppColors` |
| Credentials dans Git | A verifier | 0 | `git ls-files` |
| Score qualite estime | 5.5/10 | **6.5/10** | Recalcul post-sprint |

---

## 6. Ce qui est explicitement HORS SCOPE Sprint 1

Pour eviter le scope creep (Risque R6), les elements suivants sont **reportes** :

- Migration Riverpod (Sprint 2)
- Ecriture de tests unitaires complets pour les services (Sprint 3)
- Remplacement de SharedPreferences par une BDD (Sprint 4)
- Migration des 313 GoogleFonts.cinzel (Sprint 7 / backlog)
- Migration complete des 125 Color() dans les 44 fichiers (seuls 10+ fichiers sont cibles)
- Correction des 152 Navigator.push (Sprint 5)
- Suppression/migration de la dependance `dio` inutilisee (Sprint 5)
- Resolution des dependency_overrides ML Kit (Sprint 7)
- God Files refactoring (Sprint 6)

---

*Ce document est la reference pour le Sprint 1. Toute modification de scope doit etre validee par le Product Owner avant implementation. Les estimations sont basees sur l'analyse directe du code source au 26/02/2026.*
