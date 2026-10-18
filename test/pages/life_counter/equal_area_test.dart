// test/pages/life_counter/equal_area_test.dart
//
// Spec §6.1 : à 4 joueurs, les quatre zones RENDUES ont la même surface, à
// 1 % près, sur un grand écran comme sur un téléphone en portrait. Mesuré
// sur la vraie page (bande ou hub compris), pas sur une grille isolée : la
// bande d'actions vole de la hauteur, et ce qui compte est ce qu'elle laisse
// à chaque joueur.
//
// Le cas à 3 joueurs n'est pas couvert : sa répartition inégale est
// antérieure au chantier et reste à trancher par l'utilisateur.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/game_session_notifier.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _setScreenSize(WidgetTester tester, Size size) {
  final originalSize = tester.view.physicalSize;
  final originalDpr = tester.view.devicePixelRatio;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.physicalSize = originalSize;
    tester.view.devicePixelRatio = originalDpr;
  });
}

void main() {
  for (final screen in const [Size(840, 700), Size(390, 844)]) {
    testWidgets(
        'à 4 joueurs sur ${screen.width.toInt()}×${screen.height.toInt()}, '
        'les quatre zones rendues ont la même aire à 1 % près',
        (tester) async {
      _setScreenSize(tester, screen);
      // Aucun snapshot : la page démarre une partie à 4 joueurs (défaut).
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(gameSessionNotifierProvider)!.players,
          hasLength(4));

      final areas = [
        for (int i = 0; i < 4; i++)
          () {
            final size =
                tester.getSize(find.byKey(ValueKey('grid_slot_$i')));
            return size.width * size.height;
          }(),
      ];
      final smallest = areas.reduce(math.min);
      final largest = areas.reduce(math.max);
      expect(smallest, greaterThan(0));
      expect(largest / smallest, lessThanOrEqualTo(1.01),
          reason: 'aires rendues : $areas');
    });
  }
}
