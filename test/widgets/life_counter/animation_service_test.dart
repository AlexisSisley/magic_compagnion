import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/animations/animation_service.dart';

void main() {
  group('AnimationService.getLifeAnimation', () {
    test('small gain returns pulseLight', () {
      final config = AnimationService.getLifeAnimation(delta: 3, currentLife: 37, startingLife: 40);
      expect(config.type, AnimationType.pulseLight);
      expect(config.durationMs, 200);
    });

    test('massive gain returns pulseHeavy', () {
      final config = AnimationService.getLifeAnimation(delta: 8, currentLife: 48, startingLife: 40);
      expect(config.type, AnimationType.pulseHeavy);
      expect(config.durationMs, 400);
    });

    test('small loss returns shakeLight', () {
      final config = AnimationService.getLifeAnimation(delta: -3, currentLife: 37, startingLife: 40);
      expect(config.type, AnimationType.shakeLight);
      expect(config.durationMs, 250);
    });

    test('medium loss returns shakeMedium', () {
      final config = AnimationService.getLifeAnimation(delta: -8, currentLife: 32, startingLife: 40);
      expect(config.type, AnimationType.shakeMedium);
      expect(config.durationMs, 350);
    });

    test('massive loss returns shakeHeavy', () {
      final config = AnimationService.getLifeAnimation(delta: -15, currentLife: 25, startingLife: 40);
      expect(config.type, AnimationType.shakeHeavy);
      expect(config.durationMs, 500);
      expect(config.haptic, true);
    });
  });

  group('AnimationService.getCriticalLevel', () {
    test('returns safe above 50%', () {
      expect(AnimationService.getCriticalLevel(currentLife: 25, startingLife: 40), CriticalLevel.safe);
    });

    test('returns warning between 25-50%', () {
      expect(AnimationService.getCriticalLevel(currentLife: 15, startingLife: 40), CriticalLevel.warning);
    });

    test('returns danger between 10-25%', () {
      expect(AnimationService.getCriticalLevel(currentLife: 8, startingLife: 40), CriticalLevel.danger);
    });

    test('returns lethal at or below 10%', () {
      expect(AnimationService.getCriticalLevel(currentLife: 4, startingLife: 40), CriticalLevel.lethal);
    });

    test('standard format thresholds', () {
      expect(AnimationService.getCriticalLevel(currentLife: 12, startingLife: 20), CriticalLevel.safe);
      expect(AnimationService.getCriticalLevel(currentLife: 8, startingLife: 20), CriticalLevel.warning);
      expect(AnimationService.getCriticalLevel(currentLife: 4, startingLife: 20), CriticalLevel.danger);
      expect(AnimationService.getCriticalLevel(currentLife: 2, startingLife: 20), CriticalLevel.lethal);
    });

    // Spec V4 §3.3 : trois seuils absolus qui doivent percer la couche
    // d'alerte à tous les crans de densité, indépendamment du ratio de vie
    // restante utilisé ci-dessus.
    group('seuils absolus spec V4 §3.3', () {
      test('vie <= 5 déclenche l\'alerte même quand le ratio seul ne le ferait pas', () {
        // Format Custom à faible vie de départ (startingLife: 8) : le ratio
        // seul (5/8 = 0.625) classerait cette zone "safe". Le seuil absolu
        // de vie doit malgré tout déclencher l'alerte.
        expect(
          AnimationService.getCriticalLevel(currentLife: 5, startingLife: 8),
          isNot(CriticalLevel.safe),
        );
        // Au-dessus du seuil, aucune alerte forcée : le ratio reprend la main.
        expect(
          AnimationService.getCriticalLevel(currentLife: 6, startingLife: 8),
          CriticalLevel.safe,
        );
      });

      test('poison >= maxPoison - 2 déclenche l\'alerte même à pleine vie', () {
        expect(
          AnimationService.getCriticalLevel(
            currentLife: 40,
            startingLife: 40,
            poison: 8,
            maxPoison: 10,
          ),
          isNot(CriticalLevel.safe),
        );
        // Un poison de 7 (< maxPoison - 2) ne doit pas forcer l'alerte.
        expect(
          AnimationService.getCriticalLevel(
            currentLife: 40,
            startingLife: 40,
            poison: 7,
            maxPoison: 10,
          ),
          CriticalLevel.safe,
        );
      });

      test('18+ dégâts de commandant d\'une même source déclenche l\'alerte même à pleine vie', () {
        expect(
          AnimationService.getCriticalLevel(
            currentLife: 40,
            startingLife: 40,
            worstCommanderDamage: 18,
          ),
          isNot(CriticalLevel.safe),
        );
        // 17 ne franchit pas le seuil.
        expect(
          AnimationService.getCriticalLevel(
            currentLife: 40,
            startingLife: 40,
            worstCommanderDamage: 17,
          ),
          CriticalLevel.safe,
        );
      });

      test('les nouveaux paramètres par défaut préservent le comportement existant', () {
        // Aucun paramètre poison/commander passé : identique à l'appel
        // historique à deux arguments.
        expect(
          AnimationService.getCriticalLevel(currentLife: 25, startingLife: 40),
          CriticalLevel.safe,
        );
      });
    });
  });

  group('AnimationService.getCounterAnimation', () {
    test('poison returns poisonTint', () {
      final config = AnimationService.getCounterAnimation(counterId: 'poison', delta: 2);
      expect(config.type, AnimationType.poisonTint);
    });

    test('commander_damage returns commanderPulse', () {
      final config = AnimationService.getCounterAnimation(counterId: 'commander_damage', delta: 5);
      expect(config.type, AnimationType.commanderPulse);
    });

    test('generic counter returns shakeLight', () {
      final config = AnimationService.getCounterAnimation(counterId: 'energy', delta: 1);
      expect(config.type, AnimationType.shakeLight);
    });
  });
}
