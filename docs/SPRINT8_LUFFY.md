# Sprint 8 - Synthese Capitaine : Widgets, Qualite & Polish
> Agent : Luffy (Capitaine) | Date : 28/02/2026

---

## 1. Resume Executif

Le Sprint 8 est le **sprint de polish** qui doit amener Magic Companion au score qualite **9.5/10**. Apres 7 sprints qui ont transforme le projet de 5.5 a 9.0/10, il reste trois chantiers : les **4 widgets God Files** (774-507 lignes chacun), les **1041 issues flutter analyze**, et les **5 pages encore >500 lignes** malgre l'extraction des controllers. Ce sprint est purement technique -- aucune nouvelle fonctionnalite -- mais il pose les bases pour l'i18n, le chiffrement et les evolutions futures. Budget : **15 jours**, objectif : **0 fichier applicatif >500 lignes**, **>300 tests**, **0 issue analyse**.

---

## 2. Synthese d'Alignement

### Points de convergence

1. **Les 3 agents s'accordent sur l'ordre** : US-8.1 (analyse statique) en premier, puis US-8.2 (controllers widgets), puis US-8.3 (sous-widgets pages). C'est la sequence optimale.
2. **Les 4 controllers widgets suivent le pattern Sprint 7** : StateNotifier + AutoDispose, coherent avec les 6 controllers existants.
3. **La cible de 0 issue flutter analyze est realiste** : les corrections sont en majorite automatisables (dart fix, search/replace).

### Matrice d'alignement

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| Perimetre | 5 US, 23 SP, 15j | Architecture 4 controllers + sous-widgets + theme + routeur | >300 tests, 0 issues, 9.5/10 | **Aligne** |
| Priorite P0 | US-8.1, 8.2, 8.3 | Phase 1 (analyse), Phase 2 (controllers) | Controllers + analyse = fondation | **Aligne** |
| Priorite P2 | US-8.5 (theme) -- repoussable | Phase 5 (theme) -- en dernier | Tests theme legers (5 tests) | **Aligne** |
| Effort controllers | 8 SP | 5j (4 controllers) | 24 tests unitaires | **Aligne** |
| Effort theme | 5 SP | 3.5j | Verification visuelle manuelle | **Tension legere** |
| Risque principal | Regression UI (extraction) | DeckCardPicker (logique complexe) | withOpacity migration | **Divergence** |

### Tension identifiee : US-8.5 (Theme)

- **Zorro** estime 5 SP (priorite P2, repoussable)
- **Sanji** estime 3.5j (333 GoogleFonts + 1536 Colors)
- **Nami** prevoit seulement 5 tests automatises + verification visuelle manuelle

Le theme est le chantier le plus "invisible" pour l'utilisateur mais le plus impactant en termes de maintenabilite. C'est aussi le plus risque visuellement.

---

## 3. Arbitrage des Conflits

| Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---------|---------------|----------------|---------------|---------------------|---------------|
| US-8.5 scope (theme) | Reduire a >80% migration GoogleFonts | Migration complete 333 + 1536 | Tests legers (5 tests) | **Partial : GoogleFonts uniquement (>80%), Colors repoussees Sprint 9** | Les 333 GoogleFonts sont un quick win (1 pattern unique). Les 1536 Colors sont dispersees et risquees. ROI meilleur en separant. |
| game_setup_modal (507 lignes) | Liste dans l'inventaire mais pas dans les US | Non inclus dans les 4 controllers cibles | Non mentionne dans la matrice | **Hors scope Sprint 8** -- son controller sera Sprint 9 | 507 lignes est juste au-dessus du seuil, priorite faible vs les 4 gros widgets |
| Nombre de tests cible | Non specifie | ~32 nouveaux (305 total) | >300 tests | **Cible : >= 305 tests** | Aligne Sanji et Nami. Priorite aux tests controllers (24 min) + theme (5) + marge. |
| flutter analyze --fatal-infos en CI | Non mentionne | Non mentionne | Recommande apres US-8.1 | **Accepte : ajouter --fatal-infos au CI apres US-8.1** | Previent la regression. Cout negligeable. |

---

## 4. Roadmap de Livraison

### Phase 1 : Nettoyage & Fondation (2j) -- US-8.1

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 1 | dart fix --apply (single_quotes, const, braces, non_null) | Aucune | 0 issues corrigibles par dart fix | P0 |
| 2 | Replace .withOpacity(x) -> .withValues(alpha: x) | #1 | 0 occurrences withOpacity | P0 |
| 3 | Corriger use_build_context_synchronously (23) | #1 | if (!mounted) return ajout | P0 |
| 4 | Corriger divers (empty_catches, underscores, etc.) | #1 | 0 issues restantes | P0 |
| 5 | Ajouter --fatal-infos au CI pipeline | #4 | Pipeline echoue si info apparait | P1 |
| **Checkpoint** | `flutter analyze` = 0 issues, `flutter test` = 273 PASS | | |

