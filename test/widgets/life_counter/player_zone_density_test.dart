// test/widgets/life_counter/player_zone_density_test.dart
//
// Tâche 2 (v2 multijoueur) : câblage du contrat de densité
// (`layouts/density_tier.dart`) dans `PlayerZone`. Le `LayoutBuilder` qui
// calcule le `DensityTier` vit DANS le `RotatedBox` de `quarterTurns` --
// c'est pourquoi ces tests dimensionnent l'espace disponible AUTOUR de la
// zone (le `SizedBox` parent), jamais un `Size` passé en dur à `tierFor`.
//
// Repérage par clé (`ValueKey('player-zone-header')`), jamais par position
// dans l'arbre.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';

Player _buildPlayer({int poison = 0, int quarterTurns = 0}) {
  return Player(
    id: 0,
    name: 'Alexis',
    life: 40,
    colorValue: 0xFF880000,
    commanderDamageReceived: const {},
    poison: poison,
    quarterTurns: quarterTurns,
  );
}

Future<void> _pumpZoneOfSize(
  WidgetTester tester, {
  required double width,
  required double height,
  Player? player,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: PlayerZone(
              player: player ?? _buildPlayer(),
              onLifeChanged: (_) {},
              onColorChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'dans une zone large (cran confort), le nom du joueur (en-tête) est '
      'visible', (tester) async {
    await _pumpZoneOfSize(tester, width: 300, height: 300);

    expect(find.byKey(const ValueKey('player-zone-header')), findsOneWidget);
    expect(find.text('Alexis'), findsOneWidget);
  });

  testWidgets(
      'dans une zone au ras du plancher (cran minimal), le nom du joueur '
      '(en-tête) est masqué -- seuls les PV restent affichés', (tester) async {
    // 300x72 : le petit côté (72) est sous kZoneShortEdgeFloor (70) +
    // marge de sécurité, donc franchement dans le cran minimal (< 110).
    await _pumpZoneOfSize(tester, width: 300, height: 72);

    expect(find.byKey(const ValueKey('player-zone-header')), findsNothing);
    expect(find.text('Alexis'), findsNothing);
    // Les PV, eux, restent affichés quel que soit le cran.
    expect(find.text('40'), findsOneWidget);
  });

  testWidgets(
      'sous le cran confort, la poignée ne montre plus le résumé des '
      'compteurs secondaires même si un compteur est actif', (tester) async {
    // 300x120 : cran compact (>= 110, < 180). L'en-tête reste visible,
    // mais le résumé de la poignée doit disparaître.
    await _pumpZoneOfSize(
      tester,
      width: 300,
      height: 120,
      player: _buildPlayer(poison: 3),
    );

    expect(find.byKey(const ValueKey('player-zone-header')), findsOneWidget,
        reason: 'le cran compact garde encore le nom');

    final handle = tester.widget<ConditionalHandle>(
      find.byType(ConditionalHandle),
    );
    expect(handle.summary.poison, 3,
        reason: 'le compteur réel est toujours transmis à la poignée');
    expect(find.textContaining('☠'), findsNothing,
        reason: 'sous le cran confort, le résumé des compteurs secondaires '
            'est masqué même si un compteur est actif');
  });

  testWidgets(
      'au cran confort, un compteur actif fait bien apparaître le résumé '
      'dans la poignée', (tester) async {
    await _pumpZoneOfSize(
      tester,
      width: 300,
      height: 300,
      player: _buildPlayer(poison: 3),
    );

    expect(find.textContaining('☠ 3'), findsOneWidget);
  });

  testWidgets(
      'au cran minimal, le tiroir reste le point d\'accès garanti à la '
      'rotation -- PlayerHeader (son autre accès) est masqué (ronde de '
      'correction 1, tâche 2)', (tester) async {
    int? rotatedTo;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 300,
                // Cran minimal (même geometrie que le test ci-dessus) :
                // PlayerHeader -- et son bouton "Tourner" -- est masqué.
                height: 72,
                child: PlayerZone(
                  player: _buildPlayer(),
                  onLifeChanged: (_) {},
                  onColorChanged: (_) {},
                  onRotationChanged: (v) => rotatedTo = v,
                  // Le test tient ici le rôle de `life_counter_page.dart` :
                  // seul l'appelant connaît la session nécessaire à
                  // `showPlayerDrawer`, mais il relaie tel quel ce que
                  // `PlayerZone` lui fournit (`_rotate90Degrees`,
                  // `showPlayerSkinPicker`), sans dupliquer leur logique.
                  onOpenDrawer: (onRotate, onShowColorPicker) =>
                      showPlayerDrawer(
                    context: context,
                    playerName: 'Alexis',
                    counters: const {},
                    isMonarch: false,
                    isEliminated: false,
                    onCounterDelta: (_, _) {},
                    onToggleMonarch: () {},
                    onEliminate: () {},
                    onResetCounters: () {},
                    commanderDamage: const [],
                    onCommanderDamageDelta: (_, _) {},
                    lethalCommanderDamage: 0,
                    onRotate: onRotate,
                    onShowColorPicker: onShowColorPicker,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-zone-header')), findsNothing,
        reason: 'confirme qu\'on est bien au cran minimal, en-tête masqué');

    await tester.tap(find.byType(ConditionalHandle));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('action-rotate')), findsOneWidget,
        reason: '"Tourner" doit rester trouvable dans le tiroir même quand '
            'PlayerHeader, son autre point d\'accès, est masqué');

    await tester.ensureVisible(find.byKey(const ValueKey('action-rotate')));
    await tester.tap(find.byKey(const ValueKey('action-rotate')));
    await tester.pumpAndSettle();

    expect(rotatedTo, 1,
        reason: 'taper "Tourner" dans le tiroir doit vraiment déclencher la '
            'rotation (_rotate90Degrees), pas seulement fermer le tiroir');
  });
}
