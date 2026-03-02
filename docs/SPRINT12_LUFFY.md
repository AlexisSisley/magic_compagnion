# Sprint 12 - Synthese Capitaine : Features Avancees, Refactoring & Backlog Technique
> Agent : Luffy (Capitaine) | Date : 01/03/2026

---

## 1. Resume Executif

Le Sprint 12 est le **sprint de maturite** de Magic Companion. Apres 8 sprints techniques (fondations, Riverpod, tests, BDD, navigation, HTTP, refactoring, polish) et 3 sprints de features (quick wins, import/export/legalite, EDHREC intelligence), le Sprint 12 comble les derniers gaps fonctionnels identifies par l'audit Yamato tout en soldant le backlog technique critique.

**Double nature** : Sprint mixte features + refactoring.
- **Features** (Tier 1, 13j) : Syntaxe Scryfall avancee (A7), Power Level Commander (E1), Salt score (E3), Rulings Scryfall
- **Refactoring** (Tier 2, 10j) : Recherche multilangue (A4), Centralisation Colors (1625 occ.), Centralisation GoogleFonts (325 occ.), GameSetupModalController
- **Backlog technique** (Tier 3, 9j) : ML Kit dependency overrides, Bulk Data auto-update, Catalogs dynamiques

**Budget** : 32 jours, 5 semaines. **10 user stories**, 32 story points. **Cible tests** : >= 500 (433 + ~72 nouveaux).

**Changement de nature** : Les Sprints 9-10-11 ajoutaient des features utilisateur. Le Sprint 12 consolide le tout : le joueur avance obtient la syntaxe Scryfall, le deckbuilder Commander obtient le power level et le salt score, les regles sont enfin in-app, et sous le capot, 1950 occurrences hardcodees sont centralisees pour preparer le futur (themes, i18n).

---

## 2. Synthese d'Alignement

### Points de convergence

1. **Les 3 agents s'accordent sur les Tier 1 (P0)** : US-12.1 (syntaxe), US-12.2 (power level), US-12.3 (salt), US-12.4 (rulings) sont les 4 must-have. Les Tiers 2 et 3 sont reportables.
2. **Les 3 agents confirment que l'infrastructure existe** : ScryfallApiService.getCardRulings(), searchCards(lang:), EdhrecService enrichi Sprint 11, DeckDetailController avec synergie/combos. Le Sprint 12 exploite l'existant.
3. **Risque principal unanime** : Centralisation Colors (1625 occurrences dans 58+ fichiers) = risque de regression visuelle. Mitigation : migration par lots avec tests apres chaque lot.
4. **Nouveaux packages** : 0 pour Tier 1 et 2. Potentiellement `sqlcipher_flutter_libs` pour le chiffrement (hors scope).
5. **Les 3 agents convergent sur >= 500 tests cible** : Sanji estime ~505, Nami demande >= 500. Compatible.

### Matrice d'alignement

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| Perimetre | 10 US, 32 SP, 32j | 6 phases, ~12 fichiers crees/modifies | >= 500 tests, 0 errors | **Aligne** |
| Tier 1 P0 | Syntaxe + Power + Salt + Rulings | 4 features, 23j budget | 32 tests automatises | **Aligne** |
| Feature differenciante | Power Level (E1) | Heuristique locale, 6 facteurs | 12 tests exhaustifs | **Aligne** |
| Risque principal | Regression Colors | Migration par lots | Tests visuels manuels | **Convergent** |
| Effort total | 32j / 5 semaines | 32j (6 phases avec parallelisme) | ~72 nouveaux tests | **Converge** |
| Hors scope | i18n, chiffrement, push | Pas de nouveau package | -- | **Aligne** |

### Tensions identifiees

