# Audit Code Qualite - Rapport Franky
> Agent : Franky (Charpentier / Code Quality) | Date : 28/02/2026
> Audit complet post-Sprint 6, avant execution Sprint 7

---

## 1. Resume Executif

Le Sunny a bien evolue depuis les sprints precedents, mais la coque presente encore **1033 fissures** (issues info analyse statique) et **13 poutres trop longues** (God Files >500 lignes). Aucune erreur ni warning bloquant, mais la dette cosmetique freine la lisibilite et le refactoring futur.

**Score qualite actuel : 8.5/10** (revise a la baisse par rapport au 9.0 annonce -- les 1033 infos et les anti-patterns non corriges pesent)

---

## 2. Metriques Globales

| Metrique | Valeur | Verdict |
|----------|--------|---------|
| Fichiers Dart (hors genere) | 84 | - |
| Lignes de code total | 22 099 | - |
| Tests | 165 (tous verts) | OK |
| flutter analyze errors | **0** | PASS |
| flutter analyze warnings | **0** | PASS |
| flutter analyze infos | **1033** | ATTENTION |
| God Files >500 lignes | **13** | FAIL (cible : 0) |
| God Files pages >500 lignes | **6** | FAIL (Sprint 7) |
| Navigator.push restants | **23** (15 fichiers) | FAIL (cible : 0) |
| SharedPreferences residuels (hors migration) | **8 appels** (5 fichiers) | ATTENTION |
| Package `http` (inutilise) | **present** | FAIL |
| Controllers Riverpod | **0** | FAIL (cible Sprint 7 : 6) |

---

## 3. Analyse des 1033 Issues (par type)

| Regle | Occurrences | Severite | Correctif |
|-------|-------------|----------|-----------|
| `prefer_single_quotes` | **585** | Info | Find/replace `"` → `'` quand pas d'interpolation |
| `deprecated_member_use` (withOpacity) | **181** | Info | Remplacer `.withOpacity(x)` par `.withValues(alpha: x)` |
| `curly_braces_in_flow_control_structures` | **84** | Info | Ajouter `{}` aux if/else one-line |
| `unnecessary_non_null_assertion` | **72** | Info | Supprimer les `!` inutiles |
| `use_build_context_synchronously` | **31** | Info | Ajouter `if (!mounted) return;` avant usage context apres await |
| `prefer_const_constructors` | **24** | Info | Ajouter `const` |
| `unnecessary_underscores` | **19** | Info | Renommer les variables `_` inutiles |
| `empty_catches` | **14** | Info | Ajouter au minimum `// ignore intentionnel` ou logger |
| `prefer_final_fields` | **6** | Info | Ajouter `final` |
| `unnecessary_this` | **5** | Info | Supprimer `this.` |
| `unused_field` | **3** | Warning | Supprimer `_currentDisplayLang`, `_isValidating`, `_errorMsg` |
| `unnecessary_to_list_in_spreads` | **3** | Info | Supprimer `.toList()` dans les spreads |
| `unused_import` | **1** | Warning | `collection_service.dart` dans collection_sets_tab |
| `unnecessary_import` | **1** | Info | `services.dart` dans wishlist_detail_page |

### Actions recommandees (effort minimal, gain maximal)

1. **585 prefer_single_quotes** → Script automatique `dart format` + sed (30 min)
2. **181 withOpacity** → Search/replace `.withOpacity(` → `.withValues(alpha: ` (1h)
3. **84 curly_braces** → `dart fix --apply` peut resoudre certains (30 min)
4. **72 unnecessary_non_null_assertion** → Revue manuelle rapide (1h)
5. **31 use_build_context_synchronously** → Critique pour la stabilite, prioritaire (2h)
6. **14 empty_catches** → Ajouter logging ou commentaire (30 min)
7. **3 unused_field** → Supprimer directement (5 min)

**Effort total estime : 1.5 jours pour passer de 1033 a ~0 infos**

---

## 4. Audit SOLID & Anti-Patterns

### 4.1 - Single Responsibility Principle (SRP) : FAIL

Les 6 God Files pages melangent :
- **Logique metier** (chargement, recherche, filtrage, pagination)
- **Gestion d'etat** (setState, variables locales)
- **Rendu UI** (build, widgets)
- **Navigation** (Navigator.push)

