// Client de l'API Moxfield pour l'import de deck par URL.
//
// ATTENTION -- decision assumee : les conditions d'utilisation de Moxfield
// (clause 5) interdisent l'acces automatise sans approbation ecrite. Le
// proprietaire du projet en a ete informe et a decide d'ajouter ce chemin.
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md, section
// "Le cadre juridique, et la decision prise".
//
// Consequence a tenir : l'import de collection par fichier ne doit JAMAIS
// dependre de ce client. Il est le chemin de repli si Moxfield ferme l'acces.

import 'package:dio/dio.dart';

enum MoxfieldError { malformedUrl, notPublic, accessDenied, transient }

class MoxfieldException implements Exception {
  final MoxfieldError kind;
  final String message;
  const MoxfieldException(this.kind, this.message);

  @override
  String toString() => message;
}

// Autorise ce qui suit l'identifiant (barre finale, sous-page comme /primer,
// paramètres de requête ?utm_..., fragment #primer) : un utilisateur copie
// souvent l'URL telle qu'affichée par son navigateur, UTM ou onglet inclus.
final RegExp _deckUrlRegex = RegExp(
    r'^https?://(?:www\.)?moxfield\.com/decks/([A-Za-z0-9_-]+)(?:[/?#].*)?$');

/// Extrait l'identifiant public d'une URL de deck Moxfield, ou null.
String? extractPublicId(String url) =>
    _deckUrlRegex.firstMatch(url.trim())?.group(1);

class MoxfieldDeckClient {
  static const String baseUrl = 'https://api2.moxfield.com';

  final Dio _dio;

  MoxfieldDeckClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': 'MagicCompanion/1.0',
                'Accept': 'application/json',
              },
            ));

  Future<Map<String, dynamic>> fetchDeck(String publicId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$baseUrl/v3/decks/all/$publicId',
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        throw const MoxfieldException(MoxfieldError.notPublic,
            'Deck introuvable. Vérifie que le deck est public sur Moxfield.');
      }
      if (code == 401 || code == 403) {
        throw const MoxfieldException(MoxfieldError.accessDenied,
            "Moxfield refuse l'accès. Utilise l'export du deck depuis leur site, "
            'puis colle le texte dans l’onglet « Coller du texte ».');
      }
      throw MoxfieldException(MoxfieldError.transient,
          'Moxfield est injoignable pour le moment (${code ?? 'réseau'}). Réessaie plus tard.');
    }
  }
}