### Phase 2 : Controllers Widgets (5j) -- US-8.2

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 6 | DeckCardPickerController + 8 tests | Phase 1 | Widget <350 lignes, 8 tests PASS | P0 |
| 7 | CollectionListController + 6 tests | Phase 1 | Widget <350 lignes, 6 tests PASS | P0 |
| 8 | PlayerZoneController + 5 tests | Phase 1 | Widget <350 lignes, 5 tests PASS | P1 |
| 9 | DeckStatsController + 8 tests | Phase 1 | Widget <350 lignes, 8 tests PASS | P1 |
| **Checkpoint** | 4 widgets <350 lignes, ~300 tests, flutter analyze = 0 | | |

### Phase 3 : Pages & Routeur (4.5j) -- US-8.3 + US-8.4

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 10 | Extraire sous-widgets set_detail_page (5 widgets) | Phase 2 | <400 lignes | P0 |
| 11 | Extraire sous-widgets deck_detail_page + deck_list_page | Phase 2 | <400 lignes | P0 |
| 12 | Extraire sous-widgets card_search_page + card_detail_page | Phase 2 | <400 lignes | P0 |
| 13 | Decouper app_router.dart en sous-routeurs | Aucune (parallele) | <200 lignes, 23 routes OK | P1 |
| 14 | Extraire Drawer dans app_drawer.dart | #13 | Drawer fonctionnel | P1 |
| **Checkpoint** | 0 page >500 lignes, routeur <200 lignes, 23 routes valides | | |

### Phase 4 : Theme (3.5j) -- US-8.5 (scope reduit)

| # | Tache | Dependance | Critere PASS | Priorite |
|---|-------|------------|-------------|----------|
| 15 | Creer lib/theme/ (app_text_styles, app_colors, mtg_colors) | Phase 1 | Fichiers existent | P2 |
| 16 | Migrer GoogleFonts.cinzel -> AppTextStyles (333 -> <60) | #15 | <60 appels directs | P2 |
| 17 | Tests theme (3 tests) | #16 | Tests PASS | P2 |
| **Checkpoint** | GoogleFonts directs <60, tests theme PASS | | |