| Fichier | Lignes | Responsabilites melangees |
|---------|--------|--------------------------|
| `set_detail_page.dart` | 1003 | Chargement cartes, pagination, filtres, ajout collection/wishlist, stats, UI |
| `deck_detail_page.dart` | 850 | CRUD cartes, batch fetch, 4 zones, partage, UI |
| `card_search_page.dart` | 830 | Recherche API/locale, pagination, filtres, tri, UI |
| `deck_card_picker.dart` | 774 | Recherche, pagination, selection multi, filtres, UI |
| `card_detail_page.dart` | 773 | Fetch carte, rulings, legality, ajout, UI |
| `deck_list_page.dart` | 731 | CRUD decks, import, filtres, tri, stats, UI |
| `collection_list_tab.dart` | 715 | Liste, filtres, tri, tags, actions, UI |
| `player_zone.dart` | 674 | Compteurs, couleurs, menus, gestes, UI |
| `app_router.dart` | 613 | Routes, dialogs, drawer, guards |
| `deck_stats_tab.dart` | 612 | Calculs stats, graphiques, mana curve, UI |
| `app_database.dart` | 542 | 10 tables + toutes les requetes DAO dans un seul fichier |
| `scanner_page.dart` | 531 | Camera, ML Kit, resultat, UI |
| `collection_page.dart` | 521 | Batch loading, onglets, import/export, stats, UI |

**Correction Sprint 7** : Extraction de 6 controllers Riverpod.

### 4.2 - Open/Closed Principle (OCP) : ATTENTION

- La logique upsert est dupliquee dans 3 services (collection, deck, wishlist) au lieu d'etre dans un mixin/base class extensible.
- `app_database.dart` concentre toutes les requetes DAO au lieu de les separer par domaine dans `lib/data/database/daos/`.

### 4.3 - Dependency Inversion (DIP) : PROGRES

- **Bon** : 14 providers Riverpod, injection propre via `service_providers.dart`
- **Mauvais** : 17 widgets `StatefulWidget` (sans Consumer) n'ont pas acces aux providers et recoivent les services en parametres. 24 `ConsumerStatefulWidget` sont correctement integres.
- **Mauvais** : 8 appels `SharedPreferences.getInstance()` directs dans 5 pages au lieu de passer par un provider/service.

### 4.4 - Don't Repeat Yourself (DRY) : FAIL

| Duplication | Occurrences | Impact |
|-------------|-------------|--------|
| `GoogleFonts.cinzel(...)` | **327 appels** | Devrait etre une constante dans app_theme |
| `Colors.xxx` hardcodes | **1373 appels** | Devrait etre dans ThemeData |
| `Color(0x...)` hardcodes | **124 appels** | Devrait etre dans ThemeData |
| Logique upsert (indexWhere + update/create) | **3 services** | Sprint 7 : mixin |
| `Navigator.push(context, MaterialPageRoute(...))` | **23 appels** | Sprint 7 : go_router |
| `SharedPreferences.getInstance()` dans pages | **8 appels** | Devrait etre dans service/provider |

### 4.5 - setState proliferation

| Metrique | Valeur |
|----------|--------|
| Appels `setState` totaux | **233** |
| Fichiers avec setState | Quasiment toutes les pages |

Apres extraction des controllers, la majorite de ces `setState` seront remplaces par `ref.watch/read` + AsyncNotifier, ce qui reduira le couplage etat/UI.

---

## 5. Bugs & Risques Identifies

### 5.1 - BUG CORRIGE : UNIQUE constraint failed (collection_value_history)

- **Fichier** : `app_database.dart:245` (methode `recordDailyValue`)
- **Cause** : `insertOnConflictUpdate()` sur `id` au lieu de `dateKey` (contrainte UNIQUE)
- **Fix** : Upsert manuel SELECT + UPDATE/INSERT
- **Status** : CORRIGE

### 5.2 - BUG CORRIGE : Deactivated widget ancestor lookup

- **Fichier** : `collection_sets_tab.dart:298`
- **Cause** : `ref.read()` appele dans le `builder` de MaterialPageRoute (widget potentiellement desactive)
- **Fix** : Capturer les services avant le Navigator.push
- **Status** : CORRIGE

### 5.3 - RISQUE : use_build_context_synchronously (31 occurrences)

- **Impact** : Crash potentiel si le widget est demonte pendant un await
- **Fichiers principaux** : card_detail_page (4), card_search_page (3), set_detail_page (2), deck_detail_page (5+)
- **Correction** : Ajouter `if (!mounted) return;` avant chaque usage de context apres un await
- **Priorite** : P1 (stabilite)

### 5.4 - RISQUE : 14 empty catches

- **Impact** : Erreurs silencieuses, debug impossible
- **Fichiers** : card_detail_page (2), deck_detail_page (2), wishlist_tab (2), wishlist_detail_page (2), collection_list_tab (2), deck_card_list_tab (1), deck_stats_tab (3)
- **Correction** : Ajouter au minimum `debugPrint` ou logger
- **Priorite** : P2

### 5.5 - RISQUE : 3 champs inutilises (warning)

- `_currentDisplayLang` dans card_detail_page.dart:74
- `_isValidating` dans deck_detail_page.dart:47
- `_errorMsg` dans deck_suggestions_tab.dart:35
- **Correction** : Supprimer
- **Priorite** : P2

