// Fichier : lib/widgets/life_counter/radial_menu.dart
// V3 — Menu radial (spec 6.2) : Monarch / Éliminer / Reset compteurs
// S'ouvre sur long press zone joueur (hors header et boutons +/-)

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Data for a single radial menu item.
class RadialMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const RadialMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Shows a radial menu around [anchor] position inside an overlay.
///
/// Items are positioned in a semicircle above the anchor point.
/// Tap outside or on an item to dismiss.
Future<void> showRadialMenu({
  required BuildContext context,
  required Offset anchor,
  required List<RadialMenuItem> items,
}) {
  HapticFeedback.mediumImpact();
  return showDialog(
    context: context,
    barrierColor: AppColors.overlayDark,
    builder: (dialogCtx) => _RadialMenuOverlay(
      anchor: anchor,
      items: items,
      onDismiss: () => Navigator.of(dialogCtx).pop(),
    ),
  );
}

class _RadialMenuOverlay extends StatefulWidget {
  final Offset anchor;
  final List<RadialMenuItem> items;
  final VoidCallback onDismiss;

  const _RadialMenuOverlay({
    required this.anchor,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_RadialMenuOverlay> createState() => _RadialMenuOverlayState();
}

class _RadialMenuOverlayState extends State<_RadialMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  static const double _radius = 80.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          for (int i = 0; i < widget.items.length; i++)
            _buildItem(i, widget.items[i]),
        ],
      ),
    );
  }

  Widget _buildItem(int index, RadialMenuItem item) {
    // Distribute items in a semicircle above the anchor (180° to 0°)
    final count = widget.items.length;
    const startAngle = math.pi; // 180°
    const endAngle = 0.0; // 0°
    final angle = count == 1
        ? math.pi / 2 // Single item: straight up
        : startAngle + (endAngle - startAngle) * index / (count - 1);

    final dx = widget.anchor.dx + _radius * math.cos(angle);
    final dy = widget.anchor.dy + _radius * math.sin(angle);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final scale = _scaleAnimation.value;
        final currentDx = widget.anchor.dx + (dx - widget.anchor.dx) * scale;
        final currentDy = widget.anchor.dy + (dy - widget.anchor.dy) * scale;

        return Positioned(
          left: currentDx - 30,
          top: currentDy - 30,
          child: Opacity(
            opacity: scale.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          widget.onDismiss();
          // Defer the callback to run AFTER the dialog route is fully removed,
          // preventing setState conflicts during route animation (Bug: monarch toggle)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            item.onTap();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.color,
                boxShadow: [
                  BoxShadow(color: item.color.withAlpha(100), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: Icon(item.icon, color: AppColors.textPrimary, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
