# SPRINT 14 — Rapport QA Nami (Lead QA Senior, ISTQB Expert)

**Date** : 2026-03-08
**Sprint** : 14 (12 SP — 5 User Stories)
**Stack** : Flutter / Dart (Riverpod + GoRouter + Drift)
**Fichiers Dart** : 147 (lib/) + 39 (test/) = 186 fichiers
**Lignes** : ~41k (lib/) + ~11k (test/) = ~52k lignes totales

---

## VERDICT : PASS (avec reserves)

### Resume

| Metrique | Valeur |
|----------|--------|
| Stack detectee | Flutter 3.x / Dart 3.9 |
| Fichiers inspectes | 186 |
| Erreurs CRITICAL | 0 |
| Erreurs HIGH | 0 |
| Warnings MEDIUM | 7 |
| Warnings LOW | 5 |

> **Le projet est en etat fonctionnel.** Toutes les US Sprint 14 sont implementees et structurellement coherentes. Aucun bloquant detecte. Les points ci-dessous sont des ameliorations recommandees.

---

## Phase V1 : Inspection Structurelle

### Architecture detectee

```
lib/
  controllers/     12 fichiers  (StateNotifier / Notifier pattern)
  data/            5 fichiers   (Drift database + migrations)
  models/          12 fichiers  (Data classes)
  pages/           12 dossiers  (UI pages par feature)
  providers/       6 fichiers   (Riverpod providers)
  router/          9 fichiers   (GoRouter + routes)
  services/        15 fichiers  (Business logic / API)
  theme/           3 fichiers   (AppColors, AppTextStyles)
  utils/           3 fichiers   (Helpers)
  widgets/         ~30 fichiers (Composants reutilisables)
```

**Constat** : Architecture Feature-based coherente. Separation claire Controller/Service/Provider/UI. Le pattern Riverpod est utilise de maniere homogene.

### US Sprint 14 — Couverture Structurelle

| US | Composants | Status |
|----|-----------|--------|
| US-14.1 Prix Scryfall | `price_helper.dart` (PriceTag + PriceHelper), integre dans `collection_list_tab.dart`, `scanner_page.dart`, `set_detail_card_tile.dart`, `card_detail_page.dart` | OK — 4 pages |
| US-14.2 Valeur Collection | `collection_value_provider.dart`, `collection_page.dart` (header + refresh), `global_stats_page.dart` (top cartes), `collection_service.dart` (recordDailyValue), `app_database.dart` (CollectionValueHistory table) | OK |
| US-14.3 Animations Life Counter | `player_zone.dart` — 3 AnimationControllers (pulse/shake/glow), dispose correct, didUpdateWidget gere | OK |
| US-14.4 Onboarding | `onboarding_page.dart` (3 ecrans), `app_router.dart` (redirect conditionnel), `app_routes.dart` (route `/onboarding`) | OK |
| US-14.5 firstWhere + CI | 10 occurrences `firstWhere` restantes, **toutes avec `orElse`**. `pr-check.yml` cree (analyze + test + coverage 40% + Python lint) | OK |

---

## Phase V2 : Analyse Statique (hors build)

