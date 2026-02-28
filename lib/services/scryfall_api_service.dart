// Fichier : lib/services/scryfall_api_service.dart
// Client HTTP centralisé pour l'API Scryfall via Dio (Sprint 5)
// Intercepteurs : cache mémoire, rate limiting, logging

import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';

/// Service centralisé pour tous les appels HTTP vers Scryfall.
/// Remplace les appels directs `http.get/post` éparpillés dans le code.
///
/// Fonctionnalités :
/// - Cache mémoire avec TTL configurable
/// - Rate limiting (max 10 req/sec, conforme aux guidelines Scryfall)
/// - Logging structuré de chaque requête
/// - Headers User-Agent automatiques
/// - Gestion d'erreurs unifiée
class ScryfallApiService {
  static const String baseUrl = 'https://api.scryfall.com';
  static const String setsUrl = '$baseUrl/sets';
  static const String cardsSearchUrl = '$baseUrl/cards/search';
  static const String cardsCollectionUrl = '$baseUrl/cards/collection';

  static const Duration defaultCacheTtl = Duration(minutes: 10);
  static const Duration longCacheTtl = Duration(hours: 24);
  static const int maxRequestsPerSecond = 10;

  final Dio _dio;
  final Map<String, _CacheEntry> _cache = {};
  final List<DateTime> _requestTimestamps = [];

  ScryfallApiService({Dio? dio}) : _dio = dio ?? _createDefaultDio();

