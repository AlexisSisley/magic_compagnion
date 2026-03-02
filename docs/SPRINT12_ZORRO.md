# Sprint 12 - Analyse Business : Features Avancees, Refactoring & Backlog Technique
> Agent : Zorro (Business Analyst) | Date : 01/03/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG (deckbuilders Commander, collectionneurs, joueurs competitifs multi-formats).

**Point de douleur central** : Apres 11 sprints (8 techniques + 3 features), Magic Companion dispose d'une base technique solide (9.0/10, 433 tests), de l'import/export multi-format, de la verification de legalite, des 5 quick wins, et de l'integration EDHREC profonde (themes, synergie, combos). Cependant, le Sprint 12 doit traiter un double objectif :

### A. Features avancees a forte valeur (Yamato Tier A/B restants)

1. **Deck Power Level** (Gap Yamato E1) : Pas d'estimation automatique de la puissance d'un deck Commander. Les joueurs doivent evaluer subjectivement si leur deck est "casual", "focused", "optimized" ou "cEDH". EDHREC fournit des donnees (salt score, synergy, inclusion rates) qui permettent un calcul heuristique.

2. **Syntaxe de recherche avancee Scryfall** (Gap Yamato A7) : Le champ de recherche actuel utilise une recherche par nom simple. L'API Scryfall supporte une syntaxe riche (`c:red cmc<=3 t:creature`, `o:"draw a card"`, `is:commander`, etc.) qui n'est pas exploitee. Les joueurs avances doivent aller sur scryfall.com.

3. **Recherche multilangue** (Gap Yamato A4) : Le parametre `lang` est deja supporte dans `ScryfallApiService.searchCards()` mais jamais expose dans l'UI. Les joueurs francophones, allemands, japonais, etc. ne peuvent pas chercher par nom dans leur langue.

4. **Salt score EDHREC** (Gap Yamato E3) : L'API EDHREC retourne un indicateur de "frustration" par carte. Utile pour les joueurs Commander qui veulent eviter les cartes generant du "sel" autour de la table.

### B. Backlog technique a solder

5. **Centralisation Colors hardcodes** : 1498 occurrences `Colors.xxx` dans 58 fichiers + 127 `Color(0x...)` dans 47 fichiers. Cela rend impossible le support de themes multiples et complique la maintenance.

6. **Centralisation GoogleFonts.cinzel** : 325 occurrences dans 52 fichiers. Devrait etre centralise dans `AppTextStyles`.

7. **God Files restants** : 17 fichiers > 500 lignes (hors generes). Le Sprint 8 (en pause) visait 0 fichier > 500 lignes.

8. **Rulings Scryfall** : Le service `getCardRulings()` existe dans `ScryfallApiService` et le modele `ScryfallRuling` existe, mais ils ne sont pas integres dans `CardDetailPage`.

9. **Dependency overrides ML Kit** : `google_mlkit_commons: 0.11.0` et `google_mlkit_text_recognition: 0.15.0` sont en dependency_overrides, ce qui bloque les mises a jour.

---

## 2. Analyse de la Cause Racine

1. **Pas de Power Level** : Aucune logique d'estimation n'existe. Le Sprint 11 a ajoute le synergy score mais pas de heuristique de puissance globale. La litterature cEDH et les donnees EDHREC (mana curve, synergy average, staple ratio, combo count) permettent un calcul approximatif.

2. **Syntaxe Scryfall non exposee** : `ScryfallApiService.searchCards()` passe le parametre `q` directement a l'API. Le controller `CardSearchController` pourrait detecter la syntaxe Scryfall (presence de `:`, operateurs) et la passer telle quelle, mais actuellement il prefixe/transforme la query.

3. **Recherche multilangue absente de l'UI** : Le parametre `lang` est pris en charge cote service mais `CardSearchController` ne l'expose pas. Il suffit d'ajouter un selecteur de langue dans les filtres.

