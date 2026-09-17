// test/widgets/life_counter/zone/player_drawer_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';

const _defaultCommanderDamage = [
  CommanderDamageOpponent(
      playerId: 1, name: 'Sam', colorValue: 0xFFFF0000, damage: 0),
  CommanderDamageOpponent(
      playerId: 2, name: 'Mia', colorValue: 0xFF00FF00, damage: 6),
];

// Les deux compteurs intégrés du catalogue (tâche 1,
// lib/models/counter_type.dart) que le format Standard active
// (enabledCounterIds: ['poison', 'energy'], game_format.dart). 'Taxe de
// commandant' n'y figure pas : c'est exactement ce qui distingue le défaut
// Standard corrigé par cette tâche.
const _poison = CounterType(
  id: 'poison',
  name: 'Poison',
  emoji: '☠️',
  color: 0xFF4CAF50,
  isBuiltIn: true,
  maxValue: 10,
);
const _energy = CounterType(
  id: 'energy',
  name: 'Energy',
  emoji: '⚡',
  color: 0xFFFF9800,
  isBuiltIn: true,
);
const _defaultActiveCounters = [_poison, _energy];

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
}

Future<_Captured> _openDrawer(
  WidgetTester tester, {
  List<CounterType> activeCounters = _defaultActiveCounters,
  Map<String, int> counters = const {'poison': 0, 'energy': 0},
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
              activeCounters: activeCounters,
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
  testWidgets(
      'régression Standard — un tiroir monté avec les seuls compteurs actifs '
      'poison et énergie affiche exactement ces deux lignes, jamais la taxe '
      'de commandant', (tester) async {
    await _openDrawer(tester, activeCounters: _defaultActiveCounters);

    expect(find.text('Alexis'), findsOneWidget);
    expect(find.byKey(const ValueKey('counter_row_poison')), findsOneWidget);
    expect(find.byKey(const ValueKey('counter_row_energy')), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    // Le défaut exact que cette tâche corrige : le tiroir affichait la taxe
    // de commandant même quand le format ne l'active pas (Standard).
    expect(find.text('Commander Tax'), findsNothing);
    expect(
        find.byKey(const ValueKey('counter_row_commander_tax')), findsNothing);
  });

  testWidgets(
      'ronde de correction 1 — les compteurs intégrés du catalogue réel '
      '(CounterType.builtInCounters, pas des doublures locales) affichent '
      'leurs libellés en français, jamais en anglais', (tester) async {
    // Utilise directement CounterType.builtInCounters (pas _poison/_energy,
    // des doublures locales à ce fichier) : c'est la seule façon de figer le
    // vrai nom du catalogue -- une régression sur le `name` du modèle ne
    // toucherait pas des constantes de test dupliquées.
    final builtIns = CounterType.builtInCounters
        .where((t) => t.id == 'energy' || t.id == 'commander_tax')
        .toList();
    await _openDrawer(
      tester,
      activeCounters: builtIns,
      counters: {for (final t in builtIns) t.id: 0},
    );

    expect(find.text('Énergie'), findsOneWidget);
    expect(find.text('Taxe de commandant'), findsOneWidget);
    expect(find.text('Energy'), findsNothing);
    expect(find.text('Commander Tax'), findsNothing);
  });

  testWidgets(
      'un compteur personnalisé dans les actifs affiche son nom et son emoji',
      (tester) async {
    const custom = CounterType(
      id: 'custom_heat',
      name: 'Chaleur',
      emoji: '🔥',
      color: 0xFFFF5722,
      isBuiltIn: false,
    );
    await _openDrawer(
      tester,
      activeCounters: const [_poison, custom],
      counters: const {'poison': 0, 'custom_heat': 3},
    );

    expect(find.byKey(const ValueKey('counter_row_custom_heat')),
        findsOneWidget);
    expect(find.text('Chaleur'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
      'taper + sur la ligne du DEUXIÈME compteur émet son id, pas celui du '
      'premier — un tiroir qui émettrait toujours l\'id de la première ligne '
      'resterait vert sur un test qui ne vérifie que "un delta a été émis"',
      (tester) async {
    const alpha = CounterType(
      id: 'alpha', name: 'Alpha', emoji: '🅰️', color: 0xFF000001);
    const beta = CounterType(
      id: 'beta', name: 'Beta', emoji: '🅱️', color: 0xFF000002);
    final captured = await _openDrawer(
      tester,
      activeCounters: const [alpha, beta],
      counters: const {'alpha': 0, 'beta': 0},
    );

    final betaRow = find.byKey(const ValueKey('counter_row_beta'));
    final betaPlus = find.descendant(
      of: betaRow,
      matching: find.byKey(const ValueKey('counter_row_beta_plus')),
    );
    await tester.tap(betaPlus);
    await tester.pump();

    expect(captured.counterDeltas, [('beta', 1)],
        reason: 'seul beta (deuxième ligne) doit avoir bougé, pas alpha');
  });

  testWidgets(
      'taper − sur la ligne du DEUXIÈME compteur émet aussi son id, pas '
      'celui du premier', (tester) async {
    const alpha = CounterType(
      id: 'alpha', name: 'Alpha', emoji: '🅰️', color: 0xFF000001);
    const beta = CounterType(
      id: 'beta', name: 'Beta', emoji: '🅱️', color: 0xFF000002);
    final captured = await _openDrawer(
      tester,
      activeCounters: const [alpha, beta],
      counters: const {'alpha': 5, 'beta': 5},
    );

    final betaRow = find.byKey(const ValueKey('counter_row_beta'));
    final betaMinus = find.descendant(
      of: betaRow,
      matching: find.byKey(const ValueKey('counter_row_beta_minus')),
    );
    await tester.tap(betaMinus);
    await tester.pump();

    expect(captured.counterDeltas, [('beta', -1)]);
  });

  testWidgets(
      'l\'ordre d\'affichage suit activeCounters, pas l\'ordre du catalogue',
      (tester) async {
    // energy avant poison ici, alors que le catalogue (task 1) liste poison
    // en premier — l'affichage doit respecter CET ordre-là, pas celui du
    // catalogue.
    await _openDrawer(
      tester,
      activeCounters: const [_energy, _poison],
    );

    final energyTop = tester.getTopLeft(
        find.byKey(const ValueKey('counter_row_energy')));
    final poisonTop = tester.getTopLeft(
        find.byKey(const ValueKey('counter_row_poison')));
    expect(energyTop.dy, lessThan(poisonTop.dy),
        reason: 'energy est passé en premier dans activeCounters, il doit '
            's\'afficher au-dessus de poison');
  });

  testWidgets('l\'action monarque appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-monarch')));
    await tester.pumpAndSettle();
    expect(captured.monarchToggled, isTrue);
    expect(captured.eliminated, isFalse);
    expect(captured.reset, isFalse);
  });

  testWidgets('l\'action éliminer appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('action-eliminate')));
    await tester.pumpAndSettle();
    expect(captured.eliminated, isTrue);
    expect(captured.monarchToggled, isFalse);
  });

  testWidgets('l\'action réinitialiser appelle son callback', (tester) async {
    final captured = await _openDrawer(tester);
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
