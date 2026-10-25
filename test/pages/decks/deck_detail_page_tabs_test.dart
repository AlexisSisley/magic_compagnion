// Structure de la page réelle : quatre onglets, et le sélecteur de board qui
// reçoit le dépôt d'une carte glissée depuis la liste. Le dépôt passe par de
// vrais gestes sur la page montée, jusqu'à la base et au contrôleur.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/data/database/app_database.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/pages/decks/deck_detail_page.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/services/scryfall_api_service.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_board_selector.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';
import 'package:magic_companion/widgets/decks/deck_commander_header.dart';
import 'package:magic_companion/widgets/decks/deck_view_toggles.dart';

class _SilentApi extends ScryfallApiService {
  @override
  Future<Map<String, dynamic>> fetchCollection(
    List<Map<String, dynamic>> identifiers,
  ) async => {'data': <dynamic>[]};
}

void main() {
  late AppDatabase db;
  late Deck deck;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.insertDeck(
      DecksCompanion.insert(id: 'd1', name: 'Deck', colors: const Value('[]')),
    );
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'main',
      scryfallId: 'main-card',
      cardName: 'Carte du main',
      quantityToAdd: 1,
    );
    await db.upsertDeckCard(
      deckId: 'd1',
      board: 'side',
      scryfallId: 'side-card',
      cardName: 'Carte du side',
      quantityToAdd: 1,
    );
  });

  tearDown(() => db.close());

  Future<void> openPage(WidgetTester tester) async {
    deck = (await DeckService(
      database: db,
    ).loadDecks()).firstWhere((d) => d.id == 'd1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          scryfallApiServiceProvider.overrideWithValue(_SilentApi()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: DeckDetailPage(deck: deck),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Color? pillColor(WidgetTester tester, String label) => tester
      .widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      )
      .color;

  /// Appui long sur [source], glissement en incréments jusqu'à la puce
  /// [label], relâchement, puis attente de l'écriture en base.
  Future<void> dragTo(WidgetTester tester, Finder source, String label) async {
    final start = tester.getCenter(source);
    final end = tester.getCenter(find.text(label));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('quatre onglets exactement : Liste, Stats, Suggestions, Infos', (
    tester,
  ) async {
    await openPage(tester);

    final tabs = tester
        .widgetList<Tab>(
          find.descendant(of: find.byType(TabBar), matching: find.byType(Tab)),
        )
        .map((t) => t.text)
        .toList();
    expect(tabs, ['Liste', 'Stats', 'Suggestions', 'Infos']);

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isFalse);
    // Le primary du thème est lilas : l'or de l'onglet actif est explicite.
    expect(bar.labelColor, AppColors.primary);
  });

  testWidgets('plus de barre d outils : les interrupteurs sont au bout de '
      'la rangée des puces', (tester) async {
    // Assez large pour que les puces et les interrupteurs tiennent sur une
    // ligne avec la police de test, plus large que les vraies.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openPage(tester);

    expect(find.text('1 cartes'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DeckBoardSelector),
        matching: find.byType(DeckViewToggles),
      ),
      findsOneWidget,
    );
    // Sur la même ligne que les puces à 800 px : la liste gagne une rangée.
    final pill = tester.getRect(find.text('Wishlist 0'));
    final toggles = tester.getRect(find.byType(DeckViewToggles));
    expect(toggles.left, greaterThan(pill.right));
    expect(toggles.center.dy, closeTo(pill.center.dy, 1));
    // Le premier élément de la liste suit directement la rangée.
    expect(
      tester.getTopLeft(find.byType(DeckCardGridTile)).dy -
          tester.getBottomLeft(find.byType(DeckBoardSelector)).dy,
      lessThan(60),
    );
  });

  group('le bandeau défile avec la liste', () {
    /// Assez de cartes au main pour que la liste dépasse l'écran.
    Future<void> seedMany() async {
      for (var i = 0; i < 40; i++) {
        await db.upsertDeckCard(
          deckId: 'd1',
          board: 'main',
          scryfallId: 'extra-$i',
          cardName: 'Extra ${i.toString().padLeft(2, '0')}',
          quantityToAdd: 1,
        );
      }
    }

    Future<void> scrollList(WidgetTester tester, double dy) async {
      await tester.drag(
        find.byType(DeckCardGridTile).first,
        Offset(0, dy),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('descendre sort le bandeau ; onglets et puces restent', (
      tester,
    ) async {
      await seedMany();
      await openPage(tester);
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(
        tester.getTopLeft(find.byType(DeckCommanderHeader)).dy,
        appBarBottom,
      );

      await scrollList(tester, -400);

      expect(tester.takeException(), isNull);
      // Le bandeau est sorti de l'écran ; la TabBar a pris sa place.
      expect(find.byType(DeckCommanderHeader).hitTestable(), findsNothing);
      expect(tester.getTopLeft(find.byType(TabBar)).dy, appBarBottom);
      for (final label in ['Main 41', 'Side 1', 'Considering 0', 'Wishlist 0']) {
        expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
      }
      expect(find.byType(DeckViewToggles).hitTestable(), findsOneWidget);
      // La liste elle-même a défilé : sa première carte n'est plus visible.
      expect(find.text('Carte du main').hitTestable(), findsNothing);
    });

    testWidgets('après défilement, le dépôt sur une puce marche toujours', (
      tester,
    ) async {
      await seedMany();
      await openPage(tester);
      await scrollList(tester, -400);

      final source = find.byType(DeckCardGridTile).hitTestable().first;
      final id = (tester.widget<DeckCardGridTile>(source)).card.scryfallId;
      await dragTo(tester, source, 'Side 1');

      expect(tester.takeException(), isNull);
      final rows = await db.getDeckCardsByDeckId('d1');
      expect(rows.where((r) => r.scryfallId == id).map((r) => r.board), [
        'side',
      ]);
      expect(pillColor(tester, 'Side 2'), AppColors.primary);
    });

    testWidgets('après défilement, un appui long sans bouger ouvre le menu', (
      tester,
    ) async {
      await seedMany();
      await openPage(tester);
      await scrollList(tester, -400);

      await tester.longPress(find.byType(DeckCardGridTile).hitTestable().first);
      await tester.pumpAndSettle();

      expect(find.text('Catégorie…'), findsOneWidget);
    });

    testWidgets('changer de board repart du haut de la liste', (tester) async {
      await seedMany();
      await openPage(tester);
      await scrollList(tester, -400);
      await scrollList(tester, -400);
      expect(find.text('Carte du main').hitTestable(), findsNothing);

      await tester.tap(find.text('Side 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Main 41'));
      await tester.pumpAndSettle();

      // La première carte du main (tri par nom à mana value égale) est
      // revenue sous les puces.
      expect(find.text('Carte du main').hitTestable(), findsOneWidget);
    });

    for (final tab in ['Stats', 'Infos']) {
      testWidgets('l onglet $tab défile sous le bandeau sans erreur', (
        tester,
      ) async {
        await seedMany();
        await openPage(tester);
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(TabBarView),
          const Offset(0, -300),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(TabBar).hitTestable(), findsOneWidget);
      });
    }
  });

  testWidgets('Liste montre le sélecteur, le main par défaut', (tester) async {
    await openPage(tester);

    expect(find.text('Main 1'), findsOneWidget);
    expect(find.text('Side 1'), findsOneWidget);
    expect(find.text('Considering 0'), findsOneWidget);
    expect(find.text('Wishlist 0'), findsOneWidget);
    expect(pillColor(tester, 'Main 1'), AppColors.primary);
    expect(find.text('Carte du main'), findsOneWidget);
    expect(find.text('Carte du side'), findsNothing);
  });

  testWidgets('un tap sur Side affiche le side', (tester) async {
    await openPage(tester);

    await tester.tap(find.text('Side 1'));
    await tester.pumpAndSettle();

    expect(find.text('Carte du side'), findsOneWidget);
    expect(find.text('Carte du main'), findsNothing);
    expect(pillColor(tester, 'Side 1'), AppColors.primary);
  });

  testWidgets('une carte du main déposée sur Side y part, et Side est '
      'sélectionné', (tester) async {
    await openPage(tester);

    await dragTo(tester, find.byType(DeckCardGridTile), 'Side 1');
    expect(tester.takeException(), isNull);

    // Relue dans le contrôleur : la carte a quitté le main pour le side.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeckDetailPage)),
    );
    final current = container
        .read(deckDetailControllerProvider(deck))
        .currentDeck;
    expect(current.mainboard.map((c) => c.scryfallId), isEmpty);
    expect(
      current.sideboard.map((c) => c.scryfallId),
      containsAll(['main-card', 'side-card']),
    );
    // Et en base.
    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.where((r) => r.scryfallId == 'main-card').map((r) => r.board), [
      'side',
    ]);

    // Le sélecteur a basculé sur Side, qui affiche les deux cartes.
    expect(pillColor(tester, 'Side 2'), AppColors.primary);
    expect(find.text('Carte du main'), findsOneWidget);
    expect(find.text('Carte du side'), findsOneWidget);
  });

  testWidgets('en liste compacte aussi, le dépôt sur Side déplace la carte '
      'sans ouvrir son menu', (tester) async {
    await openPage(tester);
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pump(const Duration(milliseconds: 100));

    await dragTo(tester, find.byType(DeckCardTile), 'Side 1');

    expect(tester.takeException(), isNull);
    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.where((r) => r.scryfallId == 'main-card').map((r) => r.board), [
      'side',
    ]);
    expect(find.text('Catégorie…'), findsNothing);
    expect(pillColor(tester, 'Side 2'), AppColors.primary);
  });

  testWidgets('un appui long relâché sans bouger ouvre toujours le menu', (
    tester,
  ) async {
    await openPage(tester);

    await tester.longPress(find.byType(DeckCardGridTile));
    await tester.pumpAndSettle();

    expect(find.text('Catégorie…'), findsOneWidget);
    // Rien n'a bougé.
    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.where((r) => r.scryfallId == 'main-card').map((r) => r.board), [
      'main',
    ]);
  });

  testWidgets('déposée sur son propre board, la carte reste et aucun menu '
      'ne s\'ouvre', (tester) async {
    await openPage(tester);

    await dragTo(tester, find.byType(DeckCardGridTile), 'Main 1');

    expect(find.text('Catégorie…'), findsNothing);
    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.where((r) => r.scryfallId == 'main-card').map((r) => r.board), [
      'main',
    ]);
    expect(pillColor(tester, 'Main 1'), AppColors.primary);
  });

  testWidgets('Infos réunit Tokens et Légalité', (tester) async {
    await openPage(tester);

    await tester.tap(find.text('Infos'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tokens (0)'), findsOneWidget);
    expect(find.text('Légalité'), findsOneWidget);
  });

  testWidgets('la vignette expose l\'appui long aux lecteurs d\'écran, qui '
      'ouvre le menu', (tester) async {
    final handle = tester.ensureSemantics();
    await openPage(tester);

    final node = tester.getSemantics(find.byType(DeckCardGridTile));
    expect(
      node.getSemanticsData().hasAction(SemanticsAction.longPress),
      isTrue,
    );
    node.owner!.performAction(node.id, SemanticsAction.longPress);
    await tester.pumpAndSettle();

    expect(find.text('Catégorie…'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('un doigt qui tremble sans s\'éloigner ouvre quand même le '
      'menu', (tester) async {
    await openPage(tester);

    // Allers-retours de 12 px : la distance cumulée dépasse largement le
    // seuil, le déplacement net reste nul.
    final start = tester.getCenter(find.byType(DeckCardGridTile));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await gesture.moveTo(start + const Offset(12, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(start);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Catégorie…'), findsOneWidget);
  });

  testWidgets('à 360 px, les quatre puces restent à l\'écran et un dépôt sur '
      'Wishlist marche', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openPage(tester);

    const screen = Rect.fromLTWH(0, 0, 360, 740);
    for (final label in ['Main 1', 'Side 1', 'Considering 0', 'Wishlist 0']) {
      final pill = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      final rect = tester.getRect(pill.first);
      expect(
        screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
        isTrue,
        reason: '$label hors écran : $rect',
      );
      expect(rect.height, greaterThanOrEqualTo(48), reason: label);
      expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
    }

    await dragTo(tester, find.byType(DeckCardGridTile), 'Wishlist 0');

    expect(tester.takeException(), isNull);
    final rows = await db.getDeckCardsByDeckId('d1');
    expect(rows.where((r) => r.scryfallId == 'main-card').map((r) => r.board), [
      'wishlist',
    ]);
    expect(pillColor(tester, 'Wishlist 1'), AppColors.primary);
  });
}