4. **Salt score non exploite** : L'endpoint EDHREC principal retourne deja le salt score dans les cardviews mais il est ignore par `EdhrecCardSuggestion.fromJson()`.

5. **Colors/GoogleFonts non centralises** : Heritage des premiers sprints, jamais corrige. Chaque page/widget definit ses propres couleurs.

6. **Rulings non integres** : Le service et le modele existent depuis longtemps mais n'ont jamais ete cables dans l'UI.

---

## 3. Inventaire des Assets Existants

### Infrastructure existante reutilisable

| Composant | Etat | Utilite Sprint 12 |
|-----------|------|-------------------|
| `EdhrecService` enrichi (Sprint 11) | 357 lignes, 3 endpoints, cache 1h | Base pour salt score + power level |
| `EdhrecCardSuggestion` | synergy, inclusion, numDecks | Ajouter saltScore |
| `ScryfallApiService.searchCards(query, lang:)` | Parametre lang supporte | Expose dans UI |
| `ScryfallApiService.getCardRulings(cardId)` | Fonctionnel | Integrer dans CardDetailPage |
| `ScryfallRuling` modele | Existe (11 lignes) | Utiliser dans CardDetailController |
| `CardSearchController` | 606 lignes | Ajouter syntaxe avancee + lang |
| `DeckDetailController` | 771 lignes | Ajouter power level |
| `DeckSuggestionsTab` | 704 lignes (Sprint 11) | Ajouter salt score badges |

### Metriques actuelles

| Metrique | Valeur Sprint 11 |
|----------|-----------------|
| Tests | 433 |
| flutter analyze errors | 0 |
| Colors.xxx occurrences | 1498 dans 58 fichiers |
| Color(0x...) | 127 dans 47 fichiers |
| GoogleFonts.cinzel | 325 dans 52 fichiers |
| Fichiers > 500 lignes | 17 (hors generes) |
| Endpoints EDHREC | 3 |
| Score qualite | 9.0/10 |

---

## 4. User Stories

Le Sprint 12 est un sprint mixte (features + technique). Budget initial estimeL: 32j. Pour un sprint realiste de 5 semaines, on priorise en 3 tiers.

### Tier 1 -- Must-Have (P0) : 13j

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 1 | US-12.1 | Joueur avance | utiliser la syntaxe de recherche Scryfall dans le champ de recherche (ex: `c:red cmc<=3 t:creature`) | trouver des cartes avec des criteres precis sans quitter l'app | Must | 3 | A7 |
| 2 | US-12.2 | Joueur Commander | voir une estimation du power level de mon deck (casual/focused/optimized/cEDH) avec les facteurs contribuant au score | evaluer objectivement la puissance de mon deck et l'ajuster au niveau de ma table | Must | 5 | E1 |
| 3 | US-12.3 | Joueur Commander | voir le salt score de chaque carte dans les suggestions EDHREC et dans mon deck | eviter les cartes frustrantes pour ma table ou au contraire maximiser le sel | Must | 2 | E3 |
| 4 | US-12.4 | Joueur | voir les rulings officiels (regles et interactions) de chaque carte sur la page de detail | comprendre les interactions complexes sans quitter l'app | Must | 3 | -- |

### Tier 2 -- High Value (P1) : 10j

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 5 | US-12.5 | Joueur non-anglophone | rechercher des cartes par nom dans ma langue (FR, DE, JP, ES, IT, PT, KR, RU, ZHS, ZHT) | trouver des cartes sans connaitre le nom anglais | Should | 3 | A4 |
| 6 | US-12.6 | Developpeur | centraliser les Colors hardcodes dans AppColors/ThemeData et GoogleFonts.cinzel dans AppTextStyles | preparer le support de themes multiples et faciliter la maintenance | Should | 5 | -- |
| 7 | US-12.7 | Developpeur | extraire GameSetupModalController (507 lignes) en un controller Riverpod | reduire la complexite du widget et le rendre testable | Should | 2 | -- |

### Tier 3 -- Nice-to-Have (P2) : 9j

