// Fichier : lib/widgets/dashboard/dashboard_empty_state.dart
// Widget reutilisable pour les etats vides du dashboard avec CTA.

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class DashboardEmptyState extends StatefulWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DashboardEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<DashboardEmptyState> createState() => _DashboardEmptyStateState();
}

class _DashboardEmptyStateState extends State<DashboardEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.icon,
              size: 48,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.message,
            style: AppTextStyles.body(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: widget.onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryShade800,
                foregroundColor: AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text(
                widget.actionLabel!,
                style: AppTextStyles.label(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
