# Sprint 11 - Synthese Capitaine : EDHREC Deep Integration
> Agent : Luffy (Capitaine) | Date : 01/03/2026

---

## 1. Resume Executif

Le Sprint 11 transforme l'onglet Suggestions de Magic Companion en un **assistant de deckbuilding Commander intelligent**. Aujourd'hui, le service EDHREC existant (96 lignes, 1 endpoint) affiche une liste plate de cartes sans score ni intelligence. Apres ce sprint, il exploitera 3 endpoints EDHREC pour offrir : des recommandations par **theme/tribu** (Infect, Voltron, +1/+1 Counters...), un **score de synergie** par carte et global, et une **detection automatique de combos** dans le deck du joueur. C'est le **troisieme sprint de features** apres les Sprints 9 (quick wins) et 10 (import/export/legalite). L'impact est strategique : aucune app mobile MTG concurrente n'offre cette profondeur d'integration EDHREC. Budget : **9 jours**, 3 semaines. 3 user stories, 10 story points.

**Changement de nature** : Le Sprint 10 ajoutait de l'interoperabilite (import/export) et de la confiance (legalite). Le Sprint 11 ajoute de l'**intelligence** -- Magic Companion comprend maintenant les decks et aide a les optimiser.

---

## 2. Synthese d'Alignement

### Points de convergence

1. **Les 3 agents s'accordent sur les priorites** : US-11.1 (themes) en P0 car c'est la fondation (enrichit le service), US-11.2 (synergie) en P0 car c'est la feature la plus visible et differenciante, US-11.3 (combos) en P1 car c'est la plus independante et reportable.
2. **Les 3 agents confirment que l'infrastructure existe** : EdhrecService avec Dio, _formatSlug, Provider Riverpod, DeckSuggestionsTab, DeckDetailController avec fullCardData, LocalCardService pour la resolution de noms. Le Sprint 11 enrichit l'existant, il ne cree pas de fondation.
3. **Risque principal unanime** : la stabilite de l'API EDHREC (pas de documentation officielle, pas de SLA). Mitigation : cache agressif (1h), parsing null-safe, fallback gracieux.
4. **Les 3 agents confirment 0 nouvelle dependance** : Dio est deja present, le cache est fait en memoire.

### Matrice d'alignement

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| Perimetre | 3 US, 10 SP, 9j | 3 fichiers crees, ~4 modifies | >= 400 tests, 0 errors | **Aligne** |
| Priorite P0 | US-11.1 (themes) | US-11.1 (enrichir service) | US-11.1 (12 tests service) | **Aligne** |
| Feature differenciante | US-11.2 (synergie) | US-11.2 (cross-reference deck) | US-11.2 (4 tests synergie) | **Aligne** |
| Feature P1 | US-11.3 (combos) | US-11.3 (detectCombos) | US-11.3 (5 tests combos) | **Aligne** |
| Effort total | 10j estime, 9j budget | 9j (5 phases) | ~40 tests nouveaux | **Converge** |
| Risque principal | API EDHREC instable | Parsing JSON null-safe + cache | Tests mock Dio obligatoires | **Convergent** |
| Nouvelle dependance | 0 | 0 | 0 | **Aligne** |

### Tensions identifiees

| Tension | Resolution |
|---------|-----------|
| Zorro estime 10 SP (10j), Sanji planifie 9j avec parallelisme | **Compatible** : Sanji utilise le parallelisme Phase 3/4 pour tenir en 9j. Si retard, US-11.3 reportable. |
| Nami demande >= 400 tests, Sanji estime ~408 | **Compatible** : Sanji depasse la cible Nami |
| Zorro veut un 8eme onglet "Combos", Sanji integre dans Suggestions | **Sanji decide** : integrer dans Suggestions pour eviter un 8eme onglet (UX mobile) |
| Nami veut des tests de cache, Sanji ne les mentionne pas explicitement | **Ajoute** : 2 tests de cache dans edhrec_service_test.dart |

---

## 3. Arbitrage des Conflits

| Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---------|---------------|----------------|---------------|---------------------|---------------|
| Combos dans un onglet separe ou dans Suggestions | Nouvel onglet "Combos" | Section dans Suggestions | Tester les deux options | **Section dans Suggestions** | L'app a deja 7 onglets. Un 8eme compliquerait l'UX mobile. Les combos sont thematiquement lies aux suggestions. |
| Nombre max de combos affiches | Pas de preference | 50 max | Tester la performance | **50 combos max** (tries par popularite) | 3000+ combos pour Atraxa serait ingerable. 50 couvre les plus pertinents. |
| Seuil minimum de themes | Pas de preference | 50 decks minimum | Tester le filtre | **50 decks minimum** | Evite les themes trop obscurs (ex: 3 decks) qui polluent l'UX. |
| Conservation de getRecommendations() | Hors scope | Conserver pour retrocompatibilite | Tester la retrocompatibilite | **Conserver** | La methode est utilisee par DeckSuggestionsTab. Meme si le widget sera refactorise, la methode reste disponible. |
| Score global : moyenne simple ou ponderee | Score global 0-100 | Moyenne normalisee -1/+1 -> 0-100 | Tester le cas 0 cartes | **Normalisation (-1,+1) -> (0,100) avec clamp** | Plus intuitif pour l'utilisateur. 50 = neutre, >70 = bon, <30 = faible synergie. |

---

## 4. Roadmap de Livraison

### Phase 1 : Modeles EDHREC (1j) -- Fondation

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 1 | Creer `lib/models/edhrec_models.dart` avec EdhrecCardSuggestion, EdhrecTheme, EdhrecCombo, EdhrecCommanderData, DeckSynergyReport, CardSynergyEntry, DeckComboStatus | Aucune | Modeles compilent, fromJson fonctionnels | P0 |
| 2 | Tests edhrec_models_test.dart (15 tests : fromJson, categoryLabel, edge cases) | #1 | 383 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 383 PASS, modeles prets | | |

### Phase 2 : Enrichissement EdhrecService (2j) -- Intelligence

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 3 | Ajouter `getCommanderData()` avec parsing complet (suggestions enrichies + themes + combos resume) | Phase 1 | Retourne EdhrecCommanderData avec toutes les sections | P0 |
| 4 | Ajouter `getThemeCards()` avec lazy loading et cache | #3 | Cartes d'un theme retournees | P0 |
| 5 | Ajouter `getCommanderCombos()` avec limit 50 et cache | #3 | Top 50 combos retournes | P1 |
| 6 | Implementer le systeme de cache `_CacheEntry` (TTL 1h) | #3 | Cache fonctionne, expire apres 1h | P0 |
| 7 | Tests edhrec_service_test.dart (12 tests avec mock Dio) | #3-#6 | 395 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 395 PASS, service enrichi fonctionnel | | |

### Phase 3 : Score de Synergie & Themes UI (2j) -- Differentiation

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 8 | Ajouter `generateSynergyReport()` dans DeckDetailController | Phase 2 | Rapport avec score global + entries | P0 |
| 9 | Refactorer `DeckSuggestionsTab` pour utiliser EdhrecCommanderData | Phase 2 | Suggestions enrichies avec synergy/inclusion | P0 |
| 10 | Ajouter bandeau score global de synergie (jauge coloree) | #8, #9 | Bandeau affiche en haut des suggestions | P0 |
| 11 | Ajouter section themes (chips horizontaux + lazy loading) | #9 | Chips affiches, clic charge les cartes du theme | P0 |
| 12 | Tests synergie (5 tests controller + 3 tests widget) | #8-#11 | 403 tests PASS | P0 |
| **Checkpoint** | Themes + synergie affiches, score global visible | | |

### Phase 4 : Detection de Combos (2j) -- Plan de Jeu

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 13 | Ajouter `detectCombos()` dans DeckDetailController | Phase 2 | Detection complete/partial/none fonctionnelle | P1 |
| 14 | Creer `DeckCombosSection` widget | #13 | Combos affiches avec badges et cartes manquantes | P1 |
| 15 | Integrer DeckCombosSection dans DeckSuggestionsTab (section en bas) | #14 | Section accessible dans l'onglet Suggestions | P1 |
| 16 | Tests combos (5 tests controller + 4 tests modeles + 2 tests widget) | #13-#15 | >= 410 tests PASS | P1 |
| **Checkpoint** | Combos detectes et affiches avec tri et badges | | |

