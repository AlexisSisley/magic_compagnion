// Fichier : lib/theme/app_theme.dart
// Construction du ThemeData de l'application. Sorti de main.dart pour que le
// theme soit testable sans monter toute l'app.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'magic_palette.dart';

/// Palette du theme sombre.
///
/// Lot A : valeurs strictement identiques aux AppColors actuelles, pour que
/// l'introduction de l'extension ne deplace aucun pixel. Les valeurs Grimoire
/// arrivent au lot B.
const MagicPalette darkPalette = MagicPalette(
  canvas: AppColors.scaffoldBackground,
  raised: AppColors.cardBackground,
  overlay: AppColors.dialogBackground,
  line: AppColors.borderMedium,
  inkPrimary: AppColors.textPrimary,
  inkSecondary: AppColors.textSecondary,
  inkMuted: AppColors.textMuted,
  accent: AppColors.primary,
  onAccent: AppColors.textOnPrimary,
  // Semantique : valeurs propres, volontairement decalees des couleurs de
  // mana. Avant ce lot, success valait exactement manaGreen (0xFF4CAF50) et
  // un badge "possedee" etait indiscernable d'une carte verte.
  success: Color(0xFF6FD98F),
  warning: Color(0xFFFFA94D),
  danger: Color(0xFFFF7A6E),
  info: Color(0xFF7FB2FF),
);

ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkPalette.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: darkPalette.onAccent,
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkPalette.onAccent.withValues(alpha: 0.9),
      selectedItemColor: AppColors.primaryShade800,
      unselectedItemColor: darkPalette.inkMuted,
      type: BottomNavigationBarType.fixed,
    ),
    extensions: const <ThemeExtension<dynamic>>[darkPalette],
  );
}
