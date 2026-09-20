// Fichier : lib/router/card_detail_route.dart
// La fiche carte, greffee dans les cinq branches du shell.
//
// Elle s'ouvre depuis un deck, une collection, un scan, une recherche ou
// l'historique. Declaree une seule fois a la racine, elle sortirait du shell
// et ferait disparaitre la barre d'onglets -- c'est le comportement d'avant la
// refonte. Declaree en sous-route RELATIVE dans chaque branche, elle herite
// de la branche appelante : la barre reste visible, et le retour ramene dans
// la branche d'ou on venait.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/cards/card_detail_page.dart';

/// Racines des branches du shell, la branche Accueil mise a part : sa racine
/// est '/', et un prefixe vide evite de produire '//card'.
const _branchRoots = <String>['/scanner', '/search', '/decks', '/collection'];

/// Racine de la branche qui contient [location].
///
/// La comparaison teste l'egalite OU le prefixe suivi d'un '/' : sans le
/// separateur, '/searchable' serait vu comme appartenant a '/search'.
String branchRootOf(String location) {
  for (final root in _branchRoots) {
    if (location == root || location.startsWith('$root/')) return root;
  }
  return '';
}

/// La GoRoute de la fiche carte, a greffer dans chaque branche.
GoRoute cardDetailRoute() {
  return GoRoute(
    path: 'card',
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return RecognitionResultPage(
        cardName: extra?['cardName'] as String?,
        imagePath: extra?['imagePath'] as String?,
        isContinuousScan: extra?['isContinuousScan'] as bool? ?? false,
      );
    },
  );
}

/// Pousse la fiche carte dans la branche courante.
///
/// A utiliser partout a la place de l'ancien `context.push` vers l'adresse
/// absolue de la fiche carte, qui sortait du shell.
///
/// Rend la valeur remontee par la fiche au `pop` : le scanner s'en sert pour
/// savoir s'il doit relancer un scan en mode serie.
Future<T?> pushCardDetail<T>(
  BuildContext context, {
  String? cardName,
  String? imagePath,
  bool isContinuousScan = false,
}) {
  final root = branchRootOf(GoRouterState.of(context).matchedLocation);
  return context.push<T>('$root/card', extra: <String, dynamic>{
    'cardName': cardName,
    'imagePath': imagePath,
    'isContinuousScan': isContinuousScan,
  });
}
