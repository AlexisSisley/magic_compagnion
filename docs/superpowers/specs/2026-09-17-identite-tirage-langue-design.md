# Identité de tirage et langue d'affichage

Date : 2026-09-17
Statut : design validé, en attente de plan d'implémentation

## Le problème

L'import de decklist et le scanner rendent la mauvaise carte dès qu'elle
n'est pas anglaise. Le défaut n'est pas chez Scryfall : c'est l'identité
qu'on lui envoie qui est mutilée.

- `DeckFormatService._cleanCardName()` retire le set code et le numéro de
  collection de la ligne Moxfield : `1 Sol Ring (LTC) 284 *F*` devient
  `Sol Ring`.
- `CollectionService` (lib/services/collection_service.dart:122) interroge
  ensuite `POST /cards/collection` avec `{'name': ...}`. Scryfall répond par
  l'édition par défaut, anglaise.
- Le scanner extrait pourtant déjà `SET #cn` de l'image
  (`CardDetailController`, lib/controllers/card_detail_controller.dart:210)
  mais appelle `/cards/{set}/{cn}` **sans langue**.

Le modèle n'est pas en cause : `ScryfallCard` porte déjà `lang` et
`printedName`, et `DeckCard.scryfallId` est déjà une identité de tirage.
C'est la résolution qui perd l'information.

## Contraintes vérifiées sur l'API Scryfall

Sondes effectuées le 2026-09-17, résultats réels :

```
POST /cards/collection  {"set":"eld","collector_number":"146","lang":"fr"}
  -> Thrill of Possibility | printed_name: null | lang: en
     Le paramètre lang est ignoré, sans erreur.

GET /cards/eld/146/fr
  -> printed_name: "Frisson de probabilité" | lang: fr
     id 87027e87-e62d-42d6-9a79-c3e18394223d (différent de l'id anglais)

GET /cards/search?q=oracleid:<id> set:eld&unique=prints&include_multilingual=true
  -> 11 résultats : en, de, es, fr, it, ja, ko, pt, ru, zhs, zht

GET /cards/search?q=set:eld lang:fr&unique=prints&include_multilingual=true
  -> 280 cartes, 175 par page
```

Trois conséquences structurantes :

1. **Le batch ne parle qu'anglais.** `POST /cards/collection` ignore `lang`
   silencieusement. C'est exactement le piège qui produit le bug actuel.
2. **Chaque traduction a son propre id Scryfall.** Une carte française n'est
   pas une vue d'une carte anglaise : c'est un autre objet.
3. **La recherche par set et langue rend 175 cartes par requête.** C'est le
   levier qui rend le backfill de collection abordable (voir Optimisation).

La base locale (`assets/json/oracle-cards.json`, bulk `oracle-cards`) ne
contient ni tirage ni langue. Le bulk `all_cards`, seul à couvrir toutes les
langues, pèse environ 2 Go : exclu sur mobile.

## Décisions

| # | Question | Décision |
|---|---|---|
| 1 | Périmètre | La fondation d'abord ; le link Moxfield fera l'objet d'une spec séparée |
| 2 | Sémantique de la langue | Le tirage possédé est la vérité ; la langue est une projection d'affichage |
| 3 | Source des données traduites | À la demande, mises en cache dans Drift |
| 4 | Points d'entrée | Import, scanner, ajout manuel, migration de l'existant |
| 5 | Réglage de langue | `glossaryLang` promu en préférence de langue des cartes |
| 6 | Coût de l'import | Import rendu immédiatement, traductions en tâche de fond |
| 7 | Portée du backfill | Decks et collection uniquement |
| 8 | Noms français longs | Troncature sur une ligne, hauteur de ligne constante |

## Modèle d'identité

```
Collection / Deck  --> scryfallId  (le carton possédé : set + cn + lang + finish)
                   --> oracleId    (l'identité abstraite, stable entre langues)

Affichage          --> résolveur(oracleId, glossaryLang)
                         |- tirage traduit en cache -> nom, texte, image traduits
                         `- sinon                    -> repli sur scryfallId

Prix et valeur     --> toujours scryfallId, jamais la projection
```

`DeckCard.scryfallId` existe déjà et porte déjà cette sémantique. Le seul
ajout est `oracleId`. `scryfallId` n'est jamais réécrit par la projection
d'affichage : c'est la garantie que la valeur de la collection ne ment pas.

## Pipeline de résolution

Un service nouveau, `CardResolver`, devient le point de passage unique.

```
Temps 1 - l'édition (batch, 100 cartes par requête)
   {set, collector_number}  --POST /cards/collection-->  tirage EN + oracle_id
   (ou scryfall_id direct quand la source le fournit)

Temps 2 - la langue (unitaire, seulement si nécessaire)
   GET /cards/{set}/{cn}/{lang}  -->  printed_name, printed_text, image
   déclenché si : lang lue sur le carton != en, OU glossaryLang != en
   écrit dans le cache Drift : payé une fois, jamais deux
