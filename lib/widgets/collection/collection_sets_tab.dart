// Fichier : lib/widgets/collection/collection_sets_tab.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/models/deck_model.dart';
import '../../models/scryfall_set_model.dart';
import '../../router/app_router.dart';
import '../../services/set_service.dart';
import '../../services/local_card_service.dart';
import '../../services/wishlist_service.dart';
import '../../providers/service_providers.dart';

class CollectionSetsTab extends ConsumerStatefulWidget {
  final List<DeckCard> collection;
  final Future<void> Function()? onRefresh;

  const CollectionSetsTab({
    super.key,
    required this.collection,
    this.onRefresh,
  });

  @override
  ConsumerState<CollectionSetsTab> createState() => _CollectionSetsTabState();
}

class _CollectionSetsTabState extends ConsumerState<CollectionSetsTab> {
  SetService get _setService => ref.read(setServiceProvider);
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);
  WishlistService get _wishlistService => ref.read(wishlistServiceProvider);
  
  final TextEditingController _searchController = TextEditingController();

  List<ScryfallSet> _allSets = []; // La liste complète brute
  List<ScryfallSet> _displayedSets = []; // La liste affichée (filtrée/triée)
  
  Map<String, int> _ownedCounts = {};
  Map<String, int> _wishlistCounts = {}; 
  
  bool _isLoading = true;

  // --- ÉTATS DE FILTRE & TRI ---
  String _sortBy = 'date'; // 'date', 'name', 'code', 'type'
  bool _sortAsc = false;   // false = Descendant (plus récent en premier)
  String _filterType = 'all'; // 'all', 'expansion', 'core', 'commander'...

  // Labels pour le filtre de type
  final Map<String, String> _typeLabels = {
    'all': 'Tous les types',
    'core': 'Core Sets',
    'expansion': 'Expansions',
    'masters': 'Masters',
    'commander': 'Commander',
    'alchemy': 'Alchemy',
    'secret_lair': 'Secret Lair',
    'funny': 'Fun / Un-sets',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CollectionSetsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.length != widget.collection.length) {
      _calculate();
    }
  }

  Future<void> _load() async {
    if (!_localCardService.isLoaded) {
      await _localCardService.loadLocalData();
    }

    final sets = await _setService.getAllSets();
    // On garde uniquement les sets avec des cartes
    final validSets = sets.where((s) => s.cardCount > 0).toList();
    
    if (mounted) {
      setState(() { 
        _allSets = validSets; 
        _isLoading = false; 
      });
      _calculate();     // Calcule les stats
      _applyFilters();  // Applique tri/filtre initial
    }
  }

  // --- CALCUL DES STATS (Possédés / Wishlist) ---
  Future<void> _calculate() async {
    Map<String, Set<String>> uniqueOwnedPerSet = {};
    Map<String, Set<String>> uniqueWishedPerSet = {};

    // 1. Analyse Collection
    for (var card in widget.collection) {
      final local = _localCardService.getCardById(card.scryfallId);
      if (local != null) {
        uniqueOwnedPerSet.putIfAbsent(local.setCode, () => {});
        uniqueOwnedPerSet[local.setCode]!.add(local.id);
      }
    }

    // 2. Analyse Wishlists
    final wishlists = await _wishlistService.loadWishlists();
    for (var list in wishlists) {
      for (var card in list.cards) {
        final local = _localCardService.getCardById(card.scryfallId);
        if (local != null) {
          bool alreadyOwned = uniqueOwnedPerSet[local.setCode]?.contains(local.id) ?? false;
          if (!alreadyOwned) {
            uniqueWishedPerSet.putIfAbsent(local.setCode, () => {});
            uniqueWishedPerSet[local.setCode]!.add(local.id);
          }
        }
      }
    }

    Map<String, int> finalOwned = {};
    Map<String, int> finalWished = {};

    uniqueOwnedPerSet.forEach((setCode, ids) { finalOwned[setCode] = ids.length; });
    uniqueWishedPerSet.forEach((setCode, ids) { finalWished[setCode] = ids.length; });

    if (mounted) {
      setState(() {
        _ownedCounts = finalOwned;
        _wishlistCounts = finalWished;
      });
    }
  }

  // --- LOGIQUE FILTRE & TRI ---
  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    
    // 1. Filtrage
    List<ScryfallSet> result = _allSets.where((s) {
      // Filtre Texte (Nom ou Code)
      if (query.isNotEmpty) {
        bool matchName = s.name.toLowerCase().contains(query);
        bool matchCode = s.code.toLowerCase().contains(query);
        if (!matchName && !matchCode) return false;
      }
      // Filtre Type
      if (_filterType != 'all' && s.setType != _filterType) {
        return false;
      }
      return true;
    }).toList();

    // 2. Tri
    result.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        case 'code':
          cmp = a.code.compareTo(b.code);
          break;
        case 'type':
          cmp = a.setType.compareTo(b.setType);
          break;
        case 'date':
        default:
          final dateA = a.releaseDate ?? DateTime(1900);
          final dateB = b.releaseDate ?? DateTime(1900);
          cmp = dateA.compareTo(dateB);
          break;
      }
      return _sortAsc ? cmp : -cmp; // Inverse si descendant
    });

    setState(() {
      _displayedSets = result;
    });
  }

  Future<void> _handleRefresh() async {
    final setsFuture = _load();
    final parentFuture = widget.onRefresh?.call() ?? Future.value();
    await Future.wait([setsFuture, parentFuture]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));

    return Column(
      children: [
        // --- BARRE DE CONTRÔLE ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: AppColors.textOnPrimary.withValues(alpha: 0.3),
          child: Column(
            children: [
              // Ligne 1 : Recherche + Boutons
              Row(
                children: [
                  // Champ Recherche
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Nom ou Code...',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => _applyFilters(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Menu TRI
                  _buildSortMenu(),
                  
                  const SizedBox(width: 4),
                  
                  // Menu FILTRE TYPE
                  _buildFilterTypeMenu(),
                ],
              ),
              
              // Ligne 2 : Infos résumées
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_displayedSets.length} éditions',
                      style: AppTextStyles.label(color: AppColors.textMuted),
                    ),
                    // Indicateur de tri actuel
                    GestureDetector(
                      onTap: () { setState(() { _sortAsc = !_sortAsc; _applyFilters(); }); },
                      child: Row(
                        children: [
                          Text(_getSortLabel(_sortBy), style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                          Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: AppColors.primary, size: 14)
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),

        // --- LISTE ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.primaryShade800,
            backgroundColor: AppColors.scaffoldBackground,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), 
              itemCount: _displayedSets.length,
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
              itemBuilder: (context, index) {
                final set = _displayedSets[index];
                
                final int owned = _ownedCounts[set.code] ?? 0;
                final int wished = _wishlistCounts[set.code] ?? 0;
                final int total = set.cardCount > 0 ? set.cardCount : 1;

                return Card(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      context.push(AppRoutes.setDetail, extra: set);
                    },
                    child: Column(
                      children: [
                        ListTile(
                          leading: SizedBox(
                            width: 40, 
                            child: SvgPicture.network(set.iconSvgUri ?? '', colorFilter: const ColorFilter.mode(AppColors.textPrimary, BlendMode.srcIn))
                          ),
                          title: Text(set.name, style: AppTextStyles.cinzel()),
                          subtitle: RichText(
                            text: TextSpan(
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              children: [
                                TextSpan(text: '$owned', style: const TextStyle(color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
                                const TextSpan(text: ' + '),
                                TextSpan(text: '$wished', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                                TextSpan(text: ' / $total cartes'),
                                TextSpan(text: ' • ${_formatDate(set.releaseDate)}'),
                              ]
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.borderMedium),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: _buildMultiProgressBar(total, owned, wished),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIAIRES ---

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.textPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.sort, color: AppColors.textSecondary, size: 20),
      ),
      tooltip: 'Trier par...',
      color: AppColors.scaffoldBackground,
      onSelected: (val) {
        setState(() {
          if (_sortBy == val) {
            _sortAsc = !_sortAsc; // Inverse si même choix
          } else {
            _sortBy = val;
          }
          _applyFilters();
        });
      },
      itemBuilder: (ctx) => [
        _buildPopupItem('date', 'Date de sortie', Icons.calendar_today),
        _buildPopupItem('name', 'Nom (A-Z)', Icons.sort_by_alpha),
        _buildPopupItem('code', 'Code Set', Icons.qr_code),
        _buildPopupItem('type', 'Type de Set', Icons.category),
      ],
    );
  }

  Widget _buildFilterTypeMenu() {
    bool isActive = _filterType != 'all';
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryShade900 : AppColors.textPrimary.withValues(alpha: 0.1), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: Icon(Icons.filter_list, color: isActive ? Colors.white : AppColors.textSecondary, size: 20),
      ),
      tooltip: 'Filtrer par type',
      color: AppColors.scaffoldBackground,
      onSelected: (val) {
        setState(() { _filterType = val; _applyFilters(); });
      },
      itemBuilder: (ctx) => _typeLabels.entries.map((e) {
        return PopupMenuItem(
          value: e.key,
          child: Row(
            children: [
              Icon(_filterType == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked, 
                   color: _filterType == e.key ? AppColors.primary : AppColors.synergyNeutral, size: 18),
              const SizedBox(width: 8),
              Text(e.value, style: const TextStyle(color: AppColors.textPrimary)),
            ],
          ),
        );
      }).toList(),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String text, IconData icon) {
    bool isSelected = _sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary)),
          if (isSelected) ...[
            const Spacer(),
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, color: AppColors.primary, size: 14)
          ]
        ],
      ),
    );
  }

  String _getSortLabel(String sortKey) {
    switch(sortKey) {
      case 'date': return 'Date';
      case 'name': return 'Nom';
      case 'code': return 'Code';
      case 'type': return 'Type';
      default: return '';
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}';
  }

  Widget _buildMultiProgressBar(int total, int owned, int wished) {
    int displayOwned = owned;
    int displayWished = wished;
    
    if (displayOwned > total) {
      displayOwned = total;
      displayWished = 0;
    } else if (displayOwned + displayWished > total) {
      displayWished = total - displayOwned;
    }
    
    int empty = total - displayOwned - displayWished;
    if (empty < 0) empty = 0;

    if (total == 0) return const SizedBox(height: 4);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 4,
        color: AppColors.borderLight,
        child: Row(
          children: [
            if (displayOwned > 0)
              Expanded(flex: displayOwned, child: Container(color: AppColors.accentOrange)),
            if (displayWished > 0)
              Expanded(flex: displayWished, child: Container(color: AppColors.accent)),
            if (empty > 0)
              Expanded(flex: empty, child: Container(color: AppColors.transparent)),
          ],
        ),
      ),
    );
  }
}
