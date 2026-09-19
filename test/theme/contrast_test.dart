// Fichier : test/theme/contrast_test.dart
// Verrouille les ratios de contraste WCAG de la palette Grimoire. Une valeur
// de couleur peut etre changee ; elle ne peut pas l'etre au point de rendre
// un texte illisible sans que ce test le dise.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_theme.dart';

/// Luminance relative WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Ratio de contraste WCAG 2.1, entre 1 et 21.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
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

  group('hierarchie des surfaces', () {
    test('canvas, raised et overlay sont trois valeurs distinctes et croissantes',
        () {
      expect(_luminance(p.canvas), lessThan(_luminance(p.raised)));
      expect(_luminance(p.raised), lessThan(_luminance(p.overlay)));
    });
  });
}
