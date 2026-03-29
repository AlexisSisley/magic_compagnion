// Fichier : lib/widgets/life_counter/radial_menu.dart
// Task 14: RadialMenu widget — context menu for player zone actions.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// A single button item in the radial menu.
class RadialMenuButton extends StatelessWidget {
  const RadialMenuButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.label(color: AppColors.textPrimary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Radial context menu that appears at a given screen position with 4 action buttons.
///
/// Items are arranged at 90° intervals (top, right, bottom, left) at a radius of 60px.
/// Each item animates in with scale + fade, driven by a single AnimationController
/// with staggered intervals.
class RadialMenu extends StatefulWidget {
  const RadialMenu({
    super.key,
    required this.position,
    required this.onMonarchToggle,
    required this.onCommanderDamage,
    required this.onEliminate,
    required this.onReset,
    required this.onClose,
  });

  final Offset position;
  final VoidCallback onMonarchToggle;
  final VoidCallback onCommanderDamage;
  final VoidCallback onEliminate;
  final VoidCallback onReset;
  final VoidCallback onClose;

  // Public icon constants for tests
  static const IconData monarchIcon = Icons.auto_awesome;
  static const IconData commanderIcon = Icons.gavel;
  static const IconData eliminateIcon = Icons.person_off;
  static const IconData resetIcon = Icons.refresh;

  static const double _radius = 60.0;
  static const int _itemCount = 4;

  // Total duration = itemCount * stagger (50ms) + item duration (200ms)
  static const Duration _totalDuration = Duration(milliseconds: 400);

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Staggered animations per item using intervals of the master controller
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: RadialMenu._totalDuration,
    );

    _scaleAnimations = List.generate(RadialMenu._itemCount, (i) {
      // Each item starts at i * 0.125 (50ms out of 400ms total) and ends 200ms later
      final start = i * 0.125;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutBack),
        ),
      );
    });

    _fadeAnimations = List.generate(RadialMenu._itemCount, (i) {
      final start = i * 0.125;
      final end = (start + 0.25).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeIn),
        ),
      );
    });

    _controller.forward();
  }

  Future<void> _playCloseAnimation() async {
    await _controller.reverse().orCancel.catchError((_) {});
  }

  Future<void> _handleTap(VoidCallback action) async {
    action();
    await _playCloseAnimation();
    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

    return Positioned(
      left: widget.position.dx - 90,
      top: widget.position.dy - 90,
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Semi-transparent background circle
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.overlayVeryDark,
                shape: BoxShape.circle,
              ),
            ),
            // Menu items positioned at 90° intervals
            for (int i = 0; i < items.length; i++)
              _buildAnimatedItem(i, items[i]),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, _RadialItem item) {
    // index 0=top(270°), 1=right(0°), 2=bottom(90°), 3=left(180°)
    final double angle = (index * 90.0 - 90.0) * math.pi / 180.0;
    final double dx = RadialMenu._radius * math.cos(angle);
    final double dy = RadialMenu._radius * math.sin(angle);

    // Center of the 180x180 SizedBox is (90, 90).
    // Item size: ~60px wide (icon 44 + padding), ~64px tall (icon 44 + text ~20).
    const double itemW = 60.0;
    const double itemH = 64.0;
    final double left = 90.0 + dx - itemW / 2;
    final double top = 90.0 + dy - itemH / 2;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimations[index],
            child: ScaleTransition(
              scale: _scaleAnimations[index],
              child: child,
            ),
          );
        },
        child: RadialMenuButton(
          key: item.key,
          icon: item.icon,
          label: item.label,
          color: item.color,
          onTap: () => _handleTap(item.onTap),
        ),
      ),
    );
  }

  List<_RadialItem> _buildItems() {
    return [
      _RadialItem(
        key: const Key('radial_menu_monarch'),
        icon: RadialMenu.monarchIcon,
        label: 'Monarch',
        color: AppColors.primaryGold,
        onTap: widget.onMonarchToggle,
      ),
      _RadialItem(
        key: const Key('radial_menu_commander'),
        icon: RadialMenu.commanderIcon,
        label: 'Cmdr',
        color: AppColors.accent,
        onTap: widget.onCommanderDamage,
      ),
      _RadialItem(
        key: const Key('radial_menu_eliminate'),
        icon: RadialMenu.eliminateIcon,
        label: 'Elim.',
        color: AppColors.accentRed,
        onTap: widget.onEliminate,
      ),
      _RadialItem(
        key: const Key('radial_menu_reset'),
        icon: RadialMenu.resetIcon,
        label: 'Reset',
        color: AppColors.textSecondary,
        onTap: widget.onReset,
      ),
    ];
  }
}

/// Internal data class for a radial menu item.
class _RadialItem {
  const _RadialItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

/// Wraps a child widget and shows a [RadialMenu] on long press (500ms).
///
/// The menu appears at the long press position and is dismissed when an action
/// is selected or the user taps outside.
class RadialMenuTrigger extends StatefulWidget {
  const RadialMenuTrigger({
    super.key,
    required this.child,
    required this.onMonarchToggle,
    required this.onCommanderDamage,
    required this.onEliminate,
    required this.onReset,
  });

  final Widget child;
  final VoidCallback onMonarchToggle;
  final VoidCallback onCommanderDamage;
  final VoidCallback onEliminate;
  final VoidCallback onReset;

  @override
  State<RadialMenuTrigger> createState() => _RadialMenuTriggerState();
}

class _RadialMenuTriggerState extends State<RadialMenuTrigger> {
  OverlayEntry? _overlayEntry;
  bool _menuVisible = false;

  void _showMenu(Offset globalPosition) {
    if (_menuVisible) return;
    _menuVisible = true;

    _overlayEntry = OverlayEntry(
      builder: (context) => _RadialMenuOverlay(
        position: globalPosition,
        onMonarchToggle: widget.onMonarchToggle,
        onCommanderDamage: widget.onCommanderDamage,
        onEliminate: widget.onEliminate,
        onReset: widget.onReset,
        onClose: _closeMenu,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) setState(() {});
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _menuVisible = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showMenu(details.globalPosition),
      child: widget.child,
    );
  }
}

/// Full-screen overlay that positions the RadialMenu and dismisses on outside tap.
class _RadialMenuOverlay extends StatelessWidget {
  const _RadialMenuOverlay({
    required this.position,
    required this.onMonarchToggle,
    required this.onCommanderDamage,
    required this.onEliminate,
    required this.onReset,
    required this.onClose,
  });

  final Offset position;
  final VoidCallback onMonarchToggle;
  final VoidCallback onCommanderDamage;
  final VoidCallback onEliminate;
  final VoidCallback onReset;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invisible full-screen tap target to close on outside tap
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        RadialMenu(
          position: position,
          onMonarchToggle: onMonarchToggle,
          onCommanderDamage: onCommanderDamage,
          onEliminate: onEliminate,
          onReset: onReset,
          onClose: onClose,
        ),
      ],
    );
  }
}
