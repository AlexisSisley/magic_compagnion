# Import Moxfield : collection par fichier, decks par URL

Date : 2026-09-19
Statut : design validé, en attente de plan d'implémentation
Maquette validée : https://claude.ai/artifact/AcgKxXZdanZjFJv6ZFKuFj

## Le problème

Un joueur qui tient sa collection et ses decks sur Moxfield doit aujourd'hui
tout ressaisir dans l'app. Le menu « Importer (Masse) » de la page collection
existe pourtant déjà — et ne fait rien :

```dart
// lib/pages/collections/collection_page.dart:167
Future<void> _importBulk() async {
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text("Fonction d'import conservée (TODO: Implémenter appel modale)")));
}
```

Derrière, `CollectionService.importBatchCards` résout par nom seul et n'a aucun
appelant dans `lib/pages` ni `lib/widgets`. L'import de collection n'existe donc
pas : il y a une entrée de menu qui promet et une plomberie morte.

## Le cadre juridique, et la décision prise

Les conditions d'utilisation de Moxfield (`moxfield.com/help/terms`, lues le
2026-09-19) interdisent l'accès automatisé, clause (5) :

> *use any robot, spider or other automatic device, process or means to access
> the Site for any purpose, including monitoring or copying any information or
> material on the Site, except as expressly approved by Moxfield*

La licence accordée est par ailleurs limitée à *« your non-commercial personal
use »*.

**Deux chemins en découlent, et ils n'ont pas le même statut.**

- **L'import de collection par fichier exporté ne touche jamais leurs serveurs.**
  L'utilisateur exporte depuis son compte, l'app lit le fichier. Rien dans leurs
  conditions ne s'y oppose.
- **L'import de deck par URL interroge `api2.moxfield.com`.** C'est l'accès
  automatisé que la clause (5) prohibe.

**Le propriétaire du projet a été informé de cette clause et a décidé d'ajouter
malgré tout l'import par URL.** C'est un choix assumé, pas un oubli. Il est écrit
ici pour que quiconque lit ce code plus tard le sache, et pour que la décision
puisse être révisée en connaissance de cause.

Conséquences à accepter :

- Moxfield peut bloquer cet accès sans préavis ; la fonctionnalité doit alors
  échouer proprement et ne jamais laisser l'app dans un état cassé.
- L'import par fichier doit rester pleinement fonctionnel et autonome : il est le
  chemin de repli si l'URL cesse de marcher.

## Contraintes vérifiées

Sondes effectuées le 2026-09-19, résultats réels.

```
GET  api2.moxfield.com/v3/decks/all/{publicId}        -> 200, sans authentification
GET  api2.moxfield.com/v2/decks/search?authorUserNames=<pseudo> -> 200
GET  api2.moxfield.com/v1/collections                 -> 401
GET  api2.moxfield.com/v1/trade-binders                -> 401
```

Il n'existe donc **aucune URL publique de collection**, même pour la sienne :
le fichier exporté est le seul chemin possible pour la collection, autorisé ou
non.

Structure réelle d'un deck rendu par l'API (deck « Invincible toph », relevé le
2026-09-19) :

```
nom      : Invincible toph          format : commander
boards non vides :
   mainboard      97 entrees  (106 cartes)
   maybeboard     99 entrees  ( 99 cartes)
   commanders      1 entree   (  1 carte)
langues mainboard : {en: 97}       finitions : {nonFoil: 92, foil: 5}

par carte : quantity, isFoil, finish, isProxy,
            card { scryfall_id, set, cn, lang, name, ... }
```

Le `scryfall_id` est fourni directement. L'import par URL n'a donc besoin
d'aucune heuristique d'appariement — contrairement à l'import de fichier.

## Décisions

