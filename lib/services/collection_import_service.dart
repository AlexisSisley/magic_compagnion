// Import d'une collection Moxfield deja lue par MoxfieldCollectionParser.
//
// Fusion par tirage : la cle est (scryfallId, isFoil), la quantite du fichier
// REMPLACE celle de l'app, et rien n'est jamais supprime. Ecrire une quantite
// absolue rend l'import idempotent -- reimporter le meme fichier par doute est
// le geste naturel, il ne doit pas doubler la collection.
//
// Toute ligne du fichier est comptee exactement une fois : importee ou non
// identifiee (les lignes illisibles, elles, sont deja comptees par le
// parser et simplement reportees ici). C'est la regle 4 de la spec, et
// l'assertion centrale de la suite de tests :
//   imported + notIdentified + unreadableLines.length == linesRead
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

    // Temps 1a : entrees porteuses d'une identite de tirage complete --
    // resolues par edition et numero de collection exacts.
    final avecIdentite = parsed.entries.where((e) => e.hasIdentity).toList();
    final editionRes = await _resolver.resolveEditions(
      avecIdentite
          .map((e) => PrintRequest(
                name: e.name,
                setCode: e.setCode,
                collectorNumber: e.collectorNumber,
              ))
          .toList(),
    );
    final parEdition = <String, ResolvedPrint>{};
    for (final p in editionRes.resolved) {
      parEdition['${p.setCode.toLowerCase()}|${p.collectorNumber}'] = p;
    }

    // Temps 1b : entrees sans identite -- deja resolues par leur nom seul,
    // ici meme. Les rejouer au Temps 2 leur ferait subir une seconde
    // requete pour un resultat necessairement identique.
    final sansIdentite = parsed.entries.where((e) => !e.hasIdentity).toList();
    final nomRes = await _resolver.resolveEditions(
      sansIdentite.map((e) => PrintRequest(name: e.name)).toList(),
    );

    // Temps 2 : seules les entrees qui AVAIENT une identite mais dont la
    // resolution exacte a echoue repassent par leur nom -- celles qui n'en
    // avaient pas l'ont deja tente au Temps 1b, ci-dessus.
    final identiteEchouee =
        avecIdentite.where((e) => _parEdition(e, parEdition) == null).toList();
    final secoursRes = identiteEchouee.isEmpty
        ? null
        : await _resolver.resolveEditions(
            identiteEchouee.map((e) => PrintRequest(name: e.name)).toList(),
          );

    // File de repli par nom, consommee une entree a la fois -- jamais un
    // lookup dans une map partagee. Deux lignes de meme nom mais d'edition
    // differente (l'une resolue exactement, l'autre non) ne doivent JAMAIS
    // recevoir le meme tirage par accident : ce tableau ne contient que des
    // tirages obtenus PAR NOM SEUL (Temps 1b + Temps 2), jamais un tirage
    // resolu par edition exacte (Temps 1a) -- sous peine qu'une ligne en
    // echec de resolution herite silencieusement du tirage exact d'une
    // AUTRE ligne, et ecrase sa quantite a l'ecriture (meme scryfallId,
    // meme cle de fusion).
    final parNom = <String, List<ResolvedPrint>>{};
    for (final p in nomRes.resolved) {
      (parNom[p.name.toLowerCase()] ??= []).add(p);
    }
    if (secoursRes != null) {
      for (final p in secoursRes.resolved) {
        (parNom[p.name.toLowerCase()] ??= []).add(p);
      }
    }

    ResolvedPrint? repli(String name) {
      final file = parNom[name.toLowerCase()];
      if (file == null || file.isEmpty) return null;
      return file.removeAt(0);
    }

    int imported = 0, added = 0, updated = 0, tagged = 0, notIdentified = 0;
    final tagues = <String>[];
    final nonIdentifiees = <String>[];

    for (final e in parsed.entries) {
      final exact = _parEdition(e, parEdition);
      final tirage = exact ?? repli(e.name);
      if (tirage == null) {
        notIdentified++;
        nonIdentifiees.add(e.name);
        continue;
      }

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
      notIdentified: notIdentified,
      unreadableLines: parsed.unreadableLines,
      taggedNames: tagues,
      notIdentifiedNames: nonIdentifiees,
    );
  }

  ResolvedPrint? _parEdition(CollectionEntry e, Map<String, ResolvedPrint> index) {
    if (!e.hasIdentity) return null;
    return index['${e.setCode!.toLowerCase()}|${e.collectorNumber}'];
  }
}
