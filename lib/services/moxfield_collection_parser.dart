// Parser d'export de collection Moxfield.
//
// Le format exact n'a pas pu etre verifie sur un fichier reel : les colonnes
// sont donc detectees par leur nom, avec alias, et classees selon ce qu'on perd
// si elles manquent. Se tromper d'en-tete doit produire un message, jamais une
// collection fausse.
//
// Voir docs/superpowers/specs/2026-09-19-import-moxfield-design.md

import '../models/moxfield_import.dart';

class MoxfieldCollectionParser {
  static const List<String> _countAliases = ['count', 'quantity', 'qty'];
  static const List<String> _nameAliases = ['name', 'card', 'card name'];
  static const List<String> _editionAliases = ['edition', 'set', 'set code'];
  static const List<String> _cnAliases = ['collector number', 'collectornumber', 'card number'];
  static const List<String> _langAliases = ['language', 'lang'];
  static const List<String> _foilAliases = ['foil', 'finish', 'foiling'];

  static const Set<String> _foilTrue = {'foil', 'true', '1', 'yes', 'etched', 'oui'};

  /// Langues connues de Scryfall, avec leurs noms usuels.
  static const Map<String, String> _langMap = {
    'en': 'en', 'english': 'en', 'anglais': 'en',
    'fr': 'fr', 'french': 'fr', 'français': 'fr', 'francais': 'fr',
    'de': 'de', 'german': 'de', 'allemand': 'de', 'deutsch': 'de',
    'es': 'es', 'spanish': 'es', 'espagnol': 'es', 'español': 'es',
    'it': 'it', 'italian': 'it', 'italien': 'it', 'italiano': 'it',
    'pt': 'pt', 'portuguese': 'pt', 'portugais': 'pt',
    'ja': 'ja', 'japanese': 'ja', 'japonais': 'ja',
    'ko': 'ko', 'korean': 'ko', 'coreen': 'ko',
    'ru': 'ru', 'russian': 'ru', 'russe': 'ru',
    'zhs': 'zhs', 'zht': 'zht', 'ph': 'ph',
  };

  static CollectionParseResult parse(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const CollectionParseResult(
        refusal: 'Fichier vide : aucune ligne à lire.',
      );
    }

    final delimiter = _detectDelimiter(lines.first);
    final header = _parseLine(lines.first, delimiter)
        .map((h) => h.trim().toLowerCase())
        .toList();

    int idx(List<String> aliases) =>
        header.indexWhere((h) => aliases.contains(h));

    final countIdx = idx(_countAliases);
    final nameIdx = idx(_nameAliases);
    final editionIdx = idx(_editionAliases);
    final cnIdx = idx(_cnAliases);
    final langIdx = idx(_langAliases);
    final foilIdx = idx(_foilAliases);

    final manquantes = <String>[
      if (countIdx == -1) 'Count',
      if (nameIdx == -1) 'Name',
    ];
    if (manquantes.isNotEmpty) {
      return CollectionParseResult(
        refusal:
            'Colonne(s) indispensable(s) introuvable(s) : ${manquantes.join(', ')}. '
            'Vérifie que le fichier vient bien de l’export de collection Moxfield.',
      );
    }

    final reconnues = <String>[
      'Count', 'Name',
      if (editionIdx != -1) 'Edition',
      if (cnIdx != -1) 'Collector Number',
      if (langIdx != -1) 'Language',
      if (foilIdx != -1) 'Foil',
    ];
    final identiteManquante = <String>[
      if (editionIdx == -1) 'Edition',
      if (cnIdx == -1) 'Collector Number',
    ];

    final entries = <CollectionEntry>[];
    final illisibles = <String>[];

    String? at(List<String> cols, int i) =>
        (i == -1 || i >= cols.length) ? null : cols[i].trim();

    for (var i = 1; i < lines.length; i++) {
      final raw = lines[i].trim();
      final cols = _parseLine(raw, delimiter);

      final name = at(cols, nameIdx);
      final rawCount = at(cols, countIdx);
      final qty = int.tryParse(rawCount ?? '');

      if (name == null || name.isEmpty || qty == null || qty <= 0) {
        illisibles.add(raw);
        continue;
      }

      final edition = at(cols, editionIdx);
      final cn = at(cols, cnIdx);
      final rawLang = at(cols, langIdx)?.toLowerCase();
      final rawFoil = at(cols, foilIdx)?.toLowerCase();

      entries.add(CollectionEntry(
        name: name,
        quantity: qty,
        setCode: (edition == null || edition.isEmpty) ? null : edition,
        collectorNumber: (cn == null || cn.isEmpty) ? null : cn,
        lang: rawLang == null ? null : _langMap[rawLang],
        isFoil: rawFoil != null && _foilTrue.contains(rawFoil),
      ));
    }

    return CollectionParseResult(
      entries: entries,
      recognizedColumns: reconnues,
      missingIdentityColumns: identiteManquante,
      unreadableLines: illisibles,
    );
  }

  static String _detectDelimiter(String headerLine) =>
      headerLine.contains(';') && !headerLine.contains(',') ? ';' : ',';

  /// Decoupe une ligne CSV en respectant les guillemets.
  static List<String> _parseLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delimiter && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}
