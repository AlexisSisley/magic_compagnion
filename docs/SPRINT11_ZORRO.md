# Sprint 11 - Analyse Business : EDHREC Deep Integration
> Agent : Zorro (Business Analyst) | Date : 01/03/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG (deckbuilders Commander, collectionneurs, joueurs competitifs multi-formats).

**Point de douleur central** : Apres 10 sprints (8 techniques + 2 features), Magic Companion dispose d'une base technique solide (9.0/10, 368 tests), de l'import/export multi-format, de la verification de legalite, et de 5 quick wins. Cependant, l'app manque d'intelligence dans le deckbuilding Commander :

1. **Pas de recommandations par theme/tribu** (Gap Yamato E2) : L'onglet "Suggestions" actuel (`DeckSuggestionsTab`) affiche les Top Cards et cartes par type (creatures, instants...) mais ne propose pas de recommandations par archetype (Infect, +1/+1 Counters, Voltron, Aristocrats...) ni par tribu (Elves, Zombies, Dragons...). Les joueurs doivent aller manuellement sur EDHREC.com pour explorer les themes de leur commandant.

2. **Pas de score de synergie** (Gap Yamato E5) : L'API EDHREC retourne un champ `synergy` (float -1 a +1) pour chaque carte suggeree, mais Magic Companion ne l'exploite pas. Les joueurs ne voient pas quelles cartes de leur deck sont les plus synergiques avec leur commandant, ni lesquelles sont des "staples generiques" vs des "picks specifiques".

3. **Pas de detection de combos** (Gap Yamato E6) : L'API EDHREC fournit un endpoint `/pages/combos/{commander}.json` avec des milliers de combos identifies, incluant les cartes, le resultat ("Infinite damage", "Win the game"), le nombre de decks utilisant ce combo, et le pourcentage d'utilisation. Magic Companion n'exploite rien de tout cela.

**Objectif Sprint 11** : Exploiter les donnees EDHREC en profondeur pour transformer l'onglet Suggestions en un assistant de deckbuilding Commander intelligent. Budget : **9 jours**, duree 3 semaines.

---

## 2. Analyse de la Cause Racine

1. **EdhrecService trop basique** : Le service actuel (`lib/services/edhrec_service.dart`, 96 lignes) n'appelle qu'un seul endpoint (`/pages/commanders/{slug}.json`) et n'extrait que les sections par type de carte (Top Cards, Creatures, Instants, etc.). Il ignore les champs `synergy`, `inclusion`, `num_decks`, `potential_decks` et `trend_zscore` presents dans chaque `cardview`. Il ignore aussi les `taglinks` (themes/tribus) et `combocounts` presents dans la reponse.

2. **DeckSuggestionsTab sans intelligence** : Le widget actuel affiche une liste plate de cartes par categorie, sans scoring, sans tri par synergie, sans aucun indicateur de pertinence. Il ne sait pas quelles cartes du deck existant sont synergiques ou pas.

3. **Aucun endpoint combo appele** : L'endpoint `/pages/combos/{commander}.json` n'est jamais appele. Il contient des combos avec `results` (texte decrivant l'effet), `count` (nombre de decks), `percentage` (taux d'utilisation), et `rank` (popularite).

4. **Aucun endpoint theme appele** : Les themes disponibles sont listes dans `taglinks` de la reponse principale. Chaque theme a un endpoint `/pages/themes/{commander}/{theme}.json` qui contient des recommendations specialisees.

---

## 3. Inventaire des Assets Existants

### Service EDHREC

| Composant | Etat | Utilite Sprint 11 |
|-----------|------|-----------------|
| `EdhrecService` | Fonctionnel (1 endpoint) | Base a enrichir avec themes, synergy, combos |
| `EdhrecService.getRecommendations()` | Retourne `Map<String, List<String>>` | A enrichir pour retourner des objets structures avec synergy/inclusion |
| `EdhrecService._formatSlug()` | Fonctionnel | Reutilisable pour tous les endpoints |
| `edhrecServiceProvider` | Provider Riverpod | Deja en place |
| `DeckSuggestionsTab` | Fonctionnel (287 lignes) | A refactorer pour afficher synergy score et themes |

### Donnees EDHREC disponibles (non exploitees)

| Donnee | Source API | Format | Utilite Sprint 11 |
|--------|-----------|--------|-----------------|
| `synergy` | `/pages/commanders/{slug}.json` -> cardviews | float (-1 a +1) | Score de synergie par carte |
| `inclusion` | idem | int (pourcentage) | Taux d'inclusion dans les decks |
| `num_decks` | idem | int | Nombre de decks utilisant cette carte |
| `potential_decks` | idem | int | Nombre total de decks analyses |
| `taglinks` | idem -> container | List (theme, count, href) | Themes et tribus disponibles |
| `combocounts` | idem -> container | List (name, count, href) | Combos populaires (resume) |
| Combo details | `/pages/combos/{slug}.json` | cardviews + results | Combos complets avec cartes et effets |
| Theme cards | `/pages/themes/{slug}/{theme}.json` | cardlists | Cartes recommandees par theme |

