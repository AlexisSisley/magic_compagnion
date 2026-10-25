import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_tag_catalog_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/widgets/decks/card_tags_sheet.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    List<String> tags = const ['Ramp', 'Blink'],
    List<String> deckTags = const [],
    bool canSuggest = true,
    ValueChanged<List<String>>? onSave,
    VoidCallback? onReset,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCardTagsSheet(
                  context,
                  card: DeckCard(
                    scryfallId: 'x',
                    name: 'Ma carte',
                    quantity: 1,
                    tags: tags,
                  ),
                  deckTags: deckTags,
                  canSuggest: canSuggest,
                  onSave: onSave ?? (_) {},
                  onReset: onReset ?? () {},
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    // Le catalogue finit son chargement en base avant l'ouverture.
    await tester.runAsync(
      () => container.read(cardTagCatalogProvider.notifier).load(),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('taper l\'étoile de Blink le rend principal', (tester) async {
    List<String>? saved;
    await open(tester, onSave: (t) => saved = t);

    expect(find.text('Ma carte'), findsOneWidget);
    await tester.tap(find.byTooltip('Rendre principal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Blink', 'Ramp']);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('la croix retire le tag', (tester) async {
    List<String>? saved;
    await open(tester, onSave: (t) => saved = t);

    await tester.tap(find.byTooltip('Retirer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Blink']);
  });

  testWidgets('ajouter Combo par le champ', (tester) async {
    List<String>? saved;
    await open(tester, onSave: (t) => saved = t);

    await tester.enterText(find.byType(TextField), 'Combo');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Ramp', 'Blink', 'Combo']);
  });

  testWidgets('un nom invalide affiche le message et n\'ajoute rien', (
    tester,
  ) async {
    List<String>? saved;
    await open(tester, onSave: (t) => saved = t);

    await tester.enterText(find.byType(TextField), 'x' * 25);
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Un tag fait de 1 à 24 caractères.'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Ramp', 'Blink']);
  });

  testWidgets('un doublon ne fait rien', (tester) async {
    List<String>? saved;
    await open(tester, onSave: (t) => saved = t);

    await tester.enterText(find.byType(TextField), 'ramp');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Ramp', 'Blink']);
  });

  testWidgets('un tag universel s\'ajoute d\'un tap', (tester) async {
    List<String>? saved;
    await open(tester, tags: const ['Ramp'], onSave: (t) => saved = t);

    await tester.tap(find.widgetWithText(ActionChip, 'Pioche'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(saved, ['Ramp', 'Pioche']);
  });

  testWidgets('la section Tags de ce deck est masquée sans tag de deck', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Tags de ce deck'), findsNothing);
  });

  testWidgets('tag de deck proposé, ajouté, puis rendu universel', (
    tester,
  ) async {
    List<String>? saved;
    await open(tester, deckTags: const ['Hate'], onSave: (t) => saved = t);
    expect(find.text('Tags de ce deck'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Hate'));
    await tester.pumpAndSettle();
    // Seul le tag de deck porte « Rendre universel ».
    expect(find.byTooltip('Rendre universel'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Rendre universel'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(
      container.read(cardTagCatalogProvider).map((t) => t.name),
      contains('Hate'),
    );
    expect(find.byTooltip('Rendre universel'), findsNothing);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(saved, ['Ramp', 'Blink', 'Hate']);
  });

  testWidgets('Suggestion auto appelle onReset et ferme', (tester) async {
    var reset = 0;
    await open(tester, onReset: () => reset++);

    await tester.tap(find.text('Suggestion auto'));
    await tester.pumpAndSettle();

    expect(reset, 1);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('sans canSuggest, Suggestion auto est absent', (tester) async {
    await open(tester, canSuggest: false);
    expect(find.text('Suggestion auto'), findsNothing);
  });

  testWidgets('Annuler ne sauvegarde rien', (tester) async {
    var saved = false;
    await open(tester, onSave: (_) => saved = true);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('Enregistrer a un texte sombre explicite', (tester) async {
    await open(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enregistrer'),
    );
    final fg = button.style!.foregroundColor!.resolve({})!;
    expect(fg.computeLuminance(), lessThan(0.2));
  });

  testWidgets('étoile et croix font au moins 48 px', (tester) async {
    await open(tester);
    for (final tooltip in ['Tag principal', 'Rendre principal', 'Retirer']) {
      final size = tester.getSize(find.byTooltip(tooltip).first);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
