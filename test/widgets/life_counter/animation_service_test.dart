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
