# Sprint 12 - Plan QA : Features Avancees, Refactoring & Backlog Technique
> Agent : Nami (QA Lead) | Date : 01/03/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS

### Resume
- Stack detectee : Flutter / Dart 3.9.2 (Flutter 3.35.6)
- Tests : **433/433 PASS**
- flutter analyze : 0 errors, 0 warnings, ~982 infos
- Controllers existants : **6** (Sprint 7) + logique Sprint 11 dans DeckDetailController
- Providers actifs : **20+**
- Base drift SQLite : operationnelle
- Sprint 11 : **TERMINE** (3 features EDHREC, 433 tests, +65 nouveaux)
- Services existants : ScryfallApiService (rulings deja implementes), EdhrecService (3 endpoints)

### Constat de Sante Avant Sprint 12

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter test | 433/433 PASS | OK |
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | 0 | OK |
| flutter analyze infos | ~982 | NON BLOQUANT |
| ScryfallApiService.getCardRulings() | Fonctionnel | OK, pret a integrer |
| ScryfallApiService.searchCards(lang:) | Parametre supporte | OK, pret a exposer |
| EdhrecService (Sprint 11) | 3 endpoints, cache 1h | OK, base pour salt |
| EdhrecCardSuggestion | synergy, inclusion | OK, ajouter salt |
| CardSearchController | 606 lignes | OK, a enrichir |
| CardDetailController | 552 lignes | OK, a enrichir |
| GameSetupModal | 507 lignes | OK, a extraire |

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | DeckPowerLevel, ScryfallRuling, SearchFilters sont des objets structures testables |
| Controlabilite | **Haute** | Tous les services injectes via Riverpod, Dio mockable, calculs deterministes |
| Decomposabilite | **Haute** | Modeles, services, controllers et widgets sont 4 couches independantes |
| Stabilite | **Haute** | API Scryfall documentee et stable ; EDHREC moins stable mais Sprint 11 a demontre la resilience |
| Comprehensibilite | **Haute** | Specs Zorro completes avec Gherkin, architecture Sanji detaillee |

**Implications** : Sprint 12 est bien testable. Les features (syntaxe, power level, salt, rulings, multilangue) sont principalement de la logique locale testable en unitaire. Le refactoring Colors est un risque de regression visuelle mais pas de regression fonctionnelle.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-12.1 : Syntaxe Scryfall | Haut (joueurs avances) | Moyen (regex detection) | P0 | Profond |
| US-12.2 : Power Level | Tres haut (intelligence deck) | Haut (heuristique complexe) | P0 | Tres profond |
| US-12.3 : Salt Score | Moyen (indicateur social) | Faible (ajout champ) | P0 | Standard |
| US-12.4 : Rulings | Haut (reference regles) | Faible (service existe) | P0 | Standard |
| US-12.5 : Multilangue | Moyen (joueurs non-EN) | Faible (param existe) | P1 | Standard |
| US-12.6 : Colors/Fonts | Interne | Tres haut (1625 occ.) | P0 | Regression visuelle |
| US-12.7 : GameSetupModal | Interne | Moyen (extraction) | P1 | Standard |
| Regression 433 tests | Critique | Faible | P0 | Automatise |

### Top 3 Risques Majeurs

1. **Regression visuelle Colors** : Remplacer 1625 occurrences de couleurs dans 58+ fichiers est l'operation la plus risquee. Chaque remplacement peut changer subtillement l'apparence. Mitigation : migration par lots avec review visuelle apres chaque lot.

2. **Power Level mal calibre** : L'heuristique est subjective et les joueurs ont des opinions fortes sur le power level. Mitigation : documenter les facteurs et leurs poids, rendre la formule transparente, prevoir un ajustement futur.

3. **Syntaxe Scryfall edge cases** : La syntaxe Scryfall est riche (>50 operateurs). La detection doit etre fiable pour ne pas envoyer une recherche par nom comme syntaxe avancee (et vice versa). Mitigation : regex conservatrice, tests exhaustifs.