### Infrastructure existante

| Composant | Etat | Utilite Sprint 11 |
|-----------|------|-----------------|
| `DeckDetailController` | 668 lignes, fonctionnel | Ajouter logique synergy score + combos |
| `DeckDetailState.fullCardData` | List<ScryfallCard> chargees | Donnees Scryfall pour cross-reference |
| `LocalCardService.getCardByName()` | Fonctionnel | Resolution noms EDHREC -> ScryfallCard |
| `Dio` avec rate limiting | Fonctionnel dans ScryfallApiService | Pattern reutilisable pour EDHREC |

---

## 4. User Stories

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 1 | US-11.1 | Joueur Commander | voir les themes et tribus disponibles pour mon commandant (Infect, Voltron, +1/+1 Counters, Elves...) et obtenir des recommandations de cartes par theme | construire un deck thematique coherent plutot qu'une soupe de bonnes cartes | Must | 4 | E2 |
| 2 | US-11.2 | Joueur Commander | voir un score de synergie pour chaque carte de mon deck et pour chaque suggestion, avec un score global du deck | savoir quelles cartes sont specifiquement bonnes avec mon commandant vs des staples generiques, et optimiser la synergie globale | Must | 3 | E5 |
| 3 | US-11.3 | Joueur Commander | voir les combos detectes dans mon deck et les combos populaires pour mon commandant, avec les cartes manquantes pour completer un combo | identifier les synergies puissantes et optimiser mon plan de jeu | Should | 3 | E6 |

**Total : 10 Story Points (~9 jours)**

---

## 5. Criteres d'Acceptation (Gherkin/BDD)

### US-11.1 : Themes et tribus EDHREC

```gherkin
Fonctionnalite: Themes et tribus EDHREC pour un commandant
  Contexte:
    Etant donne que l'utilisateur consulte un deck Commander avec "Atraxa, Praetors' Voice"
    Et que l'API EDHREC retourne des taglinks pour ce commandant

  Scenario: Afficher la liste des themes disponibles
    Quand l'utilisateur accede a l'onglet "Suggestions"
    Alors une section "Themes & Tribus" est affichee en haut
    Et elle contient la liste des themes avec leur nombre de decks :
      | Theme | Decks |
      | Infect | 6284 |
      | Planeswalkers | 3654 |
      | +1/+1 Counters | 2790 |
      | Superfriends | 1823 |
    Et chaque theme est cliquable

  Scenario: Charger les recommandations par theme
    Quand l'utilisateur selectionne le theme "Infect"
    Alors les suggestions de cartes sont rechargees avec les donnees specifiques au theme "Infect"
    Et les cartes affichees sont les plus pertinentes pour le theme Infect d'Atraxa
    Et un indicateur de synergie est affiche pour chaque carte

  Scenario: Retour aux suggestions generales
    Etant donne que l'utilisateur visualise les suggestions du theme "Infect"
    Quand il clique sur "Toutes les suggestions" ou revient en arriere
    Alors les suggestions generales (non thematiques) sont reaffichees

  Scenario: Commandant sans themes
    Etant donne un commandant obscur sans taglinks
    Quand l'utilisateur accede aux Suggestions
    Alors la section "Themes & Tribus" affiche "Aucun theme disponible"
    Et les suggestions generales restent accessibles
```

### US-11.2 : Score de synergie

```gherkin
Fonctionnalite: Score de synergie des cartes
  Contexte:
    Etant donne que l'utilisateur consulte un deck Commander
    Et que les donnees EDHREC sont chargees

  Scenario: Afficher le score de synergie pour chaque suggestion
    Quand les suggestions EDHREC sont affichees
    Alors chaque carte affiche un score de synergie (ex: "+27%", "-5%")
    Et les cartes sont triees par synergie decroissante dans la section "Haute Synergie"
    Et le score est colore (vert pour positif, rouge pour negatif, gris pour neutre)

  Scenario: Calculer le score de synergie global du deck
    Quand l'utilisateur consulte le deck
    Alors un score global de synergie est affiche (ex: "Synergie deck : 42/100")
    Et le score est base sur la moyenne ponderee des synergy scores des cartes du deck presentes dans les donnees EDHREC

  Scenario: Afficher le taux d'inclusion
    Quand les suggestions EDHREC sont affichees
    Alors chaque carte affiche son taux d'inclusion (ex: "92% des decks")
    Et le nombre de decks utilisant cette carte (ex: "dans 12,450 decks")

  Scenario: Identifier les cartes generiques vs specifiques
    Etant donne que "Sol Ring" a un synergy de -0.05 et une inclusion de 98%
    Et que "Sword of Truth and Justice" a un synergy de +0.35 et une inclusion de 45%
    Quand les suggestions sont affichees
    Alors "Sol Ring" est identifie comme "Staple generique" (haute inclusion, faible synergie)
    Et "Sword of Truth and Justice" est identifie comme "Pick specifique" (haute synergie)

  Scenario: Deck sans donnees EDHREC (pas Commander ou commandant inconnu)
    Etant donne un deck format Standard (pas Commander)
    Quand l'utilisateur accede aux Suggestions
    Alors un message indique "Les scores de synergie sont disponibles uniquement pour les decks Commander"
```