| Tension | Resolution |
|---------|-----------|
| Zorro estime 32j pour 10 US, budget = 32j (aucune marge) | **Phase 5 (9j) est reportable** au Sprint 13 si retard. Tire 1+2 (23j) = coeur du sprint |
| Nami demande review visuelle complete apres Colors | **Accepte** : Ajouter 0.5j de test visuel apres chaque lot de migration Colors |
| Sanji propose migration Colors par lots, Zorro veut tout d'un coup | **Sanji decide** : par lots pour limiter le risque |
| Nami exige 0 regression, Colors touche 58 fichiers | **Compatible** : migration automatisee par recherche/remplacement + review visuelle |

---

## 3. Arbitrage des Conflits

| Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---------|---------------|----------------|---------------|---------------------|---------------|
| Power Level subjectif | Transparence des facteurs | Heuristique ponderee | Tester les cas extremes | **Heuristique + facteurs transparents** | Le joueur voit les 6 facteurs et comprend le score. Ajustable dans un futur sprint. |
| isAdvancedSyntax: conservative vs aggressive | Pas de preference | Regex conservatrice | Tester les edge cases | **Regex conservatrice** | Mieux vaut traiter une query avancee comme simple (recherche par nom qui marche quand meme) que l'inverse (erreur API). |
| Colors: tout migrer vs migration partielle | Tout migrer (32j budget) | Par lots progressifs | 0 regression | **Tout migrer dans le sprint, par lots** | Le budget permet 5j. Migration complete = dette technique soldee. |
| Bulk Data: background download | Feature P2 | Dio streaming | Tester timeout | **Reportable si retard** | P2, non critique. Si le temps manque, Sprint 13. |
| i18n: inclure ou exclure | Hors scope | Hors scope | Pas de tests i18n | **Hors scope Sprint 12** | 5j estime, 102 fichiers, trop gros pour ce sprint. Sprint 13. |

---

## 4. Roadmap de Livraison

### Phase 1 : Salt Score + Rulings (5j) -- Quick Wins

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 1 | Ajouter champ `salt` dans EdhrecCardSuggestion.fromJson + tests | Aucune | Modele compile, salt parse | P0 |
| 2 | Ajouter `averageSalt` dans DeckSynergyReport | #1 | Moyenne calculee | P0 |
| 3 | Badge salt dans DeckSuggestionsTab | #2 | Badge affiche | P0 |
| 4 | Tests salt (5 tests) | #1-#3 | 438 tests PASS | P0 |
| 5 | Ajouter `loadRulings()` dans CardDetailController | Aucune | Rulings charges | P0 |
| 6 | Creer RulingsSection widget + lazy loading | #5 | Rulings affiches | P0 |
| 7 | Integrer dans CardDetailPage | #6 | Section visible | P0 |
| 8 | Tests rulings (10 tests) | #5-#7 | 448 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 448 PASS, salt + rulings fonctionnels | | |

### Phase 2 : Syntaxe Scryfall + Multilangue (6j)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 9 | isAdvancedScryfallSyntax() + modification recherche | Aucune | Detection fiable | P0 |
| 10 | ScryfallSyntaxHelp widget + bouton aide | #9 | Modal affichee | P0 |
| 11 | Tests syntaxe (10 tests + 3 widget) | #9-#10 | 461 tests PASS | P0 |
| 12 | searchLanguage dans SearchFilters + dropdown | Aucune | Langue selectionnable | P1 |
| 13 | Passer lang a searchApi + fallback | #12 | Resultats multilingues | P1 |
| 14 | Tests multilangue (5 tests) | #12-#13 | 466 tests PASS | P1 |
| **Checkpoint** | `flutter test` >= 466 PASS, syntaxe + multilangue fonctionnels | | |

