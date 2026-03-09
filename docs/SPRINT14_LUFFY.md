# Sprint 14 -- Synthese Capitaine | RELEASE v1.10

**Date :** 8 mars 2026
**Capitaine :** Luffy -- Program Manager
**Sprint :** 14 (cible v1.10)
**Base :** 183 fichiers Dart, Sprint 13 stable, 617 tests PASS

---

## 1. Resume Executif

Magic Companion v1.10 vise a combler les 3 gaps concurrentiels les plus critiques (prix temps reel, animations life counter, onboarding) tout en posant les fondations du dashboard et de la valeur collection. L'audit croise de 4 poles revele une bonne nouvelle : **60-70% de l'infrastructure necessaire existe deja** (prix Scryfall parses, compteurs poison/energy/monarch implementes, table CollectionValueHistory en base). Le risque principal est la surcharge : 5 US estimees a 11-16 jours pour 10 jours effectifs. **La decision strategique est de garantir 3 US en "Must Ship" (prix + valeur collection + animations) et de laisser le dashboard glisser au Sprint 15 si necessaire**, protegeant ainsi la qualite sans sacrifier la valeur business. Un pre-requis bloquant de 5 minutes (fix du router recree a chaque build) doit etre traite en jour 1.

---

## 2. Synthese d'Alignement

### 3 points cles de convergence

1. **Les prix Scryfall sont le gap #1 unanime** -- Business (gap concurrentiel vs ManaBox/TopDecked), Tech (infra deja presente dans `ScryfallCard.prices`), QA (10+ patterns inconsistants a unifier = double benefice)
2. **L'existant accelere la livraison** -- Les compteurs poison/energy/monarch (Player + PlayerZone), les prix (parses dans 18 fichiers), et la valeur collection (CollectionValueHistory) sont deja codes. Le Sprint 14 est plus un sprint d'assemblage/polish que de creation from scratch.
3. **Le router est un pre-requis technique non negociable** -- Franky l'a identifie comme critique (recree a chaque `build()`), Sanji confirme, Nami valide. 5 minutes de fix, impact majeur sur la stabilite.

### Matrice d'alignement inter-fonctionnel

| Dimension | Vue Business (Zorro) | Vue Technique (Sanji) | Vue Qualite (Nami) | Consensus |
|-----------|---------------------|----------------------|--------------------|-----------|
| **Perimetre** | 5 US, 26 SP total | Must Ship 3 US (13 SP), 1 peut glisser | 9 ecarts a corriger en parallele | **4 US fermes, US-4 Dashboard conditionnel** |
| **Priorites** | Prix > Animations > Onboarding > Dashboard > Valeur | Prix+Valeur > Animations > Onboarding > Dashboard | Fix patterns prix (E1 HIGH) en premier | **Prix + fix patterns = jour 1-3** |
| **Delais** | 10-13j, serre mais faisable | 11-16j, confirme surcharge | Tests non-fonctionnels ajoutent 1-2j | **12j effectifs, buffer 2j pour QA** |
| **Qualite** | Acceptable si features livrees | Code propre DRY, PriceHelper centralise | 50+ scenarios de test, WCAG AA | **PriceHelper = convergence DRY + QA** |
| **Ressources** | 1 dev fullstack | 1 dev, ~24 fichiers a modifier | CI pipeline a mettre en place | **1 dev + CI automatisee** |

---

## 3. Arbitrage des Conflits

