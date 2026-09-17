// Point de passage unique de toute resolution de carte.
//
// Deux temps, imposes par l'API Scryfall :
//   1. POST /cards/collection fixe l'edition (il IGNORE le parametre lang)
//   2. GET /cards/{set}/{cn}/{lang} rend la traduction, qui a son propre id
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import 'dart:convert';

import 'package:dio/dio.dart';

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import 'scryfall_api_service.dart';

class CardResolver {
  static const int _batchSize = 75;

  final ScryfallApiService _api;
  final AppDatabase _db;

  CardResolver({required ScryfallApiService api, required AppDatabase db})
      : _api = api,
        _db = db;

  /// Temps 1 : fixe l'edition de chaque requete, cache compris.
  ///
  /// Un lot en echec (reseau, 5xx, 429) ne condamne pas les autres lots :
  /// ses requetes sont nommees dans [EditionResolution.failed] plutot que de
  /// disparaitre silencieusement. Une carte que Scryfall declare introuvable
  /// (champ `not_found`) est nommee dans [EditionResolution.notFound].
  ///
  /// Invariant : aucune requete ne disparait, et rien ne s'ajoute qui n'en
  /// ait consomme une. Toute requete passee a [resolveEditions] se retrouve
  /// dans exactement un seau (resolved, notFound ou failed) : au sortir de
  /// cette methode, `resolved.length + notFound.length + failed.length`
  /// vaut exactement `requests.length`. En particulier, deux [PrintRequest]
  /// d'un meme lot peuvent porter un identifiant structurel identique (deux
  /// requetes par nom seul, ou deux exemplaires de la meme carte listes
  /// ligne a ligne dans une decklist) : l'appariement se fait donc par
  /// consommation d'une liste de travail des requetes non encore attribuees
  /// pour le lot courant (une requete en est retiree a chaque appariement,
  /// qu'il provienne d'une carte rendue ou d'une entree `not_found`), jamais
  /// par simple recherche de "la premiere qui correspond" — une recherche
  /// attribuerait la meme requete a chaque doublon et en perdrait d'autres
  /// silencieusement. Toute requete du lot restee non attribuee a la fin
  /// (ni rendue, ni declaree `not_found` par Scryfall) rejoint notFound :
  /// elle n'a pas trouve son tirage, c'est un fait, et c'est infiniment
  /// preferable a son effacement. Symetriquement, une carte rendue par
  /// Scryfall qui ne consomme aucune requete restante (l'inverse du cas
  /// precedent : quelque chose en trop, plutot que quelque chose en moins)
  /// ne rejoint pas [EditionResolution.resolved] — sous peine de faire
  /// grossir ce seau sans qu'aucune requete n'en soit la source, ce qui
  /// romprait l'egalite ci-dessus tout aussi surement qu'une disparition.
  /// Elle est alors nommee dans [EditionResolution.errors] a la place.
  Future<EditionResolution> resolveEditions(List<PrintRequest> requests) async {
    final List<ResolvedPrint> resolved = [];
    final List<PrintRequest> notFound = [];
    final List<PrintRequest> failed = [];
    final List<String> errors = [];
    final List<PrintRequest> toFetch = [];

    for (final request in requests) {
      final cached = await _fromCache(request);
      if (cached != null) {
        resolved.add(cached);
      } else {
        toFetch.add(request);
      }
    }

    for (var i = 0; i < toFetch.length; i += _batchSize) {
      final slice = toFetch.skip(i).take(_batchSize).toList();
      final identifiers = slice.map(_toIdentifier).toList();
      // Liste de travail : indices (dans slice/identifiers) des requetes du
      // lot pas encore attribuees a un seau. Consommee, jamais recherchee.
      final unassigned = List<int>.generate(slice.length, (i) => i);

      try {
        final data = await _api.fetchCollection(identifiers);
        final List<dynamic> found = data['data'] ?? [];
        for (final json in found) {
          final cardJson = json as Map<String, dynamic>;
          // La carte rendue porte, en plus des siens, les champs de
          // l'identifiant envoye : on consomme la requete correspondante
          // pour qu'elle ne soit pas comptee deux fois. Si aucune requete
          // restante ne correspond, cette carte est en trop : elle ne doit
          // pas rejoindre resolved sans avoir consomme personne, sous peine
          // de faire grossir ce seau sans requete source (voir l'invariant
          // documente au-dessus de cette methode).
          final index = _consumeMatch(unassigned, identifiers, cardJson);
          if (index == null) {
            errors.add(_describeUnexpectedCard(cardJson));
            continue;
          }
          final print = ResolvedPrint.fromJson(cardJson);
          await _cache(print);
          resolved.add(print);
        }

        final List<dynamic> notFoundIdentifiers = data['not_found'] ?? [];
        for (final identifier in notFoundIdentifiers) {
          final index = _consumeMatch(
              unassigned, identifiers, identifier as Map<String, dynamic>);
          if (index != null) notFound.add(slice[index]);
        }

        // Toute requete du lot ni rendue ni declaree not_found par Scryfall
        // rejoint notFound plutot que de disparaitre.
        for (final index in unassigned) {
          notFound.add(slice[index]);
        }
      } on DioException catch (e) {
        // Lot injoignable : ses requetes sont nommees, pas perdues. On ne
        // propage pas l'exception — un seul lot en echec ne doit pas tuer
        // les autres lots deja resolus.
        failed.addAll(slice);
        errors.add(_describeError(e, slice.length));
      }
    }

    return EditionResolution(
      resolved: resolved,
      notFound: notFound,
      failed: failed,
      errors: errors,
    );
  }

