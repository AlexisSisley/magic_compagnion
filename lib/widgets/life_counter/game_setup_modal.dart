// Fichier : lib/widgets/life_counter/game_setup_modal.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/models/profile_model.dart';
import 'package:magic_companion/models/scryfall_card_model.dart';
import 'package:magic_companion/services/profile_service.dart';
import 'package:magic_companion/widgets/decks/deck_card_picker.dart';
import 'package:magic_companion/widgets/cards/scryfall_image.dart';
import 'package:magic_companion/providers/service_providers.dart';

class GameSetupModal extends ConsumerStatefulWidget {
  final int initialLife;
  final Function(int startingLife, List<Profile?> profiles) onGameStart;

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
  late int _startingLife;
  final List<Profile?> _selectedProfiles = List.filled(4, null, growable: true);
  List<Profile> _availableProfiles = [];

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.brown.shade800, Colors.pink.shade900, Colors.indigo.shade900, AppColors.greyShade800
  ];

  @override
  void initState() {
    super.initState();
    _startingLife = widget.initialLife;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await _profileService.loadProfiles();
    if (mounted) setState(() => _availableProfiles = list);
  }

  @override
  Widget build(BuildContext context) {
    // AJOUT DU SAFEAREA POUR ÉVITER LE CHEVAUCHEMENT AVEC LA NAV BAR
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        // On limite la hauteur pour ne pas prendre tout l'écran inutilement
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Configuration de la partie', 
              style: AppTextStyles.pageTitle(fontSize: 22), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 20),
            
            // Sélecteur Format
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFormatChip('Commander (40 PV)', 40),
                const SizedBox(width: 12),
                _buildFormatChip('Standard (20 PV)', 20),
              ],
            ),
            const SizedBox(height: 20),

            // Liste des Slots Joueurs
            Expanded(
              child: ListView.separated(
                itemCount: _selectedProfiles.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == _selectedProfiles.length) {
                    return _buildAddRemoveButtons();
                  }
                  return _buildPlayerSlot(index);
                },
              ),
            ),
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onGameStart(_startingLife, _selectedProfiles);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryShade800,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('LANCER LA PARTIE', 
                style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 18)
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, int life) {
    final bool isSelected = _startingLife == life;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) => setState(() => _startingLife = life),
      selectedColor: Colors.blue.shade900,
      backgroundColor: AppColors.textOnPrimary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textMuted, 
        fontWeight: FontWeight.bold
      ),
    );
  }

  Widget _buildAddRemoveButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_selectedProfiles.length < 8)
          TextButton.icon(
            onPressed: () => setState(() => _selectedProfiles.add(null)),
            icon: const Icon(Icons.add_circle, color: AppColors.success),
            label: const Text('Ajouter Joueur', style: TextStyle(color: AppColors.success)),
          ),
        if (_selectedProfiles.length > 2)
          TextButton.icon(
            onPressed: () => setState(() => _selectedProfiles.removeLast()),
            icon: const Icon(Icons.remove_circle, color: AppColors.error),
            label: const Text('Retirer Joueur', style: TextStyle(color: AppColors.error)),
          ),
      ],
    );
  }

  Widget _buildPlayerSlot(int index) {
    final profile = _selectedProfiles[index];
    return Card(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onLongPress: profile != null ? () async {
          // MODIFICATION : Clic long pour éditer le profil
          await _showProfileForm(existingProfile: profile);
          _loadProfiles(); // Recharger la liste
        } : null,
        leading: _buildProfileAvatar(profile, index),
        title: Text(profile?.name ?? 'Invité ${index + 1}', 
          style: AppTextStyles.cinzel()
        ),
        subtitle: profile?.commanderName != null 
            ? Text('Cmd: ${profile!.commanderName}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)) 
            : null,
        trailing: const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
        onTap: () async {
          final selected = await _showProfileSelector(_availableProfiles);
          if (selected != null) {
            setState(() => _selectedProfiles[index] = selected);
          }
        },
      ),
    );
  }

  // Helper pour l'avatar split si partenaires
  Widget _buildProfileAvatar(Profile? profile, int index) {
    if (profile == null) return CircleAvatar(backgroundColor: AppColors.synergyNeutral, child: Text('${index+1}'));

    if (profile.secondaryCommanderScryfallId == null) {
      return ScryfallAvatarImage(
        imageUrl: profile.commanderImageUrl,
        radius: 20,
        backgroundColor: Color(profile.colorValue),
      );
    }

    // Avatar split pour partenaires
    return Container(
      width: 40, height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Color(profile.colorValue), width: 2)),
      child: Row(
        children: [
          Expanded(child: ScryfallImage(imageUrl: profile.commanderImageUrl)),
          Expanded(child: ScryfallImage(imageUrl: profile.secondaryCommanderImageUrl)),
        ],
      ),
    );
  }

  Future<Profile?> _showProfileSelector(List<Profile> profiles) async {
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
              ...profiles.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(p.colorValue), 
                  backgroundImage: p.commanderImageUrl != null ? NetworkImage(p.commanderImageUrl!) : null
                ),
                title: Text(p.name, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => Navigator.pop(ctx, p),
              )),
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
              )
            ],
          ),
        ),
      )
    );
  }
  // Refactorisation de la modale de création en "Formulaire de Profil" (Création/Edition)
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
                    if (res != null) setState(() => cmd1 = res);
                  }
                ),
                const SizedBox(height: 10),
                _buildCommanderPickerTile(
                  label: 'Partenaire / Background', 
                  card: cmd2, 
                  existingName: existingProfile?.secondaryCommanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null) setState(() => cmd2 = res);
                  }
                ),
                // ... (Color Picker identique)
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
                  );
                  await _profileService.saveProfile(p);
                  if (!context.mounted) return;
                  Navigator.pop(context, p);
                }
              },
              child: const Text('Enregistrer'),
            )
          ],
        );
      }),
    );
  }

  // Helper pour le picker de carte
  Future<ScryfallCard?> _pickCard() async {
    final result = await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
      builder: (c) => const DeckCardPicker()
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

  // --- MODALE DE CRÉATION AU DESIGN AÉRIEN ---
  Future<Profile?> _showCreateProfileDialog() async {
    final nameCtrl = TextEditingController();
    ScryfallCard? selectedCommander;
    Color selectedColor = _defaultColors[1]; // Bleu par défaut

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

                  // 1. Avatar (Preview)
                  ScryfallAvatarImage(
                    imageUrl: avatarUrl,
                    radius: 40,
                    backgroundColor: selectedColor,
                  ),
                  const SizedBox(height: 24),

                  // 2. Champ Nom
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

                  // 3. Sélecteur Commandant
                  InkWell(
                    onTap: () async {
                      final result = await showModalBottomSheet(
                        context: context, 
                        isScrollControlled: true,
                        backgroundColor: AppColors.transparent,
                        builder: (c) => const DeckCardPicker()
                      );
                      if (result != null && result.isNotEmpty) {
                        setState(() => selectedCommander = result.first['card']);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1))
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

                  // 4. Color Picker (Style aéré)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _defaultColors.map((c) => GestureDetector(
                      onTap: () => setState(() => selectedColor = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
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
                onPressed: ()=>Navigator.pop(context), 
                child: Text('Annuler', style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.5)))
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
                    );
                    await _profileService.saveProfile(newProfile);
                    if (context.mounted) Navigator.pop(context, newProfile);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                ),
                child: const Text('CRÉER')
              )
            ],
          );
        });
      }
    );
  }
}