### 5.6 - RISQUE : dependency_overrides dans pubspec.yaml

```yaml
dependency_overrides:
  google_mlkit_commons: 0.11.0
  google_mlkit_text_recognition: 0.15.0
```

Ces overrides forcent des versions potentiellement incompatibles. A surveiller lors des mises a jour.

---

## 6. Inventaire des Dependances

### Dependances a supprimer
| Package | Raison |
|---------|--------|
| `http: ^1.2.1` | 0 import dans lib/, remplace par Dio (US-7.8) |

### Dependances sous-utilisees
| Package | Usage actuel |
|---------|-------------|
| `shared_preferences: ^2.2.3` | 8 appels residuels (devrait passer a 0 via AppDatabase settings) |
| `logger: ^2.6.2` | Declare mais usage minimal (les services utilisent `dart:developer log()`) |

### Dependances critiques
| Package | Version | Etat |
|---------|---------|------|
| `flutter_riverpod: ^3.0.3` | 24 ConsumerStatefulWidget, 14 providers | OK |
| `drift: ^2.22.1` | 10 tables, migration fonctionnelle | OK |
| `go_router: ^17.1.0` | 10 routes actives, 23 Navigator.push restants | En cours |
| `dio: ^5.9.0` | ScryfallApiService centralise | OK |

---

## 7. Score Detaille

| Critere | Note | Commentaire |
|---------|------|-------------|
| Architecture (SRP) | 6/10 | 13 God Files, 0 controllers |
| Tests | 7/10 | 165 tests mais 0 widget tests, ~40% couverture |
| Analyse statique | 7/10 | 0 errors/warnings mais 1033 infos |
| DRY | 5/10 | 327 GoogleFonts, 1373 Colors, 3 upserts dupliques |
| Securite | 8/10 | .gitignore OK, pas de credentials expose |
| Navigation | 6/10 | go_router en place mais 23 Navigator.push restants |
| Gestion d'etat | 7/10 | Riverpod 24/41 widgets, 233 setState |
| CI/CD | 8/10 | flutter analyze + test dans CI |
| Documentation | 9/10 | Sprints documentes, roadmap a jour |
| Bugs corrigés | 9/10 | 2 bugs corriges, 31 risques async |

**Score global : 7.2/10** (revue plus stricte que l'evaluation precedente de 9.0)

---

## 8. Plan d'Actions Franky (par priorite)

### P0 - Sprint 7 (obligatoire)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | Supprimer `http` du pubspec.yaml | 15 min | Nettoyage dep |
| 2 | Extraire 6 controllers Riverpod | 8.5j | Elimine 6 God Files |
| 3 | Corriger 31 `use_build_context_synchronously` | 2h | Stabilite crash |
| 4 | Supprimer 3 champs inutilises + 1 import inutilise | 10 min | 0 warnings |

### P1 - Quick wins (1.5 jours)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 5 | Script auto prefer_single_quotes (585 → 0) | 30 min | -585 infos |
| 6 | Remplacer 181 withOpacity par withValues | 1h | -181 infos |
| 7 | Ajouter curly braces (84 → 0) | 30 min | -84 infos |
| 8 | Supprimer 72 unnecessary `!` | 1h | -72 infos |
| 9 | Corriger 14 empty_catches (logger) | 30 min | -14 infos |
| 10 | Preferer const + final (30 → 0) | 30 min | -30 infos |

### P2 - Sprint 8+ (ameliorations structurelles)

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 11 | Centraliser GoogleFonts dans app_theme (327 → 1) | 2j | DRY majeur |
| 12 | Centraliser Colors dans ThemeData (1373+124 → theme) | 3j | DRY majeur |
| 13 | Migrer 8 SharedPreferences residuels vers AppDatabase | 1j | DIP |
| 14 | Deplacer les requetes DAO de app_database.dart vers daos/ | 2j | SRP |
| 15 | Migrer 17 StatefulWidget → ConsumerStatefulWidget | 2j | DIP |

---

## 9. Verdict Franky

**Etat du Sunny** : Le navire est fonctionnel et solide pour naviguer, mais la coque a besoin d'un bon calfatage. Les 1033 infos sont comme des eclats de peinture -- pas dangereux individuellement, mais ensemble ils masquent les vrais problemes.

**Priorite absolue** : Le Sprint 7 (extraction controllers) resoudra le plus gros probleme architectural (SRP). Les quick wins P1 peuvent etre faits en parallele pour atteindre ~0 infos dans flutter analyze.

**Score cible apres Sprint 7 + quick wins P1** : **9.0/10**
**Score cible apres Sprint 8** : **9.5/10**

*"Un vrai Super navire n'a pas de boulons qui depassent. Chaque info dans flutter analyze est un boulon a resserrer !"* -- Franky, Charpentier
