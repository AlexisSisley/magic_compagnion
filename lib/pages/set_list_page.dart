// Fichier : lib/pages/set_list_page.dart
// Devenu un composant (Tab) réutilisable

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scryfall_set_model.dart';
import '../services/set_service.dart';

class SetListTab extends StatefulWidget {
  // Ce callback permet au parent (CardSearchPage) de savoir qu'on a cliqué
  final Function(ScryfallSet) onSetSelected; 

  const SetListTab({super.key, required this.onSetSelected});

  @override
  State<SetListTab> createState() => _SetListTabState();
}

class _SetListTabState extends State<SetListTab> {
  final SetService _setService = SetService();
  final TextEditingController _searchController = TextEditingController();
  
  List<ScryfallSet> _allSets = [];
  List<ScryfallSet> _filteredSets = [];
  bool _isLoading = true;
  String _selectedType = 'all';

  final Map<String, String> _typeLabels = {
    'all': 'Tous les types',
    'core': 'Core Sets',
    'expansion': 'Expansions',
    'masters': 'Masters',
    'commander': 'Commander',
    'alchemy': 'Alchemy',
    'from_the_vault': 'From the Vault',
    'spellbook': 'Spellbook',
    'secret_lair': 'Secret Lair',
    'promo': 'Promos',
    'funny': 'Fun / Un-sets',
    'token': 'Tokens',
  };

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    setState(() => _isLoading = true);
    final sets = await _setService.getAllSets();
    sets.sort((a, b) {
      final dateA = a.releaseDate ?? DateTime(1900);
      final dateB = b.releaseDate ?? DateTime(1900);
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _allSets = sets;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSets = _allSets.where((set) {
        final matchesSearch = set.name.toLowerCase().contains(query) || set.code.toLowerCase().contains(query);
        final matchesType = _selectedType == 'all' || set.setType == _selectedType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filtres (Compactés pour tenir dans l'onglet)
        Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.black.withOpacity(0.2),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nom ou Code...',
                    hintStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 18),
                    filled: true, fillColor: Colors.black54,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => _applyFilters(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _typeLabels.containsKey(_selectedType) ? _selectedType : 'all',
                      dropdownColor: const Color(0xFF1A1A1A),
                      isDense: true,
                      icon: Icon(Icons.filter_list, color: Colors.yellow.shade800, size: 18),
                      style: GoogleFonts.cinzel(color: Colors.white, fontSize: 12),
                      isExpanded: true,
                      items: _typeLabels.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() { _selectedType = val; _applyFilters(); });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredSets.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemBuilder: (context, index) => _buildSetTile(_filteredSets[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildSetTile(ScryfallSet set) {
    Color typeColor = Colors.grey;
    if (set.setType == 'expansion') typeColor = Colors.blue.shade400;
    if (set.setType == 'commander') typeColor = Colors.yellow.shade700;
    if (set.setType == 'core') typeColor = Colors.green.shade400;
    if (set.setType == 'masters') typeColor = Colors.purple.shade300;

    return Card(
      color: Colors.black.withOpacity(0.4),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          padding: const EdgeInsets.all(4),
          child: set.iconSvgUri != null
              ? SvgPicture.network(
                  set.iconSvgUri!,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  placeholderBuilder: (_) => const Icon(Icons.broken_image, color: Colors.white24, size: 20),
                )
              : const Icon(Icons.circle, color: Colors.white24),
        ),
        title: Text(set.name, style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('${set.code.toUpperCase()} • ${set.releasedAt ?? ''} • ${set.cardCount} cartes', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: Icon(Icons.chevron_right, color: typeColor),
        onTap: () => widget.onSetSelected(set), // <-- Appel du callback
      ),
    );
  }
}