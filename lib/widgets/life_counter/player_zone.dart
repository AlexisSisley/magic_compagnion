// Fichier : lib/widgets/life_counter/player_zone.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/player_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../services/local_card_service.dart';
import '../../providers/service_providers.dart';
// Import du sélecteur de versions pour choisir l'artwork
import '../cards/versions_selector_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Sub-widgets
import 'player_header.dart';
import 'life_log.dart';
import 'zone/life_dial.dart';
import 'zone/conditional_handle.dart';

class PlayerZone extends ConsumerStatefulWidget {
  const PlayerZone({
    super.key,
    required this.player,
    required this.onLifeChanged,
    required this.onShowCommanderDamage,
    required this.onColorChanged,
    this.onCounterDelta,
    this.onOpenDrawer,
    this.onRotationChanged,
    this.onSkinChanged,
    this.onNameTap,
    this.quarterTurns = 0,
    this.isCommander = false,
    this.isHighlighted = false,
  });

  final Player player;
  final int quarterTurns;
  final bool isCommander;
  final bool isHighlighted;
  final Function(int) onLifeChanged;

  /// Émis quand un compteur change depuis le tiroir.
  final void Function(String counterId, int delta)? onCounterDelta;

  /// Ouverture du tiroir (tap ou glissement depuis la poignée).
  final VoidCallback? onOpenDrawer;

  final Function(Color) onColorChanged;
  final Function(int)? onRotationChanged;
  final Function(String?)? onSkinChanged;

  /// Optional callback triggered when the player name in the header is tapped.
  /// Wire this to open PlayerHistorySheet (Task 10).
  final VoidCallback? onNameTap;
  final VoidCallback onShowCommanderDamage;

  @override
  ConsumerState<PlayerZone> createState() => _PlayerZoneState();
}

