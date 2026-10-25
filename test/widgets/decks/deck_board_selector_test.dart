// Le sélecteur de board remplace les anciens onglets Main/Side/Considering/
// Wishlist comme cible de dépôt. Ces tests passent par de vrais gestes (appui
// long, glissement, relâchement) depuis un LongPressDraggable qui porte les
// mêmes données que la liste du deck : jamais par un appel direct à onDrop.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/deck_model.dart';
import 'package:magic_companion/services/deck_service.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_board_selector.dart';

final _card = DeckCard(scryfallId: 'c1', name: 'Sol Ring', quantity: 1);
const _sourceKey = Key('source');

class _Drop {
  final DeckCard card;
  final DeckBoard from;
  final DeckBoard to;
  _Drop(this.card, this.from, this.to);
}

Widget _app({
  required List<_Drop> drops,
  List<DeckBoard>? selections,
  DeckBoard selected = DeckBoard.main,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeckBoardSelector(
            selected: selected,
            counts: const {
              DeckBoard.main: 107,
              DeckBoard.side: 3,
              DeckBoard.considering: 4,
              DeckBoard.wishlist: 0,
            },
            onSelect: (b) => selections?.add(b),
            onDrop: (c, from, to) => drops.add(_Drop(c, from, to)),
          ),
          const SizedBox(height: 200),
          LongPressDraggable<Map<String, dynamic>>(
            data: {'card': _card, 'sourceBoard': DeckBoard.main},
            feedback: const SizedBox(width: 40, height: 40),
            child: Container(
              key: _sourceKey,
              width: 80,
              height: 80,
              color: AppColors.greyShade800,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Appui long sur la source, glissement en incréments jusqu'au centre de la
/// puce [label], puis relâchement si [release].
Future<TestGesture> _dragTo(
  WidgetTester tester,
  String label, {
  bool release = true,
}) async {
  final start = tester.getCenter(find.byKey(_sourceKey));
  final end = tester.getCenter(find.text(label));
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  const steps = 12;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(start, end, i / steps)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  if (release) {
    await gesture.up();
    await tester.pumpAndSettle();
  }
  return gesture;
}

/// Couleur de fond de la puce qui porte [label].
Color? _pillColor(WidgetTester tester, String label) {
  final material = tester.widget<Material>(
    find.ancestor(of: find.text(label), matching: find.byType(Material)).first,
  );
  return material.color;
}

void main() {
  testWidgets('libellés « Board n » dans l\'ordre, puce active pleine or', (
    tester,
  ) async {
    await tester.pumpWidget(_app(drops: []));

    final labels = ['Main 107', 'Side 3', 'Considering 4', 'Wishlist 0'];
    final xs = labels.map((l) => tester.getCenter(find.text(l)).dx).toList();
    expect(xs, orderedEquals([...xs]..sort()));

    expect(_pillColor(tester, 'Main 107'), AppColors.primary);
    expect(
      tester.widget<Text>(find.text('Main 107')).style?.color,
      AppColors.textOnPrimary,
    );
    expect(_pillColor(tester, 'Side 3'), AppColors.transparent);
  });

  testWidgets('chaque puce mesure au moins 48 px de haut', (tester) async {
    await tester.pumpWidget(_app(drops: []));
    for (final l in ['Main 107', 'Side 3', 'Considering 4', 'Wishlist 0']) {
      final ink = find.ancestor(
        of: find.text(l),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSize(ink.first).height,
        greaterThanOrEqualTo(48),
        reason: l,
      );
    }
  });

  testWidgets('un tap sur une puce la sélectionne', (tester) async {
    final selections = <DeckBoard>[];
    await tester.pumpWidget(_app(drops: [], selections: selections));
    await tester.tap(find.text('Considering 4'));
    expect(selections, [DeckBoard.considering]);
  });

  testWidgets('déposée sur « Side », la carte part du main vers le side', (
    tester,
  ) async {
    final drops = <_Drop>[];
    await tester.pumpWidget(_app(drops: drops));

    await _dragTo(tester, 'Side 3');

    expect(drops, hasLength(1));
    expect(drops.single.card, same(_card));
    expect(drops.single.from, DeckBoard.main);
    expect(drops.single.to, DeckBoard.side);
  });

  testWidgets('déposée sur son propre board, rien n\'est appelé', (
    tester,
  ) async {
    final drops = <_Drop>[];
    await tester.pumpWidget(_app(drops: drops));

    await _dragTo(tester, 'Main 107');

    expect(drops, isEmpty);
  });

  testWidgets('déposée sur un board vide, l\'appel a lieu', (tester) async {
    final drops = <_Drop>[];
    await tester.pumpWidget(_app(drops: drops));

    await _dragTo(tester, 'Wishlist 0');

    expect(drops, hasLength(1));
    expect(drops.single.to, DeckBoard.wishlist);
  });

  testWidgets('pendant le survol, la puce visée prend son fond de survol', (
    tester,
  ) async {
    await tester.pumpWidget(_app(drops: []));
    final hover = AppColors.primaryShade900.withValues(alpha: 0.5);

    final gesture = await _dragTo(tester, 'Considering 4', release: false);

    expect(_pillColor(tester, 'Considering 4'), hover);
    // Les autres puces ne s'allument pas, et le board courant refuse.
    expect(_pillColor(tester, 'Side 3'), AppColors.transparent);
    expect(_pillColor(tester, 'Main 107'), AppColors.primary);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_pillColor(tester, 'Considering 4'), AppColors.transparent);
  });

  testWidgets('survolée par une carte de son propre board, la puce reste '
      'telle quelle', (tester) async {
    await tester.pumpWidget(_app(drops: [], selected: DeckBoard.side));

    final gesture = await _dragTo(tester, 'Main 107', release: false);

    expect(_pillColor(tester, 'Main 107'), AppColors.transparent);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