| # | Conflit | Position Zorro | Position Sanji | Position Nami | Decision d'Arbitrage | Justification |
|---|---------|---------------|----------------|---------------|---------------------|---------------|
| C1 | **5 US vs capacite 10j** | Tout livrer, phasage A/B | Must Ship 3 US, Dashboard peut glisser | Besoin de temps pour 50+ scenarios | **4 US fermes + Dashboard conditionnel**. Si semaine 1 finit en avance, Dashboard demarre. Sinon glisse Sprint 15. | ROI : 80% de la valeur dans 3 US. Dashboard = nice-to-have sans prix integres. |
| C2 | **40+ animations scope creep** | Veut toutes les animations life counter | 8 animations = risque R3, chiffrer d'abord | Chaque animation = scenario de test supplementaire | **3 animations Must Have** (pulse vie, shake degats, glow monarch). Les 5 autres = Sprint 15. | Le polish visible (3 anims) suffit pour le "wow factor". 40 animations non chiffrees = danger. |
| C3 | **Patterns prix DRY vs vitesse** | Peu importe l'implementation, veut les prix visibles | PriceHelper + PriceTag = refactoring 6 patterns | E1 HIGH : 10+ patterns = dette tech | **PriceHelper obligatoire AVANT d'ajouter des features prix**. Refactoring = jour 2-3, bloque le reste sinon. | Ajouter de la valeur collection par-dessus 6 fallbacks differents = multiplier la dette. Fix now = velocity later. |
| C4 | **Onboarding scope** | 3 ecrans complets avec animations | Simple, via AppSettings drift | WCAG AA, accessibilite | **3 ecrans statiques** avec images, texte, bouton skip. Animations onboarding = Sprint 16. | Un onboarding fonctionnel > un onboarding beau mais en retard. La retention se joue sur le contenu, pas les transitions. |
| C5 | **Historique prix (R2)** | Veut historique 30j/90j | Impossible sans backend, Scryfall = snapshot | Confirme limitation technique | **Hors scope Sprint 14**. Snapshot prix actuel uniquement. Historique = Sprint 15-16 avec backend leger. | Promettre un historique sans infra backend = engagement impossible a tenir. |
| C6 | **CI Pipeline** | Pas prioritaire vs features | Souhaitable | Recommande fortement PR Check + Nightly | **PR Check CI en semaine 2**. Nightly + Pre-release = Sprint 15. | Un check automatique sur les PR protege la qualite sans ralentir le dev. Nightly = overhead premature. |

---

## 4. Roadmap de Livraison

### MVP (Phase 1 -- "Must Ship") -- Cible : Jours 1-7

| Fonctionnalite | US | Effort | Dependance | Criteres d'Acceptation | Statut |
|----------------|-----|--------|------------|----------------------|--------|
| Fix router `createAppRouter()` | -- | 0.5j | Aucune | Router instancie 1 seule fois, pas dans `build()` | A FAIRE -- JOUR 1 |
| Fix TapGestureRecognizer leak | -- | 0.5j | Aucune | `dispose()` appele dans tous les widgets concernes | A FAIRE -- JOUR 1 |
| PriceHelper + PriceTag (refactoring DRY) | US-1 | 1.5j | Fix router | 1 seul pattern prix, 6 fallbacks unifies en 1, PriceTag widget reutilisable | A FAIRE |
| Prix Scryfall affiches (detail, collection, scanner) | US-1 | 1j | PriceHelper | Prix EUR/USD visibles sur page detail, liste collection, overlay scanner | A FAIRE |
| Valeur collection temps reel | US-5 | 1.5j | PriceHelper | Valeur totale affichee, top cartes par valeur, CollectionValueHistory utilisee | A FAIRE |
| Animations life counter (3 core) | US-2 | 2j | Aucune | Pulse vie, shake degats, glow monarch implementes et fluides 60fps | A FAIRE |

### V1 (Phase 2 -- "Should Ship") -- Cible : Jours 8-10

| Fonctionnalite | US | Effort | Dependance | Criteres d'Acceptation | Statut |
|----------------|-----|--------|------------|----------------------|--------|
| Onboarding 3 ecrans | US-3 | 2j | AppSettings drift | 3 ecrans, skip possible, affiche 1 seule fois, completion trackee | A FAIRE |
| firstWhere + orElse (batch fix) | -- | 0.5j | Aucune | 60+ occurrences securisees, 0 crash potentiel | A FAIRE |
| PR Check CI pipeline | -- | 0.5j | Aucune | `flutter analyze` + `flutter test` sur chaque PR | A FAIRE |

### V2 (Phase 3 -- "Conditionnel / Sprint 15") -- Cible : Sprint 15

| Fonctionnalite | US | Effort | Dependance | Criteres d'Acceptation | Statut |
|----------------|-----|--------|------------|----------------------|--------|
| Dashboard Home | US-4 | 4-5j | Prix + Valeur collection | Stats collection, activite recente, carte du jour, acces rapide | REPORTE |
| Animations life counter (5 restantes) | US-2+ | 2-3j | 3 core animations | Explosion particules, dice roll 3D, poison drip, counter tick, victory crown | REPORTE |
| Nightly CI + Pre-release pipeline | -- | 1j | PR Check CI | Tests nightly, build pre-release automatise | REPORTE |
| Historique prix 30j/90j | -- | 3-5j | Backend leger | Graphique evolution prix, movers quotidiens | REPORTE |

