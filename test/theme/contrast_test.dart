// Fichier : test/theme/contrast_test.dart
// Verrouille les ratios de contraste WCAG de la palette Grimoire. Une valeur
// de couleur peut etre changee ; elle ne peut pas l'etre au point de rendre
// un texte illisible sans que ce test le dise.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';

/// Luminance relative WCAG 2.1.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Ratio de contraste WCAG 2.1, entre 1 et 21.
double contrastRatio(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final p = darkPalette;

  // Les surfaces sur lesquelles du texte peut se poser. Un jeton de feedback
  // vit sur une carte ou dans une modale, pas seulement sur le fond de page :
  // le tester sur `canvas` seul laisse passer un badge illisible sur `raised`.
  final surfaces = <String, Color>{
    'canvas': p.canvas,
    'raised': p.raised,
    'overlay': p.overlay,
  };

  group('contraste sur le fond de page', () {
    test('le texte principal atteint AAA (7:1)', () {
      expect(contrastRatio(p.inkPrimary, p.canvas), greaterThanOrEqualTo(7.0));
    });

    test('le texte secondaire atteint AA (4.5:1)', () {
      expect(contrastRatio(p.inkSecondary, p.canvas), greaterThanOrEqualTo(4.5));
    });

    test("l'accent atteint AA (4.5:1)", () {
      expect(contrastRatio(p.accent, p.canvas), greaterThanOrEqualTo(4.5));
    });
  });

  group('contraste sur les surfaces surelevees', () {
    test('le texte principal atteint AAA sur une carte', () {
      expect(contrastRatio(p.inkPrimary, p.raised), greaterThanOrEqualTo(7.0));
    });

    test('le texte secondaire atteint AA sur une carte', () {
      expect(contrastRatio(p.inkSecondary, p.raised), greaterThanOrEqualTo(4.5));
    });
  });

  group('contraste des jetons semantiques', () {
    test('chaque couleur de feedback atteint AA sur les trois surfaces', () {
      for (final token in {
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
        'info': p.info,
        'accent': p.accent,
      }.entries) {
        for (final surface in surfaces.entries) {
          expect(contrastRatio(token.value, surface.value),
              greaterThanOrEqualTo(4.5),
              reason: '${token.key} est illisible sur ${surface.key}');
        }
      }
    });
  });

  group("contraste du texte pose sur l'accent", () {
    test('onAccent atteint AA sur accent', () {
      expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
    });
  });

  // Le trou par lequel C-1 est passe : contrast_test verrouillait les JETONS,
  // mais rien ne verifiait ce que `buildAppTheme()` en FAIT. La premiere
  // version de ce lot posait `inkMuted` (#75705F) en couleur de libelle
  // d'onglet inactif sur `raised` (#191820), soit 3,56:1 -- sous AA, et
  // contre la doc du jeton, qui interdit explicitement son usage pour du
  // texte. Ces assertions regardent le ThemeData reellement construit.
  group('contraste des couleurs de texte posees par buildAppTheme', () {
    final theme = buildAppTheme();
    final navBar = theme.bottomNavigationBarTheme;

    test("le fond de la barre d'onglets est bien une surface connue", () {
      expect(navBar.backgroundColor, isNotNull);
      expect(surfaces.values, contains(navBar.backgroundColor));
    });

    test("le libelle d'un onglet INACTIF atteint AA sur le fond de la barre",
        () {
      expect(
        contrastRatio(navBar.unselectedItemColor!, navBar.backgroundColor!),
        greaterThanOrEqualTo(4.5),
        reason: "les libelles d'onglets inactifs sont du texte : inkMuted, "
            "documente comme non textuel, n'a rien a faire ici",
      );
    });

    test("le libelle d'un onglet ACTIF atteint AA sur le fond de la barre",
        () {
      expect(
        contrastRatio(navBar.selectedItemColor!, navBar.backgroundColor!),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  // Le FAB "Nouveau Deck" posait du blanc sur primaryShade800 : 1,97:1 avec
  // le jaune Material, 3,77:1 meme avec la rampe or. Illisible dans les deux
  // cas, et aucun test ne le voyait -- contrast_test ne regardait que les
  // jetons de la palette, or la rampe d'accent vit dans AppColors.
  group("contraste des encres posees sur l'accent et sa rampe", () {
    // shade900 est volontairement absent : c'est le barreau sombre de la
    // rampe, reserve aux fonds et aux bordures. Meme l'encre noire n'y
    // atteint que 4,16:1, et l'eclaircir assez pour porter du texte
    // ecraserait l'ecart avec shade800. La regle est donc "shade900 ne porte
    // pas de texte", et c'est le balayage de source ci-dessous qui la tient.
    final surfacesAccent = <String, Color>{
      'accent': darkPalette.accent,
      'primaryShade700': AppColors.primaryShade700,
      'primaryShade800': AppColors.primaryShade800,
    };

    test("l'encre designee pour les fonds d'accent atteint AA partout", () {
      for (final entry in surfacesAccent.entries) {
        expect(contrastRatio(AppColors.textOnPrimary, entry.value),
            greaterThanOrEqualTo(4.5),
            reason: 'textOnPrimary est illisible sur ${entry.key}');
      }
    });

    test('la rampe reste une echelle decroissante en luminance', () {
      // shade700 plus clair que shade800 plus clair que shade900 : c'est ce
      // qui fait de ces trois valeurs une rampe et non trois ors au hasard.
      expect(luminance(AppColors.primaryShade700),
          greaterThan(luminance(AppColors.primaryShade800)));
      expect(luminance(AppColors.primaryShade800),
          greaterThan(luminance(AppColors.primaryShade900)));
    });
  });

  // L'assertion de valeur ci-dessus dit quelle encre CONVIENT ; celle-ci
  // verifie qu'aucun site n'en utilise une autre. C'est la version balayage
  // de source, le seul moyen d'attraper un appelant : un test de couleurs ne
  // sait pas quelle encre chaque bouton pose sur son fond.
  group("aucun bouton ne pose d'encre claire sur la rampe d'accent", () {
    test('backgroundColor primaryShade* + foregroundColor textPrimary', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lignes = entity.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          if (!lignes[i].contains('backgroundColor: AppColors.primaryShade')) {
            continue;
          }
          // Le foregroundColor d'un styleFrom suit de pres son
          // backgroundColor ; trois lignes couvrent les mises en forme du
          // depot sans ramasser le bouton suivant.
          final fin = (i + 4).clamp(0, lignes.length);
          for (var j = i + 1; j < fin; j++) {
            if (lignes[j].contains('foregroundColor: AppColors.textPrimary')) {
              offenders.add('${entity.path.replaceAll(r'\', '/')}:${j + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty,
          reason: "Blanc sur l'or de la rampe ne depasse pas 3,8:1. Utiliser "
              'AppColors.textOnPrimary :\n${offenders.join('\n')}');
    });
  });

  group('hierarchie des surfaces', () {
    test('canvas, raised et overlay sont trois valeurs distinctes et croissantes',
        () {
      expect(luminance(p.canvas), lessThan(luminance(p.raised)));
      expect(luminance(p.raised), lessThan(luminance(p.overlay)));
    });
  });
}