| # | Question | Décision |
|---|---|---|
| 1 | Accès à Moxfield | Fichier pour la collection ; URL pour les decks, en infraction assumée |
| 2 | Fusion de collection | Par tirage (`scryfallId` + `isFoil`), quantité absolue, rien n'est supprimé |
| 3 | Forme produit | Parcours guidé qui explique où exporter |
| 4 | Périmètre collection | Collection seule par fichier ; les decks passent par l'URL |
| 5 | Cartes non identifiées | Ajoutées par leur nom, marquées d'un tag `à vérifier` |
| 6 | Maybeboard | Importé vers le board `considering` du modèle `Deck` |

## Architecture

Deux chemins d'entrée, une seule chaîne de résolution — celle livrée par la spec
du 2026-09-17, déjà testée.

```
A. FICHIER (collection)                B. URL (deck)
   CSV exporté par l'utilisateur          https://moxfield.com/decks/<publicId>
        |                                      |
   MoxfieldCollectionParser               extraction de <publicId>
   (Dart pur, sans Flutter)               GET v3/decks/all/<publicId>
        |                                      |
   CollectionEntry                        MoxfieldDeckMapper
   {name, setCode, collectorNumber,       -> PrintRequest{scryfallId}
    lang, isFoil, quantity}                  (identifiant exact fourni)
        |                                      |
        +------------------+-------------------+
                           |
              CardResolver.resolveEditions()      <- existant, lots de 75
              EditionResolution{resolved, notFound, failed, errors}
                           |
        +------------------+-------------------+
        |                                      |
   upsertCollectionCard                   création du Deck
   (scryfallId, isFoil,                   mainboard / sideboard /
    absoluteQuantity, newTags)            considering / commandant
        |                                      |
        +------------------+-------------------+
                           |
              enqueueTranslation() pour tout tirage
              hors langue préférée, puis unawaited(drain())
```

Le seul composant réellement neuf est le parser CSV. Le reste est du câblage sur
de l'existant testé : `CardResolver`, `upsertCollectionCard` (qui clé déjà sur
`scryfallId` + `isFoil`), la file de traduction et la projection d'affichage.

## A. Import de collection par fichier

### Le parser

`MoxfieldCollectionParser` détecte chaque colonne par son nom, avec alias, casse
et espaces tolérés, colonnes dans n'importe quel ordre. Il classe les colonnes en
trois familles **selon ce que l'on perd si elles manquent** :

| Famille | Colonnes attendues | Si absentes |
|---|---|---|
| Indispensables | `Count` / `Quantity`, `Name` | L'import **refuse** et nomme la colonne manquante |
| Identité du tirage | `Edition` / `Set`, `Collector Number` | L'import continue en mode **dégradé**, signalé |
| Affinage | `Language`, `Foil` / `Finish` | Défauts (anglais, non-foil), signalés |

Cette gradation est la réponse au fait que le format exact n'a pas pu être
vérifié sur un fichier réel. On ne garantit pas de deviner les bons en-têtes ; on
garantit que **se tromper produit un message et non une collection fausse**.

Normalisation des valeurs, volontairement tolérante :

- **Foil** : `foil`, `true`, `1`, `yes`, `etched` → foil. Vide, `nonFoil`,
  `normal`, `false` → non-foil. Une colonne `Finish` est lue de la même façon.
- **Langue** : `fr`, `French`, `Français` → `fr`. Un code inconnu ne fait pas
  échouer la ligne : il vaut « pas de langue », et la carte est résolue sur son
  édition.
- **Quantité** : non numérique ou absente → la ligne est comptée comme illisible,
  jamais importée avec une quantité devinée.

### Le parcours

Quatre écrans, dont un seul demande une action (voir la maquette validée).

1. **Explication** — où cliquer sur Moxfield pour exporter, puis le sélecteur de
   fichier. Sans ces quelques lignes, personne ne découvre que l'export existe.
2. **Vérification** — nombre de lignes lues et colonnes reconnues. Ce n'est pas un
   sélecteur de stratégie de fusion : c'est un contrôle de format. En mode
   dégradé, le bouton dit **« Importer quand même »** et non « Importer ».
