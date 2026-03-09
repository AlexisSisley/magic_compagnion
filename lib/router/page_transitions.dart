// Fichier : lib/router/page_transitions.dart
// Sprint 14, US-14.8 : Animations de transitions entre pages.
// - FadeThrough pour la navigation BottomNav (changement d'onglet)
// - SharedAxis pour les push/pop de pages
// Compatible 60fps, optimise pour low-end (R2).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page avec transition fade-through pour les onglets BottomNav.
/// La page sortante fait un fade-out pendant que la nouvelle fait un fade-in
/// avec un leger scale-up, creant une transition fluide.
class FadeThroughPage extends CustomTransitionPage<void> {
  FadeThroughPage({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade-out de la page sortante
            final fadeOut = Tween<double>(begin: 1.0, end: 0.0)
                .animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInOut,
            ));

            // Fade-in + scale-up de la page entrante
            final fadeIn = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            final scaleIn = Tween<double>(begin: 0.92, end: 1.0)
                .animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            return FadeTransition(
              opacity: fadeOut,
              child: FadeTransition(
                opacity: fadeIn,
                child: ScaleTransition(
                  scale: scaleIn,
                  child: child,
                ),
              ),
            );
          },
        );
}
