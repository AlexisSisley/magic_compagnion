import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/layouts/layout_strategy.dart';

void main() {
  group('LayoutResolver', () {
    test('2 players resolves to FaceToFace', () {
      expect(LayoutResolver.resolve(2), LayoutType.faceToFace);
    });
    test('3 players resolves to Grid', () {
      expect(LayoutResolver.resolve(3), LayoutType.grid);
    });
    test('4 players resolves to Grid', () {
      expect(LayoutResolver.resolve(4), LayoutType.grid);
    });
    test('5 players resolves to Focus', () {
      expect(LayoutResolver.resolve(5), LayoutType.focus);
    });
    test('8 players resolves to Focus', () {
      expect(LayoutResolver.resolve(8), LayoutType.focus);
    });
    test('user preference overrides default for 4 players', () {
      expect(LayoutResolver.resolve(4, preference: LayoutType.focus), LayoutType.focus);
    });
    test('user preference overrides default for 6 players', () {
      expect(LayoutResolver.resolve(6, preference: LayoutType.grid), LayoutType.grid);
    });
    test('2 players always FaceToFace regardless of preference', () {
      expect(LayoutResolver.resolve(2, preference: LayoutType.focus), LayoutType.faceToFace);
    });
  });

  group('GridLayoutConfig', () {
    test('3 players uses 2+1 layout', () {
      final config = GridLayoutConfig.forPlayerCount(3);
      expect(config.columns, 2);
      expect(config.topRowCount, 2);
      expect(config.bottomRowCount, 1);
      expect(config.bottomRowFullWidth, true);
    });
    test('4 players uses 2x2 layout', () {
      final config = GridLayoutConfig.forPlayerCount(4);
      expect(config.columns, 2);
      expect(config.topRowCount, 2);
      expect(config.bottomRowCount, 2);
      expect(config.bottomRowFullWidth, false);
    });
  });

  group('FocusLayoutConfig', () {
    test('5 players has 4 adversaries', () {
      final config = FocusLayoutConfig.forPlayerCount(5);
      expect(config.adversaryCount, 4);
      expect(config.ownerHeightRatio, closeTo(0.4, 0.01));
    });
    test('8 players has 7 adversaries', () {
      final config = FocusLayoutConfig.forPlayerCount(8);
      expect(config.adversaryCount, 7);
    });
  });
}
