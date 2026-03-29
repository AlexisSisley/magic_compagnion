// Fichier : lib/widgets/life_counter/game_setup_modal.dart
// V3: Settings avancés (5.2), anti-doublon profils, tous formats, compteurs configurables

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/game_format.dart';
import 'package:magic_companion/models/profile_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/profile_service.dart';
import 'package:magic_companion/widgets/decks/deck_card_picker.dart';
import 'package:magic_companion/widgets/cards/scryfall_image.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:go_router/go_router.dart';

class GameSetupModal extends ConsumerStatefulWidget {
  final int initialLife;
  final Function(GameFormat format, List<Profile?> profiles) onGameStart;

  const GameSetupModal({
    super.key,
    required this.initialLife,
    required this.onGameStart,
  });

  @override
  ConsumerState<GameSetupModal> createState() => _GameSetupModalState();
}

class _GameSetupModalState extends ConsumerState<GameSetupModal> {
  ProfileService get _profileService => ref.read(profileServiceProvider);

  // Format & life
  late GameFormat _selectedFormat;
  late int _startingLife;

  // Players
  final List<Profile?> _selectedProfiles = List.filled(4, null, growable: true);
  List<Profile> _availableProfiles = [];

  // Advanced settings
  bool _showAdvanced = false;
  bool _timerEnabled = true;
  String _tag = ''; // Used in tag TextField, will be exposed in future callback

