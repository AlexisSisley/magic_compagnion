# Sprint 9 - Synthese Capitaine : Quick Wins Features
> Agent : Luffy (Capitaine) | Date : 01/03/2026

---

## 1. Resume Executif

Le Sprint 9 est le **premier sprint de features utilisateur** depuis le lancement du projet. Apres 8 sprints de refactoring technique (score 5.5 -> 9.0/10), l'infrastructure est solide et Magic Companion est pret a recevoir de la valeur visible pour les joueurs. Ce sprint implemente les **5 quick wins** identifies par l'audit Yamato (veille concurrentielle) : indicateur de collection, tri par prix, bouton d'ajout au deck, filtre budget, et tokens requis par le deck. Budget : **5 jours**, effort maitrise car les donnees et composants existent deja dans le code -- il suffit de les connecter et de les exposer dans l'interface.

**Changement de nature** : Pour la premiere fois, ce sprint est tourne vers **l'utilisateur final**. Les joueurs MTG vont voir des changements concrets a chaque ecran. C'est un moment charniere pour l'adoption de l'app.

---

## 2. Synthese d'Alignement

### Points de convergence

1. **Les 3 agents s'accordent sur l'ordre** : US-9.1 (badges collection) en priorite absolue, puis US-9.3 (bouton deck, le plus rapide), puis US-9.2+9.4 (tri+filtre prix), puis US-9.5 (tokens).
2. **Les 3 agents confirment que les donnees existent deja** : prix dans ScryfallCard, collection dans collectionProvider, DeckPickerModal deja fonctionnel. Le Sprint 9 est un sprint d'assemblage, pas de construction.
3. **Risque principal unanime** : la performance du badge collection. Mitigation : index `Map<String, int>` precalcule (O(1) lookup).

### Matrice d'alignement

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| Perimetre | 5 US, 11 SP, 5j | 2 fichiers crees, ~10 modifies | >= 290 tests, 0 errors | **Aligne** |
| Priorite P0 | US-9.1 (badges) | US-9.1 (index Map<String,int>) | US-9.1 (6 tests badge) | **Aligne** |
| Priorite P2 | US-9.5 (tokens) | US-9.5 (modification modele) | US-9.5 (3 tests tokens) | **Aligne** |
| Effort total | 5j | 5j (5 phases) | 18 tests nouveaux | **Aligne** |
| Risque principal | Gap concurrentiel | Performance index | Regression parsing ScryfallCard | **Convergent** |
| Sprint 8 backlog | Assume non bloquant | Assume non bloquant | PASS conditionnel | **Aligne** |

### Aucune tension identifiee

Pour la premiere fois dans l'historique des sprints, les 3 agents sont **parfaitement alignes** sur le perimetre, les priorites et les estimations. Ceci s'explique par la nature du sprint : features simples, donnees deja disponibles, infrastructure mature.

---

## 3. Arbitrage des Conflits

| Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---------|---------------|----------------|---------------|---------------------|---------------|
| Sprint 8 non termine | Assume que l'infra est stable | Non bloquant pour les features | PASS conditionnel | **Accepte : Sprint 9 lance malgre Sprint 8 incomplet** | Les features sont legeres et n'aggravent pas la dette. Le nettoyage technique (Sprint 8) pourra se faire en parallele ou apres. La valeur utilisateur est prioritaire apres 8 sprints techniques. |
| Filtre prix API vs client | Syntaxe Scryfall `eur<=X` possible | Filtre cote client recommande | Pas de preference | **Filtre cote client** | Plus simple a implementer, unifie API et local, pas de dependance a la syntaxe Scryfall avancee (prevue Sprint 12). |
| Tokens : API vs base locale | Pas de preference | API `/cards/collection` pour les images | Performance OK si cache | **API avec cache** | Le champ `all_parts` donne les IDs, une seule requete `/cards/collection` (max 75 IDs) recupere les images. Le cache Dio gere la retention. |
| Nombre de tests cible | Non specifie | >= 290 | >= 290 | **Cible : >= 290 tests** | Aligne Sanji et Nami. 18 nouveaux tests est un minimum raisonnable. |

---

## 4. Roadmap de Livraison

