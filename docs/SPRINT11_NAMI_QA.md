# Sprint 11 - Plan QA : EDHREC Deep Integration
> Agent : Nami (QA Lead) | Date : 01/03/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS

### Resume
- Stack detectee : Flutter / Dart 3.9.2 (Flutter 3.35.6)
- Tests : **368/368 PASS**
- flutter analyze : 0 errors, ~75 warnings, ~890 infos (973 total)
- Controllers existants : **6** (Sprint 7)
- Providers actifs : **20+**
- Base drift SQLite : operationnelle
- Sprint 10 : **TERMINE** (4 features, 368 tests, commit en cours)
- EdhrecService existant : **1 endpoint**, `getRecommendations()` fonctionnel

### Constat de Sante Avant Sprint 11

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter test | 368/368 PASS | OK |
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | ~75 | NON BLOQUANT (Sprint 8 backlog) |
| flutter analyze infos | ~890 | NON BLOQUANT (Sprint 8 backlog) |
| EdhrecService | Fonctionnel (1 endpoint) | OK, base pour enrichissement |
| EdhrecService._formatSlug() | Fonctionnel | OK pour tous les endpoints |
| DeckSuggestionsTab | Fonctionnel (287 lignes) | OK, a refactorer |
| DeckDetailController | 668 lignes, fonctionnel | OK, a enrichir |
| LocalCardService.getCardByName() | Fonctionnel | OK pour resolution noms |

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | EdhrecCardSuggestion, DeckSynergyReport, DeckComboStatus sont des objets structures avec champs accessibles |
| Controlabilite | **Haute** | EdhrecService injecte via Riverpod, Dio mockable, tous les calculs sont deterministes |
| Decomposabilite | **Haute** | Modeles, service, controller et widgets sont 4 couches independantes testables isolement |
| Stabilite | **Moyenne** | API EDHREC non documentee, pas de SLA, structure JSON peut changer |
| Comprehensibilite | **Haute** | Specs Zorro completes avec Gherkin, architecture Sanji detaillee, chaque US a des criteres clairs |

**Implications** : Le Sprint 11 est bien testable pour la logique locale (modeles, controller). Le risque principal est sur la stabilite de l'API EDHREC -- les tests doivent mocker les reponses Dio, pas appeler l'API reelle.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-11.1 : Themes EDHREC | Haut (deckbuilding thematique) | Moyen (parsing JSON, endpoint theme) | P0 | Profond |
| US-11.2 : Score synergie | Tres haut (intelligence deck) | Moyen (calcul local, cross-reference) | P0 | Profond |
| US-11.3 : Combos | Haut (combos detectes) | Moyen (parsing combos, detection) | P1 | Moyen |
| API EDHREC instable | Haut | Haut | P0 | Tests mock |
| Regression suggestions | Haut | Faible | P0 | Automatise |
| Regression 368 tests | Critique | Faible | P0 | Automatise |

### Top 3 Risques Majeurs

1. **Stabilite API EDHREC** : L'API n'a pas de documentation officielle ni de SLA. La structure JSON peut changer sans preavis. Les tests doivent mocker toutes les reponses et le code doit gerer les champs manquants gracieusement (null-safe).

2. **Cross-reference noms cartes** : Le score de synergie du deck necessite de matcher les noms des cartes du deck avec les noms retournes par EDHREC. Les variations (majuscules, accents, double-face) peuvent causer des echecs de matching. Tests necessaires avec des cas edge (double-face, caracteres speciaux).

3. **Volume de donnees combos** : L'endpoint combos peut retourner 3000+ combos pour des commandants populaires. Le parsing et le rendu de 3000 combos sont potentiellement lents. La limite a 50 doit etre testee.

---

## 3. Strategie de Test Globale

### Pyramide de Tests Sprint 11

```
                    /\
                   /  \     3 tests manuels
                  / E2E\    (themes, synergy visuel, combos visuel)
                 /------\
                /        \   ~7 tests widget
               / Widget    \  (suggestions enrichies, combos section)
              /------------\
             /              \  ~33 tests unitaires
            /   Unitaires    \  (modeles, service mock, controller)
           /------------------\
```

### Niveaux de Test

