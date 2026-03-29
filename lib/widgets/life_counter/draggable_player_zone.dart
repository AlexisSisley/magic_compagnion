// Fichier : lib/widgets/life_counter/draggable_player_zone.dart
// Task 17: Drag & Drop wrapper for player zone reordering

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';

/// Wraps a player zone widget to enable long-press drag & drop reordering.
///
/// Long press (1s) activates drag with visual feedback:
/// - Scale 1.05 + shadow + 80% opacity while dragging
/// - Placeholder zone shown during drag
/// - Calls [onReorder] with old/new indices on drop
class DraggablePlayerZone extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onReorder(details.data, index),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return LongPressDraggable<int>(
          data: index,
          delay: const Duration(seconds: 1),
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: 0.8,
              child: Transform.scale(
                scale: 1.05,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 120,
                  child: child,
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkest.withAlpha(100),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.borderMedium,
                style: BorderStyle.solid,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.swap_horiz,
                color: AppColors.textMuted,
                size: 32,
              ),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isHovering
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
