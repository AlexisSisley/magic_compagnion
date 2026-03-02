// Fichier : lib/pages/cards/card_search_page.dart
// VERSION REFACTOREE : Logique metier extraite dans CardSearchController

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
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
import '../../widgets/search/scryfall_syntax_help.dart';
import '../../widgets/common/collection_badge.dart';

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
      content: Text('Edition : ${set.name}'),
      backgroundColor: AppColors.primaryShade800,
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _openFilterModal() async {
    final state = ref.read(cardSearchControllerProvider);
    final newFilters = await showModalBottomSheet<SearchFilters>(
      context: context, isScrollControlled: true, backgroundColor: AppColors.transparent,
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
          color: AppColors.textOnPrimary.withValues(alpha: 0.5),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryShade800,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTextStyles.bold(),
            tabs: const [
              Tab(text: 'Cartes', icon: Icon(Icons.search)),
              Tab(text: 'Editions', icon: Icon(Icons.layers)),
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
                      color: AppColors.overlayLight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.resultCountLabel,
                            style: AppTextStyles.label(color: AppColors.textMuted),
                          ),
                          Row(
                            children: [
                              PopupMenuButton<String>(
                                icon: Icon(Icons.sort, color: AppColors.primaryShade700, size: 20),
                                color: AppColors.scaffoldBackground,
                                tooltip: 'Trier par...',
                                onSelected: (val) {
                                  final changed = ref.read(cardSearchControllerProvider.notifier).updateSort(val);
                                  if (changed) _searchCards();
                                },
                                itemBuilder: (context) => [
                                  _buildSortMenuItem(state, 'name', 'Nom'),
                                  _buildSortMenuItem(state, 'cmc', 'Mana (CMC)'),
                                  _buildSortMenuItem(state, 'type', 'Type'),
                                  _buildSortMenuItem(state, 'price_desc', 'Prix (cher \u2192 pas cher)'),
                                  _buildSortMenuItem(state, 'price_asc', 'Prix (pas cher \u2192 cher)'),
                                ],
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => ref.read(cardSearchControllerProvider.notifier).toggleGridView(),
                                child: Icon(state.isGridView ? Icons.grid_view : Icons.view_list, color: AppColors.textSecondary, size: 20),
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
            color: state.sortBy == value ? AppColors.primaryShade800 : AppColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textPrimary)),
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
        style: AppTextStyles.cinzel(fontSize: 16),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: state.activeFilters.setCode != null ? 'Dans: ${state.activeFilters.setCode!.toUpperCase()}...' : 'Nom de la carte...',
          hintStyle: AppTextStyles.subtitle(color: AppColors.textMuted),
          prefixIcon: IconButton(
            icon: Icon(Icons.filter_list, color: hasFilters ? AppColors.primaryShade700 : AppColors.textSecondary),
            onPressed: _openFilterModal,
            tooltip: 'Filtres avances',
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               if (hasFilters)
                IconButton(
                  icon: const Icon(Icons.highlight_off, color: AppColors.error),
                  tooltip: 'Reinitialiser filtres',
                  onPressed: () {
                    _searchController.clear();
                    ref.read(cardSearchControllerProvider.notifier).resetFilters();
                  },
                )
               else if (_searchController.text.isNotEmpty)
                 IconButton(
                   icon: const Icon(Icons.clear, color: AppColors.textMuted),
                   onPressed: () {
                      _searchController.clear();
                      ref.read(cardSearchControllerProvider.notifier).clearSearchResults();
                   },
                 ),

              IconButton(
                icon: const Icon(Icons.help_outline, color: AppColors.textSecondary),
                tooltip: 'Aide syntaxe Scryfall',
                onPressed: () => ScryfallSyntaxHelp.show(context),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textSecondary),
                onPressed: _searchCards,
              ),
            ],
          ),
          filled: true,
          fillColor: AppColors.textOnPrimary.withValues(alpha: 0.55),
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
      return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(state.statusMessage, style: AppTextStyles.subtitle(fontSize: 16), textAlign: TextAlign.center)));
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

  CollectionBadge? _getBadge(CardSearchState state, String scryfallId, String cardName) {
    final normal = state.collectionIndex[scryfallId] ?? 0;
    final foil = state.collectionFoilIndex[scryfallId] ?? 0;
    final inWishlist = state.wishlistCardNames.contains(cardName);
    if (normal == 0 && foil == 0 && !inWishlist) return null;
    return CollectionBadge(normalCount: normal, foilCount: foil, inWishlist: inWishlist);
  }

  Widget _buildListTile(CardSearchState state, ScryfallCard card) {
    final String cardName = card.name;
    final String imageUrl = card.smallImageUrl ?? card.imageUrl;
    final String price = card.prices['eur'] ?? '--';

    final bool inWishlist = state.isCardInWishlist(cardName);
    final bool inCollection = state.isCardInCollection(card.id);
    final badge = _getBadge(state, card.id, cardName);

    return Card(
      color: AppColors.textOnPrimary.withValues(alpha: 0.45),
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0), side: const BorderSide(color: AppColors.borderLight, width: 1)),
      child: InkWell(
        onTap: () => _navigateToDetail(cardName),
        borderRadius: BorderRadius.circular(10.0),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, width: 60, height: 84, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(width: 60, height: 84, color: AppColors.greyShade800))
                    : Container(width: 60, height: 84, color: AppColors.greyShade800, child: const Icon(Icons.image, color: AppColors.textDisabled)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cardName, style: AppTextStyles.bold(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(card.typeLine, style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.overlayDark, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.borderMedium)),
                          child: Text(card.setCode.toUpperCase(), style: const TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text('${card.cmc?.toInt() ?? 0} CMC', style: const TextStyle(color: AppColors.borderFaint, fontSize: 10)),
                        const SizedBox(width: 8),
                        _buildRarityBadge(card.rarity),
                        const Spacer(),
                        Text('$price EUR', style: TextStyle(color: AppColors.primaryShade700, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (badge != null) CollectionBadgeWidget(badge: badge),
                  _buildActionButton(icon: inWishlist ? Icons.star : Icons.star_border, color: inWishlist ? AppColors.info : AppColors.textDisabled, onTap: () => _toggleWishlist(card.id, cardName, inWishlist)),
                  _buildActionButton(icon: inCollection ? Icons.inventory_2 : Icons.inventory_2_outlined, color: inCollection ? AppColors.success : AppColors.textDisabled, onTap: () => _toggleCollection(card.id, cardName, inCollection)),
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
      return Center(child: Text(state.statusMessage, style: AppTextStyles.cinzel(color: AppColors.textSecondary)));
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
        final badge = _getBadge(state, card.id, card.name);

        return GestureDetector(
          onTap: () => _navigateToDetail(card.name),
          child: Card(
            clipBehavior: Clip.antiAlias, color: AppColors.textOnPrimary, elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.borderSubtle, width: 1)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : Container(color: AppColors.greyShade900, child: Center(child: Text(card.name, textAlign: TextAlign.center, style: AppTextStyles.cinzel(color: AppColors.textSecondary, fontSize: 10)))),
                Positioned(bottom: 0, left: 0, right: 0, height: 40, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.9), AppColors.transparent])))),
                Positioned(
                  bottom: 4, left: 4, right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${card.prices['eur'] ?? '-'}EUR", style: TextStyle(color: AppColors.primaryShade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      _buildRarityBadge(card.rarity, small: true),
                    ],
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 4, right: 4,
                    child: CollectionBadgeWidget(badge: badge),
                  ),
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
      case 'common': c = AppColors.textPrimary; break;
      case 'uncommon': c = Colors.blue.shade300; break;
      case 'rare': c = AppColors.amber; break;
      case 'mythic': c = Colors.orange.shade800; break;
      default: c = AppColors.synergyNeutral;
    }
    return Container(
      width: small ? 8 : 12, height: small ? 8 : 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: AppColors.textOnPrimary, width: 1)),
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
      backgroundColor: AppColors.scaffoldBackground,
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
                    child: Text('Choisir une Wishlist', style: AppTextStyles.sectionTitle()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle, color: AppColors.accentGreen),
                    title: Text('Creer une nouvelle liste', style: AppTextStyles.cinzel()),
                    onTap: () async {
                      final name = await _showCreateWishlistDialog();
                      if (name != null && context.mounted) {
                        final updatedLists = await wishlistService.loadWishlists();
                        if (!context.mounted) return;
                        try {
                          final newList = updatedLists.lastWhere((w) => w.name == name);
                          Navigator.pop(context, newList.id);
                        } catch (_) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                  const Divider(color: AppColors.borderMedium),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: wishlists.length,
                      itemBuilder: (context, index) {
                        final list = wishlists[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark_border, color: AppColors.accent),
                          title: Text(list.name, style: const TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text('${list.totalCards} cartes', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Nouvelle Liste', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Nom de la liste'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await wishlistService.createWishlist(controller.text);
                if (c.mounted) Navigator.pop(c, controller.text);
              }
            },
            child: const Text('Creer'),
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
      content: Text(message, style: AppTextStyles.bold(color: AppColors.textOnPrimary)),
      backgroundColor: color,
      duration: const Duration(seconds: 1),
    ));
  }
}
