// Fichier : lib/services/card_tag_catalog.dart
// Catalogue des tags universels, stocké en JSON dans les réglages.

import 'dart:convert';

import '../data/database/app_database.dart';
import '../models/card_tag.dart';

enum RenameResult { ok, invalid, duplicate }

class CardTagCatalog {
  static const String settingKey = 'card_tags:universal';

  final AppDatabase _db;

  CardTagCatalog(AppDatabase db) : _db = db;

  /// Lit le catalogue. Une clé absente ou illisible rend les défauts et les
  /// écrit ; une liste vide stockée reste vide.
  Future<List<CardTagDef>> load() async {
    final raw = await _db.getSetting(settingKey);
    if (raw != null) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded
              .map((e) => CardTagDef.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } on FormatException {
        // retombe sur les défauts
      } on TypeError {
        // retombe sur les défauts
      }
    }
    await save(kDefaultCardTags);
    return List.of(kDefaultCardTags);
  }

  Future<void> save(List<CardTagDef> tags) {
    return _db.setSetting(
      settingKey,
      json.encode(tags.map((t) => t.toJson()).toList()),
    );
  }

  Future<RenameResult> rename(String from, String to) async {
    final name = normalizeTagName(to);
    if (name == null) return RenameResult.invalid;
    final catalog = await load();
    final index = catalog.indexWhere((t) => sameTag(t.name, from));
    if (catalog.any((t) => sameTag(t.name, name) && !sameTag(t.name, from))) {
      return RenameResult.duplicate;
    }
    if (index >= 0) {
      catalog[index] = catalog[index].copyWith(name: name);
      await save(catalog);
    }
    await _db.rewriteAllDeckCardTags((tags) {
      if (!tags.any((t) => sameTag(t, from))) return null;
      final out = <String>[];
      for (final t in tags) {
        final next = sameTag(t, from) ? name : t;
        if (!out.any((o) => sameTag(o, next))) out.add(next);
      }
      return out;
    });
    return RenameResult.ok;
  }

  Future<int> delete(String name) async {
    final catalog = await load();
    catalog.removeWhere((t) => sameTag(t.name, name));
    await save(catalog);
    return _db.rewriteAllDeckCardTags((tags) {
      if (!tags.any((t) => sameTag(t, name))) return null;
      return tags.where((t) => !sameTag(t, name)).toList();
    });
  }

  Future<int> usageCount(String name) async {
    var count = 0;
    await _db.rewriteAllDeckCardTags((tags) {
      if (tags.any((t) => sameTag(t, name))) count++;
      return null;
    });
    return count;
  }

  Future<bool> add(String rawName, {int? color}) async {
    final name = normalizeTagName(rawName);
    if (name == null) return false;
    final catalog = await load();
    if (catalog.any((t) => sameTag(t.name, name))) return false;
    catalog.add(
      CardTagDef(
        name: name,
        color: color ?? kCardTagPalette[catalog.length % kCardTagPalette.length],
      ),
    );
    await save(catalog);
    return true;
  }
}
