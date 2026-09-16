// lib/providers/player_zone_notifier.dart
// État local d'une zone joueur : nombres flottants, rotation, mode ajustement.
//
// Remplace lib/controllers/player_zone_controller.dart, bâti sur les modes de
// compteur (life/poison/energy/commanderTax) que la zone V4 n'a plus : le
// chiffre n'affiche que les PV, les compteurs vivent dans le tiroir.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Un nombre flottant (+3 / −5) qui monte et s'efface.
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

class PlayerZoneState {
  final List<FloatingNumber> floatingNumbers;
  final int nextNumberId;
  final double rotationAccumulator;
  final bool isAdjusting;
  final double wheelAccumulator;
  final double wheelGestureDistance;

  const PlayerZoneState({
    this.floatingNumbers = const [],
    this.nextNumberId = 0,
    this.rotationAccumulator = 0.0,
    this.isAdjusting = false,
    this.wheelAccumulator = 0.0,
    this.wheelGestureDistance = 0.0,
  });

  PlayerZoneState copyWith({
    List<FloatingNumber>? floatingNumbers,
    int? nextNumberId,
    double? rotationAccumulator,
    bool? isAdjusting,
    double? wheelAccumulator,
    double? wheelGestureDistance,
  }) {
    return PlayerZoneState(
      floatingNumbers: floatingNumbers ?? this.floatingNumbers,
      nextNumberId: nextNumberId ?? this.nextNumberId,
      rotationAccumulator: rotationAccumulator ?? this.rotationAccumulator,
      isAdjusting: isAdjusting ?? this.isAdjusting,
      wheelAccumulator: wheelAccumulator ?? this.wheelAccumulator,
      wheelGestureDistance: wheelGestureDistance ?? this.wheelGestureDistance,
    );
  }
}

class PlayerZoneNotifier extends Notifier<PlayerZoneState> {
  /// `NotifierProvider.family` (riverpod 3, API publique non-codegen) attend
  /// un `create` de forme `NotifierT Function(ArgT arg)` : le tear-off
  /// `PlayerZoneNotifier.new` n'est un `Function(int)` valide que si le
  /// constructeur accepte cet argument. La ségrégation entre joueurs vient
  /// déjà de `.family` (un état par clé `playerId`) — ce paramètre ne sert
  /// qu'à satisfaire la signature et n'est donc pas conservé.
  PlayerZoneNotifier(int playerId);

  /// Glissement horizontal cumulé, en pixels, avant de tourner d'un quart.
  static const double rotationThreshold = 40.0;

  /// Pixels de glissement vertical pour un point de vie, en vitesse normale.
  static const double wheelPixelsPerUnit = 8.0;

  /// Au-delà de ce déplacement (px) dans un seul geste, la molette accélère.
  static const double wheelAccelerationThreshold = 120.0;

  @override
  PlayerZoneState build() => const PlayerZoneState();

  // --- Mode ajustement ---

  void enterAdjustMode() {
    state = state.copyWith(
      isAdjusting: true,
      wheelAccumulator: 0.0,
      wheelGestureDistance: 0.0,
    );
  }

  void exitAdjustMode() {
    state = state.copyWith(
      isAdjusting: false,
      wheelAccumulator: 0.0,
      wheelGestureDistance: 0.0,
    );
  }