  static Dio _createDefaultDio() {
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'MagicCompanion/1.0',
        'Accept': 'application/json',
      },
    ));
  }

  /// Expose le Dio interne (pour les tests ou usage avancé)
  Dio get dio => _dio;

  // ============================================================
  // API PUBLIQUE - SEARCH
  // ============================================================

  /// Recherche de cartes par query string.
  /// Retourne le JSON brut de Scryfall (avec `data`, `has_more`, `next_page`).
  Future<Map<String, dynamic>> searchCards(
    String query, {
    String? lang,
    String? unique,
    String? order,
    String? dir,
  }) async {
    final params = <String, String>{
      'q': query,
      if (lang != null) 'lang': lang,
      if (unique != null) 'unique': unique,
      if (order != null) 'order': order,
      if (dir != null) 'dir': dir,
    };

    return _get('/cards/search', queryParameters: params, cacheTtl: defaultCacheTtl);
  }

  /// Charge la page suivante d'une recherche paginée.
  /// `nextPageUrl` est l'URL complète retournée par Scryfall dans `next_page`.
  Future<Map<String, dynamic>> fetchNextPage(String nextPageUrl) async {
    return _getAbsoluteUrl(nextPageUrl, cacheTtl: defaultCacheTtl);
  }

  // ============================================================
  // API PUBLIQUE - CARDS
  // ============================================================

  /// Récupère une carte par set code et collector number.
  Future<Map<String, dynamic>> getCardBySetAndNumber(String setCode, String collectorNumber) async {
    return _get('/cards/$setCode/$collectorNumber', cacheTtl: longCacheTtl);
  }

  /// Recherche de cartes par nom (pour auto-complete ou recherche simple).
  Future<Map<String, dynamic>> searchCardsByName(String name, {String? unique}) async {
    return searchCards(name, unique: unique);
  }

  /// Récupère les rulings d'une carte par son ID Scryfall.
  Future<Map<String, dynamic>> getCardRulings(String cardId) async {
    return _get('/cards/$cardId/rulings', cacheTtl: longCacheTtl);
  }

  /// Récupère les prints (versions) d'une carte via son prints_search_uri.
  Future<Map<String, dynamic>> getCardPrints(String printsSearchUri) async {
    return _getAbsoluteUrl(printsSearchUri, cacheTtl: longCacheTtl);
  }

  // ============================================================
  // API PUBLIQUE - COLLECTION (batch)
  // ============================================================

  /// Envoie une requête batch POST pour récupérer plusieurs cartes.
  /// `identifiers` est une liste de maps (ex: [{'name': 'Lightning Bolt'}]).
  /// Pas de cache pour les requêtes POST.
  Future<Map<String, dynamic>> fetchCollection(List<Map<String, dynamic>> identifiers) async {
    await _enforceRateLimit();

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post(
        '$baseUrl/cards/collection',
        data: {'identifiers': identifiers},
      );
      stopwatch.stop();

      log(
        'POST /cards/collection (${identifiers.length} ids) → ${response.statusCode} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      stopwatch.stop();
      log(
        'POST /cards/collection FAILED: ${e.message} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
        level: 900,
      );
      rethrow;
    }
  }

  // ============================================================
  // API PUBLIQUE - SETS
  // ============================================================

  /// Récupère tous les sets. Cache long (24h) car les sets changent rarement.
  Future<Map<String, dynamic>> getAllSets() async {
    return _get('/sets', cacheTtl: longCacheTtl);
  }

  // ============================================================
  // CACHE
  // ============================================================

  /// Invalide tout le cache.
  void clearCache() {
    _cache.clear();
    log('Cache cleared', name: 'ScryfallApi');
  }

  /// Invalide les entrées de cache correspondant au pattern.
  void invalidateCache(String pattern) {
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  /// Nombre d'entrées en cache (pour debug/tests).
  int get cacheSize => _cache.length;

  // ============================================================
  // INTERNALS
  // ============================================================

  /// GET avec path relatif au baseUrl.
  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? queryParameters,
    Duration cacheTtl = defaultCacheTtl,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    final cacheKey = uri.toString();

    // Check cache
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      log('CACHE HIT: $path [${cached.age.inSeconds}s old]', name: 'ScryfallApi');
      return cached.data;
    }

    await _enforceRateLimit();

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.getUri(uri);
      stopwatch.stop();

      log(
        'GET $path → ${response.statusCode} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
      );

      final data = response.data as Map<String, dynamic>;
      _cache[cacheKey] = _CacheEntry(data, cacheTtl);
      return data;
    } on DioException catch (e) {
      stopwatch.stop();
      log(
        'GET $path FAILED: ${e.message} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
        level: 900,
      );
      rethrow;
    }
  }

  /// GET avec URL absolue (pour les next_page de pagination et prints_search_uri).
  Future<Map<String, dynamic>> _getAbsoluteUrl(
    String absoluteUrl, {
    Duration cacheTtl = defaultCacheTtl,
  }) async {
    final cacheKey = absoluteUrl;

    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      log('CACHE HIT: ${Uri.parse(absoluteUrl).path} [${cached.age.inSeconds}s old]', name: 'ScryfallApi');
      return cached.data;
    }

    await _enforceRateLimit();

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get(absoluteUrl);
      stopwatch.stop();

      final path = Uri.parse(absoluteUrl).path;
      log(
        'GET $path → ${response.statusCode} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
      );

      final data = response.data as Map<String, dynamic>;
      _cache[cacheKey] = _CacheEntry(data, cacheTtl);
      return data;
    } on DioException catch (e) {
      stopwatch.stop();
      log(
        'GET ${Uri.parse(absoluteUrl).path} FAILED: ${e.message} [${stopwatch.elapsedMilliseconds}ms]',
        name: 'ScryfallApi',
        level: 900,
      );
      rethrow;
    }
  }

  /// Rate limiting : attend si nécessaire pour ne pas dépasser 10 req/sec.
  Future<void> _enforceRateLimit() async {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (ts) => now.difference(ts) > const Duration(seconds: 1),
    );

    if (_requestTimestamps.length >= maxRequestsPerSecond) {
      final oldest = _requestTimestamps.first;
      final waitTime = const Duration(seconds: 1) - now.difference(oldest);
      if (waitTime.inMilliseconds > 0) {
        log('Rate limit: waiting ${waitTime.inMilliseconds}ms', name: 'ScryfallApi');
        await Future.delayed(waitTime);
      }
    }

    _requestTimestamps.add(DateTime.now());
  }
}

/// Entrée de cache avec TTL.
class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final Duration ttl;

  _CacheEntry(this.data, this.ttl) : createdAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
  Duration get age => DateTime.now().difference(createdAt);
}
