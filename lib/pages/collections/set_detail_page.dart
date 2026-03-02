// Fichier : lib/pages/collections/set_detail_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../controllers/set_detail_controller.dart';
import '../../models/scryfall_card_model.dart';
import '../../models/scryfall_set_model.dart';
import '../../models/search_filters.dart';
import '../../router/app_router.dart';

class SetDetailPage extends ConsumerStatefulWidget {
  final ScryfallSet set;

  const SetDetailPage({
    super.key,
    required this.set,
  });

  @override
  ConsumerState<SetDetailPage> createState() => _SetDetailPageState();
}

class _SetDetailPageState extends ConsumerState<SetDetailPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Raccourci vers le notifier du controller
  SetDetailController get _ctrl =>
      ref.read(setDetailControllerProvider(widget.set).notifier);

  // --- ACTIONS QUI NECESSITENT LE CONTEXTE UI ---

  Future<void> _addSelectedTo(bool toCollection) async {
    if (toCollection) {
      final result = await _ctrl.addSelectedToCollection();
      if (mounted && result.count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result.count} cartes ajoutees !', style: AppTextStyles.cinzel()),
          backgroundColor: AppColors.success,
        ));
      }
    } else {
      final wishlistId = await _askWishlistDestination();
      if (wishlistId == null) return;
      final result = await _ctrl.addSelectedToWishlist(wishlistId);
      if (mounted && result.count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result.count} cartes ajoutees !', style: AppTextStyles.cinzel()),
          backgroundColor: AppColors.success,
        ));
      }
    }
  }

  Future<void> _removeSelectedFrom(bool fromCollection) async {
    final state = ref.read(setDetailControllerProvider(widget.set));
    final String targetName =
        fromCollection ? 'votre Collection' : 'toutes vos Wishlists';

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => _buildThemedDialog(
        context: c,
        title: 'Retirer des cartes ?',
        content:
            'Vous etes sur le point de retirer ${state.selectedKeys.length} cartes de $targetName.\nCette action est irreversible.',
        icon: Icons.delete_forever,
        iconColor: AppColors.accentRed,
        confirmText: 'RETIRER',
        confirmColor: Colors.red.shade900,
      ),
    );

    if (confirm != true) return;

    final SetDetailActionResult result;
    if (fromCollection) {
      result = await _ctrl.removeSelectedFromCollection();
    } else {
      result = await _ctrl.removeSelectedFromWishlists();
    }

    if (mounted && result.count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${result.count} cartes retirees !', style: AppTextStyles.cinzel()),
        backgroundColor: AppColors.accentRed,
      ));
    }
  }

  Future<String?> _askWishlistDestination() async {
    final wishlists = await _ctrl.getWishlists();
    if (!mounted) return null;
    final String setName = widget.set.name;

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
                top: BorderSide(color: AppColors.primaryShade800, width: 2)),
          ),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Choisir une Wishlist',
                    style: AppTextStyles.bold(fontSize: 20)),
              ),
              const Divider(color: AppColors.borderLight, height: 1),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: AppColors.accentGreen),
                ),
                title: Text('Nouvelle liste : $setName',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                onTap: () async {
                  final newId =
                      await _ctrl.createWishlistAndGetId(setName);
                  if (context.mounted && newId != null) Navigator.pop(context, newId);
                },
              ),
              const Divider(color: AppColors.borderLight),
              Expanded(
                child: ListView.separated(
                  itemCount: wishlists.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.borderLight, height: 1),
                  itemBuilder: (context, index) {
                    final w = wishlists[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 4),
                      leading: const Icon(Icons.bookmark_border,
                          color: AppColors.accent),
                      title: Text(w.name,
                          style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                      subtitle: Text('${w.totalCards} cartes',
                          style: const TextStyle(
                              color: AppColors.textDisabled, fontSize: 12)),
                      onTap: () => Navigator.pop(context, w.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openStats() async {
    final setCollection = await _ctrl.getSetCollectionForStats();
    final state = ref.read(setDetailControllerProvider(widget.set));
    if (!mounted) return;
    context.push(AppRoutes.setStats, extra: {
      'targetSet': widget.set,
      'myCollection': setCollection.cast(),
      'fullSetData': state.allCards,
    });
  }

  // --- MODALE DE FILTRES ---

  void _openFilterModal() {
    // On lit l'etat courant au moment de l'ouverture
    var currentFilters =
        ref.read(setDetailControllerProvider(widget.set)).activeFilters;
    var currentHideOwned =
        ref.read(setDetailControllerProvider(widget.set)).hideOwned;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(
                          color: AppColors.primaryShade800, width: 2)),
                  color: AppColors.scaffoldBackground,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Filtres du Set',
                        style: AppTextStyles.bold(fontSize: 20),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),

                    // --- 1. COULEURS ---
                    Text('Couleurs',
                        style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildManaIconBtn(
                            'W', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'U', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'B', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'R', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'G', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'C', currentFilters, setModalState,
                            onUpdate: (f) => currentFilters = f),
                        _buildManaIconBtn(
                            'M', currentFilters, setModalState,
                            isMulti: true,
                            onUpdate: (f) => currentFilters = f),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- 2. TYPES ---
                    Text('Type de carte',
                        style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Creature',
                        'Instant',
                        'Sorcery',
                        'Artifact',
                        'Enchantment',
                        'Land',
                        'Planeswalker'
                      ].map((type) {
                        final isSelected =
                            currentFilters.cardType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          onSelected: (val) {
                            setModalState(() {
                              currentFilters = currentFilters.copyWith(
                                  cardType: val ? type : null);
                            });
                          },
                          selectedColor: AppColors.primaryShade900,
                          backgroundColor: AppColors.overlayMedium,
                          labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. OPTIONS ---
                    Text("Options d'affichage",
                        style: AppTextStyles.cinzel(color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: currentFilters.rarity,
                            decoration: const InputDecoration(
                                labelText: 'Rarete',
                                filled: true,
                                fillColor: AppColors.overlayMedium),
                            dropdownColor: AppColors.cardBackground,
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text('Toutes')),
                              DropdownMenuItem(
                                  value: 'common',
                                  child: Text('Commune')),
                              DropdownMenuItem(
                                  value: 'uncommon',
                                  child: Text('Unco')),
                              DropdownMenuItem(
                                  value: 'rare', child: Text('Rare')),
                              DropdownMenuItem(
                                  value: 'mythic',
                                  child: Text('Mythique')),
                            ],
                            onChanged: (val) => setModalState(() =>
                                currentFilters =
                                    currentFilters.copyWith(rarity: val)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilterChip(
                            label: const Text('Masquer possedees'),
                            selected: currentHideOwned,
                            onSelected: (val) => setModalState(
                                () => currentHideOwned = val),
                            selectedColor:
                                Colors.green.withValues(alpha: 0.3),
                            checkmarkColor: AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        _ctrl.updateFilters(currentFilters);
                        _ctrl.updateHideOwned(currentHideOwned);
                        _ctrl.applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryShade800,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16)),
                      child: Text('APPLIQUER',
                          style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 16)),
                    )
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setDetailControllerProvider(widget.set));

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.set.name, style: AppTextStyles.cinzel(fontSize: 16)),
            Text(
                '${widget.set.code.toUpperCase()} \u2022 ${state.gridItems.length} items',
                style: GoogleFonts.roboto(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: AppColors.textOnPrimary,
        actions: [
          if (!state.isLoading)
            IconButton(
                icon: const Icon(Icons.pie_chart, color: AppColors.amber),
                tooltip: 'Stats',
                onPressed: _openStats),
          if (state.selectedKeys.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.deselect),
                onPressed: _ctrl.clearSelection)
          else if (!state.isLoading)
            IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: _ctrl.selectAllMissingFiltered),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.textPrimary))
          : Column(
              children: [
                _buildStatsHeader(state),
                _buildControlBar(state),
                Expanded(
                  child: state.gridItems.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.only(
                              left: 8, right: 8, top: 8, bottom: 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.7,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemCount: state.gridItems.length,
                          itemBuilder: (context, index) =>
                              _buildCardTile(state, state.gridItems[index]),
                        ),
                ),
              ],
            ),
      bottomNavigationBar:
          state.selectedKeys.isNotEmpty ? _buildBottomActionAmount(state) : null,
    );
  }

  // --- WIDGETS PURS ---

  Widget _buildControlBar(SetDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.textOnPrimary.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => _ctrl.updateSearchQuery(val),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
                color: state.hasActiveFilters
                    ? AppColors.primaryShade900
                    : AppColors.textPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: AppColors.textSecondary),
              onPressed: _openFilterModal,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: _buildSortMenu(state),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_none, size: 48, color: AppColors.borderMedium),
          const SizedBox(height: 16),
          Text(
            'Ce ne sont pas les cartes que vous recherchez...',
            style: AppTextStyles.subtitle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('\uD83D\uDC4B\uD83E\uDD16',
              style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }

  Widget _buildSortMenu(SetDetailState state) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort, color: AppColors.textSecondary, size: 20),
      color: AppColors.scaffoldBackground,
      onSelected: (val) => _ctrl.updateSort(val),
      itemBuilder: (ctx) => [
        _buildPopupItem('number', 'Numero', Icons.format_list_numbered, state),
        _buildPopupItem('name', 'Nom', Icons.sort_by_alpha, state),
        _buildPopupItem('rarity', 'Rarete', Icons.diamond, state),
        _buildPopupItem('price', 'Prix', Icons.euro, state),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value, String text, IconData icon, SetDetailState state) {
    final bool isSelected = state.sortBy == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              color: isSelected ? AppColors.primary : AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary)),
          if (isSelected) ...[
            const Spacer(),
            Icon(state.sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppColors.primary, size: 14)
          ]
        ],
      ),
    );
  }

  Widget _buildManaIconBtn(
      String code, SearchFilters filters, StateSetter setModalState,
      {bool isMulti = false, required void Function(SearchFilters) onUpdate}) {
    final isSelected = filters.colors.contains(code);

    Widget content;
    if (isMulti) {
      content = Container(
        decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: [Color(0xFFE6D68F), Color(0xFFC7A94E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: Center(
            child: Text('M',
                style: AppTextStyles.bold(color: AppColors.textOnPrimary, fontSize: 16))),
      );
    } else {
      content = SvgPicture.network(
        'https://svgs.scryfall.io/card-symbols/$code.svg',
        placeholderBuilder: (_) =>
            CircleAvatar(backgroundColor: AppColors.synergyNeutral, child: Text(code)),
      );
    }

    return GestureDetector(
      onTap: () {
        setModalState(() {
          final newColors = Set<String>.from(filters.colors);
          if (isSelected) {
            newColors.remove(code);
          } else {
            newColors.add(code);
          }
          onUpdate(filters.copyWith(colors: newColors));
        });
      },
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.4,
        child: Container(
          width: 40,
          height: 40,
          decoration: isSelected
              ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.3), blurRadius: 10)
                ])
              : null,
          child: content,
        ),
      ),
    );
  }

  Widget _buildThemedDialog({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required Color confirmColor,
  }) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: iconColor.withValues(alpha: 0.5), width: 1.5)),
      title: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: AppTextStyles.bold(fontSize: 18))),
        ],
      ),
      content: Text(content,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 15, height: 1.4)),
      actionsPadding: const EdgeInsets.all(16),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler',
                style: AppTextStyles.cinzel(color: AppColors.textMuted))),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: AppColors.textPrimary,
              elevation: 4),
          child: Text(confirmText,
              style: AppTextStyles.bold()),
        ),
      ],
    );
  }

  Widget _buildCardTile(SetDetailState state, SetCardDisplayItem item) {
    final ScryfallCard card = item.card;
    final bool isFoilSlot = item.isFoil;

    final String key = makeKey(card.id, isFoilSlot);
    final bool isOwned = state.ownedKeys.contains(key);
    final bool isSelected = state.selectedKeys.contains(key);
    final bool isWanted = state.wishlistKeys.contains(key);

    return GestureDetector(
      onTap: () => _ctrl.toggleSelection(card.id, isFoilSlot),
      onLongPress: () => context.push(AppRoutes.cardDetail, extra: {'cardName': card.name}),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: isSelected ? 1.0 : (isOwned ? 1.0 : 0.4),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: isSelected
                      ? BorderSide(color: AppColors.primaryShade700, width: 3)
                      : (isOwned
                          ? BorderSide(
                              color: Colors.green.shade800, width: 2)
                          : BorderSide.none)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(card.smallImageUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.image_not_supported))),
                  if (isFoilSlot)
                    Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                            AppColors.transparent,
                            Colors.purple.withValues(alpha: 0.3),
                            AppColors.transparent,
                            Colors.amber.withValues(alpha: 0.3)
                          ],
                              stops: const [
                            0.0,
                            0.4,
                            0.6,
                            1.0
                          ])),
                    ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
                top: 4,
                right: 4,
                child: Container(
                    decoration: const BoxDecoration(
                        color: AppColors.overlayVeryDark, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: AppColors.primary, size: 24))),
          if (isOwned && !isSelected)
            Positioned(
                top: 4,
                left: 4,
                child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.overlayDark, shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2,
                        color: AppColors.success, size: 16))),
          if (isWanted && !isSelected && !isOwned)
            Positioned(
                top: 4,
                right: 4,
                child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppColors.overlayDark, shape: BoxShape.circle),
                    child: Icon(Icons.star,
                        color: Colors.blue.shade400, size: 16))),
          Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.overlayVeryDark,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderMedium)),
                  child: Text(isFoilSlot ? 'FOIL' : 'NORM',
                      style: TextStyle(
                          color:
                              isFoilSlot ? Colors.amberAccent : AppColors.textPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)))),
          Positioned(
              bottom: 4,
              left: 4,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.overlayDark,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('#${card.collectorNumber}',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 10)))),
        ],
      ),
    );
  }

  Widget _buildBottomActionAmount(SetDetailState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C2C2C), Color(0xFF111111)]),
        border: Border(
            top: BorderSide(color: AppColors.primaryShade800, width: 2.0)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.style, color: AppColors.primaryShade800, size: 16),
                const SizedBox(width: 8),
                Text('${state.selectedKeys.length} selectionne(s)',
                    style: AppTextStyles.bold(color: const Color(0xFFE0E0E0), fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.star_border,
                              color: Colors.red.shade300,
                              label: 'Suppr.',
                              isNegative: true,
                              onTap: () => _removeSelectedFrom(false))),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.star,
                              color: AppColors.accent,
                              label: 'Wishlist',
                              onTap: () => _addSelectedTo(false))),
                    ],
                  ),
                ),
                Container(
                    height: 32,
                    width: 1,
                    color: AppColors.borderSubtle,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.inventory_2_outlined,
                              color: Colors.red.shade300,
                              label: 'Suppr.',
                              isNegative: true,
                              onTap: () => _removeSelectedFrom(true))),
                      const SizedBox(width: 4),
                      Expanded(
                          child: _buildActionButton(
                              icon: Icons.inventory_2,
                              color: AppColors.success,
                              label: 'Collect.',
                              onTap: () => _addSelectedTo(true))),
                    ],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onTap,
      bool isNegative = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isNegative ? color.withValues(alpha: 0.1) : color.withValues(alpha: 0.2),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(SetDetailState state) {
    final int missingCount = state.totalMissing;
    final int totalCount = state.totalSetCount;
    final int ownedCount = totalCount - missingCount;
    final double progress = totalCount > 0 ? ownedCount / totalCount : 0.0;
    final String percentage = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border(
            bottom: BorderSide(color: AppColors.textPrimary.withValues(alpha: 0.05))),
        boxShadow: [
          BoxShadow(
              color: AppColors.textOnPrimary.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PROGRESSION',
                      style: AppTextStyles.cinzel(color: AppColors.borderFaint, fontSize: 10).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$ownedCount',
                          style: AppTextStyles.bold(color: AppColors.accentGreen, fontSize: 20)),
                      Text(' / $totalCount',
                          style: AppTextStyles.cinzel(color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(width: 8),
                      Text('$percentage%',
                          style: GoogleFonts.roboto(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  _buildRarityBadge('M', Colors.orange.shade900,
                      state.rarityCounts['mythic'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge('R', AppColors.amber,
                      state.rarityCounts['rare'] ?? 0),
                  const SizedBox(width: 6),
                  _buildRarityBadge('U', Colors.blueGrey,
                      state.rarityCounts['uncommon'] ?? 0),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    width: constraints.maxWidth * progress,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF3B82F6),
                          Color(0xFF10B981)
                        ],
                        stops: [0.0, 0.6, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.accentGreen.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 0,
                            offset: const Offset(0, 0))
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRarityBadge(String letter, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Text(letter,
              style: AppTextStyles.cinzel(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
