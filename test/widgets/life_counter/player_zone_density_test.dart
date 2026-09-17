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
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/models/player_model.dart';
import 'package:magic_companion/widgets/life_counter/player_zone.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';
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
    expect(
      handle.summary.counters
          .firstWhere((e) => e.key.id == 'poison')
          .value,
      3,
      reason: 'le compteur réel est toujours transmis à la poignée -- '
          '`CounterSummary` porte désormais une collection générique au '
          'lieu de quatre champs nommés (lot 5), la propriété testée est '
          'la même',
    );
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
                    // Requis depuis le lot 5 : le tiroir rend les compteurs
                    // ACTIFS de la session au lieu d'une liste figée. Ce
                    // test ne porte pas sur les compteurs, d'où la liste
                    // vide et les callbacks inertes.
                    activeCounters: const [],
                    onCreateCounter: (_) async =>
                        (success: true, message: ''),
                    onRemoveCounter: (_) {},
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
                    onShowHistory: () {},
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

  testWidgets(
      'au cran minimal, "Tourner" reste atteignable même dans la '
      'configuration la plus longue du tiroir : 7 adversaires, grille de '
      'dégâts, 3 compteurs (ronde de correction 2, tâche 2)',
      (tester) async {
    int? rotatedTo;

    // Le pire cas visé par la correction : 7-8 joueurs, ce qui pousse à la
    // fois les zones sous le seuil `minimal` (en-tête masqué) ET allonge le
    // tiroir au maximum (3 compteurs, grille de dégâts à 7 lignes, puis
    // Tourner / Couleur / Monarque / Éliminer / Réinitialiser).
    final opponents = [
      for (var i = 1; i <= 7; i++)
        CommanderDamageOpponent(
          playerId: i,
          name: 'Joueur $i',
          colorValue: 0xFF000000 + i * 0x111111,
          damage: i * 3,
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SizedBox(
                width: 300,
                height: 72, // cran minimal, comme les tests ci-dessus.
                child: PlayerZone(
                  player: _buildPlayer(),
                  onLifeChanged: (_) {},
                  onColorChanged: (_) {},
                  onRotationChanged: (v) => rotatedTo = v,
                  onOpenDrawer: (onRotate, onShowColorPicker) =>
                      showPlayerDrawer(
                    context: context,
                    playerName: 'Alexis',
                    // Requis depuis le lot 5 : le tiroir rend les compteurs
                    // ACTIFS de la session. Ici les trois intégrés dont ce
                    // test fournit déjà les valeurs, pour que le rendu
                    // corresponde à `counters` ci-dessous.
                    activeCounters: CounterType.builtInCounters
                        .where((t) => t.id != 'commander_damage')
                        .toList(),
                    onCreateCounter: (_) async =>
                        (success: true, message: ''),
                    onRemoveCounter: (_) {},
                    counters: const {
                      'poison': 3,
                      'energy': 2,
                      'commander_tax': 1,
                    },
                    isMonarch: false,
                    isEliminated: false,
                    onCounterDelta: (_, _) {},
                    onToggleMonarch: () {},
                    onEliminate: () {},
                    onResetCounters: () {},
                    commanderDamage: opponents,
                    onCommanderDamageDelta: (_, _) {},
                    // Non nul : active la grille (spec §2.7 point 2 et
                    // ronde de correction 1 de player_drawer.dart).
                    lethalCommanderDamage: 21,
                    onRotate: onRotate,
                    onShowColorPicker: onShowColorPicker,
                    onShowHistory: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ConditionalHandle));
    await tester.pumpAndSettle();

    // Confirme qu'on est bien dans la configuration la plus longue, pas
    // dans un tiroir raccourci qui ne prouverait rien.
    expect(find.byType(CommanderDamageGrid), findsOneWidget);
    expect(find.text('Joueur 7'), findsOneWidget);

    // Ronde de correction 3 : ne prouve plus seulement qu'on PEUT atteindre
    // "Tourner" (un défilement jusqu'au bout du tiroir suffirait à le
    // prouver, et c'est exactement ce que la ronde 2 a révélé -- 371px sur
    // 371px de maxScrollExtent, soit la totalité). Ce test durci compare le
    // défilement réellement nécessaire au maxScrollExtent de la feuille, et
    // exige qu'il en reste une marge confortable : "Tourner"/"Couleur"
    // vivent maintenant juste après les compteurs, AVANT la grille de
    // dégâts de commandant (potentiellement longue et variable), pas après.
    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsOneWidget,
        reason: 'un seul Scrollable attendu : celui du corps du tiroir');
    final position = tester.state<ScrollableState>(scrollable).position;
    final beforePixels = position.pixels;

    await tester.ensureVisible(find.byKey(const ValueKey('action-rotate')));
    await tester.pumpAndSettle();

    final afterPixels = position.pixels;
    final maxScrollExtent = position.maxScrollExtent;
    // ignore: avoid_print
    print(
      'RONDE 3 -- pire cas du tiroir : défilement de $beforePixels à '
      '$afterPixels px (delta ${afterPixels - beforePixels} px) pour '
      'atteindre "Tourner" ; maxScrollExtent=$maxScrollExtent px '
      '(${(afterPixels / maxScrollExtent * 100).toStringAsFixed(1)}%).',
    );

    expect(find.byKey(const ValueKey('action-rotate')), findsOneWidget,
        reason: '"Tourner" doit rester atteignable même dans la '
            'configuration la plus longue du tiroir');

    // Seuil délibérément serré : si "Tourner"/"Couleur" repassaient après
    // la grille de dégâts de commandant (fin de liste, comme avant cette
    // ronde de correction), le défilement nécessaire remonterait à environ
    // 93 % du maxScrollExtent (371/397 mesuré avant ce correctif) -- très
    // au-dessus de ce seuil. Une action juste après les compteurs, elle,
    // reste largement en dessous.
    expect(afterPixels, lessThan(maxScrollExtent * 0.75),
        reason: '"Tourner" doit être atteignable SANS défiler jusqu\'au '
            'bout du tiroir -- seule preuve qu\'elle vit avant la grille de '
            'dégâts de commandant, pas derrière elle');

    await tester.tap(find.byKey(const ValueKey('action-rotate')));
    await tester.pumpAndSettle();

    expect(rotatedTo, 1,
        reason: 'taper "Tourner" doit vraiment déclencher la rotation, même '
            'depuis le pire cas du tiroir');
  });
}
