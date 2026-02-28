# Scryfall API - Reference Technique

> Genere le 26/02/2026 par Doc-Hunt (Agent Documentation Externe)
> Source officielle : https://scryfall.com/docs/api

---

## 1. Informations Generales

| Propriete          | Valeur                                |
|--------------------|---------------------------------------|
| Base URL           | `https://api.scryfall.com`            |
| Protocole          | HTTPS uniquement (TLS 1.2+)          |
| Encodage           | UTF-8                                 |
| Format reponse     | JSON (par defaut)                     |

### Headers Obligatoires

| Header       | Valeur                          | Notes                                    |
|--------------|---------------------------------|------------------------------------------|
| User-Agent   | `NomApp/Version`                | Obligatoire, doit etre precis            |
| Accept       | `*/*` ou `application/json`     | Recommande                               |

### Rate Limiting

- **Delai recommande** : 50-100ms entre chaque requete (~10 req/s max)
- **Depassement** : Retourne `HTTP 429 Too Many Requests`
- **Abus repete** : Ban IP temporaire ou permanent
- **Exception** : Les fichiers sur `*.scryfall.io` (images CDN) ne sont pas soumis au rate limit

### Politique de Cache

- Cacher les donnees telechargees pendant **au moins 24 heures**
- Les prix sont mis a jour **une fois par 24h**
- Les donnees de gameplay changent peu frequemment
- Utiliser les **Bulk Data** pour les telechargements massifs

---

## 2. Endpoints Cards

### 2.1 GET /cards/search

Recherche de cartes avec la syntaxe de recherche Scryfall.

**URL** : `https://api.scryfall.com/cards/search`

| Parametre               | Type    | Requis | Description                                                      |
|--------------------------|---------|--------|------------------------------------------------------------------|
| `q`                      | String  | Oui    | Requete de recherche (max 1000 caracteres Unicode, URL-encoded)  |
| `unique`                 | String  | Non    | Strategie de deduplication : `cards` (defaut), `art`, `prints`   |
| `order`                  | String  | Non    | Tri : `name`, `set`, `released`, `rarity`, `color`, `usd`, `tix`, `eur`, `cmc`, `power`, `toughness`, `edhrec`, `penny`, `artist`, `review` |
| `dir`                    | String  | Non    | Direction du tri : `auto` (defaut), `asc`, `desc`                |
| `include_extras`         | Boolean | Non    | Inclure tokens/plans/etc. (defaut: false)                        |
| `include_multilingual`   | Boolean | Non    | Inclure toutes les langues (defaut: false)                       |
| `include_variations`     | Boolean | Non    | Inclure les variantes rares (defaut: false)                      |
| `page`                   | Integer | Non    | Numero de page (defaut: 1)                                       |
| `format`                 | String  | Non    | Format de sortie : `json` (defaut) ou `csv`                     |
| `pretty`                 | Boolean | Non    | JSON indente (eviter en prod)                                    |

**Reponse** : Objet List contenant des objets Card. Pagine par 175 cartes.

**Usage dans l'app** : `CollectionService` et pages de recherche.

---

### 2.2 GET /cards/named

Recherche d'une carte par son nom exact ou approximatif.

**URL** : `https://api.scryfall.com/cards/named`

| Parametre  | Type    | Requis | Description                                                    |
|------------|---------|--------|----------------------------------------------------------------|
| `exact`    | String  | Non*   | Nom exact de la carte (insensible a la casse)                  |
| `fuzzy`    | String  | Non*   | Nom approximatif (tolere fautes de frappe)                     |
| `set`      | String  | Non    | Restreindre a un code de set specifique                        |
| `format`   | String  | Non    | Format : `json` (defaut), `text`, `image`                     |
| `face`     | String  | Non    | `back` pour le verso (format image uniquement)                 |
| `version`  | String  | Non    | Taille image : `small`, `normal`, `large`, `png`, `art_crop`, `border_crop` |

*Un des deux (exact ou fuzzy) est requis.

**Erreurs** :
- `404` : Carte non trouvee (exact) ou trop d'ambiguite (fuzzy)
- `422` : Face arriere demandee sur carte simple face