---

## 3. Strategie de Test Globale

### Pyramide de Tests Sprint 12

```
                      /\
                     /  \     5 tests manuels
                    / E2E\    (syntaxe, power level, rulings, multilangue, visuel)
                   /------\
                  /        \   ~10 tests widget
                 / Widget    \  (syntax help, rulings section, power badge)
                /------------\
               /              \  ~62 tests unitaires
              /   Unitaires    \  (syntaxe, power level, salt, rulings, game setup, bulk data)
             /------------------\
```

### Niveaux de Test

| Niveau | Quoi | Comment | Cible |
|--------|------|---------|-------|
| Unitaire | isAdvancedScryfallSyntax (10 cas) | flutter_test | Detection fiable |
| Unitaire | estimatePowerLevel (12 cas) | flutter_test | Heuristique correcte |
| Unitaire | EdhrecCardSuggestion.salt (3 cas) | flutter_test | Parsing salt correct |
| Unitaire | loadRulings (5 cas) | flutter_test + mock | Rulings charges |
| Unitaire | Multilangue searchApi (5 cas) | flutter_test | Lang passee a l'API |
| Unitaire | GameSetupModalController (20 cas) | flutter_test | Logique extraite |
| Unitaire | BulkDataService (10 cas) | flutter_test + mock Dio | Download/update |
| Widget | ScryfallSyntaxHelp (3 cas) | flutter_test | Modal d'aide affichee |
| Widget | RulingsSection (5 cas) | flutter_test | Rulings affiches |
| Widget | DeckPowerLevelBadge (3 cas) | flutter_test | Badge correct |
| Manuel | Syntaxe Scryfall complete | Test app | Recherches avancees |
| Manuel | Power level visuel | Test app | Badge, facteurs, couleurs |
| Manuel | Colors regression | Test app | Aucun changement visuel |
| Manuel | Rulings affichage | Test app | Lazy loading, formatage |
| Manuel | Multilangue FR/DE/JP | Test app | Resultats multilingues |

### Criteres d'Entree Sprint 12
- 433 tests PASS (confirme)
- flutter analyze : 0 errors (confirme)
- ScryfallApiService.getCardRulings() fonctionnel (confirme)
- ScryfallApiService.searchCards(lang:) fonctionnel (confirme)
- EdhrecService.getCommanderData() fonctionnel avec cache (confirme)
- DeckDetailController.generateSynergyReport() fonctionnel (confirme)
- DeckDetailController.detectCombos() fonctionnel (confirme)

### Criteres de Sortie Sprint 12
- **>= 500 tests** PASS (433 + ~72 nouveaux)
- **flutter analyze : 0 errors**
- **Syntaxe Scryfall** : detection fiable, passthrough, aide contextuelle
- **Power Level** : estime pour tout deck Commander, facteurs detailles
- **Salt Score** : affiche par carte, moyenne dans rapport
- **Rulings** : affiches dans card detail, lazy loading
- **Multilangue** : 11 langues selectionnables, fallback EN
- **Colors/Fonts** : centralisees dans AppColors/AppTextStyles, < 100 occurrences directes
- **GameSetupModal** : controller extrait, testable
- **Regression** : 0 test casse

---

## 4. Scenarios de Test

### Chemin Nominal (Happy Path)

