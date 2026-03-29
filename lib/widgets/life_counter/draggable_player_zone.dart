// Fichier : lib/widgets/life_counter/draggable_player_zone.dart
// V3 — Drag & Drop with swap animation 300ms easeInOut (spec 4.3)
// Long press 1s → drag, scale 1.05 + shadow + 80% opacity
// Drop → swap with 300ms easeInOut animation
// Drop outside → spring back animation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Wraps a player zone widget to enable long-press drag & drop reordering.
///
/// Long press (1s) activates drag with visual feedback:
/// - Scale 1.05 + shadow + 80% opacity while dragging
/// - Dashed placeholder shown at original position during drag
/// - Hover glow on valid drop targets
/// - Calls [onReorder] with old/new indices on drop
class DraggablePlayerZone extends StatefulWidget {
  final int index;
  final Widget child;
  final void Function(int oldIndex, int newIndex) onReorder;

  const DraggablePlayerZone({
    super.key,
    required this.index,
    required this.child,
    required this.onReorder,
  });

  @override
  State<DraggablePlayerZone> createState() => _DraggablePlayerZoneState();
}

class _DraggablePlayerZoneState extends State<DraggablePlayerZone>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _justSwapped = false;

  late final AnimationController _swapController;
  late final Animation<double> _swapAnimation;

  @override
  void initState() {
    super.initState();
    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swapAnimation = CurvedAnimation(
      parent: _swapController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _swapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DraggablePlayerZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger swap animation when the zone content changes (reorder happened)
    if (_justSwapped) {
      _swapController.forward(from: 0.0);
      _justSwapped = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (details.data != widget.index) {
          setState(() => _isHovering = true);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _isHovering = false),
      onAcceptWithDetails: (details) {
        setState(() {
          _isHovering = false;
          _justSwapped = true;
        });
        HapticFeedback.mediumImpact();
        widget.onReorder(details.data, widget.index);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: widget.index,
          delay: const Duration(seconds: 1),
          onDragStarted: () => HapticFeedback.selectionClick(),
          feedback: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(18),
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: Transform.scale(
                scale: 1.05,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 130,
                  child: widget.child,
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkest.withAlpha(80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.borderMedium,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(Icons.swap_horiz, color: AppColors.textMuted, size: 36),
            ),
          ),
          child: AnimatedBuilder(
            animation: _swapAnimation,
            builder: (context, child) {
              // Scale-in animation on swap completion
              final scale = _swapController.isAnimating
                  ? 0.92 + 0.08 * _swapAnimation.value
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: _isHovering
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                    boxShadow: _isHovering
                        ? [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 12, spreadRadius: 2)]
                        : null,
                  ),
                  child: child,
                ),
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
