// Fichier : test/pages/settings/card_tags_page_test.dart
// Ecran de gestion du catalogue des tags universels.

import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_tag_catalog_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/card_tag.dart';
import 'package:magic_companion/pages/settings/card_tags_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/card_tag_catalog.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  /// Les accès base de Drift passent par de vraies E/S : on laisse la main à
  /// la boucle réelle, puis on rejoue les frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> openPage(WidgetTester tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Hors ligne, la police google_fonts rejette sa Future : on l'absorbe
    // pour que le test échoue sur sa vraie cause seulement.
    await runZonedGuarded(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const CardTagsPage(),
          ),
        ),
      );
      await settle(tester);
    }, (e, s) {});
    return container;
  }

  testWidgets('lists the catalogue in order', (tester) async {
    await openPage(tester);

    expect(find.text('Tags de cartes'), findsOneWidget);
    final names = [for (final t in kDefaultCardTags) t.name];
    final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
    expect(ys, orderedEquals([...ys]..sort()));
    expect(find.text('Nouveau tag'), findsOneWidget);
    // Aucune carte de deck : chaque ligne annonce zéro carte.
    expect(find.text('0 carte'), findsNWidgets(names.length));
  });

  testWidgets('rename to an existing universal name shows the duplicate '
      'message', (tester) async {
    await openPage(tester);

    await tester.tap(find.byTooltip('Renommer').first); // Ramp
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pioche');
    await tester.tap(find.text('Renommer').last);
    await settle(tester);

    expect(find.text('Un tag porte déjà ce nom.'), findsOneWidget);
    // Le dialogue reste ouvert ; un nom vide donne l'autre message.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Renommer').last);
    await settle(tester);
    expect(find.text('Un tag fait de 1 à 24 caractères.'), findsOneWidget);
  });

  testWidgets('rename to a free name renames the row', (tester) async {
    await openPage(tester);

    await tester.tap(find.byTooltip('Renommer').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Accélération');
    await tester.tap(find.text('Renommer').last);
    await settle(tester);

    expect(find.text('Accélération'), findsOneWidget);
    expect(find.text('Ramp'), findsNothing);
  });

  testWidgets('delete asks with the usage count then removes', (tester) async {
    await tester.runAsync(() async {
      await db.insertDeck(
        DecksCompanion.insert(
          id: 'd1',
          name: 'Deck',
          colors: const Value('[]'),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await db.upsertDeckCard(
          deckId: 'd1',
          board: 'main',
          scryfallId: 'c$i',
          cardName: 'Carte $i',
          quantityToAdd: 1,
        );
        await db.setDeckCardTags(
          deckId: 'd1',
          board: 'main',
          scryfallId: 'c$i',
          tags: ['Blink'],
          tagsEdited: true,
        );
      }
    });
    await openPage(tester);
    expect(find.text('3 cartes'), findsOneWidget);

    // Blink est la cinquième ligne.
    await tester.tap(find.byTooltip('Supprimer').at(4));
    await settle(tester);
    expect(find.text('Supprimer le tag Blink ?'), findsOneWidget);
    expect(find.text('Il sera retiré de 3 cartes.'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await settle(tester);
    expect(find.text('Blink'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer').at(4));
    await settle(tester);
    await tester.tap(find.text('Supprimer'));
    await settle(tester);

    expect(find.text('Blink'), findsNothing);
    final rows = await tester.runAsync(() => db.getDeckCardsByDeckId('d1'));
    expect(AppDatabase.decodeTags(rows!.first.tags), isEmpty);
  });

  testWidgets('reorder persists', (tester) async {
    final container = await openPage(tester);

    // Glisser la poignée de Ramp sous Pioche.
    final handle = find.byIcon(Icons.drag_handle).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await settle(tester);

    final order = [
      for (final t in container.read(cardTagCatalogProvider)) t.name,
    ];
    expect(order.take(2), ['Pioche', 'Ramp']);
    final stored = await tester.runAsync(() => CardTagCatalog(db).load());
    expect([for (final t in stored!) t.name].take(2), ['Pioche', 'Ramp']);
  });

  testWidgets('la pastille ouvre la palette et recolore le tag', (
    tester,
  ) async {
    final container = await openPage(tester);

    await tester.tap(find.byKey(const ValueKey('color-Ramp')));
    await tester.pumpAndSettle();
    for (final c in kCardTagPalette) {
      expect(find.byKey(ValueKey('palette-$c')), findsOneWidget);
    }
    await tester.tap(find.byKey(ValueKey('palette-${kCardTagPalette[9]}')));
    await settle(tester);

    expect(
      container.read(cardTagCatalogProvider).first.color,
      kCardTagPalette[9],
    );
    final stored = (await tester.runAsync(() => CardTagCatalog(db).load()))!;
    expect(stored.first.color, kCardTagPalette[9]);
    // Les autres lignes gardent leur couleur.
    expect(stored[1].color, kDefaultCardTags[1].color);
  });

  testWidgets('Nouveau tag ajoute en fin de liste et refuse un doublon', (
    tester,
  ) async {
    await openPage(tester);

    await tester.tap(find.text('Nouveau tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ramp');
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    expect(find.text('Un tag porte déjà ce nom.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hate');
    await tester.tap(find.text('Ajouter'));
    await settle(tester);
    expect(find.text('Hate'), findsOneWidget);
  });
}
