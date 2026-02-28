# Sprint 5 - Analyse Business : Navigation & HTTP
> Agent : Zorro (Business Analyst) | Date : 27/02/2026

---

## Contexte

Apres 4 sprints d'amelioration (lint, Riverpod, tests, drift), Magic Companion dispose d'une architecture solide mais souffre de deux problemes structurels majeurs :
1. **Navigation imperative** : 152 appels `Navigator.push/pop` repartis dans 30 fichiers, sans deep linking ni routes declaratives
2. **HTTP non centralise** : 16+ appels `http.get()` eparpilles dans 12 fichiers (services ET pages), sans cache, rate limiting ni gestion d'erreurs unifiee

Le Sprint 5 vise a unifier ces deux couches pour atteindre un score qualite de 8.0 → 8.5/10.

---

## User Stories

### US-5.1 : Client HTTP centralise (Dio)
**En tant que** developpeur,
**je veux** un client HTTP unique avec intercepteurs,
**afin de** centraliser cache, rate limiting, logging et gestion d'erreurs.

**Criteres d'acceptation :**
- [ ] Un `ScryfallApiService` utilise Dio au lieu de `http`
- [ ] Intercepteur de cache avec TTL configurable (10min pour search, 24h pour sets)
- [ ] Intercepteur de rate limiting (max 10 req/sec, conforme Scryfall)
- [ ] Intercepteur de logging structure
- [ ] Tous les appels HTTP passent par ce service
- [ ] Le package `http` n'est plus importe dans aucun fichier applicatif

### US-5.2 : Migration des appels HTTP des pages vers les services
**En tant que** developpeur,
**je veux** que les pages ne fassent plus d'appels HTTP directs,
**afin de** respecter la separation des responsabilites (UI / Data).

**Criteres d'acceptation :**
- [ ] Les 7 pages faisant des appels HTTP utilisent les services
- [ ] Les 2 widgets faisant des appels HTTP utilisent les services
- [ ] `SetService`, `EdhrecService`, `CollectionService` utilisent `ScryfallApiService`
- [ ] Aucun import `package:http/` dans les pages ou widgets

### US-5.3 : Navigation declarative (go_router)
**En tant qu'** utilisateur,
**je veux** une navigation fluide avec support du deep linking,
**afin de** pouvoir partager des liens vers des pages specifiques.

**Criteres d'acceptation :**
- [ ] Configuration `GoRouter` centralisee dans `lib/router/app_router.dart`
- [ ] Toutes les routes principales definies avec des paths nommes
- [ ] `MaterialApp.router` remplace `MaterialApp` dans main.dart
- [ ] Les routes du Drawer utilisent `context.go()` / `context.push()`
- [ ] Navigation par onglets (BottomNavigationBar) fonctionne avec go_router

### US-5.4 : Migration des Navigator.push vers go_router
**En tant que** developpeur,
**je veux** remplacer les 152 appels `Navigator.push/pop`,
**afin d'** avoir une navigation testable et declarative.

**Criteres d'acceptation :**
- [ ] Les routes principales migrees (main, drawer, bottom nav)
- [ ] Les routes parametrees (card detail, deck detail, set detail) supportent les path params
- [ ] `Navigator.pop()` remplace par `context.pop()` ou back button natif
- [ ] Les dialogs et bottom sheets restent en imperatif (pas de migration)

### US-5.5 : Tests de la couche HTTP et routing
**En tant que** developpeur,
**je veux** des tests pour les nouvelles couches,
**afin de** garantir la non-regression.

**Criteres d'acceptation :**
- [ ] Tests unitaires ScryfallApiService (mock Dio adapter)
- [ ] Tests du rate limiting (respect du 10 req/sec)
- [ ] Tests de la configuration go_router (routes resolvables)
- [ ] Total >= 160 tests (140 Sprint 4 + 20 Sprint 5)

---

## NFRs (Non-Functional Requirements)

| NFR | Cible |
|-----|-------|
| Latence API (avec cache hit) | < 50ms |
| Latence API (cache miss) | < 2s |
| Rate limiting Scryfall | Max 10 req/sec |
| Cache TTL search | 10 min |
| Cache TTL sets/static | 24h |
| Zero appels HTTP dans UI | 0 imports http dans pages/ |

---

## Risques

| ID | Risque | Impact | Probabilite | Mitigation |
|----|--------|--------|-------------|------------|
| R-5.1 | go_router casse la navigation existante | Critique | Moyenne | Migration incrementale, tests manuels |
| R-5.2 | Cache stale affiche donnees obsoletes | Moyen | Faible | TTL court + invalidation manuelle |
| R-5.3 | Rate limiter trop strict bloque l'UX | Moyen | Faible | Queue avec priorite, pas de rejet |
| R-5.4 | Pages avec logique HTTP complexe difficiles a migrer | Moyen | Haute | Migrer les services d'abord, pages ensuite |
| R-5.5 | go_router incompatible avec certains patterns existants | Moyen | Moyenne | Garder Navigator pour modals/sheets |

---

## Priorites d'implementation

1. **P0** : ScryfallApiService + intercepteurs (fondation)
2. **P0** : Migration des 3 services HTTP (set_service, edhrec_service, collection_service)
3. **P1** : Configuration go_router + migration main.dart
4. **P1** : Migration des routes Drawer + BottomNav
5. **P2** : Migration des pages avec HTTP direct vers services
6. **P2** : Tests unitaires nouvelles couches

*"Trois epees suffisent pour trancher le chaos de 152 Navigator.push."* -- Zorro
