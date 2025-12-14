// Fichier : lib/widgets/search/universal_filter_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/search_filters.dart';

class UniversalFilterModal extends StatefulWidget {
  final SearchFilters currentFilters;
  final List<String> availableTags; // Tags existants dans la collection/deck

  const UniversalFilterModal({
    super.key,
    required this.currentFilters,
    required this.availableTags,
  });

  @override
  State<UniversalFilterModal> createState() => _UniversalFilterModalState();
}

class _UniversalFilterModalState extends State<UniversalFilterModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // États locaux
  late String _sortType;
  late bool _sortAscending;
  
  late String? _selectedType;
  late Set<String> _selectedColors;
  late String? _selectedRarity;
  late RangeValues _cmcRange;
  late Set<String> _selectedTags;
  
  final TextEditingController _keywordController = TextEditingController();

  final Map<String, String> _sortOptions = {
    'name': 'Nom (A-Z)',
    'price': 'Prix (€)',
    'cmc': 'Mana (CMC)',
    'type': 'Type',
    'date': 'Date sortie',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Init depuis les filtres actuels
    _sortType = widget.currentFilters.sortType;
    _sortAscending = widget.currentFilters.sortAscending;
    _selectedType = widget.currentFilters.cardType;
    _selectedColors = Set.from(widget.currentFilters.colors);
    _selectedRarity = widget.currentFilters.rarity;
    _cmcRange = RangeValues(widget.currentFilters.minCmc ?? 0, widget.currentFilters.maxCmc ?? 10);
    _selectedTags = Set.from(widget.currentFilters.tags);
    _keywordController.text = widget.currentFilters.keyword ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _apply() {
    final filters = SearchFilters(
      sortType: _sortType,
      sortAscending: _sortAscending,
      cardType: _selectedType,
      colors: _selectedColors,
      rarity: _selectedRarity,
      minCmc: (_cmcRange.start <= 0 && _cmcRange.end >= 10) ? null : _cmcRange.start, // Null si full range
      maxCmc: (_cmcRange.start <= 0 && _cmcRange.end >= 10) ? null : _cmcRange.end,
      tags: _selectedTags,
      keyword: _keywordController.text.trim().isEmpty ? null : _keywordController.text.trim(),
      setCode: widget.currentFilters.setCode, // On préserve le set code s'il y en a un
    );
    Navigator.pop(context, filters);
  }

  void _reset() {
    setState(() {
      _sortType = 'name';
      _sortAscending = true;
      _selectedType = null;
      _selectedColors = {};
      _selectedRarity = null;
      _cmcRange = const RangeValues(0, 10);
      _selectedTags = {};
      _keywordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.yellow.shade800, width: 2)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Organiser & Filtrer", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(onPressed: _reset, child: const Text("Réinitialiser", style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          ),
          
          TabBar(
            controller: _tabController,
            indicatorColor: Colors.yellow.shade800,
            labelColor: Colors.yellow.shade800,
            unselectedLabelColor: Colors.white54,
            tabs: const [
              Tab(text: "Tri & Tags", icon: Icon(Icons.sort)),
              Tab(text: "Filtres Avancés", icon: Icon(Icons.filter_list)),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // --- ONGLET 1 : TRI & TAGS ---
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Ordre de tri"),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: _sortOptions.entries.map((e) {
                          final isSelected = _sortType == e.key;
                          return ChoiceChip(
                            label: Text(e.value),
                            selected: isSelected,
                            selectedColor: Colors.yellow.shade900,
                            backgroundColor: Colors.black45,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                            onSelected: (val) => setState(() => _sortType = e.key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text("Direction : ", style: TextStyle(color: Colors.white70)),
                          const SizedBox(width: 8),
                          ToggleButtons(
                            isSelected: [_sortAscending, !_sortAscending],
                            onPressed: (idx) => setState(() => _sortAscending = idx == 0),
                            color: Colors.white54,
                            selectedColor: Colors.black,
                            fillColor: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(8),
                            children: const [
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_upward)),
                              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_downward)),
                            ],
                          )
                        ],
                      ),
                      
                      const Divider(color: Colors.white24, height: 32),
                      
                      _buildSectionTitle("Filtrer par Tags"),
                      if (widget.availableTags.isEmpty)
                        const Text("Aucun tag personnalisé créé.", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic))
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: widget.availableTags.map((tag) {
                            final isSelected = _selectedTags.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) _selectedTags.add(tag);
                                  else _selectedTags.remove(tag);
                                });
                              },
                              backgroundColor: Colors.black45,
                              selectedColor: Colors.blueAccent.withOpacity(0.5),
                              checkmarkColor: Colors.white,
                              labelStyle: const TextStyle(color: Colors.white),
                            );
                          }).toList(),
                        )
                    ],
                  ),
                ),

                // --- ONGLET 2 : FILTRES AVANCÉS ---
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mot clé
                      TextField(
                        controller: _keywordController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Texte / Mot-clé (ex: Flying)",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true, fillColor: Colors.black45,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54)
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Couleurs
                      _buildSectionTitle("Couleurs"),
                      _buildColorSelector(),
                      const SizedBox(height: 16),
                      
                      // Rareté
                      _buildSectionTitle("Rareté"),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['common', 'uncommon', 'rare', 'mythic'].map((r) {
                          final isSel = _selectedRarity == r;
                          Color c = Colors.grey;
                          if (r == 'uncommon') c = Colors.blueGrey;
                          if (r == 'rare') c = Colors.amber;
                          if (r == 'mythic') c = Colors.orange;
                          
                          return GestureDetector(
                            onTap: () => setState(() => _selectedRarity = isSel ? null : r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? c.withOpacity(0.3) : Colors.black45,
                                border: Border.all(color: isSel ? c : Colors.white12),
                                borderRadius: BorderRadius.circular(16)
                              ),
                              child: Text(r[0].toUpperCase() + r.substring(1), style: TextStyle(color: isSel ? c : Colors.white54, fontWeight: FontWeight.bold)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // CMC
                      _buildSectionTitle("Coût Mana (CMC) : ${_cmcRange.start.round()} - ${_cmcRange.end.round()}"),
                      RangeSlider(
                        values: _cmcRange,
                        min: 0, max: 10,
                        divisions: 10,
                        activeColor: Colors.yellow.shade800,
                        inactiveColor: Colors.white24,
                        labels: RangeLabels('${_cmcRange.start.round()}', '${_cmcRange.end.round()}'),
                        onChanged: (v) => setState(() => _cmcRange = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bouton Appliquer
          SafeArea( // <--- CORRECTION ICI
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 16)
                  ),
                  child: Text("APPLIQUER", style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildColorSelector() {
    final colors = {'W', 'U', 'B', 'R', 'G', 'C'};
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: colors.map((c) {
        final isSelected = _selectedColors.contains(c);
        return GestureDetector(
          onTap: () => setState(() => isSelected ? _selectedColors.remove(c) : _selectedColors.add(c)),
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.3,
            child: SvgPicture.network(
              'https://svgs.scryfall.io/card-symbols/$c.svg',
              width: 32, height: 32,
              placeholderBuilder: (_) => CircleAvatar(backgroundColor: Colors.grey, radius: 16, child: Text(c)),
            ),
          ),
        );
      }).toList(),
    );
  }
}