| ID | Scenario | Type | US | Preconditions | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|-----------------|----------|
| T-12.01 | isAdvancedScryfallSyntax("c:red") retourne true | Unit | 12.1 | -- | true | P0 |
| T-12.02 | isAdvancedScryfallSyntax("Lightning Bolt") retourne false | Unit | 12.1 | -- | false | P0 |
| T-12.03 | isAdvancedScryfallSyntax("cmc<=3 t:creature") retourne true | Unit | 12.1 | -- | true | P0 |
| T-12.04 | isAdvancedScryfallSyntax("o:\"draw a card\"") retourne true | Unit | 12.1 | -- | true | P0 |
| T-12.05 | isAdvancedScryfallSyntax("set:mkm") retourne true | Unit | 12.1 | -- | true | P0 |
| T-12.06 | Recherche avancee envoie query telle quelle a l'API | Unit | 12.1 | syntaxe detectee | API recoit "c:red cmc<=3" | P0 |
| T-12.07 | Recherche simple ajoute "name:" prefix | Unit | 12.1 | pas de syntaxe | API recoit "name:Lightning Bolt" | P0 |
| T-12.08 | estimatePowerLevel retourne score 1-10 | Unit | 12.2 | Deck Commander | Score entre 1 et 10 | P0 |
| T-12.09 | estimatePowerLevel retourne "Casual" pour deck basique | Unit | 12.2 | Deck CMC haut, 0 combo | score <= 3, label "Casual" | P0 |
| T-12.10 | estimatePowerLevel retourne "High Power" pour deck optimise | Unit | 12.2 | Deck CMC bas, combos, removals | score >= 8 | P0 |
| T-12.11 | estimatePowerLevel retourne null pour deck non-Commander | Unit | 12.2 | Deck Standard | null | P0 |
| T-12.12 | estimatePowerLevel.factors contient 6 facteurs | Unit | 12.2 | Deck Commander | 6 cles dans factors | P0 |
| T-12.13 | EdhrecCardSuggestion.fromJson parse salt correctement | Unit | 12.3 | JSON avec salt: 2.5 | salt = 2.5 | P0 |
| T-12.14 | EdhrecCardSuggestion.fromJson salt absent = 0.0 | Unit | 12.3 | JSON sans salt | salt = 0.0 | P0 |
| T-12.15 | DeckSynergyReport.averageSalt calcule correctement | Unit | 12.3 | 3 cartes salt 1.0, 2.0, 3.0 | avgSalt = 2.0 | P0 |
| T-12.16 | loadRulings charge les rulings triees par date | Unit | 12.4 | Mock avec 3 rulings | 3 rulings, plus recent en premier | P0 |
| T-12.17 | loadRulings retourne liste vide si pas de rulings | Unit | 12.4 | Mock avec data: [] | rulings = [] | P0 |
| T-12.18 | Recherche avec lang=fr passe le parametre | Unit | 12.5 | langue = fr | API recoit lang=fr | P0 |
| T-12.19 | Recherche sans langue utilise defaut EN | Unit | 12.5 | langue = null | API sans param lang | P0 |
| T-12.20 | GameSetupModalController.setPlayerCount met a jour l'etat | Unit | 12.7 | -- | state.playerCount = 4 | P1 |

### Cas aux Limites (Edge Cases)