### Graphe de dependances (chemin critique)

```
JOUR 1 (pre-requis bloquants)
  |
  +-- Fix Router (0.5j) --------+
  +-- Fix TapGesture leak (0.5j) |
                                 |
JOURS 2-4 (fondations)          v
  |
  +-- PriceHelper + PriceTag (1.5j) --+-- Prix Scryfall affiches (1j)
  |                                    +-- Valeur Collection (1.5j)
  |
  +-- Animations Life Counter (2j, parallele) -- independant
  |
JOURS 5-7 (assemblage + tests)
  |
  +-- Integration tests prix + valeur
  +-- QA scenarios prioritaires
  |
JOURS 8-10 (polish)
  |
  +-- Onboarding (2j)
  +-- Batch fix firstWhere (0.5j)
  +-- CI Pipeline (0.5j)
```

**Chemin critique :** Fix Router -> PriceHelper -> Prix Scryfall -> Valeur Collection (4.5j incompressibles)

---

## 5. Estimation des Ressources & Efforts

### Composition d'equipe

| Role | Profil | ETP | Responsabilite |
|------|--------|-----|----------------|
| Dev Flutter Senior | Fullstack, experience Riverpod/drift | 1.0 | Implementation features + refactoring |
| QA (automatise) | CI/CD + tests manuels | 0.2 | Pipeline CI, scenarios critiques |
| Product Owner | Vision produit, priorisation | 0.1 | Validation criteres d'acceptation |

### Estimation d'effort par phase

| Phase | Effort dev | Effort QA | Total | Risque |
|-------|-----------|-----------|-------|--------|
| MVP (Phase 1) | 7j | 1j | 8j | Moyen -- chemin critique serre |
| V1 (Phase 2) | 2.5j | 0.5j | 3j | Faible -- features independantes |
| V2 (Phase 3) | 10-13j | 2j | 12-15j | Faible -- Sprint 15 dedie |
| **Total Sprint 14** | **9.5j** | **1.5j** | **11j** | **Gerable avec buffer** |

### Considerations budgetaires

| Poste | Cout | Notes |
|-------|------|-------|
| API Scryfall | Gratuit | Rate limit 10 req/s, respecter delai 75ms entre requetes |
| Firebase (existant) | ~0 EUR/mois | Tier gratuit suffisant pour la base utilisateurs actuelle |
| CI/CD (GitHub Actions) | Gratuit | 2000 min/mois sur tier gratuit, suffisant |
| Infra backend historique prix | A evaluer Sprint 15 | Cloud Functions Firebase ou Supabase, ~5-15 EUR/mois |

---

## 6. Indicateurs de Succes (KPIs)

### KPIs de Livraison

| KPI | Cible Sprint 14 | Methode de Mesure | Frequence | Responsable |
|-----|-----------------|-------------------|-----------|-------------|
| Taux completion US Must Ship | 100% (3/3 US) | Board Sprint | Quotidien | Luffy |
| Velocity reelle vs estimee | > 80% | SP livres / SP planifies | Fin de sprint | Luffy |
| Taux de defauts post-merge | < 2 bugs/US | Bug tracker | Continue | Nami |
| Cycle time moyen par US | < 3j | PR open -> merge | Fin de sprint | Sanji |
| Couverture de tests | > 95% (baseline 100%) | `flutter test --coverage` | PR Check | Nami |

### KPIs Business

| KPI | Cible v1.10 | Methode de Mesure | Frequence | Responsable |
|-----|-------------|-------------------|-----------|-------------|
| Temps sur page detail carte | +20% vs v1.9 | Firebase Analytics | Hebdomadaire | Zorro |
| Completion onboarding | > 70% des nouveaux users | Event tracking | Hebdomadaire | Zorro |
| Retention J7 | +15% vs baseline | Cohorte Firebase | Mensuel | Zorro |
| NPS utilisateur | > 40 | Survey in-app (Sprint 16) | Trimestriel | Vivi |
| Sessions/semaine/user | 3+ | Firebase Analytics | Hebdomadaire | Zorro |

### KPIs Qualite

| KPI | Cible | Methode de Mesure | Frequence | Responsable |
|-----|-------|-------------------|-----------|-------------|
| Temps calcul valeur 1000 cartes | < 2 secondes | Test de performance | Pre-release | Nami |
| Crash rate | < 0.1% | Firebase Crashlytics | Continue | Nami |
| Accessibilite WCAG AA | 100% ecrans nouveaux | Audit manuel + `accessibility_tools` | Pre-release | Nami |
| `flutter analyze` | 0 issues | CI pipeline | Chaque PR | Nami |

