// Fichier : lib/services/deck_format_service.dart
// Service de parsing/generation de decklists multi-format (Sprint 10, US-10.1 + US-10.2).
// Gere TXT (Moxfield/MTGO), CSV (Archidekt), et texte brut.
// Service pur sans dependance Flutter, testable en Dart pur.

import '../models/deck_model.dart';

/// Resultat intermediaire du parsing d'une decklist.
class DecklistParseResult {
  final List<DecklistEntry> mainboard;
  final List<DecklistEntry> sideboard;
  final String? commanderName;
  final Map<String, List<String>> cardTags; // nom -> tags (depuis CSV Archidekt)
  final List<String> warnings;
  final bool hasErrors;

  const DecklistParseResult({
    this.mainboard = const [],
    this.sideboard = const [],
    this.commanderName,
    this.cardTags = const {},
    this.warnings = const [],
    this.hasErrors = false,
  });

  factory DecklistParseResult.empty({List<String> warnings = const []}) {
    return DecklistParseResult(warnings: warnings, hasErrors: warnings.isNotEmpty);
  }

  /// Nombre total de cartes (mainboard + sideboard).
  int get totalCards {
    final mainTotal = mainboard.fold(0, (s, e) => s + e.quantity);
    final sideTotal = sideboard.fold(0, (s, e) => s + e.quantity);
    return mainTotal + sideTotal;
  }
}

/// Entree individuelle d'une decklist parsee.
class DecklistEntry {
  final String name;
  final int quantity;
  final String section; // 'mainboard', 'sideboard', 'commander'

  const DecklistEntry({
    required this.name,
    required this.quantity,
    required this.section,
  });
}

/// Service de parsing/generation de decklists multi-format.
class DeckFormatService {
  static final RegExp _cardLineRegex = RegExp(r'^(\d+)x?\s+(.+)$');

  /// Parse une decklist au format texte (Moxfield/MTGO compatible).
  /// Supporte les sections Commander, Deck/Mainboard, Sideboard.
  /// Ignore les sections Considering/Maybeboard et les commentaires.
  static DecklistParseResult parseDecklistText(String text) {
    final List<DecklistEntry> mainboard = [];
    final List<DecklistEntry> sideboard = [];
    String? commanderName;
    String section = 'mainboard';
    final List<String> warnings = [];

    for (var line in text.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Detection des sections
      final lowerLine = line.toLowerCase();
      if (lowerLine.startsWith('commander')) {
        section = 'commander';
        continue;
      }
      if (lowerLine.startsWith('deck') ||
          lowerLine.startsWith('mainboard') ||
          lowerLine.startsWith('main board')) {
        section = 'mainboard';
        continue;
      }
      if (lowerLine.startsWith('sideboard') ||
          lowerLine.startsWith('side board') ||
          lowerLine.startsWith('sb:')) {
        section = 'sideboard';
        continue;
      }
      if (lowerLine.startsWith('considering') ||
          lowerLine.startsWith('maybeboard') ||
          lowerLine.startsWith('maybe')) {
        section = 'skip';
        continue;
      }
      if (lowerLine.startsWith('//') || lowerLine.startsWith('#')) {
        continue; // Commentaires
      }

      // Skip section
      if (section == 'skip') continue;

      final match = _cardLineRegex.firstMatch(line);
      if (match == null) {
        warnings.add('Ligne ignoree: $line');
        continue;
      }

      final qty = int.parse(match.group(1)!);
      // Nettoyer le nom : retirer set codes entre parentheses, face arriere, foil MTGO
      String name = _cleanCardName(match.group(2)!);

      switch (section) {
        case 'commander':
          commanderName = name;
          mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
          break;
        case 'sideboard':
          sideboard.add(DecklistEntry(name: name, quantity: qty, section: 'sideboard'));
          break;
        default:
          mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
      }
    }

    return DecklistParseResult(
      mainboard: mainboard,
      sideboard: sideboard,
      commanderName: commanderName,
      cardTags: {},
      warnings: warnings,
      hasErrors: false,
    );
  }

  /// Parse une decklist au format CSV (Archidekt, generique).
  /// Detecte les colonnes par header. Supporte les variantes de noms de colonnes.
  static DecklistParseResult parseDecklistCsv(String csvContent) {
    final List<DecklistEntry> mainboard = [];
    final List<DecklistEntry> sideboard = [];
    String? commanderName;
    final Map<String, List<String>> cardTags = {};
    final List<String> warnings = [];

    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return DecklistParseResult.empty(warnings: ['CSV vide']);
    }

    // Detecter le delimiteur (virgule ou point-virgule)
    final String delimiter = _detectDelimiter(lines.first);

    // Detecter les colonnes par header
    final header = _parseCsvLine(lines.first, delimiter)
        .map((h) => h.trim().toLowerCase().replaceAll('"', ''))
        .toList();

    final qtyIdx = header.indexWhere(
        (h) => h == 'quantity' || h == 'qty' || h == 'count');
    final nameIdx = header.indexWhere(
        (h) => h == 'name' || h == 'card' || h == 'card_name');
    final sectionIdx = header.indexWhere(
        (h) => h == 'section' || h == 'board');
    final categoriesIdx = header.indexWhere(
        (h) => h == 'categories' || h == 'category' || h == 'tags');

    if (qtyIdx == -1 || nameIdx == -1) {
      return DecklistParseResult.empty(
        warnings: ['CSV invalide: colonnes quantity/name introuvables'],
      );
    }

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _parseCsvLine(line, delimiter);
      if (cols.length <= nameIdx || cols.length <= qtyIdx) {
        warnings.add('Ligne CSV ignoree: $line');
        continue;
      }

