// Fichier : test/theme/magic_palette_test.dart
// Verifie que MagicPalette est atteignable depuis le contexte, que lerp
// interpole bien chaque jeton, et que les jetons semantiques ne se confondent
// plus avec les couleurs de mana.
//
// Le test de non-regression du lot A ("aucune valeur n'a bouge") a disparu :
// sa fonction etait de prouver que brancher la ThemeExtension ne deplacait
// aucun pixel, et elle est remplie depuis que le lot A est commite. Au lot B
// tous les jetons changent de valeur, y compris onAccent — le garder serait
// verrouiller l'ancienne palette. Le garde-fou durable est contrast_test.dart,
// qui verifie une propriete vraie quelles que soient les valeurs.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';

void main() {
  testWidgets('MagicPalette est resolvable depuis le contexte', (tester) async {
    MagicPalette? palette;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        palette = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(palette, isNotNull);
  });

  // Les 13 jetons, nommes, pour que lerp et copyWith soient verifies par
  // ENUMERATION plutot que sur un echantillon. Un 14e champ ajoute a
  // MagicPalette et oublie dans lerp() est le bug silencieux classique des
  // ThemeExtension : la version precedente de ce test n'assertait que canvas
  // et accent, donc 11 champs sur 13 pouvaient etre oublies sans rien casser.
  Map<String, Color> jetons(MagicPalette p) => {
        'canvas': p.canvas,
        'raised': p.raised,
        'overlay': p.overlay,
        'line': p.line,
        'inkPrimary': p.inkPrimary,
        'inkSecondary': p.inkSecondary,
        'inkMuted': p.inkMuted,
        'accent': p.accent,
        'onAccent': p.onAccent,
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
        'info': p.info,
      };

  /// Palette dont chaque jeton porte une valeur DIFFERENTE, derivee de son
  /// rang : deux champs intervertis dans `lerp` ou `copyWith` se voient, ce
  /// qu'une palette uniformement noire ne montrerait pas.
  MagicPalette paletteDistincte(int base) {
    final c = <Color>[
      for (var i = 0; i < 13; i++) Color(0xFF000000 + base + i * 0x010101),
    ];
    return MagicPalette(
      canvas: c[0],
      raised: c[1],
      overlay: c[2],
      line: c[3],
      inkPrimary: c[4],
      inkSecondary: c[5],
      inkMuted: c[6],
      accent: c[7],
      onAccent: c[8],
      success: c[9],
      warning: c[10],
      danger: c[11],
      info: c[12],
    );
  }

  test('le jeu de jetons de reference couvre bien les 13 champs', () {
    // Filet du filet : si un champ est ajoute a MagicPalette sans etre ajoute
    // a `jetons`, les deux tests ci-dessous cesseraient de le couvrir en
    // silence. Ce compte le dit.
    expect(jetons(paletteDistincte(0)).length, 13);
  });

  test('lerp interpole les 13 jetons', () {
    final a = paletteDistincte(0x000000);
    final b = paletteDistincte(0x606060);

    final mid = a.lerp(b, 0.5);

    final ja = jetons(a);
    final jb = jetons(b);
    final jmid = jetons(mid);
    for (final nom in ja.keys) {
      expect(jmid[nom], Color.lerp(ja[nom], jb[nom], 0.5),
          reason: 'lerp oublie le jeton $nom');
    }
  });

  test("lerp vers autre chose qu'une MagicPalette rend this", () {
    final a = paletteDistincte(0);
    expect(a.lerp(null, 0.5), same(a));
  });

  test('copyWith remplace le jeton vise et ne touche a aucun autre', () {
    final base = paletteDistincte(0x000000);
    final autre = paletteDistincte(0x606060);
    final jbase = jetons(base);
    final jautre = jetons(autre);

    // Un champ a la fois : on remplace le jeton vise et on verifie que les 12
    // autres sont intacts. C'est ce qui attrape un copyWith qui affecte la
    // mauvaise propriete -- la faute de frappe typique du patron.
    final remplacants = <String, MagicPalette Function(Color)>{
      'canvas': (c) => base.copyWith(canvas: c),
      'raised': (c) => base.copyWith(raised: c),
      'overlay': (c) => base.copyWith(overlay: c),
      'line': (c) => base.copyWith(line: c),
      'inkPrimary': (c) => base.copyWith(inkPrimary: c),
      'inkSecondary': (c) => base.copyWith(inkSecondary: c),
      'inkMuted': (c) => base.copyWith(inkMuted: c),
      'accent': (c) => base.copyWith(accent: c),
      'onAccent': (c) => base.copyWith(onAccent: c),
      'success': (c) => base.copyWith(success: c),
      'warning': (c) => base.copyWith(warning: c),
      'danger': (c) => base.copyWith(danger: c),
      'info': (c) => base.copyWith(info: c),
    };
    expect(remplacants.length, 13);

    for (final entry in remplacants.entries) {
      final nom = entry.key;
      final attendu = jautre[nom]!;
      final copie = jetons(entry.value(attendu));

      expect(copie[nom], attendu, reason: 'copyWith ignore le jeton $nom');
      for (final autreNom in jbase.keys) {
        if (autreNom == nom) continue;
        expect(copie[autreNom], jbase[autreNom],
            reason: 'copyWith de $nom a aussi change $autreNom');
      }
    }
  });

  test('copyWith sans argument rend une palette egale', () {
    final base = paletteDistincte(0x101010);
    expect(base.copyWith(), base);
  });

  group('separation semantique / domaine Magic', () {
    /// Distance euclidienne dans l'espace RGB. Grossiere, mais suffisante
    /// pour detecter deux couleurs qu'un oeil ne separera pas : en-dessous
    /// de 60, les deux pastilles se confondent sur un fond sombre.
    double rgbDistance(Color a, Color b) {
      final dr = ((a.r - b.r) * 255).abs();
      final dg = ((a.g - b.g) * 255).abs();
      final db = ((a.b - b.b) * 255).abs();
      return math.sqrt(dr * dr + dg * dg + db * db);
    }

    test('le vert succes ne se confond pas avec le vert mana', () {
      expect(rgbDistance(darkPalette.success, AppColors.manaGreen),
          greaterThan(60));
    });

    test('le rouge danger ne se confond pas avec le rouge mana', () {
      expect(rgbDistance(darkPalette.danger, AppColors.manaRed),
          greaterThan(60));
    });

    test('le bleu info ne se confond pas avec le bleu mana', () {
      expect(rgbDistance(darkPalette.info, AppColors.manaBlue),
          greaterThan(60));
    });

    // Les memes assertions sur AppColors, et ce n'est pas une redondance :
    // 104 sites dans 40 fichiers lisent encore AppColors.success/error/info,
    // pas le jeton. Tant que AppColors.success valait Colors.green, le badge
    // "possedee" restait indiscernable d'une carte verte A L'ECRAN, quoi que
    // dise la palette. Ce sont ces trois-la qui rendent la correction reelle.
    test('AppColors.success ne se confond pas avec AppColors.manaGreen', () {
      expect(rgbDistance(AppColors.success, AppColors.manaGreen),
          greaterThan(60));
    });

    test('AppColors.error ne se confond pas avec AppColors.manaRed', () {
      expect(rgbDistance(AppColors.error, AppColors.manaRed),
          greaterThan(60));
    });

    test('AppColors.info ne se confond pas avec AppColors.manaBlue', () {
      expect(rgbDistance(AppColors.info, AppColors.manaBlue),
          greaterThan(60));
    });
  });

  // Les 2 068 sites AppColors existants ne sont pas convertis vers la palette
  // (hors perimetre), donc la seule facon qu'ils affichent Grimoire est que
  // les const AppColors PORTENT les valeurs Grimoire. Sans ca, deux noirs
  // coexistent : celui du ThemeData pour les ecrans qui ne posent rien, celui
  // d'AppColors pour les 84 qui posent leur fond a la main -- y compris entre
  // un ecran et la modale posee dessus.
  group('AppColors porte les valeurs Grimoire', () {
    test('les surfaces valent les jetons correspondants', () {
      expect(AppColors.scaffoldBackground, darkPalette.canvas);
      expect(AppColors.cardBackground, darkPalette.raised);
      expect(AppColors.dialogBackground, darkPalette.overlay);
    });

    test("l'accent vaut le jeton accent", () {
      expect(AppColors.primary, darkPalette.accent);
    });

    test('les quatre jetons semantiques valent ceux de la palette', () {
      expect(AppColors.success, darkPalette.success);
      expect(AppColors.warning, darkPalette.warning);
      expect(AppColors.error, darkPalette.danger);
      expect(AppColors.info, darkPalette.info);
    });

    test('les couleurs de domaine Magic n\'ont PAS bouge', () {
      // La frontiere posee par la contrainte globale : mana, rarete, power
      // level et badges ne dependent pas du theme. Les aligner sur Grimoire
      // serait exactement l'erreur que la Task 2 corrige.
      expect(AppColors.manaWhite, const Color(0xFFF0F2C0));
      expect(AppColors.manaBlue, const Color(0xFF4287f5));
      expect(AppColors.manaBlack, const Color(0xFF333333));
      expect(AppColors.manaRed, const Color(0xFFeb4034));
      expect(AppColors.manaGreen, const Color(0xFF4caf50));
      expect(AppColors.manaColorless, const Color(0xFF9e9e9e));
      expect(AppColors.rarityMythic, const Color(0xFFFF4500));
    });

    test('les encres restent les blancs translucides', () {
      // Decision assumee : inkMuted (#75705F) tombe a 3,55:1 sur raised, sous
      // AA, alors que white54 y tient 5,89:1. 224 sites lisent textMuted, dont
      // beaucoup pour du texte. Migrer les encres les casserait tous -- c'est
      // la meme faute que C-1, a 224 exemplaires.
      expect(AppColors.textPrimary, Colors.white);
      expect(AppColors.textSecondary, Colors.white70);
      expect(AppColors.textMuted, Colors.white54);
    });
  });
}
