// Fichier : lib/widgets/life_counter/setup/advanced_settings_page.dart
// Task 15: Advanced Settings page for Life Counter v2

import 'package:flutter/material.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/player_config.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class AdvancedSettingsPage extends StatefulWidget {
  final GameFormat initialFormat;
  final List<PlayerConfig> initialPlayers;
  final void Function(
    GameFormat format,
    List<PlayerConfig> players,
    int startingLife,
  ) onStart;

  const AdvancedSettingsPage({
    super.key,
    required this.initialFormat,
    required this.initialPlayers,
    required this.onStart,
  });

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  late GameFormat _selectedFormat;
  late List<PlayerConfig> _players;
  late int _startingLife;
  late Set<String> _enabledCounterIds;
  String _gameTag = '';

  // Track which tiles are expanded
  bool _formatExpanded = true;
  bool _playersExpanded = false;
  bool _countersExpanded = false;
  bool _optionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat;
    _players = List.from(widget.initialPlayers);
    _startingLife = widget.initialFormat.startingLife;
    _enabledCounterIds = Set.from(widget.initialFormat.enabledCounterIds);
  }

  void _selectFormat(GameFormat format) {
    setState(() {
      _selectedFormat = format;
      _startingLife = format.startingLife;
      _enabledCounterIds = Set.from(format.enabledCounterIds);
    });
  }

  void _toggleCounter(String counterId) {
    setState(() {
      if (_enabledCounterIds.contains(counterId)) {
        _enabledCounterIds.remove(counterId);
      } else {
        _enabledCounterIds.add(counterId);
      }
    });
  }

  void _addPlayer() {
    setState(() {
      final index = _players.length;
      _players.add(PlayerConfig(
        id: 'player_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Player ${index + 1}',
        type: PlayerType.guest,
        colorValue: _defaultColors[index % _defaultColors.length],
      ));
    });
  }

  void _removePlayer(int index) {
    setState(() {
      _players.removeAt(index);
    });
  }

  static const List<int> _defaultColors = [
    0xFFB71C1C, // dark red
    0xFF1565C0, // dark blue
    0xFF1B5E20, // dark green
    0xFF4A148C, // dark purple
    0xFFE65100, // dark orange
    0xFF006064, // dark teal
    0xFF4E342E, // dark brown
    0xFF880E4F, // dark pink
  ];

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
              'Advanced Settings',
              style: AppTextStyles.pageTitle(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  _buildFormatSection(),
                  _buildPlayersSection(),
                  _buildCountersSection(),
                  _buildOptionsSection(),
                ],
              ),
            ),
          ),
          _buildStartButton(),
        ],
      ),
    );
  }

  Widget _buildFormatSection() {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: AppColors.borderLight,
      ),
      child: ExpansionTile(
        initiallyExpanded: _formatExpanded,
        onExpansionChanged: (v) => setState(() => _formatExpanded = v),
        title: Text('Format', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textMuted,
        backgroundColor: AppColors.cardBackground,
        collapsedBackgroundColor: AppColors.cardBackground,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
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
                if (_selectedFormat.id == 'custom') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Custom format: edit starting life in Options',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.borderLight),
      child: ExpansionTile(
        initiallyExpanded: _playersExpanded,
        onExpansionChanged: (v) => setState(() => _playersExpanded = v),
        title: Text('Players', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textMuted,
        backgroundColor: AppColors.cardBackground,
        collapsedBackgroundColor: AppColors.cardBackground,
        children: [
          ..._players.asMap().entries.map((entry) {
            final i = entry.key;
            final player = entry.value;
            return _PlayerSlotTile(
              player: player,
              onNameChanged: (name) {
                setState(() {
                  _players[i] = player.copyWith(name: name);
                });
              },
              onTypeChanged: (type) {
                setState(() {
                  _players[i] = player.copyWith(type: type);
                });
              },
              onColorChanged: (color) {
                setState(() {
                  _players[i] = player.copyWith(colorValue: color);
                });
              },
              onRemove: _players.length > 2 ? () => _removePlayer(i) : null,
            );
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_players.length < _selectedFormat.maxPlayers)
                  TextButton.icon(
                    onPressed: _addPlayer,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Add Player'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountersSection() {
    final allCounters = CounterType.builtInCounters;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.borderLight),
      child: ExpansionTile(
        initiallyExpanded: _countersExpanded,
        onExpansionChanged: (v) => setState(() => _countersExpanded = v),
        title: Text('Counters', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textMuted,
        backgroundColor: AppColors.cardBackground,
        collapsedBackgroundColor: AppColors.cardBackground,
        children: [
          ...allCounters.map((counter) {
            final enabled = _enabledCounterIds.contains(counter.id);
            return ListTile(
              leading: Text(counter.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(counter.name, style: TextStyle(color: AppColors.textPrimary)),
              trailing: Switch(
                value: enabled,
                onChanged: (_) => _toggleCounter(counter.id),
                activeColor: AppColors.primary,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: AppColors.borderLight),
      child: ExpansionTile(
        initiallyExpanded: _optionsExpanded,
        onExpansionChanged: (v) => setState(() => _optionsExpanded = v),
        title: Text('Options', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textMuted,
        backgroundColor: AppColors.cardBackground,
        collapsedBackgroundColor: AppColors.cardBackground,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starting Life Override', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: _startingLife > 1
                          ? () => setState(() => _startingLife--)
                          : null,
                      icon: const Icon(Icons.remove),
                      color: AppColors.textPrimary,
                    ),
                    Container(
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$_startingLife',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _startingLife++),
                      icon: const Icon(Icons.add),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Game Label / Tag', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Game Night #1',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderMedium),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.borderMedium),
                    ),
                  ),
                  onChanged: (v) => _gameTag = v,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: ElevatedButton(
        onPressed: () => widget.onStart(
          _selectedFormat,
          _players,
          _startingLife,
        ),
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }
}

/// Compact format chip used in the format selection row
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
          color: isSelected ? AppColors.primary : AppColors.surfaceDark,
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

/// Single player slot in the Players expansion tile
class _PlayerSlotTile extends StatelessWidget {
  final PlayerConfig player;
  final void Function(String name) onNameChanged;
  final void Function(PlayerType type) onTypeChanged;
  final void Function(int color) onColorChanged;
  final VoidCallback? onRemove;

  const _PlayerSlotTile({
    required this.player,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onColorChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Color dot
            GestureDetector(
              onTap: () => _showColorPicker(context),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(player.colorValue),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderMedium),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Name field
            Expanded(
              child: TextField(
                controller: TextEditingController(text: player.name),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Player name',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: onNameChanged,
              ),
            ),
            // Owner/Guest toggle
            _TypeToggle(
              type: player.type,
              onChanged: onTypeChanged,
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: AppColors.textMuted,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final colors = [
      0xFFB71C1C, 0xFF1565C0, 0xFF1B5E20, 0xFF4A148C,
      0xFFE65100, 0xFF006064, 0xFF4E342E, 0xFF880E4F,
      0xFF37474F, 0xFF827717,
    ];

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dialogBackground,
        title: Text('Pick Color', style: TextStyle(color: AppColors.textPrimary)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((c) {
            return GestureDetector(
              onTap: () {
                onColorChanged(c);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == player.colorValue ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final PlayerType type;
  final void Function(PlayerType) onChanged;

  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(type == PlayerType.owner ? PlayerType.guest : PlayerType.owner),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: type == PlayerType.owner ? AppColors.primary.withAlpha(40) : AppColors.surfaceDarkest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: type == PlayerType.owner ? AppColors.primary : AppColors.borderMedium,
          ),
        ),
        child: Text(
          type == PlayerType.owner ? 'Owner' : 'Guest',
          style: TextStyle(
            color: type == PlayerType.owner ? AppColors.primary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
