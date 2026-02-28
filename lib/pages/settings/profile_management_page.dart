import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Profils des Joueurs", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
          : _profiles.isEmpty 
              ? Center(child: Text("Aucun profil créé.", style: GoogleFonts.cinzel(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) => _buildProfileCard(_profiles[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileForm(),
        backgroundColor: Colors.yellow.shade800,
        child: const Icon(Icons.person_add, color: Colors.black),
      ),
    );
  }

  Widget _buildProfileCard(Profile profile) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
      child: ListTile(
        leading: _buildDoubleAvatar(profile),
        title: Text(profile.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          profile.secondaryCommanderName != null 
            ? "${profile.commanderName} & ${profile.secondaryCommanderName}"
            : profile.commanderName ?? "Pas de commandant", 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis, 
          style: const TextStyle(color: Colors.white54, fontSize: 12)
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.white54), 
          onPressed: () => _showProfileForm(existing: profile)
        ),
      ),
    );
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(existing == null ? "Nouveau Profil" : "Modifier Profil", style: GoogleFonts.cinzel(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Nom du joueur", labelStyle: TextStyle(color: Colors.white54)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildPickerTile(
                  label: "Commandant", 
                  name: cmd1?.name ?? existing?.commanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null) setModalState(() => cmd1 = res);
                  }
                ),
                const SizedBox(height: 10),
                _buildPickerTile(
                  label: "Partenaire / Background", 
                  name: cmd2?.name ?? existing?.secondaryCommanderName,
                  color: selectedColor,
                  onTap: () async {
                    final res = await _pickCard();
                    if (res != null) setModalState(() => cmd2 = res);
                  }
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10, runSpacing: 10,
                  children: _defaultColors.map((c) => GestureDetector(
                    onTap: () => setModalState(() => selectedColor = c),
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: selectedColor == c ? Colors.white : Colors.transparent, width: 2)
                      ),
                    ),
                  )).toList(),
                )
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await _profileService.deleteProfile(existing.id);
                  Navigator.pop(context);
                  _loadProfiles();
                },
                child: const Text("Supprimer", style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final p = Profile(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    colorValue: selectedColor.value,
                    commanderScryfallId: cmd1?.id ?? existing?.commanderScryfallId,
                    commanderName: cmd1?.name ?? existing?.commanderName,
                    commanderArtCropUrl: cmd1?.artCropUrl ?? existing?.commanderArtCropUrl,
                    secondaryCommanderScryfallId: cmd2?.id ?? existing?.secondaryCommanderScryfallId,
                    secondaryCommanderName: cmd2?.name ?? existing?.secondaryCommanderName,
                    secondaryCommanderArtCropUrl: cmd2?.artCropUrl ?? existing?.secondaryCommanderArtCropUrl,
                  );
                  await _profileService.saveProfile(p);
                  Navigator.pop(context);
                  _loadProfiles();
                }
              },
              child: const Text("Enregistrer"),
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
      tileColor: Colors.white.withOpacity(0.05),
      leading: Icon(Icons.shield, color: color),
      title: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      subtitle: Text(name ?? "Aucun", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.search, size: 16, color: Colors.white54),
    );
  }

  Future<ScryfallCard?> _pickCard() async {
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (c) => const DeckCardPicker()
    );
    if (result != null && result.isNotEmpty) return result.first['card'] as ScryfallCard;
    return null;
  }
}