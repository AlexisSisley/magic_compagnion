// Fichier : lib/pages/decks/deck_detail_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../router/app_routes.dart';
import '../../models/deck_model.dart';
import '../../services/deck_service.dart';
import '../../controllers/card_tag_catalog_controller.dart';
import '../../controllers/deck_detail_controller.dart';

import '../../widgets/decks/deck_stats_tab.dart';
import '../../widgets/decks/deck_suggestions_tab.dart';
import '../../widgets/decks/deck_card_list_tab.dart';
import '../../widgets/decks/deck_financial_sheet.dart';
import '../../widgets/decks/deck_card_picker.dart';
import '../../widgets/decks/deck_commander_header.dart';
import '../../utils/card_tag_edit.dart';
import '../../utils/deck_metrics.dart';
// IMPORT DU NOUVEAU WIDGET
import '../../widgets/decks/deck_visual_share_list.dart';
import '../../widgets/decks/deck_board_selector.dart';
import '../../widgets/decks/deck_info_tab.dart';
import '../../widgets/decks/deck_view_toggles.dart';

class DeckDetailPage extends ConsumerStatefulWidget {
  final Deck deck;
  const DeckDetailPage({super.key, required this.deck});

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _shareKey = GlobalKey();

  /// Board affiché dans l'onglet Liste. Il bascule sur le board visé après un
  /// dépôt, pour que l'utilisateur voie la carte arriver.
  DeckBoard _selectedBoard = DeckBoard.main;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Helper: raccourci vers le provider et le notifier ---
  DeckDetailController get _ctrl =>
      ref.read(deckDetailControllerProvider(widget.deck).notifier);

  // --- UI-ONLY METHODS (dialogs, snackbars, navigation) ---

  /// Ouvre la gestion du catalogue ; au retour, recharge le deck pour que les
  /// tags renommés ou supprimés se reflètent dans les en-têtes.
  Future<void> _manageTags() async {
    await context.push(AppRoutes.cardTags);
    if (!mounted) return;
    await _ctrl.refreshAfterTagChanges();
  }

