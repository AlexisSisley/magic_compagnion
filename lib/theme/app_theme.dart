// Fichier : lib/theme/app_theme.dart
// Construction du ThemeData de l'application. Sorti de main.dart pour que le
// theme soit testable sans monter toute l'app.

import 'package:flutter/material.dart';

import 'magic_palette.dart';

/// Palette Grimoire — theme sombre officiel.
///
/// Noir d'encre et or patine. L'or remplace `Colors.yellow` : le jaune pur
/// vibre sur fond noir et fatigue en lecture longue.
///
/// Les trois surfaces forment une echelle monotone croissante en luminance
/// (canvas < raised < overlay) : c'est ce qui permet de lire l'elevation
/// d'un element sans lui ajouter une ombre.
const MagicPalette darkPalette = MagicPalette(
  canvas: Color(0xFF0E0E11),
  raised: Color(0xFF191820),
  overlay: Color(0xFF2A2733),
  line: Color(0xFF3A3646),

  inkPrimary: Color(0xFFF2EFE6),
  inkSecondary: Color(0xFFA9A396),
  inkMuted: Color(0xFF75705F),

  accent: Color(0xFFC9A227),
  onAccent: Color(0xFF14120B),

  // Semantique : valeurs propres, volontairement decalees des couleurs de
  // mana. Avant le lot B, success valait exactement manaGreen (0xFF4CAF50) et
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
      backgroundColor: darkPalette.raised,
      selectedItemColor: darkPalette.accent,
      // inkSecondary, PAS inkMuted : ce sont de vrais libelles de texte, et
      // inkMuted est documente comme reserve au non-textuel -- il tombait ici
      // a 3,56:1 sur raised, sous le seuil AA de 4,5.
      unselectedItemColor: darkPalette.inkSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    extensions: const <ThemeExtension<dynamic>>[darkPalette],
  );
}
