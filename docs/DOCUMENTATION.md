# Magic Companion - Documentation Technique Interne

> Genere le 26/02/2026 par Brook (Agent Documentation)

---

## 1. Vue d'Ensemble du Projet

**Magic Companion** est une application mobile Flutter multiplateforme (Android, iOS, macOS, Windows) concue comme un compagnon non-officiel pour le jeu de cartes Magic: The Gathering. Elle offre un ensemble complet d'outils pour les joueurs : compteur de vie, scanner de cartes, recherche, gestion de decks, collection, wishlists, et un oracle IA pour les regles.

| Propriete           | Valeur                              |
|---------------------|-------------------------------------|
| Nom du package      | `magic_companion`                   |
| Version             | 1.0.0+1                             |
| SDK Dart            | ^3.9.2                              |
| State Management    | Flutter Riverpod (v3.0.3)           |
| Backend             | Firebase (Cloud Functions, Core)     |
| API Externe         | Scryfall API, EDHRec (JSON non-officiel) |
| Stockage local      | SharedPreferences (JSON serialise)  |
| Sauvegarde cloud    | Google Drive API (auto-backup)      |

---

## 2. Architecture du Projet

### 2.1 Structure des Repertoires

```
lib/
  main.dart                          # Point d'entree, AppShell, navigation, theme
  chat_screen.dart                   # Ecran de chat (Grimoire Code, debug only)
  firebase_options.dart              # Config Firebase auto-generee

  data/
    glossary_data.dart               # Donnees statiques du glossaire MTG
    secondary_breakfast.dart         # Donnees secondaires

  models/                            # Modeles de domaine (data classes)
    deck_model.dart                  # DeckCard + Deck
    game_history_model.dart          # GameHistoryItem + PlayerHistorySnapshot
    player_model.dart                # Player (compteur de vie)
    profile_model.dart               # Profile (joueur persistant)
    scan_history_model.dart          # ScanHistoryItem
    scryfall_card_model.dart         # ScryfallCard
    scryfall_ruling.dart             # ScryfallRuling
    scryfall_set_model.dart          # ScryfallSet
    search_filters.dart              # SearchFilters
    wishlist_model.dart              # Wishlist

  services/                          # Couche service (logique metier + I/O)
    backup_service.dart              # Export/Import JSON, generation backup
    collection_service.dart          # CRUD collection, import batch, historique financier
    deck_service.dart                # CRUD decks, gestion zones (mainboard/sideboard/considering/wishlist)
    edhrec_service.dart              # Suggestions EDHRec par commandant
    game_history_service.dart        # Historique des parties
    google_drive_service.dart        # Google Sign-In + Drive API (backup auto)
    local_card_service.dart          # Recherche locale offline (Isolate/compute)
    oracle_service.dart              # Cloud Function ask_oracle (IA Firebase)
    profile_service.dart             # CRUD profils joueurs
    scan_history_service.dart        # Historique des scans camera
    scryfall_api.dart                # Constantes et helpers URLs Scryfall
    set_service.dart                 # Chargement des sets Scryfall
    wishlist_service.dart            # CRUD wishlists (avec migration legacy)

  pages/                             # Ecrans (pages completes)
    cards/
      card_detail_page.dart          # Detail d'une carte (image, texte, prix, legalites)
      card_search_page.dart          # Recherche de cartes (locale + API)
      set_list_page.dart             # Liste des sets MTG
    collections/
      collection_page.dart           # Page principale collection
      global_stats_page.dart         # Statistiques globales de la collection
      set_detail_page.dart           # Detail d'un set dans la collection
      set_stats_page.dart            # Stats par set
      wishlist_tab.dart              # Onglet wishlist dans la collection
    decks/
      deck_detail_page.dart          # Detail d'un deck (onglets: cartes, stats, suggestions)
      deck_list_page.dart            # Liste des decks
    glossary/
      glossary_detail_page.dart      # Detail d'un terme du glossaire
      glossary_page.dart             # Page glossaire MTG
      turn_guide_page.dart           # Guide des phases de tour
    life_counter/
      game_history_detail_page.dart  # Detail d'une partie historisee
      game_history_page.dart         # Historique des parties
      life_counter_page.dart         # Compteur de vie (page principale)
    oracle/
      magic_oracle_page.dart         # Oracle IA (questions de regles)
    scans/
      scanner_page.dart              # Scanner camera (OCR ML Kit)
      scan_history_page.dart         # Historique des scans
    settings/
      dev_tools_page.dart            # Outils developpeur (debug)
      profile_management_page.dart   # Gestion des profils joueurs
      settings_page.dart             # Parametres et sauvegarde
    tools/
      hypergeometric_page.dart       # Calculateur de probabilites hypergeometriques
    tournaments/
      tournament_page.dart           # Gestion de tournois
    wishlists/
      wishlist_detail_page.dart      # Detail d'une wishlist

  widgets/                           # Composants reutilisables
    cards/
      scryfall_image.dart            # Widget image Scryfall avec cache (CachedNetworkImage)
      versions_selector_sheet.dart   # Selecteur de versions d'une carte
    collection/
      collection_list_tab.dart       # Liste de la collection
      collection_sets_tab.dart       # Vue par sets de la collection
      quick_add_view.dart            # Ajout rapide a la collection
    decks/
      deck_card_list_tab.dart        # Liste des cartes d'un deck
      deck_card_picker.dart          # Selecteur de carte pour deck
      deck_card_title.dart           # Widget titre de carte dans un deck
      deck_financial_sheet.dart      # Apercu financier du deck
      deck_picker_modal.dart         # Modal selection de deck
      deck_share_preview.dart        # Preview partage deck
      deck_stats_tab.dart            # Statistiques du deck
      deck_suggestions_tab.dart      # Suggestions EDHRec
      deck_visual_share_list.dart    # Liste visuelle de partage
      draw_test_simulator.dart       # Simulateur de tirage
    life_counter/
      dice_roll_dialog.dart          # Dialog de lancer de des
      game_setup_modal.dart          # Modal configuration de partie
      player_zone.dart               # Zone joueur (compteur de vie)
    search/
      search_filter_modal.dart       # Modal de filtres de recherche
      skyrim_sneak_loader.dart       # Loader anime (Easter egg)
      universal_filter_modal.dart    # Modal de filtres universels
```