| Niveau | Quoi | Comment | Cible |
|--------|------|---------|-------|
| Unitaire | EdhrecCardSuggestion.fromJson (5 cas) | flutter_test | Parsing correct, null-safe |
| Unitaire | EdhrecTheme.fromJson (3 cas) | flutter_test | Parsing correct, slug extrait |
| Unitaire | EdhrecCombo.fromJson (4 cas) | flutter_test | Parsing correct, cardNames extraits |
| Unitaire | EdhrecCardSuggestion.categoryLabel (3 cas) | flutter_test | Pick specifique, Staple, Standard |
| Unitaire | EdhrecService.getCommanderData (5 cas mock) | flutter_test + mock Dio | Parsing complet, themes, cache |
| Unitaire | EdhrecService.getThemeCards (3 cas mock) | flutter_test + mock Dio | Cartes theme, cache, erreur |
| Unitaire | EdhrecService.getCommanderCombos (4 cas mock) | flutter_test + mock Dio | Combos, limit 50, cache, erreur |
| Unitaire | DeckDetailController.generateSynergyReport (4 cas) | flutter_test | Score global, cross-reference, vide, pas Commander |
| Unitaire | DeckDetailController.detectCombos (5 cas) | flutter_test | Complete, partial, none, tri, vide |
| Widget | DeckSuggestionsTab enrichi (3 cas) | flutter_test | Themes affiches, synergy affiches |
| Widget | DeckCombosSection (2 cas) | flutter_test | Combos affiches, badges |
| Manuel | Themes EDHREC visuel | Test app | Chips, chargement, retour |
| Manuel | Synergy score visuel | Test app | Bandeau, couleurs, tri |
| Manuel | Combos visuel | Test app | Section, badges, cartes manquantes |

### Criteres d'Entree Sprint 11
- 368 tests PASS (confirme)
- flutter analyze : 0 errors (confirme)
- EdhrecService.getRecommendations() fonctionnel (confirme)
- DeckSuggestionsTab fonctionnel (confirme)
- DeckDetailController fonctionnel (confirme)
- LocalCardService.getCardByName() fonctionnel (confirme)

### Criteres de Sortie Sprint 11
- **>= 400 tests** PASS (368 + ~40 nouveaux)
- **flutter analyze : 0 errors** (les warnings/infos pre-existants sont toleres)
- **Themes** : affiches pour les commandants avec taglinks, cliquables, cartes chargees
- **Synergie** : score par carte et score global affiches
- **Combos** : top 50 affiches, detection dans le deck, cartes manquantes identifiees
- **Regression** : 0 test casse
- **Fallback** : si API EDHREC indisponible, suggestions de base toujours accessibles

---

## 4. Scenarios de Test

### Chemin Nominal (Happy Path)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-11.01 | EdhrecCardSuggestion.fromJson parse correctement | Unit | 11.1 | JSON valide avec synergy, inclusion | fromJson(json) | Tous les champs remplis | P0 |
| T-11.02 | EdhrecTheme.fromJson extrait le slug | Unit | 11.1 | JSON avec href "/themes/atraxa/infect" | fromJson(json) | slug = "infect" | P0 |
| T-11.03 | EdhrecCombo.fromJson parse les cardNames et results | Unit | 11.3 | JSON combo avec cardviews et results | fromJson(json) | cardNames et results corrects | P0 |
| T-11.04 | categoryLabel retourne "Pick specifique" pour haute synergie | Unit | 11.2 | synergy = 0.35 | .categoryLabel | "Pick specifique" | P0 |
| T-11.05 | categoryLabel retourne "Staple generique" | Unit | 11.2 | synergy = 0.01, inclusion = 95 | .categoryLabel | "Staple generique" | P0 |
| T-11.06 | getCommanderData parse les themes | Unit | 11.1 | Mock Dio avec reponse Atraxa | getCommanderData("Atraxa") | themes non vide, categories remplies | P0 |
| T-11.07 | getThemeCards charge les cartes d'un theme | Unit | 11.1 | Mock Dio avec reponse theme Infect | getThemeCards("Atraxa", "infect") | Liste de suggestions non vide | P0 |
| T-11.08 | getCommanderCombos limite a 50 | Unit | 11.3 | Mock Dio avec 100 combos | getCommanderCombos("Atraxa") | max 50 combos retournes | P0 |
| T-11.09 | generateSynergyReport score global correct | Unit | 11.2 | Deck avec 3 cartes matchees | generateSynergyReport() | Score entre 0-100, entries non vide | P0 |
| T-11.10 | detectCombos identifie combo complet | Unit | 11.3 | Deck contient toutes les cartes d'un combo | detectCombos() | completeness = complete | P0 |
| T-11.11 | detectCombos identifie combo partiel | Unit | 11.3 | Deck contient 1/2 cartes d'un combo | detectCombos() | completeness = partial, missing = 1 | P0 |
| T-11.12 | detectCombos trie correctement | Unit | 11.3 | Mix de complets, partiels, none | detectCombos() | Complets en premier, puis partiels | P0 |