```

### Points d'entrée

| Entrée | Aujourd'hui | Après |
|---|---|---|
| Import decklist | `_cleanCardName` jette `(LTC) 284`, puis résolution par nom | `DecklistEntry` porte `setCode`, `collectorNumber`, `finish` jusqu'au batch |
| Scanner | `_fetchExactCard(set, cn)` sans langue | regex OCR élargie au code langue imprimé, `getCardBySetAndNumber(set, cn, lang)` |
| Ajout manuel | `versions_selector_sheet` affiche déjà `lang` | devient le point de vérité : `oracleid:<id> unique:prints include_multilingual=true` |
| Existant | `scryfallId` arbitraire | backfill de `oracleId` par batch d'ids ; `scryfallId` intact |

### Cache

Table Drift `card_prints`, clef `scryfallId` :

```
scryfallId (PK) | oracleId | setCode | collectorNumber | lang
printedName | printedText | imageUri | fetchedAt
```

Index sur `(oracleId, lang)` : c'est la requête de la projection d'affichage.

Table `print_translation_absent` : `(oracleId, lang)`. Un 404 est une réponse
légitime, pas une panne (beaucoup de cartes n'ont jamais eu de version
française). On mémorise le fait et on ne redemande plus jamais.

## Chargement en tâche de fond

L'import se termine dès le temps 1. Le deck est utilisable immédiatement,
avec la bonne édition. La traduction arrive ensuite et améliore l'affichage
sans jamais le bloquer.

```
Import --batch--> deck complet, éditions exactes   [l'utilisateur reprend la main]
            `--> enfile N tâches de traduction
                      |
                 Worker (respecte le 10 req/s de ScryfallApiService)
                      |- 200 -> écrit dans card_prints, l'UI se rafraîchit
                      |- 404 -> absence mémorisée définitivement
                      `- réseau ou 429 -> backoff, la file survit au kill
```

La file vit dans Drift (`print_translation_queue` : cible, langue, statut,
tentatives, dernière erreur), pas en mémoire. Une importation interrompue
reprend au lancement suivant au lieu de laisser un deck à moitié traduit.

Déclencheurs : fin d'import, fin de scan, changement de `glossaryLang`.
Au changement de langue, la file est bornée aux cartes présentes dans un deck
ou dans la collection.

### Optimisation du backfill

Pour le backfill de collection, grouper par set plutôt que par carte :
`q=set:<code> lang:<lang>&unique=prints&include_multilingual=true` rend 175
cartes par requête. Une collection de 3000 cartes réparties sur 40 sets passe
d'environ 3000 requêtes unitaires à environ 60. À implémenter après le chemin
unitaire, qui reste nécessaire pour l'import et le scan.

## Règles d'affichage

0. **Un nom de carte tient sur une ligne.** Troncature avec points de
   suspension au-delà. La hauteur de ligne ne varie jamais, quelle que soit la
   langue : c'est ce qui garde la liste de deck régulière et balayable au
   pouce. Conséquence assumée : les noms français les plus longs sont coupés.
1. **Jamais de spinner sur un nom de carte.** Le résolveur rend toujours
   quelque chose immédiatement : la traduction si elle est en cache, sinon le
   tirage réellement possédé. La traduction est un remplacement silencieux,
   pas un état de chargement.
2. **Le prix ne suit jamais la projection.** Même quand l'affichage bascule en
   français, la valeur reste calculée sur le `scryfallId` possédé.
3. **Repli explicite.** Quand aucune traduction n'existe, la carte s'affiche
   dans la langue du tirage possédé, sans message d'erreur.

## Tests

| Quoi | Où | Comment |
|---|---|---|
| Parsing `1 Sol Ring (LTC) 284 *F*` | `test/services/deck_format_service_test.dart` | Dart pur, aucun mock |
| Résolution édition puis langue | `test/services/card_resolver_test.dart` (nouveau) | Dio mocké sur les fixtures réelles `eld/146` en et fr |
| 404 mémorisé | idem | une seconde demande ne produit **aucune** requête |
| File de traduction | nouveau | persistance, backoff, reprise après kill |
| Backfill `oracleId` | `test/data` | l'ancien `scryfallId` doit rester intact |

Le test qui compte le plus est celui qu'on est le plus tenté d'écrire en vert
facile. Vérifier que `printedName` est non nul passe même si on a écrasé la
vérité de la collection. Les assertions qui discriminent vraiment sont :
aucune requête au deuxième affichage, et `scryfallId` possédé jamais réécrit.

## Validation visuelle (porte bloquante)

Cette fonctionnalité déplace des pixels : les noms s'allongent
(« Frisson de probabilité » contre « Thrill of Possibility »), les images
changent, et le basculement en tâche de fond est précisément ce qu'aucun test
de widget n'attrape. Les tests de widgets mesurent des contraintes, jamais de
la lisibilité. Le lot 6 était parti avec 1028 tests verts et a été reverté.

Règle pour ce chantier, non négociable :

1. **Maquette validée avant d'écrire le code d'affichage.** Liste de deck et
   fiche carte, en français et en anglais, côte à côte.
   Maquette du 2026-09-17, validée : https://claude.ai/artifact/6hnNC9MM1fH112ptf8oMoQ
2. **Capture d'écran avant merge**, sur les mêmes écrans, validée par
   l'utilisateur.

Voir [[visual-work-needs-eyes]].

## Hors périmètre

- Le link Moxfield (spec séparée). Sonde faite : `GET
  api2.moxfield.com/v3/decks/all/{publicId}` répond 200 sans authentification
  et fournit `scryfall_id`, `set`, `cn`, `lang` et `finish` par carte ;
  `v2/decks/search?authorUserNames=<pseudo>` liste les decks publics d'un
  utilisateur. Les endpoints de collection (`/v1/collections`,
  `/v1/trade-binders`) répondent 401 : la collection passera par l'export CSV.
- Le téléchargement du bulk `all_cards`.
- La préférence de langue par deck.
