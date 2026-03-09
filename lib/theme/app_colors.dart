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

  /// Fond principal des scaffolds et pages (0xFF1A1A1A - utilise 87 fois)
  static const Color scaffoldBackground = Color(0xFF1A1A1A);

  /// Fond secondaire pour les dialogs, modals (0xFF1A1A2E)
  static const Color dialogBackground = Color(0xFF1A1A2E);

  /// Fond des cartes/containers sureleves (0xFF2A2A2A)
  static const Color cardBackground = Color(0xFF2A2A2A);

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

  /// Couleur primaire d'accent (jaune dore MTG)
  static const Color primary = Colors.yellow;
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

  static const Color success = Colors.green;
  static const Color warning = Colors.orange;
  static const Color error = Colors.red;
  static const Color info = Colors.blue;

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

  /// Pour les usages de Colors.yellow.shade700
  static Color get primaryShade700 => Colors.yellow.shade700;

  /// Pour les usages de Colors.yellow.shade800
  static Color get primaryShade800 => Colors.yellow.shade800;

  /// Pour les usages de Colors.yellow.shade900
  static Color get primaryShade900 => Colors.yellow.shade900;

  /// Pour les usages de Colors.grey.shade800
  static Color get greyShade800 => Colors.grey.shade800;

  /// Pour les usages de Colors.grey.shade900
  static Color get greyShade900 => Colors.grey.shade900;
}
