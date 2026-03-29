enum AnimationType {
  pulseLight,
  pulseHeavy,
  shakeLight,
  shakeMedium,
  shakeHeavy,
  poisonTint,
  commanderPulse,
  elimination,
}

enum CriticalLevel { safe, warning, danger, lethal }

class AnimationConfig {
  final AnimationType type;
  final int durationMs;
  final bool haptic;

  const AnimationConfig({
    required this.type,
    required this.durationMs,
    this.haptic = false,
  });
}

class AnimationService {
  const AnimationService._();

  static AnimationConfig getLifeAnimation({
    required int delta,
    required int currentLife,
    required int startingLife,
  }) {
    if (delta > 0) {
      if (delta <= 5) {
        return const AnimationConfig(type: AnimationType.pulseLight, durationMs: 200);
      }
      return const AnimationConfig(type: AnimationType.pulseHeavy, durationMs: 400);
    } else {
      final absDelta = delta.abs();
      if (absDelta <= 5) {
        return const AnimationConfig(type: AnimationType.shakeLight, durationMs: 250);
      }
      if (absDelta <= 10) {
        return const AnimationConfig(type: AnimationType.shakeMedium, durationMs: 350);
      }
      return const AnimationConfig(
        type: AnimationType.shakeHeavy,
        durationMs: 500,
        haptic: true,
      );
    }
  }

  static CriticalLevel getCriticalLevel({
    required int currentLife,
    required int startingLife,
  }) {
    if (startingLife <= 0) return CriticalLevel.safe;
    final ratio = currentLife / startingLife;
    if (ratio <= 0.10) return CriticalLevel.lethal;
    if (ratio <= 0.25) return CriticalLevel.danger;
    if (ratio <= 0.50) return CriticalLevel.warning;
    return CriticalLevel.safe;
  }

  static AnimationConfig getCounterAnimation({
    required String counterId,
    required int delta,
  }) {
    switch (counterId) {
      case 'poison':
        return const AnimationConfig(type: AnimationType.poisonTint, durationMs: 300);
      case 'commander_damage':
        return const AnimationConfig(type: AnimationType.commanderPulse, durationMs: 350);
      default:
        return const AnimationConfig(type: AnimationType.shakeLight, durationMs: 200);
    }
  }

  static const AnimationConfig eliminationAnimation = AnimationConfig(
    type: AnimationType.elimination,
    durationMs: 900,
    haptic: true,
  );
}
