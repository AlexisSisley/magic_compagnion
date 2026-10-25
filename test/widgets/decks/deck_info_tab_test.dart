// L'onglet Infos regroupe les tokens et la légalité dans un seul défilement :
// les deux sections doivent y vivre sans défilement imbriqué qui casserait.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/deck_detail_controller.dart';
import 'package:magic_companion/models/legality_report.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/widgets/decks/deck_info_tab.dart';

final _report = LegalityReport(
  generatedAt: DateTime(2026, 10, 19),
  results: const [
    FormatLegalityResult(format: 'commander', status: LegalityStatus.legal),
    FormatLegalityResult(
      format: 'modern',
      status: LegalityStatus.illegal,
      violations: ['Sol Ring est banni'],
    ),
  ],
);

Widget _app(List<TokenInfo> tokens) => MaterialApp(
  theme: buildAppTheme(),
  home: Scaffold(
    body: DeckInfoTab(tokens: tokens, report: _report),
  ),
);

void main() {
  testWidgets('Tokens (n) puis Légalité, dans un seul défilement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const [
        TokenInfo(id: 't1', name: 'Soldier', typeLine: 'Token Creature'),
        TokenInfo(id: 't2', name: 'Treasure', typeLine: 'Token Artifact'),
      ]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Tokens (2)'), findsOneWidget);
    expect(find.text('Soldier'), findsOneWidget);
    expect(find.text('Légalité'), findsOneWidget);
    expect(find.text('Commander'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Tokens (2)')).dy,
      lessThan(tester.getTopLeft(find.text('Légalité')).dy),
    );
    // Un seul défilement vertical dans tout l'onglet.
    final vertical = tester
        .widgetList<Scrollable>(find.byType(Scrollable))
        .where((s) => axisDirectionToAxis(s.axisDirection) == Axis.vertical);
    expect(vertical, hasLength(1));
  });

  testWidgets('sans token, la section dit qu\'il n\'y en a pas', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));

    expect(tester.takeException(), isNull);
    expect(find.text('Tokens (0)'), findsOneWidget);
    expect(find.text('Ce deck ne nécessite aucun token'), findsOneWidget);
    expect(find.text('Légalité'), findsOneWidget);
  });
}
