import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/providers/card_display_provider.dart';

DbCardPrint _print({
  required String scryfallId,
  required String lang,
  String? printedName,
  String oracleId = 'oracle-thrill',
  String oracleName = 'Thrill of Possibility',
}) =>
    DbCardPrint(
      scryfallId: scryfallId,
      oracleId: oracleId,
      oracleName: oracleName,
      setCode: 'eld',
      collectorNumber: '146',
      lang: lang,
      printedName: printedName,
      printedText: null,
      imageUri: null,
      colorIdentity: '[]',
      fetchedAt: DateTime.utc(2026, 9, 17),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('la traduction en cache est projetee', () async {
    final owned = _print(
        scryfallId: 'en-id', lang: 'en', printedName: 'Thrill of Possibility');
    await db.upsertCardPrint(owned);
    await db.upsertCardPrint(_print(
        scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité'));

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Frisson de probabilité');
    expect(display.lang, 'fr');
    expect(display.isFallback, isFalse);
  });

  test(
      'sans traduction CONFIRMEE absente, on replie sur le tirage possede et '
      'on le signale', () async {
    final owned = _print(
        scryfallId: 'sld-en',
        lang: 'en',
        printedName: 'Dreadbore',
        oracleId: 'oracle-dreadbore',
        oracleName: 'Dreadbore');
    await db.upsertCardPrint(owned);
    // Scryfall a repondu 404 sur la route de traduction : l'absence est un
    // fait etabli, pas une hypothese.
    await db.markTranslationAbsent('oracle-dreadbore', 'fr');

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Dreadbore');
    expect(display.lang, 'en');
    expect(display.isFallback, isTrue);
  });

  test(
      'une traduction PAS ENCORE DEMANDEE ne pose aucun badge : le repli est '
      'silencieux', () async {
    // C'est la premiere chose que l'utilisateur voit apres un import : tant
    // que la file de traduction n'a pas tourne, `findTranslation` rend null
    // pour TOUTES les cartes. Badger ce null afficherait "EN · pas de VF" sur
    // chaque ligne du deck, y compris les cartes qui ont une VF. Un badge qui
    // ment est pire que pas de badge.
    final owned = _print(
        scryfallId: 'sld-en',
        lang: 'en',
        printedName: 'Dreadbore',
        oracleId: 'oracle-dreadbore',
        oracleName: 'Dreadbore');
    await db.upsertCardPrint(owned);
    // Aucun markTranslationAbsent : on n'a simplement pas encore demande.

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Dreadbore');
    expect(display.lang, 'en');
    expect(
      display.isFallback,
      isFalse,
      reason: 'l\'absence n\'est pas etablie : repli silencieux, sans badge',
    );
  });

  test('un tirage deja dans la langue voulue n est pas un repli', () async {
    final owned = _print(
        scryfallId: 'fr-id', lang: 'fr', printedName: 'Frisson de probabilité');
    await db.upsertCardPrint(owned);

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'fr');

    expect(display.name, 'Frisson de probabilité');
    expect(display.isFallback, isFalse);
  });

  test(
      'un tirage anglais sans printedName s affiche sous son oracleName, jamais une chaine vide',
      () async {
    final owned = _print(
      scryfallId: 'en-null-id',
      lang: 'en',
      printedName: null,
      oracleId: 'oracle-no-printed-name',
      oracleName: 'Dreadbore',
    );
    await db.upsertCardPrint(owned);

    final display =
        await resolveDisplay(db: db, owned: owned, preferredLang: 'en');

    expect(display.name, 'Dreadbore');
    expect(display.name, isNot(isEmpty));
    expect(display.lang, 'en');
    expect(display.isFallback, isFalse);
  });
}