### Cas aux Limites (Edge Cases)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-11.13 | fromJson avec champs manquants | Unit | 11.1 | JSON avec synergy null | fromJson(json) | synergy = 0.0, pas de crash | P0 |
| T-11.14 | getCommanderData commandant inconnu | Unit | 11.1 | Mock Dio retourne 404 | getCommanderData("xxx") | EdhrecCommanderData.empty | P0 |
| T-11.15 | getCommanderData pas de taglinks | Unit | 11.1 | JSON sans taglinks | getCommanderData() | themes = [] | P1 |
| T-11.16 | getCommanderCombos pas de combos | Unit | 11.3 | Mock Dio retourne JSON sans cardlists | getCombos() | [] | P1 |
| T-11.17 | generateSynergyReport deck vide | Unit | 11.2 | Deck sans cartes | generateSynergyReport() | Score = 50 (neutre), entries vide | P0 |
| T-11.18 | generateSynergyReport pas Commander | Unit | 11.2 | Deck Standard sans commandant | generateSynergyReport() | return null | P0 |
| T-11.19 | detectCombos aucun match | Unit | 11.3 | Deck sans carte commune avec combos | detectCombos() | Tous completeness = none | P1 |
| T-11.20 | Cross-reference noms case-insensitive | Unit | 11.2 | Deck a "sol ring", EDHREC a "Sol Ring" | generateSynergyReport() | Match trouve | P0 |
| T-11.21 | Cache EdhrecService retourne cache valide | Unit | 11.1 | 2 appels < 1h | getCommanderData() x2 | 2eme appel = cache, pas de requete Dio | P0 |
| T-11.22 | Cache EdhrecService expire apres 1h | Unit | 11.1 | Appel > 1h apres | getCommanderData() | Nouvelle requete Dio | P1 |
| T-11.23 | Themes filtres par minimum 50 decks | Unit | 11.1 | JSON avec themes de 10 et 500 decks | getCommanderData() | Seul le theme 500 decks est retourne | P1 |
| T-11.24 | Combo avec carte double-face | Unit | 11.3 | Deck a "Delver of Secrets", combo a "Delver of Secrets // Insectile Aberration" | detectCombos() | Match gere correctement | P2 |

### Tests Negatifs

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-11.30 | API EDHREC timeout | Unit | 11.1 | Mock Dio throw DioException timeout | getCommanderData() | Return empty, pas de crash | P0 |
| T-11.31 | API EDHREC retourne HTML au lieu de JSON | Unit | 11.1 | Mock Dio retourne contenu non-JSON | getCommanderData() | Return empty, pas de crash | P1 |
| T-11.32 | JSON structure inattendue (pas de container) | Unit | 11.1 | JSON sans "container" | getCommanderData() | Return empty, pas de crash | P0 |
| T-11.33 | Combo JSON sans cardviews | Unit | 11.3 | Section combo sans "cardviews" | EdhrecCombo.fromJson() | cardNames = [] | P1 |
| T-11.34 | Theme slug vide | Unit | 11.1 | Theme avec href vide | EdhrecTheme.fromJson() | slug = "", pas de crash | P1 |

---

## 5. Specifications BDD/Gherkin Detaillees

### Scenario 1 : Themes + cartes thematiques

