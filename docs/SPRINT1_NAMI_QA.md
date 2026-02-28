# SPRINT 1 "Fondations" - Rapport QA par Nami

**Date d'audit** : 2026-02-26
**Auditeur** : Nami, Agent QA - Equipage Mugiwara
**Projet** : Magic Companion (Flutter)
**Branche** : main

---

## Resume executif

| # | Verification                                | Verdict  |
|---|---------------------------------------------|----------|
| 1 | Test widget_test.dart corrige               | PASS     |
| 2 | Anti-pattern firstWhere/catch corrige (x3)  | PASS     |
| 3 | Lint rules activees                         | PASS     |
| 4 | print() remplaces par log()                 | **FAIL** |
| 5 | Code mort nettoye                           | PASS     |
| 6 | .gitignore securise                         | PASS     |
| 7 | CI pipeline mis a jour                      | PASS     |

**VERDICT GLOBAL : FAIL** (1 verification echouee sur 7)

---

## Detail des verifications

### 1. Test widget_test.dart corrige -- PASS

**Fichier** : `test/widget_test.dart`

- [x] Le test reference bien `MagicCompanionApp` (ligne 11) et non `MyApp`
- [x] Import correct : `package:magic_companion/main.dart`
- [x] Widget wrape dans un `ProviderScope` (compatible Riverpod)
- [x] Syntaxe correcte : `testWidgets`, `pumpWidget`, `expect(find.byType(MaterialApp), findsOneWidget)`
- [x] Aucune erreur syntaxique detectee

```dart
testWidgets('MagicCompanionApp builds without crashing', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MagicCompanionApp(),
    ),
  );
  expect(find.byType(MaterialApp), findsOneWidget);
});
```

### 2. Anti-pattern firstWhere/catch corrige dans 3 services -- PASS

#### 2a. `lib/services/collection_service.dart` - `_upsertInMemory`

- [x] Utilise `indexWhere` (ligne 45) au lieu de try/firstWhere/catch
- [x] Pattern correct : `index != -1` pour verifier l'existence

```dart
final index = collection.indexWhere(
  (c) => c.scryfallId == scryfallId && c.isFoil == isFoil
);
if (index != -1) { ... }
```

#### 2b. `lib/services/deck_service.dart` - 4 methodes

- [x] `upsertCardInDeck` : `indexWhere` ligne 68 (deckIndex) et ligne 80 (cardIndex)
- [x] `setCommander` : `indexWhere` ligne 154
- [x] `unsetCommander` : `indexWhere` ligne 169
- [x] `clearDeck` : `indexWhere` ligne 186
- [x] Aucun try/firstWhere/catch restant dans les 3 fichiers de services

#### 2c. `lib/services/wishlist_service.dart` - `upsertCard`

- [x] Utilise `indexWhere` ligne 121 (pour la wishlist) et ligne 129 (pour la carte)
- [x] Pattern correct avec `index == -1` pour gestion d'absence

### 3. Lint rules activees -- PASS

**Fichier** : `analysis_options.yaml`

- [x] `avoid_print: true` present en ligne 14, **non commente**
- [x] Autres regles complementaires presentes (prefer_single_quotes, prefer_const_constructors, etc.)

```yaml
linter:
  rules:
    avoid_print: true
```

### 4. print() remplaces par log() -- FAIL

**Resultat du grep** : 2 occurrences de `print()` trouvees dans `lib/`

| Fichier | Ligne | Code incrimine |
|---------|-------|----------------|
| `lib/pages/collections/collection_page.dart` | 304 | `print("Erreur ajout carte $id : $e");` |
| `lib/pages/cards/card_detail_page.dart` | 215 | `print("Erreur API Search: $e");` |

**Points positifs** :
- 13 fichiers utilisent correctement `log()` avec `import 'dart:developer'`
- Les 3 fichiers de services (collection, deck, wishlist) sont propres

**Correction requise** :
- Remplacer les 2 `print()` restants par `log()` avec import de `dart:developer`
- `collection_page.dart` ligne 304 : `log("Erreur ajout carte $id : $e");`
- `card_detail_page.dart` ligne 215 : `log("Erreur API Search: $e");`

### 5. Code mort nettoye -- PASS

- [x] Pas de `_manaRegex` dans `lib/pages/cards/card_search_page.dart` (grep vide)
- [x] Pas de `_collectionService` inutilise dans `lib/pages/wishlists/wishlist_detail_page.dart` (grep vide)
- [x] Aucun `// ignore: unused_field` restant dans tout `lib/` (grep vide)

### 6. .gitignore securise -- PASS

**Fichier** : `.gitignore`

- [x] `**/service-account.json` present en ligne 44
- [x] Autres fichiers sensibles egalement couverts : `*.jks`, `*.keystore`, `key.properties`

```gitignore
**/service-account.json
```

### 7. CI pipeline mis a jour -- PASS

**Fichier** : `.github/workflows/build-main.yml`

- [x] `flutter analyze --no-fatal-infos` present (ligne 104, step "Flutter Analyze")
- [x] `flutter test` present (ligne 112, step "Run Flutter Tests")
- [x] Decompression prealable des assets de test (ligne 109, step "Unzip Data Files")
- [x] Pipeline ordonnee : pub get -> analyze -> unzip -> test -> build

```yaml
- name: Flutter Analyze
  run: flutter analyze --no-fatal-infos

- name: Unzip Data Files (for tests)
  run: |
    echo "Decompression des donnees..."
    unzip assets/json/cards_data.zip -d assets/json/

- name: Run Flutter Tests
  run: flutter test
```

---

## Actions correctives requises

### Priorite HAUTE (bloquant pour PASS)

1. **`lib/pages/collections/collection_page.dart` ligne 304** :
   - Ajouter `import 'dart:developer';` en haut du fichier (si absent)
   - Remplacer `print("Erreur ajout carte $id : $e");` par `log("Erreur ajout carte $id : $e");`

2. **`lib/pages/cards/card_detail_page.dart` ligne 215** :
   - Ajouter `import 'dart:developer';` en haut du fichier (si absent)
   - Remplacer `print("Erreur API Search: $e");` par `log("Erreur API Search: $e");`

---

## Note de Nami

> "Oi oi ! Le travail est presque parfait a 85% ! 6 verifications sur 7 sont OK, c'est du bon boulot.
> Mais il reste 2 `print()` planques dans le code comme des marines embusques...
> Corrigez-moi ca et je tamponnerai le PASS sans hesiter.
> On ne laisse pas de dette technique trainer sur ce navire !"
>
> -- Nami, Navigatrice & QA des Mugiwara