---

### 2.3 GET /cards/autocomplete

Suggestions de noms de cartes pour l'autocompletion.

**URL** : `https://api.scryfall.com/cards/autocomplete`

| Parametre | Type   | Requis | Description                      |
|-----------|--------|--------|----------------------------------|
| `q`       | String | Oui    | Texte de recherche               |

---

### 2.4 GET /cards/random

Retourne une carte aleatoire.

**URL** : `https://api.scryfall.com/cards/random`

| Parametre | Type   | Requis | Description                                   |
|-----------|--------|--------|-----------------------------------------------|
| `q`       | String | Non    | Filtre de recherche pour restreindre le pool   |

---

### 2.5 POST /cards/collection

Recuperation de plusieurs cartes en une seule requete.

**URL** : `https://api.scryfall.com/cards/collection`

**Content-Type** : `application/json`

**Corps de la requete** :
```json
{
  "identifiers": [
    { "id": "uuid-scryfall" },
    { "name": "Lightning Bolt" },
    { "name": "Sol Ring", "set": "c21" },
    { "collector_number": "1", "set": "mh2" },
    { "mtgo_id": 12345 },
    { "multiverse_id": 489375 },
    { "oracle_id": "uuid-oracle" },
    { "illustration_id": "uuid-illustration" }
  ]
}
```

**Schemas d'identifiants supportes** :

| Schema                   | Type     | Description                                     |
|--------------------------|----------|-------------------------------------------------|
| `id`                     | UUID     | ID unique Scryfall                              |
| `mtgo_id`                | Integer  | ID Magic Online                                 |
| `multiverse_id`          | Integer  | ID Gatherer                                     |
| `oracle_id`              | UUID     | Retourne l'edition la plus recente              |
| `illustration_id`        | UUID     | Scan prefere avec cette illustration            |
| `name`                   | String   | Edition la plus recente par nom                 |
| `name` + `set`           | Strings  | Carte specifique par nom et set                 |
| `collector_number` + `set` | Strings | Carte specifique par numero et set             |

**Limites** :
- Maximum **75 identifiants** par requete
- Plusieurs schemas peuvent etre melanges dans une meme requete