**Note** : La migration Colors. hardcodes est **reportee au Sprint 9** (decision d'arbitrage).

### Graphe de Dependances (Chemin Critique)

```
Phase 1 (2j) ──────┬──> Phase 2 (5j) ──────> Phase 3a (3j) ──> Phase 4 (3.5j)
[US-8.1 Analyse]    │   [US-8.2 Controllers]   [US-8.3 Pages]    [US-8.5 Theme]
                    │
                    └──> Phase 3b (1.5j) [parallele]
                         [US-8.4 Routeur]
```

**Chemin critique** : Phase 1 -> Phase 2 -> Phase 3a -> Phase 4 = **13.5j**
**Parallele** : Phase 3b (routeur) peut etre fait pendant Phase 2 ou 3a.

---

## 5. Estimation des Ressources & Efforts

| Phase | Effort | Cumul |
|-------|--------|-------|
| Phase 1 : Analyse statique | 2j | 2j |
| Phase 2 : Controllers widgets | 5j | 7j |
| Phase 3a : Sous-widgets pages | 3j | 10j |
| Phase 3b : Routeur (parallele) | 1.5j | (parallele) |
| Phase 4 : Theme (scope reduit) | 3.5j | 13.5j |
| **Total** | **13.5j** (+1.5j parallele) | |

**Marge de securite** : 1.5j (sur le budget de 15j Zorro). Utilisable pour :
- Corrections post-extraction si flutter test echoue
- Tests supplementaires si couverture insuffisante
- Debuts de migration Colors si Phase 4 termine en avance

---

## 6. Indicateurs de Succes (KPIs)

| KPI | Valeur Actuelle | Cible Sprint 8 | Methode de Mesure | Frequence |
|-----|-----------------|-----------------|-------------------|-----------|
| Tests totaux | 273 | **>= 305** | `flutter test` | Apres chaque US |
| flutter analyze issues | 1041 | **0** | `flutter analyze` | Apres chaque US |
| Fichiers pages >500 lignes | 5 | **0** | `wc -l lib/pages/**/*.dart` | Fin Phase 3a |
| Fichiers widgets >500 lignes | 5 | **0** (hors game_setup_modal) | `wc -l lib/widgets/**/*.dart` | Fin Phase 2 |
| Controllers Riverpod | 6 | **10** | `ls lib/controllers/` | Fin Phase 2 |
| app_router.dart lignes | 713 | **<200** | `wc -l` | Fin Phase 3b |
| GoogleFonts directs | 333 | **<60** | `grep -r "GoogleFonts" lib/ \| wc -l` | Fin Phase 4 |
| Score qualite global | 9.0/10 | **9.5/10** | Evaluation multicritere | Fin sprint |

### Bilan des 8 Sprints (progression cumulative)

| Sprint | Objectif | Score |
|--------|----------|-------|
| Sprint 1 - Fondations | Anti-patterns, lint, CI | 5.5 -> 6.5 |
| Sprint 2 - Riverpod | State management, DI | 6.5 -> 7.0 |
| Sprint 3 - Tests & CI | Couverture tests | 7.0 -> 7.5 |
| Sprint 4 - BDD Locale | drift SQLite, migration | 7.5 -> 8.0 |
| Sprint 5 - Navigation & HTTP | go_router, Dio | 8.0 -> 8.5 |
| Sprint 6 - Migration HTTP | Elimination http direct | 8.5 -> 8.5* |
| Sprint 7 - Refactoring | Controllers, tests, navigation | 8.5 -> 9.0 |
| **Sprint 8 - Polish** | **Widgets, analyse, theme** | **9.0 -> 9.5** |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| R-8.1 | Regression UI extraction sous-widgets set_detail_page | QA/Tech | Moyen | Haut | Extraire 1 widget a la fois, test visuel apres chaque extraction | Dev |
| R-8.2 | DeckCardPickerController casse recherche/pagination | Tech/QA | Moyen | Haut | 8 tests unitaires couvrant les cas nominaux et edge cases | Dev |
| R-8.3 | withOpacity -> withValues casse les opacites | QA | Faible | Moyen | Verification visuelle manuelle des ecrans principaux | Dev |
| R-8.4 | Script quotes modifie des strings avec apostrophes | Biz | Faible | Moyen | Utiliser dart fix (context-aware) au lieu de sed | Dev |
| R-8.5 | Decoupage routeur casse la navigation Shell | Tech | Moyen | Haut | Garder ShellRoute dans le fichier principal, tester 23 routes | Dev |
| R-8.6 | Sprint trop ambitieux | Biz | Moyen | Moyen | US-8.5 repoussable (1.5j marge + theme partiel) | Dev |
| R-8.7 | Controllers widgets conflits avec controllers pages | Tech | Faible | Haut | Dependance uniquement vers services, jamais vers controllers pages | Dev |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence |
|----------------|---------------------|-------|-----------|
| Alexis (dev) | Progression des US, blocages | Documents docs/ | A chaque US |
| CI/CD | Status pipeline | GitHub Actions | Automatique |
| Utilisateurs | Aucun (sprint technique) | - | - |

---

## 9. Journal de Decisions

| Decision | Contexte | Alternatives Considerees | Justification |
|----------|---------|--------------------------|---------------|
| US-8.5 scope reduit (GoogleFonts only, pas Colors) | 333 GoogleFonts + 1536 Colors = trop en 1 sprint | (a) Tout migrer (b) Rien migrer (c) GoogleFonts seulement | GoogleFonts = 1 pattern unique, ROI eleve. Colors = dispersees, risque visuel, ROI faible par rapport a l'effort |
| game_setup_modal hors scope | 507 lignes, juste au-dessus du seuil | (a) Inclure (b) Exclure | Priorite faible vs 4 widgets >600 lignes. Sprint 9 |
| --fatal-infos dans CI | Nami recommande | (a) Ajouter (b) Garder --fatal-warnings seulement | Prevention de regression, cout zero |
| StateNotifier pour controllers widgets | Coherence avec Sprint 7 | (a) StateNotifier (b) Notifier (c) AsyncNotifier | Meme pattern que les 6 controllers existants, simplicite, equipe deja familiere |
| DeckStatsController comme Provider.family | Calculs purs sans etat mutable | (a) StateNotifier (b) Provider.family | Plus adapte semantiquement, mais StateNotifier accepte pour coherence |

---

## 10. Top 5 Actions Immediates

1. **Verifier** la version Flutter (`flutter --version` >= 3.27 pour .withValues()) -- **DEJA FAIT : Flutter 3.35.6 confirme**

2. **Lancer** `dart fix --apply` pour corriger automatiquement ~700 issues (prefer_single_quotes, prefer_const_constructors, curly_braces, unnecessary_non_null_assertion) -- **US-8.1, etape 1**

3. **Remplacer** les 148 `.withOpacity()` par `.withValues(alpha: ...)` -- **US-8.1, etape 2**

4. **Creer** `lib/controllers/deck_card_picker_controller.dart` (le widget le plus gros, 774 lignes) -- **US-8.2, premiere extraction**

5. **Mettre a jour** la roadmap (`docs/ROADMAP_MUGIWARA.md`) pour marquer Sprint 7 TERMINE et Sprint 8 EN COURS

---

## Metriques de Succes Sprint 8

| Metrique | Avant | Apres | Status |
|----------|-------|-------|--------|
| Tests totaux | 273 | >= 305 | A valider |
| flutter analyze issues | 1041 | 0 | A valider |
| Fichiers pages >500 lignes | 5 | 0 | A valider |
| Fichiers widgets >500 lignes | 5 | 0 | A valider |
| Controllers Riverpod | 6 | 10 | A valider |
| app_router.dart | 713 lignes | <200 lignes | A valider |
| GoogleFonts directs | 333 | <60 | A valider |
| withOpacity | 148 | 0 | A valider |
| Score qualite | 9.0/10 | 9.5/10 | A valider |

---

*"Le Sunny est bientot parfait ! 7 sprints ont forge cette machine de guerre, et le Sprint 8 va la polir comme un navire digne du Roi des Pirates. Les God Widgets vont tomber, l'analyse sera propre, et le theme sera centralise. Cap sur le 9.5/10 -- le One Piece du code parfait est a portee de main !"* -- Luffy, Capitaine
