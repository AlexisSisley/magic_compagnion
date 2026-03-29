// Fichier : lib/widgets/life_counter/setup/quick_start_page.dart
// Task 15: Quick Start page for Life Counter v2

import 'package:flutter/material.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class QuickStartPage extends StatefulWidget {
  final void Function(GameFormat format, int playerCount) onStart;
  final VoidCallback? onAdvancedSettings;

  const QuickStartPage({
    super.key,
    required this.onStart,
    this.onAdvancedSettings,
  });

  @override
  State<QuickStartPage> createState() => _QuickStartPageState();
}

class _QuickStartPageState extends State<QuickStartPage> {
  GameFormat _selectedFormat = GameFormat.builtInFormats.first;
  int _playerCount = GameFormat.builtInFormats.first.minPlayers;

  void _selectFormat(GameFormat format) {
    setState(() {
      _selectedFormat = format;
      // Clamp player count within new format's range
      _playerCount = _playerCount.clamp(format.minPlayers, format.maxPlayers);
    });
  }

  void _selectPlayerCount(int count) {
    setState(() {
      _playerCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Quick Start',
              style: AppTextStyles.pageTitle(),
            ),
          ),
          const SizedBox(height: 8),
          _buildFormatSection(),
          const SizedBox(height: 16),
          _buildPlayerCountSection(),
          const Spacer(),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildFormatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Format',
            style: AppTextStyles.sectionTitle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: GameFormat.builtInFormats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final format = GameFormat.builtInFormats[index];
              final isSelected = format.id == _selectedFormat.id;
              return _FormatChip(
                format: format,
                isSelected: isSelected,
                onTap: () => _selectFormat(format),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCountSection() {
    final validCounts = List.generate(
      _selectedFormat.maxPlayers - _selectedFormat.minPlayers + 1,
      (i) => _selectedFormat.minPlayers + i,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Players',
            style: AppTextStyles.sectionTitle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: validCounts.map((count) {
              final isSelected = count == _playerCount;
              return GestureDetector(
                onTap: () => _selectPlayerCount(count),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderMedium,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () => widget.onStart(_selectedFormat, _playerCount),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start Game',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          if (widget.onAdvancedSettings != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onAdvancedSettings,
              child: Text(
                'Advanced Settings',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final GameFormat format;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderMedium,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              format.name,
              style: TextStyle(
                color: isSelected ? AppColors.textOnPrimary : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Text(
              '${format.startingLife}',
              style: TextStyle(
                color: isSelected ? AppColors.textOnPrimary.withAlpha(200) : AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
