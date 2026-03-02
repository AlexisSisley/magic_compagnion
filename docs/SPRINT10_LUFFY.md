# Sprint 10 - Synthese Capitaine : Import/Export & Legalite
> Agent : Luffy (Capitaine) | Date : 01/03/2026

---

## 1. Resume Executif

Le Sprint 10 comble les **deux gaps critiques** identifies par l'audit Yamato : l'absence d'import/export (Gap #1) et l'absence de verification de legalite (Gap #3). C'est le **deuxieme sprint de features utilisateur** apres le Sprint 9 (quick wins). L'impact est strategique : l'import ouvre la porte aux joueurs migrants (Moxfield, Archidekt, MTGO), l'export leur donne la liberte de quitter sans friction, et la legalite installe la confiance chez les joueurs competitifs. Les tags collection completent l'offre d'organisation. Budget : **9 jours**, 3 semaines. 4 user stories, 14 story points.

**Changement de nature** : Le Sprint 9 ajoutait des features legeres (badges, tri, boutons). Le Sprint 10 ajoute des **fonctionnalites structurantes** qui changent la proposition de valeur de l'app : interoperabilite et confiance competiteur.

---

## 2. Synthese d'Alignement

### Points de convergence

1. **Les 3 agents s'accordent sur les priorites** : US-10.1 (import) en P0 absolu, US-10.3 (legalite) en P0, US-10.2 (export) en P0, US-10.4 (tags) en P1.
2. **Les 3 agents confirment que l'infrastructure existe** : legalities parse dans ScryfallCard, import basique dans DeckListController, tags dans DeckCard, BackupService pour le pattern I/O fichier. Le Sprint 10 est un sprint d'enrichissement, pas de creation ex nihilo.
3. **Risque principal unanime** : le parsing des formats d'import externes (variantes entre apps). Mitigation : parser tolerant avec nettoyage agressif des noms + fallback LOCAL:.
4. **Les 3 agents confirment 0 nouvelle dependance** : share_plus, path_provider, file_picker sont deja dans le projet.

### Matrice d'alignement

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| Perimetre | 4 US, 14 SP, 9j | 6 fichiers crees, ~8 modifies | >= 330 tests, 0 errors | **Aligne** |
| Priorite P0 | US-10.1 (import) | US-10.1 (DeckFormatService) | US-10.1 (12 tests parser) | **Aligne** |
| Feature structurante | US-10.3 (legalite) | US-10.3 (LegalityService) | US-10.3 (18 tests legalite) | **Aligne** |
| Feature P1 | US-10.4 (tags) | US-10.4 (CollectionController) | US-10.4 (3 tests tags) | **Aligne** |
| Effort total | 9j | 9j (6 phases) | 38 tests nouveaux | **Aligne** |
| Risque principal | Resolution noms import | Parsing variantes formats | Regression importDeck refactoring | **Convergent** |
| Nouvelle dependance | 0 | 0 | 0 | **Aligne** |

### Tensions identifiees

| Tension | Resolution |
|---------|-----------|
| Zorro estime import a 4j, Sanji decoupe en 2j service + 2j integration | **Aligne** : total = 4j dans les deux cas |
| Nami demande >= 330 tests, Sanji estime ~336 | **Compatible** : Sanji depasse la cible Nami |
| Zorro inclut import Archidekt CSV avec tags -> categories, Sanji le traite dans le parser CSV | **Aligne** : le parser CSV extrait les categories en tags |

---

## 3. Arbitrage des Conflits

| Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---------|---------------|----------------|---------------|---------------------|---------------|
| Refactoring vs nouveau importDeck | Nouveau service dedie | Refactorer l'existant | Tester les 2 | **Nouveau service DeckFormatService + refactoring de importDeck pour l'utiliser** | Le parser est reutilisable (import + export). Le controller est refactorise pour le consommer. Best of both worlds. |
| validateDeckRules remplacement | Pas de preference | Remplacement complet | Adapter les tests | **Remplacement complet + adaptation tests** | validateDeckRules est un placeholder. Le vrai LegalityService le remplace. Les 2-3 tests existants sont adaptes. |
| Filtre tags collection : SearchFilters ou CollectionController | SearchFilters.tags existe deja | CollectionController._applyFilters | Test unitaire du filtre | **CollectionController._applyFilters utilise SearchFilters.tags** | Le champ existe deja dans SearchFilters (Sprint 9), il suffit de l'exploiter dans le controller. |
| Import par URL (Moxfield link) | Hors scope | Hors scope | Hors scope | **Hors scope Sprint 10** | Necessite du web scraping ou une API tierce. Trop risque pour ce sprint. |

---

## 4. Roadmap de Livraison

### Phase 1 : Service de Formats & Parsing (2j) -- Fondation

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 1 | Creer `DeckFormatService` avec parser TXT (Moxfield + MTGO) | Aucune | Parse correct, sections detectees, noms nettoyes | P0 |
| 2 | Ajouter parser CSV (Archidekt + generique) | #1 | CSV parse, colonnes detectees, tags extraits | P0 |
| 3 | Ajouter auto-detection de format (TXT vs CSV) | #1, #2 | Detection correcte | P1 |
| 4 | Ajouter export TXT et CSV | #1 | Texte genere correct | P0 |
| 5 | Tests DeckFormatService (15 tests) | #1-#4 | 313 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 313 PASS, parser fonctionne pour tous les formats | | |

### Phase 2 : Import Integration (2j) -- Adoption

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 6 | Refactorer `DeckListController.importDeck()` -> `importDeckFromText()` | Phase 1 | Import utilise DeckFormatService | P0 |
| 7 | Ajouter `_resolveCardNames()` batch (75 par batch) | #6 | Resolution par batch fonctionnelle | P0 |
| 8 | Creer `DeckImportModal` (coller texte + fichier) | #6 | Modal 2 onglets fonctionnel | P0 |
| 9 | Integrer dans `DeckListPage` (bouton import) | #8 | Bouton accessible, import fonctionne | P0 |
| 10 | Tests import integration (5 tests) | #6-#9 | 318 tests PASS | P0 |
| **Checkpoint** | Import TXT + CSV fonctionnel depuis fichier et presse-papiers | | |

### Phase 3 : Export Integration (1j) -- Liberte

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 11 | Ajouter `exportAsTxt()` et `exportAsCsv()` dans `DeckDetailController` | Phase 1 | Methodes retournent le texte correct | P0 |
| 12 | Modifier `DeckDetailPage` : menu export (TXT, CSV, clipboard) | #11 | Menu accessible, 3 options | P0 |
| 13 | Partage via `share_plus` (fichier TXT/CSV) | #12 | Share sheet systeme s'ouvre | P0 |
| 14 | Tests export (3 tests) | #11 | 321 tests PASS | P1 |
| **Checkpoint** | Export TXT + CSV + clipboard fonctionnel | | |

### Phase 4 : Verification de Legalite (2j) -- Confiance

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 15 | Creer `LegalityReport` modele + `FormatRules` | Aucune | Modele compile, constructeur fonctionne | P0 |
| 16 | Creer `LegalityService` avec regles pour 8 formats | #15 | Regles correctes pour tous les formats | P0 |
| 17 | Integrer dans `DeckDetailController` (remplacer `validateDeckRules`) | #16 | Methode retourne LegalityReport | P0 |
| 18 | Creer `DeckLegalityTab` widget | #17 | Affiche badges + violations | P0 |
| 19 | Integrer onglet dans `DeckDetailPage` | #18 | Onglet accessible et fonctionnel | P0 |
| 20 | Tests legalite (18 tests) | #16-#17 | 339 tests PASS | P0 |
| **Checkpoint** | 8 formats verifies, rapport detaille avec violations | | |

### Phase 5 : Tags Collection (1j) -- Organisation

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 21 | Modifier `CollectionController` pour gestion tags + filtre | Aucune | Tags CRUD fonctionnel | P1 |
| 22 | Creer `TagEditorDialog` widget | #21 | Dialog avec autocomplete | P1 |
| 23 | Integrer dans collection page (long-press, filtre) | #22 | Tags accessibles et filtrables | P1 |
| 24 | Tests tags (3 tests) | #21-#23 | >= 336 tests PASS | P1 |
| **Checkpoint** | Tags CRUD + filtre fonctionnels dans la collection | | |

### Phase 6 : Integration & Validation Finale (1j)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 25 | Test regression complet (`flutter test`) | Toutes | >= 330 tests PASS, 0 fail | P0 |
| 26 | `flutter analyze` : 0 errors | Toutes | 0 errors | P0 |
| 27 | Test manuel E2E : import -> edit -> export -> legalite | Toutes | Workflow complet fonctionne | P0 |
| 28 | Mise a jour ROADMAP_MUGIWARA.md | Toutes | Sprint 10 marque TERMINE | P1 |

### Graphe de Dependances (Chemin Critique)

```
Phase 1 (2j) ──> Phase 2 (2j) ──> Phase 3 (1j)
[Formats]         [Import]          [Export]
    │                                  │
    │                                  └──> Phase 6 (1j) [Integration]
    │
    └──> Phase 4 (2j) [Legalite] ──> Phase 6
                                        │
Phase 5 (1j) [Tags, parallele] ────────┘
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3 -> Phase 6 = **6j**
**Parallele** : Phase 4 (legalite, 2j) peut commencer en parallele de Phase 2-3
**Parallele** : Phase 5 (tags, 1j) peut commencer a tout moment
**Total** : 9j (avec parallelisme)

---

## 5. Estimation des Ressources & Efforts

| Phase | Effort | Cumul |
|-------|--------|-------|
| Phase 1 : Service de Formats | 2j | 2j |
| Phase 2 : Import Integration | 2j | 4j |
| Phase 3 : Export Integration | 1j | 5j |
| Phase 4 : Legalite (parallele a 2+3) | 2j | 7j |
| Phase 5 : Tags Collection (parallele) | 1j | 8j |
| Phase 6 : Integration & Validation | 1j | 9j |
| **Total** | **9j** | |

**Marge de securite** : 0j (budget serre). Si retard, US-10.4 (tags) est reportable au Sprint 11.

---

## 6. Indicateurs de Succes (KPIs)

| KPI | Valeur Actuelle | Cible Sprint 10 | Methode de Mesure | Frequence |
|-----|-----------------|-----------------|-------------------|-----------|
| Tests totaux | 298 | **>= 330** | `flutter test` | Apres chaque US |
| flutter analyze errors | 0 | **0** | `flutter analyze` | Apres chaque US |
| Formats d'import | 1 (TXT basique) | **3** (TXT Moxfield, TXT MTGO, CSV) | Revue fonctionnelle | Fin Phase 2 |
| Formats d'export | 0 (copier texte seul) | **3** (TXT, CSV, clipboard) | Revue fonctionnelle | Fin Phase 3 |
| Formats de legalite | 0 (placeholder) | **8** (Standard, Pioneer, Modern, Legacy, Vintage, Pauper, Commander, Brawl) | Revue fonctionnelle | Fin Phase 4 |
| Tags collection | Non expose | **CRUD + filtre** | Test fonctionnel | Fin Phase 5 |
| Score qualite | 9.0/10 | **9.0/10** (stable) | Evaluation | Fin sprint |

### Bilan des 10 Sprints (progression cumulative)

| Sprint | Objectif | Score | Nature |
|--------|----------|-------|--------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI | 5.5 -> 6.5 | Technique |
| Sprint 2 - Riverpod | State management, DI | 6.5 -> 7.0 | Technique |
| Sprint 3 - Tests & CI | Couverture tests | 7.0 -> 7.5 | Technique |
| Sprint 4 - BDD Locale | drift SQLite, migration | 7.5 -> 8.0 | Technique |
| Sprint 5 - Navigation & HTTP | go_router, Dio | 8.0 -> 8.5 | Technique |
| Sprint 6 - Migration HTTP | Elimination http direct | 8.5 -> 8.5 | Technique |
| Sprint 7 - Refactoring | Controllers, tests, navigation | 8.5 -> 9.0 | Technique |
| Sprint 8 - Polish | Widgets, analyse, theme | 9.0 -> 9.0 (en pause) | Technique |
| Sprint 9 - Quick Wins | 5 features utilisateur | 9.0 (stable) | **FEATURE** |
| **Sprint 10 - Import/Export & Legalite** | **Import, export, legalite, tags** | **9.0 (stable)** | **FEATURE** |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| R-10.1 | Parsing formats externes varie (espaces, annotations, set codes) | Tech/QA | Haute | Moyen | Regex tolerant + nettoyage agressif + tests 8 variantes | Dev |
| R-10.2 | Resolution noms echoue (FR, accents, double-face) | Tech | Haute | Moyen | Split "//" pour face, fallback LOCAL:, avertissement utilisateur | Dev |
| R-10.3 | Regles legalite Commander complexes (singleton, identite couleur, basic land) | Tech/QA | Moyenne | Haut | Tests specifiques pour chaque edge case + donnees Scryfall fiables | Dev |
| R-10.4 | Regression refactoring importDeck | Tech | Moyenne | Haut | Tests existants preserves + nouveaux tests + DeckFormatService en abstraction | Dev |
| R-10.5 | CSV non standardise entre apps (delimiteurs, guillemets) | Tech | Moyenne | Moyen | Auto-detection delimiteur + parser CSV robuste | Dev |
| R-10.6 | Vintage restricted rules | Biz | Faible | Moyen | Test specifique, liste restricted dans Scryfall legalities | Dev |
| R-10.7 | Budget 9j serre (0j marge) | Process | Moyenne | Moyen | US-10.4 (tags) reportable si retard | Dev |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence |
|----------------|---------------------|-------|-----------|
| Alexis (dev) | Progression des US, blocages | Documents docs/ | A chaque US |
| CI/CD | Status pipeline | GitHub Actions | Automatique |
| **Joueurs migrants** | **Import/export disponible** | **Release notes / changelog** | **Fin de sprint** |
| **Joueurs competitifs** | **Legalite disponible** | **Release notes / changelog** | **Fin de sprint** |

---

## 9. Journal de Decisions

| Decision | Contexte | Alternatives Considerees | Justification |
|----------|---------|--------------------------|---------------|
| Creer DeckFormatService separe | Le parser est reutilisable pour import et export | (a) Parser dans le controller (b) Service dedie (c) Mixin | Service dedie = testable isolement, reutilisable, pas de dependance Flutter |
| Remplacer validateDeckRules par LegalityService | validateDeckRules est un placeholder | (a) Enrichir validateDeckRules (b) Nouveau service | Nouveau service = logique pure, testable, couvre 8 formats au lieu de 4 |
| Parser tolerant (warnings, pas d'erreurs) | Les formats d'import varient | (a) Strict (rejeter si format invalide) (b) Tolerant (parser ce qu'on peut) | Tolerant = meilleure UX, le joueur voit ce qui a ete importe et ce qui manque |
| Tags via CollectionController (pas nouveau controller) | Le controller collection existe deja | (a) Nouveau TagController (b) Extension CollectionController | Extension = moins de code, meme pattern que DeckDetailController.updateTags |
| Export via share_plus (pas de sauvegarde locale) | L'export doit etre facile a partager | (a) Sauvegarder dans Documents (b) Share sheet (c) Les deux | Share sheet = pattern deja utilise dans BackupService, plus intuitif sur mobile |
| 8 formats de legalite | Scryfall supporte ~15 formats | (a) Tous les formats (b) Les 8 principaux (c) Seulement 4 | Les 8 principaux couvrent 99% des joueurs competitifs, les autres sont tres niche |

---

## 10. Top 5 Actions Immediates

1. **Creer** `lib/services/deck_format_service.dart` avec `parseDecklistText()` supportant les sections Commander/Deck/Sideboard + nettoyage des noms (set codes, double-face, foil) -- **Phase 1, tache #1**

2. **Ajouter** `parseDecklistCsv()` avec detection des colonnes par header et extraction des tags/categories -- **Phase 1, tache #2**

3. **Creer** `lib/services/legality_service.dart` avec `FormatRules` pour 8 formats et verification complete (legalities, taille, copies, singleton, identite couleur) -- **Phase 4, tache #16**

4. **Refactorer** `DeckListController.importDeck()` en `importDeckFromText()` utilisant `DeckFormatService.autoDetectAndParse()` + `_resolveCardNames()` batch -- **Phase 2, tache #6-7**

5. **Creer** `lib/widgets/decks/deck_legality_tab.dart` avec badges par format (vert/rouge) et ExpansionTile pour les violations -- **Phase 4, tache #18**

---

## Metriques de Succes Sprint 10

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 298 | >= 330 | A valider |
| Formats import | 1 (TXT basique) | 3 (TXT Moxfield, TXT MTGO, CSV) | A valider |
| Formats export | 0 | 3 (TXT, CSV, clipboard) | A valider |
| Formats legalite | 0 (placeholder) | 8 (Standard -> Brawl) | A valider |
| Tags collection | Non expose | CRUD + filtre | A valider |
| Score qualite | 9.0/10 | 9.0/10 (stable) | A valider |
| flutter analyze errors | 0 | 0 | A valider |
| Nouvelles dependances | 0 | 0 | A valider |

---

*"Nakamas ! Le Sprint 9 a ouvert l'appetit des joueurs avec 5 quick wins. Le Sprint 10, c'est le plat de resistance : on ouvre les portes de Magic Companion au monde entier. L'import ramene les joueurs de Moxfield et Archidekt. L'export leur dit 'tu es libre de partir, mais tu n'en auras pas envie'. La legalite plante notre drapeau dans le monde competitif. Et les tags, c'est la cerise -- l'organisation sur mesure. Apres ce sprint, Magic Companion n'est plus une app isolee. C'est un nakama de l'ecosysteme MTG."* -- Luffy, Capitaine