class _PlayerZoneState extends ConsumerState<PlayerZone>
    with TickerProviderStateMixin {
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);

  final List<FloatingNumberData> _floatingNumbers = [];

  int _nextNumberId = 0;
  double _dragAccumulator = 0.0;
  Offset _lastLongPressPosition = Offset.zero;
  final double _rotationThreshold = 40.0;

  /// Hauteur réservée à l'en-tête (palette, rotation, nom) au-dessus du
  /// cadran de vie (spec §2.1 : le chiffre occupe le reste de la zone).
  static const double _headerHeight = 40.0;

  // --- US-14.3 : Animation controllers ---
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  final List<Color> _colorOptions = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    AppColors.greyShade800, Colors.purple.shade900, Colors.orange.shade900,
    Colors.teal.shade900, Colors.pink.shade900, Colors.brown.shade800,
    Colors.indigo.shade900, Colors.blueGrey.shade800, Colors.black
  ];

  @override
  void initState() {
    super.initState();

    // Pulse (scale) : 200ms
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    // Shake (translation X) : 300ms
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    // Glow (opacity pulsation) : 1.5s, boucle infinie
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 0.8), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.3), weight: 50),
    ]).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut));

    if (widget.player.isMonarch) {
      _glowController.repeat();
    }

    if (!_localCardService.isLoaded) {
      _localCardService.loadLocalData();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayerZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.isMonarch && !_glowController.isAnimating) {
      _glowController.repeat();
    } else if (!widget.player.isMonarch && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  // --- Logic (kept in orchestrator since it coordinates animations + callbacks) ---

  /// Remonte un delta de vie : la zone ne mute plus le `Player` en place
  /// (V4 — voir le tiroir pour les compteurs), elle se contente d'émettre et
  /// de jouer le retour visuel (pulse/shake + nombre flottant).
  void _triggerChange(int change) {
    widget.onLifeChanged(change);
    _showFloatingNumber(change);
    if (change > 0) {
      _pulseController.forward(from: 0);
    } else if (change < 0) {
      _shakeController.forward(from: 0);
    }
  }

  void _showFloatingNumber(int change) {
    final String text = (change > 0) ? '+$change' : '$change';
    final Color color = (change > 0) ? AppColors.accentGreen : AppColors.accentRed;

    final int id = _nextNumberId++;
    final number = FloatingNumberData(id: id, text: text, color: color);

    if(mounted) setState(() => _floatingNumbers.add(number));

    Timer(const Duration(milliseconds: 50), () {
      if(mounted) setState(() { number.top = -50.0; number.opacity = 0.0; });
    });

    Timer(const Duration(milliseconds: 600), () {
      if(mounted) setState(() => _floatingNumbers.removeWhere((n) => n.id == id));
    });
  }

  Future<void> _pickImage(BuildContext dialogCtx) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && widget.onSkinChanged != null) {
        widget.onSkinChanged!(image.path);
        if (!mounted) return;
        Navigator.of(dialogCtx).pop();
      }
    } catch (e) {
      debugPrint('Erreur image picker: $e');
    }
  }

  void _openArtworkSearch(BuildContext dialogCtx) {
    // Close the color picker dialog using the dialog's own context
    Navigator.of(dialogCtx).pop();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      isScrollControlled: true,
      builder: (sheetCtx) => _ArtworkSearchModal(
        localCardService: _localCardService,
        onCardSelected: (ScryfallCard card) {
          final String artUrl = card.artCropUrl ?? card.imageUrl;
          if (widget.onSkinChanged != null) {
            widget.onSkinChanged!(artUrl);
          }
        },
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        title: Text('Personnalisation J${widget.player.id + 1}', style: AppTextStyles.cinzel()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openArtworkSearch(dialogCtx),
              icon: const Icon(Icons.palette, color: AppColors.textOnPrimary),
              label: Text('Choisir un Artwork', style: AppTextStyles.bold()),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade800, foregroundColor: AppColors.textOnPrimary),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _pickImage(dialogCtx),
              icon: const Icon(Icons.photo_library),
              label: const Text('Depuis la galerie'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.borderMedium)),
            ),
            if (widget.player.backgroundImagePath != null)
               TextButton(
                 onPressed: () {
                   widget.onSkinChanged?.call(null);
                   Navigator.of(dialogCtx).pop();
                 },
                 child: const Text("Supprimer l'image", style: TextStyle(color: AppColors.accentRed))
               ),
            const Divider(color: AppColors.borderMedium),
            const Text('Couleur unie :', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colorOptions.map((c) => GestureDetector(
                onTap: () { widget.onColorChanged(c); Navigator.of(dialogCtx).pop(); },
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.textMuted, width: 2),
                    boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 8)]
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      )
    );
  }

  void _showCommanderGallery() {
    final gallery = widget.player.commanderGallery;
    if (gallery.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.scaffoldBackground,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Commanders', style: AppTextStyles.cinzel(fontSize: 18)),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final entry = gallery[i];
                  final isActive = widget.player.backgroundImagePath == entry.imageUrl;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (widget.onSkinChanged != null) {
                        widget.onSkinChanged!(entry.imageUrl);
                        HapticFeedback.selectionClick();
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive ? AppColors.primary : AppColors.borderMedium,
                              width: isActive ? 3 : 1,
                            ),
                            boxShadow: isActive ? [
                              BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 8),
                            ] : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: entry.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: entry.imageUrl!,
                                  httpHeaders: const {'User-Agent': 'MagicCompanion/1.0', 'Accept': '*/*'},
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: AppColors.surfaceDarkest,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.surfaceDarkest,
                                    child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                                  ),
                                )
                              : Container(
                                  color: AppColors.surfaceDarkest,
                                  child: const Icon(Icons.image, color: AppColors.textMuted),
                                ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 80,
                          child: Text(
                            entry.name,
                            style: AppTextStyles.label(fontSize: 10),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _rotate90Degrees() {
    if (widget.onRotationChanged != null) {
      final nextRot = (widget.player.quarterTurns + 1) % 4;
      widget.onRotationChanged!(nextRot);
      HapticFeedback.lightImpact();
    }
  }

  void _handleRotationDrag(double delta) {
    if (widget.onRotationChanged == null) return;
    _dragAccumulator += delta;
    if (_dragAccumulator.abs() > _rotationThreshold) {
      int direction = _dragAccumulator > 0 ? 1 : -1;
      int newRot = (widget.player.quarterTurns + direction) % 4;
      if (newRot < 0) newRot += 4;
      widget.onRotationChanged!(newRot);
      HapticFeedback.mediumImpact();
      _dragAccumulator = 0.0;
    }
  }

  // --- BUILD ---

  @override
  Widget build(BuildContext context) {
    Color bgColor = Color(widget.player.colorValue);

    // Background image handling
    Widget backgroundWidget;

    if (widget.player.backgroundImagePath != null && widget.player.secondaryBackgroundImagePath != null) {
      backgroundWidget = Row(
        children: [
          Expanded(child: _buildImage(widget.player.backgroundImagePath!)),
          Expanded(child: _buildImage(widget.player.secondaryBackgroundImagePath!)),
        ],
      );
    } else if (widget.player.backgroundImagePath != null) {
      backgroundWidget = _buildImage(widget.player.backgroundImagePath!);
    } else {
      backgroundWidget = Container(color: bgColor);
    }

    // Résumé des compteurs pour la poignée conditionnelle (spec §2.2) : le
    // "pire" dégât de commandant, pas le total, est ce qui menace vraiment.
    final counterSummary = CounterSummary(
      poison: widget.player.poison,
      energy: widget.player.energy,
      commanderTax: widget.player.commanderCastCount,
      worstCommanderDamage: widget.player.commanderDamageReceived.values
          .fold<int>(0, (max, v) => v > max ? v : max),
    );

    // US-14.3 : Glow monarch via AnimatedBuilder
    Widget content = AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final bool isMonarch = widget.player.isMonarch;
        final double glowOpacity = isMonarch && _glowController.isAnimating ? _glowAnimation.value : 0.0;
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: widget.isHighlighted
                ? Border.all(color: AppColors.textPrimary, width: 4)
                : isMonarch
                    ? Border.all(color: AppColors.primaryBright.withValues(alpha: glowOpacity), width: 3)
                    : Border.all(color: AppColors.borderSubtle, width: 1),
            boxShadow: [
              BoxShadow(color: AppColors.textOnPrimary.withValues(alpha: 0.4), blurRadius: 4, offset: const Offset(2, 2)),
              if (isMonarch)
                BoxShadow(color: AppColors.primaryBright.withValues(alpha: glowOpacity * 0.6), blurRadius: 16, spreadRadius: 2),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
      child: Stack(
        children: [
          // Background
          Positioned.fill(child: backgroundWidget),
          Positioned.fill(child: Container(color: AppColors.textOnPrimary.withValues(alpha: 0.3))),

          // Corps central : en-tête (palette/rotation/nom), le chiffre de vie
          // occupe tout le reste (spec §2.1), la poignée conditionnelle ferme
          // la zone en bas (spec §2.2).
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(
                  height: _headerHeight,
                  child: PlayerHeader(
                    onShowColorPicker: _showColorPicker,
                    onRotate: _rotate90Degrees,
                    onLongPressStart: (details) {
                      _dragAccumulator = 0.0;
                      _lastLongPressPosition = details.localPosition;
                      HapticFeedback.selectionClick();
                    },
                    onLongPressMoveUpdate: (details) {
                      final double delta = details.localPosition.dx - _lastLongPressPosition.dx;
                      _lastLongPressPosition = details.localPosition;
                      _handleRotationDrag(delta);
                    },
                    playerName: widget.player.name,
                    onNameTap: widget.onNameTap,
                  ),
                ),
                Expanded(
                  // US-14.3 : pulse (gain de vie) et shake (dégâts) — le
                  // chiffre occupe tout le cadran désormais, l'animation
                  // s'applique donc au cadran entier plutôt qu'à un Text isolé
                  // comme au temps de LifeDisplay.
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulseController, _shakeController]),
                    builder: (context, child) {
                      final double scale = _pulseController.isAnimating ? _pulseAnimation.value : 1.0;
                      final double shakeX = _shakeController.isAnimating ? _shakeAnimation.value : 0.0;
                      return Transform.translate(
                        offset: Offset(shakeX, 0),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: LifeDial(
                      playerId: widget.player.id,
                      life: widget.player.life,
                      onDelta: _triggerChange,
                    ),
                  ),
                ),
                ConditionalHandle(
                  summary: counterSummary,
                  onTap: widget.onOpenDrawer,
                ),
              ],
            ),
          ),

          // Floating numbers overlay
          LifeLog(floatingNumbers: _floatingNumbers),

          // Commander gallery quick-switch (top-right)
          if (widget.player.commanderGallery.isNotEmpty)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: _showCommanderGallery,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceDarkest.withAlpha(180),
                    border: Border.all(color: AppColors.borderMedium, width: 1),
                  ),
                  child: const Icon(Icons.swap_horiz, color: AppColors.textPrimary, size: 18),
                ),
              ),
            ),

          // Highlight overlay
          if (widget.isHighlighted)
            Container(
              color: AppColors.overlayMedium,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: AppColors.textPrimary, width: 2), borderRadius: BorderRadius.circular(8)),
                child: Text('Start ?', style: AppTextStyles.pageTitle()),
              ),
            )
        ],
      ),
    );

    return RotatedBox(
      quarterTurns: widget.player.quarterTurns,
      child: content,
    );
  }

  Widget _buildImage(String path) {
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        httpHeaders: const {'User-Agent': 'MagicCompanion/1.0', 'Accept': '*/*'},
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(color: AppColors.greyShade900),
        errorWidget: (context, url, error) => Container(
          color: AppColors.greyShade900,
          child: const Center(child: Icon(Icons.image_not_supported, color: AppColors.borderMedium)),
        ),
      );
    }
    return Image(image: FileImage(File(path)), fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        color: AppColors.greyShade900,
        child: const Center(child: Icon(Icons.image_not_supported, color: AppColors.borderMedium)),
      ),
    );
  }
}