```gherkin
Fonctionnalite: Themes EDHREC pour un commandant
  Plan du Scenario: Charger et selectionner un theme
    Etant donne un deck Commander "Atraxa, Praetors' Voice"
    Et que l'API EDHREC retourne les themes :
      | Nom | Decks |
      | Infect | 6284 |
      | Planeswalkers | 3654 |
      | +1/+1 Counters | 2790 |
    Quand l'utilisateur charge les suggestions
    Alors 3 chips de themes sont affiches
    Quand l'utilisateur clique sur "Infect"
    Alors les suggestions changent pour les cartes du theme Infect
    Et chaque carte affiche son score de synergie
```

### Scenario 2 : Score de synergie global

```gherkin
Fonctionnalite: Score de synergie global du deck
  Scenario: Deck avec bonnes synergies
    Etant donne un deck Commander avec 5 cartes matchees dans EDHREC :
      | Carte | Synergy |
      | Sword of Truth | +0.35 |
      | Atraxa's Fall | +0.28 |
      | Sol Ring | -0.05 |
      | Arcane Signet | -0.02 |
      | Gyre Sage | +0.22 |
    Quand le rapport de synergie est genere
    Alors le score global est calcule (environ 66/100)
    Et les cartes sont triees par synergie decroissante
    Et "Sword of Truth" est labellee "Pick specifique"
    Et "Sol Ring" est labellee "Staple generique"
```

### Scenario 3 : Detection de combos

```gherkin
Fonctionnalite: Detection de combos dans le deck
  Scenario: Combo complet dans le deck
    Etant donne un deck contenant "Exquisite Blood" et "Sanguine Bond"
    Et que le combo "Exquisite Blood + Sanguine Bond" est dans EDHREC
    Quand les combos sont analyses
    Alors ce combo est "Dans votre deck" (completeness = complete)
    Et il apparait en premier dans la liste

  Scenario: Combo partiel (1 carte manquante)
    Etant donne un deck contenant "Exquisite Blood" mais pas "Sanguine Bond"
    Quand les combos sont analyses
    Alors ce combo est "1 carte manquante" (completeness = partial)
    Et "Sanguine Bond" est listee comme manquante
    Et il apparait apres les combos complets
```

---

## 6. Strategie d'Automatisation

### Tests Automatises (CI/CD)

| Type | Framework | Quoi | CI |
|------|-----------|------|----|
| Unitaire modeles | flutter_test | EdhrecCardSuggestion/Theme/Combo fromJson (12 tests) | Oui |
| Unitaire modeles | flutter_test | categoryLabel (3 tests) | Oui |
| Unitaire service | flutter_test + mock Dio | getCommanderData, getThemeCards, getCombos (12 tests) | Oui |
| Unitaire controller | flutter_test | synergyReport, detectCombos (9 tests) | Oui |
| Widget | flutter_test | DeckSuggestionsTab enrichi (3 tests) | Oui |
| Widget | flutter_test | DeckCombosSection (2 tests) | Oui |

### Tests Manuels

| Type | Quoi | Quand |
|------|------|-------|
| Fonctionnel | Themes chips + chargement par theme | Apres US-11.1 |
| Fonctionnel | Retour aux suggestions generales | Apres US-11.1 |
| Visuel | Score synergie bandeau + couleurs | Apres US-11.2 |
| Visuel | Labels "Pick specifique" / "Staple" | Apres US-11.2 |
| Fonctionnel | Section combos avec badges | Apres US-11.3 |
| Fonctionnel | Combos partiels avec cartes manquantes | Apres US-11.3 |
| Regression | Onglet Suggestions sans commandant | Apres toutes US |

### CI/CD Pipeline

Le pipeline existant (`flutter analyze` + `flutter test`) suffit. Aucune modification necessaire.

---

## 7. Plan de Tests Non-Fonctionnels

### Performance

| Test | Cible | Methode |
|------|-------|---------|
| Parsing JSON commander (gros payload Atraxa) | < 50ms | Stopwatch dans le test |
| Parsing 50 combos | < 20ms | Stopwatch |
| generateSynergyReport (100 cartes deck) | < 10ms | Stopwatch |
| detectCombos (100 cartes deck x 50 combos) | < 10ms | Stopwatch |
| Cache hit (2eme appel) | < 1ms | Stopwatch |

### Compatibilite

- `EdhrecModels` est un fichier de modeles pur Dart sans dependance Flutter -> testable en Dart pur
- `EdhrecService` utilise Dio (deja present) -> mockable
- Les calculs de synergie et combos sont des fonctions pures
- Aucun nouveau package ajoute

