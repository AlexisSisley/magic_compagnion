// Tests unitaires pour LegalityService (Sprint 10, Phase 4)
// Teste la verification de legalite par format avec regles completes.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/models/legality_report.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/legality_service.dart';

// --- Helpers ---

ScryfallCard _makeCard({
  required String id,
  required String name,
  Map<String, String> legalities = const {},
  List<String> colorIdentity = const [],
  String typeLine = 'Creature',
  String rulesText = '',
}) {
  return ScryfallCard(
    id: id,
    oracleId: 'oracle-$id',
    name: name,
    imageUrl: '',
    rulesText: rulesText,
    typeLine: typeLine,
    legalities: legalities,
    prices: {},
    lang: 'en',
    colorIdentity: colorIdentity,
    setName: 'Test Set',
    setCode: 'TST',
    collectorNumber: '1',
    rarity: 'common',
    purchaseUris: {},
  );
}

Deck _makeDeck({
  String format = 'Standard',
  List<DeckCard>? mainboard,
  List<DeckCard>? sideboard,
  String? commanderScryfallId,
  String? commanderSecondaryScryfallId,
}) {
  return Deck(
    id: 'test-deck',
    name: 'Test Deck',
    format: format,
    mainboard: mainboard,
    sideboard: sideboard,
    commanderScryfallId: commanderScryfallId,
    commanderSecondaryScryfallId: commanderSecondaryScryfallId,
  );
}