### Phase 1 : Modeles & Infrastructure (0.5j) -- Fondation

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 1 | Ajouter `RelatedCard` + `allParts` dans `ScryfallCard.fromJson` | Aucune | Parsing fonctionne, default [] | P0 |
| 2 | Ajouter `maxPrice` dans `SearchFilters` | Aucune | copyWith + hasActiveFilters OK | P1 |
| 3 | Tests modeles (5 tests) | #1, #2 | 278 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 278 PASS, parsing retrocompatible | | |

### Phase 2 : US-9.1 Indicateur Collection (1.5j) -- Impact Maximum

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 4 | Creer `CollectionBadge` model + `CollectionBadgeWidget` | Phase 1 | Widget render OK pour tous les cas | P0 |
| 5 | Ajouter index `Map<String,int>` dans `CardSearchState` | Phase 1 | Index construit en O(n) | P0 |
| 6 | Modifier `CardSearchController.loadLocalData()` | #5 | Index peuple correctement | P0 |
| 7 | Integrer badge dans `card_search_page.dart` | #4, #6 | Badge visible sur les tuiles | P0 |
| 8 | Integrer badge dans `set_detail_page.dart` | #4 | Badge visible sur les tuiles du set | P0 |
| 9 | Enrichir info collection dans `card_detail_page.dart` | #4 | "Dans ma collection : X + Y foils" | P1 |
| 10 | Tests badge (6 tests) | #4 | 284 tests PASS | P0 |
| **Checkpoint** | Badges visibles sur recherche + set + detail. Tests verts. | | |

### Phase 3 : US-9.3 Bouton Ajout Deck (0.5j) -- Quick Win

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 11 | Ajouter `IconButton` "Ajouter au deck" dans `card_detail_page.dart` | Aucune | Bouton visible | P1 |
| 12 | Connecter au `DeckPickerModal` existant | #11 | Modal s'ouvre avec liste des decks | P1 |
| 13 | Ajouter SnackBar de confirmation | #12 | SnackBar affiche apres ajout | P1 |
| **Checkpoint** | Bouton fonctionnel. Test manuel OK. | | |

