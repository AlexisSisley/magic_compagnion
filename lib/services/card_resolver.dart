// Point de passage unique de toute resolution de carte.
//
// Deux temps, imposes par l'API Scryfall :
//   1. POST /cards/collection fixe l'edition (il IGNORE le parametre lang)
//   2. GET /cards/{set}/{cn}/{lang} rend la traduction, qui a son propre id
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

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
  Future<List<ResolvedPrint>> resolveEditions(List<PrintRequest> requests) async {
    final List<ResolvedPrint> resolved = [];
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

      try {
        final data = await _api.fetchCollection(identifiers);
        final List<dynamic> found = data['data'] ?? [];
        for (final json in found) {
          final print = ResolvedPrint.fromJson(json as Map<String, dynamic>);
          await _cache(print);
          resolved.add(print);
        }
      } on DioException {
        // Lot injoignable : les cartes restent non resolues, l'appelant decide.
      }
    }

    return resolved;
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

  ResolvedPrint _fromRow(DbCardPrint row) => ResolvedPrint(
        scryfallId: row.scryfallId,
        oracleId: row.oracleId,
        setCode: row.setCode,
        collectorNumber: row.collectorNumber,
        lang: row.lang,
        name: row.printedName ?? '',
        printedName: row.printedName,
        printedText: row.printedText,
        imageUri: row.imageUri,
      );

  Future<void> _cache(ResolvedPrint print) => _db.upsertCardPrint(DbCardPrint(
        scryfallId: print.scryfallId,
        oracleId: print.oracleId,
        setCode: print.setCode,
        collectorNumber: print.collectorNumber,
        lang: print.lang,
        printedName: print.printedName ?? print.name,
        printedText: print.printedText,
        imageUri: print.imageUri,
        fetchedAt: DateTime.now(),
      ));
}
