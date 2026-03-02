# Sprint 8 - Plan QA : Widgets, Qualite & Polish
> Agent : Nami (QA Lead) | Date : 28/02/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS

### Resume
- Stack detectee : Flutter / Dart 3.9.2 (Flutter 3.35.6)
- Tests : **273/273 PASS**
- flutter analyze : 0 errors, **75 warnings**, **966 infos** (1041 total)
- Fichiers >500 lignes (hors genere) : **17**

### Constat de Sante Avant Sprint 8

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter test | 273/273 PASS | OK |
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | 75 (74 unnecessary_non_null_assertion + 1 unused_field) | A CORRIGER |
| flutter analyze infos | 966 | A CORRIGER |
| Fichiers pages >500 lignes | 5 | A CORRIGER |
| Fichiers widgets >500 lignes | 5 | A CORRIGER |
| Controllers existants (Sprint 7) | 6 | OK |

### Avertissement

**Flutter 3.35.6** (Dart 3.9.2) est utilise. La methode `.withValues()` est disponible (introduite dans Flutter 3.27). La migration `.withOpacity()` -> `.withValues()` est viable.

**Note** : Les 75 warnings (unnecessary_non_null_assertion) sont classes comme MEDIUM dans l'analyse. Ils ne bloquent pas le build mais degradent la qualite et doivent etre traites en Sprint 8.

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | Riverpod StateNotifiers exposent l'etat ; flutter analyze disponible ; 273 tests existants |
| Controlabilite | **Haute** | Les services sont injectables via Riverpod ; les controllers ont des methodes publiques testables |
| Decomposabilite | **Moyenne** | Les 6 controllers pages sont separes, mais 4 widgets sont encore monolithiques. Sprint 8 ameliorera cette note |
| Stabilite | **Haute** | L'API Scryfall est stable ; les modeles internes sont figes depuis Sprint 4 |
| Comprehensibilite | **Haute** | Specs Zorro completes pour chaque US ; architecture documentee par Sanji |

**Implications** : Le Sprint 8 est un sprint de refactoring pur avec un filet de securite solide (273 tests). La testabilite est bonne pour les controllers existants. Les nouveaux controllers widgets seront testables des leur creation.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-8.1 : flutter analyze cleanup | Bas | Moyen (withOpacity migration) | P1 | Moyen |
| US-8.2 : DeckCardPickerController | Haut (fonctionnalite critique) | Haut (774 lignes, recherche+pagination) | P0 | Profond |
| US-8.2 : CollectionListController | Haut (collection = feature core) | Moyen (filtrage/tri local) | P0 | Profond |
| US-8.2 : PlayerZoneController | Moyen (life counter) | Moyen (timers, animations) | P1 | Moyen |
| US-8.2 : DeckStatsController | Bas (lecture seule, stats) | Bas (calculs purs, deterministes) | P2 | Leger |
| US-8.3 : Extraction sous-widgets pages | Moyen | Haut (5 pages, regression UI) | P0 | Moyen |
| US-8.4 : Decoupage routeur | Bas | Moyen (navigation, ShellRoute) | P1 | Moyen |
| US-8.5 : Centralisation theme | Bas | Moyen (regression visuelle) | P2 | Leger |

### Top 3 Risques Majeurs

1. **Regression UI lors extraction sous-widgets de set_detail_page** (1039 -> <400 lignes) : le plus gros fichier, le plus de sous-widgets a extraire, le plus de parametres a passer.
2. **DeckCardPickerController casse la recherche/pagination** : logique complexe avec debounce, pagination API, pagination locale, cache. Erreur = fonctionnalite cassee.
3. **Migration withOpacity casse les opacites visuelles** : le facteur passe de 0.0-1.0, mais certains `.withOpacity()` pourraient utiliser une convention differente. Verification visuelle necessaire.

---

## 3. Strategie de Test Globale

### Pyramide de Tests Sprint 8

```
                    /\
                   /  \     2 tests manuels navigation (routeur)
                  / E2E\    + verification visuelle theme
                 /------\
                /        \   ~8 tests integration
               / Integr.  \  (controllers + services mock)
              /------------\
             /              \  ~24 tests unitaires
            /   Unitaires    \  (4 controllers x 6 tests moy.)
           /------------------\
```

### Niveaux de Test

