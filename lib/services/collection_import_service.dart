// Import d'une collection Moxfield deja lue par MoxfieldCollectionParser.
//
// Fusion par tirage : la cle est (scryfallId, isFoil), la quantite du fichier
// REMPLACE celle de l'app, et rien n'est jamais supprime. Ecrire une quantite
// absolue rend l'import idempotent -- reimporter le meme fichier par doute est
// le geste naturel, il ne doit pas doubler la collection.
//
// Plusieurs lignes DISTINCTES du fichier peuvent retomber sur le meme tirage :
// deux lignes de meme nom en mode degrade (un Sol Ring possede en LTC et un
// autre en M19, sans colonne d'edition), ou deux lignes de meme set+numero
// dans des langues differentes (POST /cards/collection ignore la langue).
// Leurs quantites sont donc SOMMEES et le tirage n'est ecrit qu'une fois : une
// ecriture par ligne ferait ecraser 3 par 2 au lieu d'ecrire 5.
//
// Les tags ne sont jamais remplaces : les tags utilisateur d'une carte deja en
// collection (« a echanger », « deck Atraxa ») survivent a l'import. Seul le
// tag systeme kNeedsCheckTag est ajoute (ligne resolue par son nom seul) ou
// retire (ligne redevenue resolue exactement).
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

    // Ecritures agregees par (scryfallId, isFoil), dans l'ordre du fichier.
    final parTirage = <String, _Ecriture>{};

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
          // Une ligne avec identite peut avoir ete tentee jusqu'a deux fois
          // (edition exacte au Temps 1a, puis repli par nom au Temps 2) --
          // le OU ci-dessous est volontaire : IL SUFFIT QU'UNE SEULE de ces
          // tentatives ait subi une panne reseau pour classer la ligne en
          // transitoire, MEME SI L'AUTRE a recu un not_found propre de
          // Scryfall. On ne peut pas garantir que ce not_found aurait ete
          // le meme sans la panne (une edition introuvable a cause d'une
          // panne aurait peut-etre ete trouvee par nom, et inversement) ; se
          // fier a la seule tentative qui a repondu ferait passer pour
          // definitive une absence qu'on n'a en verite jamais pu confirmer
          // sur les deux voies. Mieux vaut donc, dans le doute, inviter a
          // reessayer plutot que d'affirmer a tort qu'une carte n'existe
          // pas.
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

      // La ligne est comptee ici, mais rien n'est ecrit encore : plusieurs
      // lignes peuvent viser le meme tirage, et c'est la SOMME de leurs
      // quantites qui doit atterrir en base (voir l'entete du fichier).
      imported++;
      final cle = '${tirage.scryfallId}|${e.isFoil}';
      final deja = parTirage[cle];
      if (deja == null) {
        parTirage[cle] = _Ecriture(
          tirage: tirage,
          isFoil: e.isFoil,
          quantite: e.quantity,
          exact: exact != null,
          nom: e.name,
        );
      } else {
        deja.quantite += e.quantity;
        // Il suffit qu'UNE des lignes fusionnees ait ete resolue par son nom
        // seul pour que le tirage retenu reste incertain : le tag est pose.
        if (exact == null) deja.exact = false;
      }
    }

    // Une seule ecriture par tirage : added/updated comptent des lignes de
    // collection, pas des lignes de fichier (imported, lui, reste par ligne --
    // c'est l'invariant de somme de la regle 4).
    for (final w in parTirage.values) {
      final existant = await _db.getCollectionCard(w.tirage.scryfallId, w.isFoil);
      if (existant == null) {
        added++;
      } else {
        updated++;
      }

      // Fusion des tags, jamais remplacement : `upsertCollectionCard` ecrase
      // les tags existants quand `newTags` est non nul (convention de
      // card_list_upsert_mixin.dart). On relit donc les tags de la carte et
      // on n'y touche que pour poser ou retirer le tag systeme.
      final tags = existant == null
          ? <String>[]
          : AppDatabase.decodeTags(existant.tags).toList();
      if (w.exact) {
        tags.remove(kNeedsCheckTag);
      } else if (!tags.contains(kNeedsCheckTag)) {
        tags.add(kNeedsCheckTag);
      }

      await _db.upsertCollectionCard(
        scryfallId: w.tirage.scryfallId,
        cardName: w.tirage.name,
        absoluteQuantity: w.quantite,
        isFoil: w.isFoil,
        newTags: tags,
      );

      if (!w.exact) {
        tagged++;
        tagues.add(w.nom);
      }

      if (w.tirage.lang != preferredLang) {
        await _db.enqueueTranslation(
          scryfallId: w.tirage.scryfallId,
          setCode: w.tirage.setCode,
          collectorNumber: w.tirage.collectorNumber,
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

/// Une ecriture de collection en preparation : le tirage retenu, la somme des
/// quantites des lignes du fichier qui y retombent, et si TOUTES ces lignes
/// ont ete resolues par leur edition exacte.
class _Ecriture {
  final ResolvedPrint tirage;
  final bool isFoil;
  final String nom;
  int quantite;
  bool exact;

  _Ecriture({
    required this.tirage,
    required this.isFoil,
    required this.nom,
    required this.quantite,
    required this.exact,
  });
}
