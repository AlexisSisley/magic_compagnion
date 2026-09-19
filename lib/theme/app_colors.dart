// Fichier : lib/theme/app_colors.dart
// Sprint 12, US-12.6 : Couleurs centralisees de Magic Companion.
// Remplace les 1625+ occurrences de Colors.xxx et Color(0x...) hardcodes.
// Usage : import 'package:magic_companion/theme/app_colors.dart';

import 'package:flutter/material.dart';

// ┌─────────────────────────────────────────┐
// │  WANTED  DEAD OR ALIVE                  │
// │                                         │
// │  « LE DEVELOPPEUR CURIEUX »             │
// │                                         │
// │  Reward: B 0,000,000,000                │
// │                                         │
// │  Tu as trouve le tresor cache dans      │
// │  les couleurs. Bienvenue dans           │
// │  l'equipage des Mugiwara.               │
// └─────────────────────────────────────────┘

/// Couleurs centralisees de Magic Companion.
/// Toutes les couleurs hardcodees doivent etre remplacees par des references AppColors.
abstract final class AppColors {
  // ============================================================
  // BACKGROUNDS
  // ============================================================

  /// Fond principal des scaffolds et pages. Vaut MagicPalette.canvas.
  ///
  /// Les 84 ecrans qui posent ce fond a la main doivent afficher le meme noir
  /// que ceux qui laissent faire `ThemeData.scaffoldBackgroundColor` -- sinon
  /// deux noirs coexistent, y compris entre un ecran et la modale posee
  /// dessus.
  static const Color scaffoldBackground = Color(0xFF0E0E11);

  /// Fond des dialogues et modales. Vaut MagicPalette.overlay.
  static const Color dialogBackground = Color(0xFF2A2733);

  /// Fond des cartes et containers sureleves. Vaut MagicPalette.raised.
  static const Color cardBackground = Color(0xFF191820);

  /// Fond des surfaces sombres (0xFF1E1E1E)
  static const Color surfaceDark = Color(0xFF1E1E1E);

  /// Fond tres sombre (0xFF121212)
  static const Color surfaceDarkest = Color(0xFF121212);

  /// Fond de la barre d'app et du header
  static const Color appBarBackground = Colors.black;

  /// Fond semi-transparent pour les overlays
  static const Color overlayLight = Colors.black26;
  static const Color overlayMedium = Colors.black45;
  static const Color overlayDark = Colors.black54;
  static const Color overlayVeryDark = Colors.black87;

  // ============================================================
  // PRIMARY / ACCENT
  // ============================================================

  /// Couleur primaire d'accent. Vaut MagicPalette.accent : l'or patine
  /// Grimoire, et non plus `Colors.yellow` -- le jaune pur vibre sur fond
  /// noir et fatigue en lecture longue.
  static const Color primary = Color(0xFFC9A227);
  static const Color primaryDark = Color(0xFFC7A94E);
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color primaryBright = Color(0xFFFFD700);

  /// Accent bleu
  static const Color accent = Colors.blueAccent;

  /// Accent vert
  static const Color accentGreen = Colors.greenAccent;

  /// Accent orange
  static const Color accentOrange = Colors.orangeAccent;

  /// Accent rouge
  static const Color accentRed = Colors.redAccent;

  /// Accent violet
  static const Color accentPurple = Colors.purpleAccent;

  /// Couleur ambre (foil, prix, etc.)
  static const Color amber = Colors.amber;

  /// Transparent
  static const Color transparent = Colors.transparent;

  // ============================================================
  // TEXT
  // ============================================================

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white54;
  static const Color textDisabled = Colors.white30;
  static const Color textOnPrimary = Colors.black;

  // ============================================================
  // BORDERS / DIVIDERS
  // ============================================================

  static const Color borderLight = Colors.white10;
  static const Color borderSubtle = Colors.white12;
  static const Color borderMedium = Colors.white24;
  static const Color borderFaint = Colors.white38;
  static const Color divider = Colors.white24;