  /// Message d'erreur exploitable : la taille du lot concerne et le type de
  /// l'exception sont toujours presents ; le code de statut HTTP et le
  /// message sont ajoutes quand ils existent. `DioException.message` est
  /// `null` pour toute exception de type `badResponse` (le cas le plus
  /// courant : 429, 5xx) — sans le code de statut et le type, un appelant
  /// ne peut pas distinguer un 429 d'un timeout a la seule lecture de ce
  /// message, et [EditionResolution.errors] ne serait d'aucun secours.
  String _describeError(DioException e, int batchSize) {
    final statusCode = e.response?.statusCode;
    final parts = <String>[
      'lot de $batchSize carte(s)',
      'type=${e.type}',
      if (statusCode != null) 'statusCode=$statusCode',
      if (e.message != null) 'message=${e.message}',
    ];
    return parts.join(', ');
  }

  /// Message nommant une carte rendue par Scryfall dans `data` mais
  /// qu'aucune requete restante du lot ne demandait (voir l'invariant
  /// documente au-dessus de [resolveEditions]). Ne devrait normalement pas
  /// arriver — Scryfall ne rend que ce qu'on lui demande — mais si le
  /// contrat change ou qu'un bug d'appariement survient, mieux vaut la
  /// nommer que la faire grossir silencieusement [EditionResolution.resolved].
  String _describeUnexpectedCard(Map<String, dynamic> cardJson) {
    final id = cardJson['id'] ?? '?';
    final set = cardJson['set'] ?? '?';
    final collectorNumber = cardJson['collector_number'] ?? '?';
    final name = cardJson['name'] ?? '?';
    return 'carte rendue sans requete correspondante restante dans le lot : '
        'id=$id, set=$set, collector_number=$collectorNumber, name=$name';
  }