### Phase 3 : Power Level (5j) -- Feature Differenciante

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 15 | DeckPowerLevel modele | Aucune | Modele compile | P0 |
| 16 | estimatePowerLevel() + 6 helpers dans DeckDetailController | Sprint 11 data | Score 1-10 correct | P0 |
| 17 | DeckPowerLevelBadge widget | #16 | Badge affiche | P0 |
| 18 | Integrer dans DeckDetailPage | #17 | Visible dans onglet | P0 |
| 19 | Tests power level (12 tests + 3 widget) | #15-#18 | 481 tests PASS | P0 |
| **Checkpoint** | `flutter test` >= 481 PASS, power level affiche | | |

### Phase 4 : GameSetupModal + Colors/Fonts (7j)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 20 | Extraire GameSetupModalController + refactorer widget | Aucune | Controller fonctionnel | P1 |
| 21 | Tests GameSetupModalController (20 tests) | #20 | 501 tests PASS | P1 |
| 22 | Creer AppColors + AppTextStyles | Aucune | Fichiers compiles | P1 |
| 23 | Migrer Colors -> AppColors : pages (19 fichiers) | #22 | 0 regression visuelle | P1 |
| 24 | Migrer Colors -> AppColors : widgets (30+ fichiers) | #22 | 0 regression visuelle | P1 |
| 25 | Migrer Colors -> AppColors : controllers + autres | #22 | 0 regression visuelle | P1 |
| 26 | Migrer GoogleFonts.cinzel -> AppTextStyles (52 fichiers) | #22 | < 10 occ. directes | P1 |
| **Checkpoint** | `flutter test` >= 501 PASS, Colors < 100 occ., Fonts < 10 occ. | | |

### Phase 5 : Backlog Technique (9j) -- Reportable

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 27 | Resoudre dependency overrides ML Kit | Aucune | Build sans overrides | P2 |
| 28 | Tester scanner avec nouvelles versions | #27 | Scanner fonctionnel | P2 |
| 29 | Creer BulkDataService + integration settings | Aucune | Download en background | P2 |
| 30 | Tests BulkDataService (10 tests) | #29 | 511 tests PASS | P2 |
| 31 | getCatalog() + integration filtres dynamiques | Aucune | Catalogs integres | P2 |
| 32 | Tests catalogs (5 tests) | #31 | 516 tests PASS | P2 |
| **Checkpoint** | Si tout: `flutter test` >= 516 PASS | | |

### Phase 6 : Integration & Validation Finale (1j)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 33 | Test regression complet (`flutter test`) | Toutes | >= 500 tests PASS, 0 fail | P0 |
| 34 | `flutter analyze` : 0 errors | Toutes | 0 errors | P0 |
| 35 | Test manuel E2E complet | Toutes | Workflow complet fonctionne | P0 |
| 36 | Mise a jour ROADMAP_MUGIWARA.md | Toutes | Sprint 12 marque TERMINE | P1 |

### Graphe de Dependances (Chemin Critique)

