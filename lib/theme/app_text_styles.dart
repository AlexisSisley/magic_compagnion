// Fichier : lib/theme/app_text_styles.dart
// Sprint 12, US-12.6 : Styles texte centralises de Magic Companion.
// Remplace les 325+ occurrences de GoogleFonts.cinzel() hardcodes.
// Usage : import 'package:magic_companion/theme/app_text_styles.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles texte centralises de Magic Companion.
/// Toutes les occurrences de GoogleFonts.cinzel() doivent etre remplacees
/// par des references AppTextStyles.
abstract final class AppTextStyles {
  // ============================================================
  // TITRES (Cinzel, la police thematique de l'app)
  // ============================================================

  /// Titre de page principal (24px, bold, blanc)
  static TextStyle pageTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 24,
      fontWeight: FontWeight.bold,
    );

  /// Titre de section (18px, bold)
  static TextStyle sectionTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 18,
      fontWeight: FontWeight.bold,
    );

  /// Titre de carte/item (16px, semibold)
  static TextStyle cardTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 16,
      fontWeight: FontWeight.w600,
    );

  /// Titre d'AppBar (16px, semibold)
  static TextStyle appBarTitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 16,
      fontWeight: FontWeight.w600,
    );

  /// Sous-titre (14px, normal)
  static TextStyle subtitle({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textSecondary,
      fontSize: fontSize ?? 14,
    );

  /// Label (12px)
  static TextStyle label({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 12,
    );

  /// Texte de bouton (14px, bold)
  static TextStyle buttonText({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textOnPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.bold,
    );

  // ============================================================
  // BODY TEXT
  // ============================================================

  /// Texte body generique (14px, normal, blanc)
  static TextStyle body({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 14,
    );

  // ============================================================
  // TEXTE BOLD (Cinzel bold)
  // ============================================================

  /// Texte bold generique avec Cinzel
  static TextStyle bold({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.bold,
    );

  // ============================================================
  // TAB LABELS
  // ============================================================

  /// Style des onglets actifs
  static TextStyle tabActive({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );

  /// Style des onglets inactifs
  static TextStyle tabInactive({Color? color, double? fontSize}) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textMuted,
      fontSize: fontSize,
    );

  // ============================================================
  // SHORTCUT : Cinzel avec parametres custom
  // ============================================================

  /// Cinzel generique pour les cas non couverts par les methodes ci-dessus.
  /// A utiliser en dernier recours.
  static TextStyle cinzel({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) =>
    GoogleFonts.cinzel(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
}
