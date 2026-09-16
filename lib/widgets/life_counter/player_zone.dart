// Fichier : lib/widgets/life_counter/player_zone.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/player_model.dart';
import '../../services/local_card_service.dart';
import '../../providers/service_providers.dart';

// Sub-widgets
import 'player_header.dart';
import 'life_log.dart';
import 'zone/life_dial.dart';
import 'zone/conditional_handle.dart';
import 'zone/player_skin_picker.dart';

class PlayerZone extends ConsumerStatefulWidget {
  const PlayerZone({
    super.key,
    required this.player,
    required this.onLifeChanged,
    required this.onColorChanged,
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

  /// Ouverture du tiroir (tap ou glissement depuis la poignée) : compteurs,
  /// monarque, élimination et dégâts de commandant y vivent désormais tous
  /// (voir player_drawer.dart) — PlayerZone n'a plus besoin de callbacks
  /// dédiés à chacun d'eux.
  final VoidCallback? onOpenDrawer;

  final Function(Color) onColorChanged;
  final Function(int)? onRotationChanged;
  final Function(String?)? onSkinChanged;

  /// Optional callback triggered when the player name in the header is tapped.
  /// Wire this to open PlayerHistorySheet (Task 10).
  final VoidCallback? onNameTap;

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
    //
    // ATTENTION (tests) : `.repeat()` ne se termine jamais tant que le
    // joueur reste monarque — `tester.pumpAndSettle()` fait alors timeout
    // dans tout test dont l'arbre traverse un `PlayerZone` monarque (vu en
    // ronde 1 de revue de la tâche 6). Utiliser `tester.pump(duration)` avec
    // une durée bornée pour ces cas, jamais `pumpAndSettle()`. Le coût de
    // rendu réel reste négligeable : l'animation ne tourne que pour le seul
    // joueur monarque (au plus un par partie), et son sous-arbre est passé
    // en `child:` de l'`AnimatedBuilder` — il n'est reconstruit qu'une fois,
    // pas à chaque frame du glow.
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

    // Image de fond (ou couleur unie de repli) : voir zone/player_skin_picker.dart.
    final Widget backgroundWidget = buildPlayerBackground(widget.player);

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
                    onShowColorPicker: () => showPlayerSkinPicker(
                      context: context,
                      player: widget.player,
                      onColorChanged: widget.onColorChanged,
                      onSkinChanged: widget.onSkinChanged,
                      localCardService: _localCardService,
                    ),
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
                onTap: () => showCommanderGallery(
                  context: context,
                  player: widget.player,
                  onSkinChanged: widget.onSkinChanged,
                ),
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
}