### Phase 5 : Integration & Validation Finale (1j)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 17 | Test regression complet (`flutter test`) | Toutes | >= 400 tests PASS, 0 fail | P0 |
| 18 | `flutter analyze` : 0 errors | Toutes | 0 errors | P0 |
| 19 | Test manuel E2E : suggestions -> theme -> synergie -> combos | Toutes | Workflow complet fonctionne | P0 |
| 20 | Mise a jour ROADMAP_MUGIWARA.md | Toutes | Sprint 11 marque TERMINE | P1 |

### Graphe de Dependances (Chemin Critique)

```
Phase 1 (1j) ──> Phase 2 (2j) ──> Phase 3 (2j) ──> Phase 5 (1j)
[Modeles]         [Service]         [Synergie+Themes]   [Integration]
                      │                    │
                      └──> Phase 4 (2j) ──┘
                           [Combos, parallele Phase 3]
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3 -> Phase 5 = **6j**
**Parallele** : Phase 4 (combos, 2j) peut commencer en parallele de Phase 3 apres Phase 2
**Total** : 9j (avec parallelisme)

---

## 5. Estimation des Ressources & Efforts

| Phase | Effort | Cumul |
|-------|--------|-------|
| Phase 1 : Modeles EDHREC | 1j | 1j |
| Phase 2 : Enrichissement Service | 2j | 3j |
| Phase 3 : Synergie & Themes UI | 2j | 5j |
| Phase 4 : Combos (parallele a Phase 3) | 2j | 7j |
| Phase 5 : Integration & Validation | 1j | 8j |
| **Total** | **8j** (avec parallelisme) | |

**Marge de securite** : 1j de marge sur un budget de 9j. Si la Phase 4 (combos) prend du retard, la marge absorbe. Si la marge est insuffisante, US-11.3 (combos) est reportable au Sprint 12.

---

## 6. Indicateurs de Succes (KPIs)

| KPI | Valeur Actuelle | Cible Sprint 11 | Methode de Mesure | Frequence |
|-----|-----------------|-----------------|-------------------|-----------|
| Tests totaux | 368 | **>= 400** | `flutter test` | Apres chaque US |
| flutter analyze errors | 0 | **0** | `flutter analyze` | Apres chaque US |
| Endpoints EDHREC | 1 | **3** (commander, themes, combos) | Revue fonctionnelle | Fin Phase 2 |
| Themes affiches | 0 | **Tous** (>50 decks) | Revue fonctionnelle | Fin Phase 3 |
| Score synergie | Non | **Oui** (par carte + global) | Revue fonctionnelle | Fin Phase 3 |
| Combos detectes | Non | **Oui** (top 50 + presence deck) | Revue fonctionnelle | Fin Phase 4 |
| Score qualite | 9.0/10 | **9.0/10** (stable) | Evaluation | Fin sprint |

### Bilan des 11 Sprints (progression cumulative)

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
| Sprint 10 - Import/Export & Legalite | Import, export, legalite, tags | 9.0 (stable) | **FEATURE** |
| **Sprint 11 - EDHREC Deep Integration** | **Themes, synergie, combos** | **9.0 (stable)** | **FEATURE (intelligence)** |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| R-11.1 | API EDHREC indisponible ou changement structure JSON | Tech | Moyenne | Haut | Cache 1h, parsing null-safe, fallback suggestions de base | Dev |
| R-11.2 | Volume combos trop important (3000+ pour commandants populaires) | Tech | Haute | Moyen | Limit 50 combos tries par popularite | Dev |
| R-11.3 | Cross-reference noms deck/EDHREC echoue | Tech | Moyenne | Moyen | Comparaison case-insensitive, split double-face | Dev |
| R-11.4 | Themes EDHREC non disponibles pour certains commandants | Biz | Moyenne | Faible | Section themes cachee si vide, suggestions generales preservees | Dev |
| R-11.5 | Score de synergie non representatif (peu de cartes matchees) | Biz | Moyenne | Faible | Afficher "X/Y cartes analysees", avertissement si < 30% matchees | Dev |
| R-11.6 | Budget 9j avec 10 SP | Process | Moyenne | Moyen | 1j de marge, US-11.3 reportable si retard | Dev |
| R-11.7 | Rate limit EDHREC (non documente) | Tech | Faible | Haut | Max 5 req/sec, cache agressif, lazy loading themes | Dev |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence |
|----------------|---------------------|-------|-----------|
| Alexis (dev) | Progression des US, blocages | Documents docs/ | A chaque US |
| CI/CD | Status pipeline | GitHub Actions | Automatique |
| **Joueurs Commander** | **Intelligence deckbuilding disponible** | **Release notes / changelog** | **Fin de sprint** |

---

## 9. Journal de Decisions

| Decision | Contexte | Alternatives Considerees | Justification |
|----------|---------|--------------------------|---------------|
| Enrichir EdhrecService plutot que creer un nouveau service | Le service existe et est injecte via Riverpod | (a) Nouveau service EdhrecDeepService (b) Enrichir l'existant | Enrichir = moins de code, meme provider, retrocompatibilite |
| Combos dans Suggestions, pas un onglet separe | 7 onglets existants (TabController) | (a) 8eme onglet (b) Section dans Suggestions (c) Page separee | Section dans Suggestions = coherence thematique, pas de 8eme onglet |
| Cache memoire 1h | Les donnees EDHREC sont stables (maj hebdomadaire) | (a) Cache drift persistent (b) Cache memoire (c) Pas de cache | Cache memoire = simple, 1h suffit, pas besoin de persistance |
| Limit 50 combos | Atraxa a 3000+ combos | (a) Tous les combos (b) Top 50 (c) Top 20 | Top 50 = assez pour couvrir les populaires, pas trop pour l'UX |
| Score global normalise 0-100 | Le synergy EDHREC est -1 a +1 | (a) Garder le float (b) Normaliser 0-100 (c) Etoiles 1-5 | 0-100 = intuitif, comparable, affichable comme jauge |
| Themes filtres > 50 decks | Certains themes ont < 10 decks | (a) Aucun filtre (b) > 50 (c) > 100 | > 50 = filtre les themes non significatifs sans etre trop restrictif |

---

## 10. Top 5 Actions Immediates

1. **Creer** `lib/models/edhrec_models.dart` avec `EdhrecCardSuggestion`, `EdhrecTheme`, `EdhrecCombo`, `EdhrecCommanderData`, `DeckSynergyReport`, `CardSynergyEntry`, `DeckComboStatus` -- **Phase 1, tache #1**

2. **Enrichir** `lib/services/edhrec_service.dart` avec `getCommanderData()` (parsing complet : suggestions enrichies, themes, combos resume, cache 1h) -- **Phase 2, tache #3**

3. **Ajouter** `generateSynergyReport()` dans `DeckDetailController` (cross-reference deck/EDHREC, score global normalise 0-100) -- **Phase 3, tache #8**

4. **Refactorer** `DeckSuggestionsTab` pour afficher les themes (chips), les scores de synergie (badges), les taux d'inclusion, et le bandeau score global -- **Phase 3, taches #9-#11**

5. **Creer** `lib/widgets/decks/deck_combos_section.dart` avec detection complete/partiel/none, badges, et cartes manquantes -- **Phase 4, tache #14**

---

## Metriques de Succes Sprint 11

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 368 | >= 400 | A valider |
| Endpoints EDHREC | 1 | 3 (commander, themes, combos) | A valider |
| Themes affiches | 0 | Tous (>50 decks) | A valider |
| Score synergie | Non | Oui (par carte + global) | A valider |
| Combos detectes | Non | Oui (top 50 + presence deck) | A valider |
| Score qualite | 9.0/10 | 9.0/10 (stable) | A valider |
| flutter analyze errors | 0 | 0 | A valider |
| Nouvelles dependances | 0 | 0 | A valider |

---

*"Nakamas ! Les Sprints 9 et 10 ont ouvert les portes de Magic Companion au monde. Le Sprint 11, c'est le cerveau. Jusqu'ici, on stockait des decks. Maintenant, on les comprend. Les themes disent au joueur 'ton commandant peut faire CA'. Le score de synergie lui dit 'CETTE carte est faite pour TON deck'. Les combos lui revelent 'regarde, tu as deja la moitie d'une victoire dans ton deck, il te manque juste une carte'. C'est la difference entre un coffre au tresor et une carte au tresor. Apres ce sprint, Magic Companion ne stocke plus des decks -- il aide a les construire intelligemment. Et ca, aucune autre app mobile ne le fait."* -- Luffy, Capitaine
