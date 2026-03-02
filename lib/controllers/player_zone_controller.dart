// Fichier : lib/controllers/player_zone_controller.dart
// Controller pour PlayerZone - extrait la logique metier du widget.

import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

// --- ENUM ---

enum CounterMode { life, poison, energy, commanderTax }

// --- FLOATING NUMBER (donnee UI reactive) ---

class FloatingNumber {
  final int id;
  final String text;
  final Color color;
  double top;
  double opacity;

  FloatingNumber({
    required this.id,
    required this.text,
    required this.color,
    this.top = 20.0,
    this.opacity = 1.0,
  });
}

// --- ETAT IMMUTABLE ---

class PlayerZoneState {
  final CounterMode editMode;
  final List<FloatingNumber> floatingNumbers;
  final int nextNumberId;
  final double dragAccumulator;

  const PlayerZoneState({
    this.editMode = CounterMode.life,
    this.floatingNumbers = const [],
    this.nextNumberId = 0,
    this.dragAccumulator = 0.0,
  });

  PlayerZoneState copyWith({
    CounterMode? editMode,
    List<FloatingNumber>? floatingNumbers,
    int? nextNumberId,
    double? dragAccumulator,
  }) {
    return PlayerZoneState(
      editMode: editMode ?? this.editMode,
      floatingNumbers: floatingNumbers ?? this.floatingNumbers,
      nextNumberId: nextNumberId ?? this.nextNumberId,
      dragAccumulator: dragAccumulator ?? this.dragAccumulator,
    );
  }
}

// --- RESULT pour les changements de compteur ---

class CounterChangeResult {
  final String type;
  final int change;
  final int? newValue;

  const CounterChangeResult({
    required this.type,
    required this.change,
    this.newValue,
  });
}

// --- CONTROLLER (StateNotifier) ---

class PlayerZoneController extends StateNotifier<PlayerZoneState> {
  static const double rotationThreshold = 40.0;

  PlayerZoneController() : super(const PlayerZoneState());

  // --- MODE ---

  void setEditMode(CounterMode mode) {
    state = state.copyWith(editMode: mode);
  }

  // --- COUNTER LOGIC ---

  /// Calcule le changement et retourne un CounterChangeResult.
  /// Le widget est responsable de muter le Player model et d'appeler les callbacks.
  CounterChangeResult triggerChange(int change, {
    required int currentLife,
    required int currentPoison,
    required int currentEnergy,
    required int currentCommanderTax,
  }) {
    final mode = state.editMode;

    if (mode == CounterMode.life) {
      final newLife = currentLife + change;
      _showFloatingNumber(change, isLife: true);
      return CounterChangeResult(type: 'life', change: change, newValue: newLife);
    }

    int newValue;
    switch (mode) {
      case CounterMode.poison:
        newValue = (currentPoison + change).clamp(0, 99);
        break;
      case CounterMode.energy:
        newValue = (currentEnergy + change).clamp(0, 99);
        break;
      case CounterMode.commanderTax:
        newValue = (currentCommanderTax + change).clamp(0, 99);
        break;
      default:
        newValue = currentLife + change;
    }
    _showFloatingNumber(change, isLife: false);
    return CounterChangeResult(type: mode.toString(), change: change, newValue: newValue);
  }

  // --- FLOATING NUMBERS ---

  void _showFloatingNumber(int change, {bool isLife = true}) {
    final String text = (change > 0) ? '+$change' : '$change';
    Color color;
    if (isLife) {
      color = (change > 0) ? AppColors.accentGreen : AppColors.accentRed;
    } else {
      color = getModeColor(state.editMode);
    }

    final int id = state.nextNumberId;
    final number = FloatingNumber(id: id, text: text, color: color);
    state = state.copyWith(
      floatingNumbers: [...state.floatingNumbers, number],
      nextNumberId: id + 1,
    );
  }

  /// Declenche l'animation de depart (appele par un Timer dans le widget).
  void animateFloatingNumber(int id) {
    final updated = state.floatingNumbers.map((n) {
      if (n.id == id) {
        n.top = -50.0;
        n.opacity = 0.0;
      }
      return n;
    }).toList();
    state = state.copyWith(floatingNumbers: updated);
  }

  /// Supprime un floating number termine (appele par un Timer dans le widget).
  void removeFloatingNumber(int id) {
    final updated = state.floatingNumbers.where((n) => n.id != id).toList();
    state = state.copyWith(floatingNumbers: updated);
  }

  // --- DISPLAY HELPERS ---

  String getDisplayValue({
    required int life,
    required int poison,
    required int energy,
    required int commanderTax,
  }) {
    switch (state.editMode) {
      case CounterMode.poison:
        return '$poison';
      case CounterMode.energy:
        return '$energy';
      case CounterMode.commanderTax:
        return '$commanderTax';
      default:
        return '$life';
    }
  }

  // --- MODE HELPERS (statiques, utilisables partout) ---

  static Color getModeColor(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison:
        return AppColors.accentGreen;
      case CounterMode.energy:
        return AppColors.accent;
      case CounterMode.commanderTax:
        return AppColors.amber;
      default:
        return AppColors.textPrimary;
    }
  }

  static IconData getModeIcon(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison:
        return Icons.science;
      case CounterMode.energy:
        return Icons.flash_on;
      case CounterMode.commanderTax:
        return Icons.local_police;
      default:
        return Icons.favorite;
    }
  }

  // --- ROTATION ---

  /// Rotation simple de 90 degres. Retourne le nouveau quarterTurns.
  int rotate90Degrees(int currentQuarterTurns) {
    return (currentQuarterTurns + 1) % 4;
  }

  /// Gestion du drag de rotation. Retourne le nouveau quarterTurns ou null si pas de changement.
  int? handleRotationDrag(double delta, int currentQuarterTurns) {
    final newAccumulator = state.dragAccumulator + delta;
    state = state.copyWith(dragAccumulator: newAccumulator);

    if (newAccumulator.abs() > rotationThreshold) {
      int direction = newAccumulator > 0 ? 1 : -1;
      int newRot = (currentQuarterTurns + direction) % 4;
      if (newRot < 0) newRot += 4;
      state = state.copyWith(dragAccumulator: 0.0);
      return newRot;
    }
    return null;
  }

  /// Reset de l'accumulateur de drag.
  void resetDragAccumulator() {
    state = state.copyWith(dragAccumulator: 0.0);
  }
}

// --- PROVIDER (.family par playerId) ---

final playerZoneControllerProvider = StateNotifierProvider.autoDispose
    .family<PlayerZoneController, PlayerZoneState, int>(
  (ref, playerId) => PlayerZoneController(),
);
