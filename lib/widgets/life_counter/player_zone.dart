// Fichier : lib/widgets/life_counter/player_zone.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/counter_type.dart';
import '../../models/player_model.dart';
import '../../services/local_card_service.dart';
import '../../providers/counter_catalog_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/player_zone_notifier.dart';

// Sub-widgets
import 'player_header.dart';
import 'life_log.dart';
import 'zone/life_dial.dart';
import 'zone/conditional_handle.dart';
import 'zone/player_skin_picker.dart';
import 'zone/damage_attribution_row.dart';

/// Résout un compteur intégré par id (voir le doc-comment de la
/// construction de `CounterSummary` dans `_PlayerZoneState.build` ci-dessous
/// pour le pourquoi). `CounterType.builtInCounters` est une liste fixe de 4
/// entrées : un `firstWhere` sans `orElse` est sûr ici, seulement pour ces
/// trois ids connus (poison/energy/commander_tax).
CounterType _builtInCounterType(String id) =>
    CounterType.builtInCounters.firstWhere((c) => c.id == id);

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
    this.isHighlighted = false,
    this.attributionOpponents,
    this.onAttributeDamage,
  });

  final Player player;
  final int quarterTurns;
  final bool isHighlighted;
  final Function(int) onLifeChanged;

  /// Rangée d'attribution à la volée (spec S2.6, tâche 3 du lot 3). `null`
  /// ou vide masque la rangée -- c'est l'appelant (`life_counter_page.dart`)
  /// qui décide de la visibilité (buffer négatif, format Commander, zone
  /// pas en mode ajustement) ; ce widget ne fait qu'afficher ce qu'on lui
  /// donne, au même titre que `player.commanderDamageReceived`.
  ///
  /// Ronde de correction finale (Critical/Important #2) : vit ICI, DANS le
  /// `RotatedBox` de `quarterTurns` ci-dessous -- et non empilée par-dessus
  /// depuis `life_counter_page.dart` comme au premier jet -- pour pivoter
  /// avec le reste de la zone. Contrairement au badge de buffer (décoratif,
  /// même défaut resté tel quel, voir la note du lot 6), cette rangée est
  /// une cible tactile : mal orientée, elle tombe au bas de l'écran plutôt
  /// qu'au bas de la zone telle que le joueur la lit à 90°/270°.
  final List<DamageAttributionOpponent>? attributionOpponents;
  final void Function(int sourcePlayerId)? onAttributeDamage;

  /// Ouverture du tiroir (tap sur la poignée — voir `ConditionalHandle`, qui
  /// n'expose qu'un `onTap`, aucun glissement) : compteurs, monarque,
  /// élimination et dégâts de commandant y vivent désormais tous (voir
  /// player_drawer.dart) — PlayerZone n'a plus besoin de callbacks dédiés à
  /// chacun d'eux.
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

  /// Le notifier de cette zone (nombres flottants, rotation, mode
  /// ajustement — voir `player_zone_notifier.dart`). Getter de lecture
  /// ordinaire, jamais utilisé dans `dispose()`.
  PlayerZoneNotifier get _notifier =>
      ref.read(playerZoneNotifierProvider(widget.player.id).notifier);

  Offset _lastLongPressPosition = Offset.zero;

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

  /// Délègue au notifier (`showFloatingNumber`) l'apparition du nombre, puis
  /// programme son animation puis son retrait via deux `Timer`, comme avant
  /// — la seule différence est que l'état vit désormais dans le notifier.
  ///
  /// Attention au cycle de vie : ces `Timer` peuvent se déclencher après le
  /// démontage de la zone (changement de layout, retrait du joueur...). Le
  /// provider n'est pas `autoDispose`, un appel tardif ne plantera donc pas
  /// — mais il écrirait dans l'état d'une zone qui n'existe plus. D'où les
  /// gardes `if (!mounted) return;` avant tout accès à `ref`.
  void _showFloatingNumber(int change) {
    final int id = _notifier.showFloatingNumber(change);

    Timer(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      _notifier.animateFloatingNumber(id);
    });

    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _notifier.removeFloatingNumber(id);
    });
  }

  void _rotate90Degrees() {
    if (widget.onRotationChanged == null) return;
    final nextRot = _notifier.rotate90Degrees(widget.player.quarterTurns);
    widget.onRotationChanged!(nextRot);
    HapticFeedback.lightImpact();
  }

  void _handleRotationDrag(double delta) {
    if (widget.onRotationChanged == null) return;
    final nextRot = _notifier.handleRotationDrag(delta, widget.player.quarterTurns);
    if (nextRot != null) {
      widget.onRotationChanged!(nextRot);
      HapticFeedback.mediumImpact();
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
    //
    // Lot 5, tâche 3b -- `CounterSummary` est désormais générique (une
    // collection de paires `CounterType`/valeur), plus le pire dégât de
    // commandant à part.
    //
    // Lot 5, tâche 4 (câblage manquant) : construite depuis
    // `widget.player.counters` (générique, alimentée par
    // `_toLegacyPlayer` à partir de `GameSession.activeCounterIds`), pas
    // des trois champs `Player.poison`/`energy`/`commanderCastCount` --
    // c'était le trou qui empêchait tout compteur personnalisé actif
    // d'atteindre la poignée, bien que celle-ci sache déjà en résumer N
    // (voir `ConditionalHandle`). Un id intégré est résolu localement
    // (`_builtInCounterType`, pas de dépendance à `ref` pour les trois
    // historiques) ; un id personnalisé est résolu via le catalogue
    // (`counterTypeByIdProvider`) -- `null` (catalogue pas encore chargé,
    // id obsolète) écarte silencieusement l'entrée, comme le fait déjà
    // `_openPlayerDrawer` pour le tiroir.
    final counterEntries = <MapEntry<CounterType, int>>[];
    for (final entry in widget.player.counters.entries) {
      final isBuiltIn =
          CounterType.builtInCounters.any((c) => c.id == entry.key);
      final type = isBuiltIn
          ? _builtInCounterType(entry.key)
          : ref.watch(counterTypeByIdProvider(entry.key));
      if (type != null) counterEntries.add(MapEntry(type, entry.value));
    }
    final counterSummary = CounterSummary(
      counters: counterEntries,
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
                      // Un nouveau geste ne doit pas hériter du résidu d'un
                      // geste précédent, achevé sans franchir le seuil (voir
                      // le doc-comment de `resetRotationDrag`).
                      _notifier.resetRotationDrag();
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

          // Floating numbers overlay — la liste vit dans le notifier (voir
          // `_showFloatingNumber`) : `watch` pour reconstruire l'overlay
          // quand un nombre apparaît, s'anime ou disparaît.
          LifeLog(
            floatingNumbers: ref
                .watch(playerZoneNotifierProvider(widget.player.id))
                .floatingNumbers,
          ),

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

          // Rangée d'attribution à la volée (spec S2.6) — voir le
          // doc-comment de `attributionOpponents` : ancrée juste au-dessus
          // de la poignée conditionnelle, comme la rangée de paliers
          // ±5/±10 de `LifeDial._stepRow()`. Les deux ne coexistent jamais
          // (l'appelant masque `attributionOpponents` en mode ajustement,
          // ronde de correction finale Critical #1) : plus besoin de
          // partager le même 30px du bas sans se recouvrir.
          if (widget.attributionOpponents != null &&
              widget.attributionOpponents!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: ConditionalHandle.reservedHeight,
              child: Center(
                child: DamageAttributionRow(
                  opponents: widget.attributionOpponents!,
                  onAttribute: widget.onAttributeDamage!,
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