3. **Bilan** — importées, ajoutées, quantités mises à jour, non identifiées. Les
   cartes non identifiées sont **nommées**, pas comptées, et la liste est
   copiable.
4. Le mode dégradé est une variante de l'écran 2, pas un écran de plus.

### La fusion

`upsertCollectionCard(scryfallId, isFoil, absoluteQuantity, newTags)` existe déjà
et clé sur `(scryfallId, isFoil)` — exactement l'identité de fusion retenue.

- Un tirage présent dans le fichier **et** dans l'app : la quantité du fichier
  remplace celle de l'app.
- Un tirage présent seulement dans le fichier : ajouté.
- Un tirage présent seulement dans l'app : **laissé intact**. L'import n'efface
  jamais rien.

Écrire une quantité absolue et non une addition rend l'import **idempotent** :
réimporter le même fichier deux fois laisse la collection identique. C'est la
propriété qui compte, parce que réimporter par doute est le geste naturel quand
on n'est pas sûr que le premier import ait abouti.

### Les cartes non identifiées

Une ligne dont l'édition est inconnue de Scryfall, ou dont le numéro de
collection ne correspond à rien, est tout de même ajoutée — résolue par son nom
seul — et porte le tag **`à vérifier`**.

Aucune notion nouvelle n'est introduite : `upsertCollectionCard` accepte déjà
`newTags`, et `CollectionCards` porte une colonne `tags` en JSON. C'est une
convention, pas une fonctionnalité.

Le compte de la collection correspond ainsi au fichier, et l'approximation reste
repérable et filtrable.

## B. Import de deck par URL

### Extraction et récupération

L'utilisateur colle une URL de la forme
`https://moxfield.com/decks/<publicId>`. L'identifiant public est extrait par
expression régulière ; une URL qui n'en contient pas produit un message explicite
plutôt qu'une requête vouée à l'échec.

`GET https://api2.moxfield.com/v3/decks/all/<publicId>` rend le deck complet.
Codes à traiter distinctement :

- **404** — deck privé, supprimé, ou identifiant erroné. Message clair : le deck
  doit être public.
- **401 / 403** — accès refusé. Probable que Moxfield ait fermé l'accès (voir
  le cadre juridique) : message invitant à passer par l'export TXT, qui reste
  pleinement fonctionnel.
- **429 / 5xx / réseau** — panne transitoire, retenter plus tard.

### Correspondance des boards

| Moxfield | App (`Deck`) |
|---|---|
| `commanders` | `commanderScryfallId` (+ secondaire si partenaire) |
| `mainboard` | `mainboard` |
| `sideboard` | `sideboard` |
| `maybeboard` | `considering` |
| autres (`attractions`, `stickers`, `planes`…) | ignorés |

Les boards ignorés le sont silencieusement : ils n'ont pas d'équivalent dans le
modèle et ne concernent pas les formats que l'app gère.

### Résolution

Chaque carte porte son `scryfall_id`. Les requêtes sont donc des
`PrintRequest{scryfallId}`, résolues par identifiant exact. **L'heuristique
d'appariement par nom ou par set+numéro n'est jamais sollicitée** — le constat
parqué le 2026-09-18 sur l'appariement par inclusion ne s'applique pas à ce
chemin.

`quantity` et `isFoil` viennent du fichier JSON. `isProxy` est repris dans
`proxyQuantity` si la carte est marquée proxy.

## Règles

1. **L'app ne contacte jamais Moxfield pour la collection.** Elle lit un fichier
   exporté. Cette propriété doit rester vraie, y compris si quelqu'un propose
   plus tard d'« améliorer » en allant chercher le fichier automatiquement.
2. **L'import n'efface jamais rien.** Une carte que l'app connaît et que le
   fichier ignore reste intacte.
