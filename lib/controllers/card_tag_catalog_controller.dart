// Fichier : lib/controllers/card_tag_catalog_controller.dart
// Catalogue des tags universels exposé à l'interface.

import 'package:flutter_riverpod/legacy.dart';

import '../models/card_tag.dart';
import '../providers/service_providers.dart';
import '../services/card_tag_catalog.dart';

class CardTagCatalogController extends StateNotifier<List<CardTagDef>> {
  final CardTagCatalog _catalog;

  CardTagCatalogController(this._catalog) : super(const []) {
    load();
  }

  Future<void> load() async {
    final tags = await _catalog.load();
    if (mounted) state = tags;
  }

  Future<bool> add(String rawName, {int? color}) async {
    final ok = await _catalog.add(rawName, color: color);
    if (ok) await load();
    return ok;
  }

  Future<RenameResult> rename(String from, String to) async {
    final result = await _catalog.rename(from, to);
    if (result == RenameResult.ok) await load();
    return result;
  }

  /// Rend le nombre de lignes de deck touchées.
  Future<int> delete(String name) async {
    final touched = await _catalog.delete(name);
    await load();
    return touched;
  }

  /// [newIndex] suit la convention de `ReorderableListView.onReorder`.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = List.of(state);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex.clamp(0, list.length - 1), list.removeAt(oldIndex));
    await _catalog.save(list);
    if (mounted) state = list;
  }

  Future<void> setColor(String name, int color) async {
    final list = [
      for (final t in state) sameTag(t.name, name) ? t.copyWith(color: color) : t,
    ];
    await _catalog.save(list);
    if (mounted) state = list;
  }
}

final cardTagCatalogProvider =
    StateNotifierProvider<CardTagCatalogController, List<CardTagDef>>((ref) {
      return CardTagCatalogController(
        CardTagCatalog(ref.watch(appDatabaseProvider)),
      );
    });
