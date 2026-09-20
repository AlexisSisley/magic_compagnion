// Fichier : lib/theme/app_text_styles.dart
// Sprint 12, US-12.6 : Styles texte centralises de Magic Companion.
// Remplace les 325+ occurrences de GoogleFonts.cinzel() hardcodes.
// Usage : import 'package:magic_companion/theme/app_text_styles.dart';
//
// ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
//   R O A D   P O N E G L Y P H S
// │                                                               │
//   Il existe 4 Road Poneglyphs dans ce projet.
// │ Chacun contient un fragment de la verite.                     │
//   Trouve-les tous et tu atteindras Laugh Tale.
// │                                                               │
//   Fragment 1/4 : "La volonte" ........ life_counter_page.dart
// │ Fragment 2/4 : "Le tresor"  ........ app_colors.dart          │
//   Fragment 3/4 : "Le lien"   ........ app_database.dart
// │ Fragment 4/4 : "Le chemin" ........ app_router.dart           │
//
// │ "Les Poneglyphs ne mentent jamais.                            │
//    Seul celui qui les reunit tous
// │  peut decouvrir la verite du monde."                          │
//                — Nico Robin
// └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Styles texte centralises de Magic Companion.
/// Toutes les occurrences de GoogleFonts.cinzel() doivent etre remplacees
/// par des references AppTextStyles.
///
/// Repartition des polices : Cinzel aux titres, Source Sans 3 au texte
/// courant. Verrouillee par test/theme/app_text_styles_test.dart.
abstract final class AppTextStyles {
  // ============================================================
  // TITRES (Cinzel, la police thematique de l'app)
  //
  // Cinzel est une romaine a capitales : elle porte un titre, pas un
  // paragraphe. Sous 14px elle n'est plus lisible, d'ou la frontiere posee
  // ici -- seuls les quatre helpers de titre ci-dessous la gardent.
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
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textSecondary,
      fontSize: fontSize ?? 14,
    );

  /// Label (12px)
  static TextStyle label({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 12,
    );

  /// Texte de bouton (14px, bold)
  static TextStyle buttonText({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textOnPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.bold,
    );

  // ============================================================
  // BODY TEXT
  // ============================================================

  /// Texte body generique (14px, normal, blanc)
  static TextStyle body({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 14,
    );

  // ============================================================
  // TEXTE BOLD
  // ============================================================

  /// Texte bold generique
  static TextStyle bold({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize ?? 14,
      fontWeight: FontWeight.bold,
    );

  // ============================================================
  // TAB LABELS
  // ============================================================

  /// Style des onglets actifs
  static TextStyle tabActive({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontWeight: FontWeight.bold,
      fontSize: fontSize,
    );

  /// Style des onglets inactifs
  static TextStyle tabInactive({Color? color, double? fontSize}) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textMuted,
      fontSize: fontSize,
    );

  // ============================================================
  // ECHAPPATOIRE GENERIQUE
  // ============================================================

  /// Texte courant, pour les cas non couverts par les methodes ci-dessus.
  ///
  /// Source Sans 3 : humaniste dessinee pour l'interface, lisible en petite
  /// taille, et de proportions classiques qui s'accordent avec Cinzel.
  /// Le choix de la police est isole ici et dans les helpers ci-dessus : il
  /// reste substituable en un point.
  ///
  /// Remplace l'ancien `cinzel()`, qui etait documente "a utiliser en dernier
  /// recours" et servait de style par defaut sur 182 sites.
  static TextStyle text({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );

  // ============================================================
  // LIFE COUNTER (zone joueur V4)
  // ============================================================

  /// Chiffre du cadran de vie (88px, w300).
  ///
  /// Roboto Mono, et pas par gout du style : ses chiffres ont tous la meme
  /// largeur, donc le nombre ne se decale pas quand il change de valeur.
  /// Avec une police proportionnelle, passer de 40 a 39 deplace le chiffre de
  /// quelques pixels, et le compteur bouge sous le doigt a chaque tap — sur un
  /// ecran qu'on tape des dizaines de fois par partie, ca se remarque.
  static TextStyle lifeNumeral({Color? color, double? fontSize}) =>
      GoogleFonts.robotoMono(
    color: color ?? AppColors.textPrimary,
    fontSize: fontSize ?? 88,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
  );

  /// Badge de delta en attente sous le chiffre de vie (20px, semibold).
  static TextStyle lifeBadge({Color? color, double? fontSize}) => TextStyle(
    color: color ?? AppColors.textPrimary,
    fontSize: fontSize ?? 20,
    fontWeight: FontWeight.w600,
  );

  /// Libellé des paliers du mode ajustement, ex. "+5"/"-10" (15px, w700).
  static TextStyle lifeStepLabel({Color? color, double? fontSize}) =>
      TextStyle(
    color: color ?? AppColors.textPrimary,
    fontSize: fontSize ?? 15,
    fontWeight: FontWeight.w700,
  );

  /// Puce de la poignée conditionnelle (bandeau résumé), ex. "☠ 3" (13px, w700).
  static TextStyle lifeHandleChip({Color? color, double? fontSize}) =>
      TextStyle(
    color: color ?? AppColors.textPrimary,
    fontSize: fontSize ?? 13,
    fontWeight: FontWeight.w700,
  );
}
