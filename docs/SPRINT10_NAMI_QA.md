# Sprint 10 - Plan QA : Import/Export & Legalite
> Agent : Nami (QA Lead) | Date : 01/03/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS

### Resume
- Stack detectee : Flutter / Dart 3.9.2 (Flutter 3.35.6)
- Tests : **298/298 PASS**
- flutter analyze : 0 errors, **~75 warnings**, **~890 infos** (966 total)
- Controllers existants : **6** (Sprint 7)
- Providers actifs : **20+**
- Base drift SQLite : operationnelle
- Sprint 9 : **TERMINE** (5 features, 298 tests, commit 1c07d36)

### Constat de Sante Avant Sprint 10

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter test | 298/298 PASS | OK |
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | ~75 | NON BLOQUANT (Sprint 8 backlog) |
| flutter analyze infos | ~890 | NON BLOQUANT (Sprint 8 backlog) |
| DeckListController.importDeck() | Fonctionnel (format simple) | OK, base pour refactoring |
| ScryfallCard.legalities | Parse et affiche | OK pour exploitation deck-level |
| DeckCard.tags | Fonctionnel avec drift | OK pour extension collection |
| CollectionService.getAllUniqueTags() | Fonctionnel | OK |
| BackupService (export/import fichier) | Fonctionnel | Modele pour I/O fichier |

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | DeckFormatService retourne des objets structures (DecklistParseResult), LegalityService retourne LegalityReport avec violations detaillees |
| Controlabilite | **Haute** | Tous les services sont injectables, les parsers sont des methodes statiques pures, les donnees de legalite sont deterministes |
| Decomposabilite | **Haute** | Import/export/legalite/tags sont 4 features 100% independantes, testables isolement |
| Stabilite | **Haute** | L'API Scryfall est stable, les formats de decklist sont standardises, legalities ne changent que lors des ban updates |
| Comprehensibilite | **Haute** | Specs Zorro completes avec Gherkin, architecture Sanji detaillee, chaque US a des criteres clairs |

**Implications** : Le Sprint 10 est hautement testable grace a la nature deterministe des parsers de decklist et des regles de legalite. Les services sont des fonctions pures (input -> output) ideales pour les tests unitaires.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-10.1 : Import multi-format | Tres haut (adoption) | Moyen (parsing varie) | P0 | Profond |
| US-10.2 : Export multi-format | Haut (interoperabilite) | Faible (generation texte) | P1 | Moyen |
| US-10.3 : Legalite | Tres haut (confiance) | Moyen (regles complexes) | P0 | Profond |
| US-10.4 : Tags collection | Moyen (organisation) | Faible (infra existante) | P2 | Leger |
| Regression import existant | Haut | Moyen | P0 | Profond |
| Regression 298 tests | Critique | Faible | P0 | Automatise |

### Top 3 Risques Majeurs

1. **Parsing de decklists externes** : Chaque app (Moxfield, MTGO, Archidekt) a des variantes subtiles dans le format. Lignes vides, commentaires, set codes entre parentheses, indicateurs foil, noms en francais -- le parser doit etre tolerant sans etre fragile.

2. **Regles de legalite incorrectes** : La logique Commander (singleton, identite de couleur) et Vintage (restricted) est complexe. Des edge cases comme les terrains de base (exempts du singleton), les cartes "relentless" (any number), et les lands a double identite de couleur doivent etre geres.

3. **Resolution de noms de cartes** : Les cartes double-face ("Delver of Secrets // Insectile Aberration"), les cartes avec accents ("Eladamri, Lord of Leaves"), et les cartes en francais peuvent echouer la resolution via Scryfall.

---

## 3. Strategie de Test Globale

### Pyramide de Tests Sprint 10

```
                    /\
                   /  \     3 tests manuels
                  / E2E\    (import file, export share, legalite visuel)
                 /------\
                /        \   ~8 tests integration
               / Integr.  \  (controller + service mock)
              /------------\
             /              \  ~30 tests unitaires
            /   Unitaires    \  (parser, legalite, export, tags)
           /------------------\
```

### Niveaux de Test