### US-11.3 : Detection de combos

```gherkin
Fonctionnalite: Detection de combos dans un deck Commander
  Contexte:
    Etant donne que l'utilisateur consulte un deck Commander
    Et que l'API EDHREC retourne des combos pour ce commandant

  Scenario: Afficher les combos disponibles pour le commandant
    Quand l'utilisateur accede a un nouvel onglet "Combos" ou une section dans Suggestions
    Alors les combos populaires sont listes, tries par nombre de decks decroissant :
      | Combo | Resultat | Decks | Pourcentage |
      | Vraska + Vorinclex | Target opponent loses | 24872 | 1.45% |
      | Exquisite Blood + Sanguine Bond | Infinite damage | 18340 | 1.07% |
    Et chaque combo affiche les cartes impliquees

  Scenario: Detecter les combos presents dans le deck
    Etant donne que le deck contient "Vraska, Betrayal's Sting" et "Vorinclex, Monstrous Raider"
    Et que ce combo est dans la liste EDHREC
    Quand les combos sont affiches
    Alors ce combo est mis en avant avec un badge "Dans votre deck"
    Et il est affiche en haut de la liste

  Scenario: Suggerer des cartes manquantes pour completer un combo
    Etant donne que le deck contient "Exquisite Blood" mais pas "Sanguine Bond"
    Et que le combo "Exquisite Blood + Sanguine Bond" est dans la liste
    Quand les combos sont affiches
    Alors ce combo affiche "1 carte manquante : Sanguine Bond"
    Et "Sanguine Bond" est cliquable pour voir le detail

  Scenario: Trier les combos par pertinence
    Quand les combos sont affiches
    Alors l'ordre est :
      1. Combos 100% dans le deck (toutes les cartes presentes)
      2. Combos partiels (1 carte manquante)
      3. Combos populaires (tries par nombre de decks)

  Scenario: Commandant sans combos
    Etant donne un commandant sans donnees de combos
    Quand l'utilisateur accede aux combos
    Alors un message indique "Aucun combo connu pour ce commandant"
```

---

## 6. Contraintes & Hypotheses

### Contraintes
- **Stack figee** : Flutter/Dart, Riverpod, drift, go_router, Dio
- **Tests existants** : 368 tests doivent rester verts a chaque etape
- **Retrocompatibilite** : L'onglet Suggestions actuel ne doit pas regresser
- **Budget** : 9 jours / 3 semaines
- **API EDHREC** : Pas de documentation officielle, JSON endpoints decouverts par reverse engineering. Pas de rate limit documente, mais respecter 5 req/sec par precaution
- **Pas d'auth** : L'API EDHREC est publique (pas de cle API)
- **Cache** : Les donnees EDHREC ne changent pas souvent (mise a jour hebdomadaire des themes/combos), un cache de 1h est acceptable

### Hypotheses
- L'API EDHREC reste accessible et stable pendant le sprint (risque : pas de SLA officiel)
- Le champ `synergy` de EDHREC est une valeur flottante entre -1 et +1 qui represente la specificite d'une carte pour un commandant donne
- Les `taglinks` contiennent les themes et tribus avec leur nom et nombre de decks
- L'endpoint `/pages/combos/{slug}.json` retourne des combos avec `cardviews` (cartes), `results` (effets), `count` (decks), `percentage`
- L'endpoint `/pages/themes/{slug}/{theme}.json` retourne les cartes recommandees pour un theme specifique
- Les joueurs Commander representent la majorite des utilisateurs actifs de Magic Companion

---