3. **Réimporter deux fois ne change rien.** Quantité absolue sur le couple
   tirage + foil.
4. **Aucune ligne ne disparaît en silence.** Importées + non identifiées +
   illisibles = nombre de lignes lues. Cette égalité est l'assertion centrale de
   la suite de tests.
5. **Un import dégradé ne se produit jamais sans décision explicite.** Le libellé
   du bouton est le seul endroit où cette décision se voit.

## Tests

| Quoi | Où | Comment |
|---|---|---|
| Détection des colonnes | `test/services/moxfield_collection_parser_test.dart` | Dart pur : en-tête attendu, alias, casse, ordre quelconque |
| Colonne indispensable absente | idem | L'import **refuse** et nomme la colonne |
| Mode dégradé | idem | Identité absente → résolution par nom, drapeau signalé |
| Valeurs de foil | idem | `foil`, `true`, `1`, `etched`, vide, `nonFoil` |
| Valeurs de langue | idem | `fr`, `French`, `Français`, code inconnu |
| Lignes malformées | idem | Guillemets, virgule dans un nom, ligne tronquée |
| Somme des sorties | idem | importées + non identifiées + illisibles = lignes lues |
| Fusion idempotente | `test/services/collection_import_test.dart` | Deux imports du même contenu → collection identique |
| Rien n'est supprimé | idem | Une carte absente du fichier survit à l'import |
| Tag `à vérifier` | idem | Posé sur les cartes résolues par nom, absent des autres |
| Extraction d'identifiant | `test/services/moxfield_deck_import_test.dart` | URL valide, URL sans identifiant, URL d'un autre site |
| Codes HTTP | idem | 404, 401, 429 → messages distincts, Dio mocké |
| Boards | idem | maybeboard → considering, commandant, boards ignorés |
| Quantités et foil | idem | `quantity`, `isFoil`, `isProxy` fidèlement repris |

L'assertion qui compte le plus est la somme des sorties. Sans elle, une ligne peut
s'évaporer entre le parser et la base sans qu'aucun test ne rougisse — c'est
exactement ce qui est arrivé trois fois lors du chantier précédent.

Les fixtures du chemin URL sont construites sur la structure réelle relevée
ci-dessus, pas sur une structure supposée.

## Validation visuelle (porte bloquante)

Maquette validée par l'utilisateur le 2026-09-19 :
https://claude.ai/artifact/AcgKxXZdanZjFJv6ZFKuFj

Capture des quatre écrans avant merge, comparée à cette maquette, selon la
convention de `test/captures/` (tag `capture`, polices système chargées).
Voir [[visual-work-needs-eyes]].

## Hors périmètre

- **L'import de deck par fichier reste inchangé.** Le TXT Moxfield est déjà lu
  correctement, codes d'édition et foil compris, depuis le chantier du
  2026-09-17.
- **Le format CSV de deck** continue de perdre les éditions là où le TXT les
  garde. Incohérence connue, non traitée ici.
- **La liste des decks publics d'un utilisateur**
  (`v2/decks/search?authorUserNames=`) n'est pas exploitée : l'import se fait deck
  par deck, par URL.
- **La collection par API** est impossible (401), et le restera sans compte
  authentifié.
- **L'identité de collection par langue est reportée.** La colonne `Language`
  du fichier est lue puis ignorée : `POST /cards/collection` ne parle que
  l'anglais et ignore le paramètre de langue, si bien que résoudre chaque
  carte dans sa langue coûterait une requête par carte — inacceptable sur
  1247 lignes. Plutôt que d'afficher `Language` comme une colonne reconnue et
  de mentir à l'utilisateur sur ce que l'app a compris de son fichier, la
  colonne a été retirée du modèle, du parser et de l'écran de vérification.
  Les traductions restent gérées, après coup, par la file de `TranslationWorker`
  selon la langue **préférée** de l'utilisateur, pas selon celle du fichier.