| Niveau | Quoi | Comment | Cible |
|--------|------|---------|-------|
| Unitaire | DeckFormatService.parseDecklistText (8 variantes) | flutter_test | Tous les formats d'entree |
| Unitaire | DeckFormatService.parseDecklistCsv (4 variantes) | flutter_test | CSV Archidekt, standard, edge cases |
| Unitaire | DeckFormatService.exportToTxt (3 cas) | flutter_test | Standard, Commander, vide |
| Unitaire | DeckFormatService.exportToCsv (2 cas) | flutter_test | Standard, avec tags |
| Unitaire | LegalityService - format legal (8 formats) | flutter_test | 1 test par format |
| Unitaire | LegalityService - violations (6 cas) | flutter_test | banned, restricted, singleton, copies, color identity, taille |
| Unitaire | LegalityService - edge cases (4 cas) | flutter_test | basic land, any number, LOCAL: cards, empty deck |
| Integration | DeckListController.importDeckFromText | flutter_test + mock | Import complet avec resolution |
| Integration | DeckDetailController.generateLegalityReport | flutter_test | Rapport avec fullCardData mock |
| Integration | CollectionController tags | flutter_test + mock | Tags CRUD + filtre |
| Manuel | Import fichier .txt/.csv | Test app | File picker -> import complet |
| Manuel | Export partage systeme | Test app | Menu export -> share sheet |
| Manuel | Onglet legalite dans deck detail | Test app | Badges + violations affichees |

### Criteres d'Entree Sprint 10
- 298 tests PASS (confirme)
- flutter analyze : 0 errors (confirme)
- DeckListController.importDeck() fonctionnel (confirme)
- ScryfallCard.legalities parse (confirme)
- DeckCard.tags avec persistence drift (confirme)
- CollectionService.getAllUniqueTags() fonctionnel (confirme)

### Criteres de Sortie Sprint 10
- **>= 330 tests** PASS (298 + ~38 nouveaux)
- **flutter analyze : 0 errors** (les warnings/infos pre-existants sont toleres)
- **Import** : fichiers TXT (Moxfield, MTGO) et CSV (Archidekt) importes correctement
- **Export** : TXT et CSV generes et partageables
- **Legalite** : 8 formats verifies avec rapport detaille
- **Tags** : CRUD tags collection + filtre par tag
- **Regression** : 0 test casse

---

## 4. Scenarios de Test

### Chemin Nominal (Happy Path)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-10.01 | Parse TXT format Moxfield | Unit | 10.1 | Texte avec sections Commander/Deck/Sideboard | parseDecklistText(moxfieldTxt) | mainboard OK, sideboard OK, commanderName set | P0 |
| T-10.02 | Parse TXT format MTGO | Unit | 10.1 | Texte avec Deck/Sideboard sans Commander | parseDecklistText(mtgoTxt) | mainboard OK, sideboard OK, commanderName null | P0 |
| T-10.03 | Parse CSV format Archidekt | Unit | 10.1 | CSV avec Quantity,Name,Categories | parseDecklistCsv(archidektCsv) | cartes OK, tags extraits | P0 |
| T-10.04 | Auto-detection format | Unit | 10.1 | Texte TXT et CSV | autoDetectAndParse() | Detecte correctement le format | P1 |
| T-10.05 | Export TXT deck standard | Unit | 10.2 | Deck avec mainboard + sideboard | exportToTxt(deck) | Format Moxfield/MTGO compatible | P0 |
| T-10.06 | Export TXT deck Commander | Unit | 10.2 | Deck avec commander | exportToTxt(deck) | Section Commander en premier | P0 |
| T-10.07 | Export CSV | Unit | 10.2 | Deck complet | exportToCsv(deck) | Header + lignes correctes | P1 |
| T-10.08 | Legalite Modern legal | Unit | 10.3 | Deck 60 cartes, toutes legal en Modern | generateReport() | Modern = legal | P0 |
| T-10.09 | Legalite Standard avec banned | Unit | 10.3 | Deck avec carte bannie en Standard | generateReport() | Standard = illegal, violation listee | P0 |
| T-10.10 | Legalite Commander complet | Unit | 10.3 | Deck 100 cartes, commander, singleton, bonne identite | generateReport() | Commander = legal | P0 |
| T-10.11 | Tags ajout collection | Unit | 10.4 | Carte en collection | updateCardTags(id, ['Trade']) | Tag sauvegarde | P1 |
| T-10.12 | Filtre collection par tag | Unit | 10.4 | 5 cartes avec tag "Trade" | Appliquer filtre "Trade" | 5 resultats | P1 |