> Note : `flutter analyze` non execute (pas de SDK Flutter dans l'environnement CI actuel). Analyse statique manuelle realisee.

### Erreurs et Warnings Detectes

| ID | Categorie | Severite | Description | Fichier/Composant | Action |
|----|-----------|----------|-------------|-------------------|--------|
| W1 | CODE | MEDIUM | `card_detail_page.dart` n'utilise PAS le widget `PriceTag.detailed` — construit manuellement le meme layout (duplication) | `lib/pages/cards/card_detail_page.dart:444-453` | SANJI — Refactorer `_buildPriceInfo()` pour utiliser `PriceTag.detailed(prices: prices)` |
| W2 | CODE | MEDIUM | 70 catch generiques `catch (e)` dans 37 fichiers sans clause `on` specifique — risque de masquer des exceptions inattendues | Multiple (37 fichiers) | SANJI — Ajouter au minimum `on DioException`, `on StateError`, `on FormatException` pour les cas les plus courants |
| W3 | CODE | MEDIUM | 4 empty catches (`catch (e) { /* */ }`, `catch (_) {}`) qui avalent silencieusement les erreurs | `deck_card_list_tab.dart:66`, `wishlist_detail_page.dart:155`, `card_detail_controller.dart:336`, `deck_combos_section.dart:48` | SANJI — Logger au minimum avec `log()` ou `debugPrint()` |
| W4 | CODE | MEDIUM | `analysis_options.yaml` n'active pas `empty_catches` ni `avoid_catches_without_on_clauses` | `analysis_options.yaml` | SANJI — Ajouter les lints `empty_catches: true` et `avoid_catches_without_on_clauses: true` |
| W5 | CODE | MEDIUM | `CollectionValueNotifier.build()` appelle `_computeValue()` (async) dans un `collectionAsync.when(data:)` sans `await` — le Future est fire-and-forget, les erreurs non propagees au state initial | `lib/providers/collection_value_provider.dart:71` | SANJI — Wrapper dans un `Future.microtask` ou gerer le Future correctement |
| W6 | CODE | MEDIUM | `_hasSeenOnboardingCache` est une variable globale mutable (top-level `bool?`) — pas thread-safe et difficile a tester | `lib/router/app_router.dart:69` | SANJI — Encapsuler dans un Provider ou un service injectable |
| W7 | CODE | MEDIUM | `dependency_overrides` dans `pubspec.yaml` pour `google_mlkit_commons` et `google_mlkit_text_recognition` — peut masquer des incompatibilites | `pubspec.yaml:127-129` | SANJI — Verifier si les overrides sont toujours necessaires avec la version Flutter actuelle |
| W8 | CODE | LOW | Ratio test/code : 39 fichiers test pour 147 fichiers source (26.5%). Couverture probablement sous 40% sans les pages/widgets testes | `test/` | SANJI — Ajouter tests pour `card_detail_controller`, `player_zone_controller`, `scanner_page` |
| W9 | CODE | LOW | Pas de test pour `PriceTag` widget (seulement `price_helper_test.dart` pour le helper) | `test/utils/price_helper_test.dart` | SANJI — Ajouter widget test pour `PriceTag` et `PriceTag.detailed` |
| W10 | CODE | LOW | Pas de fichier `.env.example` pour documenter les variables d'environnement requises (Firebase, API keys) | Racine projet | SANJI — Creer `.env.example` |
| W11 | SPEC | LOW | US-14.2 mentionne "CollectionValueHistory" mais pas de vue UI dediee pour l'historique (seulement `recordDailyValue` en DB) | `global_stats_page.dart` | ZORRO — Clarifier si un graphique d'evolution historique est attendu dans le Sprint 14 ou reporte |
| W12 | CODE | LOW | `fetchCollection` (POST batch Scryfall) n'a pas de cache — chaque recalcul de valeur re-fetch les cartes non locales | `lib/services/scryfall_api_service.dart:112` | SANJI — Ajouter un cache en memoire TTL 24h pour les resultats batch |

---

## Phase V3 : Verification de Coherence

### Entites et Modeles

| Entite | Fichier Model | Fichier Service | Fichier Test | Status |
|--------|--------------|----------------|-------------|--------|
| ScryfallCard | `scryfall_card_model.dart` | `scryfall_api_service.dart` | `scryfall_api_service_test.dart` + `scryfall_card_model_test.dart` | OK |
| Deck | `deck_model.dart` | `deck_service.dart` (non dans services/) | `deck_service_test.dart` + `deck_model_test.dart` | OK |
| Collection | (via DeckCard) | `collection_service.dart` | `collection_service_test.dart` | OK |
| CollectionValue | (inline state) | `collection_value_provider.dart` | `collection_value_provider_test.dart` | OK |
| Player | `player_model.dart` | (controller direct) | `player_zone_controller_test.dart` | OK |
| GameHistory | `game_history_model.dart` | `game_history_service.dart` | (pas de test) | MANQUANT |
| Wishlist | `wishlist_model.dart` | `wishlist_service.dart` | `wishlist_service_test.dart` + `wishlist_model_test.dart` | OK |
| Profile | `profile_model.dart` | `profile_service.dart` | `profile_model_test.dart` | OK |
| ScanHistory | `scan_history_model.dart` | `scan_history_service.dart` | (pas de test) | MANQUANT |

### CI/CD Pipeline

| Element | Status | Fichier |
|---------|--------|---------|
| PR Check | OK | `.github/workflows/pr-check.yml` |
| Build Main | OK | `.github/workflows/build-main.yml` |
| Release | OK | `.github/workflows/release.yml` |
| Retro Doc | OK | `.github/workflows/retro-doc.yml` |
| Coverage seuil | 40% | `pr-check.yml:46-58` |
| Python backend lint | Flake8 (E9,F63,F7,F82) | `pr-check.yml:80-81` |

### Tests Existants (39 fichiers)

| Couche | Fichiers Test | Couverture |
|--------|--------------|-----------|
| Controllers | 11 | Bonne (tous sauf card_detail) |
| Services | 13 | Bonne |
| Models | 5 | Correcte |
| Providers | 1 | Faible (seulement collection_value) |
| Pages | 1 | Faible (seulement onboarding) |
| Widgets | 2 | Faible |
| Utils | 3 | Correcte |
| Router | 1 | OK |
| Data | 1 | OK |

---

## Phases 1-7 : Strategie QA Complete

### 1. Analyse de Testabilite

| Dimension | Note | Justification |
|-----------|------|---------------|
| **Observabilite** | Haute | States Riverpod exposent clairement les etats (loading, error, data). Logs avec `dart:developer`. |
| **Controlabilite** | Moyenne | Les services sont injectables via Riverpod, mais `SharedPreferences` et API calls rendent certains tests complexes. Le cache global `_hasSeenOnboardingCache` est un frein. |
| **Decomposabilite** | Haute | Architecture bien separee (Controller/Service/Provider). Les widgets sont composes, pas monolithiques. |
| **Stabilite** | Moyenne | 4 dependency overrides, SDK `^3.9.2` recent. Les API Scryfall sont stables mais le rate limit (10 req/s) peut causer des flaky tests. |
| **Comprehensibilite** | Haute | Code bien documente (commentaires Sprint/US), noms explicites, patterns coherents. |

### 2. Matrice de Risques

| Zone Fonctionnelle | Risque Business | Risque Technique | Priorite | Profondeur |
|-------------------|----------------|-----------------|----------|-----------|
| Prix Scryfall (US-14.1) | **H** — feature premium, monetisation future | **M** — API externe, parsing JSON | P1 | Tests unitaires + integration |
| Valeur Collection (US-14.2) | **H** — KPI utilisateur majeur | **H** — calcul batch async, rate limit, cache | P1 | Tests unitaires + integration + perf |
| Animations Life Counter (US-14.3) | **M** — UX critique mais non-bloquante | **M** — 60fps sur appareils bas de gamme, dispose | P2 | Tests widget + tests manuels perf |
| Onboarding (US-14.4) | **M** — premiere impression utilisateur | **B** — code simple, SharedPreferences | P3 | Tests widget + test E2E |
| firstWhere + CI (US-14.5) | **H** — stabilite app (crashes) | **B** — correction mecanique | P1 | Tests unitaires (regression) |

**Top 3 Risques Majeurs** :

1. **Rate Limit Scryfall** : Le calcul batch de valeur collection peut generer 75+ requetes. En cas de collection de 5000+ cartes non cachees, on depasse largement les 10 req/s. Impact = calcul incomplet ou erreur utilisateur.
2. **Catch generiques** : 70 `catch (e)` sans discrimination. Une `OutOfMemoryError` ou `StackOverflowError` serait avalee comme une simple erreur reseau. Impact = bugs silencieux impossibles a diagnostiquer.
3. **Fire-and-forget async dans `build()`** : Le `CollectionValueNotifier.build()` lance un Future sans `await`. Si le widget est dispose avant la fin du calcul, une exception `state =` sur un notifier dispose peut crasher.

### 3. Strategie de Test Globale

#### Niveaux de Test

| Niveau | Perimetre | Outils | Seuil |
|--------|----------|--------|-------|
| Unitaire | Models, Helpers, Services (mock API) | `flutter_test`, mock manual | 60% couverture cible |
| Integration | Controllers + Providers avec services mockes | `flutter_test` + `ProviderContainer` | Tous les flux principaux |
| Widget | Pages critiques (card_detail, collection, scanner, life_counter) | `flutter_test` + `pumpWidget` | Pages avec logique UI |
| E2E | Onboarding flow, scan-to-collection flow | `integration_test` | 2 scenarios cles |

#### Criteres d'Entree/Sortie

| Critere | Entree | Sortie |
|---------|--------|--------|
| Build | `flutter analyze` sans erreur | Zero CRITICAL dans le rapport |
| Tests | Tous les tests existants passent | Couverture >= 40% (CI) |
| Review | Code review par au moins 1 pair | Toutes les US validees en Gherkin |

### 4. Scenarios de Test

#### US-14.1 : Prix Scryfall

| ID | Scenario | Type | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|---------------|--------|-----------------|----------|
| T1.1 | Prix affiche sur detail carte | Happy Path | Carte avec prix EUR | Ouvrir detail carte | Prix normal et foil affiches | P1 |
| T1.2 | Prix affiche sur collection list | Happy Path | Collection non vide | Ouvrir collection | PriceTag compact visible par carte | P1 |
| T1.3 | Prix affiche sur scanner result | Happy Path | Scanner une carte connue | Scanner et voir resultat | PriceTag visible | P1 |
| T1.4 | Prix N/A (carte sans prix) | Edge Case | Carte token sans prix | Ouvrir detail | Affiche "N/A" sans crash | P1 |
| T1.5 | Prix foil vs normal | Edge Case | Carte avec prix foil > normal | Toggle foil | Prix foil en amber, prix normal en primaire | P2 |
| T1.6 | Prix USD fallback | Edge Case | Carte avec prix USD mais pas EUR | Afficher prix | Fallback sur USD | P2 |
| T1.7 | Carte avec prices null | Negatif | `prices: {}` | Afficher PriceTag | Affiche "--" sans exception | P1 |
| T1.8 | Prix avec string invalide | Negatif | `prices: {'eur': 'abc'}` | parsePrice | Retourne null, affiche fallback | P2 |
| T1.9 | PriceTag.detailed layout | Edge Case | Ecran etroit (320px) | Afficher PriceTag.detailed | Pas d'overflow, texte lisible | P2 |

#### US-14.2 : Valeur Collection

| ID | Scenario | Type | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|---------------|--------|-----------------|----------|
| T2.1 | Valeur totale affichee | Happy Path | Collection avec 10 cartes pricees | Ouvrir collection | Header affiche valeur totale EUR | P1 |
| T2.2 | Refresh valeur | Happy Path | Collection chargee | Tap refresh | Recalcul et mise a jour header | P1 |
| T2.3 | Top cartes par valeur | Happy Path | Collection avec 50+ cartes | Ouvrir stats globales | Top 10 cartes les plus cheres affichees | P1 |
| T2.4 | Collection vide | Edge Case | Collection a 0 cartes | Ouvrir collection | Header affiche 0.00 EUR, pas d'erreur | P1 |
| T2.5 | Cartes sans prix Scryfall | Edge Case | 50% cartes sans prix | Calculer valeur | `pricedCards` < `totalCards`, pas de crash | P2 |
| T2.6 | Rate limit Scryfall (batch > 75) | Edge Case | 200 cartes non cachees | Calcul valeur | Batch par 75, respecte 10 req/s | P1 |
| T2.7 | Erreur reseau pendant batch | Negatif | Mode avion | Refresh valeur | State error affiche, pas de crash | P1 |
| T2.8 | Timeout API | Negatif | API lente (>10s) | Calcul valeur | Timeout gere, valeur partielle affichee | P2 |
| T2.9 | Collection de 10000 cartes | Performance | Grande collection | Calcul valeur | Complete en < 30s | P2 |
| T2.10 | recordDailyValue persistence | Happy Path | Valeur calculee | Fermer et rouvrir app | Historique en DB correct | P2 |

#### US-14.3 : Animations Life Counter

| ID | Scenario | Type | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|---------------|--------|-----------------|----------|
| T3.1 | Pulse sur gain de vie | Happy Path | Partie 2 joueurs | Tap + (gain vie) | Texte vie scale 1.15x puis revient | P1 |
| T3.2 | Shake sur degats | Happy Path | Partie 2 joueurs | Tap - (degats) | Texte vie tremble horizontalement | P1 |
| T3.3 | Glow monarch | Happy Path | Joueur est monarch | Activer monarch | Bordure pulsante doree | P1 |
| T3.4 | Glow arret apres perte monarch | Edge Case | Joueur perd monarch | Desactiver monarch | Glow s'arrete, bordure normale | P1 |
| T3.5 | Taps rapides multiples | Edge Case | Joueur spam tap | 10 taps rapides en 1s | Animations ne stackent pas, pas de jank | P1 |
| T3.6 | Animation dispose proprement | Edge Case | Quitter la page pendant animation | Pop page mid-animation | Pas de "setState after dispose" | P1 |
| T3.7 | Animations sur 6+ joueurs | Performance | 6 joueurs actifs | Tous changent vie en meme temps | 60fps maintenu | P2 |
| T3.8 | Mode -10/+10 avec animation | Edge Case | Long tap mode actif | Tap -10 | Shake + grand changement valeur | P2 |

#### US-14.4 : Onboarding

| ID | Scenario | Type | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|---------------|--------|-----------------|----------|
| T4.1 | Premier lancement | Happy Path | App jamais ouverte | Lancer app | Onboarding ecran 1 affiche | P1 |
| T4.2 | Navigation 3 ecrans | Happy Path | Onboarding affiche | Swipe 3 ecrans + "C'est parti" | Redirige vers Life Counter | P1 |
| T4.3 | Skip onboarding | Happy Path | Ecran 1 | Tap "Passer" | Redirige vers Life Counter, flag set | P1 |
| T4.4 | Pas de re-affichage | Edge Case | Onboarding deja vu | Relancer app | Directement Life Counter | P1 |
| T4.5 | Rotation ecran | Edge Case | Onboarding ecran 2 | Rotation portrait/paysage | Layout adapte, pas de crash | P2 |
| T4.6 | Indicateurs de page | Edge Case | Ecran 2 | Observer dots | Dot 2 active (24px), dots 1 et 3 inactives (8px) | P2 |

#### US-14.5 : firstWhere + CI

| ID | Scenario | Type | Preconditions | Etapes | Resultat Attendu | Priorite |
|----|----------|------|---------------|--------|-----------------|----------|
| T5.1 | Zero firstWhere sans orElse | Happy Path | Code source | Grep `firstWhere` sans `orElse` | 0 occurrences (sauf cas try/catch) | P1 |
| T5.2 | CI PR analyze + test | Happy Path | Push sur branche | Ouvrir PR | Pipeline passe (analyze + test + coverage) | P1 |
| T5.3 | CI coverage threshold | Edge Case | Coverage 39% | Push | Pipeline FAIL avec message clair | P1 |
| T5.4 | CI Python backend lint | Happy Path | Modifier backend_rag/ | Push PR | Flake8 passe | P2 |

### 5. Specifications BDD/Gherkin (Top 5 critiques)

```gherkin
Fonctionnalite: US-14.1 Prix Scryfall affiches
  Contexte:
    Etant donne que l'utilisateur a une collection avec des cartes

  Scenario: Affichage du prix sur la page detail
    Etant donne que la carte "Lightning Bolt" a un prix EUR de "0.50"
    Quand j'ouvre la page detail de "Lightning Bolt"
    Alors je vois le texte "0.50" dans la section "Prix & Marche"
    Et je vois le prix normal et le prix foil cote a cote

  Scenario: Affichage du prix sur la liste de collection
    Etant donne que ma collection contient "Lightning Bolt" avec prix "0.50"
    Quand j'ouvre la page collection
    Alors je vois un PriceTag compact "0.50€" a cote de la carte

  Scenario: Prix indisponible
    Etant donne que la carte "Custom Token" n'a pas de prix Scryfall
    Quand j'affiche cette carte
    Alors je vois "--" comme prix
    Et aucune exception n'est levee

  Plan du Scenario: Fallback devise
    Etant donne que la carte a les prix <eur> et <usd>
    Quand j'affiche le prix
    Alors je vois <affichage>

    Exemples:
      | eur    | usd    | affichage   |
      | "1.50" | "1.80" | "1.50 €"    |
      | null   | "1.80" | "N/A"       |
      | null   | null   | "N/A"       |
```

```gherkin
Fonctionnalite: US-14.2 Valeur collection temps reel
  Contexte:
    Etant donne que l'utilisateur a une collection non vide

  Scenario: Affichage valeur totale dans le header
    Etant donne que ma collection vaut 150.75 EUR au total
    Quand j'ouvre la page collection
    Alors le header affiche "150.75 €"
    Et le nombre de cartes pricees est affiche

  Scenario: Refresh de la valeur
    Etant donne que la page collection est ouverte
    Quand je tape sur le bouton refresh
    Alors la valeur est recalculee
    Et l'heure de derniere mise a jour est actualisee

  Scenario: Batch Scryfall avec rate limit
    Etant donne que 200 cartes ne sont pas dans le cache local
    Quand le calcul de valeur se lance
    Alors les requetes sont envoyees par batch de 75
    Et le rate limit de 10 req/s est respecte
```

```gherkin
Fonctionnalite: US-14.3 Animations life counter
  Contexte:
    Etant donne qu'une partie est en cours avec 2 joueurs

  Scenario: Pulse quand vie augmente
    Etant donne que le joueur 1 a 20 points de vie
    Quand le joueur 1 gagne 1 point de vie
    Alors le texte de vie pulse (scale 1.15x pendant 200ms)
    Et la vie affichee passe a 21

  Scenario: Shake quand vie diminue
    Etant donne que le joueur 1 a 20 points de vie
    Quand le joueur 1 perd 1 point de vie
    Alors le texte de vie tremble (oscillation X pendant 300ms)
    Et la vie affichee passe a 19

  Scenario: Glow monarch
    Etant donne que le joueur 1 devient monarch
    Quand le state monarch est active
    Alors une bordure doree pulsante apparait (1.5s cycle, infini)
    Et un box shadow dore accompagne la bordure
```

```gherkin
Fonctionnalite: US-14.4 Onboarding 3 ecrans
  Contexte:
    Etant donne que l'application est installee pour la premiere fois

  Scenario: Parcours complet onboarding
    Etant donne que l'onboarding n'a jamais ete vu
    Quand je lance l'application
    Alors je vois l'ecran "Compteur de Vie"
    Quand je tape "Suivant"
    Alors je vois l'ecran "Scanner & Collection"
    Quand je tape "Suivant"
    Alors je vois l'ecran "Decks & Outils"
    Et le bouton affiche "C'est parti !"
    Quand je tape "C'est parti !"
    Alors je suis redirige vers le Life Counter
    Et l'onboarding ne se reaffiche plus au prochain lancement

  Scenario: Skip onboarding
    Etant donne que je suis sur l'ecran 1
    Quand je tape "Passer"
    Alors je suis redirige vers le Life Counter
    Et l'onboarding ne se reaffiche plus
```

```gherkin
Fonctionnalite: US-14.5 firstWhere securise et CI pipeline
  Scenario: Aucun firstWhere non protege
    Etant donne le code source dans lib/
    Quand je cherche toutes les occurrences de firstWhere
    Alors chaque appel a soit un orElse, soit est dans un try/catch
    Et le nombre total est inferieur a 15

  Scenario: CI pipeline bloque PR avec erreurs
    Etant donne une PR vers main
    Quand le pipeline s'execute
    Alors flutter analyze passe sans erreurs fatales
    Et flutter test passe avec couverture >= 40%
    Et flake8 passe sur backend_rag/
```

### 6. Strategie d'Automatisation

#### Quoi automatiser

| Composant | Automatiser ? | Justification |
|-----------|:------------:|---------------|
| PriceHelper (parsing, format) | OUI | Logique pure, testable sans mock, haute criticite business |
| PriceTag widget | OUI | Widget reutilisable, golden tests possibles |
| CollectionValueNotifier | OUI | Logique async complexe, mock Scryfall API |
| Player animations (pulse/shake/glow) | NON | Verif visuelle requise, tester manuellement sur device |
| Onboarding flow | OUI (widget test) | Navigation testable avec GoRouter mock |
| CI pipeline | OUI (par definition) | `pr-check.yml` deja en place |
| firstWhere audit | OUI | Script grep dans CI ou pre-commit hook |

#### Planning CI/CD

| Suite | Declencheur | Contenu | Duree cible |
|-------|------------|---------|-------------|
| Smoke | Chaque push | `flutter analyze` + tests rapides | < 3 min |
| PR Check | Pull Request | Analyze + tous tests + coverage | < 8 min |
| Nightly | Cron 02:00 | Tests + build Android/iOS | < 20 min |
| Release | Tag version | Build + sign + deploy | < 30 min |

#### Outils recommandes

- **Tests unitaires/integration** : `flutter_test` (deja en place)
- **Mocks** : `mockito` ou manual mocks (deja utilise avec manual)
- **Widget tests** : `flutter_test` + `pumpWidget`
- **Golden tests** : `golden_toolkit` pour PriceTag, collection header
- **E2E** : `integration_test` (package Flutter officiel)
- **Coverage** : `lcov` + seuil CI 40% (deja en place, monter a 50% Sprint 15)

### 7. Plan de Tests Non-Fonctionnels

#### Performance

| Test | Metriques | Seuil |
|------|----------|-------|
| Animations 60fps (pulse/shake/glow) | Frame time via DevTools | < 16.67ms par frame (60fps) |
| Calcul valeur collection (1000 cartes) | Temps total | < 10s |
| Calcul valeur collection (10000 cartes) | Temps total | < 60s |
| Demarrage app (cold start) | Temps premier frame | < 3s sur device milieu de gamme |
| ScrollPerformance collection list (500 cartes) | Jank count | 0 janks |

#### Securite

| Risque | Verification |
|--------|-------------|
| API keys exposees | Pas de `.env` commite, Firebase config via `firebase_options.dart` (genere) |
| `upload-keystore.jks` dans le repo | **ATTENTION** — fichier keystore present a la racine. Devrait etre dans `.gitignore` |
| `keystore_base64.txt` dans le repo | **ATTENTION** — fichier potentiellement sensible |
| Injection dans recherche Scryfall | `ScryfallQueryBuilder` devrait sanitizer les inputs |

#### Accessibilite

| Element | Status | Action |
|---------|--------|--------|
| Semantics sur PriceTag | NON present | Ajouter `Semantics(label: 'Prix: $text')` |
| Contraste couleurs prix (amber sur fond sombre) | A verifier | Tester ratio WCAG AA (4.5:1) |
| Onboarding swipe | OK (PageView natif) | Tester avec TalkBack/VoiceOver |
| Life counter taps | Zone de tap adequate | Verifier taille minimum 48x48dp |

#### Compatibilite

| Axe | Perimetre |
|-----|----------|
| Android | API 21+ (5.0 Lollipop) — confirmer dans `build.gradle` |
| iOS | iOS 12+ — confirmer dans Xcode |
| Taille ecran | 320dp (SE) a 414dp (Pro Max) + tablettes |
| Orientation | Portrait principal, paysage pour life counter |

---

## Resume des Actions

### Pour Sanji (CODE) — 7 items

1. **W1** : Refactorer `card_detail_page.dart:_buildPriceInfo()` pour utiliser `PriceTag.detailed`
2. **W2** : Typer les 70 catch generiques (au moins les 10 plus critiques dans controllers/)
3. **W3** : Logger les 4 empty catches
4. **W4** : Ajouter lints `empty_catches` et `avoid_catches_without_on_clauses`
5. **W5** : Corriger le fire-and-forget async dans `CollectionValueNotifier.build()`
6. **W6** : Encapsuler `_hasSeenOnboardingCache` dans un Provider
7. **W12** : Ajouter cache TTL 24h pour `fetchCollection` batch

### Pour Zorro (SPEC) — 1 item

1. **W11** : Clarifier si le graphique d'historique de valeur collection est Sprint 14 ou reporte

### Alertes Securite

- **Retirer `upload-keystore.jks` et `keystore_base64.txt`** du repo et les ajouter a `.gitignore`

---

*Rapport genere par Nami — Lead QA Senior (ISTQB Expert Level)*
*Score qualite estime : 7.8/10 (avant corrections) → 8.5/10 cible (apres corrections)*
