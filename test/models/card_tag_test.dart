import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/card_tag.dart';

void main() {
  test('normalizeTagName réduit les espaces', () {
    expect(normalizeTagName('  Pioche   rapide '), 'Pioche rapide');
  });

  test('normalizeTagName refuse le vide et le trop long', () {
    expect(normalizeTagName('   '), isNull);
    expect(normalizeTagName('a' * 25), isNull);
    expect(normalizeTagName('a' * 24), 'a' * 24);
  });

  test('sameTag ignore la casse', () {
    expect(sameTag('blink', 'Blink'), isTrue);
    expect(sameTag('blink', 'Ramp'), isFalse);
  });

  test('tags par défaut : clés et noms dans l ordre', () {
    expect(kDefaultCardTags.map((t) => t.key), [
      'ramp',
      'draw',
      'removal',
      'wipe',
      'blink',
      'protection',
      'tutor',
      'wincon',
    ]);
    expect(kDefaultCardTags.map((t) => t.name), [
      'Ramp',
      'Pioche',
      'Removal',
      'Wipe',
      'Blink',
      'Protection',
      'Tuteur',
      'Win-con',
    ]);
    expect(kCardTagPalette, hasLength(10));
    for (final t in kDefaultCardTags) {
      expect(kCardTagPalette, contains(t.color));
    }
  });

  test('toJson / fromJson / copyWith', () {
    const t = CardTagDef(key: 'ramp', name: 'Ramp', color: 0xFF000000);
    expect(CardTagDef.fromJson(t.toJson()), t);
    expect(
      CardTagDef.fromJson(const CardTagDef(name: 'X', color: 1).toJson()).key,
      isNull,
    );
    expect(t.copyWith(name: 'Y').key, 'ramp');
    expect(t.copyWith(color: 5).color, 5);
  });

  group('legacyCategoryTags', () {
    test('chaque catégorie de rôle verrouillée donne le libellé en tête', () {
      const expected = {
        'ramp': 'Ramp',
        'draw': 'Pioche',
        'removal': 'Removal',
        'wipe': 'Wipe',
        'protection': 'Protection',
        'tutor': 'Tuteur',
        'wincon': 'Win-con',
      };
      expected.forEach((cat, label) {
        expect(legacyCategoryTags(cat, true, ['X']), [label, 'X'], reason: cat);
      });
    });

    test('lands, creatures, other, inconnue ou nulle : tags inchangés', () {
      for (final cat in ['lands', 'creatures', 'other', 'inconnue', null]) {
        expect(legacyCategoryTags(cat, true, ['X']), ['X'], reason: '$cat');
      }
    });

    test('un tag déjà porté à la casse près n\'est pas doublé', () {
      expect(legacyCategoryTags('draw', true, ['Y', 'pioche']), [
        'Y',
        'pioche',
      ]);
    });

    test('une catégorie non verrouillée n\'écrit rien (simple suggestion)', () {
      expect(legacyCategoryTags('wipe', false, []), isEmpty);
      expect(legacyCategoryTags('ramp', false, ['X']), ['X']);
    });

    test('verrouillée sur des tags vides : le libellé seul', () {
      expect(legacyCategoryTags('wipe', true, []), ['Wipe']);
    });
  });
}