| Priorite | ID | En tant que... | Je veux... | Afin de... | MoSCoW | Story Points | Ref Yamato |
|----------|----|----------------|------------|------------|--------|-------------|------------|
| 8 | US-12.8 | Developpeur | resoudre les dependency overrides ML Kit et mettre a jour le scanner | eliminer la dette technique et beneficier des corrections de bugs | Could | 2 | -- |
| 9 | US-12.9 | Joueur | que la base locale oracle-cards.json se mette a jour automatiquement via Scryfall Bulk Data | avoir les dernieres cartes sans reinstaller l'app | Could | 4 | -- |
| 10 | US-12.10 | Joueur | que l'app utilise les Catalogs Scryfall pour les filtres dynamiques (types de creature, noms de planeswalkers, etc.) | avoir des filtres toujours a jour | Could | 3 | -- |

### Hors Scope Sprint 12

- Internationalisation complete (i18n avec fichiers ARB) -> Sprint 13 (trop gros : 5j estime, 19 pages + 102 fichiers a localiser)
- Chiffrement BDD SQLite -> Sprint 13 (necessite `sqlcipher`, dependance lourde)
- Notifications push Firebase -> Sprint 13 (necessite configuration FCM + backend)

**Total : 32 Story Points (~32j) -- Budget Sprint : 32j / 5 semaines**

---

## 5. Criteres d'Acceptation (Gherkin/BDD)

### US-12.1 : Syntaxe de recherche avancee Scryfall

```gherkin
Fonctionnalite: Syntaxe de recherche avancee Scryfall
  Contexte:
    Etant donne que l'utilisateur est sur la page de recherche de cartes
    Et qu'il est connecte a internet

  Scenario: Recherche avec syntaxe Scryfall
    Quand l'utilisateur tape "c:red cmc<=3 t:creature" dans le champ de recherche
    Alors la recherche est envoyee directement a l'API Scryfall avec la syntaxe complete
    Et les resultats affichent les creatures rouges avec CMC <= 3

  Scenario: Detection automatique de syntaxe avancee
    Quand l'utilisateur tape une query contenant ":", "<=", ">=", "=", "!", "is:", "o:", "t:", "c:", "id:", "cmc"
    Alors la query est identifiee comme syntaxe Scryfall avancee
    Et elle est envoyee telle quelle a l'API (pas de transformation)

  Scenario: Recherche simple inchangee
    Quand l'utilisateur tape "Lightning Bolt" (sans operateurs)
    Alors la recherche fonctionne comme avant (recherche par nom)

  Scenario: Aide a la syntaxe
    Quand l'utilisateur appuie sur un bouton "?" a cote du champ de recherche
    Alors une aide contextuelle affiche les operateurs principaux :
      | Operateur | Exemple | Description |
      | c: | c:red | Couleur |
      | cmc | cmc<=3 | Cout de mana converti |
      | t: | t:creature | Type |
      | o: | o:"draw a card" | Texte Oracle |
      | is: | is:commander | Legalite/propriete |
      | set: | set:mkm | Extension |

  Scenario: Gestion erreur syntaxe invalide
    Quand l'utilisateur tape une syntaxe invalide "c:" (sans valeur)
    Alors l'API retourne une erreur
    Et l'app affiche un message explicatif
```

### US-12.2 : Deck Power Level

