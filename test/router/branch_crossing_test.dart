// Fichier : test/router/branch_crossing_test.dart
// Critere n4 du plan : aucun `context.push` ne franchit une frontiere de
// branche.
//
// La regle de navigation de la refonte tient en deux lignes :
//   - `go` pour CHANGER de branche ;
//   - `push` pour DESCENDRE dans la branche courante.
//
// Un `push` vers une adresse appartenant a une AUTRE branche empile la cible
// sur la pile COURANTE : la barre d'onglets reste sur l'onglet de depart
// pendant qu'un ecran d'un autre onglet s'affiche. Trois sites du tableau de
// bord le faisaient jusqu'a la revue finale -- ils poussaient /decks/detail
// et /scanner/history depuis la branche Accueil.
//
// Un push vers sa PROPRE branche est legitime et reste autorise : c'est
// exactement "descendre dans la branche courante".
//
// Les adresses hors shell (reglages, profils, grimoire, mode Jeu) ne sont pas
// listees : elles n'appartiennent a aucune branche et se poussent librement.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_routes.dart';

void main() {
  /// Adresse de chaque constante de route appartenant a une branche, et la
  /// branche qui la porte.
  const brancheDeLaRoute = <String, String>{
    'scanner': 'scanner',
    'scanHistory': 'scanner',
    'search': 'search',
    'decks': 'decks',
    'deckDetail': 'decks',
    'collection': 'collection',
    'globalStats': 'collection',
    'setDetail': 'collection',
    'setStats': 'collection',
    'wishlistDetail': 'collection',
    'home': 'home',
    'gameHistory': 'home',
    'gameHistoryDetail': 'home',
  };

  /// La branche a laquelle appartient chaque dossier de `lib/`.
  ///
  /// Prefixes les plus longs d'abord : `lib/pages/life_counter` doit gagner
  /// sur `lib/pages`.
  const brancheDuDossier = <String, String>{
    'lib/pages/collections/': 'collection',
    'lib/widgets/collection/': 'collection',
    'lib/widgets/collections/': 'collection',
    'lib/pages/wishlists/': 'collection',
    'lib/pages/decks/': 'decks',
    'lib/widgets/decks/': 'decks',
    'lib/pages/scans/': 'scanner',
    'lib/widgets/scans/': 'scanner',
    'lib/pages/cards/': 'search',
    'lib/widgets/search/': 'search',
    'lib/pages/home/': 'home',
    'lib/widgets/dashboard/': 'home',
    'lib/pages/life_counter/': 'home',
  };

  String? brancheDuFichier(String chemin) {
    String? trouvee;
    var longueur = 0;
    for (final entree in brancheDuDossier.entries) {
      if (chemin.contains(entree.key) && entree.key.length > longueur) {
        trouvee = entree.value;
        longueur = entree.key.length;
      }
    }
    return trouvee;
  }

  test('les adresses listees existent bien dans AppRoutes', () {
    // Filet du filet : si une constante disparait ou change de nom, le
    // balayage cesserait de la couvrir en silence.
    const valeurs = <String, String>{
      'scanner': AppRoutes.scanner,
      'scanHistory': AppRoutes.scanHistory,
      'search': AppRoutes.search,
      'decks': AppRoutes.decks,
      'deckDetail': AppRoutes.deckDetail,
      'collection': AppRoutes.collection,
      'globalStats': AppRoutes.globalStats,
      'setDetail': AppRoutes.setDetail,
      'setStats': AppRoutes.setStats,
      'wishlistDetail': AppRoutes.wishlistDetail,
      'home': AppRoutes.home,
      'gameHistory': AppRoutes.gameHistory,
      'gameHistoryDetail': AppRoutes.gameHistoryDetail,
    };
    expect(valeurs.keys.toSet(), brancheDeLaRoute.keys.toSet());
  });

  test('aucun push ne vise une branche autre que celle du fichier', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final chemin = entity.path.replaceAll(r'\', '/');
      final source = brancheDuFichier(chemin);
      final lignes = entity.readAsLinesSync();

      for (var i = 0; i < lignes.length; i++) {
        if (!lignes[i].contains('.push(')) continue;

        // L'adresse peut etre sur la ligne suivante quand l'appel est
        // multiligne -- c'etait le cas de deux des trois sites trouves.
        final fenetre =
            lignes.sublist(i, (i + 3).clamp(0, lignes.length)).join(' ');

        for (final entree in brancheDeLaRoute.entries) {
          if (!fenetre.contains('AppRoutes.${entree.key}')) continue;
          if (entree.value == source) continue;
          offenders.add('$chemin:${i + 1} : push vers AppRoutes.'
              '${entree.key} (branche ${entree.value}) depuis '
              '${source ?? 'un fichier hors branche'}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: "Un push vers une autre branche laisse la barre d'onglets "
            "sur l'onglet de depart. Utiliser `go` pour changer de branche, "
            'ou un helper relatif pour descendre dans la branche courante '
            '(voir pushCardDetail) :\n${offenders.join('\n')}');
  });
}
