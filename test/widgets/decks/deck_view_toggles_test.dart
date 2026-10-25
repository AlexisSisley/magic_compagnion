// Interrupteurs d'affichage de la liste d'un deck, posés dans la rangée des
// puces de board : regroupement « Tags | Type » et bascule grille/liste
// en un seul bouton.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/deck_view_prefs.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_view_toggles.dart';

Widget _app({
  DeckViewPrefs prefs = const DeckViewPrefs(),
  ValueChanged<DeckGrouping>? onGrouping,
  ValueChanged<DeckLayout>? onLayout,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Center(
        child: DeckViewToggles(
          prefs: prefs,
          onGrouping: onGrouping ?? (_) {},
          onLayout: onLayout ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('l\'interrupteur Tags appelle onGrouping(tag)', (
    tester,
  ) async {
    DeckGrouping? got;
    await tester.pumpWidget(_app(onGrouping: (g) => got = g));

    await tester.tap(find.text('Tags'));
    await tester.pump();

    expect(got, DeckGrouping.tag);
  });

  testWidgets('l\'interrupteur Type appelle onGrouping(type)', (tester) async {
    DeckGrouping? got;
    await tester.pumpWidget(
      _app(
        prefs: const DeckViewPrefs(grouping: DeckGrouping.tag),
        onGrouping: (g) => got = g,
      ),
    );

    await tester.tap(find.text('Type'));
    await tester.pump();

    expect(got, DeckGrouping.type);
  });

  testWidgets('le segment choisi est or, libellé foncé, malgré le primary '
      'lilas du thème', (tester) async {
    await tester.pumpWidget(_app());

    final button = tester.widget<SegmentedButton<DeckGrouping>>(
      find.byType(SegmentedButton<DeckGrouping>),
    );
    final selected = {WidgetState.selected};
    expect(button.style!.backgroundColor!.resolve(selected), AppColors.primary);
    expect(
      button.style!.foregroundColor!.resolve(selected),
      AppColors.textOnPrimary,
    );
    expect(button.style!.foregroundColor!.resolve({}), AppColors.textSecondary);
  });

  testWidgets('en grille, un seul bouton propose la liste', (tester) async {
    DeckLayout? got;
    await tester.pumpWidget(_app(onLayout: (l) => got = l));

    expect(find.byIcon(Icons.grid_view), findsNothing);
    expect(find.byTooltip('Afficher en liste'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump();

    expect(got, DeckLayout.list);
  });

  testWidgets('en liste, le même bouton propose la grille', (tester) async {
    DeckLayout? got;
    await tester.pumpWidget(
      _app(
        prefs: const DeckViewPrefs(layout: DeckLayout.list),
        onLayout: (l) => got = l,
      ),
    );

    expect(find.byIcon(Icons.view_list), findsNothing);
    expect(find.byTooltip('Afficher en grille'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.grid_view));
    await tester.pump();

    expect(got, DeckLayout.grid);
  });

  testWidgets('les cibles font 48 px de haut', (tester) async {
    await tester.pumpWidget(_app());

    expect(
      tester.getSize(find.byType(SegmentedButton<DeckGrouping>)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));
  });
}