### 2.2 Architecture en Couches

```
+---------------------------+
|        UI (Pages)         |   Pages completes avec navigation
+---------------------------+
|      UI (Widgets)         |   Composants reutilisables
+---------------------------+
|       Services            |   Logique metier, acces donnees, API
+---------------------------+
|        Models             |   Data classes (serialisation JSON)
+---------------------------+
|   SharedPreferences       |   Stockage local (cle-valeur JSON)
+---------------------------+
|  APIs Externes            |   Scryfall, EDHRec, Firebase, Google Drive
+---------------------------+
```

### 2.3 Navigation

L'application utilise un pattern **AppShell** avec :
- **BottomNavigationBar** (5 onglets) : Compteur, Scanner, Recherche, Decks, Collection
- **Drawer** lateral : Historique Parties, Tournoi, Oracle IA, Calculateur Proba, Glossaire, Profils, Parametres, A propos
- **Navigation push** classique (`Navigator.push`) pour les sous-pages

---

## 3. Modeles de Domaine

### 3.1 ScryfallCard

Represente une carte Magic issue de l'API Scryfall.

| Champ            | Type                    | Description                                    |
|------------------|-------------------------|------------------------------------------------|
| id               | String                  | ID unique Scryfall                             |
| oracleId         | String                  | ID Oracle (regroupe toutes les editions)       |
| name             | String                  | Nom anglais                                    |
| printedName      | String?                 | Nom imprime (dans la langue de la carte)       |
| manaCost         | String?                 | Cout de mana (ex: {2}{U}{B})                  |
| cmc              | double?                 | Cout converti de mana                          |
| imageUrl         | String                  | URL image normale                              |
| smallImageUrl    | String?                 | URL image petite                               |
| artCropUrl       | String?                 | URL art crop                                   |
| rulesText        | String                  | Texte de regles                                |
| typeLine         | String                  | Ligne de type (ex: "Creature - Elf Wizard")    |
| legalities       | Map<String, String>     | Legalites par format                           |
| prices           | Map<String, dynamic>    | Prix par devise/condition                      |
| lang             | String                  | Langue de la carte                             |
| colorIdentity    | List<String>            | Identite de couleur                            |
| setName          | String                  | Nom du set                                     |
| setCode          | String                  | Code du set                                    |
| collectorNumber  | String                  | Numero de collecteur                           |
| rarity           | String                  | Rarete (common, uncommon, rare, mythic)        |
| purchaseUris     | Map<String, String>     | Liens d'achat (TCGplayer, CardMarket, etc.)    |

