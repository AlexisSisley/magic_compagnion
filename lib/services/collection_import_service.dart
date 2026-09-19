// Import d'une collection Moxfield deja lue par MoxfieldCollectionParser.
//
// Fusion par tirage : la cle est (scryfallId, isFoil), la quantite du fichier
// REMPLACE celle de l'app, et rien n'est jamais supprime. Ecrire une quantite
// absolue rend l'import idempotent -- reimporter le meme fichier par doute est
// le geste naturel, il ne doit pas doubler la collection.
//
// Toute ligne du fichier est comptee exactement une fois : importee, non
// identifiee, en echec reseau transitoire, ou illisible (deja comptee par
// le parser et simplement reportee ici). C'est la regle 4 de la spec, et
// l'assertion centrale de la suite de tests :
//   imported + notIdentified + failedTransient + unreadableLines.length
//       == linesRead
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
    final editionReqs = avecIdentite
        .map((e) => PrintRequest(
              name: e.name,
              setCode: e.setCode,
              collectorNumber: e.collectorNumber,
            ))
        .toList();
    final editionRes = await _resolver.resolveEditions(editionReqs);
    final parEdition = <String, ResolvedPrint>{};
    for (final p in editionRes.resolved) {
      parEdition['${p.setCode.toLowerCase()}|${p.collectorNumber}'] = p;
    }

    // Temps 1b : entrees sans identite -- deja resolues par leur nom seul,
    // ici meme. Les rejouer au Temps 2 leur ferait subir une seconde
    // requete pour un resultat necessairement identique.
    final sansIdentite = parsed.entries.where((e) => !e.hasIdentity).toList();
    final nomReqs = sansIdentite.map((e) => PrintRequest(name: e.name)).toList();
    final nomRes = await _resolver.resolveEditions(nomReqs);

    // Temps 2 : seules les entrees qui AVAIENT une identite mais dont la
    // resolution exacte a echoue repassent par leur nom -- celles qui n'en
    // avaient pas l'ont deja tente au Temps 1b, ci-dessus. `indicesEchoues`
    // retient la position de chaque entree DANS `avecIdentite`/`editionReqs`,
    // pour pouvoir retrouver plus bas, requete par requete, si son echec
    // initial venait d'une panne reseau plutot que d'un not_found.
    final indicesEchoues = <int>[
      for (var i = 0; i < avecIdentite.length; i++)
        if (_parEdition(avecIdentite[i], parEdition) == null) i,
    ];
    final secoursReqs =
        indicesEchoues.map((i) => PrintRequest(name: avecIdentite[i].name)).toList();
    final secoursRes =
        secoursReqs.isEmpty ? null : await _resolver.resolveEditions(secoursReqs);
    // Position, dans `secoursReqs`, de la requete de repli pour l'entree
    // situee a tel index dans `avecIdentite` -- pour retrouver son eventuel
    // echec reseau au Temps 2.
    final secoursIndexPour = <int, int>{
      for (var k = 0; k < indicesEchoues.length; k++) indicesEchoues[k]: k,
    };

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

    int imported = 0, added = 0, updated = 0, tagged = 0;
    int notIdentified = 0, failedTransient = 0;
    final tagues = <String>[];
    final nonIdentifiees = <String>[];

    var iAvecIdentite = 0;
    var iSansIdentite = 0;

    for (final e in parsed.entries) {
      ResolvedPrint? exact;
      ResolvedPrint? tirage;
      // Vrai quand l'absence de tirage vient d'un lot reseau qui n'a pas
      // abouti (voir EditionResolution.failed), et non d'un not_found
      // confirme par Scryfall -- la distinction de la regle 5 : definitif
      // contre transitoire.
      var echecReseau = false;

      if (e.hasIdentity) {
        final i = iAvecIdentite++;
        exact = _parEdition(e, parEdition);
        tirage = exact ?? repli(e.name);
        if (tirage == null) {
          final k = secoursIndexPour[i];
          echecReseau = editionRes.failed.contains(editionReqs[i]) ||
              (k != null && secoursRes != null && secoursRes.failed.contains(secoursReqs[k]));
        }
      } else {
        final i = iSansIdentite++;
        tirage = repli(e.name);
        if (tirage == null) {
          echecReseau = nomRes.failed.contains(nomReqs[i]);
        }
      }

      if (tirage == null) {
        if (echecReseau) {
          failedTransient++;
        } else {
          notIdentified++;
          nonIdentifiees.add(e.name);
        }
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
      failedTransient: failedTransient,
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
