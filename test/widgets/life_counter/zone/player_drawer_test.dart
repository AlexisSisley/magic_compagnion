// test/widgets/life_counter/zone/player_drawer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';

const _defaultCommanderDamage = [
  CommanderDamageOpponent(
      playerId: 1, name: 'Sam', colorValue: 0xFFFF0000, damage: 0),
  CommanderDamageOpponent(
      playerId: 2, name: 'Mia', colorValue: 0xFF00FF00, damage: 6),
];

class _Captured {
  // Un record `(String, int)` plutôt qu'un `MapEntry` : `MapEntry` n'a pas
  // d'égalité structurelle (`==` par défaut est l'identité), donc deux
  // instances distinctes aux mêmes champs ne sont jamais `==` — ce qui fait
  // échouer `expect` même quand le comportement est correct. Les records ont
  // une égalité structurelle native en Dart 3.
  final counterDeltas = <(String, int)>[];
  final commanderDamageDeltas = <(int, int)>[];
  var monarchToggled = false;
  var eliminated = false;
  var reset = false;
  var rotated = false;
  var colorPickerOpened = false;
  var historyOpened = false;
}

Future<_Captured> _openDrawer(
  WidgetTester tester, {
  Map<String, int> counters = const {'poison': 0, 'energy': 0, 'commander_tax': 0},
  bool isMonarch = false,
  bool isEliminated = false,
  List<CommanderDamageOpponent> commanderDamage = _defaultCommanderDamage,
  int lethalCommanderDamage = 21,
}) async {
  final captured = _Captured();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPlayerDrawer(
              context: context,
              playerName: 'Alexis',
              counters: counters,
              isMonarch: isMonarch,
              isEliminated: isEliminated,
              onCounterDelta: (id, d) =>
                  captured.counterDeltas.add((id, d)),
              onToggleMonarch: () => captured.monarchToggled = true,
              onEliminate: () => captured.eliminated = true,
              onResetCounters: () => captured.reset = true,
              commanderDamage: commanderDamage,
              onCommanderDamageDelta: (sourceId, d) =>
                  captured.commanderDamageDeltas.add((sourceId, d)),
              lethalCommanderDamage: lethalCommanderDamage,
              onRotate: () => captured.rotated = true,
              onShowColorPicker: () => captured.colorPickerOpened = true,
              onShowHistory: () => captured.historyOpened = true,
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('affiche le nom du joueur et les trois compteurs',
      (tester) async {
    await _openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
    expect(find.text('Énergie'), findsOneWidget);
    expect(find.text('Taxe de commandant'), findsOneWidget);
  });

  testWidgets('incrémenter un compteur émet son delta', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('counter-poison-plus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [('poison', 1)]);
  });

  testWidgets('décrémenter un compteur émet son delta', (tester) async {
    final captured = await _openDrawer(tester, counters: {'poison': 2});
    await tester.tap(find.byKey(const ValueKey('counter-poison-minus')));
    await tester.pumpAndSettle();
    expect(captured.counterDeltas, [('poison', -1)]);
  });

  testWidgets('l\'action monarque appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    // « Historique du joueur » (revue finale, IMPORTANT #1) pousse Monarque
    // sous le pli dans ce test à petite fenêtre, comme Tourner et Couleur
    // l'avaient fait pour Éliminer : il faut défiler avant de taper, comme
    // un vrai doigt le ferait.
    await tester.ensureVisible(find.byKey(const ValueKey('action-monarch')));
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(captured.monarchToggled, isTrue);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
  });

  testWidgets('l\'action éliminer appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    // Tourner + Couleur (ronde de correction 1, tâche 2) poussent Éliminer
    // sous le pli du tiroir dans ce test à petite fenêtre : il faut le
    // faire défiler avant de le taper, comme un vrai doigt le ferait.
    await tester.ensureVisible(find.byKey(const ValueKey('action-eliminate')));
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();
    expect(captured.eliminated, isTrue);
    expect(captured.monarchToggled, isFalse);
  });

  testWidgets(
      'l\'action tourner appelle onRotate (ronde de correction 1, tâche 2)',
      (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-rotate')));
    await tester.pumpAndSettle();
    expect(captured.rotated, isTrue);
    expect(captured.colorPickerOpened, isFalse);
  });

  testWidgets(
      'l\'action couleur appelle onShowColorPicker (ronde de correction 1, '
      'tâche 2)', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-color')));
    await tester.pumpAndSettle();
    expect(captured.colorPickerOpened, isTrue);
    expect(captured.rotated, isFalse);
  });

  // Revue finale (IMPORTANT #1) : `PlayerHistorySheet` n'avait qu'un point
  // d'entrée, `onNameTap` sur `PlayerHeader`, masqué au cran `minimal` --
  // l'historique PAR JOUEUR devenait injoignable à 8 joueurs sur téléphone.
  // L'action « Historique » de la bande et du hub ouvre l'historique GLOBAL,
  // pas celui-ci.
  testWidgets('l\'action historique du joueur appelle onShowHistory',
      (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-player-history')));
    await tester.pumpAndSettle();
    expect(captured.historyOpened, isTrue);
    expect(captured.rotated, isFalse);
    expect(captured.colorPickerOpened, isFalse);
  });

  testWidgets('l\'action réinitialiser appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('action-reset')));
    await tester.tap(find.byKey(const ValueKey('action-reset')));
    await tester.pumpAndSettle();
    expect(captured.reset, isTrue);
    expect(captured.eliminated, isFalse);
  });

  testWidgets(
      'affiche la grille de dégâts de commandant reçus, une ligne par '
      'adversaire avec son total', (tester) async {
    await _openDrawer(tester);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Mia'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets(
      'taper + sur une ligne de la grille émet onCommanderDamageDelta avec '
      'l\'id de CETTE ligne, sans fermer le tiroir', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('commander-damage-2-plus')));
    await tester.pump();

    expect(captured.commanderDamageDeltas, [(2, 1)]);
    expect(captured.monarchToggled, isFalse);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
    expect(find.text('Alexis'), findsOneWidget,
        reason: 'contrairement aux actions, la grille est un filet de '
            'rattrapage consulté à chaud : le tiroir doit rester ouvert');
    expect(find.text('7'), findsOneWidget,
        reason: 'la copie locale de la grille doit refléter le nouveau '
            'total immédiatement, comme les compteurs');
  });

  testWidgets(
      'ronde de correction 1 (Important, "seconde porte") — un seuil '
      'letal de 0 (format sans commandant, ex. Standard) masque la grille '
      'de dégâts de commandant', (tester) async {
    await _openDrawer(tester, lethalCommanderDamage: 0);

    expect(find.byType(CommanderDamageGrid), findsNothing);
    expect(find.text('Sam'), findsNothing);
    expect(find.text('Mia'), findsNothing);
    // Le reste du tiroir reste intact.
    expect(find.text('Alexis'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
  });

  testWidgets('une action ferme le tiroir', (tester) async {
    await _openDrawer(tester);
    expect(find.text('Alexis'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('action-monarch')));
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(find.text('Alexis'), findsNothing,
        reason: 'le tiroir se referme avant de déclencher l\'action');
  });

  testWidgets('l\'action monarque change de libellé selon l\'état',
      (tester) async {
    await _openDrawer(tester, isMonarch: false);
    expect(find.text('Monarque'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // ferme le sheet
    await tester.pumpAndSettle();

    await _openDrawer(tester, isMonarch: true);
    expect(find.text('Retirer le monarque'), findsOneWidget);
  });

  testWidgets('l\'action éliminer devient annuler pour un joueur éliminé',
      (tester) async {
    await _openDrawer(tester, isEliminated: true);
    expect(find.text('Annuler l\'élimination'), findsOneWidget);
  });
}
