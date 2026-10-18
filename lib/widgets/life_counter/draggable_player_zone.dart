// Fichier : lib/widgets/life_counter/draggable_player_zone.dart
// V3 — Drag & Drop with swap animation 300ms easeInOut (spec 4.3)
// Long press 1s → drag, scale 1.05 + shadow + 80% opacity
// Drop → swap with 300ms easeInOut animation
// Drop outside → spring back animation

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/life_counter/zone/orientation_picker.dart';

/// Wraps a player zone widget to enable long-press drag & drop reordering.
///
/// Tâche 8a (spec §1.9) : le glisser-déposer n'existe plus qu'en mode
/// réorganisation ([enabled]). Hors de ce mode, l'enfant est rendu NU --
/// aucun `Draggable`, aucun `DragTarget`, aucun détecteur : un appui long
/// sur une zone en pleine partie ne peut plus déplacer un joueur. Dans le
/// mode, la zone change d'habit (voile, bordure en tirets, poignée,
/// [OrientationPicker]) et son contenu n'est plus touchable : le geste de vie
/// est suspendu tant que la table se réarrange.
///
/// Long press (1s) activates drag with visual feedback:
/// - Scale 1.05 + shadow + 80% opacity while dragging
/// - Dashed placeholder shown at original position during drag
/// - Hover glow on valid drop targets
/// - Calls [onReorder] with old/new indices on drop
class DraggablePlayerZone extends StatefulWidget {
  final int index;
  final Widget child;
  final void Function(int oldIndex, int newIndex) onReorder;

  /// Vrai en mode réorganisation, et seulement alors. Requis (pas de défaut) :
  /// l'appelant doit dire dans quel mode on est, pas en hériter d'un oubli.
  final bool enabled;

  /// Rotation courante du joueur, pour allumer la bonne flèche.
  final int quarterTurns;

  /// Appelé avec le quart de tour choisi sur une flèche. La page le relaie à
  /// `GameSessionNotifier.updateRotation`, qui le marque comme manuel.
  final ValueChanged<int> onOrientationChanged;

  /// Nom affiché près de la poignée en mode réorganisation : le contenu de la
  /// zone est voilé, et une zone tournée à 90° se lit mal de travers.
  final String? playerName;

  const DraggablePlayerZone({
    super.key,
    required this.index,
    required this.child,
    required this.onReorder,
    required this.enabled,
    required this.quarterTurns,
    required this.onOrientationChanged,
    this.playerName,
  });

  @override
  State<DraggablePlayerZone> createState() => _DraggablePlayerZoneState();
}

class _DraggablePlayerZoneState extends State<DraggablePlayerZone>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  bool _justSwapped = false;

  late final AnimationController _swapController;
  late final Animation<double> _swapAnimation;

  @override
  void initState() {
    super.initState();
    _swapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swapAnimation = CurvedAnimation(
      parent: _swapController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _swapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DraggablePlayerZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger swap animation when the zone content changes (reorder happened)
    if (_justSwapped) {
      _swapController.forward(from: 0.0);
      _justSwapped = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mode jeu : l'enfant tel quel. C'est CE retour, et non un drapeau lu plus
    // bas, qui garantit qu'aucun glisser n'est armé pendant la partie.
    if (!widget.enabled) return widget.child;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (details.data != widget.index) {
          setState(() => _isHovering = true);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _isHovering = false),
      onAcceptWithDetails: (details) {
        setState(() {
          _isHovering = false;
          _justSwapped = true;
        });
        HapticFeedback.mediumImpact();
        widget.onReorder(details.data, widget.index);
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: widget.index,
          delay: const Duration(seconds: 1),
          onDragStarted: () => HapticFeedback.selectionClick(),
          feedback: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(18),
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.8,
              child: Transform.scale(
                scale: 1.05,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: 130,
                  child: widget.child,
                ),
              ),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDarkest.withAlpha(80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.borderMedium,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(Icons.swap_horiz, color: AppColors.textMuted, size: 36),
            ),
          ),
          child: AnimatedBuilder(
            animation: _swapAnimation,
            builder: (context, child) {
              // Scale-in animation on swap completion
              final scale = _swapController.isAnimating
                  ? 0.92 + 0.08 * _swapAnimation.value
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: _isHovering
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                    boxShadow: _isHovering
                        ? [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 12, spreadRadius: 2)]
                        : null,
                  ),
                  child: child,
                ),
              );
            },
            child: _reorganiseDress(),
          ),
        );
      },
    );
  }

  /// L'habit du mode réorganisation, posé par-dessus la zone.
  ///
  /// Le contenu est enveloppé dans `AbsorbPointer` : la zone (cadran de vie,
  /// poignée du tiroir, rangée d'attribution, overlay de mort) ne reçoit plus
  /// aucune touche -- spec §1.9, « le geste de vie désactivé ». Les ancêtres,
  /// eux, restent sur le chemin du hit-test : le `LongPressDraggable` qui
  /// enveloppe cet habit continue donc de voir l'appui long, où qu'il soit
  /// posé sur la zone. `ExcludeSemantics` ferme la même porte aux lecteurs
  /// d'écran, qui pourraient sinon déclencher les actions de la zone voilée.
  ///
  /// Le sélecteur et la poignée sont posés ICI, hors du `RotatedBox` de
  /// `PlayerZone` : leurs flèches sont dans le repère de l'ÉCRAN (▲ montre le
  /// haut de l'appareil, pas le haut d'une zone pivotée).
  Widget _reorganiseDress() {
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: AbsorbPointer(child: widget.child),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey('reorganise-veil'),
              foregroundPainter: _DashedBorderPainter(
                color: AppColors.primary.withAlpha(140),
              ),
              child: const ColoredBox(color: AppColors.overlayMedium),
            ),
          ),
        ),
        Positioned(
          top: 4,
          left: 4,
          right: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Déplacer la zone',
                child: const SizedBox(
                  key: ValueKey('reorganise-handle'),
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  child: Icon(Icons.drag_handle,
                      color: AppColors.primary, size: 26),
                ),
              ),
              if (widget.playerName != null)
                Flexible(
                  child: Text(
                    widget.playerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bold(
                        fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
            ],
          ),
        ),
        // `FittedBox(scaleDown)` : à 7-8 joueurs ou sur un écran plié, une
        // zone peut être plus petite que la croix (3×48). Elle se réduit
        // alors au lieu de déborder -- ses cases passent sous 48 dans ce seul
        // cas, compromis assumé plutôt qu'un débordement qui la couperait.
        Positioned.fill(
          top: kMinInteractiveDimension,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: OrientationPicker(
                quarterTurns: widget.quarterTurns,
                onChanged: widget.onOrientationChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bordure en tirets du mode réorganisation : le trait plein reste réservé
/// au survol d'une cible de dépôt (`_isHovering`), pour que les deux états
/// ne se confondent pas.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 8;
  static const double _gap = 5;
  static const double _stroke = 2;
  static const double _radius = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_stroke),
      const Radius.circular(_radius),
    );
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
