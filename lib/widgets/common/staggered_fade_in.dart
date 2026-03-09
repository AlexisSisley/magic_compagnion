// Fichier : lib/widgets/common/staggered_fade_in.dart
// Sprint 14, US-14.9 : Staggered fade-in pour les listes de cartes.
// Chaque item apparait avec un leger delai, creant un effet cascade fluide.

import 'package:flutter/material.dart';

/// Widget qui anime son enfant avec un fade-in + slide-up decale.
/// Utiliser dans un ListView.builder pour un effet staggered.
class StaggeredFadeIn extends StatefulWidget {
  /// Index de l'item dans la liste (determine le delai).
  final int index;

  /// Duree de l'animation d'un seul item.
  final Duration duration;

  /// Delai entre chaque item.
  final Duration delay;

  /// Decalage vertical initial (en pixels).
  final double verticalOffset;

  /// Le widget enfant a animer.
  final Widget child;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = const Duration(milliseconds: 50),
    this.verticalOffset = 20,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _offset = Tween<Offset>(
      begin: Offset(0, widget.verticalOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Delai staggered : chaque item attend un peu plus que le precedent.
    // Cap a 15 items pour eviter des delais trop longs.
    final cappedIndex = widget.index.clamp(0, 15);
    final totalDelay = widget.delay * cappedIndex;

    Future.delayed(totalDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _offset.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