      final qty = int.tryParse(cols[qtyIdx].trim().replaceAll('"', '')) ?? 1;
      final name = cols[nameIdx].trim().replaceAll('"', '');
      if (name.isEmpty) continue;

      String section = 'mainboard';
      if (sectionIdx != -1 && cols.length > sectionIdx) {
        section = cols[sectionIdx].trim().toLowerCase().replaceAll('"', '');
      }

      // Tags depuis Archidekt categories
      if (categoriesIdx != -1 && cols.length > categoriesIdx) {
        final rawCategories = cols[categoriesIdx].trim().replaceAll('"', '');
        if (rawCategories.isNotEmpty) {
          final tags = rawCategories
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          if (tags.isNotEmpty) {
            cardTags[name] = tags;
          }
        }
      }

      if (section.contains('side')) {
        sideboard.add(DecklistEntry(name: name, quantity: qty, section: 'sideboard'));
      } else if (section.contains('command')) {
        commanderName = name;
        mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
      } else {
        mainboard.add(DecklistEntry(name: name, quantity: qty, section: 'mainboard'));
      }
    }

    return DecklistParseResult(
      mainboard: mainboard,
      sideboard: sideboard,
      commanderName: commanderName,
      cardTags: cardTags,
      warnings: warnings,
      hasErrors: false,
    );
  }

  /// Detecte automatiquement le format (TXT vs CSV) et parse.
  /// Heuristique: si la premiere ligne non-vide contient un delimiteur CSV
  /// et des noms de colonnes reconnus, traite comme CSV.
  static DecklistParseResult autoDetectAndParse(String content) {
    if (content.trim().isEmpty) {
      return DecklistParseResult.empty(warnings: ['Contenu vide']);
    }

    final firstLine = content.split('\n').firstWhere(
      (l) => l.trim().isNotEmpty,
      orElse: () => '',
    ).toLowerCase();

    // Heuristique CSV: la premiere ligne contient des mots-cles de header
    final csvKeywords = ['quantity', 'qty', 'count', 'name', 'card', 'card_name'];
    final hasDelimiter = firstLine.contains(',') || firstLine.contains(';');
    final hasHeader = csvKeywords.any((kw) => firstLine.contains(kw));

    if (hasDelimiter && hasHeader) {
      return parseDecklistCsv(content);
    }

    return parseDecklistText(content);
  }

  /// Genere le texte au format TXT (Moxfield/MTGO compatible).
  static String exportToTxt(Deck deck) {
    final sb = StringBuffer();

    // Commander section
    if (deck.commanderScryfallId != null) {
      sb.writeln('Commander');
      final cmdCards = deck.mainboard.where(
        (c) => c.scryfallId == deck.commanderScryfallId,
      );
      if (cmdCards.isNotEmpty) {
        sb.writeln('1 ${cmdCards.first.name}');
      }
      if (deck.commanderSecondaryScryfallId != null) {
        final partnerCards = deck.mainboard.where(
          (c) => c.scryfallId == deck.commanderSecondaryScryfallId,
        );
        if (partnerCards.isNotEmpty) {
          sb.writeln('1 ${partnerCards.first.name}');
        }
      }
      sb.writeln();
    }

    // Deck/Mainboard
    sb.writeln('Deck');
    for (final card in deck.mainboard) {
      // Skip commander cards in mainboard section
      if (card.scryfallId == deck.commanderScryfallId ||
          card.scryfallId == deck.commanderSecondaryScryfallId) {
        continue;
      }
      sb.writeln('${card.quantity} ${card.name}');
    }

    // Sideboard
    if (deck.sideboard.isNotEmpty) {
      sb.writeln();
      sb.writeln('Sideboard');
      for (final card in deck.sideboard) {
        sb.writeln('${card.quantity} ${card.name}');
      }
    }

    return sb.toString().trimRight();
  }

  /// Genere le contenu au format CSV.
  static String exportToCsv(Deck deck) {
    final sb = StringBuffer();
    sb.writeln('quantity,name,section,scryfallId,tags');

    void writeCards(List<DeckCard> cards, String section) {
      for (final card in cards) {
        final tagsStr = card.tags.join(';');
        final escapedName = card.name.contains(',') || card.name.contains('"')
            ? '"${card.name.replaceAll('"', '""')}"'
            : card.name;
        sb.writeln('${card.quantity},$escapedName,$section,${card.scryfallId},"$tagsStr"');
      }
    }

    writeCards(deck.mainboard, 'mainboard');
    writeCards(deck.sideboard, 'sideboard');
    writeCards(deck.considering, 'considering');
    writeCards(deck.wishlist, 'wishlist');

    return sb.toString().trimRight();
  }

  // --- PRIVATE HELPERS ---

  /// Nettoie un nom de carte en retirant les annotations courantes.
  static String _cleanCardName(String rawName) {
    return rawName
        .split('//')[0] // Retirer face arriere double-face
        .replaceAll(RegExp(r'\s*\([A-Z0-9]+\)\s*$'), '') // Retirer set code (SET)
        .replaceAll(RegExp(r'\s*\*F\*\s*$'), '') // Retirer indicateur foil MTGO
        .replaceAll(RegExp(r'\s*#\d+\s*$'), '') // Retirer collector number
        .trim();
  }

  /// Detecte le delimiteur CSV (virgule ou point-virgule).
  static String _detectDelimiter(String headerLine) {
    final commaCount = headerLine.split(',').length;
    final semicolonCount = headerLine.split(';').length;
    return semicolonCount > commaCount ? ';' : ',';
  }

  /// Parse une ligne CSV en tenant compte des guillemets.
  static List<String> _parseCsvLine(String line, String delimiter) {
    final List<String> fields = [];
    bool inQuotes = false;
    final current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        fields.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    fields.add(current.toString());

    return fields;
  }
}
