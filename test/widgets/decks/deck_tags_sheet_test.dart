// Tests de la feuille « Dossiers » : ce qu'elle rend a l'appelant selon les
// gestes, sans passer par la page (qui ne se monte pas en test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_tags_sheet.dart';

void main() {
  /// Ouvre la feuille ; [result] recoit ce qu'elle rend une fois fermee.
  Future<void> openSheet(
    WidgetTester tester,
    void Function(List<String>?) onResult, {
    List<String> current = const [],
    List<String> known = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showDeckTagsSheet(
                  context,
                  deckName: 'Atraxa',
                  current: current,
                  known: known,
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  Future<void> addTag(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('deck-tags-input')), text);
    await tester.tap(find.byKey(const ValueKey('deck-tags-add')));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('deck-tags-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('le titre nomme le deck', (tester) async {
    await openSheet(tester, (_) {});
    expect(find.text('Dossiers de Atraxa'), findsOneWidget);
  });

  testWidgets('ajouter « cEDH » puis enregistrer rend [cEDH]', (tester) async {
    List<String>? result;
    await openSheet(tester, (r) => result = r);
    await addTag(tester, 'cEDH');
    await save(tester);
    expect(result, ['cEDH']);
  });

  testWidgets('le texte est rogné', (tester) async {
    List<String>? result;
    await openSheet(tester, (r) => result = r);
    await addTag(tester, '  cEDH  ');
    await save(tester);
    expect(result, ['cEDH']);
  });

  testWidgets('un texte vide n\'ajoute rien', (tester) async {
    List<String>? result;
    await openSheet(tester, (r) => result = r);
    await addTag(tester, '   ');
    await save(tester);
    expect(result, isEmpty);
  });

  testWidgets(
    '« Casual » quand « casual » existe sélectionne l\'existant, sans doublon',
    (tester) async {
      List<String>? result;
      await openSheet(tester, (r) => result = r, known: ['casual']);
      await addTag(tester, 'Casual');
      expect(find.byType(FilterChip), findsOneWidget);
      await save(tester);
      expect(result, ['casual']);
    },
  );

  testWidgets('fermer sans enregistrer rend null', (tester) async {
    List<String>? result = ['sentinelle'];
    await openSheet(tester, (r) => result = r);
    await addTag(tester, 'cEDH');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('décocher un tag du deck le retire du résultat', (tester) async {
    List<String>? result;
    await openSheet(
      tester,
      (r) => result = r,
      current: ['a', 'b'],
      known: ['a', 'b', 'c'],
    );
    await tester.tap(find.widgetWithText(FilterChip, 'a'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(result, ['b']);
  });
}