### Cas aux Limites (Edge Cases)

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-10.13 | Parse TXT avec lignes vides et commentaires | Unit | 10.1 | Texte avec // et lignes vides | parseDecklistText() | Lignes ignorees, cartes parsees | P0 |
| T-10.14 | Parse TXT carte double-face | Unit | 10.1 | "1 Delver of Secrets // Insectile Aberration" | parseDecklistText() | name = "Delver of Secrets" (face avant seulement) | P0 |
| T-10.15 | Parse TXT avec set code | Unit | 10.1 | "1 Lightning Bolt (M10)" | parseDecklistText() | name = "Lightning Bolt" (set code retire) | P1 |
| T-10.16 | Parse TXT avec indicateur foil MTGO | Unit | 10.1 | "1 Sol Ring *F*" | parseDecklistText() | name = "Sol Ring" (foil retire) | P1 |
| T-10.17 | Import avec carte non trouvee | Integ | 10.1 | Carte "XXX Inexistante" dans la liste | importDeckFromText() | scryfallId = "LOCAL:XXX Inexistante", warning | P0 |
| T-10.18 | Export deck vide | Unit | 10.2 | Deck sans cartes | exportToTxt(emptyDeck) | "Deck\n" (section vide mais pas de crash) | P1 |
| T-10.19 | Legalite - terrain de base > singleton | Unit | 10.3 | Commander avec 35x Plains | generateReport() | Pas de violation singleton pour Plains | P0 |
| T-10.20 | Legalite - carte "any number" | Unit | 10.3 | Deck avec 4x "Relentless Rats" en Commander | generateReport() | Pas de violation singleton | P1 |
| T-10.21 | Legalite - carte LOCAL: ignoree | Unit | 10.3 | Deck avec carte scryfallId "LOCAL:XXX" | generateReport() | Carte ignoree, unresolvedCards = 1 | P0 |
| T-10.22 | Legalite Vintage restricted | Unit | 10.3 | 2x "Black Lotus" (restricted) | generateReport() | Vintage = illegal, violation restricted | P0 |
| T-10.23 | Legalite Commander identite couleur | Unit | 10.3 | Commander mono-R avec carte bleue | generateReport() | Commander = illegal, violation couleur | P0 |
| T-10.24 | Tags multiples sur une carte | Unit | 10.4 | Carte avec ["Trade", "Budget"] | updateCardTags() | 2 tags sauvegardes | P1 |
| T-10.25 | CSV avec delimiteur point-virgule | Unit | 10.1 | CSV avec ; au lieu de , | parseDecklistCsv() | Detection auto et parsing correct | P2 |

### Tests Negatifs

| ID | Scenario | Type | US | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|----|---------------|--------|-----------------|----------|
| T-10.30 | Parse texte completement invalide | Unit | 10.1 | "Lorem ipsum dolor sit amet" | parseDecklistText() | mainboard vide, warnings, pas de crash | P0 |
| T-10.31 | Parse CSV sans header | Unit | 10.1 | CSV sans premiere ligne de colonnes | parseDecklistCsv() | Warning "colonnes introuvables", hasErrors = true | P1 |
| T-10.32 | Import fichier vide | Integ | 10.1 | Fichier vide "" | importDeckFromText("", "") | Message "Aucune carte trouvee" | P1 |
| T-10.33 | Legalite deck completement vide | Unit | 10.3 | Deck sans cartes | generateReport() | Tous les formats = illegal (taille insuffisante) | P1 |
| T-10.34 | Legalite sans fullCardData | Unit | 10.3 | fullCardData vide | generateReport() | Report genere avec unresolvedCards eleve | P1 |
| T-10.35 | Export avec noms contenant des guillemets | Unit | 10.2 | Carte avec nom contenant " | exportToCsv() | Guillemets echappes correctement | P2 |

---

## 5. Specifications BDD/Gherkin Detaillees

### Scenario 1 : Import roundtrip (import -> export -> re-import)