**Particularite** : Gere les cartes double-face (`card_faces`) en prenant les donnees de la premiere face.

### 3.2 DeckCard

Represente une carte dans un deck ou une collection.

| Champ          | Type          | Description                        |
|----------------|---------------|------------------------------------|
| scryfallId     | String        | ID Scryfall de reference           |
| name           | String        | Nom de la carte                    |
| quantity       | int           | Nombre d'exemplaires               |
| proxyQuantity  | int           | Nombre de proxies (defaut 0)       |
| isFoil         | bool          | Version brillante (defaut false)   |
| tags           | List<String>  | Tags utilisateur (ex: "Ramp")      |

### 3.3 Deck

| Champ                          | Type           | Description                          |
|--------------------------------|----------------|--------------------------------------|
| id                             | String         | ID unique (timestamp)                |
| name                           | String         | Nom du deck                          |
| mainboard                      | List<DeckCard> | Cartes du mainboard                  |
| sideboard                      | List<DeckCard> | Cartes du sideboard                  |
| considering                    | List<DeckCard> | Cartes en consideration              |
| wishlist                       | List<DeckCard> | Cartes souhaitees (trop cheres)      |
| commanderScryfallId            | String?        | ID du commandant principal           |
| commanderSecondaryScryfallId   | String?        | ID du commandant secondaire (Partner)|
| colors                         | List<String>   | Couleurs du deck                     |
| format                         | String         | Format (Standard, Commander, etc.)   |

### 3.4 Player

Modele runtime pour le compteur de vie (non persiste directement).

| Champ                    | Type           | Description                          |
|--------------------------|----------------|--------------------------------------|
| id                       | int            | ID du joueur dans la partie          |
| name                     | String         | Nom du joueur                        |
| life                     | int            | Points de vie actuels                |
| colorValue               | int            | Couleur de fond (ARGB)               |
| backgroundImagePath      | String?        | Image de fond (commandant)           |
| secondaryBackgroundImagePath | String?    | Image secondaire                     |
| commanderDamageReceived  | Map<int, int>  | Degats de commandant par adversaire  |
| poison                   | int            | Compteurs de poison                  |
| energy                   | int            | Compteurs d'energie                  |
| commanderCastCount       | int            | Nombre de lancers du commandant      |
| isMonarch                | bool           | Statut Monarque                      |
| quarterTurns             | int            | Rotation de la zone (0-3)            |

### 3.5 Profile

Profil joueur persistant (lie aux parties).

| Champ                              | Type    | Description                        |
|------------------------------------|---------|------------------------------------|
| id                                 | String  | ID unique                          |
| name                               | String  | Nom du joueur                      |
| colorValue                         | int     | Couleur associee                   |
| commanderScryfallId                | String? | ID Scryfall du commandant          |
| commanderName                      | String? | Nom du commandant                  |
| commanderArtCropUrl                | String? | URL art crop du commandant         |
| secondaryCommanderScryfallId       | String? | ID du commandant secondaire        |
| secondaryCommanderName             | String? | Nom du commandant secondaire       |
| secondaryCommanderArtCropUrl       | String? | URL art crop secondaire            |

Proprietes calculees : `commanderImageUrl`, `secondaryCommanderImageUrl` (fallback sur redirect Scryfall).

### 3.6 GameHistoryItem + PlayerHistorySnapshot

| Champ (GameHistoryItem) | Type                        | Description                   |
|-------------------------|-----------------------------|-------------------------------|
| id                      | String                      | ID unique                     |
| date                    | DateTime                    | Date de la partie             |
| durationSeconds         | int                         | Duree en secondes             |
| winnerName              | String                      | Nom du gagnant                |
| format                  | String                      | Format de jeu                 |
| winMethod               | String                      | Methode de victoire           |
| playerStates            | List<PlayerHistorySnapshot> | Etats finaux des joueurs      |

