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

  /// Niveau d'alerte affiché par `CriticalOverlay`, quel que soit le cran de
  /// densité de la zone (spec V4 §3.3 — c'est la seule chose autorisée à
  /// percer en cran minimal, où plus aucun compteur ne s'affiche).
  ///
  /// Le ratio de vie restante reste la base du calcul (comportement
  /// inchangé pour tout appelant qui ne passe pas les nouveaux paramètres :
  /// `poison` et `worstCommanderDamage` valent 0, `maxPoison` est absent, donc
  /// aucune des trois conditions ajoutées ne peut se déclencher). Trois
  /// seuils absolus s'y ajoutent, chacun ne pouvant qu'AGGRAVER le niveau
  /// déjà calculé par le ratio, jamais le faire régresser :
  /// - `currentLife <= 5` (ex. un format Custom à faible vie de départ, où
  ///   le ratio seul ne classerait pas encore la zone en alerte) ;
  /// - `poison >= maxPoison - 2` (à deux marqueurs de l'élimination) ;
  /// - `worstCommanderDamage >= 18` (à trois dégâts de la mort par une seule
  ///   source, le seuil officiel du jeu étant 21).
  static CriticalLevel getCriticalLevel({
    required int currentLife,
    required int startingLife,
    int poison = 0,
    int? maxPoison,
    int worstCommanderDamage = 0,
  }) {
    CriticalLevel level = CriticalLevel.safe;
    if (startingLife > 0) {
      final ratio = currentLife / startingLife;
      if (ratio <= 0.10) {
        level = CriticalLevel.lethal;
      } else if (ratio <= 0.25) {
        level = CriticalLevel.danger;
      } else if (ratio <= 0.50) {
        level = CriticalLevel.warning;
      }
    }

    if (currentLife <= 5 && level.index < CriticalLevel.danger.index) {
      level = CriticalLevel.danger;
    }
    if (maxPoison != null &&
        maxPoison > 0 &&
        poison >= maxPoison - 2 &&
        level.index < CriticalLevel.danger.index) {
      level = CriticalLevel.danger;
    }
    if (worstCommanderDamage >= 18 && level.index < CriticalLevel.lethal.index) {
      level = CriticalLevel.lethal;
    }

    return level;
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