void main() {
  // =================================================================
  // FormatRules & LegalityReport model tests
  // =================================================================

  group('LegalityReport model', () {
    test('getFormat returns correct result', () {
      final report = LegalityReport(
        results: [
          const FormatLegalityResult(
            format: 'modern',
            status: LegalityStatus.legal,
          ),
          const FormatLegalityResult(
            format: 'standard',
            status: LegalityStatus.illegal,
            violations: ['Carte non legale : X'],
          ),
        ],
        generatedAt: DateTime.now(),
      );

      expect(report.getFormat('modern')?.status, LegalityStatus.legal);
      expect(report.getFormat('standard')?.status, LegalityStatus.illegal);
      expect(report.getFormat('vintage'), isNull);
    });

    test('legalCount and illegalCount', () {
      final report = LegalityReport(
        results: [
          const FormatLegalityResult(format: 'a', status: LegalityStatus.legal),
          const FormatLegalityResult(format: 'b', status: LegalityStatus.legal),
          const FormatLegalityResult(format: 'c', status: LegalityStatus.illegal),
        ],
        generatedAt: DateTime.now(),
      );

      expect(report.legalCount, 2);
      expect(report.illegalCount, 1);
    });
  });

  // =================================================================
  // LegalityService.generateReport
  // =================================================================

  group('LegalityService.generateReport', () {
    test('returns 8 format results', () {
      final deck = _makeDeck(
        mainboard: List.generate(60, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      );
      final fullCardData = List.generate(60, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {
          'standard': 'legal', 'pioneer': 'legal', 'modern': 'legal',
          'legacy': 'legal', 'vintage': 'legal', 'pauper': 'legal',
          'commander': 'legal', 'brawl': 'legal',
        },
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      expect(report.results.length, 8);
    });

    test('deck legal in Modern (60 cards, all legal)', () {
      final mainboard = List.generate(15, (i) => DeckCard(
        scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
      )); // 15 * 4 = 60 cards
      final deck = _makeDeck(mainboard: mainboard);

      final fullCardData = List.generate(15, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {'modern': 'legal'},
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final modern = report.getFormat('modern');
      expect(modern?.status, LegalityStatus.legal);
    });

    test('deck illegal in Standard with banned card', () {
      final mainboard = [
        ...List.generate(14, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
        )),
        DeckCard(scryfallId: 'oko', name: 'Oko, Thief of Crowns', quantity: 4),
      ]; // 15 * 4 = 60 cards
      final deck = _makeDeck(mainboard: mainboard);

      final fullCardData = [
        ...List.generate(14, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'standard': 'legal'},
        )),
        _makeCard(
          id: 'oko',
          name: 'Oko, Thief of Crowns',
          legalities: {'standard': 'banned'},
        ),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final standard = report.getFormat('standard');
      expect(standard?.status, LegalityStatus.illegal);
      expect(standard?.bannedCards, 1);
      expect(
        standard?.violations.any((v) => v.contains('Oko')),
        isTrue,
      );
    });

    test('deck illegal with not_legal card', () {
      final mainboard = [
        ...List.generate(14, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
        )),
        DeckCard(scryfallId: 'cs', name: 'Counterspell', quantity: 4),
      ];
      final deck = _makeDeck(mainboard: mainboard);

      final fullCardData = [
        ...List.generate(14, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'standard': 'legal'},
        )),
        _makeCard(
          id: 'cs',
          name: 'Counterspell',
          legalities: {'standard': 'not_legal'},
        ),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final standard = report.getFormat('standard');
      expect(standard?.status, LegalityStatus.illegal);
      expect(standard?.illegalCards, 1);
    });

    test('Vintage restricted violation (>1 copy)', () {
      final mainboard = [
        DeckCard(scryfallId: 'bl', name: 'Black Lotus', quantity: 2),
        ...List.generate(14, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
        )),
      ]; // 2 + 56 = 58 cards (will be short)
      final deck = _makeDeck(mainboard: mainboard);

      final fullCardData = [
        _makeCard(
          id: 'bl',
          name: 'Black Lotus',
          legalities: {'vintage': 'restricted'},
        ),
        ...List.generate(14, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'vintage': 'legal'},
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final vintage = report.getFormat('vintage');
      expect(vintage?.status, LegalityStatus.illegal);
      expect(
        vintage?.violations.any((v) => v.contains('Black Lotus') && v.contains('restreinte')),
        isTrue,
      );
    });

    test('Commander legal (100 cards, singleton, commander set)', () {
      final mainboard = List.generate(100, (i) => DeckCard(
        scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
      ));
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'card-0',
        mainboard: mainboard,
      );

      final fullCardData = List.generate(100, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {'commander': 'legal'},
        colorIdentity: ['R'],
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(commander?.status, LegalityStatus.legal);
    });

    test('Commander illegal - wrong card count', () {
      final mainboard = List.generate(50, (i) => DeckCard(
        scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
      ));
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'card-0',
        mainboard: mainboard,
      );

      final fullCardData = List.generate(50, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {'commander': 'legal'},
        colorIdentity: ['R'],
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(commander?.status, LegalityStatus.illegal);
      expect(
        commander?.violations.any((v) => v.contains('100 requises')),
        isTrue,
      );
    });

    test('Commander illegal - no commander set', () {
      final mainboard = List.generate(100, (i) => DeckCard(
        scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
      ));
      final deck = _makeDeck(
        format: 'Commander',
        mainboard: mainboard,
      );

      final fullCardData = List.generate(100, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {'commander': 'legal'},
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(commander?.status, LegalityStatus.illegal);
      expect(
        commander?.violations.any((v) => v.contains('Commandant manquant')),
        isTrue,
      );
    });

    test('Commander illegal - singleton violation (2 copies non-basic)', () {
      final mainboard = [
        DeckCard(scryfallId: 'sol', name: 'Sol Ring', quantity: 2),
        ...List.generate(98, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      ];
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'card-0',
        mainboard: mainboard,
      );

      final fullCardData = [
        _makeCard(id: 'sol', name: 'Sol Ring', legalities: {'commander': 'legal'}, colorIdentity: ['R']),
        ...List.generate(98, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'commander': 'legal'},
          colorIdentity: ['R'],
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(commander?.status, LegalityStatus.illegal);
      expect(
        commander?.violations.any((v) => v.contains('Sol Ring') && v.contains('2 copies')),
        isTrue,
      );
    });

    test('Commander - basic land exempt from singleton', () {
      final mainboard = [
        DeckCard(scryfallId: 'plains', name: 'Plains', quantity: 35),
        ...List.generate(65, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      ];
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'card-0',
        mainboard: mainboard,
      );

      final fullCardData = [
        _makeCard(
          id: 'plains',
          name: 'Plains',
          typeLine: 'Basic Land - Plains',
          legalities: {'commander': 'legal'},
          colorIdentity: ['W'],
        ),
        ...List.generate(65, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'commander': 'legal'},
          colorIdentity: ['W'],
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      // Plains should NOT cause a singleton violation
      expect(
        commander?.violations.any((v) => v.contains('Plains')),
        isFalse,
      );
    });

    test('Commander - "any number" card exempt from singleton', () {
      final mainboard = [
        DeckCard(scryfallId: 'rats', name: 'Relentless Rats', quantity: 4),
        ...List.generate(96, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      ];
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'card-0',
        mainboard: mainboard,
      );

      final fullCardData = [
        _makeCard(
          id: 'rats',
          name: 'Relentless Rats',
          rulesText: 'A deck can have any number of cards named Relentless Rats.',
          legalities: {'commander': 'legal'},
          colorIdentity: ['B'],
        ),
        ...List.generate(96, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'commander': 'legal'},
          colorIdentity: ['B'],
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(
        commander?.violations.any((v) => v.contains('Relentless Rats')),
        isFalse,
      );
    });

    test('Commander - color identity violation', () {
      final mainboard = [
        DeckCard(scryfallId: 'cmd', name: 'Red Commander', quantity: 1),
        DeckCard(scryfallId: 'cs', name: 'Counterspell', quantity: 1),
        ...List.generate(98, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      ];
      final deck = _makeDeck(
        format: 'Commander',
        commanderScryfallId: 'cmd',
        mainboard: mainboard,
      );

      final fullCardData = [
        _makeCard(
          id: 'cmd',
          name: 'Red Commander',
          typeLine: 'Legendary Creature',
          legalities: {'commander': 'legal'},
          colorIdentity: ['R'],
        ),
        _makeCard(
          id: 'cs',
          name: 'Counterspell',
          legalities: {'commander': 'legal'},
          colorIdentity: ['U'],
        ),
        ...List.generate(98, (i) => _makeCard(
          id: 'card-$i',
          name: 'Card $i',
          legalities: {'commander': 'legal'},
          colorIdentity: ['R'],
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final commander = report.getFormat('commander');
      expect(commander?.status, LegalityStatus.illegal);
      expect(
        commander?.violations.any((v) => v.contains('Counterspell') && v.contains('U')),
        isTrue,
      );
    });

    test('LOCAL: cards are counted as unresolved', () {
      final mainboard = [
        DeckCard(scryfallId: 'LOCAL:Unknown Card', name: 'Unknown Card', quantity: 1),
        ...List.generate(59, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 1,
        )),
      ];
      final deck = _makeDeck(mainboard: mainboard);
      final fullCardData = List.generate(59, (i) => _makeCard(
        id: 'card-$i',
        name: 'Card $i',
        legalities: {'standard': 'legal'},
      ));

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      expect(report.unresolvedCards, 1);
    });

    test('empty deck is illegal in all formats', () {
      final deck = _makeDeck();
      final report = LegalityService.generateReport(
        deck: deck, fullCardData: [],
      );

      for (final result in report.results) {
        expect(result.status, LegalityStatus.illegal,
            reason: '${result.format} should be illegal for empty deck');
      }
    });

    test('sideboard too large is a violation', () {
      final mainboard = List.generate(15, (i) => DeckCard(
        scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
      )); // 60 cards
      final sideboard = List.generate(5, (i) => DeckCard(
        scryfallId: 'side-$i', name: 'Side $i', quantity: 4,
      )); // 20 cards
      final deck = _makeDeck(mainboard: mainboard, sideboard: sideboard);

      final fullCardData = [
        ...List.generate(15, (i) => _makeCard(
          id: 'card-$i', name: 'Card $i', legalities: {'modern': 'legal'},
        )),
        ...List.generate(5, (i) => _makeCard(
          id: 'side-$i', name: 'Side $i', legalities: {'modern': 'legal'},
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final modern = report.getFormat('modern');
      expect(modern?.status, LegalityStatus.illegal);
      expect(
        modern?.violations.any((v) => v.contains('Sideboard') && v.contains('20')),
        isTrue,
      );
    });

    test('too many copies in non-singleton format', () {
      final mainboard = [
        DeckCard(scryfallId: 'bolt', name: 'Lightning Bolt', quantity: 5),
        ...List.generate(14, (i) => DeckCard(
          scryfallId: 'card-$i', name: 'Card $i', quantity: 4,
        )),
      ]; // 5 + 56 = 61
      final deck = _makeDeck(mainboard: mainboard);

      final fullCardData = [
        _makeCard(id: 'bolt', name: 'Lightning Bolt', legalities: {'modern': 'legal'}),
        ...List.generate(14, (i) => _makeCard(
          id: 'card-$i', name: 'Card $i', legalities: {'modern': 'legal'},
        )),
      ];

      final report = LegalityService.generateReport(
        deck: deck, fullCardData: fullCardData,
      );

      final modern = report.getFormat('modern');
      expect(modern?.status, LegalityStatus.illegal);
      expect(
        modern?.violations.any((v) => v.contains('Lightning Bolt') && v.contains('5 copies')),
        isTrue,
      );
    });
  });

  // =================================================================
  // FormatRules static data
  // =================================================================

  group('LegalityService.formatRules', () {
    test('contains all 8 expected formats', () {
      expect(LegalityService.formatRules.length, 8);
      expect(LegalityService.formatRules.containsKey('standard'), isTrue);
      expect(LegalityService.formatRules.containsKey('pioneer'), isTrue);
      expect(LegalityService.formatRules.containsKey('modern'), isTrue);
      expect(LegalityService.formatRules.containsKey('legacy'), isTrue);
      expect(LegalityService.formatRules.containsKey('vintage'), isTrue);
      expect(LegalityService.formatRules.containsKey('pauper'), isTrue);
      expect(LegalityService.formatRules.containsKey('commander'), isTrue);
      expect(LegalityService.formatRules.containsKey('brawl'), isTrue);
    });

    test('Commander has correct rules', () {
      final rules = LegalityService.formatRules['commander']!;
      expect(rules.minMainboard, 100);
      expect(rules.maxSideboard, 0);
      expect(rules.maxCopies, 1);
      expect(rules.singleton, isTrue);
      expect(rules.exactMainboard, isTrue);
      expect(rules.requiresCommander, isTrue);
      expect(rules.checksColorIdentity, isTrue);
    });

    test('Vintage has restricted flag', () {
      final rules = LegalityService.formatRules['vintage']!;
      expect(rules.hasRestricted, isTrue);
      expect(rules.minMainboard, 60);
    });

    test('Standard has 60/15/4 rules', () {
      final rules = LegalityService.formatRules['standard']!;
      expect(rules.minMainboard, 60);
      expect(rules.maxSideboard, 15);
      expect(rules.maxCopies, 4);
      expect(rules.singleton, isFalse);
    });
  });
}