| Niveau | Quoi | Comment | Cible |
|--------|------|---------|-------|
| Unitaire | 4 controllers widgets (logique pure) | flutter_test, mock services | ~24 tests |
| Unitaire | Theme (AppTextStyles, AppColors) | flutter_test | ~5 tests |
| Integration | Controllers + services | flutter_test avec vrais services mockes | ~8 tests |
| Systeme | Navigation (23 routes apres decoupage) | Test manuel | 1 session |
| Visuel | Theme (couleurs, fonts apres migration) | Revue manuelle screenshots | 1 session |

### Criteres d'Entree Sprint 8
- 273 tests PASS (confirme)
- flutter analyze : 0 errors (confirme)
- Sprint 7 controllers stables (confirme)

### Criteres de Sortie Sprint 8
- **>300 tests** PASS (273 + ~32 nouveaux)
- **flutter analyze : 0 issues** (0 errors, 0 warnings, 0 infos)
- **0 fichier page >500 lignes**
- **0 fichier widget >500 lignes** (hors game_setup_modal si reporte)
- **10 controllers Riverpod** (6 + 4)
- **app_router.dart <200 lignes**

---

## 4. Scenarios de Test

### Chemin Nominal (Happy Path)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-8.01 | DeckCardPicker recherche API fonctionne | Unit | 8.2 | Controller instancie, service mocke | Appeler search("Lightning Bolt") | State.apiResults contient des resultats, isSearching passe a false | P0 |
| T-8.02 | DeckCardPicker pagination locale | Unit | 8.2 | Collection chargee (30+ cartes) | Appeler loadMoreLocalResults() | displayedCollection grossit de pageSize items | P0 |
| T-8.03 | CollectionList filtrage par type | Unit | 8.2 | Liste de cartes chargee | Appeler filter(SearchFilters(cardType: "Creature")) | filteredCards ne contient que des creatures | P0 |
| T-8.04 | CollectionList tri par prix | Unit | 8.2 | Liste filtree | Appeler sort("price") | Cartes triees par prix decroissant | P1 |
| T-8.05 | DeckStats mana curve correcte | Unit | 8.2 | Deck avec 60 cartes variees | Verifier manaCurveData | Distribution correcte par CMC | P1 |
| T-8.06 | PlayerZone mode switch | Unit | 8.2 | Controller instancie | Appeler setEditMode(CounterMode.poison) | state.editMode == CounterMode.poison | P1 |
| T-8.07 | Navigation post-decoupage routeur | Manuel | 8.4 | App lancee | Naviguer vers chaque ecran principal | Toutes les 23 routes accessibles | P0 |

### Cas aux Limites (Edge Cases)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-8.10 | DeckCardPicker recherche vide | Unit | 8.2 | Controller instancie | Appeler search("") | Pas de requete API, state inchange | P0 |
| T-8.11 | DeckCardPicker pagination fin de resultats | Unit | 8.2 | nextApiPageUrl == null | Appeler loadMoreApiResults() | Pas de requete, isApiLoadingMore reste false | P0 |
| T-8.12 | CollectionList liste vide | Unit | 8.2 | Aucune carte | Appeler filter(any) | filteredCards vide, pas d'erreur | P1 |
| T-8.13 | DeckStats deck vide | Unit | 8.2 | mainboard vide | Verifier averageCmc | averageCmc == 0.0, pas de division par zero | P0 |
| T-8.14 | DeckStats carte LOCAL: ignoree | Unit | 8.2 | Carte avec scryfallId "LOCAL:xxx" | Calculer stats | Carte ignoree dans les stats | P1 |
| T-8.15 | PlayerZone auto-return timer | Unit | 8.2 | Mode poison actif | Attendre 5 secondes (timer) | Retour automatique au mode vie | P2 |
| T-8.16 | withOpacity migration 0.5 | Unit | 8.1 | Widget utilisant .withOpacity(0.5) | Remplacer par .withValues(alpha: 0.5) | Meme apparence visuelle | P1 |

