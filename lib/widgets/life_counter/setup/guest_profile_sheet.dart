// Fichier : lib/widgets/life_counter/setup/guest_profile_sheet.dart
// Task 15: Bottom sheet for editing a guest player profile

import 'package:flutter/material.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// Result returned when a guest profile is configured.
class GuestProfileResult {
  final String name;
  final int colorValue;
  final List<String> commanderNames;

  const GuestProfileResult({
    required this.name,
    required this.colorValue,
    this.commanderNames = const [],
  });
}

/// Bottom sheet for configuring a guest player.
class GuestProfileSheet extends StatefulWidget {
  final String initialName;
  final int initialColor;
  final List<String> initialCommanders;
  final int maxCommanders;

  const GuestProfileSheet({
    super.key,
    this.initialName = '',
    this.initialColor = 0xFF2196F3,
    this.initialCommanders = const [],
    this.maxCommanders = 2,
  });

  @override
  State<GuestProfileSheet> createState() => _GuestProfileSheetState();
}

class _GuestProfileSheetState extends State<GuestProfileSheet> {
  late TextEditingController _nameController;
  late int _selectedColor;
  late List<TextEditingController> _commanderControllers;

  static const List<int> _colorOptions = [
    0xFFB71C1C, 0xFF1565C0, 0xFF1B5E20, 0xFF4A148C,
    0xFFE65100, 0xFF006064, 0xFF4E342E, 0xFF880E4F,
    0xFF37474F, 0xFF827717, 0xFF2196F3, 0xFF4CAF50,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedColor = widget.initialColor;
    _commanderControllers = widget.initialCommanders.isEmpty
        ? [TextEditingController()]
        : widget.initialCommanders
            .map((c) => TextEditingController(text: c))
            .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _commanderControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCommander() {
    if (_commanderControllers.length < widget.maxCommanders) {
      setState(() {
        _commanderControllers.add(TextEditingController());
      });
    }
  }

  void _removeCommander(int index) {
    if (_commanderControllers.length > 1) {
      setState(() {
        _commanderControllers[index].dispose();
        _commanderControllers.removeAt(index);
      });
    }
  }

  void _save() {
    final result = GuestProfileResult(
      name: _nameController.text.isEmpty ? 'Guest' : _nameController.text,
      colorValue: _selectedColor,
      commanderNames: _commanderControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderMedium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Guest Profile', style: AppTextStyles.sectionTitle()),
          const SizedBox(height: 16),

          // Name field
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Player Name',
              labelStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('Color', style: AppTextStyles.label(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colorOptions.map((c) {
              final isSelected = c == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Commander name(s)
          Text(
            'Commander(s)',
            style: AppTextStyles.label(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          ..._commanderControllers.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: entry.value,
                      style: TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Commander name',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_commanderControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.textMuted,
                      onPressed: () => _removeCommander(entry.key),
                    ),
                ],
              ),
            );
          }),
          if (_commanderControllers.length < widget.maxCommanders)
            TextButton.icon(
              onPressed: _addCommander,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Commander'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          const SizedBox(height: 16),

          // Save button
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
