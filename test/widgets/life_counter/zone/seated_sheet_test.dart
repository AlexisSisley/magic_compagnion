// test/widgets/life_counter/zone/seated_sheet_test.dart
//
// Écran de test : 800 x 600 logiques (valeur par défaut de `flutter_test`).
// Pour un siège latéral, la largeur LOCALE de la feuille est donc 600 et sa
// hauteur locale 800.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/widgets/life_counter/zone/seated_sheet.dart';

const _screen = Size(800, 600);

/// Monte une app vide et rend un contexte sous son `Navigator`.
/// [media] remplace le `MediaQuery` vu par la route (clavier, encoche).
Future<BuildContext> _pumpHost(
  WidgetTester tester, {
  MediaQueryData Function(MediaQueryData)? media,
}) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      builder: media == null
          ? null
          : (context, child) =>
                MediaQuery(data: media(MediaQuery.of(context)), child: child!),
      home: Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return ctx;
}

/// La surface de la feuille : le `Material` le plus proche du contenu.
Finder _sheetOf(Finder content) =>
    find.ancestor(of: content, matching: find.byType(Material)).first;

void main() {
  testWidgets('la feuille porte la rotation de son siège', (tester) async {
    final ctx = await _pumpHost(tester);

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 2,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(
      find.ancestor(
        of: find.text('contenu'),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(rotated.quarterTurns, 2);
  });

  testWidgets(
    "un siège du bas garde l'habillage de l'ancien tiroir : ancré en bas, "
    'pleine largeur, greyShade800, rayon haut 18',
    (tester) async {
      final ctx = await _pumpHost(tester);

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 0,
        builder: (_) => const Text('contenu'),
      );
      await tester.pumpAndSettle();

      final sheetFinder = _sheetOf(find.text('contenu'));
      final rect = tester.getRect(sheetFinder);
      expect(rect.bottom, moreOrLessEquals(_screen.height));
      expect(rect.left, moreOrLessEquals(0));
      expect(rect.width, moreOrLessEquals(_screen.width));

      final sheet = tester.widget<Material>(sheetFinder);
      expect(sheet.color, AppColors.greyShade800);
      expect(
        sheet.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(18)),
      );
    },
  );

  testWidgets(
    "siège du haut : en cours d'animation la feuille arrive par le HAUT "
    "de l'écran, pas par le bas",
    (tester) async {
      final ctx = await _pumpHost(tester);

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 2,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final mid = tester.getRect(_sheetOf(find.text('contenu')));
      expect(
        mid.top,
        lessThan(0),
        reason:
            'la feuille doit encore dépasser du bord haut (son bord à '
            'elle) en cours de glissade',
      );
      expect(
        mid.bottom,
        lessThan(_screen.height / 2),
        reason:
            "une glissade en repère écran la ferait traverser l'écran "
            'depuis le bas',
      );

      await tester.pumpAndSettle();
      final end = tester.getRect(_sheetOf(find.text('contenu')));
      expect(end.top, moreOrLessEquals(0));
    },
  );

  testWidgets(
    'siège latéral : la feuille occupe toute la largeur LOCALE (= hauteur '
    'physique) et colle au bord gauche',
    (tester) async {
      final ctx = await _pumpHost(tester);

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 1,
        builder: (_) => const Text('contenu'),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(_sheetOf(find.text('contenu')));
      expect(rect.height, moreOrLessEquals(_screen.height));
      expect(rect.left, moreOrLessEquals(0));
      expect(rect.width, lessThan(_screen.width / 2));
    },
  );

  testWidgets('quarterTurns: 6 se comporte comme 2', (tester) async {
    final ctx = await _pumpHost(tester);

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 6,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();

    final rotated = tester.widget<RotatedBox>(
      find.ancestor(
        of: find.text('contenu'),
        matching: find.byType(RotatedBox),
      ),
    );
    expect(rotated.quarterTurns, 2);
    expect(
      tester.getRect(_sheetOf(find.text('contenu'))).top,
      moreOrLessEquals(0),
    );
  });

  testWidgets('toucher la barrière, hors de la feuille, la ferme', (
    tester,
  ) async {
    final ctx = await _pumpHost(tester);

    showSeatedSheet<void>(
      context: ctx,
      quarterTurns: 0,
      builder: (_) => const Text('contenu'),
    );
    await tester.pumpAndSettle();
    expect(find.text('contenu'), findsOneWidget);

    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();

    expect(find.text('contenu'), findsNothing);
  });

  testWidgets(
    'clavier ouvert : le contenu de la feuille du bas reste au-dessus',
    (tester) async {
      const keyboard = 250.0;
      final ctx = await _pumpHost(
        tester,
        media: (m) =>
            m.copyWith(viewInsets: const EdgeInsets.only(bottom: keyboard)),
      );

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 0,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(_sheetOf(find.text('contenu'))).bottom,
        lessThanOrEqualTo(_screen.height - keyboard),
      );
    },
  );

  testWidgets(
    "encoche : pour le siège d'en face, elle est évitée au HAUT physique ; "
    "le fond de la feuille, lui, va jusqu'au bord",
    (tester) async {
      const notch = 40.0;
      final ctx = await _pumpHost(
        tester,
        media: (m) => m.copyWith(
          padding: const EdgeInsets.only(top: notch),
          viewPadding: const EdgeInsets.only(top: notch),
        ),
      );

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 2,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(_sheetOf(find.text('contenu'))).top,
        moreOrLessEquals(0),
      );
      // Rotation de 180° : le haut physique du texte est son bas local.
      expect(
        tester.getRect(find.text('contenu')).top,
        greaterThanOrEqualTo(notch),
      );
    },
  );

  testWidgets(
    'barre de navigation : pour le siège du bas, contenu au-dessus, fond '
    "jusqu'au bord comme l'ancien tiroir",
    (tester) async {
      const navBar = 30.0;
      final ctx = await _pumpHost(
        tester,
        media: (m) => m.copyWith(
          padding: const EdgeInsets.only(bottom: navBar),
          viewPadding: const EdgeInsets.only(bottom: navBar),
        ),
      );

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 0,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getRect(_sheetOf(find.text('contenu'))).bottom,
        moreOrLessEquals(_screen.height),
      );
      expect(
        tester.getRect(find.text('contenu')).bottom,
        lessThanOrEqualTo(_screen.height - navBar),
      );
    },
  );

  // Sièges 1 et 3 : les deux seuls qui échangent largeur et hauteur, et les
  // seuls qu'une inversion dans `_toSeatFrame` ou dans la glissade
  // confondrait sans que les sièges 0 et 2 le voient. Les insets sont
  // DIFFÉRENTS à gauche et à droite : celui du bord du siège doit écarter le
  // contenu, l'autre tombe sur le haut local, retiré comme pour tout siège.
  const leftInset = 40.0;
  const rightInset = 10.0;
  MediaQueryData sideInsets(MediaQueryData m) => m.copyWith(
        padding: const EdgeInsets.only(left: leftInset, right: rightInset),
        viewPadding: const EdgeInsets.only(left: leftInset, right: rightInset),
      );

  testWidgets(
    'siège 1 : la feuille glisse depuis le bord GAUCHE, y finit collée, et '
    "écarte son contenu de l'inset gauche",
    (tester) async {
      final ctx = await _pumpHost(tester, media: sideInsets);

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 1,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getRect(_sheetOf(find.text('contenu')));
      expect(mid.left, lessThan(0),
          reason: 'en cours de glissade, la feuille dépasse encore du bord '
              'gauche, le sien');
      expect(mid.right, lessThan(_screen.width / 2));

      await tester.pumpAndSettle();
      final sheet = tester.getRect(_sheetOf(find.text('contenu')));
      expect(sheet.left, moreOrLessEquals(0));
      expect(sheet.height, moreOrLessEquals(_screen.height));
      final content = tester.getRect(find.text('contenu'));
      expect(content.left, moreOrLessEquals(leftInset),
          reason: "l'inset gauche est le bas local de ce siège");
      expect(sheet.right - content.right, lessThan(rightInset),
          reason: "l'inset droit est son haut local, retiré");
    },
  );

  testWidgets(
    'siège 3 : la feuille glisse depuis le bord DROIT, y finit collée, et '
    "écarte son contenu de l'inset droit",
    (tester) async {
      final ctx = await _pumpHost(tester, media: sideInsets);

      showSeatedSheet<void>(
        context: ctx,
        quarterTurns: 3,
        builder: (_) => const SizedBox(height: 100, child: Text('contenu')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = tester.getRect(_sheetOf(find.text('contenu')));
      expect(mid.right, greaterThan(_screen.width),
          reason: 'en cours de glissade, la feuille dépasse encore du bord '
              'droit, le sien');
      expect(mid.left, greaterThan(_screen.width / 2));

      await tester.pumpAndSettle();
      final sheet = tester.getRect(_sheetOf(find.text('contenu')));
      expect(sheet.right, moreOrLessEquals(_screen.width));
      expect(sheet.height, moreOrLessEquals(_screen.height));
      final content = tester.getRect(find.text('contenu'));
      expect(_screen.width - content.right, moreOrLessEquals(rightInset),
          reason: "l'inset droit est le bas local de ce siège");
      expect(content.left - sheet.left, lessThan(leftInset),
          reason: "l'inset gauche est son haut local, retiré");
    },
  );
}