  /// Consomme un glissement vertical et renvoie le nombre de points à appliquer.
  ///
  /// `dy` suit la convention Flutter : négatif vers le haut. Un glissement vers
  /// le haut ajoute des PV, d'où l'inversion de signe.
  /// Renvoie 0 tant que le seuil d'un point n'est pas atteint ; le reste est
  /// conservé pour l'appel suivant, sans quoi une série de petits glissements
  /// ne produirait jamais rien.
  ///
  /// Revue globale de branche (Critical) : la décision d'accélérer se prend
  /// sur `wheelGestureDistance`, la distance **totale** du geste depuis
  /// l'entrée en mode ajustement, jamais réduite par la consommation de pas —
  /// pas sur `wheelAccumulator`, le résidu sous 8px qui, lui, repart
  /// (presque) de zéro après chaque pas consommé. Sur un appareil réel,
  /// `handleWheelDrag` est appelé une fois par `PointerMoveEvent` (~10px à
  /// 60fps) : le résidu ne dépasse donc jamais quelques pixels et n'atteint
  /// jamais le seuil de 120px, quelle que soit la longueur du geste — seul
  /// un test qui appelle la méthode une seule fois avec un très grand `dy`
  /// pouvait déclencher l'accélération, une chronologie que l'appareil ne
  /// produit jamais.
  int handleWheelDrag(double dy) {
    if (!state.isAdjusting) return 0;

    final accumulated = state.wheelAccumulator + (-dy);
    final magnitude = accumulated.abs();

    final gestureDistance = state.wheelGestureDistance + (-dy);
    final gestureMagnitude = gestureDistance.abs();
    final accelerated = gestureMagnitude > wheelAccelerationThreshold;

    // Au-delà du seuil, chaque pixel supplémentaire compte double : un grand
    // geste doit couvrir une grosse perte de PV sans traverser l'écran.
    final double effective = accelerated ? magnitude * 2 : magnitude;

    final steps = (effective / wheelPixelsPerUnit).floor();
    if (steps == 0) {
      state = state.copyWith(
        wheelAccumulator: accumulated,
        wheelGestureDistance: gestureDistance,
      );
      return 0;
    }

    // Le résidu se tient en pixels bruts, pas en pixels « effectifs » : on
    // convertit donc les pixels consommés dans l'autre sens avant de calculer
    // ce qu'il reste.
    final consumedEffective = steps * wheelPixelsPerUnit;
    final consumedRaw = accelerated ? consumedEffective / 2 : consumedEffective;
    final remaining = magnitude - consumedRaw;
    state = state.copyWith(
      wheelAccumulator: accumulated.isNegative ? -remaining : remaining,
      wheelGestureDistance: gestureDistance,
    );
    return accumulated.isNegative ? -steps : steps;
  }

  // --- Nombres flottants ---

  /// Ajoute un nombre flottant et renvoie l'id qui lui a été assigné, pour
  /// que l'appelant puisse l'animer puis le retirer plus tard (voir
  /// `animateFloatingNumber`/`removeFloatingNumber`) sans avoir à connaître
  /// par ailleurs la façon dont cet id est choisi — un `ref.read` séparé sur
  /// `nextNumberId` juste avant l'appel serait un couplage implicite à cette
  /// implémentation interne.
  int showFloatingNumber(int delta) {
    final text = delta > 0 ? '+$delta' : '$delta';
    final color = delta > 0 ? AppColors.accentGreen : AppColors.accentRed;
    final id = state.nextNumberId;
    state = state.copyWith(
      floatingNumbers: [
        ...state.floatingNumbers,
        FloatingNumber(id: id, text: text, color: color),
      ],
      nextNumberId: id + 1,
    );
    return id;
  }

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

  void removeFloatingNumber(int id) {
    state = state.copyWith(
      floatingNumbers: state.floatingNumbers.where((n) => n.id != id).toList(),
    );
  }

  // --- Rotation ---

  int rotate90Degrees(int currentQuarterTurns) => (currentQuarterTurns + 1) % 4;

  /// Remet l'accumulateur de rotation à zéro sans toucher au reste de
  /// l'état. Appelé au début de chaque nouveau geste de glissement
  /// (`onLongPressStart`) : le résidu d'un geste précédent, achevé sans
  /// franchir le seuil, ne doit pas se combiner avec un nouveau geste sans
  /// rapport (position de doigt différente, direction potentiellement
  /// opposée) — sans quoi le nouveau geste hériterait d'un biais invisible
  /// pour l'utilisateur.
  void resetRotationDrag() {
    state = state.copyWith(rotationAccumulator: 0.0);
  }

  int? handleRotationDrag(double delta, int currentQuarterTurns) {
    final accumulated = state.rotationAccumulator + delta;
    if (accumulated.abs() <= rotationThreshold) {
      state = state.copyWith(rotationAccumulator: accumulated);
      return null;
    }
    final direction = accumulated > 0 ? 1 : -1;
    var next = (currentQuarterTurns + direction) % 4;
    if (next < 0) next += 4;
    state = state.copyWith(rotationAccumulator: 0.0);
    return next;
  }

  void reset() {
    state = const PlayerZoneState();
  }
}

final playerZoneNotifierProvider =
    NotifierProvider.family<PlayerZoneNotifier, PlayerZoneState, int>(
  PlayerZoneNotifier.new,
);
