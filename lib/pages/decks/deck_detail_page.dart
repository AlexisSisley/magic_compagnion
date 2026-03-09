// Fichier : lib/pages/decks/deck_detail_page.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/deck_model.dart';
import '../../services/deck_service.dart';
import '../../controllers/deck_detail_controller.dart';

import '../../widgets/decks/deck_stats_tab.dart';
import '../../widgets/decks/deck_suggestions_tab.dart';
import '../../widgets/decks/deck_card_list_tab.dart';
import '../../widgets/decks/deck_financial_sheet.dart';
import '../../widgets/decks/deck_card_picker.dart';
// IMPORT DU NOUVEAU WIDGET
import '../../widgets/decks/deck_visual_share_list.dart';
import '../../widgets/decks/deck_tokens_tab.dart';
import '../../widgets/decks/deck_legality_tab.dart';

class DeckDetailPage extends ConsumerStatefulWidget {
  final Deck deck;
  const DeckDetailPage({super.key, required this.deck});

  @override
  ConsumerState<DeckDetailPage> createState() => _DeckDetailPageState();
}

class _DeckDetailPageState extends ConsumerState<DeckDetailPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
        SnackBar(content: Text(result.message, style: AppTextStyles.cinzel())),
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
              Text('Apercu avant partage', style: AppTextStyles.cinzel()),
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
          content: Text(result.message, style: AppTextStyles.cinzel(color: AppColors.accentRed)),
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
        toolbarHeight: 75,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(deck.name, style: AppTextStyles.appBarTitle()),
            Text('${deckState.mainCount} cartes \u2022 ${deck.format}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        backgroundColor: AppColors.textOnPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            color: AppColors.textOnPrimary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.warning, width: 1)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.transparent,
              labelColor: AppColors.textPrimary,
              labelStyle: AppTextStyles.bold(),
              unselectedLabelColor: AppColors.textMuted,
              unselectedLabelStyle: AppTextStyles.cinzel(),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              tabs: [
                _buildDragTargetTab(DeckBoard.main, 'Main (${deckState.mainCount})'),
                _buildDragTargetTab(DeckBoard.side, 'Side (${deckState.sideCount})'),
                _buildDragTargetTab(DeckBoard.considering, 'Considering (${deckState.consCount})'),
                _buildDragTargetTab(DeckBoard.wishlist, 'Wishlist (${deckState.wishCount})'),
                Tab(text: 'Tokens (${deckState.tokens.length})'),
                const Tab(text: 'Stats'),
                const Tab(text: 'Suggestions'),
                const Tab(icon: Icon(Icons.gavel, size: 18), text: 'Legalite'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), onPressed: _openCardPicker),
          PopupMenuButton<String>(
            onSelected: (val) {
               if (val == 'legality') _showValidationResults();
               if (val == 'finance') _showFinancialAnalysis();
               if (val == 'share_deck') _shareFullDeck();
               if (val == 'share_considering') _shareConsidering();
               if (val == 'share_wishlist') _shareWishlist();
               if (val == 'share_image') _captureAndShare();
               if (val == 'clear') _showClearDeckDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'finance', child: Row(children: [Icon(Icons.euro, size: 18), SizedBox(width: 8), Text('Finance')])),
              const PopupMenuItem(value: 'legality', child: Row(children: [Icon(Icons.gavel, size: 18), SizedBox(width: 8), Text('Legalite')])),
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
          : Column(
              children: [
                _buildCommanderHeader(deckState),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      DeckCardListTab(
                        cardList: deck.mainboard,
                        fullCardData: deckState.fullCardData,
                        collection: deckState.myCollection,
                        commanderId: deck.commanderScryfallId,
                        partnerId: deck.commanderSecondaryScryfallId,
                        currentBoard: DeckBoard.main,
                        onUpdateQuantity: (c, q) => _handleUpdateQuantity(c, q, DeckBoard.main),
                        onMoveCard: (c, target) => _handleMoveCard(c, target, DeckBoard.main),
                        onUpdateTags: (c, tags) => _ctrl.updateTags(c, tags, DeckBoard.main),
                        onSetCommander: _handleSetCommander,
                        onToggleFoil: (c) => _ctrl.toggleFoil(c, DeckBoard.main),
                        onSwitchVersion: (c, newV) => _ctrl.switchVersion(c, newV, DeckBoard.main),
                        onAddToCollection: (c, qty) => _handleAddToCollection(c, qty),
                        onAddToWishlist: (c, qty, wId) => _handleAddToWishlist(c, qty, wId),
                      ),
                      DeckCardListTab(
                        cardList: deck.sideboard,
                        fullCardData: deckState.fullCardData,
                        collection: deckState.myCollection,
                        currentBoard: DeckBoard.side,
                        onUpdateQuantity: (c, q) => _handleUpdateQuantity(c, q, DeckBoard.side),
                        onMoveCard: (c, target) => _handleMoveCard(c, target, DeckBoard.side),
                        onUpdateTags: (c, tags) => _ctrl.updateTags(c, tags, DeckBoard.side),
                        onToggleFoil: (c) => _ctrl.toggleFoil(c, DeckBoard.side),
                        onSwitchVersion: (c, newV) => _ctrl.switchVersion(c, newV, DeckBoard.side),
                        onAddToCollection: (c, qty) => _handleAddToCollection(c, qty),
                        onAddToWishlist: (c, qty, wId) => _handleAddToWishlist(c, qty, wId),
                      ),
                      DeckCardListTab(
                        cardList: deck.considering,
                        fullCardData: deckState.fullCardData,
                        collection: deckState.myCollection,
                        currentBoard: DeckBoard.considering,
                        onUpdateQuantity: (c, q) => _handleUpdateQuantity(c, q, DeckBoard.considering),
                        onMoveCard: (c, target) => _handleMoveCard(c, target, DeckBoard.considering),
                        onUpdateTags: (c, tags) => _ctrl.updateTags(c, tags, DeckBoard.considering),
                        onToggleFoil: (c) => _ctrl.toggleFoil(c, DeckBoard.considering),
                        onSwitchVersion: (c, newV) => _ctrl.switchVersion(c, newV, DeckBoard.considering),
                        onAddToCollection: (c, qty) => _handleAddToCollection(c, qty),
                        onAddToWishlist: (c, qty, wId) => _handleAddToWishlist(c, qty, wId),
                      ),
                      DeckCardListTab(
                        cardList: deck.wishlist,
                        fullCardData: deckState.fullCardData,
                        collection: deckState.myCollection,
                        currentBoard: DeckBoard.wishlist,
                        onUpdateQuantity: (c, q) => _handleUpdateQuantity(c, q, DeckBoard.wishlist),
                        onMoveCard: (c, target) => _handleMoveCard(c, target, DeckBoard.wishlist),
                        onUpdateTags: (c, tags) => _ctrl.updateTags(c, tags, DeckBoard.wishlist),
                        onExportToGlobalWishlist: _handleExportDeckWishlistToGlobal,
                        onToggleFoil: (c) => _ctrl.toggleFoil(c, DeckBoard.wishlist),
                        onSwitchVersion: (c, newV) => _ctrl.switchVersion(c, newV, DeckBoard.wishlist),
                        onAddToCollection: (c, qty) => _handleAddToCollection(c, qty),
                        onAddToWishlist: (c, qty, wId) => _handleAddToWishlist(c, qty, wId),
                      ),
                      DeckTokensTab(tokens: deckState.tokens),
                      DeckStatsTab(mainboard: deck.mainboard, cardData: deckState.fullCardData),
                      DeckSuggestionsTab(deck: deck),
                      DeckLegalityTab(report: _ctrl.generateLegalityReport()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCommanderHeader(DeckDetailState deckState) {
    final deck = deckState.currentDeck;
    final c1Id = deck.commanderScryfallId;
    final c2Id = deck.commanderSecondaryScryfallId;

    if (c1Id == null && c2Id == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: AppColors.overlayDark,
        child: const Text('Aucun Commandant defini', style: TextStyle(color: AppColors.textMuted, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textOnPrimary,
        border: Border(bottom: BorderSide(color: AppColors.primaryShade900, width: 2)),
        image: const DecorationImage(image: AssetImage('assets/images/background_texture_black.png'), fit: BoxFit.cover, opacity: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (c1Id != null) _buildSingleCommander(deckState, c1Id, 'Commander'),
          if (c1Id != null && c2Id != null)
             Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.add, color: AppColors.primaryShade700)),
          if (c2Id != null) _buildSingleCommander(deckState, c2Id, 'Partenaire'),
        ],
      ),
    );
  }

  Widget _buildSingleCommander(DeckDetailState deckState, String id, String label) {
    String? imageUrl;
    String name = 'Chargement...';
    final card = deckState.fullCardData.where((c) => c.id == id).firstOrNull;
    if (card != null) {
      imageUrl = card.artCropUrl ?? card.imageUrl;
      name = card.name;
    }

    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.accentOrange, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 60,
              width: double.infinity,
              color: AppColors.greyShade900,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Image.network(imageUrl, fit: BoxFit.cover, alignment: Alignment.topCenter,
                      errorBuilder: (c, e, s) => const SizedBox()),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.transparent, AppColors.overlayVeryDark]),
                    ),
                  ),
                  Positioned(
                    bottom: 4, left: 4, right: 4,
                    child: Text(name, style: AppTextStyles.bold(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragTargetTab(DeckBoard board, String label) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        return details.data['sourceBoard'] != board;
      },
      onAcceptWithDetails: (details) {
        final DeckCard card = details.data['card'];
        final DeckBoard source = details.data['sourceBoard'];
        _handleMoveCard(card, board, source);
        const boardToIndex = {
          DeckBoard.main: 0,
          DeckBoard.side: 1,
          DeckBoard.considering: 2,
          DeckBoard.wishlist: 3,
        };
        _tabController.animateTo(boardToIndex[board] ?? 0);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHovered = candidateData.isNotEmpty;
        return Tab(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: isHovered ? 4 : 0),
            decoration: isHovered
                ? BoxDecoration(color: AppColors.primaryShade900.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8))
                : null,
            child: Text(label),
          ),
        );
      },
    );
  }
}