### 3.7 Autres Modeles

- **ScryfallSet** : Represente un set MTG (id, code, name, setType, releasedAt, cardCount, iconSvgUri, parentSetCode)
- **ScryfallRuling** : Regle officielle (date, comment)
- **ScanHistoryItem** : Historique de scan (scryfallId, cardName, imagePath, timestamp)
- **Wishlist** : Liste de souhaits (id, name, cards: List<DeckCard>, dateCreated, iconScryfallId)
- **SearchFilters** : Filtres de recherche (setCode, cardType, colors, cmc range, rarity, keyword, sort, tags)

---

## 4. Couche Services

### 4.1 LocalCardService (Singleton)

- Charge un fichier JSON local (`assets/json/oracle-cards.json`) contenant la base complete des cartes Oracle
- Utilise `compute()` (Dart Isolate) pour le parsing et la recherche, evitant le blocage du thread UI
- Fournit : `getCardById()`, `getCardByName()`, `searchCards()`, `findSmartMatch()`
- Gere un cache en memoire avec index par ID et par nom (y compris les cartes double-face)

### 4.2 CollectionService

- Stocke la collection dans `SharedPreferences` sous la cle `user_collection`
- CRUD via `upsertCardInCollection()` avec support foil/non-foil et tags
- Import batch : appelle l'endpoint `/cards/collection` de Scryfall par paquets de 75
- Historique financier : enregistrement quotidien de la valeur, nettoyage > 30 jours

### 4.3 DeckService

- Stocke les decks dans `SharedPreferences` sous la cle `user_decks`
- Gere 4 zones par deck : mainboard, sideboard, considering, wishlist
- Operations : `createNewDeck()`, `deleteDeck()`, `upsertCardInDeck()`, `moveCard()`, `changeCardVersion()`
- Gestion du commandant : `setCommander()` / `unsetCommander()` avec changement de format automatique

### 4.4 BackupService

- Genere un JSON de sauvegarde englobant toutes les cles SharedPreferences
- Cles sauvegardees : `user_collection`, `user_decks`, `user_wishlists_v2`, `user_wishlist`, `scan_history`, `glossaryLang`, `playerCount`, `startingLife`
- Export via `Share.shareXFiles()` (fichier temporaire)
- Import via `FilePicker` (fichier .json)

### 4.5 GoogleDriveService

- Authentification Google Sign-In avec scope `driveFileScope`
- Fichier de backup : `magic_companion_auto_backup.json`
- Operations : `findBackupFile()`, `downloadBackup()`, `uploadBackup()`
- Sauvegarde automatique declenchee quand l'app passe en `AppLifecycleState.paused`

### 4.6 EdhrecService

- Appelle l'API JSON non-officielle d'EDHRec (`json.edhrec.com/pages/commanders/{slug}.json`)
- Genere le slug du commandant (minuscule, suppression caracteres speciaux, remplacement espaces par tirets)
- Retourne les suggestions categorizees (Haute Synergie, Top Cartes, Creatures, Ephemeres, etc.)

### 4.7 OracleService (Singleton)

- Appelle la Cloud Function Firebase `ask_oracle`
- Recoit une question en langage naturel, retourne la reponse de l'IA

### 4.8 Autres Services

- **SetService** : Charge tous les sets depuis `api.scryfall.com/sets`
- **ProfileService** : CRUD des profils joueurs (SharedPreferences, cle `user_profiles`)
- **GameHistoryService** : Sauvegarde/chargement de l'historique des parties (cle `game_history`)
- **ScanHistoryService** : Historique des scans camera (cle `scan_history`, limite 50 items)
- **WishlistService** : CRUD wishlists avec migration automatique du format legacy (`user_wishlist` -> `user_wishlists_v2`)
- **ScryfallApi** : Classe utilitaire avec constantes d'URL et helpers pour extraire les art_crop (y compris cartes double-face)

---

## 5. Fonctionnalites Principales

