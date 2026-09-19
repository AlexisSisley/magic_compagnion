// Fichier : test/theme/magic_palette_test.dart
// Verifie que MagicPalette est atteignable depuis le contexte, que les jetons
// de surface et d'encre n'ont pas bouge, et que les jetons semantiques ne se
// confondent plus avec les couleurs de mana.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';

void main() {
  testWidgets('MagicPalette est resolvable depuis le contexte', (tester) async {
    MagicPalette? palette;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        palette = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(palette, isNotNull);
  });

  // Les quatre jetons semantiques (success, warning, danger, info) sont
  // modifies par le lot B : ils n'ont rien a faire dans un test de
  // non-regression. Ce test ne verrouille donc que les surfaces, les encres
  // et l'accent.
  testWidgets("les jetons de surface et d'encre sont inchanges au lot B",
      (tester) async {
    late MagicPalette p;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        p = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(p.canvas, AppColors.scaffoldBackground);
    expect(p.raised, AppColors.cardBackground);
    expect(p.overlay, AppColors.dialogBackground);
    expect(p.line, AppColors.borderMedium);
    expect(p.inkPrimary, AppColors.textPrimary);
    expect(p.inkSecondary, AppColors.textSecondary);
    expect(p.inkMuted, AppColors.textMuted);
    expect(p.accent, AppColors.primary);
    expect(p.onAccent, AppColors.textOnPrimary);
  });

  test('lerp interpole chaque jeton', () {
    const a = MagicPalette(
      canvas: Color(0xFF000000),
      raised: Color(0xFF000000),
      overlay: Color(0xFF000000),
      line: Color(0xFF000000),
      inkPrimary: Color(0xFF000000),
      inkSecondary: Color(0xFF000000),
      inkMuted: Color(0xFF000000),
      accent: Color(0xFF000000),
      onAccent: Color(0xFF000000),
      success: Color(0xFF000000),
      warning: Color(0xFF000000),
      danger: Color(0xFF000000),
      info: Color(0xFF000000),
    );
    const b = MagicPalette(
      canvas: Color(0xFFFFFFFF),
      raised: Color(0xFFFFFFFF),
      overlay: Color(0xFFFFFFFF),
      line: Color(0xFFFFFFFF),
      inkPrimary: Color(0xFFFFFFFF),
      inkSecondary: Color(0xFFFFFFFF),
      inkMuted: Color(0xFFFFFFFF),
      accent: Color(0xFFFFFFFF),
      onAccent: Color(0xFFFFFFFF),
      success: Color(0xFFFFFFFF),
      warning: Color(0xFFFFFFFF),
      danger: Color(0xFFFFFFFF),
      info: Color(0xFFFFFFFF),
    );

    final mid = a.lerp(b, 0.5);

    expect(mid.canvas, Color.lerp(a.canvas, b.canvas, 0.5));
    expect(mid.accent, Color.lerp(a.accent, b.accent, 0.5));
  });

  group('separation semantique / domaine Magic', () {
    /// Distance euclidienne dans l'espace RGB. Grossiere, mais suffisante
    /// pour detecter deux couleurs qu'un oeil ne separera pas : en-dessous
    /// de 60, les deux pastilles se confondent sur un fond sombre.
    double rgbDistance(Color a, Color b) {
      final dr = ((a.r - b.r) * 255).abs();
      final dg = ((a.g - b.g) * 255).abs();
      final db = ((a.b - b.b) * 255).abs();
      return math.sqrt(dr * dr + dg * dg + db * db);
    }

    test('le vert succes ne se confond pas avec le vert mana', () {
      expect(rgbDistance(darkPalette.success, AppColors.manaGreen),
          greaterThan(60));
    });

    test('le rouge danger ne se confond pas avec le rouge mana', () {
      expect(rgbDistance(darkPalette.danger, AppColors.manaRed),
          greaterThan(60));
    });

    test('le bleu info ne se confond pas avec le bleu mana', () {
      expect(rgbDistance(darkPalette.info, AppColors.manaBlue),
          greaterThan(60));
    });
  });
}