```
Phase 1 (5j) ──> Phase 2 (6j) ──> Phase 3 (5j) ──> Phase 6 (1j)
[Salt+Rulings]    [Syntaxe+Lang]    [Power Level]    [Integration]
                       │                   │
Phase 4 (7j) ─────────┘──────────────────┘
[GameSetup+Colors]     (parallele a Phase 2-3)

Phase 5 (9j) ──────────────────────────────────> Phase 6
[Backlog P2]           (parallele, REPORTABLE)
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3 -> Phase 6 = **17j**
**Parallele** : Phase 4 (7j) et Phase 5 (9j) en parallele des Phases 2-3
**Total** : 32j avec parallelisme sur 5 semaines
**Si retard** : Phase 5 -> Sprint 13 (economise 9j)

---

## 5. Estimation des Ressources & Efforts

| Phase | Effort | Cumul | Reportable |
|-------|--------|-------|------------|
| Phase 1 : Salt Score + Rulings | 5j | 5j | Non |
| Phase 2 : Syntaxe Scryfall + Multilangue | 6j | 11j | Non |
| Phase 3 : Power Level | 5j | 16j | Non |
| Phase 4 : GameSetupModal + Colors/Fonts | 7j | 23j | Partiellement (Fonts) |
| Phase 5 : Backlog Technique | 9j | 32j | **Oui, entierement** |
| Phase 6 : Integration | 1j | 33j | Non |
| **Total** | **33j** (1j de marge negative) | | |

**Plan B** : Si le budget est serre, Phase 5 (9j) est entierement reportable au Sprint 13. Le coeur du sprint (Phases 1-4 + 6 = 24j) tient confortablement dans 5 semaines.

---

## 6. Indicateurs de Succes (KPIs)

| KPI | Valeur Actuelle | Cible Sprint 12 | Methode de Mesure | Frequence |
|-----|-----------------|-----------------|-------------------|-----------|
| Tests totaux | 433 | **>= 500** | `flutter test` | Apres chaque US |
| flutter analyze errors | 0 | **0** | `flutter analyze` | Apres chaque US |
| Colors.xxx + Color(0x) directes | 1625 | **< 100** | grep | Fin Phase 4 |
| GoogleFonts.cinzel directes | 325 | **< 10** | grep | Fin Phase 4 |
| Fichiers > 500 lignes | 17 | **< 15** | wc -l | Fin sprint |
| Power Level automatique | Non | **Oui** | Revue fonctionnelle | Fin Phase 3 |
| Salt Score | Non | **Oui** | Revue fonctionnelle | Fin Phase 1 |
| Syntaxe recherche avancee | Non | **Oui** | Revue fonctionnelle | Fin Phase 2 |
| Recherche multilangue | Non | **Oui (11 langues)** | Revue fonctionnelle | Fin Phase 2 |
| Rulings in-app | Non | **Oui** | Revue fonctionnelle | Fin Phase 1 |
| Score qualite | 9.0/10 | **9.5/10** | Evaluation | Fin sprint |

### Bilan des 12 Sprints (progression cumulative)

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
| Sprint 11 - EDHREC Deep | Themes, synergie, combos | 9.0 (stable) | **FEATURE (intelligence)** |
| **Sprint 12 - Features + Refactor** | **Syntaxe, power, salt, rulings, colors** | **9.0 -> 9.5** | **FEATURE + TECHNIQUE** |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| R-12.1 | Regression visuelle Colors (1625 occ. dans 58 fichiers) | Tech | Haute | Haut | Migration par lots, review visuelle apres chaque lot | Dev |
| R-12.2 | Power level mal calibre ou subjectif | Biz | Moyenne | Moyen | 6 facteurs transparents, seuils ajustables | Dev |
| R-12.3 | Regex syntaxe Scryfall faux positifs | Tech | Moyenne | Moyen | Regex conservatrice, tests exhaustifs | Dev |
| R-12.4 | Bulk Data trop volumineux (100MB+) | Tech | Moyenne | Haut | Streaming download, indicateur progression | Dev |
| R-12.5 | ML Kit dependency overrides cassent le build | Tech | Moyenne | Haut | Branch isolee, rollback possible | Dev |
| R-12.6 | Budget 32j serre (33j estimes) | Process | Haute | Moyen | Phase 5 (9j) reportable Sprint 13 | Dev |
| R-12.7 | Salt score absent dans certaines reponses EDHREC | Tech | Faible | Faible | Default 0.0, pas d'affichage si 0 | Dev |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence |
|----------------|---------------------|-------|-----------|
| Alexis (dev) | Progression des US, blocages | Documents docs/ | A chaque phase |
| CI/CD | Status pipeline | GitHub Actions | Automatique |
| **Joueurs MTG** | **Recherche avancee, power level, rulings in-app** | **Release notes / changelog** | **Fin de sprint** |

---

## 9. Journal de Decisions

| Decision | Contexte | Alternatives Considerees | Justification |
|----------|---------|--------------------------|---------------|
| i18n hors scope Sprint 12 | Estime a 5j, 102 fichiers | (a) Inclure (b) Exclure | Trop gros pour ce sprint. Sprint 13 dedie. |
| Chiffrement BDD hors scope | Necessite sqlcipher | (a) Inclure (b) Exclure | Dependance lourde, pas demande par les utilisateurs. Sprint 13. |
| Push notifications hors scope | Necessite FCM + backend | (a) Inclure (b) Exclure | Necessite infra backend, pas dans le budget. |
| Power level : heuristique 6 facteurs | Pas de standard officiel | (a) Simple (CMC seul) (b) 6 facteurs (c) ML | 6 facteurs = bon equilibre precision/complexite. ML trop lourd. |
| Syntaxe detection : regex conservatrice | 50+ operateurs Scryfall | (a) Parser complet (b) Regex partielle (c) Passthrough total | Regex = detecte 90% des cas, simple, fiable. Passthrough = trop de faux positifs. |
| Colors : migration complete vs partielle | 1625 occ. dans 58 fichiers | (a) Tout migrer (b) Pages seulement (c) Reporter | Tout migrer = dette technique soldee, prerequis themes. |
| Phase 5 : reportable | Budget serre (33j pour 32j budget) | (a) Couper Phase 5 (b) Couper Phase 4 | Phase 5 = P2, le moins impactant a reporter. |

---

## 10. Top 5 Actions Immediates

1. **Ajouter** le champ `salt` dans `EdhrecCardSuggestion.fromJson()` et `averageSalt` dans `DeckSynergyReport` -- **Phase 1, taches #1-#2**

2. **Implementer** `loadRulings()` dans `CardDetailController` + creer `RulingsSection` widget avec lazy loading dans `CardDetailPage` -- **Phase 1, taches #5-#7**

3. **Ajouter** `isAdvancedScryfallSyntax()` dans `CardSearchController` avec regex conservatrice + bouton aide syntaxique -- **Phase 2, taches #9-#10**

4. **Creer** `estimatePowerLevel()` dans `DeckDetailController` avec 6 facteurs (CMC, synergy, combos, interactions, mana base, card quality) + `DeckPowerLevelBadge` widget -- **Phase 3, taches #15-#18**

5. **Creer** `lib/theme/app_colors.dart` et `lib/theme/app_text_styles.dart` puis migrer les 1950 occurrences hardcodees par lots -- **Phase 4, taches #22-#26**

---

## Metriques de Succes Sprint 12

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 433 | >= 500 | A valider |
| flutter analyze errors | 0 | 0 | A valider |
| Colors directes | 1625 | < 100 | A valider |
| GoogleFonts directes | 325 | < 10 | A valider |
| Power Level | Non | Oui (1-10 + 6 facteurs) | A valider |
| Salt Score | Non | Oui (par carte + moyenne) | A valider |
| Syntaxe Scryfall | Non | Oui (detection + passthrough) | A valider |
| Multilangue | Non | Oui (11 langues) | A valider |
| Rulings in-app | Non | Oui (lazy loading) | A valider |
| Score qualite | 9.0/10 | 9.5/10 | A valider |

---

*"Nakamas ! On a traverse 11 sprints. Les 8 premiers ont construit le navire : fondations, Riverpod, tests, BDD, navigation, HTTP, controllers, polish. Les 3 suivants ont hisse les voiles : quick wins, import/export, intelligence EDHREC. Maintenant, le Sprint 12, c'est la ligne d'arrivee du Grand Line. La syntaxe Scryfall donne au joueur le pouvoir de chercher comme un pro. Le power level transforme l'intuition en science. Le salt score ajoute la diplomatie au deckbuilding. Les rulings rendent l'app autonome. Et la centralisation Colors, c'est le grand nettoyage avant le Nouveau Monde -- themes, i18n, tout ce qui vient apres. Apres ce sprint, Magic Companion n'est plus une app parmi d'autres. C'est l'app que les joueurs ne voudront plus quitter."* -- Luffy, Capitaine
