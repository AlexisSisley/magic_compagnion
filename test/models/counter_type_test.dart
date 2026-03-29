import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/counter_type.dart';

void main() {
  group('CounterType', () {
    test('creates a valid counter', () {
      final counter = CounterType(
        id: 'poison',
        name: 'Poison',
        emoji: '☠️',
        color: 0xFF4CAF50,
        isBuiltIn: true,
        maxValue: 10,
      );

      expect(counter.id, 'poison');
      expect(counter.name, 'Poison');
      expect(counter.maxValue, 10);
      expect(counter.isBuiltIn, true);
    });

    test('custom counter has no maxValue', () {
      final counter = CounterType(
        id: 'storm',
        name: 'Storm Count',
        emoji: '⚡',
        color: 0xFFFF9800,
        isBuiltIn: false,
      );

      expect(counter.maxValue, isNull);
      expect(counter.isBuiltIn, false);
    });

    test('copyWith preserves values', () {
      final counter = CounterType(
        id: 'poison',
        name: 'Poison',
        emoji: '☠️',
        color: 0xFF4CAF50,
        isBuiltIn: true,
        maxValue: 10,
      );
      final copied = counter.copyWith(name: 'Infect');
      expect(copied.id, 'poison');
      expect(copied.name, 'Infect');
      expect(copied.maxValue, 10);
    });

    test('toJson and fromJson roundtrip', () {
      final counter = CounterType(
        id: 'custom-1',
        name: 'Rad',
        emoji: '☢️',
        color: 0xFFFF5722,
        isBuiltIn: false,
        maxValue: null,
      );
      final json = counter.toJson();
      final restored = CounterType.fromJson(json);
      expect(restored.id, counter.id);
      expect(restored.name, counter.name);
      expect(restored.emoji, counter.emoji);
      expect(restored.maxValue, isNull);
    });
  });

  group('CounterType.builtInCounters', () {
    test('contains 4 built-in counters', () {
      expect(CounterType.builtInCounters, hasLength(4));
    });

    test('all built-in counters have isBuiltIn true', () {
      for (final c in CounterType.builtInCounters) {
        expect(c.isBuiltIn, true, reason: '${c.name} should be built-in');
      }
    });

    test('poison has maxValue 10', () {
      final poison = CounterType.builtInCounters.firstWhere((c) => c.id == 'poison');
      expect(poison.maxValue, 10);
    });

    test('energy has no maxValue', () {
      final energy = CounterType.builtInCounters.firstWhere((c) => c.id == 'energy');
      expect(energy.maxValue, isNull);
    });
  });
}
