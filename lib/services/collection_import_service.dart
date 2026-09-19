// Import d'une collection Moxfield deja lue par MoxfieldCollectionParser.
//
// Fusion par tirage : la cle est (scryfallId, isFoil), la quantite du fichier
// REMPLACE celle de l'app, et rien n'est jamais supprime. Ecrire une quantite
// absolue rend l'import idempotent -- reimporter le meme fichier par doute est
// le geste naturel, il ne doit pas doubler la collection.
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import '../models/moxfield_import.dart';
import 'card_resolver.dart';

class CollectionImportService {
  final AppDatabase _db;
  final CardResolver _resolver;

  CollectionImportService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  Future<CollectionImportResult> import(
    CollectionParseResult parsed, {
    required String preferredLang,
  }) async {
    if (parsed.entries.isEmpty) {
      return CollectionImportResult(unreadableLines: parsed.unreadableLines);
    }

    // Temps 1 : resoudre par edition quand on l'a.
    final requetes = parsed.entries
        .map((e) => PrintRequest(
              name: e.name,
              setCode: e.setCode,
              collectorNumber: e.collectorNumber,
            ))
        .toList();
    final resolution = await _resolver.resolveEditions(requetes);

    // Index des tirages resolus par (set, cn) puis par nom, pour rattacher
    // chaque entree du fichier a son tirage.
    final parEdition = <String, ResolvedPrint>{};
    final parNom = <String, ResolvedPrint>{};
    for (final p in resolution.resolved) {
      parEdition['${p.setCode.toLowerCase()}|${p.collectorNumber}'] = p;
      parNom.putIfAbsent(p.name.toLowerCase(), () => p);
    }

    // Temps 2 : les entrees non resolues repassent par leur nom seul.
    final nonResolues = <CollectionEntry>[];
    for (final e in parsed.entries) {
      if (_tirage(e, parEdition, parNom) == null) nonResolues.add(e);
    }
    if (nonResolues.isNotEmpty) {
      final secours = await _resolver.resolveEditions(
        nonResolues.map((e) => PrintRequest(name: e.name)).toList(),
      );
      for (final p in secours.resolved) {
        parNom.putIfAbsent(p.name.toLowerCase(), () => p);
      }
    }

    int imported = 0, added = 0, updated = 0, tagged = 0;
    final tagues = <String>[];

    for (final e in parsed.entries) {
      final exact = _parEdition(e, parEdition);
      final tirage = exact ?? parNom[e.name.toLowerCase()];
      if (tirage == null) continue;

      final existant = await _db.getCollectionCard(tirage.scryfallId, e.isFoil);
      if (existant == null) {
        added++;
      } else {
        updated++;
      }

      await _db.upsertCollectionCard(
        scryfallId: tirage.scryfallId,
        cardName: tirage.name,
        absoluteQuantity: e.quantity,
        isFoil: e.isFoil,
        newTags: exact == null ? const [kNeedsCheckTag] : null,
      );
      imported++;

      if (exact == null) {
        tagged++;
        tagues.add(e.name);
      }

      if (tirage.lang != preferredLang) {
        await _db.enqueueTranslation(
          scryfallId: tirage.scryfallId,
          setCode: tirage.setCode,
          collectorNumber: tirage.collectorNumber,
          lang: preferredLang,
        );
      }
    }

    return CollectionImportResult(
      imported: imported,
      added: added,
      updated: updated,
      tagged: tagged,
      unreadableLines: parsed.unreadableLines,
      taggedNames: tagues,
    );
  }

  ResolvedPrint? _parEdition(CollectionEntry e, Map<String, ResolvedPrint> index) {
    if (e.setCode == null || e.collectorNumber == null) return null;
    return index['${e.setCode!.toLowerCase()}|${e.collectorNumber}'];
  }

  ResolvedPrint? _tirage(
    CollectionEntry e,
    Map<String, ResolvedPrint> parEdition,
    Map<String, ResolvedPrint> parNom,
  ) =>
      _parEdition(e, parEdition) ?? parNom[e.name.toLowerCase()];
}