### Tests Negatifs

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-8.20 | DeckCardPicker erreur API | Unit | 8.2 | Service API retourne une erreur | Appeler search("xxx") | state.error rempli, isSearching = false, pas de crash | P0 |
| T-8.21 | CollectionList carte sans scryfallCard (base locale) | Unit | 8.2 | Carte collection sans equivalent dans localCardService | Appeler filter avec filtres avances | Carte ignoree, pas de crash | P1 |
| T-8.22 | DeckStats prix null | Unit | 8.2 | Carte sans prix dans scryfallCard.prices | Calculer totalPrice | Prix = 0 pour cette carte, pas de crash | P1 |
| T-8.23 | Route invalide apres decoupage | Manuel | 8.4 | App lancee | Naviguer vers une route inexistante | Page 404 ou redirect vers home | P1 |
| T-8.24 | Theme manquant (AppTextStyles sans GoogleFonts fallback) | Unit | 8.5 | GoogleFonts non chargee (offline) | Appeler AppTextStyles.heading | Fallback correct, pas de crash | P2 |

---

## 5. Specifications BDD/Gherkin

### Scenario 1 : DeckCardPicker recherche avec pagination

```gherkin
Fonctionnalite: Recherche de cartes dans le DeckCardPicker
  Contexte:
    Etant donne que le DeckCardPickerController est instancie
    Et que ScryfallApiService est disponible

  Scenario: Recherche API retourne des resultats
    Etant donne que l'API Scryfall contient des cartes pour "Lightning"
    Quand l'utilisateur recherche "Lightning"
    Alors apiResults contient au moins 1 resultat
    Et isSearching est false
    Et totalApiResults est superieur a 0

  Scenario: Pagination charge la page suivante
    Etant donne que la recherche "Lightning" a retourne des resultats
    Et que nextApiPageUrl est non null
    Quand l'utilisateur scrolle jusqu'en bas
    Alors de nouveaux resultats sont ajoutes a apiResults
    Et isApiLoadingMore passe a true puis false
```

### Scenario 2 : DeckStats calculs corrects

```gherkin
Fonctionnalite: Calcul des statistiques de deck
  Contexte:
    Etant donne que le deck contient des cartes avec des donnees Scryfall

  Plan du Scenario: Mana curve correcte
    Etant donne que le deck contient <count> cartes de CMC <cmc>
    Quand les stats sont calculees
    Alors manaCurveData[<bucket>] vaut <count>

    Exemples:
      | count | cmc | bucket |
      | 4     | 1   | 1      |
      | 8     | 2   | 2      |
      | 6     | 3   | 3      |
      | 2     | 8   | 7      |

  Scenario: Deck vide ne crashe pas
    Etant donne que le deck est vide (0 cartes)
    Quand les stats sont calculees
    Alors averageCmc vaut 0.0
    Et totalPrice vaut 0.0
    Et manaCurveData est tout a zero
```

### Scenario 3 : flutter analyze zero issues

```gherkin
Fonctionnalite: Analyse statique propre
  Scenario: Aucune issue apres nettoyage
    Etant donne que le nettoyage US-8.1 a ete applique
    Quand flutter analyze est execute
    Alors le resultat est "No issues found"
    Et 0 errors, 0 warnings, 0 infos

  Scenario: Tests toujours verts apres nettoyage
    Etant donne que le nettoyage US-8.1 a ete applique
    Quand flutter test est execute
    Alors tous les 273 tests passent
```

### Scenario 4 : Navigation apres decoupage routeur

```gherkin
Fonctionnalite: Navigation apres refactoring routeur
  Scenario: Toutes les routes principales accessibles
    Etant donne que app_router.dart a ete decoupe en sous-routeurs
    Quand l'utilisateur navigue vers chacune des 23 routes
    Alors chaque page s'affiche correctement
    Et le bouton retour fonctionne
    Et le Drawer est accessible depuis la ShellRoute

  Scenario: Deep link fonctionne
    Etant donne que app_router.dart est decoupe
    Quand l'app recoit un deep link "/decks/deck-detail?id=xxx"
    Alors la page DeckDetailPage s'affiche avec le bon deck
```

### Scenario 5 : Extraction sous-widgets sans regression

```gherkin
Fonctionnalite: Pages allègees par extraction de sous-widgets
  Scenario: set_detail_page sous 400 lignes
    Etant donne que set_detail_page.dart contient 1039 lignes
    Quand les sous-widgets sont extraits (filter modal, card tile, stats header, bottom bar, control bar)
    Alors set_detail_page.dart contient moins de 400 lignes
    Et l'affichage du detail de set est identique visuellement
    Et les 273 tests passent toujours
```

---

## 6. Strategie d'Automatisation

### Tests Automatises (CI/CD)