---

## 7. Registre de Risques Consolide

| ID | Risque | Source | Prob. | Impact | Mitigation | Responsable |
|----|--------|--------|-------|--------|------------|-------------|
| **R1** | Surcharge Sprint 14 (5 US > capacite) | Biz+Tech | **Haute** | Eleve | Dashboard conditionnel, phasage MVP/V1/V2. Si jour 7 : arbitrage go/no-go Dashboard. | Luffy |
| **R2** | Historique prix impossible sans backend | Biz+Tech | Certaine | Moyen | Hors scope Sprint 14. Snapshot uniquement. Backend leger Sprint 15. | Sanji |
| **R3** | Scope creep animations (40+ non chiffrees) | Biz | Haute | Eleve | 3 animations fermes Sprint 14. Catalogue priorise, chiffrage Sprint 15. | Luffy |
| **R4** | Scanner ML = 8 sprints d'effort | Biz | Faible (S14) | Faible (S14) | Hors perimetre Sprint 14-16. Evaluation technique Sprint 17. | Sanji |
| **R5** | Mode playtest = 5 sprints | Biz | Faible (S14) | Faible (S14) | Planifie Sprint 17-18. Pas d'engagement premature. | Zorro |
| **R6** | Cible retention J7 +30% irrealiste | Biz | Moyenne | Moyen | Cible revisee a +15%. Mesure baseline avant engagement. | Zorro |
| **R7** | Dependance unique Scryfall API | Tech | Moyenne | Eleve | Cache local agressif (TTL 24h). Fallback gracieux si API down. Monitoring uptime. | Sanji |
| **R8** | Router recree a chaque build (perf) | Tech+QA | **Certaine** | **Critique** | Fix jour 1. 5 minutes. Non negociable. | Sanji |
| **R9** | TapGestureRecognizer fuite memoire | Tech+QA | Certaine | Eleve | Fix jour 1. Dispose dans tous les widgets concernes. | Sanji |
| **R10** | 60+ firstWhere sans orElse | Tech+QA | Haute | Moyen | Batch fix semaine 2. Script ou search-replace semi-auto. | Sanji |
| **R11** | 6 patterns prix inconsistants (E1 HIGH) | QA | Certaine | Eleve | PriceHelper jour 2-3 resout le probleme. Prerequis a toute feature prix. | Sanji+Nami |
| **R12** | Regression tests sur 24 fichiers modifies | QA | Moyenne | Moyen | CI pipeline PR Check. 617 tests existants = filet de securite. | Nami |

---

## 8. Matrice de Communication

| Partie Prenante | Besoin d'Information | Canal | Frequence | Responsable |
|----------------|---------------------|-------|-----------|-------------|
| Equipe dev (Sanji) | Priorites du jour, blocages | Daily standup (async Slack) | Quotidien | Luffy |
| QA (Nami) | Features prete a tester, changements de scope | Channel #qa + tag PR | A chaque merge | Sanji |
| Business (Zorro) | Avancement US, decisions de scope | Recap hebdomadaire | 2x/sprint | Luffy |
| Product (Vivi) | Alignement roadmap, KPIs | Sync bi-hebdomadaire | 2x/sprint | Luffy |
| Utilisateurs | Release notes, nouveautes | Changelog in-app + store listing | A chaque release | Brook |
| Stakeholders | Resume executif, risques majeurs | Email + dashboard | Fin de sprint | Luffy |

---

## 9. Journal de Decisions

