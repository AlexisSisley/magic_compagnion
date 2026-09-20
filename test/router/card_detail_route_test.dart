// Fichier : test/router/card_detail_route_test.dart
// La fiche carte est atteignable depuis les cinq branches. Greffee en
// sous-route relative dans chacune, elle garde la barre d'onglets et revient
// dans la branche d'ou elle a ete ouverte.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/card_detail_route.dart';

void main() {
  group('branchRootOf', () {
    test('reconnait chaque branche a sa racine', () {
      expect(branchRootOf('/scanner'), '/scanner');
      expect(branchRootOf('/scanner/history'), '/scanner');
      expect(branchRootOf('/search'), '/search');
      expect(branchRootOf('/decks/detail'), '/decks');
      expect(branchRootOf('/collection/set/stats'), '/collection');
    });

    test('la branche Accueil a une racine vide', () {
      expect(branchRootOf('/'), '');
      expect(branchRootOf('/game-history'), '');
    });

    test('produit un chemin de fiche carte valide pour chaque branche', () {
      for (final location in [
        '/',
        '/scanner',
        '/search',
        '/decks',
        '/collection'
      ]) {
        final path = '${branchRootOf(location)}/card';
        expect(path.startsWith('/'), isTrue);
        expect(path.contains('//'), isFalse,
            reason: '$location produit un chemin malforme : $path');
      }
    });

    test('un prefixe qui ressemble a une racine ne la declenche pas', () {
      // '/searchable' n'est pas dans la branche '/search'. Sans la
      // verification du separateur, `startsWith` les confondrait et la fiche
      // carte s'ouvrirait dans la mauvaise branche.
      expect(branchRootOf('/searchable'), '');
      expect(branchRootOf('/decksomething'), '');
    });
  });

  group('cardDetailRoute', () {
    test('le chemin est relatif, pour se greffer dans chaque branche', () {
      expect(cardDetailRoute().path, 'card');
      expect(cardDetailRoute().path.startsWith('/'), isFalse,
          reason: 'un chemin absolu sortirait de la branche');
    });
  });

  group('plus aucun appelant ne pousse une route de fiche carte absolue', () {
    test('AppRoutes.cardDetail a disparu de lib/', () {
      // La constante est supprimee : chaque appelant manque devient une
      // erreur de compilation. Ce test tient la porte fermee ensuite.
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lignes = entity.readAsLinesSync();
        for (var i = 0; i < lignes.length; i++) {
          if (lignes[i].contains('AppRoutes.cardDetail')) {
            offenders.add('${entity.path.replaceAll(r'\', '/')}:${i + 1}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'Utiliser pushCardDetail(context, ...), qui reste dans la '
              'branche courante :\n${offenders.join('\n')}');
    });
  });
}