### 5.1 Compteur de Vie
- Support 2-10 joueurs avec disposition adaptative
- Compteurs : vie, poison, energie, degats de commandant, lancers de commandant
- Statut Monarque
- Timer de partie integre
- Lancer de des (dialog dedie)
- Configuration de partie via modal (nombre de joueurs, vie de depart)
- Sauvegarde automatique de l'historique a la fin de partie
- Wakelock actif pendant la partie
- Profils joueurs avec image de commandant en fond

### 5.2 Scanner de Cartes
- Utilisation de la camera via le package `camera`
- Reconnaissance de texte via Google ML Kit (`google_mlkit_text_recognition`)
- Matching intelligent avec la base locale via `findSmartMatch()`
- Historique des scans (max 50 items)

### 5.3 Recherche de Cartes
- Recherche locale offline dans la base Oracle complete
- Filtres avances : type, couleur, set, rarete, CMC, mot-cle dans le texte de regles
- Tri configurable (nom, prix, cmc, type, date) ascendant/descendant
- Filtrage par tags utilisateur

### 5.4 Gestion de Decks
- Creation/suppression de decks
- 4 zones : Mainboard, Sideboard, Considering (en reflexion), Wishlist (trop cher)
- Commandant principal et secondaire (Partner)
- Changement de format automatique lors de l'assignation d'un commandant
- Changement de version de carte (entre editions)
- Deplacement de cartes entre zones
- Statistiques du deck (via onglet dedie)
- Suggestions EDHRec (pour Commander)
- Simulateur de tirage (draw test)
- Apercu financier
- Partage visuel (preview + liste)

### 5.5 Collection
- Ajout unitaire et import batch (format "Nx CardName")
- Distinction Foil / Non-Foil
- Tags utilisateur personnalises
- Historique de la valeur financiere (30 jours)
- Statistiques globales et par set
- Vue par sets

### 5.6 Wishlists
- Systeme multi-wishlists (migration automatique depuis le format legacy)
- Icone de couverture par wishlist
- CRUD complet (creation, renommage, suppression, vidage)

### 5.7 Oracle IA
- Chat avec un LLM specialise regles MTG via Firebase Cloud Function
- Interface de type chat avec Markdown rendering

### 5.8 Outils Complementaires
- Calculateur de probabilites hypergeometriques
- Glossaire MTG bilingue (FR/EN) depuis fichiers JSON
- Guide des phases de tour
- Gestion de tournois
- Outils developpeur (debug only)

---

## 6. Dependencies Principales

| Package                    | Version  | Usage                                      |
|----------------------------|----------|--------------------------------------------|
| flutter_riverpod           | ^3.0.3   | State management                           |
| http                       | ^1.2.1   | Appels HTTP (Scryfall, EDHRec)             |
| dio                        | ^5.9.0   | Client HTTP avance                         |
| shared_preferences         | ^2.2.3   | Stockage local cle-valeur                  |
| camera                     | ^0.11.3  | Acces camera                               |
| google_mlkit_text_recognition | ^0.11.0 | OCR pour scanner                         |
| firebase_core              | ^3.0.0   | Firebase                                   |
| cloud_functions            | ^5.0.0   | Firebase Cloud Functions (Oracle)          |
| google_sign_in             | ^6.1.0   | Authentification Google                    |
| googleapis                 | ^11.0.0  | Google Drive API                           |
| cached_network_image       | ^3.4.1   | Cache d'images reseau                      |
| google_fonts               | ^6.2.1   | Typographie (Cinzel principalement)        |
| fl_chart                   | ^0.68.0  | Graphiques et charts                       |
| flutter_svg                | ^2.0.10+1| Rendu SVG (icones de sets)                 |
| share_plus                 | ^12.0.1  | Partage de fichiers                        |
| wakelock_plus              | ^1.3.3   | Maintien ecran allume                      |
| flutter_markdown           | ^0.7.7+1 | Rendu Markdown (Oracle IA)                 |
| intl                       | ^0.20.2  | Internationalisation / formatage dates     |
| path_provider              | ^2.1.5   | Chemins fichiers systeme                   |
| file_picker                | ^10.3.7  | Selection de fichiers                      |
| connectivity_plus          | ^7.0.0   | Detection connectivite reseau              |
| flutter_speed_dial         | ^7.0.0   | Bouton flottant avec sous-actions          |
| package_info_plus          | ^8.0.0   | Infos version de l'app                     |
| image_picker               | ^1.2.1   | Selection d'images                         |
| url_launcher               | ^6.1.11  | Ouverture d'URLs externes                  |