  /// Temps 2 : recupere la traduction d'un tirage, ou null s'il n'en existe pas.
  Future<ResolvedPrint?> resolveTranslation({
    required String scryfallId,
    required String oracleId,
    required String setCode,
    required String collectorNumber,
    required String lang,
  }) async {
    if (await _db.isTranslationAbsent(oracleId, lang)) return null;

    final cached = await _db.findTranslation(oracleId, lang);
    if (cached != null) return _fromRow(cached);

    try {
      final data = await _api.getCardBySetAndNumber(setCode, collectorNumber, lang: lang);
      final print = ResolvedPrint.fromJson(data);
      await _cache(print);
      return print;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Pas de traduction dans cette langue : c'est une reponse, pas une panne.
        await _db.markTranslationAbsent(oracleId, lang);
        return null;
      }
      rethrow;
    }
  }

  Map<String, dynamic> _toIdentifier(PrintRequest request) {
    if (request.scryfallId != null) return {'id': request.scryfallId};
    if (request.setCode != null && request.collectorNumber != null) {
      return {'set': request.setCode!.toLowerCase(), 'collector_number': request.collectorNumber};
    }
    return {'name': request.name};
  }

  Future<ResolvedPrint?> _fromCache(PrintRequest request) async {
    if (request.scryfallId == null) return null;
    final row = await _db.getCardPrint(request.scryfallId!);
    return row == null ? null : _fromRow(row);
  }

  /// Retrouve, parmi les indices non encore attribues de [unassigned],
  /// celui dont l'identifiant envoye correspond a [candidate] — une carte
  /// rendue dans `data` (superset de champs) ou une entree `not_found`
  /// (identique a l'identifiant envoye) — le retire de la liste de travail
  /// et renvoie son index dans le lot. Par consommation, pas par recherche :
  /// une fois un index retire, il ne peut plus etre attribue a une autre
  /// carte ou entree `not_found`, ce qui empeche deux requetes de meme
  /// identifiant structurel de s'ecraser l'une l'autre. Renvoie `null` si
  /// aucun index disponible ne correspond (la requete reste alors dans
  /// [unassigned] et rejoindra `notFound` en fin de lot).
  int? _consumeMatch(
    List<int> unassigned,
    List<Map<String, dynamic>> identifiers,
    Map<String, dynamic> candidate,
  ) {
    for (var i = 0; i < unassigned.length; i++) {
      final index = unassigned[i];
      if (_identifierMatches(identifiers[index], candidate)) {
        unassigned.removeAt(i);
        return index;
      }
    }
    return null;
  }

  /// Vrai si toutes les cles de [identifier] (l'identifiant envoye a
  /// Scryfall) sont presentes avec la meme valeur dans [candidate]. Une
  /// comparaison en sous-ensemble, pas en egalite stricte de maps : une
  /// entree `not_found` echoue l'identifiant a l'identique, mais une carte
  /// rendue dans `data` porte des champs supplementaires (id, oracle_id,
  /// name, lang...) en plus de ceux de l'identifiant envoye.
  bool _identifierMatches(
    Map<String, dynamic> identifier,
    Map<String, dynamic> candidate,
  ) {
    for (final entry in identifier.entries) {
      if (candidate[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// [DbCardPrint.oracleName] porte le nom oracle (anglais), stable a travers
  /// les traductions. [DbCardPrint.printedName] porte le nom localise de CE
  /// tirage precis, et reste nul quand il n'y en a pas (cas anglais) — jamais
  /// de repli sur l'un ou l'autre, sous peine de confondre les deux champs.
  ResolvedPrint _fromRow(DbCardPrint row) => ResolvedPrint(
        scryfallId: row.scryfallId,
        oracleId: row.oracleId,
        setCode: row.setCode,
        collectorNumber: row.collectorNumber,
        lang: row.lang,
        name: row.oracleName,
        printedName: row.printedName,
        printedText: row.printedText,
        imageUri: row.imageUri,
        colorIdentity: AppDatabase.decodeTags(row.colorIdentity),
      );

  Future<void> _cache(ResolvedPrint print) => _db.upsertCardPrint(DbCardPrint(
        scryfallId: print.scryfallId,
        oracleId: print.oracleId,
        setCode: print.setCode,
        collectorNumber: print.collectorNumber,
        lang: print.lang,
        oracleName: print.name,
        printedName: print.printedName,
        printedText: print.printedText,
        imageUri: print.imageUri,
        colorIdentity: json.encode(print.colorIdentity),
        fetchedAt: DateTime.now(),
      ));
}