  // ============================================================
  // MTG MANA COLORS
  // ============================================================

  static const Color manaWhite = Color(0xFFF0F2C0);
  static const Color manaBlue = Color(0xFF4287f5);
  static const Color manaBlack = Color(0xFF333333);
  static const Color manaRed = Color(0xFFeb4034);
  static const Color manaGreen = Color(0xFF4caf50);
  static const Color manaColorless = Color(0xFF9e9e9e);
  static const Color manaMulti = Color(0xFFD4AF37);

  // ============================================================
  // RARITY
  // ============================================================

  static const Color rarityCommon = Colors.white;
  static const Color rarityUncommon = Color(0xFFC0C0C0);
  static const Color rarityRare = Color(0xFFFFD700);
  static const Color rarityMythic = Color(0xFFFF4500);

  // ============================================================
  // STATUS / FEEDBACK
  // ============================================================

  // Valeurs Grimoire, volontairement decalees des couleurs de mana ci-dessus.
  // Avant ce lot, `success` valait EXACTEMENT `manaGreen` (0xFF4CAF50) : un
  // badge "possedee" et une carte verte etaient indiscernables a l'ecran.
  // L'ecart minimal est verrouille par test/theme/magic_palette_test.dart.
  static const Color success = Color(0xFF6FD98F);
  static const Color warning = Color(0xFFFFA94D);
  static const Color error = Color(0xFFFF7A6E);
  static const Color info = Color(0xFF7FB2FF);

  // ============================================================
  // SYNERGY / SALT / POWER LEVEL (Sprint 11-12)
  // ============================================================

  static const Color synergyPositive = Colors.green;
  static const Color synergyNegative = Colors.red;
  static const Color synergyNeutral = Colors.grey;

  static const Color saltHigh = Colors.red;
  static const Color saltLow = Colors.green;

  static const Color powerCasual = Colors.green;
  static const Color powerFocused = Colors.teal;
  static const Color powerOptimized = Colors.orange;
  static const Color powerHigh = Colors.deepOrange;
  static const Color powerCEDH = Colors.red;

  // ============================================================
  // COLLECTION BADGES (Sprint 9)
  // ============================================================

  static const Color badgeOwned = Colors.green;
  static const Color badgeFoil = Colors.purple;
  static const Color badgeWishlist = Colors.blue;

  // ============================================================
  // DECK ZONES
  // ============================================================

  static const Color deckMainboard = Colors.yellow;
  static const Color deckSideboard = Colors.blueAccent;
  static const Color deckConsidering = Colors.orangeAccent;
  static const Color deckWishlist = Colors.purple;

  // ============================================================
  // LEGACY COMPATIBILITY HELPERS
  // ============================================================

  /// Rampe d'accent, derivee de [primary] (#C9A227).
  ///
  /// Trois `const`, et non plus des getters `Colors.yellow.shade*` : 142
  /// sites lisent cette rampe, et tant qu'elle restait Material, l'app
  /// portait deux accents concurrents -- l'or patine du jeton d'un cote,
  /// le jaune vif de la rampe de l'autre, souvent dans le meme ecran.
  ///
  /// Echelle decroissante en luminance (700 > 800 > 900), verrouillee par
  /// test/theme/contrast_test.dart.
  ///
  /// Ces trois valeurs sont des FONDS et des BORDURES. `shade900` n'atteint
  /// que 3,82:1 sur le canvas : ne pas s'en servir pour du texte. L'encre a
  /// poser dessus est [textOnPrimary], jamais [textPrimary] -- du blanc n'y
  /// depasse pas 3,8:1.
  static const Color primaryShade700 = Color(0xFFB8922A);

  static const Color primaryShade800 = Color(0xFFA37E22);

  static const Color primaryShade900 = Color(0xFF8A6A1B);

  /// Pour les usages de Colors.grey.shade800
  static Color get greyShade800 => Colors.grey.shade800;

  /// Pour les usages de Colors.grey.shade900
  static Color get greyShade900 => Colors.grey.shade900;
}