| # | Decision | Contexte | Alternatives Considerees | Justification |
|---|----------|---------|-------------------------|---------------|
| D1 | **Dashboard reporte conditionnellement** | 5 US > capacite 10j. Dashboard = 4-5j seul. | (a) Tout livrer en coupant QA, (b) Couper onboarding | Dashboard depend des prix et valeur collection. Le livrer sans ces fondations = ecran vide. Mieux vaut le livrer complet Sprint 15. |
| D2 | **3 animations seulement Sprint 14** | 40+ animations specifiees par Vivi, aucune chiffree | (a) 8 animations life counter, (b) 0 animation | 3 animations core = 80% de l'impact percu (pulse, shake, glow). Chiffrer les 37 restantes avant de s'engager. |
| D3 | **PriceHelper obligatoire avant features prix** | 6 fallbacks differents sur 18 fichiers, dette tech avere | (a) Ajouter prix par-dessus l'existant, (b) Refactoring complet | Refactoring cible (PriceHelper + PriceTag) = 1.5j. Evite de multiplier la dette et simplifie valeur collection. |
| D4 | **Fix router = jour 1, bloquant** | Router recree a chaque `build()` dans main.dart:50. Score Franky 6.5/10, #1 issue critique. | (a) Reporter au Sprint 15, (b) Fix en parallele | 5 minutes de fix. Impact critique sur performances. Aucune raison de reporter. |
| D5 | **Historique prix hors scope** | Scryfall = snapshot, pas d'historique. Backend necessaire. | (a) Stocker localement chaque jour, (b) Scraper MTGGoldfish | Stockage local = donnees incompletes (app pas ouverte tous les jours). Backend leger = solution propre, Sprint 15-16. |
| D6 | **Cible retention J7 revisee a +15%** | Zorro visait +30%. Nami et Sanji jugent irrealiste pour 1 sprint. | (a) Garder +30%, (b) Ne pas cibler | +15% = ambitieux mais mesurable. +30% = multi-sprint (onboarding + dashboard + prix combines). |
| D7 | **CI pipeline : PR Check Sprint 14, reste Sprint 15** | Nami recommande PR Check + Nightly + Pre-release | (a) Tout Sprint 14, (b) Tout Sprint 15 | PR Check = 0.5j, protection immediate. Nightly + Pre-release = overhead premature pour 1 dev. |

---

## 10. Actions Immediates

### Action 1 : Fix des 2 bugs critiques (JOUR 1 -- 1h max)

**Responsable : Sanji**

1. **Router** : Extraire `createAppRouter()` de `build()` dans `main.dart:50`. Le rendre `static final` ou le placer dans `initState`/`late final`. Verification : un seul log de creation du router au demarrage.
2. **TapGestureRecognizer** : Ajouter `dispose()` dans chaque widget utilisant un TapGestureRecognizer. Verification : 0 fuite memoire sur profiling Flutter DevTools.

### Action 2 : PriceHelper + refactoring patterns prix (JOURS 2-3)

**Responsable : Sanji, review par Nami**

1. Creer `lib/helpers/price_helper.dart` avec une logique unique de resolution de prix (EUR prioritaire, fallback USD, format unifie).
2. Creer `lib/widgets/shared/price_tag.dart` comme widget reutilisable.
3. Migrer les 18 fichiers utilisant 6 patterns differents vers PriceHelper/PriceTag.
4. Tests unitaires : 10+ cas (prix null, EUR seul, USD seul, les deux, format, etc.).

### Action 3 : Lancer les animations life counter en parallele (JOURS 2-4)

**Responsable : Sanji**

1. Implementer dans `PlayerZone` : pulse de vie (AnimatedScale + ColorTween), shake de degats (Transform.translate + sin()), glow monarch (AnimatedContainer + BoxShadow).
2. S'appuyer sur l'existant : le modele Player et PlayerZone ont deja les compteurs poison/energy/monarch.
3. Tests : fluidite 60fps verifiee sur device physique, pas de jank sur emulateur.

---

## Annexe : Calendrier synthetique Sprint 14

```
Sem 1 (Jours 1-5)
  J1  : Fix router + Fix TapGesture + Setup branche sprint14
  J2  : PriceHelper + PriceTag (creation)
  J3  : Migration 18 fichiers vers PriceHelper + tests
  J4  : Prix Scryfall affiches (detail, collection, scanner)
  J5  : Animations life counter (pulse, shake, glow)

Sem 2 (Jours 6-10)
  J6  : Animations life counter (finalisation) + Valeur collection
  J7  : Valeur collection (top cartes, CollectionValueHistory)
  J8  : Onboarding 3 ecrans
  J9  : Onboarding (fin) + batch fix firstWhere + CI pipeline
  J10 : Tests integration, QA scenarios prioritaires, tag release

Buffer : Si J7 termine en avance -> Dashboard (J8-J10)
```

---

*Synthese capitaine generee par Luffy -- Program Manager*
*Sources : Zorro (Business), Sanji (Architecture), Nami (QA), Franky (Code Review)*
*Sprint 14 -- Magic Companion v1.10 -- 8 mars 2026*