  Future<void> _handleUpdateQuantity(DeckCard card, int change, DeckBoard board) async {
    final result = await _ctrl.updateQuantity(card, change, board);
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.warning),
      );
    }
  }

  Future<void> _handleMoveCard(DeckCard card, DeckBoard targetBoard, DeckBoard sourceBoard) async {
    final result = await _ctrl.moveCard(card, targetBoard, sourceBoard);
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.warning),
      );
    } else if (result.success && result.message.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), duration: const Duration(milliseconds: 800)),
      );
    }
  }

  Future<void> _handleSetCommander(DeckCard deckCard) async {
    // Check if already a commander -> unset
    if (_ctrl.isCommander(deckCard)) {
      final result = await _ctrl.unsetCommander(deckCard);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
      return;
    }

    // Validate eligibility
    final error = _ctrl.validateCommanderEligibility(deckCard);
    if (error != null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // Ask for slot via dialog
    int? slot = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Definir comme...', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.scaffoldBackground,
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 1),
            child: const Padding(padding: EdgeInsets.all(8.0), child: Text('Commandant Principal', style: TextStyle(color: AppColors.primary))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 2),
            child: const Padding(padding: EdgeInsets.all(8.0), child: Text('Partenaire / Background', style: TextStyle(color: AppColors.accent))),
          ),
        ],
      ),
    );

    if (slot == null) return;

    final result = await _ctrl.setCommanderSlot(deckCard, slot);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message, style: AppTextStyles.text())),
      );
    }
  }

  Future<void> _handleAddToCollection(DeckCard card, int quantity) async {
    final result = await _ctrl.addToCollection(card, quantity);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _handleAddToWishlist(DeckCard card, int quantity, String? wishlistId) async {
    final result = await _ctrl.addToWishlist(card, quantity, wishlistId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _handleExportDeckWishlistToGlobal() async {
    final currentDeckState = ref.read(deckDetailControllerProvider(widget.deck));
    if (currentDeckState.currentDeck.wishlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La Wishlist du deck est vide.')));
      return;
    }

    final textController = TextEditingController(text: 'Achats: ${currentDeckState.currentDeck.name}');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: const Text('Creer une Wishlist Globale', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Cela va creer une nouvelle liste dans l'onglet Wishlist de l'application avec ces cartes.", style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(controller: textController, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Nom de la liste')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(c, textController.text), child: const Text('Creer')),
        ],
      ),
    );

    if (name != null) {
      final result = await _ctrl.exportDeckWishlistToGlobal(name);
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.success),
        );
      }
    }
  }

  // --- VISUAL SHARE ---
  Future<void> _captureAndShare() async {
    final captureState = ref.read(deckDetailControllerProvider(widget.deck));
    if (captureState.fullCardData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donnees des cartes non chargees. Veuillez patienter.')));
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.scaffoldBackground,
          contentPadding: EdgeInsets.zero,
          insetPadding: const EdgeInsets.all(16),
          title: Column(
            children: [
              Text('Apercu avant partage', style: AppTextStyles.sectionTitle()),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Generation du poster en cours...',
                  style: TextStyle(color: Colors.orangeAccent.shade100, fontSize: 11, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: SingleChildScrollView(
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: _shareKey,
                  child: DeckVisualShareList(
                    deck: captureState.currentDeck,
                    fullCardData: captureState.fullCardData,
                    totalPrice: captureState.totalDeckPrice,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.share, color: AppColors.textOnPrimary),
              label: const Text("Partager l'image", style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange),
              onPressed: () async {
                showDialog(
                  context: dialogContext,
                  barrierDismissible: false,
                  builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
                );

                try {
                  await Future.delayed(const Duration(milliseconds: 500));

                  RenderRepaintBoundary boundary = _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                  ui.Image image = await boundary.toImage(pixelRatio: 1.5);

                  ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                  Uint8List pngBytes = byteData!.buffer.asUint8List();

                  final tempDir = await getTemporaryDirectory();
                  final fileName = 'deck_share_${DateTime.now().millisecondsSinceEpoch}.png';
                  final file = await File('${tempDir.path}/$fileName').create();
                  await file.writeAsBytes(pngBytes);

                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);

                  final currentDeck = ref.read(deckDetailControllerProvider(widget.deck)).currentDeck;
                  await SharePlus.instance.share(ShareParams(
                    files: [XFile(file.path)],
                    text: 'Mon deck Commander : ${currentDeck.name}',
                  ));

                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  debugPrint('Erreur capture: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la generation.')));
                }
              },
            ),
          ],
        );
      },
    );
  }

  // --- TEXT SHARES ---

  void _shareFullDeck() {
    final text = _ctrl.generateFullDeckText();
    final deckName = ref.read(deckDetailControllerProvider(widget.deck)).currentDeck.name;
    SharePlus.instance.share(ShareParams(text: text, subject: 'Decklist : $deckName'));
  }

  void _shareConsidering() {
    final text = _ctrl.generateConsideringText();
    if (text == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La liste Considering est vide.')));
      return;
    }
    final deckName = ref.read(deckDetailControllerProvider(widget.deck)).currentDeck.name;
    SharePlus.instance.share(ShareParams(text: text, subject: 'Considering : $deckName'));
  }

  void _shareWishlist() {
    final text = _ctrl.generateWishlistText();
    if (text == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La Wishlist du deck est vide.')));
      return;
    }
    final deckName = ref.read(deckDetailControllerProvider(widget.deck)).currentDeck.name;
    SharePlus.instance.share(ShareParams(text: text, subject: 'Wishlist : $deckName'));
  }

  void _showValidationResults() {
    final results = _ctrl.validateDeckRules();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: results.entries.map((e) => ListTile(
              title: Text(e.key, style: const TextStyle(color: AppColors.textPrimary)),
              trailing: Text(e.value, style: TextStyle(color: e.value.contains('OK') ? AppColors.success : AppColors.error)),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openCardPicker() async {
    final List<Map<String, dynamic>>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => const DeckCardPicker(),
    );
    if (result != null && result.isNotEmpty) {
      await _ctrl.addCardsFromPicker(result);
    }
  }

  void _showFinancialAnalysis() {
    final finState = ref.read(deckDetailControllerProvider(widget.deck));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => DeckFinancialSheet(
        deck: finState.currentDeck,
        fullCardData: finState.fullCardData,
        collection: finState.myCollection,
      ),
    );
  }

  Future<void> _showClearDeckDialog() async {
    final result = await _ctrl.clearDeck();
    if (mounted && result.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message, style: AppTextStyles.text(color: AppColors.accentRed)),
          backgroundColor: AppColors.textOnPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deckState = ref.watch(deckDetailControllerProvider(widget.deck));
    final deck = deckState.currentDeck;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: _openCardPicker),
          PopupMenuButton<String>(
            onSelected: (val) {
               if (val == 'legality') _showValidationResults();
               if (val == 'finance') _showFinancialAnalysis();
               if (val == 'tags') _manageTags();
               if (val == 'share_deck') _shareFullDeck();
               if (val == 'share_considering') _shareConsidering();
               if (val == 'share_wishlist') _shareWishlist();
               if (val == 'share_image') _captureAndShare();
               if (val == 'clear') _showClearDeckDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'finance', child: Row(children: [Icon(Icons.euro, size: 18), SizedBox(width: 8), Text('Finance')])),
              const PopupMenuItem(value: 'legality', child: Row(children: [Icon(Icons.gavel, size: 18), SizedBox(width: 8), Text('Legalite')])),
              const PopupMenuItem(value: 'tags', child: Row(children: [Icon(Icons.label, size: 18), SizedBox(width: 8), Text('Gérer les tags')])),
              const PopupMenuItem(value: 'share_image', child: Row(children: [Icon(Icons.image, size: 18), SizedBox(width: 8), Text('Partager (Image)')])),

              const PopupMenuDivider(),
              const PopupMenuItem(value: 'share_deck', child: Row(children: [Icon(Icons.text_snippet, size: 18, color: AppColors.textSecondary), SizedBox(width: 8), Text('Copier Decklist')])),
              const PopupMenuItem(value: 'share_considering', child: Row(children: [Icon(Icons.question_mark, size: 18, color: AppColors.textSecondary), SizedBox(width: 8), Text('Copier Considering')])),
              const PopupMenuItem(value: 'share_wishlist', child: Row(children: [Icon(Icons.star_border, size: 18, color: AppColors.textSecondary), SizedBox(width: 8), Text('Copier Wishlist')])),
              const PopupMenuDivider(),

              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete, color: AppColors.error, size: 18), SizedBox(width: 8), Text('Vider', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: deckState.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.textPrimary))
          // Le bandeau défile avec la liste : sur un téléphone, il laisse
          // sa place aux cartes dès qu'on descend, et revient en haut de
          // liste. Les listes des onglets n'ont pas de ScrollController à
          // elles : elles prennent celui que NestedScrollView leur fournit.
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: DeckCommanderHeader(
                    deck: deck,
                    fullCardData: deckState.fullCardData,
                    cardCount: deckState.mainCount,
                    averageManaValue: averageManaValue(deck.mainboard, deckState.fullCardData),
                    powerLevel: deckState.powerLevel,
                    totalPrice: deckState.totalDeckPrice,
                  ),
                ),
              ],
              // La TabBar ouvre le corps plutôt qu'un en-tête épinglé : un
              // en-tête épinglé recouvrirait le haut des onglets (puces de
              // board comprises) sans SliverOverlapInjector dans chacun. Le
              // corps, lui, reste entier à l'écran une fois le bandeau sorti.
              body: Column(
                children: [
                  // Sous le bandeau, comme sur la maquette : le nom du deck
                  // passe avant les vues.
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildListTab(deckState),
                        DeckStatsTab(mainboard: deck.mainboard, cardData: deckState.fullCardData),
                        DeckSuggestionsTab(deck: deck),
                        DeckInfoTab(tokens: deckState.tokens, report: _ctrl.generateLegalityReport()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Quatre onglets de largeur égale. Le primary du thème est lilas : l'or de
  /// l'onglet actif et de son soulignement est posé explicitement.
  Widget _buildTabBar() {
    return Container(
      color: AppColors.textOnPrimary,
      child: TabBar(
        controller: _tabController,
        isScrollable: false,
        indicator: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primary, width: 2)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.transparent,
        labelColor: AppColors.primary,
        labelStyle: AppTextStyles.bold(),
        unselectedLabelColor: AppColors.textMuted,
        unselectedLabelStyle: AppTextStyles.text(),
        // Marges réduites : « Suggestions » doit tenir en entier sur un
        // téléphone de 360 px, où chaque onglet ne reçoit qu'un quart.
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        tabs: const [
          Tab(text: 'Liste'),
          Tab(text: 'Stats'),
          Tab(text: 'Suggestions'),
          Tab(text: 'Infos'),
        ],
      ),
    );
  }

  /// Onglet Liste : le sélecteur de board, avec les interrupteurs
  /// d'affichage au bout de la même rangée, puis la liste du board choisi.
  /// La rangée reste au-dessus de la liste et ne défile pas avec elle : c'est
  /// la cible du glisser-déposer, elle doit rester visible pendant un glisser.
  /// Une seule liste, câblée sur `_selectedBoard` : chaque callback vise le
  /// board affiché.
  Widget _buildListTab(DeckDetailState deckState) {
    final deck = deckState.currentDeck;
    final board = _selectedBoard;
    final cards = switch (board) {
      DeckBoard.main => deck.mainboard,
      DeckBoard.side => deck.sideboard,
      DeckBoard.considering => deck.considering,
      DeckBoard.wishlist => deck.wishlist,
    };
    final isMain = board == DeckBoard.main;
    final tagCatalog = ref.watch(cardTagCatalogProvider);
    return Column(
      children: [
        DeckBoardSelector(
          selected: board,
          counts: {
            DeckBoard.main: deckState.mainCount,
            DeckBoard.side: deckState.sideCount,
            DeckBoard.considering: deckState.consCount,
            DeckBoard.wishlist: deckState.wishCount,
          },
          onSelect: (b) => setState(() => _selectedBoard = b),
          onDrop: (card, from, to) {
            _handleMoveCard(card, to, from);
            setState(() => _selectedBoard = to);
          },
          trailing: [
            DeckViewToggles(
              prefs: deckState.viewPrefs,
              onGrouping: _ctrl.setGrouping,
              onLayout: _ctrl.setLayout,
            ),
          ],
        ),
        Expanded(
          child: DeckCardListTab(
            // Une clé par board : changer de board repart d'un défilement en
            // haut de liste, comme le faisait un onglet distinct.
            key: ValueKey(board),
            cardList: cards,
            fullCardData: deckState.fullCardData,
            collection: deckState.myCollection,
            // Commandant et « Définir comme commandant » n'existent que sur le main.
            commanderId: isMain ? deck.commanderScryfallId : null,
            partnerId: isMain ? deck.commanderSecondaryScryfallId : null,
            currentBoard: board,
            onUpdateQuantity: (c, q) => _handleUpdateQuantity(c, q, board),
            onMoveCard: (c, target) => _handleMoveCard(c, target, board),
            onSetCommander: isMain ? _handleSetCommander : null,
            onExportToGlobalWishlist:
                board == DeckBoard.wishlist ? _handleExportDeckWishlistToGlobal : null,
            onToggleFoil: (c) => _ctrl.toggleFoil(c, board),
            onSwitchVersion: (c, newV) => _ctrl.switchVersion(c, newV, board),
            onAddToCollection: (c, qty) => _handleAddToCollection(c, qty),
            onAddToWishlist: (c, qty, wId) => _handleAddToWishlist(c, qty, wId),
            viewPrefs: deckState.viewPrefs,
            tagCatalog: tagCatalog,
            deckTags: deckOnlyTags(deck, tagCatalog),
            onSetTags: (c, tags) => _ctrl.setCardTags(c, board, tags),
            onResetTags: (c) => _ctrl.resetCardTags(c, board),
          ),
        ),
      ],
    );
  }
}
