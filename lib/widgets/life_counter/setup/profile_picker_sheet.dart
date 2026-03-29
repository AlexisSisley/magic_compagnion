// Fichier : lib/widgets/life_counter/setup/profile_picker_sheet.dart
// Task 15: Bottom sheet for picking from saved player profiles

import 'package:flutter/material.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Bottom sheet displaying saved player profiles for selection.
class ProfilePickerSheet extends StatelessWidget {
  final List<PlayerConfig> profiles;
  final VoidCallback? onCreateNew;

  const ProfilePickerSheet({
    super.key,
    required this.profiles,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackground,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderMedium,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Player Profiles', style: AppTextStyles.sectionTitle()),
                if (onCreateNew != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onCreateNew!();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: profiles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No saved profiles yet.',
                        style: AppTextStyles.body(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return ListTile(
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(profile.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          profile.name,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          profile.type == PlayerType.owner ? 'Owner' : 'Guest',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                        ),
                        onTap: () => Navigator.of(context).pop(profile),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