```gherkin
Fonctionnalite: Estimation du power level d'un deck Commander
  Contexte:
    Etant donne que l'utilisateur consulte un deck Commander
    Et que les donnees EDHREC sont disponibles

  Scenario: Afficher le power level estime
    Quand l'utilisateur accede a l'onglet Stats ou Suggestions
    Alors un indicateur de power level est affiche (1-10 avec label)
    Et le label correspond au niveau :
      | Score | Label |
      | 1-3 | Casual |
      | 4-5 | Focused |
      | 6-7 | Optimized |
      | 8-9 | High Power |
      | 10 | cEDH |

  Scenario: Facteurs du power level
    Quand le power level est affiche
    Alors les facteurs contributifs sont detailles :
      | Facteur | Description |
      | Mana Curve | Courbe de mana moyenne (< 2.5 = bon) |
      | Synergy Score | Score synergie global EDHREC |
      | Staple Ratio | % de staples generiques vs picks specifiques |
      | Combo Potential | Nombre de combos detectes dans le deck |
      | Interaction Count | Nombre de removals, counters, protection |
      | Mana Base Quality | Nombre de terrains non-basiques, mana rocks |
      | Card Quality | % de cartes avec inclusion EDHREC > 50% |

  Scenario: Deck non-Commander
    Etant donne un deck Standard (pas Commander)
    Quand l'utilisateur consulte les stats
    Alors le power level n'est pas affiche
    Et un message indique "Power level disponible uniquement pour Commander"
```

### US-12.3 : Salt Score EDHREC

```gherkin
Fonctionnalite: Salt score des cartes EDHREC
  Contexte:
    Etant donne que les suggestions EDHREC sont chargees

  Scenario: Afficher le salt score par carte
    Quand les suggestions EDHREC sont affichees
    Alors chaque carte affiche son salt score (icone + valeur)
    Et les cartes a haut salt (> 2.0) ont un indicateur visuel rouge
    Et les cartes a faible salt (< 0.5) ont un indicateur vert

  Scenario: Salt score dans le rapport de synergie du deck
    Quand le rapport de synergie est genere
    Alors un "Salt Score moyen du deck" est affiche
    Et les cartes du deck les plus "salees" sont identifiees

  Scenario: API EDHREC sans salt score
    Quand une carte n'a pas de salt score dans les donnees EDHREC
    Alors aucun indicateur de salt n'est affiche pour cette carte
```

### US-12.4 : Rulings Scryfall

```gherkin
Fonctionnalite: Rulings officiels dans le detail de carte
  Contexte:
    Etant donne que l'utilisateur consulte le detail d'une carte

  Scenario: Afficher les rulings
    Quand l'utilisateur accede a la section "Regles" de la page detail
    Alors les rulings Scryfall sont charges et affiches
    Et chaque ruling a une date et un commentaire
    Et les rulings sont tries du plus recent au plus ancien

  Scenario: Carte sans rulings
    Quand une carte n'a pas de rulings
    Alors la section affiche "Aucune regle specifique pour cette carte"

  Scenario: Chargement lazy des rulings
    Quand l'utilisateur arrive sur la page detail
    Alors les rulings ne sont PAS charges automatiquement (lazy loading)
    Quand l'utilisateur fait defiler vers la section Regles
    Alors les rulings sont charges a la demande
```

### US-12.5 : Recherche multilangue

```gherkin
Fonctionnalite: Recherche de cartes par nom dans differentes langues
  Contexte:
    Etant donne que l'utilisateur est sur la page de recherche

  Scenario: Selectionner une langue de recherche
    Quand l'utilisateur ouvre les filtres de recherche
    Alors un selecteur de langue est disponible avec les options :
      | Code | Langue |
      | en | English (defaut) |
      | fr | Francais |
      | de | Deutsch |
      | es | Espanol |
      | it | Italiano |
      | pt | Portugues |
      | ja | Japanese |
      | ko | Korean |
      | ru | Russian |
      | zhs | Simplified Chinese |
      | zht | Traditional Chinese |

  Scenario: Recherche en francais
    Etant donne que la langue est regle sur "Francais"
    Quand l'utilisateur tape "Eclair" (nom FR de Lightning Bolt)
    Alors la recherche utilise le parametre lang=fr
    Et les resultats montrent les cartes correspondantes

  Scenario: Retour a l'anglais
    Quand l'utilisateur reselectionne "English"
    Alors les recherches suivantes utilisent lang=en (par defaut)
```

### US-12.6 : Centralisation Colors et GoogleFonts

