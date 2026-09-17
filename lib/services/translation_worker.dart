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

  /// Traite les taches pretes. Rend le nombre de taches retirees de la file.
  /// Un seul drain a la fois : un second appel concurrent rend 0 immediatement.
  ///
  /// Aucun acces base n'est laisse a decouvert : une panne se consigne (via
  /// `log`, comme pour une traduction reportee) et le drain rend ce qu'il a
  /// pu accomplir plutot que de lever. Une panne sur une tache ne condamne
  /// pas les suivantes de la meme passe.
  Future<int> drain({int maxTasks = 50}) async {
    if (_running) return 0;
    _running = true;
    int completed = 0;

    try {
      List<DbTranslationTask> tasks;
      try {
        tasks = await _db.nextTranslationTasks(limit: maxTasks);
      } catch (e) {
        // Rien a traiter si on ne peut meme pas lire la file.
        log('Lecture de la file de traduction impossible: $e',
            name: 'TranslationWorker');
        return 0;
      }

      for (final task in tasks) {
        DbCardPrint? owned;
        try {
          owned = await _db.getCardPrint(task.scryfallId);
        } catch (e) {
          // Panne isolee a cette tache : on passe a la suivante de la passe.
          log('Lecture du tirage possede impossible (${task.scryfallId}): $e',
              name: 'TranslationWorker');
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
          // 200 comme 404 sont des reponses : la tache est finie dans les deux cas.
          await _db.completeTranslationTask(task.id);
          completed++;
        } catch (e) {
          log('Traduction reportee (${task.scryfallId}/${task.lang}): $e',
              name: 'TranslationWorker');
          try {
            await _db.failTranslationTask(task.id, e.toString());
          } catch (e2) {
            log('Enregistrement de l\'echec impossible (${task.id}): $e2',
                name: 'TranslationWorker');
          }
        }
      }
    } finally {
      _running = false;
    }

    return completed;
  }
}
