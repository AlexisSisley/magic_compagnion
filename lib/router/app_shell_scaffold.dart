// Fichier : lib/router/app_shell_scaffold.dart
// Shell d'onglets. Ne fait plus que ca.
//
// Avant la refonte, ce fichier portait aussi un Drawer de onze entrees, la
// sauvegarde automatique Google Drive, la restauration au demarrage et une
// boite "A propos" -- 482 lignes. Le Drawer a disparu (ses entrees sont dans
// /play et /settings) et les effets Drive sont dans DriveLifecycleObserver.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/magic_palette.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  /// Pilote les cinq branches : `currentIndex` dit laquelle est active,
  /// `goBranch` bascule en conservant la pile de chacune.
  final StatefulNavigationShell navigationShell;

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
    BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scanner'),
    BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Rechercher'),
    BottomNavigationBarItem(icon: Icon(Icons.style_outlined), label: 'Decks'),
    BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined), label: 'Collection'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);

    return Stack(
      children: [
        const _BackgroundTexture(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: navigationShell,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            // initialLocation: true renvoie a la racine de la branche quand on
            // retape l'onglet deja actif -- le geste attendu pour "remonter en
            // haut". Sur un AUTRE onglet, il doit rester false, sinon chaque
            // changement d'onglet viderait la pile de la branche d'arrivee et
            // la preservation des piles ne servirait a rien.
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            type: BottomNavigationBarType.fixed,
            backgroundColor: p.raised,
            selectedItemColor: p.accent,
            unselectedItemColor: p.inkSecondary,
            items: _items,
          ),
        ),
      ],
    );
  }
}

class _BackgroundTexture extends StatelessWidget {
  const _BackgroundTexture();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background_texture_black.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
