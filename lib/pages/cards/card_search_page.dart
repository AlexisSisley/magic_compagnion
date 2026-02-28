// Fichier : lib/pages/cards/card_search_page.dart
// VERSION REFACTOREE : Logique metier extraite dans CardSearchController

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/search_filters.dart';
import 'package:magic_companion/widgets/search/search_filter_modal.dart';
import '../../controllers/card_search_controller.dart';
import '../../providers/service_providers.dart';
import '../../router/app_router.dart';
import 'set_list_page.dart';
import '../../models/scryfall_set_model.dart';
import '../../models/scryfall_card_model.dart';

// --- IMPORT DU NOUVEAU WIDGET ---
import '../../widgets/search/skyrim_sneak_loader.dart';

class CardSearchPage extends ConsumerStatefulWidget {
  const CardSearchPage({super.key});

  @override
  ConsumerState<CardSearchPage> createState() => _CardSearchPageState();
}

class _CardSearchPageState extends ConsumerState<CardSearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(cardSearchControllerProvider.notifier).onScroll(nearEnd: true);
    }
  }

  void _onSearchChanged(String query) {
    ref.read(cardSearchControllerProvider.notifier).onSearchChanged(query);
  }

  Future<void> _searchCards() async {
    if (_tabController.index != 0) _tabController.animateTo(0);
    final query = _searchController.text.trim();
    await ref.read(cardSearchControllerProvider.notifier).searchCards(query);
  }

  void _onSetSelected(ScryfallSet set) {
    ref.read(cardSearchControllerProvider.notifier).onSetSelected(set.code);
    _searchController.clear();
    _tabController.animateTo(0);
    _searchCards();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("Edition : ${set.name}"),
      backgroundColor: Colors.yellow.shade800,
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _openFilterModal() async {
    final state = ref.read(cardSearchControllerProvider);
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) { return SearchFilterModal(initialFilters: state.activeFilters); },
    );
    if (newFilters != null) {
      ref.read(cardSearchControllerProvider.notifier).updateFilters(newFilters);
      _searchCards();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardSearchControllerProvider);

    return Column(
      children: [
        Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.yellow.shade800,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.cinzel(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Cartes", icon: Icon(Icons.search)),
              Tab(text: "Editions", icon: Icon(Icons.layers)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              Column(
                children: [
                  _buildSearchBar(state),

                  if (state.searchResults.isNotEmpty && !state.isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      color: Colors.black26,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.resultCountLabel,
                            style: GoogleFonts.cinzel(color: Colors.white54, fontSize: 12),
                          ),
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: Icon(Icons.sort, color: Colors.yellow.shade700, size: 20),
                                color: const Color(0xFF1A1A1A),
                                tooltip: "Trier par...",
                                onSelected: (val) {
                                  final changed = ref.read(cardSearchControllerProvider.notifier).updateSort(val);
                                  if (changed) _searchCards();
                                },
                                itemBuilder: (context) => [
                                  _buildSortMenuItem(state, 'name', 'Nom'),
                                  _buildSortMenuItem(state, 'cmc', 'Mana (CMC)'),
                                  _buildSortMenuItem(state, 'type', 'Type'),
                                  _buildSortMenuItem(state, 'eur', 'Prix (EUR)'),
                                ],
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => ref.read(cardSearchControllerProvider.notifier).toggleGridView(),
                                child: Icon(state.isGridView ? Icons.grid_view : Icons.view_list, color: Colors.white70, size: 20),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                  Expanded(
                    child: state.isGridView
                        ? _buildResultsGrid(state, key: const ValueKey('Grid'))
                        : _buildResultsList(state, key: const ValueKey('List')),
                  ),
                ],
              ),
              SetListTab(onSetSelected: _onSetSelected),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(CardSearchState state, String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            state.sortBy == value ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: state.sortBy == value ? Colors.yellow.shade800 : Colors.white54,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(CardSearchState state) {
    final bool hasFilters = state.hasActiveFilters;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: state.activeFilters.setCode != null ? 'Dans: ${state.activeFilters.setCode!.toUpperCase()}...' : 'Nom de la carte...',
          hintStyle: GoogleFonts.cinzel(color: Colors.white54, fontSize: 14),
          prefixIcon: IconButton(
            icon: Icon(Icons.filter_list, color: hasFilters ? Colors.yellow.shade700 : Colors.white70),
            onPressed: _openFilterModal,
            tooltip: "Filtres avances",
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (hasFilters)
                IconButton(
                  icon: const Icon(Icons.highlight_off, color: Colors.red),
                  tooltip: "Reinitialiser filtres",
                  onPressed: () {
                    _searchController.clear();
                    ref.read(cardSearchControllerProvider.notifier).resetFilters();
                  },
                )
               else if (_searchController.text.isNotEmpty)
                 IconButton(
                   icon: const Icon(Icons.clear, color: Colors.white54),
                   onPressed: () {
                      _searchController.clear();
                      ref.read(cardSearchControllerProvider.notifier).clearSearchResults();
                   },
                 ),

              IconButton(
                icon: const Icon(Icons.search, color: Colors.white70),
                onPressed: _searchCards,
              ),
            ],
          ),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.55),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onSubmitted: (_) => _searchCards(),
      ),
    );
  }

  Widget _buildResultsList(CardSearchState state, {Key? key}) {
    if (state.isLoading) {
      return const Center(child: SkyrimSneakLoader());
    }

    if (state.searchResults.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(state.statusMessage, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center)));
    }

    return ListView.builder(
      key: key,
      controller: _scrollController,
      itemCount: state.searchResults.length + 1,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        if (index >= state.searchResults.length) {
          bool showLoader = state.hasMoreLocal || state.hasMoreApi;
          return showLoader ? const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())) : const SizedBox(height: 20);
        }

        if (index < 0) return const SizedBox();

        return _buildListTile(state, state.searchResults[index]);
      },
    );
  }

  Widget _buildListTile(CardSearchState state, ScryfallCard card) {
    final String cardName = card.name;
    final String? imageUrl = card.smallImageUrl ?? card.imageUrl;
    final String price = card.prices['eur'] ?? '--';

    final bool inWishlist = state.isCardInWishlist(cardName);
    final bool inCollection = state.isCardInCollection(card.id);

    return Card(
      color: Colors.black.withValues(alpha: 0.45),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: BorderSide(color: Colors.white10, width: 1)),
      child: InkWell(
        onTap: () => _navigateToDetail(cardName),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 60, height: 84, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 84, color: Colors.grey.shade800))
                    : Container(width: 60, height: 84, color: Colors.grey.shade800, child: const Icon(Icons.image, color: Colors.white30)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cardName, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(card.typeLine, style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
                          child: Text(card.setCode.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text("${card.cmc?.toInt() ?? 0} CMC", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(width: 8),
                        _buildRarityBadge(card.rarity),
                        const Spacer(),
                        Text('$price EUR', style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildActionButton(icon: inWishlist ? Icons.star : Icons.star_border, color: inWishlist ? Colors.blue : Colors.white30, onTap: () => _toggleWishlist(card.id, cardName, inWishlist)),
                  _buildActionButton(icon: inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, color: inCollection ? Colors.green : Colors.white30, onTap: () => _toggleCollection(card.id, cardName, inCollection)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsGrid(CardSearchState state, {Key? key}) {
    if (state.isLoading) {
      return const Center(child: SkyrimSneakLoader());
    }

    if (state.searchResults.isEmpty) {
      return Center(child: Text(state.statusMessage, style: GoogleFonts.cinzel(color: Colors.white70)));
    }

    return GridView.builder(
      key: key,
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.68, crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: state.searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index >= state.searchResults.length) {
           bool showLoader = state.hasMoreLocal || state.hasMoreApi;
           return showLoader ? const Center(child: CircularProgressIndicator()) : const SizedBox();
        }

        final card = state.searchResults[index];
        final String imageUrl = card.imageUrl.isNotEmpty ? card.imageUrl : (card.smallImageUrl ?? '');

        return GestureDetector(
          onTap: () => _navigateToDetail(card.name),
          child: Card(
            clipBehavior: Clip.antiAlias, color: Colors.black, elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.white12, width: 1)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(color: Colors.grey.shade900, child: Center(child: Text(card.name, textAlign: TextAlign.center, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 10)))),
                Positioned(bottom: 0, left: 0, right: 0, height: 40, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.9), Colors.transparent])))),
                Positioned(
                  bottom: 4, left: 4, right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${card.prices['eur'] ?? '-'}EUR", style: TextStyle(color: Colors.yellow.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildRarityBadge(card.rarity, small: true),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRarityBadge(String rarity, {bool small = false}) {
    Color c;
    switch(rarity) {
      case 'common': c = Colors.white; break;
      case 'uncommon': c = Colors.blue.shade300; break;
      case 'rare': c = Colors.amber; break;
      case 'mythic': c = Colors.orange.shade800; break;
      default: c = Colors.grey;
    }
    return Container(
      width: small ? 8 : 12, height: small ? 8 : 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1)),
    );
  }

  void _navigateToDetail(String cardName) {
    context.push(AppRoutes.cardDetail, extra: {'cardName': cardName}).then((_) {
      ref.read(cardSearchControllerProvider.notifier).loadLocalData();
    });
  }

  // --- SELECTEUR DE WISHLIST (UI uniquement) ---
  Future<String?> _showWishlistSelector() async {
    final wishlistService = ref.read(wishlistServiceProvider);
    final wishlists = await wishlistService.loadWishlists();
    if (!mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Choisir une Wishlist", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.greenAccent),
                    title: Text("Creer une nouvelle liste", style: GoogleFonts.cinzel(color: Colors.white)),
                    onTap: () async {
                      final name = await _showCreateWishlistDialog();
                      if (name != null && mounted) {
                        final updatedLists = await wishlistService.loadWishlists();
                        try {
                          final newList = updatedLists.lastWhere((w) => w.name == name);
                          Navigator.pop(context, newList.id);
                        } catch (_) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final list = wishlists[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark_border, color: Colors.blueAccent),
                          title: Text(list.name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text("${list.totalCards} cartes", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          onTap: () => Navigator.pop(context, list.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Future<String?> _showCreateWishlistDialog() async {
    final wishlistService = ref.read(wishlistServiceProvider);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Nouvelle Liste", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "Nom de la liste"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await wishlistService.createWishlist(controller.text);
                if (mounted) Navigator.pop(c, controller.text);
              }
            },
            child: const Text("Creer"),
          )
        ],
      )
    );
  }

  Future<void> _toggleWishlist(String id, String name, bool currentState) async {
    final ctrl = ref.read(cardSearchControllerProvider.notifier);
    if (currentState) {
      final msg = await ctrl.removeFromAllWishlists(name);
      _showFeedback(msg, Colors.red.shade700);
    } else {
      final targetListId = await _showWishlistSelector();
      if (targetListId != null) {
        final msg = await ctrl.addToWishlist(targetListId, id, name);
        _showFeedback(msg, Colors.blue.shade700);
      }
    }
  }

  Future<void> _toggleCollection(String id, String name, bool currentState) async {
    final msg = await ref.read(cardSearchControllerProvider.notifier).toggleCollection(id, name, currentState);
    _showFeedback(msg, currentState ? Colors.red.shade700 : Colors.green.shade700);
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, color: color, size: 22)),
    );
  }

  void _showFeedback(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.cinzel(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ));
  }
}
