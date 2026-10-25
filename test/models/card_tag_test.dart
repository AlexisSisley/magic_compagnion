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
      'ramp', 'draw', 'removal', 'wipe', 'blink', 'protection', 'tutor', 'wincon',
    ]);
    expect(kDefaultCardTags.map((t) => t.name), [
      'Ramp', 'Pioche', 'Removal', 'Wipe', 'Blink', 'Protection', 'Tuteur', 'Win-con',
    ]);
    expect(kCardTagPalette, hasLength(10));
    for (final t in kDefaultCardTags) {
      expect(kCardTagPalette, contains(t.color));
    }
  });

  test('toJson / fromJson / copyWith', () {
    const t = CardTagDef(key: 'ramp', name: 'Ramp', color: 0xFF000000);
    expect(CardTagDef.fromJson(t.toJson()), t);
    expect(CardTagDef.fromJson(const CardTagDef(name: 'X', color: 1).toJson()).key, isNull);
    expect(t.copyWith(name: 'Y').key, 'ramp');
    expect(t.copyWith(color: 5).color, 5);
  });
}