### Phase 4 : US-9.2 + US-9.4 Tri & Filtre Prix (1j) -- Budget Features

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 14 | Ajouter `price_asc`/`price_desc` dans `CardSearchController` | Aucune | Tri correct avec nulls en dernier | P1 |
| 15 | Passer `order`/`dir` a l'API Scryfall | #14 | Tri API natif fonctionne | P1 |
| 16 | Ajouter boutons de tri prix dans la UI | #14 | Options visibles dans le dropdown | P1 |
| 17 | Ajouter champ "Prix max" dans le modal de filtres | Phase 1 (#2) | Champ saisissable | P1 |
| 18 | Implementer `_applyPriceFilter` cote client | #17 | Filtre fonctionne API + local | P1 |
| 19 | Tests tri + filtre (5 tests) | #14, #18 | 289 tests PASS | P1 |
| **Checkpoint** | Tri et filtre prix fonctionnels. Tests verts. | | |

### Phase 5 : US-9.5 Tokens Deck (1.5j) -- Commander Feature

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 20 | Ajouter `tokens` dans `DeckDetailState` | Phase 1 (#1) | Champ present dans le state | P2 |
| 21 | Implementer `_computeTokens()` dans `DeckDetailController` | #20 | Tokens extraits et dedupliques | P2 |
| 22 | Creer `DeckTokensTab` widget | #21 | Affiche liste tokens avec images | P2 |
| 23 | Ajouter onglet "Tokens" dans `deck_detail_page.dart` | #22 | Onglet accessible et fonctionnel | P2 |
| 24 | Charger images tokens via `/cards/collection` | #21 | Images affichees, cache actif | P2 |
| 25 | Tests tokens (3 tests) | #21 | >= 290 tests PASS (cible finale) | P2 |
| **Checkpoint** | Onglet Tokens fonctionnel. Tests >= 290. Sprint termine. | | |

### Graphe de Dependances (Chemin Critique)

```
Phase 1 (0.5j) ──> Phase 2 (1.5j) ──> Phase 4 (1j) ──> Phase 5 (1.5j)
[Modeles]          [Badges]            [Tri+Filtre]      [Tokens]
                      │
                      └──> Phase 3 (0.5j) [parallele]
                           [Bouton Deck]
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 4 -> Phase 5 = **4.5j**
**Parallele** : Phase 3 (bouton deck) peut etre fait pendant Phase 2 ou Phase 4.
**Marge** : 0.5j sur le budget de 5j.

---

## 5. Estimation des Ressources & Efforts

| Phase | Effort | Cumul |
|-------|--------|-------|
| Phase 1 : Modeles | 0.5j | 0.5j |
| Phase 2 : Badges collection | 1.5j | 2j |
| Phase 3 : Bouton ajout deck (parallele) | 0.5j | (parallele) |
| Phase 4 : Tri + filtre prix | 1j | 3j |
| Phase 5 : Tokens deck | 1.5j | 4.5j |
| **Total** | **4.5j** (+0.5j parallele) | |

**Marge de securite** : 0.5j (sur le budget de 5j Zorro). Utilisable pour :
- Tests supplementaires si couverture insuffisante
- Amelioration UX des badges (animations, tooltips)
- Debug si l'API `all_parts` ne repond pas comme attendu

---

## 6. Indicateurs de Succes (KPIs)

| KPI | Valeur Actuelle | Cible Sprint 9 | Methode de Mesure | Frequence |
|-----|-----------------|-----------------|-------------------|-----------|
| Tests totaux | 273 | **>= 290** | `flutter test` | Apres chaque US |
| flutter analyze errors | 0 | **0** | `flutter analyze` | Apres chaque US |
| Features utilisateur | 0 nouvelles (Sprint 0) | **5 nouvelles** | Revue fonctionnelle | Fin sprint |
| Badge collection | Non existant | **Visible sur recherche + set + detail** | Test visuel | Fin Phase 2 |
| Options de tri | ~5 | **7** (+price_asc, +price_desc) | UI verification | Fin Phase 4 |
| Filtre prix max | Non existant | **Fonctionnel dans le modal** | Test fonctionnel | Fin Phase 4 |
| Onglet Tokens | Non existant | **Fonctionnel dans deck detail** | Test fonctionnel | Fin Phase 5 |
| Score qualite | 9.0/10 | **9.0/10** (stable, pas de refactoring) | Evaluation | Fin sprint |

### Bilan des 9 Sprints (progression cumulative)

| Sprint | Objectif | Score | Nature |
|--------|----------|-------|--------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI | 5.5 -> 6.5 | Technique |
| Sprint 2 - Riverpod | State management, DI | 6.5 -> 7.0 | Technique |
| Sprint 3 - Tests & CI | Couverture tests | 7.0 -> 7.5 | Technique |
| Sprint 4 - BDD Locale | drift SQLite, migration | 7.5 -> 8.0 | Technique |
| Sprint 5 - Navigation & HTTP | go_router, Dio | 8.0 -> 8.5 | Technique |
| Sprint 6 - Migration HTTP | Elimination http direct | 8.5 -> 8.5 | Technique |
| Sprint 7 - Refactoring | Controllers, tests, navigation | 8.5 -> 9.0 | Technique |
| Sprint 8 - Polish | Widgets, analyse, theme | 9.0 -> 9.0 (en cours) | Technique |
| **Sprint 9 - Quick Wins** | **5 features utilisateur** | **9.0 (stable)** | **FEATURE** |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| R-9.1 | Performance badge : boucle O(n) sur la collection a chaque build | Tech/QA | Moyen | Haut | Index Map<String,int> precalcule dans le State | Dev |
| R-9.2 | Prix EUR absent pour certaines cartes | Biz/Tech | Moyen | Moyen | Fallback USD, affichage "N/A", tri en dernier | Dev |
| R-9.3 | Regression parsing ScryfallCard avec allParts | Tech/QA | Faible | Haut | Default const [], tests unitaires dedies, champ additif | Dev |
| R-9.4 | Tokens non disponibles dans oracle-cards.json local | Tech | Moyen | Moyen | Requete API `/cards/collection` pour les tokens, cache Dio | Dev |
| R-9.5 | Sprint 8 incomplet degrade la base de code | Tech | Moyen | Faible | Les features Sprint 9 sont legeres et n'aggravent pas la dette | Dev |
| R-9.6 | UX surcharge avec trop de badges | Biz | Faible | Moyen | Design minimaliste : petit badge vert discret, icone coeur pour wishlist | Dev |
| R-9.7 | Filtre prix exclut trop de cartes (prix EUR manquants) | Biz | Moyen | Moyen | Option "Inclure les cartes sans prix" dans le filtre | Dev |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence |
|----------------|---------------------|-------|-----------|
| Alexis (dev) | Progression des US, blocages | Documents docs/ | A chaque US |
| CI/CD | Status pipeline | GitHub Actions | Automatique |
| **Utilisateurs** | **Nouvelles features** (premiere fois !) | **Release notes / changelog** | **Fin de sprint** |

---

## 9. Journal de Decisions

| Decision | Contexte | Alternatives Considerees | Justification |
|----------|---------|--------------------------|---------------|
| Lancer Sprint 9 malgre Sprint 8 incomplet | Sprint 8 est un sprint technique pur ; Sprint 9 est un sprint features | (a) Finir Sprint 8 d'abord (b) Lancer Sprint 9 en parallele (c) Fusionner Sprint 8 et 9 | La valeur utilisateur est prioritaire apres 8 sprints techniques. Les features Sprint 9 sont legeres et n'aggravent pas la dette. Le Sprint 8 peut etre repris plus tard. |
| Filtre prix cote client (pas API) | L'API Scryfall supporte `eur<=X` dans la query | (a) Filtre API (b) Filtre client (c) Les deux | Filtre client unifie API et local, plus simple, pas de dependance a la syntaxe Scryfall |
| Index Map pour badges collection | La collection peut atteindre 5000+ cartes | (a) Scan lineaire O(n) (b) Map O(1) (c) Set pour existence seulement | Map donne quantite + existence en O(1), performance critique pour le scroll |
| allParts avec default const [] | Le champ n'existe pas dans tous les JSONs | (a) Nullable (b) Default vide (c) Lazy loading | Default vide est le plus safe : retrocompatible, pas de null check partout |
| DeckPickerModal reutilise tel quel | Le modal existe et fonctionne | (a) Reutiliser (b) Creer un nouveau modal (c) Popup menu | Reutiliser = 0 code nouveau pour le modal, deja teste, UX coherente |

---

## 10. Top 5 Actions Immediates

1. **Ajouter** `RelatedCard` + `allParts` dans `ScryfallCard.fromJson` avec default `const []` + **3 tests** -- **Phase 1, tache #1 et #3**

2. **Creer** `lib/widgets/common/collection_badge.dart` avec le widget `CollectionBadgeWidget` + **6 tests** -- **Phase 2, tache #4**

3. **Modifier** `CardSearchController.loadLocalData()` pour construire les index `collectionIndex` / `collectionFoilIndex` / `wishlistCardNames` -- **Phase 2, tache #5-6**

4. **Ajouter** le bouton `IconButton(Icons.playlist_add)` dans `card_detail_page.dart` connecte au `DeckPickerModal` -- **Phase 3, tache #11-12**

5. **Ajouter** les options `price_asc` / `price_desc` dans le tri du `CardSearchController` et passer `order: 'eur'` a l'API -- **Phase 4, tache #14-15**

---

## Metriques de Succes Sprint 9

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 273 | >= 290 | A valider |
| Features nouvelles | 0 | 5 | A valider |
| Badge collection | Non existant | Visible (recherche, set, detail) | A valider |
| Tri par prix | Non existant | Fonctionnel (API + local) | A valider |
| Bouton ajout deck | Non existant | Fonctionnel (detail carte) | A valider |
| Filtre prix max | Non existant | Fonctionnel (modal filtres) | A valider |
| Onglet Tokens | Non existant | Fonctionnel (deck detail) | A valider |
| Score qualite | 9.0/10 | 9.0/10 (stable) | A valider |
| flutter analyze errors | 0 | 0 | A valider |

---

*"Ca y est, nakamas ! Apres 8 sprints a construire le Sunny, on va enfin naviguer ! Les joueurs MTG vont voir 5 vraies features -- badges de collection, tri par prix, ajout au deck en un tap, filtre budget, et tokens. C'est pas un refactoring, c'est pas du nettoyage -- c'est du CONCRET. Le One Piece des joueurs de cartes, c'est maintenant qu'on le cherche !"* -- Luffy, Capitaine