**Reponse** :
- `data` : Liste des cartes trouvees (dans l'ordre de la requete)
- `not_found` : Liste des identifiants non trouves

**Usage dans l'app** : `CollectionService.importBatchCards()` (par paquets de 75)

---

### 2.6 GET /cards/:id

Recuperation directe par UUID Scryfall.

**URL** : `https://api.scryfall.com/cards/{id}`

| Parametre | Type   | Requis | Description                                        |
|-----------|--------|--------|----------------------------------------------------|
| `format`  | String | Non    | `json` (defaut) ou `image`                         |
| `version` | String | Non    | Version image : `small`, `normal`, `large`, `png`, `art_crop`, `border_crop` |

**Usage dans l'app** : `ScryfallApi.artCropRedirectUrl()` avec `?format=image&version=art_crop`

---

### 2.7 GET /cards/:code/:number(/:lang)

Recuperation par code de set et numero de collecteur.

**URL** : `https://api.scryfall.com/cards/{code}/{number}` ou `/cards/{code}/{number}/{lang}`

---

### 2.8 Endpoints Cross-Reference

| Endpoint                      | Description                |
|-------------------------------|----------------------------|
| GET /cards/multiverse/:id     | Recherche par ID Gatherer  |
| GET /cards/mtgo/:id           | Recherche par ID MTGO      |
| GET /cards/arena/:id          | Recherche par ID Arena     |
| GET /cards/tcgplayer/:id      | Recherche par ID TCGplayer |
| GET /cards/cardmarket/:id     | Recherche par ID Cardmarket|

---

## 3. Objet Card

L'objet Card est la structure principale retournee par l'API. Voici les champs principaux :

### Core Properties

| Champ            | Type           | Description                                    |
|------------------|----------------|------------------------------------------------|
| id               | UUID           | ID unique Scryfall                             |
| oracle_id        | UUID           | ID Oracle (partage entre editions)             |
| name             | String         | Nom complet (anglais)                          |
| printed_name     | String?        | Nom imprime (dans la langue de l'edition)      |
| lang             | String         | Code langue (en, fr, de, ja, etc.)             |
| layout           | String         | Type de carte (normal, transform, mdfc, etc.)  |
| uri              | URI            | URL API de cette carte                         |
| scryfall_uri     | URI            | URL web sur scryfall.com                       |

### Gameplay Fields

| Champ            | Type           | Description                                    |
|------------------|----------------|------------------------------------------------|
| mana_cost        | String?        | Cout de mana (ex: {1}{W}{U})                  |
| cmc              | Decimal        | Cout converti de mana                          |
| type_line        | String         | Ligne de type                                  |
| oracle_text      | String?        | Texte de regles Oracle                         |
| printed_text     | String?        | Texte imprime (langue de l'edition)            |
| power            | String?        | Force (creatures)                              |
| toughness        | String?        | Endurance (creatures)                          |
| loyalty          | String?        | Loyaute (planeswalkers)                        |
| colors           | Array          | Couleurs de la carte                           |
| color_identity   | Array          | Identite de couleur (pour Commander)           |
| keywords         | Array          | Mots-cles de la carte                          |
| legalities       | Object         | Statut de legalite par format                  |

### Print Fields

| Champ              | Type         | Description                                  |
|--------------------|--------------|----------------------------------------------|
| set                | String       | Code du set                                  |
| set_name           | String       | Nom du set                                   |
| collector_number   | String       | Numero de collecteur                         |
| rarity             | String       | Rarete : common, uncommon, rare, mythic      |
| image_uris         | Object?      | URLs des images (voir ci-dessous)            |
| card_faces         | Array?       | Faces pour les cartes double-face            |
| prices             | Object       | Prix : usd, usd_foil, eur, eur_foil, tix    |
| purchase_uris      | Object       | Liens d'achat (tcgplayer, cardmarket, etc.)  |

### image_uris

| Cle          | Description                              | Dimensions       |
|--------------|------------------------------------------|-------------------|
| small        | Petite image JPEG                        | 146 x 204        |
| normal       | Image JPEG standard                      | 488 x 680        |
| large        | Grande image JPEG                        | 672 x 936        |
| png          | Image PNG pleine resolution              | 745 x 1040       |
| art_crop     | Image recadree sur l'illustration        | variable          |
| border_crop  | Image recadree sans bord noir            | 480 x 680        |

### card_faces (cartes double-face)

Pour les cartes avec layout `transform`, `modal_dfc`, etc., les champs `image_uris`, `oracle_text`, `mana_cost`, `printed_name`, `printed_text` se trouvent dans chaque face du tableau `card_faces`.

---

## 4. Endpoint Sets

### 4.1 GET /sets

Retourne tous les sets Magic.

**URL** : `https://api.scryfall.com/sets`

**Reponse** : Objet List contenant des objets Set.

**Usage dans l'app** : `SetService.getAllSets()`

### 4.2 Objet Set

| Champ            | Type      | Description                               |
|------------------|-----------|-------------------------------------------|
| id               | UUID      | ID unique du set                          |
| code             | String    | Code du set (3-6 lettres)                 |
| mtgo_code        | String?   | Code MTGO                                 |
| arena_code       | String?   | Code Arena                                |
| tcgplayer_id     | Integer?  | ID groupe TCGplayer                       |
| name             | String    | Nom du set (anglais)                      |
| set_type         | String    | Type de set (expansion, core, commander..)|
| released_at      | Date?     | Date de sortie (GMT-8)                    |
| block_code       | String?   | Code du bloc                              |
| block            | String?   | Nom du bloc                               |
| parent_set_code  | String?   | Code du set parent (pour promos/tokens)   |
| card_count       | Integer   | Nombre total de cartes                    |
| printed_size     | Integer?  | Denominateur du numero de collecteur      |
| digital          | Boolean   | Set uniquement digital                    |
| foil_only        | Boolean   | Contient uniquement des foils             |
| nonfoil_only     | Boolean   | Contient uniquement des non-foils         |
| scryfall_uri     | URI       | URL de la page web                        |
| uri              | URI       | URL API                                   |
| icon_svg_uri     | URI       | URL de l'icone SVG du set                 |
| search_uri       | URI       | URL de recherche des cartes du set        |

### Autres Endpoints Sets

| Endpoint                  | Description                     |
|---------------------------|---------------------------------|
| GET /sets/:code           | Set par code                    |
| GET /sets/:id             | Set par UUID Scryfall           |
| GET /sets/tcgplayer/:id   | Set par ID TCGplayer            |

---

## 5. Endpoint Rulings

Regles officielles et notes de set pour une carte.

### Objet Ruling

| Champ         | Type   | Description                                  |
|---------------|--------|----------------------------------------------|
| object        | String | Toujours `"ruling"`                          |
| oracle_id     | UUID   | ID Oracle de la carte associee               |
| source        | String | Source : `"wotc"` ou `"scryfall"`            |
| published_at  | Date   | Date de publication                          |
| comment       | String | Texte de la regle                            |

### Endpoints Rulings

| Endpoint                               | Description                         |
|----------------------------------------|-------------------------------------|
| GET /cards/:id/rulings                 | Regles par UUID Scryfall            |
| GET /cards/:code/:number/rulings       | Regles par set/numero               |
| GET /cards/multiverse/:id/rulings      | Regles par ID Gatherer              |
| GET /cards/mtgo/:id/rulings            | Regles par ID MTGO                  |
| GET /cards/arena/:id/rulings           | Regles par ID Arena                 |

---

## 6. Endpoint Symbology

### GET /symbology

Retourne tous les symboles de mana et de regles.

**URL** : `https://api.scryfall.com/symbology`

### GET /symbology/parse-mana

Parse un cout de mana et retourne les symboles correspondants.

**URL** : `https://api.scryfall.com/symbology/parse-mana`

### Objet CardSymbol

| Champ                 | Type     | Description                                    |
|-----------------------|----------|------------------------------------------------|
| symbol                | String   | Notation du symbole (ex: `{U}`, `{2/W}`)      |
| loose_variant         | String?  | Forme sans accolades                           |
| english               | String   | Description lisible                            |
| transposable          | Boolean  | Peut etre ecrit a l'envers                     |
| represents_mana       | Boolean  | Est un symbole de mana                         |
| mana_value            | Decimal? | Valeur numerique de mana                       |
| appears_in_mana_costs | Boolean  | Apparait dans les couts de mana                |
| funny                 | Boolean  | Utilise uniquement sur les cartes humoristiques|
| colors                | Array    | Couleurs associees                             |
| hybrid                | Boolean  | Mana hybride                                   |
| phyrexian             | Boolean  | Payable avec 2 points de vie                   |
| svg_uri               | URI?     | URL de l'image SVG                             |

**Usage dans l'app** : `ScryfallApi.svgBaseUrl` pointe vers `https://svgs.scryfall.io/card-symbols`

---

## 7. Endpoint Catalogs

Catalogues de valeurs pour aider les developpeurs.

**URL** : `https://api.scryfall.com/catalog/{type}`

### Catalogues Disponibles

| Endpoint                    | Description                    |
|-----------------------------|--------------------------------|
| /catalog/card-names         | Tous les noms de cartes        |
| /catalog/artist-names       | Tous les noms d'artistes       |
| /catalog/word-bank          | Mots utilises dans les textes  |
| /catalog/supertypes         | Supertypes de carte            |
| /catalog/card-types         | Types de carte                 |
| /catalog/artifact-types     | Sous-types d'artefact          |
| /catalog/battle-types       | Types de bataille              |
| /catalog/creature-types     | Types de creature              |
| /catalog/enchantment-types  | Types d'enchantement           |
| /catalog/land-types         | Types de terrain               |
| /catalog/planeswalker-types | Types de planeswalker          |
| /catalog/spell-types        | Types de sort                  |
| /catalog/powers             | Valeurs de force               |
| /catalog/toughnesses        | Valeurs d'endurance            |
| /catalog/loyalties          | Valeurs de loyaute             |
| /catalog/keyword-abilities  | Capacites a mot-cle            |
| /catalog/keyword-actions    | Actions a mot-cle              |
| /catalog/ability-words      | Mots de capacite               |
| /catalog/flavor-words       | Mots de saveur                 |
| /catalog/watermarks         | Filigranes                     |

**Objet Catalog** :
```json
{
  "object": "catalog",
  "uri": "https://api.scryfall.com/catalog/card-names",
  "total_values": 27000,
  "data": ["Lightning Bolt", "Sol Ring", ...]
}
```

---

## 8. Endpoint Bulk Data

Telechargement de donnees en masse.

### Endpoints

| Endpoint            | Description                           |
|---------------------|---------------------------------------|
| GET /bulk-data      | Liste tous les fichiers disponibles   |
| GET /bulk-data/:id  | Fichier specifique par UUID           |
| GET /bulk-data/:type| Fichier specifique par type           |

### Types de Bulk Data

| Type              | Description                                              | Taille    |
|-------------------|----------------------------------------------------------|-----------|
| oracle_cards      | Une carte par Oracle ID (edition curatee)                | ~162 MB   |
| unique_artwork    | Toutes les illustrations uniques                         | ~235 MB   |
| default_cards     | Toutes les cartes en anglais                             | ~504 MB   |
| all_cards         | Toutes les cartes dans toutes les langues                | ~2.3 GB   |
| rulings           | Toutes les regles (reference par oracle_id)              | ~23.4 MB  |

### Objet BulkData

| Champ            | Type      | Description                           |
|------------------|-----------|---------------------------------------|
| id               | UUID      | ID unique                             |
| uri              | URI       | URL API                               |
| type             | String    | Type du fichier                       |
| name             | String    | Nom lisible                           |
| description      | String    | Description detaillee                 |
| download_uri     | URI       | Lien de telechargement direct         |
| updated_at       | Timestamp | Derniere mise a jour                  |
| size             | Integer   | Taille en octets                      |
| content_type     | String    | Type MIME                             |
| content_encoding | String    | Encodage de transmission              |

**Usage dans l'app** : Le fichier `assets/json/oracle-cards.json` utilise par `LocalCardService` provient du type `oracle_cards`.

**Recommandations** :
- Les fichiers bulk ne sont rafraichis que toutes les 12 heures
- Les prix deviennent obsoletes apres 24h
- Les donnees de gameplay changent rarement, un telechargement hebdomadaire suffit

---

## 9. Correspondance App / API

| Fonctionnalite App          | Endpoint Scryfall Utilise                    | Service App             |
|-----------------------------|----------------------------------------------|-------------------------|
| Recherche de cartes online  | GET /cards/search                            | Pages de recherche      |
| Import batch collection     | POST /cards/collection                       | CollectionService       |
| Chargement des sets         | GET /sets                                    | SetService              |
| Images de cartes (cache)    | CDN cards.scryfall.io (via image_uris)       | ScryfallImage widget    |
| Art crop commandant         | GET /cards/:id?format=image&version=art_crop | ScryfallApi helper      |
| Base locale offline         | Bulk Data : oracle_cards (pre-telecharge)    | LocalCardService        |
| Icones de symboles          | CDN svgs.scryfall.io/card-symbols            | ScryfallApi.svgBaseUrl  |

---

## 10. Bonnes Pratiques et Regles d'Utilisation

1. **Toujours inclure un User-Agent** precis dans les requetes API
2. **Respecter le rate limit** de 50-100ms entre requetes (~10/s)
3. **Cacher les donnees** au moins 24h
4. **Utiliser les Bulk Data** pour les telechargements massifs (plutot que des milliers de requetes individuelles)
5. **Les images CDN** (cards.scryfall.io) ne sont pas soumises au rate limit
6. **Conformite** : respecter la Fan Content Policy de Wizards of the Coast
7. **Pas de paywall** sur les donnees Scryfall repackagees
8. **Attribution** : les images de cartes sont la propriete de Wizards of the Coast