```gherkin
Fonctionnalite: Import/Export roundtrip
  Scenario: Exporter un deck puis le re-importer
    Etant donne un deck "Burn" avec :
      | Mainboard |
      | 4 Lightning Bolt |
      | 4 Goblin Guide |
      Et un sideboard :
      | 2 Blood Moon |
    Quand l'utilisateur exporte en TXT
    Et re-importe le TXT genere comme "Burn Copy"
    Alors "Burn Copy" contient exactement les memes cartes que "Burn"
    Et les quantites sont identiques
```

### Scenario 2 : Legalite multi-format

```gherkin
Fonctionnalite: Verification de legalite multi-format
  Plan du Scenario: Deck legal dans certains formats
    Etant donne un deck contenant :
      | name | legalities.standard | legalities.modern | legalities.commander |
      | Lightning Bolt | legal | legal | legal |
      | Counterspell | not_legal | legal | legal |
    Et que le deck a 60 cartes
    Quand le rapport de legalite est genere
    Alors le format "Standard" est "illegal" a cause de "Counterspell"
    Et le format "Modern" est "legal"
```

### Scenario 3 : Commander singleton + identite de couleur

```gherkin
Fonctionnalite: Legalite Commander
  Scenario: Violation singleton
    Etant donne un deck Commander avec 2 exemplaires de "Sol Ring"
    Et que "Sol Ring" n'est pas un terrain de base
    Quand le rapport est genere
    Alors Commander = illegal
    Et la violation indique "Sol Ring : 2 copies (max 1)"

  Scenario: Violation identite de couleur
    Etant donne un commandant avec colorIdentity = ['R', 'G']
    Et que le deck contient "Counterspell" avec colorIdentity = ['U']
    Quand le rapport est genere
    Alors Commander = illegal
    Et la violation indique "Hors identite de couleur : Counterspell (U)"
```

---

## 6. Strategie d'Automatisation

### Tests Automatises (CI/CD)

| Type | Framework | Quoi | CI |
|------|-----------|------|----|
| Unitaire parser | flutter_test | DeckFormatService parse TXT (8 tests) | Oui |
| Unitaire parser | flutter_test | DeckFormatService parse CSV (4 tests) | Oui |
| Unitaire export | flutter_test | DeckFormatService export TXT/CSV (5 tests) | Oui |
| Unitaire legalite | flutter_test | LegalityService 8 formats + violations (18 tests) | Oui |
| Unitaire tags | flutter_test | CollectionController tags (3 tests) | Oui |
| Integration | flutter_test + mocks | DeckListController import (5 tests) | Oui |
| Integration | flutter_test | DeckDetailController export + legalite (3 tests) | Oui |

### Tests Manuels

| Type | Quoi | Quand |
|------|------|-------|
| Fonctionnel | Import fichier .txt Moxfield | Apres US-10.1 |
| Fonctionnel | Import fichier .csv Archidekt | Apres US-10.1 |
| Fonctionnel | Import par collage de texte | Apres US-10.1 |
| Fonctionnel | Export TXT via Share sheet | Apres US-10.2 |
| Fonctionnel | Export CSV via Share sheet | Apres US-10.2 |
| Fonctionnel | Copie clipboard | Apres US-10.2 |
| Visuel | Onglet legalite dans deck detail | Apres US-10.3 |
| Visuel | Badges format (vert/rouge) | Apres US-10.3 |
| Fonctionnel | Tags collection (ajout, suppression, filtre) | Apres US-10.4 |

### CI/CD Pipeline

Le pipeline existant (`flutter analyze` + `flutter test`) suffit. Aucune modification necessaire.

---

## 7. Plan de Tests Non-Fonctionnels

### Performance

| Test | Cible | Methode |
|------|-------|---------|
| Parse TXT 100 lignes | < 10ms | Stopwatch dans le test |
| Parse CSV 100 lignes | < 10ms | Stopwatch dans le test |
| Export TXT 100 cartes | < 5ms | Stopwatch |
| Export CSV 100 cartes | < 5ms | Stopwatch |
| Generation rapport legalite (100 cartes x 8 formats) | < 50ms | Stopwatch |
| Resolution noms API (100 cartes, 2 batch) | < 5s | Test reseau (non CI) |

### Compatibilite

- `DeckFormatService` est un service pur sans dependance Flutter -> testable en Dart pur
- `LegalityService` est un service pur sans dependance -> testable en Dart pur
- Aucun nouveau package ajoute
- Les formats d'import sont retrocompatibles avec l'import existant