// --- SOUS-WIDGET : MODALE DE RECHERCHE D'ARTWORK ---
class _ArtworkSearchModal extends StatefulWidget {
  final LocalCardService localCardService;
  final Function(ScryfallCard) onCardSelected;

  const _ArtworkSearchModal({required this.localCardService, required this.onCardSelected});

  @override
  State<_ArtworkSearchModal> createState() => _ArtworkSearchModalState();
}

class _ArtworkSearchModalState extends State<_ArtworkSearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<ScryfallCard> _results = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length >= 2) {
        final results = await widget.localCardService.searchCards(query: query);
        if (mounted) {
          setState(() {
            _results = results.take(20).toList();
          });
        }
      } else {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  void _openVersionSelector(ScryfallCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => VersionsSelectorSheet(
        oracleId: card.oracleId,
        currentCardId: card.id,
        onVersionSelected: (version) {
           widget.onCardSelected(version);
           Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text('Choisir un Artwork', style: AppTextStyles.cinzel(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: AppTextStyles.cinzel(),
              decoration: const InputDecoration(
                hintText: 'Nom de la carte...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.overlayMedium,
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text("Tapez le nom d'une carte", style: AppTextStyles.cinzel(color: AppColors.textDisabled)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.7,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        final imgUrl = card.smallImageUrl ?? '';

                        return GestureDetector(
                          onTap: () => _openVersionSelector(card),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, _, _)=>Container(color: AppColors.greyShade800)),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    color: AppColors.overlayDark,
                                    child: const Icon(Icons.grid_view, size: 12, color: AppColors.textSecondary),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