### Regression

- Les 368 tests existants doivent rester verts a 100%
- La methode `getRecommendations()` existante est conservee pour retrocompatibilite
- Le widget `DeckSuggestionsTab` est refactorise mais le comportement de base est preserve
- Le DeckDetailController est enrichi (ajout de methodes), pas modifie (les methodes existantes ne changent pas)

---

## 8. Matrice de Verification par US

| US | Verification Automatisee | Verification Manuelle | Critere PASS |
|----|--------------------------|----------------------|--------------|
| US-11.1 | 12 tests service + 5 tests modeles + 3 tests widget | Themes chips, chargement, retour | Themes affiches, cartes par theme correctes |
| US-11.2 | 4 tests synergie controller + 3 tests modeles | Bandeau score, labels, couleurs | Score global et par carte corrects |
| US-11.3 | 5 tests combos controller + 4 tests modeles + 2 tests widget | Section combos, badges, manquantes | Combos detectes, tries, badges corrects |
| Regression | 368 tests existants | - | 0 test casse |
| **Total** | **~40 tests automatises** | **7 sessions manuelles** | |

---

## 9. Checklist de Validation Sprint 11

```bash
# Verification rapide apres chaque modification
flutter analyze                    # Cible : 0 errors (warnings/infos toleres)
flutter test                       # Cible : >= 400 tests, 0 fail

# Verification des features
# US-11.1 : Themes chips affiches + cartes chargees par theme + retour
# US-11.2 : Score synergie global + score par carte + labels categorie
# US-11.3 : Section combos + badges dans le deck + cartes manquantes
```

### Criteres d'Acceptation Globaux Sprint 11

| # | Critere | Methode de verification | Cible |
|---|---------|------------------------|-------|
| 1 | flutter test | `flutter test` | >= 400 tests, 0 fail |
| 2 | flutter analyze errors | `flutter analyze` | 0 errors |
| 3 | Themes EDHREC | Test fonctionnel | Chips affiches, cartes par theme |
| 4 | Score synergie par carte | Test fonctionnel | Badge colore par carte |
| 5 | Score synergie global | Test fonctionnel | Bandeau avec score 0-100 |
| 6 | Labels categorie | Test fonctionnel | "Pick specifique" / "Staple" |
| 7 | Combos detectes | Test fonctionnel | Top 50 affiches |
| 8 | Combos dans le deck | Test fonctionnel | Badge "Dans votre deck" / "1 carte manquante" |
| 9 | Fallback API indisponible | Test fonctionnel | Suggestions de base accessibles |
| 10 | Retrocompatibilite | 368 tests existants | 0 test casse |

---

## 10. Strategie de Non-Regression

Le Sprint 11 enrichit le service EDHREC existant et refactorise le widget DeckSuggestionsTab. La strategie de non-regression est :

1. **Avant chaque US** : Verifier que `flutter test` passe (368 tests)
2. **Apres chaque US** : Verifier que `flutter test` passe (368 + nouveaux tests)
3. **getRecommendations() conservee** : La methode existante n'est pas supprimee, elle reste fonctionnelle
4. **DeckSuggestionsTab** : Le comportement de base (bouton charger, liste de cartes, navigation vers detail) est preserve
5. **DeckDetailController** : Nouvelles methodes ajoutees, anciennes methodes inchangees
6. **Aucun impact sur** : Import/export, legalite, collection, recherche, tous les autres onglets

### Points d'attention specifiques

- Le parsing JSON EDHREC doit etre 100% null-safe (tout champ peut etre absent)
- Le cache doit etre thread-safe (pas de race condition sur les writes)
- La methode `_formatSlug()` doit gerer les memes edge cases que pour `getRecommendations()`
- Le score de synergie global doit gerer le cas 0 cartes matchees (retourner 50, pas NaN)

*"Chaque berri compte ! 3 features, ~40 tests, 0 regression. Le tresor du Sprint 11, c'est l'intelligence -- les joueurs ne se contentent plus de stocker des decks, ils les optimisent. Les themes guident la construction. La synergie mesure la coherence. Les combos revelent les plans de victoire. Et tout ca, avec des donnees en cache qui respectent les limites API. C'est du profit sans risque."* -- Nami, QA Lead
