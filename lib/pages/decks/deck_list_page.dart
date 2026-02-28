// Fichier : lib/pages/decks/deck_list_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/deck_list_controller.dart';
import '../../models/deck_model.dart';
import '../../router/app_router.dart';
import '../../services/scryfall_api.dart';
import '../../widgets/cards/scryfall_image.dart';

class DeckListPage extends ConsumerStatefulWidget {
  const DeckListPage({super.key});

  @override
  ConsumerState<DeckListPage> createState() => _DeckListPageState();
}

class _DeckListPageState extends ConsumerState<DeckListPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DeckListController get _controller => ref.read(deckListControllerProvider.notifier);

  // --- ACTIONS (UI-only: dialogs, navigation, snackbars) ---

  Future<void> _deleteDeck(String deckId) async {
    await _controller.deleteDeck(deckId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Text("La Force a effacé ce deck.", style: GoogleFonts.cinzel(color:Colors.cyanAccent,fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.black,
          duration: const Duration(seconds: 2),
        )
      );
    }
  }

  Future<void> _showCreateDeckDialog() async {
    final controller = TextEditingController();
    final String? name = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Nouveau Deck', style: GoogleFonts.cinzel(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Nom du deck...', filled: true, fillColor: Colors.black45),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _controller.createNewDeck(name);
    }
  }

  Future<void> _showImportDeckDialog() async {
    final nameController = TextEditingController();
    final listController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withOpacity(0.95),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Importer un Deck', style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 16),
                TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nom du nouveau deck', filled: true, fillColor: Colors.black54)),
                const SizedBox(height: 12),
                TextField(controller: listController, style: const TextStyle(color: Colors.white), maxLines: 8, decoration: const InputDecoration(hintText: 'Collez votre decklist ici...', filled: true, fillColor: Colors.black54)),
                const SizedBox(height: 12),
                Consumer(builder: (context, ref, _) {
                  final isImporting = ref.watch(deckListControllerProvider).isImporting;
                  return ElevatedButton(
                    onPressed: () {
                      final String deckName = nameController.text.trim();
                      final String deckList = listController.text.trim();
                      // --- EASTER EGG CHECK ---
                      final (resolvedName, resolvedList) = _controller.resolveEasterEgg(deckName, deckList);
                      if (resolvedName != deckName || (deckName.isNotEmpty && deckList.isNotEmpty)) {
                        Navigator.pop(context);
                        _controller.importDeck(resolvedName, resolvedList);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800),
                    child: isImporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Importer'),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deckListControllerProvider);

    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text('Mes Decks', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
                centerTitle: false,
                pinned: true,
                floating: true,
                snap: true,
                expandedHeight: 120.0,
                backgroundColor: Colors.black,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.file_upload_outlined, color: Colors.white),
                    tooltip: "Importer une liste",
                    onPressed: _showImportDeckDialog
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(70),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF1A1A1A),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Rechercher un deck...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.white54),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => _controller.updateSearchQuery(val),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : CustomScrollView(
                slivers: [
                  // Filtres
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildIdentityFilterChip(state),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: state.selectedFormat,
                              items: ['Tous', 'Commander', 'Standard'],
                              onSelected: (v) => _controller.updateFormat(v),
                            ),
                            const SizedBox(width: 8),
                            _buildChoiceChip(
                              label: _controller.getSortLabel(state.selectedSort),
                              items: ['Nom (A-Z)', 'Prix (Décroissant)', 'Prix (Croissant)'],
                              onSelected: (label) {
                                String code = 'name';
                                if(label.contains('Décroissant')) code = 'price_desc';
                                else if(label.contains('Croissant')) code = 'price_asc';
                                _controller.updateSort(code);
                              }
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Liste
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDeckCard(state.filteredDecks[index], state),
                        childCount: state.filteredDecks.length,
                      ),
                    ),
                  ),
                ],
              ),
        ),

        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _showCreateDeckDialog,
            backgroundColor: Colors.yellow.shade800,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('Nouveau Deck', style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS ---

  Widget _buildIdentityFilterChip(DeckListState state) {
    final bool isActive = state.selectedIdentityName != null;
    return GestureDetector(
      onTap: _openIdentityFilterModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow.shade900 : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.yellow.shade700 : Colors.white12),
        ),
        child: Row(
          children: [
            if (state.selectedIdentityColors != null && state.selectedIdentityColors!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  children: state.selectedIdentityColors!.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: _getManaIcon(c, size: 14),
                  )).toList(),
                ),
              ),
            Text(
              state.selectedIdentityName ?? "Couleurs",
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: isActive ? Colors.white : Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip({required String label, required List<String> items, required Function(String) onSelected}) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (ctx) => items.map((i) => PopupMenuItem(value: i, child: Text(i))).toList(),
      color: const Color(0xFF2A2A2A),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  void _openIdentityFilterModal() {
    final currentState = ref.read(deckListControllerProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Identité Couleur", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (currentState.selectedIdentityName != null)
                        TextButton(
                          onPressed: () {
                            _controller.clearIdentityFilter();
                            Navigator.pop(context);
                          },
                          child: const Text("Effacer", style: TextStyle(color: Colors.redAccent))
                        )
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: DeckListController.colorFamilies.entries.map((familyEntry) {
                      return ExpansionTile(
                        title: Text(familyEntry.key, style: GoogleFonts.cinzel(color: Colors.yellow.shade800, fontWeight: FontWeight.bold)),
                        iconColor: Colors.yellow.shade800,
                        collapsedIconColor: Colors.white54,
                        initiallyExpanded: true,
                        children: familyEntry.value.entries.map((colorEntry) {
                          final name = colorEntry.key;
                          final colors = colorEntry.value;
                          final isSelected = currentState.selectedIdentityName == name;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: Colors.yellow.shade900.withOpacity(0.2),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            title: Row(
                              children: [
                                ...colors.map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 4.0),
                                  child: _getManaIcon(c, size: 20),
                                )),
                                if(colors.isEmpty) _getManaIcon('C', size: 20),
                                const SizedBox(width: 12),
                                Text(name, style: TextStyle(color: isSelected ? Colors.yellow : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.yellow) : null,
                            onTap: () {
                              _controller.updateIdentityFilter(name, colors);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildDeckCard(Deck deck, DeckListState state) {
    final bool isCommander = deck.commanderScryfallId != null;
    final int cardCount = deck.mainboard.fold(0, (s, c) => s + c.quantity);
    final double totalPrice = state.deckPrices[deck.id] ?? 0.0;

    return Dismissible(
      key: Key(deck.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text("USE THE FORCE",style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold,fontSize: 16, letterSpacing: 1.5)),
          const SizedBox(width: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.back_hand, color: Colors.white, size: 30),
              Icon(Icons.flash_on, color: Colors.blueAccent.shade100, size: 40),
            ],
          ),
        ]),
      ),
      confirmDismiss: (d) => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Supprimer ?", style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(onPressed: ()=>Navigator.pop(c,false),child: const Text("Non")),
            TextButton(onPressed: ()=>Navigator.pop(c,true),child: const Text("Oui"))
          ]
        )
      ),
      onDismissed: (_) {
        _deleteDeck(deck.id);
      },
      child: Card(
        color: Colors.black.withOpacity(0.8),
        margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: isCommander ? Colors.yellow.shade800.withOpacity(0.6) : Colors.white12,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () async {
            await context.push(AppRoutes.deckDetail, extra: deck);
            _controller.loadDecks();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isCommander)
                      ScryfallImage(
                        imageUrl: ScryfallApi.artCropRedirectUrl(deck.commanderScryfallId!),
                        width: 50, height: 50,
                        borderRadius: BorderRadius.circular(20),
                        errorWidget: Icon(Icons.shield_outlined, color: Colors.yellow.shade700, size: 28),
                      )
                    else
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(25)),
                        child: Icon(Icons.style, color: Colors.white54, size: 24),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        deck.name,
                        style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (deck.colors.isNotEmpty)
                      Row(
                        children: deck.colors.map((c) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _getManaIcon(c, size: 16),
                        )).toList(),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCommander ? Colors.yellow.shade900.withOpacity(0.3) : Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCommander ? 'COMMANDER' : 'STANDARD',
                        style: GoogleFonts.cinzel(
                          color: isCommander ? Colors.yellow.shade200 : Colors.white70,
                          fontSize: 10, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('$cardCount cartes', style: GoogleFonts.cinzel(color: Colors.amberAccent, fontSize: 12)),
                    const SizedBox(width: 12),
                    Text(
                        " ≈ ${totalPrice.toStringAsFixed(0)} €",
                        style: GoogleFonts.roboto(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _getManaIcon(String symbol, {double size = 20}) {
    final url = 'https://svgs.scryfall.io/card-symbols/$symbol.svg';
    return SvgPicture.network(
      url, height: size, width: size,
      placeholderBuilder: (_) => Text(symbol, style: TextStyle(color: Colors.white, fontSize: size)),
    );
  }
}
