// Fichier : lib/services/legality_service.dart
// Service de verification de legalite de deck (Sprint 10, US-10.3).
// Fonctionne 100% localement sur les donnees deja chargees (fullCardData).
// Service pur sans dependance Flutter, testable en Dart pur.

import '../models/deck_model.dart';
import '../models/legality_report.dart';
import '../models/scryfall_card_model.dart';

/// Service de verification de legalite de deck par format.
class LegalityService {
  /// Formats verifies avec leurs regles structurelles.
  static const Map<String, FormatRules> formatRules = {
    'standard': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
    ),
    'pioneer': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
    ),
    'modern': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
    ),
    'legacy': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
    ),
    'vintage': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
      hasRestricted: true,
    ),
    'pauper': FormatRules(
      minMainboard: 60, maxSideboard: 15, maxCopies: 4, singleton: false,
    ),
    'commander': FormatRules(
      minMainboard: 100, maxSideboard: 0, maxCopies: 1, singleton: true,
      exactMainboard: true, requiresCommander: true, checksColorIdentity: true,
    ),
    'brawl': FormatRules(
      minMainboard: 60, maxSideboard: 0, maxCopies: 1, singleton: true,
      exactMainboard: true, requiresCommander: true, checksColorIdentity: true,
    ),
  };

  /// Genere un rapport de legalite complet pour un deck.
  static LegalityReport generateReport({
    required Deck deck,
    required List<ScryfallCard> fullCardData,
  }) {
    final unresolvedCards = deck.mainboard
            .where((c) => c.scryfallId.startsWith('LOCAL:')).length +
        deck.sideboard
            .where((c) => c.scryfallId.startsWith('LOCAL:')).length;

    final results = formatRules.entries.map((entry) {
      return _checkFormat(
        format: entry.key,
        rules: entry.value,
        deck: deck,
        fullCardData: fullCardData,
      );
    }).toList();

    return LegalityReport(
      results: results,
      unresolvedCards: unresolvedCards,
      generatedAt: DateTime.now(),
    );
  }

  /// Verifie la legalite d'un deck pour un format specifique.
  static FormatLegalityResult _checkFormat({
    required String format,
    required FormatRules rules,
    required Deck deck,
    required List<ScryfallCard> fullCardData,
  }) {
    final List<String> violations = [];
    int illegalCards = 0;
    int bannedCards = 0;
    int restrictedCards = 0;

    final totalMainboard = deck.mainboard.fold(0, (s, c) => s + c.quantity);
    final totalSideboard = deck.sideboard.fold(0, (s, c) => s + c.quantity);

    // 1. Taille du deck
    if (rules.exactMainboard) {
      if (totalMainboard != rules.minMainboard) {
        violations.add(
          'Mainboard : $totalMainboard cartes (${rules.minMainboard} requises)',
        );
      }
    } else {
      if (totalMainboard < rules.minMainboard) {
        violations.add(
          'Mainboard : $totalMainboard cartes (minimum ${rules.minMainboard})',
        );
      }
    }

    // 2. Taille sideboard
    if (totalSideboard > rules.maxSideboard) {
      violations.add(
        'Sideboard : $totalSideboard cartes (maximum ${rules.maxSideboard})',
      );
    }

    // 3. Commander requis
    if (rules.requiresCommander && deck.commanderScryfallId == null) {
      violations.add('Commandant manquant');
    }

    // 4. Map scryfallId -> ScryfallCard pour lookup rapide
    final cardDataMap = <String, ScryfallCard>{};
    for (var c in fullCardData) {
      cardDataMap[c.id] = c;
    }

    // 5. Commander color identity
    Set<String>? commanderIdentity;
    if (rules.checksColorIdentity && deck.commanderScryfallId != null) {
      final cmdCard = cardDataMap[deck.commanderScryfallId];
      if (cmdCard != null) {
        commanderIdentity = cmdCard.colorIdentity.toSet();
        // Add partner identity
        if (deck.commanderSecondaryScryfallId != null) {
          final partner = cardDataMap[deck.commanderSecondaryScryfallId];
          if (partner != null) {
            commanderIdentity.addAll(partner.colorIdentity);
          }
        }
      }
    }

    // 6. Group cards by name for copy count (across mainboard + sideboard)
    final Map<String, int> cardCounts = {};
    for (final card in [...deck.mainboard, ...deck.sideboard]) {
      if (card.scryfallId.startsWith('LOCAL:')) continue;
      cardCounts[card.name] = (cardCounts[card.name] ?? 0) + card.quantity;
    }

    // Track already-reported violations to avoid duplicates
    final Set<String> reportedViolations = {};

    for (final card in [...deck.mainboard, ...deck.sideboard]) {
      if (card.scryfallId.startsWith('LOCAL:')) continue;
      final scryfallCard = cardDataMap[card.scryfallId];
      if (scryfallCard == null) continue;

      // 6a. Legality status from Scryfall
      final status = scryfallCard.legalities[format] ?? 'not_legal';
      final legalityKey = 'legality:${card.name}';
      if (!reportedViolations.contains(legalityKey)) {
        if (status == 'banned') {
          bannedCards++;
          violations.add('Carte bannie : ${card.name}');
          reportedViolations.add(legalityKey);
        } else if (status == 'not_legal') {
          illegalCards++;
          violations.add('Carte non legale : ${card.name}');
          reportedViolations.add(legalityKey);
        } else if (status == 'restricted' && rules.hasRestricted) {
          if (card.quantity > 1) {
            restrictedCards++;
            violations.add(
              'Carte restreinte en exces : ${card.name} (${card.quantity} copies, max 1)',
            );
            reportedViolations.add(legalityKey);
          }
        }
      }

      // 6b. Copy count (exemptions: basic land, "any number" cards)
      final isBasicLand = scryfallCard.typeLine.toLowerCase().contains('basic land');
      final anyNumber = scryfallCard.rulesText.toLowerCase().contains('a deck can have any number');
      if (!isBasicLand && !anyNumber) {
        final count = cardCounts[card.name] ?? 0;
        if (count > rules.maxCopies) {
          final violationKey = 'copies:${card.name}';
          if (!reportedViolations.contains(violationKey)) {
            violations.add(
              '${card.name} : $count copies (max ${rules.maxCopies})',
            );
            reportedViolations.add(violationKey);
          }
        }
      }

      // 6c. Color identity (Commander/Brawl)
      if (commanderIdentity != null) {
        final ciKey = 'ci:${card.name}';
        if (!reportedViolations.contains(ciKey)) {
          for (final color in scryfallCard.colorIdentity) {
            if (!commanderIdentity.contains(color)) {
              violations.add(
                'Hors identite de couleur : ${card.name} ($color)',
              );
              reportedViolations.add(ciKey);
              break;
            }
          }
        }
      }
    }

    final legalityStatus = violations.isEmpty
        ? LegalityStatus.legal
        : LegalityStatus.illegal;

    return FormatLegalityResult(
      format: format,
      status: legalityStatus,
      violations: violations,
      totalCards: totalMainboard + totalSideboard,
      illegalCards: illegalCards,
      bannedCards: bannedCards,
      restrictedCards: restrictedCards,
    );
  }
}
