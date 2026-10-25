// Fichier : lib/widgets/decks/deck_card_list_tab.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/services.dart'; // Pour Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/widgets/cards/versions_selector_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:magic_companion/widgets/decks/card_tags_sheet.dart';
import 'package:magic_companion/widgets/decks/deck_card_title.dart';
import '../../models/card_tag.dart';
import '../../models/deck_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../providers/card_display_provider.dart';
import '../../providers/preferred_language_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/deck_service.dart'; // Pour DeckBoard enum
import '../../services/deck_view_prefs.dart';
import '../../router/card_detail_route.dart';
import '../../utils/deck_metrics.dart';

class DeckCardListTab extends ConsumerStatefulWidget {
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
  final VoidCallback? onExportToGlobalWishlist;

  final Function(DeckCard)? onToggleFoil;
  final Function(DeckCard, ScryfallCard)? onSwitchVersion;
  final Function(DeckCard, int)? onAddToCollection;
  final Function(DeckCard, int, String?)? onAddToWishlist;

  /// Affichage mémorisé du deck (regroupement, grille ou liste) et les
  /// callbacks qui corrigent les tags d'une carte : la page les câble au
  /// contrôleur, l'onglet ne garde aucun état d'affichage. Les interrupteurs
  /// qui changent l'affichage vivent dans la rangée des puces de board
  /// (DeckViewToggles), pas ici.
  final DeckViewPrefs viewPrefs;
  final void Function(DeckCard, List<String>) onSetTags;
  final ValueChanged<DeckCard> onResetTags;

  /// Catalogue des tags universels, dans son ordre : il ordonne les sections
  /// du regroupement par tag.
  final List<CardTagDef> tagCatalog;

  /// Tags du deck absents du catalogue, proposés par la feuille d'édition
  /// (la page connaît les quatre boards, pas l'onglet).
  final List<String> deckTags;

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
    this.onExportToGlobalWishlist,
    this.onToggleFoil,
    this.onSwitchVersion,
    this.onAddToCollection,
    this.onAddToWishlist,
    required this.viewPrefs,
    required this.onSetTags,
    required this.onResetTags,
    required this.tagCatalog,
    required this.deckTags,
  });

  @override
  ConsumerState<DeckCardListTab> createState() => _DeckCardListTabState();
}

class _DeckCardListTabState extends ConsumerState<DeckCardListTab> {
  /// Projection d'affichage (langue preferee) par carte possedee, indexee
  /// par scryfallId. Resolue en une seule passe au chargement du deck --
  /// jamais une requete par ligne de liste, donc jamais de spinner par nom
  /// de carte (regle d'affichage n°1). Tant qu'une entree est absente de
  /// cette map, la tuile correspondante affiche `card.name` (le tirage
  /// possede) sans attendre : le remplacement par la traduction, quand elle
  /// arrive, est silencieux.
  Map<String, CardDisplay> _displays = {};

