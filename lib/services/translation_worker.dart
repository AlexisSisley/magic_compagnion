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
  Future<int> drain({int maxTasks = 50}) async {
    if (_running) return 0;
    _running = true;
    int completed = 0;

    try {
      final tasks = await _db.nextTranslationTasks(limit: maxTasks);
      for (final task in tasks) {
        final owned = await _db.getCardPrint(task.scryfallId);
        if (owned == null) {
          // Le tirage possede n'est plus en cache : la tache n'a plus d'objet.
          await _db.completeTranslationTask(task.id);
          completed++;
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
          await _db.failTranslationTask(task.id, e.toString());
        }
      }
    } finally {
      _running = false;
    }

    return completed;
  }
}