### Dependency Overrides

```yaml
google_mlkit_commons: 0.11.0
google_mlkit_text_recognition: 0.15.0
```

---

## 7. Configuration et Theme

### Theme
- Base : `ThemeData.dark()`
- Fond principal : `#1A1A1A`
- AppBar : noir, elevation 0
- Navigation : jaune dore (`Colors.yellow.shade800`) pour l'item selectionne
- Typographie : Google Fonts Cinzel pour les titres/labels
- Image de fond : `background_texture_black.png`

### Localisation
- Locales supportees : FR (par defaut), EN
- Formatage des dates : `intl` avec initialisation `fr_FR`

### Orientation
- Verrouillee en portrait (portraitUp + portraitDown)

---

## 8. Integration API Scryfall

### Endpoints utilises

| Endpoint                            | Usage                                   |
|-------------------------------------|-----------------------------------------|
| `GET /sets`                         | Liste de tous les sets                  |
| `GET /cards/search?q=...`           | Recherche de cartes en ligne            |
| `POST /cards/collection`            | Recuperation batch par nom (max 75)     |
| `GET /cards/{id}?format=image&version=art_crop` | Redirect vers l'image art_crop |

### Classe ScryfallApi

Centralise les URLs de base :
- `baseUrl` : `https://api.scryfall.com`
- `setsUrl` : `https://api.scryfall.com/sets`
- `cardsSearchUrl` : `https://api.scryfall.com/cards/search`
- `cardsCollectionUrl` : `https://api.scryfall.com/cards/collection`
- `svgBaseUrl` : `https://svgs.scryfall.io/card-symbols`

### Widget ScryfallImage

Widget reutilisable pour afficher des images Scryfall avec :
- Cache disque via `CachedNetworkImage`
- Header `User-Agent: MagicCompanion/1.0` (obligatoire pour les URLs redirect)
- Placeholder avec spinner pendant le chargement
- Fallback icon en cas d'erreur
- Variante `ScryfallAvatarImage` pour les avatars circulaires

---

## 9. Stockage des Donnees

Toutes les donnees sont stockees en local via **SharedPreferences** au format JSON serialise.

| Cle                       | Type stocke   | Contenu                              |
|---------------------------|---------------|--------------------------------------|
| `user_collection`         | String (JSON) | Liste de DeckCard (collection)       |
| `user_decks`              | String (JSON) | Liste de Deck                        |
| `user_wishlists_v2`       | String (JSON) | Liste de Wishlist                    |
| `user_wishlist`           | String (JSON) | Legacy : ancienne wishlist unique    |
| `scan_history`            | String (JSON) | Liste de ScanHistoryItem             |
| `game_history`            | String (JSON) | Liste de GameHistoryItem             |
| `user_profiles`           | String (JSON) | Liste de Profile                     |
| `collection_value_history`| String (JSON) | Map date->valeur (historique financier)|
| `glossaryLang`            | String        | Langue du glossaire (fr/en)          |
| `playerCount`             | int           | Nombre de joueurs par defaut         |
| `startingLife`            | int           | Points de vie de depart par defaut   |

---

## 10. Sauvegarde et Restauration

### Flux de sauvegarde automatique (Google Drive)

```
1. Au demarrage : signIn(silent: true)
2. Si connecte : cherche le fichier backup sur Drive
3. Si backup trouve : propose la restauration via dialog
4. En cours d'utilisation : quand l'app passe en pause (AppLifecycleState.paused)
   -> generateBackupJson() -> uploadBackup()
5. Fichier Drive : "magic_companion_auto_backup.json"
```

### Flux manuel (fichier local)

```
Export : generateBackupJson() -> fichier temp -> Share.shareXFiles()
Import : FilePicker (.json) -> restoreFromJson()
```

---
