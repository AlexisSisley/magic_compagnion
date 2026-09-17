// La langue preferee des cartes, et le backfill qu'un changement declenche.
//
// Portee du backfill : uniquement les cartes presentes dans un deck ou dans la
// collection. Traduire tout le cache couterait des milliers de requetes dont la
// plupart ne seraient jamais regardees.

import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';

const String kPreferredLanguageKey = 'glossaryLang';
const String kDefaultLanguage = 'fr';

/// Langue d'affichage des cartes. Partagee avec le glossaire.
Future<String> readPreferredLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(kPreferredLanguageKey) ?? kDefaultLanguage;
}

/// Enregistre la langue preferee, dans les preferences et dans son miroir en
/// base (que lit le service de sauvegarde).
Future<void> writePreferredLanguage(AppDatabase db, String lang) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPreferredLanguageKey, lang);
  await db.setSetting(kPreferredLanguageKey, lang);
}

/// Enfile les traductions manquantes des cartes possedees. Rend le nombre de
/// taches creees.
Future<int> enqueueOwnedCardsForLanguage({
  required AppDatabase db,
  required String lang,
}) async {
  final deckRows = await db.select(db.deckCards).get();
  final collectionRows = await db.select(db.collectionCards).get();

  final ownedIds = <String>{
    ...deckRows.map((r) => r.scryfallId),
    ...collectionRows.map((r) => r.scryfallId),
  };

  int queued = 0;
  for (final scryfallId in ownedIds) {
    final owned = await db.getCardPrint(scryfallId);
    if (owned == null) continue;
    if (owned.lang == lang) continue;
    if (await db.findTranslation(owned.oracleId, lang) != null) continue;
    if (await db.isTranslationAbsent(owned.oracleId, lang)) continue;

    await db.enqueueTranslation(
      scryfallId: owned.scryfallId,
      setCode: owned.setCode,
      collectorNumber: owned.collectorNumber,
      lang: lang,
    );
    queued++;
  }

  return queued;
}
