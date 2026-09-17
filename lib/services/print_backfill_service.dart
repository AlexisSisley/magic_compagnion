// Reprise de l'existant : met en cache le tirage de chaque carte deja stockee,
// pour que la projection d'affichage dispose d'un oracleId.
//
// Ne modifie AUCUNE ligne de deck ni de collection : le scryfallId possede est
// la verite, et ce service ne fait que remplir le cache a cote.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import '../data/database/app_database.dart';
import '../models/card_print.dart';
import 'card_resolver.dart';

class PrintBackfillService {
  /// Cle AppSettings memorisant que la reprise a deja aboutit une fois.
  /// Posee uniquement quand la resolution est COMPLETE (voir [runOnce]) :
  /// [CardResolver.resolveEditions] ne leve jamais sur une panne de lot --
  /// un lot en echec ou une carte introuvable se consignent respectivement
  /// dans `failed` et `notFound` plutot que de faire remonter une exception.
  /// Se fier a la seule absence d'exception poserait donc le drapeau meme
  /// quand rien n'a ete resolu (ex. reseau absent au premier lancement), ce
  /// qui perdrait la reprise pour toujours pour l'utilisateur concerne.
  static const String backfillCompletedSettingKey = 'print_backfill_completed';

  final AppDatabase _db;
  final CardResolver _resolver;

  PrintBackfillService({required AppDatabase db, required CardResolver resolver})
      : _db = db,
        _resolver = resolver;

  /// Lance la reprise une seule fois au total, memorisee via [AppSettings]
  /// (drapeau [backfillCompletedSettingKey]).
  ///
  /// Pensee pour etre appelee sans `await` au demarrage (voir `main.dart`) :
  /// - le drapeau n'est pose que si la resolution est COMPLETE (rien dans
  ///   `failed`, rien dans `notFound`) -- une resolution partielle ou
  ///   totalement en echec laisse le drapeau absent, pour etre retentee au
  ///   prochain lancement plutot que perdue silencieusement ;
  /// - tout le corps de la methode est protege : une panne pendant la
  ///   lecture ou l'ecriture du drapeau lui-meme (base fermee/corrompue,
  ///   etc.), pas seulement pendant la resolution, ne doit jamais faire
  ///   echouer le demarrage de l'application (l'appel se fait `unawaited`
  ///   depuis `main.dart` : une exception non geree y deviendrait un rejet
  ///   de Future non capture).
  Future<void> runOnce() async {
    try {
      final alreadyDone = await _db.getSetting(backfillCompletedSettingKey);
      if (alreadyDone == 'true') return;

      final resolution = await _resolveEditionsForExisting();
      if (resolution.failed.isEmpty && resolution.notFound.isEmpty) {
        await _db.setSetting(backfillCompletedSettingKey, 'true');
      }
    } catch (_) {
      // Toute panne (reseau, lecture/ecriture du drapeau...) laisse le
      // drapeau absent expres : le prochain lancement retentera la reprise
      // plutot que de la considerer terminee a tort.
    }
  }

  /// Rend le nombre de tirages nouvellement mis en cache.
  Future<int> run() async {
    final resolution = await _resolveEditionsForExisting();
    return resolution.resolved.length;
  }

  /// Identifie les tirages manquants du cache parmi les cartes deja stockees
  /// (decks + collection) et delegue leur resolution a [CardResolver]. Seul
  /// point d'acces a la base et au resolveur partage par [run] et [runOnce],
  /// pour que les deux versions de la completude (nombre resolu vs
  /// resolution totale) soient calculees a partir du meme
  /// [EditionResolution].
  Future<EditionResolution> _resolveEditionsForExisting() async {
    final deckRows = await _db.select(_db.deckCards).get();
    final collectionRows = await _db.select(_db.collectionCards).get();

    final ids = <String, String>{}; // scryfallId -> nom
    for (final row in deckRows) {
      ids[row.scryfallId] = row.name;
    }
    for (final row in collectionRows) {
      ids[row.scryfallId] = row.name;
    }

    final missing = <PrintRequest>[];
    for (final entry in ids.entries) {
      if (await _db.getCardPrint(entry.key) == null) {
        missing.add(PrintRequest(name: entry.value, scryfallId: entry.key));
      }
    }

    return _resolver.resolveEditions(missing);
  }
}
