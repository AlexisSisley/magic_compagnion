// Fichier : lib/widgets/decks/deck_card_list_tab.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Pour Clipboard
import 'package:go_router/go_router.dart';
import 'package:magic_companion/widgets/cards/versions_selector_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../router/app_router.dart';
import '../../services/deck_service.dart'; // Pour DeckBoard enum

class DeckCardListTab extends StatefulWidget {
  final List<DeckCard> cardList;
  final List<ScryfallCard> fullCardData;
  final List<DeckCard> collection;
  final String? commanderId;
  final String? partnerId;
  
  // Context pour savoir d'où on vient (pour les options "Move to...")
  final DeckBoard currentBoard; 
  
  final Function(DeckCard, int) onUpdateQuantity;
  final Function(DeckCard)? onSetCommander;
  final Function(DeckCard, DeckBoard)? onMoveCard; // Nouveau callback
  final Function(DeckCard, List<String>)? onUpdateTags; // Nouveau callback
  final VoidCallback? onExportToGlobalWishlist;

  final Function(DeckCard)? onToggleFoil;
  final Function(DeckCard, ScryfallCard)? onSwitchVersion;
  final Function(DeckCard, int)? onAddToCollection;
  final Function(DeckCard, int, String?)? onAddToWishlist;

  const DeckCardListTab({
    super.key,
    required this.cardList,
    required this.fullCardData,
    required this.collection,
    this.commanderId,
    this.partnerId,
    this.currentBoard = DeckBoard.main,
    required this.onUpdateQuantity,
    this.onSetCommander,
    this.onMoveCard,
    this.onUpdateTags,
    this.onExportToGlobalWishlist,
    this.onToggleFoil,
    this.onSwitchVersion,
    this.onAddToCollection,
    this.onAddToWishlist,
  });

  @override
  State<DeckCardListTab> createState() => _DeckCardListTabState();
}