```gherkin
Fonctionnalite: Centralisation des constantes visuelles
  Scenario: AppColors centralise les couleurs
    Etant donne que lib/theme/app_colors.dart est cree
    Alors toutes les couleurs hardcodees (Colors.xxx, Color(0x...)) sont remplaces par des references AppColors
    Et le nombre total d'occurrences directes passe de 1625 a < 100

  Scenario: AppTextStyles centralise les fonts
    Etant donne que lib/theme/app_text_styles.dart est cree
    Alors toutes les occurrences GoogleFonts.cinzel sont remplacees par AppTextStyles
    Et le nombre total d'occurrences directes passe de 325 a < 10

  Scenario: Zero regression visuelle
    Apres la centralisation
    Alors l'app a exactement le meme rendu visuel qu'avant
    Et tous les tests passent
```

---

## 6. Contraintes & Hypotheses

### Contraintes
- **Stack figee** : Flutter/Dart, Riverpod, drift, go_router, Dio
- **Tests existants** : 433 tests doivent rester verts a chaque etape
- **Retrocompatibilite** : Aucune regression fonctionnelle
- **Budget** : 32 jours / 5 semaines
- **API Scryfall** : Rate limit 10 req/sec, syntaxe documentee
- **API EDHREC** : Pas de documentation officielle, salt score present dans cardviews
- **Refactoring Colors** : Operation a fort impact (1625 occurrences dans 58+ fichiers), risque de regression visuelle