  /// Jeton de sequence pour `_loadDisplays` : incremente a chaque lancement,
  /// capture en debut d'appel. `didUpdateWidget` peut relancer une
  /// resolution avant que la precedente n'ait fini (deck modifie deux fois
  /// rapidement, import qui rafraichit la liste...) ; rien ne garantit
  /// l'ordre de resolution des Future. Au moment de publier, un appel ne
  /// pose son resultat que si son jeton est toujours le plus recent -- le
  /// dernier lancement gagne, jamais un retour tardif d'un appel perime.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _loadDisplays();
  }

  @override
  void didUpdateWidget(covariant DeckCardListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_cardsSignature(oldWidget.cardList) != _cardsSignature(widget.cardList)) {
      _loadDisplays();
    }
  }

  String _cardsSignature(List<DeckCard> cards) =>
      cards.map((c) => c.scryfallId).join('|');

  /// Resout la projection d'affichage de chaque carte possedee du deck, en
  /// une seule passe. Le tirage possede (`DbCardPrint`) est lu depuis le
  /// cache local ; s'il est absent (carte non encore mise en cache, entree
  /// `LOCAL:` sans tirage Scryfall...) la carte est simplement absente de la
  /// map et la tuile continue d'afficher `card.name`.
  Future<void> _loadDisplays() async {
    final seq = ++_loadSeq;
    final db = ref.read(appDatabaseProvider);
    final preferredLang = await readPreferredLanguage();

    final Map<String, CardDisplay> resolved = {};
    for (final card in widget.cardList) {
      if (resolved.containsKey(card.scryfallId)) continue;
      final owned = await db.getCardPrint(card.scryfallId);
      if (owned == null) continue;
      resolved[card.scryfallId] = await resolveDisplay(
        db: db,
        owned: owned,
        preferredLang: preferredLang,
      );
    }

    // Le dernier lancement gagne : un appel demarre avant mais qui repond
    // apres ne publie pas son resultat s'il n'est plus le plus recent.
    if (!mounted || seq != _loadSeq) return;
    setState(() => _displays = resolved);
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

    final byTag = widget.viewPrefs.grouping == DeckGrouping.tag;
    final groupedList = byTag
        ? _buildTagList(widget.cardList, widget.tagCatalog)
        : _buildGroupedList(widget.cardList);
    final isGrid = widget.viewPrefs.layout == DeckLayout.grid;

    final shopping = widget.currentBoard == DeckBoard.wishlist ||
        widget.currentBoard == DeckBoard.considering;

    return Column(
      children: [
        // Ligne fine des achats, seulement sur Wishlist et Considering : sur
        // Main et Side, les interrupteurs d'affichage sont montés dans la
        // rangée des puces et la liste commence tout de suite.
        if (shopping)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentBoard == DeckBoard.wishlist && widget.onExportToGlobalWishlist != null)
                  IconButton(
                    icon: const Icon(Icons.cloud_upload, size: 18, color: AppColors.accentGreen),
                    tooltip: 'Créer une Wishlist Globale (App)',
                    onPressed: widget.onExportToGlobalWishlist,
                  ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart_checkout, size: 18, color: AppColors.accent),
                  tooltip: 'Export Cardmarket Mass Entry',
                  onPressed: _exportCardmarket,
                ),
              ],
            ),
          ),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Le padding horizontal du ListView (4 + 4) est déjà retiré de
              // la largeur utile : les colonnes se calent sur ce que la grille
              // reçoit vraiment.
              final cols = deckCardGridColumns(constraints.maxWidth - 8);
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 90.0, top: 0.0, left: 4.0, right: 4.0),
                itemCount: groupedList.length,
                itemBuilder: (context, index) {
                  final group = groupedList[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(group, byTag),
                      isGrid
                          ? GridView.builder(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, childAspectRatio: 0.8, crossAxisSpacing: 6, mainAxisSpacing: 6),
                              itemCount: group.cards.length,
                              itemBuilder: (ctx, i) => _buildDraggableItem(group.cards[i], isGrid: true),
                            )
                          : Column(children: group.cards.map((c) => _buildDraggableItem(c, isGrid: false)).toList()),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// En mode tag, l'en-tête dit le tag principal et le coût moyen de la
  /// section ; en mode type, il garde son titre d'origine.
  Widget _buildSectionHeader(_GroupedCardList group, bool byTag) {
    final count = group.cards.fold(0, (s, c) => s + c.quantity);
    if (!byTag) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        child: Text('${group.title} ($count)', style: AppTextStyles.sectionTitle()),
      );
    }
    final avg = averageManaValue(group.cards, widget.fullCardData);
    final detail = avg > 0
        ? '$count · CMC moyen ${avg.toStringAsFixed(1).replaceAll('.', ',')}'
        : '$count';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            key: const ValueKey('tag-header-dot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: group.isUntagged
                  ? AppColors.textMuted
                  : cardTagColor(group.title, widget.tagCatalog),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            group.title.toUpperCase(),
            style: AppTextStyles.sectionTitle().copyWith(color: AppColors.primary, letterSpacing: 1.2),
          ),
          const SizedBox(width: 8),
          Text(detail, style: AppTextStyles.label(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(height: 1, color: AppColors.borderMedium)),
        ],
      ),
    );
  }

  /// Déplacement net du glisser en cours, du départ au relâchement. Un appui
  /// long relâché sans bouger reste un appui long : il ouvre le menu de la
  /// carte. Net et non cumulé : le tremblement d'un doigt qui tient appuyé
  /// s'annule au lieu de s'additionner.
  Offset _dragNet = Offset.zero;

  Widget _buildDraggableItem(DeckCard card, {required bool isGrid}) {
    // La tuile n'a pas d'appui long à elle : le LongPressDraggable porte les
    // deux gestes. Sinon la tuile gagnait l'arène, son menu s'ouvrait et la
    // carte ne pouvait jamais être déposée sur un autre board.
    return LongPressDraggable<Map<String, dynamic>>(
      data: {'card': card, 'sourceBoard': widget.currentBoard},
      onDragStarted: () => _dragNet = Offset.zero,
      onDragUpdate: (details) => _dragNet += details.delta,
      onDragEnd: (details) {
        if (!details.wasAccepted && _dragNet.distance < kTouchSlop && mounted) {
          _openOptions(card);
        }
      },
      feedback: Material(
        color: AppColors.transparent,
        child: Opacity(
          opacity: 0.8,
          // La vignette remplit sa cellule : dans l'overlay, sans cellule, elle
          // a besoin d'une hauteur, au même ratio que la grille (0,8).
          child: SizedBox(
            width: isGrid ? 100 : 300,
            height: isGrid ? 125 : null,
            child: _buildItem(card, isGrid: isGrid), // Visuel pendant le drag
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildItem(card, isGrid: isGrid)),
      // Le draggable n'expose aucune action d'accessibilité : sans celle-ci,
      // un lecteur d'écran ne pourrait plus ouvrir le menu de la vignette, qui
      // n'a pas de bouton « ⋮ ». Une action sémantique n'ajoute aucun
      // reconnaisseur, donc ne rouvre pas le conflit d'arène.
      child: Semantics(
        onLongPress: () => _openOptions(card),
        child: _buildItem(card, isGrid: isGrid),
      ),
    );
  }

  void _openOptions(DeckCard card) {
    final scryfallCard = widget.fullCardData.where((sc) => sc.id == card.scryfallId).firstOrNull;
    final isCommander = widget.commanderId == card.scryfallId || widget.partnerId == card.scryfallId;
    _showCardOptions(card, scryfallCard, isCommander);
  }

  Widget _buildItem(DeckCard card, {required bool isGrid}) {
    final bool isCommander = (widget.commanderId == card.scryfallId || widget.partnerId == card.scryfallId);
    ScryfallCard? scryfallCard;
    scryfallCard = widget.fullCardData.where((sc) => sc.id == card.scryfallId).firstOrNull;
    final bool isInCollection = widget.collection.any((c) => c.scryfallId == card.scryfallId);
    final CardDisplay? display = _displays[card.scryfallId];

    if (isGrid) {
      return DeckCardGridTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander, isInCollection: isInCollection,
        display: display,
        tagCatalog: widget.tagCatalog,
        showPrimaryTag: widget.viewPrefs.grouping != DeckGrouping.tag,
        onPlus: () => widget.onUpdateQuantity(card, 1),
        onMinus: () => widget.onUpdateQuantity(card, -1),
        onTap: () { if (scryfallCard != null) pushCardDetail(context, cardName: scryfallCard.name); },
      );
    } else {
      return DeckCardTile(
        card: card, scryfallCard: scryfallCard, isCommander: isCommander, isInCollection: isInCollection,
        display: display,
        tagCatalog: widget.tagCatalog,
        showPrimaryTag: widget.viewPrefs.grouping != DeckGrouping.tag,
        onTap: () { if (scryfallCard != null) pushCardDetail(context, cardName: scryfallCard.name); },
        onMore: () => _showCardOptions(card, scryfallCard, isCommander), // <--- Ouvre la modale
        longPressOpensMenu: false,
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
              return SingleChildScrollView(
                child: Column(
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

                  // 3. TAGS
                  ListTile(
                    leading: const Icon(Icons.label, color: AppColors.accentGreen),
                    title: const Text('Tags…', style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      _openTagsSheet(card, scryfallCard);
                    },
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
              ));
            }
          ),
        );        
      }
    );
  }

  void _openTagsSheet(DeckCard card, ScryfallCard? scryfallCard) {
    showCardTagsSheet(
      context,
      card: card,
      deckTags: widget.deckTags,
      canSuggest: scryfallCard != null && !card.scryfallId.startsWith('LOCAL:'),
      onSave: (tags) => widget.onSetTags(card, tags),
      onReset: () => widget.onResetTags(card),
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

  /// Dans chaque section, par type comme par tag, les cartes suivent la
  /// courbe de mana : mana value croissante, puis nom (voir sortByManaValue).
  List<_GroupedCardList> _buildGroupedList(List<DeckCard> cardList) {
    Map<String, List<DeckCard>> groupedMap = { 'Créatures': [], 'Planeswalkers': [], 'Sorts': [], 'Artefacts': [], 'Enchantements': [], 'Terrains': [], 'Autres': [] };
    for (final deckCard in cardList) {
      String type = 'Autres';
      final sc = widget.fullCardData.where((s) => s.id == deckCard.scryfallId).firstOrNull;
      type = sc != null ? _getPrimaryType(sc.typeLine) : _getPrimaryType(deckCard.name);
      groupedMap[type]?.add(deckCard);
    }
    List<_GroupedCardList> groupedList = [];
    groupedMap.forEach((title, cards) { if (cards.isNotEmpty) { groupedList.add(_GroupedCardList(title: title, cards: sortByManaValue(cards, widget.fullCardData))); } });
    return groupedList;
  }

  /// Une section par tag principal : d'abord les tags du catalogue, dans son
  /// ordre et son orthographe, puis les tags propres au deck par ordre
  /// alphabétique, et « Sans tag » en dernier. L'égalité des tags est
  /// insensible à la casse.
  List<_GroupedCardList> _buildTagList(
      List<DeckCard> cardList, List<CardTagDef> catalog) {
    final byKey = <String, List<DeckCard>>{};
    final titles = <String, String>{};
    final untagged = <DeckCard>[];
    for (final c in cardList) {
      final tag = c.primaryTag;
      if (tag == null) {
        untagged.add(c);
        continue;
      }
      final key = tag.toLowerCase();
      titles.putIfAbsent(key, () => tag);
      byKey.putIfAbsent(key, () => []).add(c);
    }
    _GroupedCardList section(String title, List<DeckCard> cards,
            {bool isUntagged = false}) =>
        _GroupedCardList(
            title: title,
            cards: sortByManaValue(cards, widget.fullCardData),
            isUntagged: isUntagged);
    final catalogKeys = catalog.map((t) => t.name.toLowerCase()).toSet();
    final deckKeys = byKey.keys.where((k) => !catalogKeys.contains(k)).toList()
      ..sort();
    return [
      for (final def in catalog)
        if (byKey[def.name.toLowerCase()] case final cards?)
          section(def.name, cards),
      for (final key in deckKeys) section(titles[key]!, byKey[key]!),
      if (untagged.isNotEmpty) section('Sans tag', untagged, isUntagged: true),
    ];
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

class _GroupedCardList {
  final String title;
  final List<DeckCard> cards;
  /// Section des cartes sans tag (et non un tag utilisateur du même nom).
  final bool isUntagged;
  _GroupedCardList({required this.title, required this.cards, this.isUntagged = false});
}
