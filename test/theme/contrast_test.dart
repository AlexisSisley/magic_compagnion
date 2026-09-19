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
    test('chaque couleur de feedback atteint AA sur le fond de page', () {
      for (final entry in {
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
        'info': p.info,
      }.entries) {
        expect(contrastRatio(entry.value, p.canvas), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} est illisible sur le fond de page');
      }
    });
  });

  group("contraste du texte pose sur l'accent", () {
    test('onAccent atteint AA sur accent', () {
      expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
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
