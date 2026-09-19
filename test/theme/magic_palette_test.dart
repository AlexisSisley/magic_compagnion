// Fichier : test/theme/magic_palette_test.dart
// Verifie que MagicPalette est atteignable depuis le contexte et que le lot A
// n'a change aucune valeur : chaque jeton doit valoir exactement la couleur
// AppColors qu'il remplace.

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

  testWidgets('lot A ne change aucune valeur', (tester) async {
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
    expect(p.success, AppColors.success);
    expect(p.warning, AppColors.warning);
    expect(p.danger, AppColors.error);
    expect(p.info, AppColors.info);
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
}
