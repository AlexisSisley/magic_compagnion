// Projection d'affichage : le tirage possede reste la verite, la langue
// preferee n'est qu'une vue par-dessus.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import '../data/database/app_database.dart';

/// Ce qu'on montre a l'ecran pour une carte possedee.
class CardDisplay {
  final String name;
  final String lang;

  /// Vrai quand aucune traduction n'existe dans la langue preferee et qu'on
  /// affiche le tirage possede a la place. L'UI le signale par un badge ambre.
  final bool isFallback;

  const CardDisplay({
    required this.name,
    required this.lang,
    required this.isFallback,
  });
}

/// Le nom a afficher pour un tirage : le nom imprime quand il existe, sinon
/// le nom oracle (anglais, toujours renseigne). `printedName` est nul pour
/// les tirages anglais -- ce n'est jamais une chaine vide a afficher.
String _displayName(DbCardPrint print) => print.printedName ?? print.oracleName;

/// Projette un tirage possede dans la langue preferee, sans jamais le modifier.
Future<CardDisplay> resolveDisplay({
  required AppDatabase db,
  required DbCardPrint owned,
  required String preferredLang,
}) async {
  if (owned.lang == preferredLang) {
    return CardDisplay(
      name: _displayName(owned),
      lang: owned.lang,
      isFallback: false,
    );
  }

  final translated = await db.findTranslation(owned.oracleId, preferredLang);
  if (translated != null) {
    return CardDisplay(
      name: _displayName(translated),
      lang: translated.lang,
      isFallback: false,
    );
  }

  return CardDisplay(
    name: _displayName(owned),
    lang: owned.lang,
    isFallback: true,
  );
}