### Regression

- Les 298 tests existants doivent rester verts a 100%
- L'import existant `importDeck()` est refactorise mais le comportement est preserve
- La methode `validateDeckRules()` est remplacee par `generateLegalityReport()` : le retour change de `Map<String, String>` a `LegalityReport`
- Les tests existants de `DeckDetailController` qui utilisent `validateDeckRules()` doivent etre mis a jour

---

## 8. Matrice de Verification par US

| US | Verification Automatisee | Verification Manuelle | Critere PASS |
|----|--------------------------|----------------------|--------------|
| US-10.1 | 12 tests parser + 5 tests import controller | Import fichier TXT + CSV | Decks crees avec bonnes cartes et quantites |
| US-10.2 | 5 tests export | Export via Share sheet | Fichiers generes et partageables |
| US-10.3 | 18 tests legalite | Onglet legalite visuel | 8 formats verifies, violations listees |
| US-10.4 | 3 tests tags | Tags ajout/suppression/filtre | Tags sauvegardes et filtrables |
| Regression | 298 tests existants | - | 0 test casse |
| **Total** | **~38 tests automatises** | **9 sessions manuelles** | |

---

## 9. Checklist de Validation Sprint 10

```bash
# Verification rapide apres chaque modification
flutter analyze                    # Cible : 0 errors (warnings/infos toleres)
flutter test                       # Cible : >= 330 tests, 0 fail

# Verification des features
# US-10.1 : Import TXT Moxfield + MTGO + CSV Archidekt
# US-10.2 : Export TXT + CSV + clipboard
# US-10.3 : Onglet legalite avec 8 formats et violations
# US-10.4 : Tags collection (CRUD + filtre)
```

### Criteres d'Acceptation Globaux Sprint 10

| # | Critere | Methode de verification | Cible |
|---|---------|------------------------|-------|
| 1 | flutter test | `flutter test` | >= 330 tests, 0 fail |
| 2 | flutter analyze errors | `flutter analyze` | 0 errors |
| 3 | Import TXT (Moxfield) | Test fonctionnel | Deck cree avec cartes correctes |
| 4 | Import TXT (MTGO) | Test fonctionnel | Deck cree avec cartes correctes |
| 5 | Import CSV (Archidekt) | Test fonctionnel | Deck cree avec cartes et tags |
| 6 | Export TXT | Test fonctionnel | Fichier genere et partageable |
| 7 | Export CSV | Test fonctionnel | Fichier genere et partageable |
| 8 | Legalite 8 formats | Test fonctionnel | Badges corrects, violations listees |
| 9 | Tags collection CRUD | Test fonctionnel | Tags sauvegardes et filtrables |
| 10 | Retrocompatibilite | 298 tests existants | 0 test casse |

---

## 10. Strategie de Non-Regression

Le Sprint 10 ajoute de nouveaux services (`DeckFormatService`, `LegalityService`) et modifie un controller existant (`DeckListController.importDeck`). La strategie de non-regression est :

1. **Avant chaque US** : Verifier que `flutter test` passe (298 tests)
2. **Apres chaque US** : Verifier que `flutter test` passe (298 + nouveaux tests)
3. **Refactoring importDeck** : Les tests existants de `DeckListController` doivent passer avec le nouveau code
4. **Remplacement validateDeckRules** : Adapter les tests qui referencent l'ancienne methode
5. **Tags collection** : Le champ `tags` de `DeckCard` n'est pas modifie, seule l'UX est ajoutee
6. **Aucun impact sur** : CardSearchController, SetDetailController, CardDetailController, les providers existants

### Points d'attention specifiques

- Le `DecklistParseResult` doit gerer gracieusement les edge cases sans throw
- Le `LegalityService` ne doit jamais throw (retourner `unknown` si donnees insuffisantes)
- L'export ne doit jamais corrompre les donnees (utiliser des StringBuffer, pas de mutation)

*"Chaque berri compte ! 4 features, 38 tests, 0 regression. Le tresor du Sprint 10, c'est l'interoperabilite -- les joueurs peuvent enfin entrer ET sortir avec leurs decks. La legalite ajoute la confiance. Les tags ajoutent l'ordre. Et tout ca, sans casser un seul test existant."* -- Nami, QA Lead
