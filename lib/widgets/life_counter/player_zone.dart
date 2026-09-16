// Fichier : lib/widgets/life_counter/player_zone.dart

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/player_model.dart';
import '../../services/local_card_service.dart';
import '../../providers/service_providers.dart';
import '../../providers/player_zone_notifier.dart';

// Sub-widgets
import 'player_header.dart';
import 'life_log.dart';
import 'zone/life_dial.dart';
import 'zone/conditional_handle.dart';
import 'zone/player_skin_picker.dart';
import 'zone/damage_attribution_row.dart';
import 'layouts/density_tier.dart';

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
    this.pendingDamage = 0,
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
  /// avec le reste de la zone : mal orientée, elle tomberait au bas de
  /// l'écran plutôt qu'au bas de la zone telle que le joueur la lit à
  /// 90°/270°. Même raisonnement, même correction pour `pendingDamage`
  /// ci-dessous (tâche 6 du lot 6).
  final List<DamageAttributionOpponent>? attributionOpponents;
  final void Function(int sourcePlayerId)? onAttributeDamage;

  /// Solde du buffer de dégâts de 2s en attente d'application (voir
  /// `life_counter_page._pendingDamage`) : 0 masque le badge, un signe
  /// choisit sa couleur (gain vs dégât). État transitoire, pas un compteur
  /// permanent -- il reste affiché à tous les crans de densité, y compris
  /// au cran minimal (spec §3.3 : seule la couche d'alerte perce le
  /// silence du cran minimal, ce badge n'est pas cette couche).
  ///
  /// Vit ICI, DANS le `RotatedBox` de `quarterTurns` -- corrigé au lot 6
  /// tâche 6 : rendu hors de la zone depuis `life_counter_page.dart`
  /// jusqu'ici, il ne pivotait jamais avec elle, ce qui restait discret
  /// tant que les rotations non nulles étaient rares. Ce lot place deux
  /// sièges sur quatre à 90°/270°, ce qui rend le défaut visible.
  final int pendingDamage;

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

  /// Délègue entièrement au notifier (`showFloatingNumber`) : apparition,
  /// animation à 50ms et retrait à 600ms. Ce widget n'arme plus de `Timer`
  /// ni ne garde de `mounted` sur ce chemin -- le notifier possède l'état
  /// (`state.floatingNumbers`), il possède donc aussi son propre nettoyage
  /// (voir le commentaire de `PlayerZoneNotifier._animateTimers`). Avant
  /// cette correction (tâche 7 du lot 6), ces `Timer` vivaient ici, gardés
  /// par `if (!mounted) return;` : si la zone était démontée entre
  /// l'affichage et les 600ms, la garde empêchait le retrait et le nombre
  /// restait affiché indéfiniment -- le bug signalé par l'utilisateur.
  void _showFloatingNumber(int change) {
    _notifier.showFloatingNumber(change);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final int quarterTurns = widget.player.quarterTurns;

        // Le cran de densite se decide sur la taille DANS LE REPERE DU
        // JOUEUR (tache 4 du lot 6) : un siege lateral (90/270) est haut et
        // etroit a l'ecran mais large et bas pour le joueur qui le lit une
        // fois la zone tournee -- `RotatedBox` echange les axes pour son
        // enfant. `constraints` ici est mesure AVANT cette rotation (elle
        // n'est appliquee qu'au `return` ci-dessous), donc on transpose
        // nous-memes.
        final Size sizeInPlayerFrame = quarterTurns.isOdd
            ? Size(constraints.maxHeight, constraints.maxWidth)
            : Size(constraints.maxWidth, constraints.maxHeight);
        final DensityTier tier = tierFor(sizeInPlayerFrame);

        return _buildZone(context, tier, quarterTurns);
      },
    );
  }

  Widget _buildZone(BuildContext context, DensityTier tier, int quarterTurns) {
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
                  height: kZoneHeaderHeight,
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
                    // Cran minimal (tache 4, spec §3.2) : le nom se reduit a
                    // la pastille de couleur deja portee par le fond de la
                    // zone -- on n'affiche plus le libelle du PlayerHeader,
                    // qui n'a pas la place de s'afficher sans deborder.
                    playerName:
                        tier == DensityTier.minimal ? null : widget.player.name,
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
                  tier: tier,
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
          // partager le même bas sans se recouvrir.
          //
          // La hauteur effective de la poignée dépend désormais du cran
          // (tâche 4) : en confort elle vaut 48, pas 30 -- ancrer sur
          // `ConditionalHandle.reservedHeight` (le plancher, invariant)
          // recouvrirait 18px de la poignée dès 2-3 joueurs. `handleHeightFor`
          // est la seule source qui connaisse la hauteur réelle.
          if (widget.attributionOpponents != null &&
              widget.attributionOpponents!.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: handleHeightFor(tier),
              child: Center(
                child: DamageAttributionRow(
                  opponents: widget.attributionOpponents!,
                  onAttribute: widget.onAttributeDamage!,
                ),
              ),
            ),

          // Badge de dégâts en attente (voir le doc-comment de
          // `pendingDamage`) : ancré top/right comme l'icône de galerie de
          // commandants ci-dessus -- les deux ne se recouvrent qu'au cas
          // marginal où une galerie ET un buffer sont actifs en même temps
          // sur le même joueur, préexistant à cette correction et hors
          // périmètre de la tâche 6.
          if (widget.pendingDamage != 0)
            Positioned(
              key: const ValueKey('pending_damage_badge'),
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (widget.pendingDamage > 0
                          ? AppColors.accentGreen
                          : AppColors.accentRed)
                      .withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.pendingDamage > 0
                      ? '+${widget.pendingDamage}'
                      : '${widget.pendingDamage}',
                  style: AppTextStyles.bold(color: AppColors.textPrimary, fontSize: 14),
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
      quarterTurns: quarterTurns,
      child: content,
    );
  }
}
