// Fichier : lib/theme/magic_palette.dart
// Jetons de couleur qui dependent du theme, exposes via ThemeExtension.
//
// Frontiere avec AppColors : ici vivent les couleurs qui changeront quand le
// theme clair "Table" arrivera (surfaces, encres, accent, semantique). Les
// couleurs de domaine Magic (mana, rarete, power level, badges) restent des
// const dans AppColors : elles ne dependent pas du theme.

import 'package:flutter/material.dart';

@immutable
class MagicPalette extends ThemeExtension<MagicPalette> {
  const MagicPalette({
    required this.canvas,
    required this.raised,
    required this.overlay,
    required this.line,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Fond de page.
  final Color canvas;

  /// Fond des cartes et tuiles posees sur le canvas.
  final Color raised;

  /// Fond des modales et menus.
  final Color overlay;

  /// Separateurs et contours.
  final Color line;

  final Color inkPrimary;
  final Color inkSecondary;

  /// Reserve aux elements non textuels (icones decoratives, puces).
  /// Ne jamais s'en servir pour du texte : le contraste n'est pas garanti.
  final Color inkMuted;

  final Color accent;

  /// Couleur de texte posee SUR l'accent.
  final Color onAccent;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Raccourci d'acces. Leve si le ThemeData n'enregistre pas l'extension --
  /// c'est voulu : un ecran sans palette est un bug de configuration, pas un
  /// cas a rattraper silencieusement par des couleurs par defaut.
  static MagicPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<MagicPalette>();
    assert(palette != null,
        'MagicPalette absente du ThemeData. Utiliser buildAppTheme().');
    return palette!;
  }

  @override
  MagicPalette copyWith({
    Color? canvas,
    Color? raised,
    Color? overlay,
    Color? line,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return MagicPalette(
      canvas: canvas ?? this.canvas,
      raised: raised ?? this.raised,
      overlay: overlay ?? this.overlay,
      line: line ?? this.line,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  MagicPalette lerp(ThemeExtension<MagicPalette>? other, double t) {
    if (other is! MagicPalette) return this;
    return MagicPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      line: Color.lerp(line, other.line, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
