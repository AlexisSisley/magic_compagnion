import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/moxfield_deck_mapper.dart';

Map<String, dynamic> _carte({
  required String id,
  required String name,
  int quantity = 1,
  bool isFoil = false,
  bool isProxy = false,
  String set = 'tla',
  String cn = '353',
  String lang = 'en',
}) =>
    {
      'quantity': quantity,
      'isFoil': isFoil,
      'isProxy': isProxy,
      'finish': isFoil ? 'foil' : 'nonFoil',
      'card': {
        'scryfall_id': id,
        'name': name,
        'set': set,
        'cn': cn,
        'lang': lang,
      },
    };

Map<String, dynamic> _deck({Map<String, dynamic>? boards}) => {
      'name': 'Invincible toph',
      'format': 'commander',
      'boards': boards ??
          {
            'commanders': {
              'cards': {'a': _carte(id: 'toph-id', name: 'Toph, the First Metalbender')}
            },
            'mainboard': {
              'cards': {
                'b': _carte(id: 'wurmcoil-id', name: 'Wurmcoil Engine', set: 'cm2', cn: '231'),
                'c': _carte(id: 'lattice-id', name: 'Mycosynth Lattice', quantity: 2, isFoil: true),
              }
            },
            'maybeboard': {
              'cards': {'d': _carte(id: 'maybe-id', name: 'Contagion Engine')}
            },
            'sideboard': {'cards': <String, dynamic>{}},
            'attractions': {
              'cards': {'e': _carte(id: 'attr-id', name: 'Attraction')}
            },
          },
    };

void main() {
  test('le nom et le format sont repris', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.name, 'Invincible toph');
    expect(d.format, 'commander');
  });

  test('le commandant est extrait du board commanders', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.commanderScryfallId, 'toph-id');
    expect(d.partnerScryfallId, isNull);
  });

  test('le maybeboard atterrit dans considering', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    final maybe = d.lines.where((l) => l.board == 'considering');
    expect(maybe, hasLength(1));
    expect(maybe.single.name, 'Contagion Engine');
  });

  test('les boards sans equivalent sont ignores silencieusement', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.lines.any((l) => l.name == 'Attraction'), isFalse);
  });

  test('quantite, foil et proxy sont fidelement repris', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    final lattice = d.lines.firstWhere((l) => l.name == 'Mycosynth Lattice');
    expect(lattice.quantity, 2);
    expect(lattice.isFoil, isTrue);
    expect(lattice.isProxy, isFalse);
  });

  test('le scryfall_id est repris tel quel, sans resolution par nom', () {
    final d = MoxfieldDeckMapper.fromJson(_deck());

    expect(d.lines.map((l) => l.scryfallId),
        containsAll(['wurmcoil-id', 'lattice-id', 'maybe-id']));
  });

  test('un deck sans commandant ne leve pas', () {
    final d = MoxfieldDeckMapper.fromJson(_deck(boards: {
      'mainboard': {
        'cards': {'b': _carte(id: 'x', name: 'Lightning Bolt')}
      }
    }));

    expect(d.commanderScryfallId, isNull);
    expect(d.lines, hasLength(1));
  });

  test('deux commandants donnent un commandant et un partenaire', () {
    final d = MoxfieldDeckMapper.fromJson(_deck(boards: {
      'commanders': {
        'cards': {
          'a': _carte(id: 'cmd-1', name: 'Commandant A'),
          'b': _carte(id: 'cmd-2', name: 'Commandant B'),
        }
      },
      'mainboard': {'cards': <String, dynamic>{}},
    }));

    expect(d.commanderScryfallId, isNotNull);
    expect(d.partnerScryfallId, isNotNull);
    expect(d.commanderScryfallId, isNot(d.partnerScryfallId));
  });

  test('une carte sans scryfall_id est ignoree plutot que de casser l import', () {
    final d = MoxfieldDeckMapper.fromJson({
      'name': 'x',
      'format': 'commander',
      'boards': {
        'mainboard': {
          'cards': {
            'a': {'quantity': 1, 'card': {'name': 'Sans id'}},
            'b': _carte(id: 'bon-id', name: 'Bonne carte'),
          }
        }
      },
    });

    expect(d.lines, hasLength(1));
    expect(d.lines.single.scryfallId, 'bon-id');
  });
}
