// Fichier : lib/widgets/life_counter/critical_overlay.dart
// Task 13: CriticalOverlay widget — animated border based on CriticalLevel

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/widgets/life_counter/animations/animation_service.dart';

/// Widget that wraps a child and renders an animated pulsing border
/// based on the player's [CriticalLevel].
///
/// - safe   → transparent, no animation
/// - warning → slow pulsing amber border (1.5s cycle)
/// - danger  → faster pulsing red border (1.0s cycle)
/// - lethal  → rapid pulsing deep red border (0.6s cycle)
class CriticalOverlay extends StatefulWidget {
  final CriticalLevel level;
  final Widget child;

  const CriticalOverlay({
    super.key,
    required this.level,
    required this.child,
  });

  /// Returns the base border color for a given [CriticalLevel].
  static Color borderColorForLevel(CriticalLevel level) {
    switch (level) {
      case CriticalLevel.safe:
        return Colors.transparent;
      case CriticalLevel.warning:
        return AppColors.warning; // Colors.orange
      case CriticalLevel.danger:
        return AppColors.accentRed; // Colors.redAccent
      case CriticalLevel.lethal:
        return AppColors.error; // Colors.red (deep red)
    }
  }

  /// Returns the animation cycle duration for a given [CriticalLevel].
  static Duration durationForLevel(CriticalLevel level) {
    switch (level) {
      case CriticalLevel.safe:
        return const Duration(milliseconds: 1500);
      case CriticalLevel.warning:
        return const Duration(milliseconds: 1500);
      case CriticalLevel.danger:
        return const Duration(milliseconds: 1000);
      case CriticalLevel.lethal:
        return const Duration(milliseconds: 600);
    }
  }

  /// Returns the maximum border opacity for a given [CriticalLevel].
  static double maxOpacityForLevel(CriticalLevel level) {
    switch (level) {
      case CriticalLevel.safe:
        return 0.0;
      case CriticalLevel.warning:
        return 0.5;
      case CriticalLevel.danger:
        return 0.7;
      case CriticalLevel.lethal:
        return 0.9;
    }
  }

  @override
  State<CriticalOverlay> createState() => _CriticalOverlayState();
}

class _CriticalOverlayState extends State<CriticalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CriticalOverlay.durationForLevel(widget.level),
    );
    _opacityAnimation = _buildOpacityAnimation();
    _startIfNeeded();
  }

  Animation<double> _buildOpacityAnimation() {
    final maxOpacity = CriticalOverlay.maxOpacityForLevel(widget.level);
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: maxOpacity),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: maxOpacity, end: 0.1),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _startIfNeeded() {
    if (widget.level != CriticalLevel.safe) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void didUpdateWidget(covariant CriticalOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _controller.stop();
      _controller.duration = CriticalOverlay.durationForLevel(widget.level);
      _opacityAnimation = _buildOpacityAnimation();
      _startIfNeeded();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level == CriticalLevel.safe) {
      return widget.child;
    }

    final baseColor = CriticalOverlay.borderColorForLevel(widget.level);

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: baseColor.withValues(alpha: _opacityAnimation.value),
              width: widget.level == CriticalLevel.lethal ? 4.0 : 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(
                  alpha: _opacityAnimation.value * 0.5,
                ),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
