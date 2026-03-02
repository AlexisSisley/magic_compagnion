// Tests unitaires pour PlayerZoneController
// Teste la logique d'etat, les helpers mode/display et la rotation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/player_zone_controller.dart';

void main() {
  // =================================================================
  // PlayerZoneState - Tests unitaires purs sur l'etat immutable
  // =================================================================

  group('PlayerZoneState', () {
    test('initial state defaults to life mode', () {
      const state = PlayerZoneState();

      expect(state.editMode, CounterMode.life);
      expect(state.floatingNumbers, isEmpty);
      expect(state.nextNumberId, 0);
      expect(state.dragAccumulator, 0.0);
    });

    test('copyWith preserves values when not specified', () {
      const state = PlayerZoneState(
        editMode: CounterMode.poison,
        nextNumberId: 5,
        dragAccumulator: 12.5,
      );

      final copied = state.copyWith(nextNumberId: 10);

      expect(copied.editMode, CounterMode.poison);
      expect(copied.nextNumberId, 10);
      expect(copied.dragAccumulator, 12.5);
    });
  });

  // =================================================================
  // PlayerZoneController - Tests de la logique metier
  // =================================================================

  group('PlayerZoneController', () {
    late PlayerZoneController controller;

    setUp(() {
      controller = PlayerZoneController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('triggerChange in life mode returns life type and creates floating number', () {
      final result = controller.triggerChange(
        3,
        currentLife: 20,
        currentPoison: 0,
        currentEnergy: 0,
        currentCommanderTax: 0,
      );

      expect(result.type, 'life');
      expect(result.change, 3);
      expect(result.newValue, 23);
      // A floating number should have been added
      expect(controller.state.floatingNumbers, hasLength(1));
      expect(controller.state.floatingNumbers.first.text, '+3');
    });

    test('triggerChange in poison mode clamps value between 0 and 99', () {
      controller.setEditMode(CounterMode.poison);

      final result = controller.triggerChange(
        -5,
        currentLife: 20,
        currentPoison: 3,
        currentEnergy: 0,
        currentCommanderTax: 0,
      );

      expect(result.type, 'CounterMode.poison');
      expect(result.newValue, 0); // clamped to 0
    });

    test('setEditMode changes the current mode', () {
      expect(controller.state.editMode, CounterMode.life);

      controller.setEditMode(CounterMode.energy);
      expect(controller.state.editMode, CounterMode.energy);

      controller.setEditMode(CounterMode.commanderTax);
      expect(controller.state.editMode, CounterMode.commanderTax);
    });

    test('getDisplayValue returns correct value per mode', () {
      const life = 20;
      const poison = 5;
      const energy = 3;
      const cmdTax = 2;

      // Life mode (default)
      expect(
        controller.getDisplayValue(life: life, poison: poison, energy: energy, commanderTax: cmdTax),
        '20',
      );

      // Poison mode
      controller.setEditMode(CounterMode.poison);
      expect(
        controller.getDisplayValue(life: life, poison: poison, energy: energy, commanderTax: cmdTax),
        '5',
      );

      // Energy mode
      controller.setEditMode(CounterMode.energy);
      expect(
        controller.getDisplayValue(life: life, poison: poison, energy: energy, commanderTax: cmdTax),
        '3',
      );

      // Commander tax mode
      controller.setEditMode(CounterMode.commanderTax);
      expect(
        controller.getDisplayValue(life: life, poison: poison, energy: energy, commanderTax: cmdTax),
        '2',
      );
    });

    test('rotate90Degrees cycles through quarter turns', () {
      expect(controller.rotate90Degrees(0), 1);
      expect(controller.rotate90Degrees(1), 2);
      expect(controller.rotate90Degrees(2), 3);
      expect(controller.rotate90Degrees(3), 0); // wraps around
    });

    test('handleRotationDrag returns null below threshold and new rotation above', () {
      // Small drag below threshold - should return null
      final result1 = controller.handleRotationDrag(10.0, 0);
      expect(result1, isNull);
      expect(controller.state.dragAccumulator, 10.0);

      // Continue drag past threshold (40.0 total)
      final result2 = controller.handleRotationDrag(35.0, 0);
      expect(result2, 1); // positive direction -> +1
      expect(controller.state.dragAccumulator, 0.0); // reset after trigger
    });

    test('handleRotationDrag handles negative direction', () {
      // Drag left past threshold
      final result = controller.handleRotationDrag(-50.0, 2);
      expect(result, 1); // (2 - 1) % 4 = 1
      expect(controller.state.dragAccumulator, 0.0);
    });

    test('handleRotationDrag wraps around from 0 in negative direction', () {
      final result = controller.handleRotationDrag(-50.0, 0);
      expect(result, 3); // (0 - 1) % 4 -> -1 + 4 = 3
      expect(controller.state.dragAccumulator, 0.0);
    });
  });

  // =================================================================
  // Static helpers - getModeColor / getModeIcon
  // =================================================================

  group('PlayerZoneController static helpers', () {
    test('getModeColor returns correct colors per mode', () {
      expect(PlayerZoneController.getModeColor(CounterMode.life), Colors.white);
      expect(PlayerZoneController.getModeColor(CounterMode.poison), Colors.greenAccent);
      expect(PlayerZoneController.getModeColor(CounterMode.energy), Colors.blueAccent);
      expect(PlayerZoneController.getModeColor(CounterMode.commanderTax), Colors.amber);
    });

    test('getModeIcon returns correct icons per mode', () {
      expect(PlayerZoneController.getModeIcon(CounterMode.life), Icons.favorite);
      expect(PlayerZoneController.getModeIcon(CounterMode.poison), Icons.science);
      expect(PlayerZoneController.getModeIcon(CounterMode.energy), Icons.flash_on);
      expect(PlayerZoneController.getModeIcon(CounterMode.commanderTax), Icons.local_police);
    });
  });

  // =================================================================
  // FloatingNumber / CounterChangeResult
  // =================================================================

  group('FloatingNumber', () {
    test('has correct defaults', () {
      final fn = FloatingNumber(id: 0, text: '+1', color: Colors.green);
      expect(fn.top, 20.0);
      expect(fn.opacity, 1.0);
    });
  });

  group('CounterChangeResult', () {
    test('stores values correctly', () {
      const result = CounterChangeResult(type: 'life', change: -3, newValue: 17);
      expect(result.type, 'life');
      expect(result.change, -3);
      expect(result.newValue, 17);
    });
  });
}