## 7. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|-------------------------|
| R-11.1 | API EDHREC indisponible ou changement de structure JSON | Moyenne | Haut | Cache local des dernieres donnees valides + fallback gracieux (afficher suggestions de base sans scores) |
| R-11.2 | Endpoint combos retourne trop de donnees (3000+ combos pour Atraxa) | Haute | Moyen | Paginer, ne charger que les top 50 combos tries par popularite |
| R-11.3 | Resolution noms EDHREC -> ScryfallCard echoue pour certaines cartes | Moyenne | Faible | Fallback virtuel existant (ScryfallCard avec `id: 'edhrec_...'`) deja en place dans `DeckSuggestionsTab` |
| R-11.4 | Score de synergie difficile a calculer pour les cartes du deck (pas dans la reponse EDHREC) | Moyenne | Moyen | Cross-reference par nom entre le deck et les cardviews EDHREC pour recuperer le synergy |
| R-11.5 | Performance : trop d'appels API (commander + combos + N themes) | Moyenne | Moyen | Charger les themes a la demande (lazy loading), pas tous en meme temps |
| R-11.6 | Les themes EDHREC ne sont pas toujours pertinents (themes trop generiques) | Faible | Faible | Filtrer les themes avec moins de 100 decks |
| R-11.7 | Budget 9j serre si les 3 US sont implementees | Moyenne | Moyen | US-11.3 (combos) est `Should`, reportable au Sprint 12 si retard |

---

## 8. Dependances & Carte des Parties Prenantes

### Dependances internes

- **US-11.1 est independante** : enrichit EdhrecService avec themes, modifie DeckSuggestionsTab
- **US-11.2 depend partiellement de US-11.1** : le synergy score utilise les donnees deja chargees par le service enrichi
- **US-11.3 est independante** : nouveau endpoint combos, nouveau widget ou section

### Ordre d'execution recommande

```
US-11.1 (Themes) ──────> US-11.2 (Synergy) -- partagent le service enrichi
                                    |
US-11.3 (Combos) ──────────────── independant (peut commencer en parallele)
```

**Recommandation** : Commencer par US-11.1 (themes, enrichit le service), enchainer avec US-11.2 (synergy, exploite les donnees enrichies), puis US-11.3 (combos, independant).

### Parties prenantes

| Partie prenante | Role | Interet | Influence |
|----------------|------|---------|-----------|
| Alexis (dev) | Developpeur unique | Tres haut | Tres haute |
| Joueurs Commander | Utilisateurs principaux | **Tres haut** (deckbuilding intelligent) | Haute |
| CI/CD (GitHub Actions) | Pipeline automatise | Moyen (doit rester vert) | Haute |
| EDHREC (API externe) | Fournisseur de donnees | Indirect | **Haute** (dependance forte) |

---

## 9. Estimation

| User Story | Effort | Priorite | Dependances |
|------------|--------|----------|-------------|
| US-11.1 : Themes et tribus EDHREC | 4j | P0 | Aucune |
| US-11.2 : Score de synergie | 3j | P0 | Partage le service enrichi avec US-11.1 |
| US-11.3 : Detection de combos | 3j | P1 | Aucune (parallele) |
| **Total** | **10j** | -- | -- |

### Scope ajustable (si retard)

1. **US-11.3** (combos) -> Sprint 12 (P1, 3j) -- le plus independant, le moins critique pour l'UX quotidienne
2. **US-11.2 score global deck** -> Sprint 12 (garder le score par carte, reporter le calcul global)
3. Les US-11.1 et US-11.2 (score par carte) sont **P0 et non negociables**

---

## 10. Hors Scope Sprint 11

- Salt score EDHREC (indicateur de cartes "frustrantes") -> Sprint 12
- Power level estimation (estimation de la puissance d'un deck) -> Sprint 12
- EDHREC deck average (copier le deck moyen d'un commandant) -> Sprint 12
- Staples auto-add (ajouter automatiquement les staples au deck) -> Post-Sprint 12
- Integration EDHREC API authentifiee (si elle existe un jour) -> Post-Sprint 12
- Recommandations pour formats non-Commander (Standard, Modern) -> Post-Sprint 12

---

## 11. Impact Utilisateur Attendu

| Feature | Impact UX | Frequence d'utilisation | Avantage concurrentiel |
|---------|-----------|------------------------|----------------------|
| US-11.1 : Themes et tribus | **Tres haut** -- construction thematique guidee | A chaque creation/modification de deck Commander | Moxfield n'a pas ca dans l'app mobile |
| US-11.2 : Score de synergie | **Tres haut** -- optimisation intelligente | A chaque consultation de deck Commander | Uniquement sur EDHREC.com (pas dans les apps mobiles concurrentes) |
| US-11.3 : Detection de combos | **Haut** -- plan de jeu claire, combos identifies | A chaque consultation de deck Commander | Aucune app mobile ne fait ca |

*"Trois coups d'epee. Le premier ouvre le livre des themes -- chaque commandant a ses archetypes, ses tribus, ses strategies. Le deuxieme affute chaque carte avec un score : cette carte est-elle ici parce qu'elle est bonne partout, ou parce qu'elle est parfaite ICI ? Le troisieme revele les combos caches -- les sequences de victoire que le joueur ne voyait peut-etre pas. Apres ce sprint, Magic Companion ne se contente plus de stocker des decks. Il les comprend."* -- Zorro