| Type | Framework | Quoi | CI |
|------|-----------|------|----|
| Unitaire controllers | flutter_test | 4 controllers widgets (24 tests) | Oui (flutter test) |
| Unitaire theme | flutter_test | AppTextStyles, AppColors (5 tests) | Oui |
| Integration | flutter_test + mocks | Controllers + services (8 tests) | Oui |
| Analyse statique | flutter analyze | 0 issues | Oui (deja dans CI) |

### Tests Manuels

| Type | Quoi | Quand |
|------|------|-------|
| Navigation | 23 routes apres decoupage routeur | Apres US-8.4 |
| Visuel | Couleurs et fonts apres migration theme | Apres US-8.5 |
| Regression UI | Toutes les pages apres extraction sous-widgets | Apres US-8.3 |

### CI/CD Pipeline

Le pipeline existant (`.github/workflows/build-main.yml`) doit deja executer `flutter analyze` et `flutter test`. Aucune modification necessaire pour le Sprint 8.

**Ajout recommande** : Ajouter un seuil `--fatal-infos` a flutter analyze dans le CI pour echouer si des infos apparaissent (apres US-8.1).

---

## 7. Plan de Tests Non-Fonctionnels

### Performance
- Les calculs de DeckStatsController doivent s'executer en <100ms pour un deck de 100 cartes
- La recherche locale dans DeckCardPickerController doit rester <50ms (deja optimise via Isolate)
- Pas de regression de performance apres extraction controllers (mesurer avant/apres si doute)

### Compatibilite
- Flutter 3.35.6 (Dart 3.9.2) : `.withValues()` disponible
- Android SDK min : a verifier dans android/app/build.gradle
- iOS : pas de contrainte specifique pour ce sprint

### Accessibilite
- Pas de regression : les sous-widgets extraits doivent conserver les semantics existants
- La centralisation du theme (US-8.5) ne doit pas degrader les contrastes

---

## 8. Matrice de Verification par US

| US | Verification Automatisee | Verification Manuelle | Critere PASS |
|----|--------------------------|----------------------|--------------|
| US-8.1 | `flutter analyze` = 0 issues | - | 0 errors + 0 warnings + 0 infos |
| US-8.1 | `flutter test` = 273 PASS | - | Tous verts |
| US-8.2 | Tests unitaires controllers (24+) | - | Tous PASS |
| US-8.2 | Widgets <350 lignes (wc -l) | - | 4 widgets sous seuil |
| US-8.3 | `flutter test` toujours vert | Verification visuelle 5 pages | Toutes pages <400 lignes |
| US-8.4 | `flutter test` toujours vert | Navigation 23 routes | app_router.dart <200 lignes |
| US-8.5 | Tests theme (5+) | Verification visuelle globale | GoogleFonts directs <60 |

---

## 9. Checklist de Validation Sprint 8

A executer a la fin de chaque US et en fin de sprint :

```bash
# Verification rapide apres chaque modification
flutter analyze                    # Cible : 0 issues
flutter test                       # Cible : >300 tests, 0 fail

# Mesure des metriques
find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | sort -rn | awk '$1 > 500 {print}'
grep -r "GoogleFonts" lib/ --include="*.dart" | wc -l
grep -r "withOpacity" lib/ --include="*.dart" | wc -l
wc -l lib/router/app_router.dart
```

### Criteres d'Acceptation Globaux Sprint 8

| # | Critere | Methode de verification | Cible |
|---|---------|------------------------|-------|
| 1 | flutter analyze : 0 issues | `flutter analyze` | 0 |
| 2 | Tests >300 | `flutter test` | >300 |
| 3 | 0 fichier page >500 lignes | `wc -l lib/pages/**/*.dart` | 0 |
| 4 | 0 fichier widget >500 lignes | `wc -l lib/widgets/**/*.dart` | 0 |
| 5 | 10 controllers Riverpod | `ls lib/controllers/` | 10 |
| 6 | app_router.dart <200 lignes | `wc -l lib/router/app_router.dart` | <200 |
| 7 | GoogleFonts directs <60 | `grep -r "GoogleFonts" lib/ \| wc -l` | <60 |
| 8 | 0 .withOpacity() | `grep -r "withOpacity" lib/ \| wc -l` | 0 |
| 9 | Score qualite | Evaluation globale | 9.5/10 |

*"1041 issues, c'est 1041 fuites dans la coque du Sunny. Chaque fuite colmatee, c'est 1000 berrys d'economie. A la fin du Sprint 8, plus une goutte d'eau ne passera !"* -- Nami, QA Lead
