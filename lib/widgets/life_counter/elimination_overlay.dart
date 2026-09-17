// Fichier : lib/widgets/life_counter/elimination_overlay.dart
// Task 13: EliminationOverlay — 3-phase animation sequence for player elimination

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/widgets/life_counter/animations/crack_effect.dart';

/// Overlay widget that plays a 3-phase elimination animation when [isEliminated]
/// transitions from false → true.
///
/// Phase 1 (0–300ms)  : White flash overlay fading in then out.
/// Phase 2 (300–700ms): Crack lines radiating from center using [CrackEffect].
/// Phase 3 (700–900ms): Dark overlay with skull/elimination icon fading in.
///
/// After the animation completes, a static dark overlay with the icon remains.
class EliminationOverlay extends StatefulWidget {
  final bool isEliminated;
  final VoidCallback? onAnimationComplete;
  final Widget child;

  const EliminationOverlay({
    super.key,
    required this.isEliminated,
    this.onAnimationComplete,
    required this.child,
  });

  /// The icon used to indicate elimination (accessible from tests).
  static const IconData eliminationIcon = Icons.person_off;

  @override
  State<EliminationOverlay> createState() => _EliminationOverlayState();
}

class _EliminationOverlayState extends State<EliminationOverlay>
    with TickerProviderStateMixin {
  // Total animation duration: 900ms
  static const _totalDurationMs = 900;

  // Phase boundaries (in milliseconds)
  static const _flashEnd = 300;
  static const _cracksEnd = 700;
  static const _overlayEnd = 900;

  late AnimationController _controller;

  // Phase 1: flash opacity (0→1→0 over first 300ms)
  late Animation<double> _flashOpacity;

  // Phase 2: crack progress (0→1 from 300→700ms)
  late Animation<double> _crackProgress;

  // Phase 3: dark overlay + icon opacity (0→1 from 700→900ms)
  late Animation<double> _finalOverlayOpacity;

  bool _animationComplete = false;
  bool _wasEliminated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    );
    _buildAnimations();
    _wasEliminated = widget.isEliminated;

    if (widget.isEliminated) {
      _runAnimation();
    }
  }

  void _buildAnimations() {
    // Phase 1: flash (0ms – 300ms → normalized 0.0 – 0.333)
    final flashInterval = Interval(
      0.0,
      _flashEnd / _totalDurationMs,
      curve: Curves.easeOut,
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: flashInterval));

    // Phase 2: cracks (300ms – 700ms → normalized 0.333 – 0.778)
    final cracksInterval = Interval(
      _flashEnd / _totalDurationMs,
      _cracksEnd / _totalDurationMs,
      curve: Curves.easeOut,
    );
    _crackProgress = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: cracksInterval));

    // Phase 3: dark overlay + icon (700ms – 900ms → normalized 0.778 – 1.0)
    final finalInterval = Interval(
      _cracksEnd / _totalDurationMs,
      _overlayEnd / _totalDurationMs,
      curve: Curves.easeIn,
    );
    _finalOverlayOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: finalInterval));
  }

  void _runAnimation() {
    _animationComplete = false;
    _controller.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _animationComplete = true);
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(covariant EliminationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isEliminated && !_wasEliminated) {
      // Transition: not eliminated → eliminated
      _runAnimation();
    } else if (!widget.isEliminated && _wasEliminated) {
      // Reset when no longer eliminated (e.g. new game)
      _controller.stop();
      _controller.reset();
      setState(() => _animationComplete = false);
    }
    _wasEliminated = widget.isEliminated;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Revue finale (Critical #2) : la PROFONDEUR de l'arbre rendu ici est
  /// INVARIANTE — le `Stack` est toujours monté, et `widget.child` occupe
  /// toujours sa première position. Seules les trois phases décoratives
  /// varient, et elles sont déjà inconditionnelles (chacune décide à
  /// l'intérieur de son `AnimatedBuilder` de ne rien peindre).
  ///
  /// La version précédente renvoyait `widget.child` nu tant que le joueur
  /// n'était pas éliminé. Même cause racine que dans `critical_overlay.dart`
  /// et que celle documentée dans `life_counter_page.dart` : envelopper
  /// conditionnellement insère un niveau, Flutter détruit puis recrée le
  /// sous-arbre, et le `State` de `LifeDial` repart de zéro avec le doigt
  /// encore posé — le geste en cours meurt.
  ///
  /// Toute évolution de ce `build` doit conserver cette propriété.
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base child content always present
        widget.child,

        // Les trois phases ci-dessous sont purement décoratives : sans
        // `IgnorePointer`, leur `Container` plein (en particulier la phase 3,
        // qui reste affichée en permanence une fois l'animation terminée)
        // absorbait tous les gestes sur la zone, y compris la poignée du
        // tiroir — rendant "Annuler l'élimination" injoignable dès qu'un
        // joueur était éliminé (trouvé en ronde 1 de revue de la tâche 6, en
        // durcissant les tests du tiroir avec de vrais `tester.tap`).

        // Phase 1: white flash
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _flashOpacity,
            builder: (context, _) {
              if (_flashOpacity.value <= 0.0) return const SizedBox.shrink();
              return Opacity(
                opacity: _flashOpacity.value,
                child: Container(color: Colors.white),
              );
            },
          ),
        ),

        // Phase 2: crack lines
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _crackProgress,
            builder: (context, _) {
              if (_crackProgress.value <= 0.0) return const SizedBox.shrink();
              return CustomPaint(
                painter: CrackEffect(progress: _crackProgress.value),
              );
            },
          ),
        ),

        // Phase 3 + static: dark overlay with elimination icon
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _finalOverlayOpacity,
            builder: (context, _) {
              final opacity = _animationComplete ? 1.0 : _finalOverlayOpacity.value;
              if (opacity <= 0.0) return const SizedBox.shrink();
              return Opacity(
                opacity: opacity,
                child: Container(
                  color: AppColors.overlayVeryDark,
                  alignment: Alignment.center,
                  child: const Icon(
                    EliminationOverlay.eliminationIcon,
                    color: AppColors.textPrimary,
                    size: 48,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