  // Loss threshold overrides
  late int _maxPoison;
  late int _maxCommanderDamage;
  late bool _lethalAtZeroLife;

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900, Colors.indigo.shade900, AppColors.greyShade800,
  ];

  @override
  void initState() {
    super.initState();
    _selectedFormat = GameFormat.builtInFormats.firstWhere(
      (f) => f.startingLife == widget.initialLife,
      orElse: () => GameFormat.builtInFormats.first,
    );
    _startingLife = _selectedFormat.startingLife;
    _maxPoison = _selectedFormat.maxPoison;
    _maxCommanderDamage = _selectedFormat.maxCommanderDamage;
    _lethalAtZeroLife = _selectedFormat.lethalAtZeroLife;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await _profileService.loadProfiles();
    if (mounted) setState(() => _availableProfiles = list);
  }

  /// Returns set of profile IDs already assigned to slots (excluding the given index).
  Set<String> _assignedProfileIds({int? excludeIndex}) {
    final ids = <String>{};
    for (int i = 0; i < _selectedProfiles.length; i++) {
      if (i == excludeIndex) continue;
      final p = _selectedProfiles[i];
      if (p != null) ids.add(p.id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.borderMedium, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Configuration de la partie',
              style: AppTextStyles.pageTitle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Format chips (all 6 formats)
            _buildFormatSelector(),
            const SizedBox(height: 12),

            // Player count quick selector
            _buildPlayerCountSelector(),
            const SizedBox(height: 12),

            // Player slots
            Expanded(
              child: ListView.separated(
                itemCount: _selectedProfiles.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index == _selectedProfiles.length) {
                    return _buildAddRemoveButtons();
                  }
                  return _buildPlayerSlot(index);
                },
              ),
            ),

            // Advanced settings toggle
            _buildAdvancedToggle(),
            if (_showAdvanced) _buildAdvancedSettings(),

            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final finalFormat = _selectedFormat.copyWith(
                  startingLife: _startingLife,
                  maxPoison: _maxPoison,
                  maxCommanderDamage: _maxCommanderDamage,
                  lethalAtZeroLife: _lethalAtZeroLife,
                );
                Navigator.pop(context);
                widget.onGameStart(finalFormat, _selectedProfiles);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryShade800,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('LANCER LA PARTIE',
                style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FORMAT SELECTOR (all 6 formats as scrollable chips) ---
  Widget _buildFormatSelector() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GameFormat.builtInFormats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final format = GameFormat.builtInFormats[index];
          final isSelected = _selectedFormat.id == format.id;
          return ChoiceChip(
            label: Text('${format.name} (${format.startingLife})'),
            selected: isSelected,
            onSelected: (_) => setState(() {
              _selectedFormat = format;
              _startingLife = format.startingLife;
              _maxPoison = format.maxPoison;
              _maxCommanderDamage = format.maxCommanderDamage;
              _lethalAtZeroLife = format.lethalAtZeroLife;
              // Adjust player count to format bounds
              while (_selectedProfiles.length < format.minPlayers) {
                _selectedProfiles.add(null);
              }
              while (_selectedProfiles.length > format.maxPlayers) {
                _selectedProfiles.removeLast();
              }
            }),
            selectedColor: AppColors.primaryShade800,
            backgroundColor: AppColors.surfaceDark,
            labelStyle: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  // --- PLAYER COUNT QUICK SELECTOR ---
  Widget _buildPlayerCountSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Joueurs : ', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 13)),
        for (int n = _selectedFormat.minPlayers; n <= _selectedFormat.maxPlayers && n <= 8; n++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => setState(() {
                while (_selectedProfiles.length < n) { _selectedProfiles.add(null); }
                while (_selectedProfiles.length > n) { _selectedProfiles.removeLast(); }
              }),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedProfiles.length == n ? AppColors.primaryShade800 : AppColors.surfaceDark,
                  border: Border.all(
                    color: _selectedProfiles.length == n ? AppColors.primary : AppColors.borderMedium,
                  ),
                ),
                child: Text('$n', style: TextStyle(
                  color: _selectedProfiles.length == n ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: FontWeight.bold, fontSize: 13,
                )),
              ),
            ),
          ),
      ],
    );
  }

  // --- ADD/REMOVE BUTTONS ---
  Widget _buildAddRemoveButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedProfiles.length < _selectedFormat.maxPlayers)
          TextButton.icon(
            onPressed: () => setState(() => _selectedProfiles.add(null)),
            icon: const Icon(Icons.add_circle, color: AppColors.success, size: 18),
            label: const Text('Ajouter', style: TextStyle(color: AppColors.success, fontSize: 13)),
          ),
        if (_selectedProfiles.length > _selectedFormat.minPlayers)
          TextButton.icon(
            onPressed: () => setState(() => _selectedProfiles.removeLast()),
            icon: const Icon(Icons.remove_circle, color: AppColors.error, size: 18),
            label: const Text('Retirer', style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
      ],
    );
  }

  // --- PLAYER SLOT ---
  Widget _buildPlayerSlot(int index) {
    final profile = _selectedProfiles[index];
    return Card(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        onLongPress: profile != null ? () async {
          await _showProfileForm(existingProfile: profile);
          _loadProfiles();
        } : null,
        leading: _buildProfileAvatar(profile, index),
        title: Text(
          profile?.name ?? 'Invité ${index + 1}',
          style: AppTextStyles.cinzel(fontSize: 14),
        ),
        subtitle: profile?.commanderName != null
            ? Text('Cmd: ${profile!.commanderName}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile != null)
              InkWell(
                onTap: () => setState(() => _selectedProfiles[index] = null),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                ),
              ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ],
        ),
        onTap: () async {
          final selected = await _showProfileSelector(index);
          if (selected != null) {
            setState(() => _selectedProfiles[index] = selected);
          } else {
            // User picked "Invité" — null means guest
          }
        },
      ),
    );
  }

  Widget _buildProfileAvatar(Profile? profile, int index) {
    if (profile == null) {
      return CircleAvatar(
        backgroundColor: _defaultColors[index % _defaultColors.length],
        radius: 18,
        child: Text('${index + 1}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
      );
    }

    if (profile.secondaryCommanderScryfallId == null) {
      return ScryfallAvatarImage(
        imageUrl: profile.commanderImageUrl,
        radius: 18,
        backgroundColor: Color(profile.colorValue),
      );
    }

    return Container(
      width: 36, height: 36,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Color(profile.colorValue), width: 2),
      ),
      child: Row(
        children: [
          Expanded(child: ScryfallImage(imageUrl: profile.commanderImageUrl)),
          Expanded(child: ScryfallImage(imageUrl: profile.secondaryCommanderImageUrl)),
        ],
      ),
    );
  }

  // --- ADVANCED SETTINGS TOGGLE ---
  Widget _buildAdvancedToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showAdvanced ? Icons.expand_less : Icons.expand_more,
              color: AppColors.textMuted, size: 20,
            ),
            const SizedBox(width: 4),
            Text('Paramètres avancés',
              style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // --- ADVANCED SETTINGS (5.2) ---
  Widget _buildAdvancedSettings() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom starting life
          Row(
            children: [
              Text('PV de départ : ', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.textMuted, size: 18),
                onPressed: _startingLife > 1
                    ? () => setState(() => _startingLife--)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_startingLife',
                  style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.textMuted, size: 18),
                onPressed: () => setState(() => _startingLife++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Timer toggle
          Row(
            children: [
              Text('Timer de partie', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _timerEnabled,
                onChanged: (v) => setState(() => _timerEnabled = v),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),

          const Divider(color: AppColors.borderMedium, height: 16),

          // --- Loss thresholds ---
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Conditions de défaite',
              style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),

          // Lethal at zero life toggle
          Row(
            children: [
              const Icon(Icons.favorite_border, color: AppColors.accentRed, size: 16),
              const SizedBox(width: 6),
              Text('PV à 0 = éliminé', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _lethalAtZeroLife,
                onChanged: (v) => setState(() => _lethalAtZeroLife = v),
                activeTrackColor: AppColors.accentRed,
              ),
            ],
          ),

          // Max poison
          Row(
            children: [
              const Icon(Icons.science, color: AppColors.accentGreen, size: 16),
              const SizedBox(width: 6),
              Text('Poison létal : ', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.textMuted, size: 18),
                onPressed: _maxPoison > 0
                    ? () => setState(() => _maxPoison--)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _maxPoison == 0 ? 'OFF' : '$_maxPoison',
                  style: AppTextStyles.bold(
                    color: _maxPoison == 0 ? AppColors.textMuted : AppColors.accentGreen,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.textMuted, size: 18),
                onPressed: () => setState(() => _maxPoison++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          // Max commander damage
          Row(
            children: [
              const Icon(Icons.shield, color: AppColors.accentOrange, size: 16),
              const SizedBox(width: 6),
              Text('Cmd létal : ', style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 12)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove, color: AppColors.textMuted, size: 18),
                onPressed: _maxCommanderDamage > 0
                    ? () => setState(() => _maxCommanderDamage--)
                    : null,
                visualDensity: VisualDensity.compact,
              ),
              Container(
                width: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _maxCommanderDamage == 0 ? 'OFF' : '$_maxCommanderDamage',
                  style: AppTextStyles.bold(
                    color: _maxCommanderDamage == 0 ? AppColors.textMuted : AppColors.accentOrange,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.textMuted, size: 18),
                onPressed: () => setState(() => _maxCommanderDamage++),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const Divider(color: AppColors.borderMedium, height: 16),

          // Tag
          TextField(
            onChanged: (v) => _tag = v,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tag de partie (ex: soirée chez Max)',
              hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.3), fontSize: 12),
              filled: true,
              fillColor: AppColors.textPrimary.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // --- PROFILE SELECTOR (with duplicate prevention) ---
  Future<Profile?> _showProfileSelector(int slotIndex) async {
    final assignedIds = _assignedProfileIds(excludeIndex: slotIndex);
    return showDialog<Profile>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choisir un profil', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: AppColors.textPrimary),
                title: const Text('Invité (Pas de profil)', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, null),
              ),
              const Divider(color: AppColors.borderMedium),
              ..._availableProfiles.map((p) {
                final isAssigned = assignedIds.contains(p.id);
                return ListTile(
                  enabled: !isAssigned,
                  leading: CircleAvatar(
                    backgroundColor: Color(p.colorValue).withValues(alpha: isAssigned ? 0.3 : 1.0),
                    backgroundImage: p.commanderImageUrl != null ? NetworkImage(p.commanderImageUrl!) : null,
                  ),
                  title: Text(
                    p.name,
                    style: TextStyle(
                      color: isAssigned ? AppColors.textDisabled : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: isAssigned
                      ? const Text('Déjà assigné', style: TextStyle(color: AppColors.textDisabled, fontSize: 11))
                      : null,
                  onTap: isAssigned ? null : () => Navigator.pop(ctx, p),
                );
              }),
              const Divider(color: AppColors.borderMedium),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.success),
                title: const Text('Créer un nouveau profil', style: TextStyle(color: AppColors.success)),
                onTap: () async {
                  final newProfile = await _showCreateProfileDialog();
                  if (newProfile != null && ctx.mounted) {
                    Navigator.pop(ctx, newProfile);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts, color: AppColors.primary),
                title: const Text('Gérer les profils', style: TextStyle(color: AppColors.primary)),
                subtitle: const Text('Galerie, partenaires, couleurs...', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx); // Close selector
                  Navigator.pop(context); // Close game setup modal
                  if (mounted) context.push(AppRoutes.profiles);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- PROFILE FORM (create/edit) ---
  Future<Profile?> _showProfileForm({Profile? existingProfile}) async {
    final nameCtrl = TextEditingController(text: existingProfile?.name);
    ScryfallCard? cmd1;
    ScryfallCard? cmd2;
    Color selectedColor = existingProfile != null ? Color(existingProfile.colorValue) : _defaultColors[1];

    return showDialog<Profile>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Text(existingProfile == null ? 'Nouveau Profil' : 'Modifier Profil', style: AppTextStyles.cinzel()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du Planeswalker', labelStyle: TextStyle(color: AppColors.textMuted)),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                _buildCommanderPickerTile(
                  label: 'Commandant',
                  card: cmd1,
                  existingName: existingProfile?.commanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null && context.mounted) setState(() => cmd1 = res);
                  },
                ),
                const SizedBox(height: 10),
                _buildCommanderPickerTile(
                  label: 'Partenaire / Background',
                  card: cmd2,
                  existingName: existingProfile?.secondaryCommanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null && context.mounted) setState(() => cmd2 = res);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (existingProfile != null)
              TextButton(
                onPressed: () async {
                  await _profileService.deleteProfile(existingProfile.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Supprimer', style: TextStyle(color: AppColors.accentRed)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final p = Profile(
                    id: existingProfile?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    colorValue: selectedColor.toARGB32(),
                    commanderScryfallId: cmd1?.id ?? existingProfile?.commanderScryfallId,
                    commanderName: cmd1?.name ?? existingProfile?.commanderName,
                    commanderArtCropUrl: cmd1?.artCropUrl ?? existingProfile?.commanderArtCropUrl,
                    secondaryCommanderScryfallId: cmd2?.id ?? existingProfile?.secondaryCommanderScryfallId,
                    secondaryCommanderName: cmd2?.name ?? existingProfile?.secondaryCommanderName,
                    secondaryCommanderArtCropUrl: cmd2?.artCropUrl ?? existingProfile?.secondaryCommanderArtCropUrl,
                    commanderGallery: existingProfile?.commanderGallery ?? [],
                  );
                  await _profileService.saveProfile(p);
                  if (!context.mounted) return;
                  Navigator.pop(context, p);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
  }

  Future<ScryfallCard?> _pickCard() async {
    final result = await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
      builder: (c) => const DeckCardPicker(),
    );
    if (result != null && result.isNotEmpty) return result.first['card'];
    return null;
  }

  Widget _buildCommanderPickerTile({required String label, ScryfallCard? card, String? existingName, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      tileColor: AppColors.textPrimary.withValues(alpha: 0.05),
      leading: Icon(Icons.shield, color: color),
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      subtitle: Text(card?.name ?? existingName ?? 'Aucun', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.search, size: 16),
    );
  }

  // --- CREATE PROFILE DIALOG ---
  Future<Profile?> _showCreateProfileDialog() async {
    final nameCtrl = TextEditingController();
    ScryfallCard? selectedCommander;
    Color selectedColor = _defaultColors[1];

    return showDialog<Profile>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          final String? avatarUrl = selectedCommander?.artCropUrl;
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.98),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            insetPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Nouveau Profil', style: AppTextStyles.pageTitle(fontSize: 22)),
                  const SizedBox(height: 24),
                  ScryfallAvatarImage(imageUrl: avatarUrl, radius: 40, backgroundColor: selectedColor),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.sectionTitle(),
                    decoration: InputDecoration(
                      hintText: 'Nom du joueur',
                      hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: AppColors.textPrimary.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final result = await showModalBottomSheet(
                        context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
                        builder: (c) => const DeckCardPicker(),
                      );
                      if (result != null && result.isNotEmpty && context.mounted) {
                        setState(() => selectedCommander = result.first['card']);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield, color: selectedColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Commandant Favori', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                Text(
                                  selectedCommander?.name ?? 'Aucun sélectionné',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.search, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _defaultColors.map((c) => GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c, shape: BoxShape.circle,
                          border: selectedColor == c ? Border.all(color: AppColors.textPrimary, width: 2) : null,
                          boxShadow: selectedColor == c ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8)] : null,
                        ),
                        child: selectedColor == c ? const Icon(Icons.check, size: 16, color: AppColors.textPrimary) : null,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Annuler', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5))),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty) {
                    final newProfile = Profile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      colorValue: selectedColor.toARGB32(),
                      commanderScryfallId: selectedCommander?.id,
                      commanderName: selectedCommander?.name,
                      commanderArtCropUrl: selectedCommander?.artCropUrl,
                      commanderGallery: selectedCommander != null
                          ? [CommanderEntry(
                              scryfallId: selectedCommander!.id,
                              name: selectedCommander!.name,
                              artCropUrl: selectedCommander!.artCropUrl,
                            )]
                          : [],
                    );
                    await _profileService.saveProfile(newProfile);
                    if (context.mounted) Navigator.pop(context, newProfile);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('CRÉER'),
              ),
            ],
          );
        });
      },
    );
  }
}
