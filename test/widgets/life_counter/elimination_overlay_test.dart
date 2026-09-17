// Fichier : test/widgets/life_counter/elimination_overlay_test.dart
// Task 13: TDD tests for EliminationOverlay widget

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/elimination_overlay.dart';

void main() {
  group('EliminationOverlay', () {
    Widget buildWidget({
      required bool isEliminated,
      VoidCallback? onAnimationComplete,
      Widget child = const SizedBox(
        key: Key('child'),
        width: 100,
        height: 100,
      ),
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: EliminationOverlay(
              isEliminated: isEliminated,
              onAnimationComplete: onAnimationComplete,
              child: child,
            ),
          ),
        ),
      );
    }

    // Revue finale, Critical #2 : la profondeur de l arbre rendu par
    // `EliminationOverlay` doit être INVARIANTE. La version précédente
    // renvoyait `widget.child` nu tant que le joueur n était pas éliminé et
    // l enveloppait dans un `Stack` ensuite : basculer détruisait puis
    // recréait tout le sous-arbre, donc le `State` de `LifeDial`.
    //
    // Aucun geste ne traverse cette bascule dans l application AUJOURD HUI
    // (l élimination passe par une confirmation explicite, jamais par un
    // seuil franchi en plein glissé) : ce test garde la propriété
    // structurelle, pas un scénario utilisateur observé.
    testWidgets(
        'basculer isEliminated ne recrée PAS le State de son enfant '
        '(profondeur de l arbre invariante)', (tester) async {
      var inits = 0;
      await tester.pumpWidget(buildWidget(
        isEliminated: false,
        child: _StateProbe(onInit: () => inits++),
      ));
      expect(inits, 1, reason: 'précondition : une seule création au montage');

      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        child: _StateProbe(onInit: () => inits++),
      ));
      await tester.pump();

      expect(inits, 1,
          reason: 'la bascule ne doit insérer ni retirer aucun niveau '
              'au-dessus de son enfant');
    });

    testWidgets('non-eliminated state shows child', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('non-eliminated state does not show skull icon', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      await tester.pump();
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsNothing);
    });

    testWidgets('contains child widget when not eliminated', (tester) async {
      const childKey = Key('my_child');
      await tester.pumpWidget(buildWidget(
        isEliminated: false,
        child: const Text('Player 1', key: childKey),
      ));
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('eliminated state eventually shows elimination icon after animation', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: true));

      // Pump through all animation phases (900ms total)
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));

      // After animation completes, elimination icon should be visible
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsOneWidget);
    });

    testWidgets('child is still present when eliminated', (tester) async {
      const childKey = Key('child_under');
      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        child: const SizedBox(key: childKey, width: 100, height: 100),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(childKey), findsOneWidget);
    });

    testWidgets('onAnimationComplete callback is called after animation', (tester) async {
      bool called = false;
      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        onAnimationComplete: () => called = true,
      ));

      // Pump through all 900ms of animation
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));

      expect(called, isTrue);
    });

    testWidgets('widget can switch from eliminated to not-eliminated', (tester) async {
      bool isEliminated = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: EliminationOverlay(
                        isEliminated: isEliminated,
                        child: const SizedBox(width: 100, height: 100),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() => isEliminated = false),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.byIcon(EliminationOverlay.eliminationIcon), findsNothing);
    });

    testWidgets('EliminationOverlay widget exists in tree', (tester) async {
      await tester.pumpWidget(buildWidget(isEliminated: false));
      expect(find.byType(EliminationOverlay), findsOneWidget);
    });

    testWidgets(
        "un enfant tapable reste atteignable une fois l'animation "
        "d'élimination terminée (verrou anti-régression)",
        (tester) async {
      // Ronde 1 de revue de la tâche 6 : les trois couches décoratives
      // (flash, fissures, cache sombre + icône) absorbaient tous les gestes
      // sur la zone une fois éliminée — la phase 3 reste affichée en
      // permanence après l'animation et n'avait pas d'`IgnorePointer`. Ça
      // rendait "Annuler l'élimination" injoignable dans l'app réelle malgré
      // un câblage logique correct, et rien ici ne le détectait puisqu'aucun
      // test ne traversait l'overlay au doigt. Ce test protège le composant
      // lui-même, indépendamment de qui l'utilise.
      var tapped = false;
      await tester.pumpWidget(buildWidget(
        isEliminated: true,
        child: GestureDetector(
          key: const Key('tappable_child'),
          // `HitTestBehavior.opaque` : un `SizedBox` sans couleur ne
          // s'enregistre pas lui-même comme hit (`HitTestBehavior.deferToChild`,
          // le défaut de `GestureDetector`, dépend du hit propre de l'enfant).
          // Sans ce réglage explicite, ce test échouerait même sans aucun
          // `Container` opaque devant lui — pour un défaut qui n'a rien à voir
          // avec `EliminationOverlay`.
          behavior: HitTestBehavior.opaque,
          onTap: () => tapped = true,
          child: const SizedBox(width: 100, height: 100),
        ),
      ));

      // Traverse toute l'animation (900ms) pour atteindre l'état statique
      // final (cache sombre + icône), celui qui reste affiché en permanence.
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.tap(find.byKey(const Key('tappable_child')));
      await tester.pump();

      expect(
        tapped,
        isTrue,
        reason: 'les trois couches décoratives sont purement visuelles : un '
            "IgnorePointer manquant sur l'une d'elles bloquerait tous les "
            'gestes sur une zone éliminée, y compris ceux qui doivent '
            'rester ouverts',
      );
    });
  });
}

/// Enfant sonde : compte les créations de `State`. Si un ancêtre change la
/// PROFONDEUR de l arbre au-dessus de lui, Flutter ne peut plus apparier son
/// `Element`, détruit le sous-arbre et recrée ce `State` — ce compteur le
/// voit. C est exactement ce qui tuait le geste en cours dans `LifeDial`
/// (revue finale, Critical #2).
class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(key: Key('child'), width: 100, height: 100);
}
