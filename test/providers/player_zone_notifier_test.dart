// test/providers/player_zone_notifier_test.dart
import 'package:fake_async/fake_async.dart';
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

  group('nombres flottants — cycle de vie (bug : le nombre restait affiché '
      'indéfiniment)', () {
    test(
        'le nombre disparaît de lui-même après 600ms, sans aucun widget '
        'monté : c\'est le notifier qui possède son propre nettoyage, pas '
        'un widget observateur', () {
      fakeAsync((async) {
        final n = notifierFor(0);
        n.showFloatingNumber(-1);
        expect(stateFor(0).floatingNumbers, isNotEmpty);

        async.elapse(const Duration(milliseconds: 601));

        expect(stateFor(0).floatingNumbers, isEmpty,
            reason: 'aucun widget ne tourne dans ce test -- si le retrait '
                'dépendait d\'un Timer côté widget (comme avant la '
                'correction), il ne se produirait jamais ici, et le nombre '
                'resterait affiché indéfiniment, exactement le bug signalé');
      });
    });

    test(
        'deux nombres rapprochés disparaissent tous les deux, sans que le '
        'second ne prolonge la durée de vie du premier', () {
      fakeAsync((async) {
        final n = notifierFor(0);
        n.showFloatingNumber(1);
        async.elapse(const Duration(milliseconds: 200));
        n.showFloatingNumber(2);

        // 601ms depuis le premier (t=0) : son minuteur de retrait doit
        // s'être déclenché ; celui du second (armé à t=200, retrait à
        // t=800) ne s'est pas encore déclenché.
        async.elapse(const Duration(milliseconds: 401));
        expect(stateFor(0).floatingNumbers.map((f) => f.text).toList(), ['+2']);

        // 601ms depuis le second : son propre minuteur se déclenche à son
        // tour, indépendamment du premier.
        async.elapse(const Duration(milliseconds: 200));
        expect(stateFor(0).floatingNumbers, isEmpty);
      });
    });

    test('l\'animation reste appliquée à 50ms : opacity 0.0 et top -50.0', () {
      fakeAsync((async) {
        final n = notifierFor(0);
        n.showFloatingNumber(-1);

        async.elapse(const Duration(milliseconds: 51));

        final entry = stateFor(0).floatingNumbers.single;
        expect(entry.opacity, 0.0);
        expect(entry.top, -50.0);
      });
    });

    test(
        'ref.onDispose annule les minuteurs en vol : un Timer qui '
        'échoirait après la disposition du container ne doit pas tenter '
        'd\'écrire dans un notifier détruit', () {
      fakeAsync((async) {
        final localContainer = ProviderContainer();
        localContainer
            .read(playerZoneNotifierProvider(0).notifier)
            .showFloatingNumber(-1);
        localContainer.dispose();

        // Sans l'annulation dans `ref.onDispose`, le Timer de 600ms armé par
        // `showFloatingNumber` continuerait de courir malgré la disposition
        // du container, et tenterait d'écrire dans l'état d'un notifier
        // détruit à son échéance -- ce qui lève ici plutôt que de rester
        // silencieux.
        expect(() => async.elapse(const Duration(milliseconds: 601)),
            returnsNormally);
      });
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