### Hypotheses
- Le salt score est un champ `salt` (float) dans les cardviews EDHREC
- La syntaxe Scryfall est stable et bien documentee (https://scryfall.com/docs/syntax)
- Le power level peut etre estime par heuristique a partir des donnees deja disponibles (mana curve, synergy, combos, staple ratio)
- Les Bulk Data Scryfall sont accessibles sans authentification
- Les Catalogs Scryfall retournent des listes statiques (types, subtypes, etc.)

---

## 7. Evaluation des Risques

| ID | Risque | Probabilite | Impact | Strategie de Mitigation |
|----|--------|-------------|--------|-------------------------|
| R-12.1 | Regression visuelle lors de la centralisation Colors (1625 occurrences) | Haute | Haut | Proceder fichier par fichier, tests visuels manuels, ne pas tout faire d'un coup |
| R-12.2 | Power level trop subjectif / mal calibre | Moyenne | Moyen | Utiliser des seuils bases sur des donnees EDHREC reelles, permettre l'ajustement utilisateur |
| R-12.3 | Syntaxe Scryfall mal geree (erreurs silencieuses) | Moyenne | Moyen | Afficher les erreurs API Scryfall a l'utilisateur, proposer une aide syntaxique |
| R-12.4 | Bulk Data Scryfall trop volumineux (oracle-cards.json ~100MB) | Moyenne | Haut | Telechargement en background, indicateur de progression, stockage incremental |
| R-12.5 | Dependency overrides ML Kit cassent le build apres resolution | Moyenne | Haut | Tester sur un branch separee avant merge |
| R-12.6 | Budget 32j serre pour 10 US | Haute | Moyen | Tier 3 (P2) reportable au Sprint 13 |
| R-12.7 | Recherche multilangue retourne peu de resultats pour certaines langues | Faible | Faible | Fallback vers anglais si 0 resultat |

---

## 8. Dependances & Ordre d'Execution

### Dependances internes

```
US-12.1 (Syntaxe Scryfall) -- independant
US-12.2 (Power Level)      -- depend des donnees Sprint 11 (EdhrecCommanderData)
US-12.3 (Salt Score)       -- depend du modele EDHREC (ajout champ salt)
US-12.4 (Rulings)          -- independant (service existe deja)
US-12.5 (Multilangue)      -- independant (parametre lang existe deja)
US-12.6 (Colors/Fonts)     -- independant mais operation massive
US-12.7 (GameSetupModal)   -- independant
US-12.8 (ML Kit)           -- independant
US-12.9 (Bulk Data)        -- independant
US-12.10 (Catalogs)        -- independant
```

### Ordre recommande

1. **US-12.3** (Salt Score, 2j) -- rapide, enrichit le modele EDHREC existant
2. **US-12.4** (Rulings, 3j) -- service existe, il faut juste cabler l'UI
3. **US-12.1** (Syntaxe Scryfall, 3j) -- forte valeur utilisateur
4. **US-12.5** (Multilangue, 3j) -- rapide, parametre existe deja
5. **US-12.2** (Power Level, 5j) -- feature differenciante, plus complexe
6. **US-12.7** (GameSetupModal, 2j) -- refactoring cible
7. **US-12.6** (Colors/Fonts, 5j) -- operation massive, a faire en bloc
8. **US-12.8** (ML Kit, 2j) -- fix technique
9. **US-12.9** (Bulk Data, 4j) -- nice-to-have
10. **US-12.10** (Catalogs, 3j) -- nice-to-have

---

## 9. Estimation

| User Story | Effort | Priorite | Tier |
|------------|--------|----------|------|
| US-12.1 : Syntaxe Scryfall | 3j | P0 | Must |
| US-12.2 : Power Level | 5j | P0 | Must |
| US-12.3 : Salt Score | 2j | P0 | Must |
| US-12.4 : Rulings | 3j | P0 | Must |
| US-12.5 : Multilangue | 3j | P1 | Should |
| US-12.6 : Colors/Fonts | 5j | P1 | Should |
| US-12.7 : GameSetupModal | 2j | P1 | Should |
| US-12.8 : ML Kit | 2j | P2 | Could |
| US-12.9 : Bulk Data | 4j | P2 | Could |
| US-12.10 : Catalogs | 3j | P2 | Could |
| **Total** | **32j** | -- | -- |

### Scope ajustable (si retard)

1. **Tier 3** (US-12.8 + 12.9 + 12.10 = 9j) -> Sprint 13
2. **US-12.6** (Colors/Fonts = 5j) -> peut etre fait en 2 phases (phase 1 = AppColors dans Sprint 12, phase 2 = GoogleFonts dans Sprint 13)
3. Les **Tier 1** (US-12.1 a 12.4 = 13j) sont **P0 et non negociables**

---

## 10. Impact Utilisateur Attendu

| Feature | Impact UX | Frequence d'utilisation | Avantage concurrentiel |
|---------|-----------|------------------------|----------------------|
| US-12.1 : Syntaxe Scryfall | **Tres haut** -- recherche de niveau expert | Chaque session de recherche avancee | Moxfield et ManaBox n'ont pas ca en mobile |
| US-12.2 : Power Level | **Tres haut** -- evaluation objective du deck | Chaque consultation de deck Commander | Aucune app mobile ne fait ca automatiquement |
| US-12.3 : Salt Score | **Moyen** -- indicateur social utile | Consultation Commander | Uniquement sur EDHREC.com |
| US-12.4 : Rulings | **Haut** -- reference regles in-app | Chaque carte complexe | MTG Companion officiel le fait |
| US-12.5 : Multilangue | **Haut** -- joueurs non-anglophones | Chaque session de recherche (pour non-EN) | ManaBox le fait, Moxfield non |
| US-12.6 : Colors/Fonts | **Interne** -- maintenabilite | N/A | Prerequis pour themes sombres/clairs |
| US-12.7 : GameSetupModal | **Interne** -- testabilite | N/A | Prerequis pour tests widget |

*"Dix coups d'epee. Les quatre premiers (syntaxe, power level, salt, rulings) tranchent les derniers gaps fonctionnels -- les joueurs n'auront plus jamais besoin de quitter l'app pour comprendre une carte, evaluer leur deck ou trouver une interaction. Les trois suivants (multilangue, colors, game setup) affilent la lame -- l'app devient internationale, maintenable, testable. Les trois derniers (ML Kit, Bulk Data, Catalogs) preparent le terrain pour le futur. Apres ce sprint, Magic Companion n'est plus une app parmi d'autres -- c'est LA reference mobile pour les joueurs de MTG."* -- Zorro
