// test/providers/player_zone_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayerZoneNotifier notifierFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId).notifier);

  PlayerZoneState stateFor(int playerId) =>
      container.read(playerZoneNotifierProvider(playerId));

  group('mode ajustement', () {
    test('démarre hors mode ajustement', () {
      expect(stateFor(0).isAdjusting, isFalse);
    });

    test('enterAdjustMode puis exitAdjustMode', () {
      notifierFor(0).enterAdjustMode();
      expect(stateFor(0).isAdjusting, isTrue);
      notifierFor(0).exitAdjustMode();
      expect(stateFor(0).isAdjusting, isFalse);
    });

    test('exitAdjustMode vide l\'accumulateur de molette', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      n.handleWheelDrag(5.0); // sous le seuil, reste dans l'accumulateur
      expect(stateFor(0).wheelAccumulator, isNot(0.0));
      n.exitAdjustMode();
      expect(stateFor(0).wheelAccumulator, 0.0);
    });
  });

  group('molette', () {
    test('sous le seuil ne produit aucun pas', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(5.0), 0);
    });

    test('un glissement vers le haut produit des pas positifs', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      // 8 px par unité, glissement vers le haut = dy négatif = +PV
      expect(n.handleWheelDrag(-24.0), 3);
    });

    test('un glissement vers le bas produit des pas négatifs', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(24.0), -3);
    });

    test('le reste est conservé entre deux appels', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      expect(n.handleWheelDrag(-12.0), 1); // 12 px = 1 pas, reste 4 px
      expect(n.handleWheelDrag(-4.0), 1);  // 4 + 4 = 8 px = 1 pas
    });

    test('accélère au-delà du seuil d\'accélération', () {
      final n = notifierFor(0);
      n.enterAdjustMode();
      final lent = n.handleWheelDrag(-80.0);
      n.exitAdjustMode();
      n.enterAdjustMode();
      final rapide = n.handleWheelDrag(-160.0);
      expect(rapide, greaterThan(lent * 2),
          reason: 'au-delà du seuil, la molette doit accélérer, pas rester linéaire');
    });

    test('ne produit rien hors mode ajustement', () {
      expect(notifierFor(0).handleWheelDrag(-100.0), 0);
    });

    test(
        'un grand geste fractionné en petits événements successifs '
        'déclenche l\'accélération (revue globale, Critical)', () {
      final n = notifierFor(0);
      n.enterAdjustMode();

      // Un vrai doigt appelle `handleWheelDrag` une fois par
      // `PointerMoveEvent`, ~10px à la fois à 60fps — jamais un seul gros
      // saut. 20 appels de 10px = 200px au total, largement au-delà du
      // seuil de 120px.
      var totalSteps = 0;
      for (var i = 0; i < 20; i++) {
        totalSteps += n.handleWheelDrag(10.0).abs();
      }

      // Sans l'accélération (le bug : elle se décidait sur le résidu local,
      // qui ne dépasse jamais quelques pixels par appel), 200px produiraient
      // exactement 200 / 8 = 25 points, linéaire du début à la fin. Avec
      // l'accélération décidée sur la distance totale du geste : linéaire
      // jusqu'à 120px (15 points), puis double au-delà (80px restants à 4px
      // par point = 20 points) = 35 points.
      expect(totalSteps, 35,
          reason: 'un glissement fractionné qui dépasse le seuil doit '
              'accélérer exactement comme un unique gros saut le ferait');
    });
  });

  group('nombres flottants', () {
    test('showFloatingNumber empile avec le bon texte et des ids croissants', () {
      final n = notifierFor(0);
      n.showFloatingNumber(3);
      n.showFloatingNumber(-5);
      final numbers = stateFor(0).floatingNumbers;
      expect(numbers.map((f) => f.text).toList(), ['+3', '-5']);
      expect(numbers.map((f) => f.id).toList(), [0, 1]);
    });

    test('removeFloatingNumber retire le bon', () {
      final n = notifierFor(0);
      n.showFloatingNumber(1);
      n.showFloatingNumber(2);
      n.removeFloatingNumber(0);
      expect(stateFor(0).floatingNumbers.single.text, '+2');
    });
  });

  group('rotation', () {
    test('rotate90Degrees boucle sur 4', () {
      expect(notifierFor(0).rotate90Degrees(3), 0);
    });

    test('le glissement sous le seuil ne tourne pas', () {
      expect(notifierFor(0).handleRotationDrag(10.0, 0), isNull);
    });

    test('le glissement au-delà du seuil tourne et remet l\'accumulateur à zéro', () {
      final n = notifierFor(0);
      expect(n.handleRotationDrag(50.0, 0), 1);
      expect(stateFor(0).rotationAccumulator, 0.0);
    });

    test('un glissement négatif tourne dans l\'autre sens sans passer en négatif', () {
      expect(notifierFor(0).handleRotationDrag(-50.0, 0), 3);
    });
  });

  test('les instances sont indépendantes par playerId', () {
    notifierFor(0).enterAdjustMode();
    expect(stateFor(0).isAdjusting, isTrue);
    expect(stateFor(1).isAdjusting, isFalse);
  });
}
