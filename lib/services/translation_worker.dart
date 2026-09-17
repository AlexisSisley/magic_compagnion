// Vide la file de traduction en tache de fond.
// L'import rend la main des le temps 1 ; ce worker fait le temps 2.
//
// Voir docs/superpowers/specs/2026-09-17-identite-tirage-langue-design.md

import 'dart:developer';

import '../data/database/app_database.dart';
import 'card_resolver.dart';

class TranslationWorker {
  final CardResolver _resolver;
  final AppDatabase _db;
  bool _running = false;

  TranslationWorker({required CardResolver resolver, required AppDatabase db})
      : _resolver = resolver,
        _db = db;

  /// Vide la file, par passes de [batchSize] taches, jusqu'a ce qu'il n'y ait
  /// plus rien de pret. Rend le nombre de taches retirees de la file.
  /// Un seul drain a la fois : un second appel concurrent rend 0 immediatement.
  ///
  /// Pourquoi une boucle et pas une seule passe : une collection de 3000
  /// cartes produit 3000 taches. Une passe unique plafonnee a 50 obligerait
  /// l'utilisateur a relancer le drain a la main des dizaines de fois, et la
  /// file ne convergerait jamais.
  ///
  /// Deux protections rendent cette boucle sure :
  /// - toute tache en echec est REPOUSSEE en base (backoff exponentiel via
  ///   [AppDatabase.failTranslationTask]) avant de passer a la suivante,
  ///   panne de lecture du tirage possede comprise -- sans cela, une tache
  ///   qui reste en file sans backoff serait relue a chaque passe et la
  ///   boucle tournerait a vide indefiniment (defaut mineur tant que le
  ///   drain etait declenche par evenement, boucle serree des qu'il boucle) ;
  /// - les identifiants deja traverses par CE drain sont memorises : une
  ///   tache qu'une passe n'a reussi ni a clore ni a repousser (panne base
  ///   sur l'ecriture du backoff elle-meme) arrete la boucle au lieu d'etre
  ///   rejouee sans fin. C'est la ceinture en plus des bretelles : aucune
  ///   panne base, ou qu'elle survienne, ne peut transformer ce drain en
  ///   boucle serree.
  ///
  /// Aucun acces base n'est laisse a decouvert : une panne se consigne (via
  /// `log`, comme pour une traduction reportee) et le drain rend ce qu'il a
  /// pu accomplir plutot que de lever. Une panne sur une tache ne condamne
  /// pas les suivantes de la meme passe.
  Future<int> drain({int batchSize = 50}) async {
    if (_running) return 0;
    _running = true;
    int completed = 0;
    final seen = <int>{};

    try {
      while (true) {
        List<DbTranslationTask> tasks;
        try {
          tasks = await _db.nextTranslationTasks(limit: batchSize);
        } catch (e) {
          // Rien a traiter si on ne peut meme pas lire la file.
          log('Lecture de la file de traduction impossible: $e',
              name: 'TranslationWorker');
          break;
        }

        if (tasks.isEmpty) break;

        // Toute tache deja traversee par ce drain et toujours prete n'a ete
        // ni close ni repoussee : la rejouer boucterait sans fin.
        final fresh = tasks.where((t) => seen.add(t.id)).toList();
        if (fresh.isEmpty) break;

        for (final task in fresh) {
          DbCardPrint? owned;
          try {
            owned = await _db.getCardPrint(task.scryfallId);
          } catch (e) {
            // Panne isolee a cette tache : on la repousse (backoff) pour
            // qu'elle ne revienne pas immediatement dans la passe suivante,
            // puis on passe a la suivante de la passe.
            log('Lecture du tirage possede impossible (${task.scryfallId}): $e',
                name: 'TranslationWorker');
            await _deferTask(task.id, e);
            continue;
          }

          if (owned == null) {
            // Le tirage possede n'est plus en cache : la tache n'a plus d'objet.
            try {
              await _db.completeTranslationTask(task.id);
              completed++;
            } catch (e) {
              log('Cloture de la tache orpheline impossible (${task.id}): $e',
                  name: 'TranslationWorker');
            }
            continue;
          }

          try {
            await _resolver.resolveTranslation(
              scryfallId: owned.scryfallId,
              oracleId: owned.oracleId,
              setCode: task.setCode,
              collectorNumber: task.collectorNumber,
              lang: task.lang,
            );
            // 200 comme 404 sont des reponses : la tache est finie dans les
            // deux cas.
            await _db.completeTranslationTask(task.id);
            completed++;
          } catch (e) {
            log('Traduction reportee (${task.scryfallId}/${task.lang}): $e',
                name: 'TranslationWorker');
            await _deferTask(task.id, e);
          }
        }
      }
    } finally {
      _running = false;
    }

    return completed;
  }

  /// Repousse une tache (backoff exponentiel) sans jamais lever : l'echec de
  /// l'ecriture du backoff lui-meme ne doit pas interrompre la passe.
  Future<void> _deferTask(int id, Object cause) async {
    try {
      await _db.failTranslationTask(id, cause.toString());
    } catch (e) {
      log('Enregistrement de l\'echec impossible ($id): $e',
          name: 'TranslationWorker');
    }
  }
}