| ID | Scenario | Type | US | Resultat Attendu | Priorite |
|----|----------|------|----|-----------------|----------|
| T-12.30 | isAdvancedScryfallSyntax("") retourne false | Unit | 12.1 | false | P0 |
| T-12.31 | isAdvancedScryfallSyntax("Magic: The Gathering") ne detecte pas ":" dans le nom | Unit | 12.1 | false (pas d'operateur valide avant ":") | P0 |
| T-12.32 | estimatePowerLevel deck vide (0 cartes mainboard) | Unit | 12.2 | Score neutre (~5), pas de crash | P0 |
| T-12.33 | estimatePowerLevel deck sans donnees EDHREC | Unit | 12.2 | Score base uniquement sur deck local | P0 |
| T-12.34 | estimatePowerLevel CMC moyen = 0 (deck de terrains) | Unit | 12.2 | cmcScore = 10 (maximum) | P1 |
| T-12.35 | DeckSynergyReport.averageSalt deck avec 0 cartes EDHREC | Unit | 12.3 | avgSalt = 0.0, pas de NaN | P0 |
| T-12.36 | loadRulings erreur reseau | Unit | 12.4 | rulings = [], pas de crash | P0 |
| T-12.37 | Recherche lang=ja retourne 0 resultats | Unit | 12.5 | Message explicatif, suggestion fallback EN | P1 |
| T-12.38 | GameSetupModalController.selectProfile index hors limites | Unit | 12.7 | Pas de crash, ignore | P1 |
| T-12.39 | BulkDataService.downloadOracleCards timeout | Unit | 12.9 | Erreur geree, message | P1 |
| T-12.40 | BulkDataService.isUpdateAvailable erreur reseau | Unit | 12.9 | Retourne false | P1 |

### Tests Negatifs

| ID | Scenario | Type | US | Resultat Attendu | Priorite |
|----|----------|------|----|-----------------|----------|
| T-12.50 | Syntaxe invalide "c:" (sans valeur) envoyee a l'API | Unit | 12.1 | Erreur API propagee a l'utilisateur | P0 |
| T-12.51 | Syntaxe avec operateur inconnu "x:value" | Unit | 12.1 | Considere comme recherche simple | P1 |
| T-12.52 | API Scryfall retourne erreur pour syntaxe mal formee | Unit | 12.1 | Message d'erreur affiche | P0 |
| T-12.53 | Salt score negatif dans JSON EDHREC | Unit | 12.3 | Accepte (salt peut etre negatif) | P1 |
| T-12.54 | Rulings API retourne HTML au lieu de JSON | Unit | 12.4 | rulings = [], pas de crash | P1 |

---

## 5. Specifications BDD/Gherkin Detaillees

### Scenario 1 : Syntaxe Scryfall

```gherkin
Fonctionnalite: Detection et passthrough de syntaxe Scryfall
  Plan du Scenario: Detecter les operateurs Scryfall
    Etant donne une query "<query>"
    Quand la detection de syntaxe est executee
    Alors le resultat est <resultat>

    Exemples:
      | query                    | resultat |
      | c:red                    | avancee  |
      | cmc<=3 t:creature        | avancee  |
      | o:"draw a card"          | avancee  |
      | Lightning Bolt           | simple   |
      | Sol Ring                 | simple   |
      | Magic: The Gathering     | simple   |
      | is:commander f:edh       | avancee  |
```

### Scenario 2 : Power Level

```gherkin
Fonctionnalite: Estimation du power level Commander
  Scenario: Deck casual avec CMC eleve et 0 combo
    Etant donne un deck Commander avec :
      | CMC moyen | Combos | Removals | Non-basics |
      | 4.2       | 0      | 3        | 5          |
    Quand le power level est estime
    Alors le score est entre 1 et 3
    Et le label est "Casual"

  Scenario: Deck optimise avec CMC bas et combos
    Etant donne un deck Commander avec :
      | CMC moyen | Combos complets | Removals | Non-basics | Synergy |
      | 2.1       | 3               | 12       | 25         | 72/100  |
    Quand le power level est estime
    Alors le score est entre 7 et 9
    Et le label est "Optimized" ou "High Power"
```

### Scenario 3 : Rulings lazy loading

```gherkin
Fonctionnalite: Rulings avec lazy loading
  Scenario: Chargement a la demande
    Etant donne que l'utilisateur arrive sur la page detail d'une carte
    Alors les rulings ne sont PAS charges automatiquement
    Quand l'utilisateur scrolle vers la section Regles
    Alors les rulings sont charges depuis l'API Scryfall
    Et ils sont affiches tries par date decroissante
```

---

## 6. Strategie d'Automatisation

### Tests Automatises (CI/CD)

| Type | Framework | Quoi | CI |
|------|-----------|------|----|
| Unitaire | flutter_test | isAdvancedScryfallSyntax (10 tests) | Oui |
| Unitaire | flutter_test + mock | estimatePowerLevel (12 tests) | Oui |
| Unitaire | flutter_test | salt dans EdhrecCardSuggestion (5 tests) | Oui |
| Unitaire | flutter_test + mock | loadRulings (5 tests) | Oui |
| Unitaire | flutter_test | multilangue (5 tests) | Oui |
| Unitaire | flutter_test | GameSetupModalController (20 tests) | Oui |
| Unitaire | flutter_test + mock | BulkDataService (10 tests) | Oui |
| Widget | flutter_test | ScryfallSyntaxHelp (3 tests) | Oui |
| Widget | flutter_test | RulingsSection (5 tests) | Oui |
| Widget | flutter_test | DeckPowerLevelBadge (3 tests) | Oui |

### Tests Manuels

| Type | Quoi | Quand |
|------|------|-------|
| Fonctionnel | Syntaxe Scryfall : `c:red`, `t:creature cmc<=3`, `o:"draw"` | Apres US-12.1 |
| Fonctionnel | Aide syntaxique (modal "?") | Apres US-12.1 |
| Visuel | Power Level badge + facteurs | Apres US-12.2 |
| Visuel | Salt badges dans suggestions | Apres US-12.3 |
| Fonctionnel | Rulings lazy loading | Apres US-12.4 |
| Fonctionnel | Recherche FR/DE/JP | Apres US-12.5 |
| Visuel | Regression Colors (toutes les pages) | Apres US-12.6 |

### CI/CD Pipeline

Le pipeline existant (`flutter analyze` + `flutter test`) suffit. Aucune modification necessaire.

---

## 7. Plan de Tests Non-Fonctionnels

### Performance

| Test | Cible | Methode |
|------|-------|---------|
| isAdvancedScryfallSyntax (regex) | < 1ms | Stopwatch |
| estimatePowerLevel (calcul local) | < 100ms | Stopwatch |
| loadRulings (API + parsing) | < 1s | Stopwatch |
| Salt parsing dans fromJson | < 0.1ms | Implicit |
| Bulk Data download (100MB) | < 60s (avec progress) | Test manuel |

### Compatibilite

- Tous les nouveaux modeles sont du Dart pur -> testables sans Flutter
- Tous les services sont mockables via Dio
- Le power level est un calcul deterministe (memes inputs = meme output)
- La detection de syntaxe est une regex pure -> pas de dependance externe

### Regression

- Les 433 tests existants doivent rester verts a 100%
- Les methodes existantes (getRecommendations, generateSynergyReport, detectCombos) ne changent pas
- La centralisation Colors est cosmetique, pas fonctionnelle -> 0 regression fonctionnelle attendue
- L'extraction GameSetupModal preserve le comportement exact

---

## 8. Matrice de Verification par US

| US | Verification Automatisee | Verification Manuelle | Critere PASS |
|----|--------------------------|----------------------|--------------|
| US-12.1 | 10 tests syntaxe + 3 tests widget | Syntaxe avancee dans l'app | Detection fiable, resultats corrects |
| US-12.2 | 12 tests power level | Badge, facteurs, couleurs | Score 1-10 correct, facteurs detailles |
| US-12.3 | 5 tests salt | Badges salt, moyenne | Salt affiche, moyenne correcte |
| US-12.4 | 10 tests rulings | Lazy loading, affichage | Rulings charges et affiches |
| US-12.5 | 5 tests multilangue | Recherche FR/DE/JP | Resultats multilingues |
| US-12.6 | 0 (cosmetique) | Review visuelle complete | Aucun changement visuel |
| US-12.7 | 20 tests controller | Modal fonctionnelle | Comportement identique |
| US-12.8 | Build OK sans overrides | Scanner fonctionnel | Pas de regression scanner |
| US-12.9 | 10 tests bulk data | Download en background | Fichier mis a jour |
| US-12.10 | 5 tests catalogs | Filtres dynamiques | Catalogs integres |
| Regression | 433 tests existants | -- | 0 test casse |
| **Total** | **~72 tests automatises** | **7 sessions manuelles** | |

---

## 9. Checklist de Validation Sprint 12

```bash
# Verification rapide apres chaque modification
flutter analyze                    # Cible : 0 errors
flutter test                       # Cible : >= 500 tests, 0 fail

# Verification des features (Phase 1)
# US-12.3 : Salt badges dans suggestions + moyenne rapport
# US-12.4 : Rulings affiches dans card detail (lazy loading)

# Verification des features (Phase 2)
# US-12.1 : "c:red cmc<=3 t:creature" -> resultats corrects
# US-12.1 : Bouton aide "?" affiche la reference syntaxique
# US-12.5 : Recherche en FR/DE/JP retourne des resultats

# Verification des features (Phase 3)
# US-12.2 : Power level badge dans deck Commander
# US-12.2 : Facteurs detailles cliquables

# Verification refactoring (Phase 4)
# US-12.7 : Game setup modal fonctionnelle
# US-12.6 : Review visuelle de toutes les pages (0 regression)

# Verification backlog (Phase 5)
# US-12.8 : Build sans dependency_overrides
# US-12.9 : Download bulk data en background
# US-12.10 : Filtres dynamiques avec catalogs
```

### Criteres d'Acceptation Globaux Sprint 12

| # | Critere | Methode de verification | Cible |
|---|---------|------------------------|-------|
| 1 | flutter test | `flutter test` | >= 500 tests, 0 fail |
| 2 | flutter analyze errors | `flutter analyze` | 0 errors |
| 3 | Syntaxe Scryfall avancee | Test fonctionnel | Detection + passthrough |
| 4 | Power Level Commander | Test fonctionnel | Score 1-10 + facteurs |
| 5 | Salt Score | Test fonctionnel | Badge par carte + moyenne |
| 6 | Rulings | Test fonctionnel | Lazy loading + affichage |
| 7 | Recherche multilangue | Test fonctionnel | 11 langues |
| 8 | Colors centralisees | Review visuelle | < 100 occ. directes |
| 9 | GoogleFonts centralisees | Review visuelle | < 10 occ. directes |
| 10 | GameSetupModal extracte | Tests controller | 20 tests PASS |
| 11 | Retrocompatibilite | 433 tests existants | 0 test casse |

---

## 10. Strategie de Non-Regression

Le Sprint 12 touche de nombreux fichiers (surtout la centralisation Colors). La strategie de non-regression est :

1. **Avant chaque US** : Verifier que `flutter test` passe (433 tests)
2. **Apres chaque US** : Verifier que `flutter test` passe (433 + nouveaux tests)
3. **Centralisation Colors** : Migrer par lots de 5-10 fichiers, `flutter test` apres chaque lot
4. **EdhrecCardSuggestion** : Le champ `salt` est ajoute avec default 0.0, donc aucun test existant ne casse
5. **CardDetailController** : Nouvelles methodes ajoutees, anciennes inchangees
6. **DeckDetailController** : Nouvelles methodes ajoutees, anciennes inchangees
7. **CardSearchController** : La recherche simple reste identique (pas de regression)
8. **GameSetupModal** : Le widget consomme le controller mais le comportement UI est preserve

### Points d'attention specifiques

- La regex `isAdvancedScryfallSyntax` doit etre conservatrice : mieux vaut considerer une query avancee comme simple que l'inverse (evite les erreurs API inattendues)
- Le power level doit gerer le cas 0 cartes (score neutre, pas NaN)
- Le salt score default 0.0 ne doit pas etre affiche visuellement (cacher si 0)
- Les rulings doivent etre charges en lazy loading pour ne pas ralentir le chargement initial
- La migration Colors doit preserver les valeurs exactes (pas d'approximation de couleur)

*"Chaque berri compte -- et ce sprint en a beaucoup ! 10 user stories, ~72 tests nouveaux, 1625 occurrences de couleurs a migrer. Le tresor du Sprint 12, c'est la completude : la syntaxe Scryfall pour les experts, le power level pour les deckbuilders, le salt score pour les diplomates, les rulings pour les juges. Et derriere le rideau, la centralisation Colors prepare le terrain pour les themes sombres/clairs. C'est du profit a long terme."* -- Nami, QA Lead
