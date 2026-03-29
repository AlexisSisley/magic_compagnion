import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/profile_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/profile_service.dart';
import '../../widgets/decks/deck_card_picker.dart';
import '../../widgets/cards/scryfall_image.dart';
import '../../providers/service_providers.dart';

class ProfileManagementPage extends ConsumerStatefulWidget {
  const ProfileManagementPage({super.key});

  @override
  ConsumerState<ProfileManagementPage> createState() => _ProfileManagementPageState();
}

class _ProfileManagementPageState extends ConsumerState<ProfileManagementPage> {
  ProfileService get _profileService => ref.read(profileServiceProvider);
  List<Profile> _profiles = [];
  bool _isLoading = true;

  /// Gallery limits — free: 5, premium: 30 (IAP later)
  static const int _galleryLimitFree = 5;
  static const int _galleryLimitPremium = 30;
  // TODO: wire to real IAP premium check
  bool get _isPremium => false;
  int get _galleryLimit => _isPremium ? _galleryLimitPremium : _galleryLimitFree;

  final List<Color> _defaultColors = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.purple.shade900, Colors.orange.shade900, Colors.teal.shade900,
    Colors.pink.shade900, Colors.brown.shade800, Colors.indigo.shade900,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final list = await _profileService.loadProfiles();
    if (mounted) setState(() { _profiles = list; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('Profils des Joueurs', style: AppTextStyles.bold()),
        backgroundColor: AppColors.textOnPrimary,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _profiles.isEmpty 
              ? Center(child: Text('Aucun profil créé.', style: AppTextStyles.cinzel(color: AppColors.borderFaint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) => _buildProfileCard(_profiles[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileForm(),
        backgroundColor: AppColors.primaryShade800,
        child: const Icon(Icons.person_add, color: AppColors.textOnPrimary),
      ),
    );
  }

  Widget _buildProfileCard(Profile profile) {
    return Card(
      color: AppColors.textPrimary.withValues(alpha: 0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.borderLight)),
      child: ListTile(
        leading: _buildDoubleAvatar(profile),
        title: Text(profile.name, style: AppTextStyles.bold()),
        subtitle: Text(
          _buildProfileSubtitle(profile),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: AppColors.textMuted), 
          onPressed: () => _showProfileForm(existing: profile)
        ),
      ),
    );
  }

  String _buildProfileSubtitle(Profile profile) {
    final parts = <String>[];
    if (profile.secondaryCommanderName != null) {
      parts.add('${profile.commanderName} & ${profile.secondaryCommanderName}');
    } else if (profile.commanderName != null) {
      parts.add(profile.commanderName!);
    } else {
      parts.add('Pas de commandant');
    }
    if (profile.commanderGallery.isNotEmpty) {
      parts.add('(${profile.commanderGallery.length} en galerie)');
    }
    return parts.join(' ');
  }

  Widget _buildDoubleAvatar(Profile p) {
    if (p.secondaryCommanderScryfallId == null) {
      return ScryfallAvatarImage(
        imageUrl: p.commanderImageUrl,
        radius: 20,
        backgroundColor: Color(p.colorValue),
      );
    }
    return Container(
      width: 40, height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Color(p.colorValue), width: 2)),
      child: Row(
        children: [
          Expanded(child: ScryfallImage(imageUrl: p.commanderImageUrl)),
          Expanded(child: ScryfallImage(imageUrl: p.secondaryCommanderImageUrl)),
        ],
      ),
    );
  }

  Future<void> _showProfileForm({Profile? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    ScryfallCard? cmd1;
    ScryfallCard? cmd2;
    Color selectedColor = existing != null ? Color(existing.colorValue) : _defaultColors[1];
    // Commander gallery — mutable copy from existing profile
    final List<CommanderEntry> gallery = List.from(existing?.commanderGallery ?? []);

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(builder: (dialogCtx, setModalState) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Text(existing == null ? 'Nouveau Profil' : 'Modifier Profil', style: AppTextStyles.cinzel()),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nom du joueur', labelStyle: TextStyle(color: AppColors.textMuted)),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 20),
                _buildPickerTile(
                  label: 'Commandant',
                  name: cmd1?.name ?? existing?.commanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null) setModalState(() => cmd1 = res);
                  }
                ),
                const SizedBox(height: 10),
                _buildPickerTile(
                  label: 'Partenaire / Background',
                  name: cmd2?.name ?? existing?.secondaryCommanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null) setModalState(() => cmd2 = res);
                  }
                ),
                const SizedBox(height: 16),
                // --- Commander Gallery ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Galerie Commanders', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('${gallery.length}/$_galleryLimit',
                            style: TextStyle(
                              color: gallery.length >= _galleryLimit ? AppColors.accentOrange : AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          if (!_isPremium) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _showPremiumInfo(dialogCtx),
                              child: const Icon(Icons.lock_outline, color: AppColors.accentOrange, size: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: gallery.length >= _galleryLimit
                          ? () => _showPremiumInfo(dialogCtx)
                          : () async {
                              final cards = await _pickCards();
                              if (cards.isNotEmpty && dialogCtx.mounted) {
                                setModalState(() {
                                  final remaining = _galleryLimit - gallery.length;
                                  int added = 0;
                                  for (final card in cards) {
                                    if (added >= remaining) break;
                                    // Avoid duplicates by scryfallId
                                    if (!gallery.any((e) => e.scryfallId == card.id)) {
                                      gallery.add(CommanderEntry(
                                        scryfallId: card.id,
                                        name: card.name,
                                        artCropUrl: card.artCropUrl,
                                      ));
                                      added++;
                                    }
                                  }
                                  if (added < cards.length) {
                                    _showLimitReachedSnackbar(dialogCtx, cards.length - added);
                                  }
                                });
                              }
                            },
                    ),
                  ],
                ),
                if (gallery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucun commander dans la galerie.\nAjoute-en pour switcher en partie.\n(Limite : $_galleryLimit${_isPremium ? '' : ' gratuit, 30 en Premium'})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  )
                else
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final entry = gallery[i];
                        return Stack(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.borderMedium),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: entry.imageUrl != null
                                      ? ScryfallImage(imageUrl: entry.imageUrl)
                                      : Container(color: AppColors.surfaceDarkest, child: const Icon(Icons.image, size: 20, color: AppColors.textMuted)),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  width: 48,
                                  child: Text(entry.name, style: const TextStyle(fontSize: 8, color: AppColors.textMuted),
                                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                            // Delete button
                            Positioned(
                              top: -4, right: -4,
                              child: GestureDetector(
                                onTap: () => setModalState(() => gallery.removeAt(i)),
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentRed),
                                  child: const Icon(Icons.close, size: 12, color: AppColors.textPrimary),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _defaultColors.map((c) => GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: selectedColor == c ? Colors.white : AppColors.transparent, width: 2)
                      ),
                    ),
                  )).toList(),
                )
              ],
            ),
          ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await _profileService.deleteProfile(existing.id);
                  if (!dialogCtx.mounted) return;
                  Navigator.of(dialogCtx).pop();
                  _loadProfiles();
                },
                child: const Text('Supprimer', style: TextStyle(color: AppColors.accentRed)),
              ),
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final p = Profile(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    colorValue: selectedColor.toARGB32(),
                    commanderScryfallId: cmd1?.id ?? existing?.commanderScryfallId,
                    commanderName: cmd1?.name ?? existing?.commanderName,
                    commanderArtCropUrl: cmd1?.artCropUrl ?? existing?.commanderArtCropUrl,
                    secondaryCommanderScryfallId: cmd2?.id ?? existing?.secondaryCommanderScryfallId,
                    secondaryCommanderName: cmd2?.name ?? existing?.secondaryCommanderName,
                    secondaryCommanderArtCropUrl: cmd2?.artCropUrl ?? existing?.secondaryCommanderArtCropUrl,
                    commanderGallery: gallery,
                  );
                  await _profileService.saveProfile(p);
                  if (!dialogCtx.mounted) return;
                  Navigator.of(dialogCtx).pop();
                  _loadProfiles();
                }
              },
              child: const Text('Enregistrer'),
            )
          ],
        );
      }),
    );
  }

  Widget _buildPickerTile({required String label, String? name, required Color color, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      tileColor: AppColors.textPrimary.withValues(alpha: 0.05),
      leading: Icon(Icons.shield, color: color),
      title: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      subtitle: Text(name ?? 'Aucun', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.search, size: 16, color: AppColors.textMuted),
    );
  }

  /// Pick a single card (for commander / partner selection).
  Future<ScryfallCard?> _pickCard() async {
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
      builder: (c) => const DeckCardPicker()
    );
    if (result != null && result.isNotEmpty) return result.first['card'] as ScryfallCard;
    return null;
  }

  /// Pick multiple cards at once (for gallery bulk add).
  /// Returns a flat list of unique ScryfallCard objects from the picker's cart.
  Future<List<ScryfallCard>> _pickCards() async {
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
      builder: (c) => const DeckCardPicker()
    );
    if (result == null || result.isEmpty) return [];
    // Each entry: {'card': ScryfallCard, 'quantity': int}
    // For gallery we only care about unique cards (quantity ignored)
    final cards = <ScryfallCard>[];
    final seen = <String>{};
    for (final entry in result) {
      final card = entry['card'] as ScryfallCard;
      if (seen.add(card.id)) cards.add(card);
    }
    return cards;
  }

  void _showLimitReachedSnackbar(BuildContext ctx, int skipped) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(
          '$skipped commander(s) ignoré(s) — limite de $_galleryLimit atteinte.${_isPremium ? '' : ' Passe en Premium pour 30 !'}',
        ),
        backgroundColor: AppColors.accentOrange,
        behavior: SnackBarBehavior.floating,
        action: _isPremium ? null : SnackBarAction(
          label: 'PREMIUM',
          textColor: AppColors.textPrimary,
          onPressed: () => _showPremiumInfo(ctx),
        ),
      ),
    );
  }

  void _showPremiumInfo(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.accentOrange, size: 28),
            const SizedBox(width: 8),
            Text('Premium', style: AppTextStyles.cinzel(color: AppColors.accentOrange)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La galerie gratuite est limitée à $_galleryLimitFree commanders par profil.',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Avec Premium, tu peux sauvegarder jusqu\'à $_galleryLimitPremium commanders et switcher en pleine partie !',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bientôt disponible.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