class _DeckCardListTabState extends State<DeckCardListTab> {
  double _gridColumns = 1.0; 
  double _lastScale = 1.0;

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.scale > 1.3 && _lastScale <= 1.0) { setState(() { if (_gridColumns > 1) _gridColumns--; _lastScale = details.scale; }); } 
    else if (details.scale < 0.7 && _lastScale >= 1.0) { setState(() { if (_gridColumns < 5) _gridColumns++; _lastScale = details.scale; }); }
  }

  Future<void> _launchURL(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (e) { /* */ }
  }

  void _exportCardmarket() {
    StringBuffer sb = StringBuffer();
    for (var c in widget.cardList) {
      sb.writeln('${c.quantity} ${c.name}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liste copiée ! Ouverture Cardmarket...'), backgroundColor: AppColors.success));
    _launchURL('https://www.cardmarket.com/en/Magic/Wants/MassEntry');
  }

  @override
  @override
  Widget build(BuildContext context) {
    if (widget.cardList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Aucune carte ici.', style: AppTextStyles.subtitle(fontSize: 16)),
            // Bouton spécial si on est dans l'onglet Wishlist
            if (widget.currentBoard == DeckBoard.wishlist)
               const Padding(
                 padding: EdgeInsets.only(top: 16.0),
                 child: Text("Ajoutez ici les cartes trop chères\nvia le menu 'Déplacer vers Wishlist'", textAlign: TextAlign.center, style: TextStyle(color: AppColors.textDisabled)),
               )
          ],
        ),
      );
    }

    final groupedList = _buildGroupedList(widget.cardList);
    final int currentCols = _gridColumns.round();

    return Column(
      children: [
        // Barre d'outils de la liste
        Container(
          color: AppColors.overlayLight,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            children: [
              Text('${widget.cardList.fold(0, (s, c) => s + c.quantity)} cartes', style: AppTextStyles.label(color: AppColors.textMuted)),
              const Spacer(),
              if (widget.currentBoard == DeckBoard.wishlist && widget.onExportToGlobalWishlist != null)
                IconButton(
                  icon: const Icon(Icons.cloud_upload, size: 18, color: AppColors.accentGreen),
                  tooltip: 'Créer une Wishlist Globale (App)',
                  onPressed: widget.onExportToGlobalWishlist,
                ),
              // Bouton Export Cardmarket (visible surtout pour Wishlist/Considering)
              if (widget.currentBoard == DeckBoard.wishlist || widget.currentBoard == DeckBoard.considering)
                IconButton(
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18, color: AppColors.accent),
                  tooltip: 'Export Cardmarket Mass Entry',
                  onPressed: _exportCardmarket,
                ),
              const SizedBox(width: 8),
              const Icon(Icons.view_agenda, size: 16, color: AppColors.textMuted),
              SizedBox(
                width: 100, 
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
                  child: Slider(
                    value: _gridColumns, min: 1, max: 5, divisions: 4, 
                    activeColor: AppColors.primaryShade800, inactiveColor: AppColors.borderMedium,
                    onChanged: (val) => setState(() => _gridColumns = val),
                  ),
                ),
              ),
              const Icon(Icons.grid_view, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),

        Expanded(
          child: GestureDetector(
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: (_) => _lastScale = 1.0,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 90.0, top: 0.0, left: 4.0, right: 4.0),
              itemCount: groupedList.length,
              itemBuilder: (context, index) {
                final group = groupedList[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Text('${group.title} (${group.cards.fold(0, (s, c) => s + c.quantity)})', style: AppTextStyles.sectionTitle()),
                    ),
                    currentCols == 1 
                        ? Column(children: group.cards.map((c) => _buildDraggableItem(c, isGrid: false)).toList())
                        : GridView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: currentCols, childAspectRatio: 0.68, crossAxisSpacing: 6, mainAxisSpacing: 6),
                            itemCount: group.cards.length,
                            itemBuilder: (ctx, i) => _buildDraggableItem(group.cards[i], isGrid: true),
                          ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableItem(DeckCard card, {required bool isGrid}) {
    // On wrap la tuile dans un LongPressDraggable pour permettre le drag vers les onglets
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'card': card, 'sourceBoard': widget.currentBoard},
      feedback: Material(
        color: AppColors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: isGrid ? 100 : 300,
            child: _buildItem(card, isGrid: isGrid), // Visuel pendant le drag
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildItem(card, isGrid: isGrid)),
      child: _buildItem(card, isGrid: isGrid),
    );
  }

  Widget _buildItem(DeckCard card, {required bool isGrid}) {
    final bool isCommander = (widget.commanderId == card.scryfallId || widget.partnerId == card.scryfallId);
    ScryfallCard? scryfallCard;
    scryfallCard = widget.fullCardData.where((sc) => sc.id == card.scryfallId).firstOrNull;
    final bool isInCollection = widget.collection.any((c) => c.scryfallId == card.scryfallId);

    
    if (isGrid) {
      return DeckCardGridTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander, isInCollection: isInCollection,
        onPlus: () => widget.onUpdateQuantity(card, 1),
        onMinus: () => widget.onUpdateQuantity(card, -1),
        onTap: () { if (scryfallCard != null) context.push(AppRoutes.cardDetail, extra: {'cardName': scryfallCard.name}); },
        onLongPress: () => _showCardOptions(card, scryfallCard, isCommander),
      );
    } else {
      return DeckCardTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander, isInCollection: isInCollection,
        onTap: () { if (scryfallCard != null) context.push(AppRoutes.cardDetail, extra: {'cardName': scryfallCard.name}); },
        onMore: () => _showCardOptions(card, scryfallCard, isCommander), // <--- Ouvre la modale
      );
    }
  }

  void _showCardOptions(DeckCard card, ScryfallCard? scryfallCard, bool isAlreadyCommander) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true, // Permet à la modale de prendre la taille nécessaire
      builder: (modalContext) {
        // Variable locale mutable pour tracker la quantite en temps reel
        int currentQuantity = card.quantity;

        return SafeArea(
          // StatefulBuilder permet de mettre à jour l'affichage de la quantité DANS la modale
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  // --- HEADER AVEC GESTION QUANTITÉ ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: Text(card.name, style: AppTextStyles.sectionTitle())),

                        // Contrôles Quantité
                        Container(
                          decoration: BoxDecoration(color: AppColors.overlayDark, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: AppColors.accentRed),
                                onPressed: () {
                                  if (currentQuantity <= 1) {
                                    // Confirmation avant suppression
                                    showDialog(
                                      context: context,
                                      builder: (dialogCtx) => AlertDialog(
                                        backgroundColor: AppColors.scaffoldBackground,
                                        title: const Text('Supprimer la carte ?', style: TextStyle(color: AppColors.textPrimary)),
                                        content: Text('Retirer "${card.name}" de la liste ?', style: const TextStyle(color: AppColors.textSecondary)),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx),
                                            child: const Text('Annuler'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(dialogCtx); // Fermer le dialog
                                              Navigator.pop(context);   // Fermer la modale
                                              widget.onUpdateQuantity(card, -1);
                                            },
                                            child: const Text('Supprimer', style: TextStyle(color: AppColors.accentRed)),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  widget.onUpdateQuantity(card, -1);
                                  setModalState(() {
                                    currentQuantity--;
                                  });
                                },
                              ),
                              Text(
                                '$currentQuantity',
                                style: AppTextStyles.pageTitle(fontSize: 20)
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: AppColors.accentGreen),
                                onPressed: () {
                                  widget.onUpdateQuantity(card, 1);
                                  setModalState(() {
                                    currentQuantity++;
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.borderMedium),
                  
                  // --- ACTIONS ---
                  
                  // 1. CHANGER VERSION
                  if (scryfallCard != null && !card.scryfallId.startsWith('LOCAL:'))
                    ListTile(
                      leading: const Icon(Icons.style, color: AppColors.accent),
                      title: const Text("Changer d'illustration", style: TextStyle(color: AppColors.textPrimary)),
                      onTap: () { Navigator.pop(context); _openVersionSelector(card, scryfallCard); },
                    ),

                  // 2. TOGGLE FOIL
                  if (widget.onToggleFoil != null)
                    ListTile(
                      leading: Icon(Icons.star, color: card.isFoil ? AppColors.amber : AppColors.synergyNeutral),
                      title: Text(card.isFoil ? 'Retirer le Foil' : 'Passer en Foil', style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: Switch(
                        value: card.isFoil, 
                        activeThumbColor: AppColors.amber,
                        onChanged: (val) {
                          widget.onToggleFoil!(card);
                          setModalState(() {}); // Met à jour le switch visuellement
                        }
                      ),
                      onTap: () {
                        widget.onToggleFoil!(card);
                        setModalState(() {});
                      },
                    ),

                  // 3. GESTION TAGS
                  ListTile(
                    leading: const Icon(Icons.label, color: AppColors.accentGreen),
                    title: const Text('Gérer les Tags', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () { Navigator.pop(context); _showTagEditor(card); },
                  ),

                  // 4. DÉPLACEMENT
                  if (widget.currentBoard != DeckBoard.main)
                    ListTile(leading: const Icon(Icons.arrow_upward, color: AppColors.textMuted), title: const Text('Vers Mainboard', style: TextStyle(color: AppColors.textPrimary)), onTap: () { widget.onMoveCard?.call(card, DeckBoard.main); Navigator.pop(context); }),
                  if (widget.currentBoard != DeckBoard.side)
                    ListTile(leading: const Icon(Icons.swap_horiz, color: AppColors.textMuted), title: const Text('Vers Sideboard', style: TextStyle(color: AppColors.textPrimary)), onTap: () { widget.onMoveCard?.call(card, DeckBoard.side); Navigator.pop(context); }),
                  if (widget.currentBoard != DeckBoard.considering)
                    ListTile(leading: const Icon(Icons.question_mark, color: AppColors.textMuted), title: const Text('Vers Considering', style: TextStyle(color: AppColors.textPrimary)), onTap: () { widget.onMoveCard?.call(card, DeckBoard.considering); Navigator.pop(context); }),
                  if (widget.currentBoard != DeckBoard.wishlist)
                    ListTile(leading: const Icon(Icons.shopping_cart, color: AppColors.accentRed), title: const Text('Vers Deck Wishlist (Trop cher)', style: TextStyle(color: AppColors.textPrimary)), onTap: () { widget.onMoveCard?.call(card, DeckBoard.wishlist); Navigator.pop(context); }),

                  // 4b. AJOUT COLLECTION / WISHLIST GLOBALE
                  if (widget.onAddToCollection != null)
                    ListTile(
                      leading: const Icon(Icons.inventory_2, color: AppColors.accentGreen),
                      title: const Text('Ajouter a la Collection', style: TextStyle(color: AppColors.textPrimary)),
                      onTap: () {
                        widget.onAddToCollection!(card, currentQuantity);
                        Navigator.pop(context);
                      },
                    ),
                  if (widget.onAddToWishlist != null)
                    ListTile(
                      leading: const Icon(Icons.favorite, color: AppColors.accentRed),
                      title: const Text('Ajouter a une Wishlist', style: TextStyle(color: AppColors.textPrimary)),
                      onTap: () {
                        widget.onAddToWishlist!(card, currentQuantity, null);
                        Navigator.pop(context);
                      },
                    ),

                  const Divider(color: AppColors.borderMedium),

                  // 5. COMMANDANT
                  if (widget.currentBoard == DeckBoard.main && widget.onSetCommander != null)
                    ListTile(
                      leading: Icon(isAlreadyCommander ? Icons.person_remove : Icons.person_add, color: AppColors.primary),
                      title: Text(isAlreadyCommander ? 'Retirer du statut Commandant' : 'Définir comme Commandant', style: const TextStyle(color: AppColors.textPrimary)),
                      onTap: () { Navigator.pop(context); widget.onSetCommander!(card); },
                    ),
                ],
              );
            }
          ),
        );        
      }
    );
  }

  void _openVersionSelector(DeckCard card, ScryfallCard currentScryfallCard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => VersionsSelectorSheet(
        oracleId: currentScryfallCard.oracleId,
        currentCardId: currentScryfallCard.id,
        onVersionSelected: (newVersion) {
          // Appel du callback parent pour remplacer la carte
          widget.onSwitchVersion?.call(card, newVersion);
        },
      ),
    );
  }

  void _showTagEditor(DeckCard card) {
    // Simple dialogue pour ajouter/retirer des tags
    List<String> tags = List.from(card.tags);
    TextEditingController ctrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.scaffoldBackground,
            title: const Text('Tags', style: TextStyle(color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 4, 
                  children: tags.map((t) => Chip(
                    label: Text(t), 
                    onDeleted: () => setState(() => tags.remove(t))
                  )).toList()
                ),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nouveau tag...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () { if (ctrl.text.isNotEmpty) setState(() => tags.add(ctrl.text)); ctrl.clear(); }
                    )
                  ),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: () { widget.onUpdateTags?.call(card, tags); Navigator.pop(ctx); }, child: const Text('OK'))
            ],
          );
        }
      )
    );
  }

  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = { 'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [] };
    for (final deckCard in cardList) {
      String type = 'Autres';
      final sc = widget.fullCardData.where((s) => s.id == deckCard.scryfallId).firstOrNull;
      type = sc != null ? _getPrimaryType(sc.typeLine) : _getPrimaryType(deckCard.name);
      groupedMap[type]?.add(deckCard);
    }
    List<_GroupedCardList> groupedList = [];
    groupedMap.forEach((title, cards) { if (cards.isNotEmpty) { cards.sort((a, b) => a.name.compareTo(b.name)); groupedList.add(_GroupedCardList(title: title, cards: cards)); } });
    return groupedList;
  }

  String _getPrimaryType(String typeLine) {
    String lower = typeLine.toLowerCase();
    if (lower.contains('land')) return 'Terrains';
    if (lower.contains('creature')) return 'Créatures';
    if (lower.contains('planeswalker')) return 'Planeswalkers';
    if (lower.contains('artifact')) return 'Artefacts';
    if (lower.contains('enchantment')) return 'Enchantements';
    if (lower.contains('instant') || lower.contains('sorcery')) return 'Sorts';
    return 'Autres';
  }
}

class _GroupedCardList { final String title; final List<DeckCard> cards; _GroupedCardList({required this.title, required this.cards}); }
