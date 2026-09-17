// test/widgets/life_counter/zone/counter_editor_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/widgets/life_counter/zone/counter_editor_dialog.dart';

void main() {
  group('deriveCounterId', () {
    test('minuscule, espaces réduits à un underscore', () {
      expect(deriveCounterId('Storm Count'), 'storm_count');
    });

    test('ponctuation et accents non alphanumériques réduits à un underscore', () {
      expect(deriveCounterId('Énergie !'), 'nergie');
    });

    test('espaces de tête/fin recadrés avant dérivation', () {
      expect(deriveCounterId('  Bouclier  '), 'bouclier');
    });

    test('un nom qui usurpe un intégré dérive le même id (par construction)', () {
      expect(deriveCounterId('Poison'), 'poison');
    });

    test('un nom qui ne réduit à rien (ponctuation seule) dérive un id vide', () {
      expect(deriveCounterId('!!!'), isEmpty);
    });
  });

  testWidgets('remplir nom et emoji puis valider rend le CounterType saisi',
      (tester) async {
    late CounterType? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CounterEditorDialog.show(context);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Bouclier');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_max_value')), '20');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.id, 'bouclier');
    expect(result!.name, 'Bouclier');
    expect(result!.emoji, '🛡️');
    expect(result!.maxValue, 20);
    expect(result!.isBuiltIn, isFalse);
  });

  testWidgets('taper Annuler après une saisie ne rend aucun CounterType',
      (tester) async {
    late CounterType? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CounterEditorDialog.show(context);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Bouclier');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('counter_editor_cancel')));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets(
      'nom vide : le bouton Créer reste désactivé, même avec un emoji saisi',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CounterEditorDialog())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.pump();

    final submit = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('counter_editor_submit')),
    );
    expect(submit.onPressed, isNull,
        reason: 'un nom vide doit désactiver la création, jamais la '
            'laisser silencieusement produire un compteur sans nom');
  });

  testWidgets(
      'emoji vide : le bouton Créer reste désactivé, même avec un nom saisi',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CounterEditorDialog())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Bouclier');
    await tester.pump();

    final submit = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('counter_editor_submit')),
    );
    expect(submit.onPressed, isNull,
        reason: 'un emoji vide doit désactiver la création, jamais la '
            'laisser silencieusement produire un compteur sans glyphe');
  });

  testWidgets(
      'un nom qui ne dérive aucun id (ponctuation seule) désactive la '
      'création malgré un nom et un emoji non vides', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CounterEditorDialog())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), '!!!');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🛡️');
    await tester.pump();

    final submit = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('counter_editor_submit')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('sans borne saisie, maxValue reste null (illimité)',
      (tester) async {
    late CounterType? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await CounterEditorDialog.show(context);
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')), 'Storm');
    await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')), '🌀');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('counter_editor_submit')));
    await tester.pumpAndSettle();

    expect(result!.maxValue, isNull);
  });
}
