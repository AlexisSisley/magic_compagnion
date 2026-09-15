// lib/widgets/life_counter/zone/life_dial.dart
// Surface de geste des points de vie (spec §2.1, §2.5).
//
// Le chiffre occupe toute la zone. Tap à gauche = −1, à droite = +1. Appui
// long = mode ajustement (paliers ±5/±10, molette). Le widget n'applique
// rien : il émet des deltas, que life_counter_page accumule dans son buffer
// de 2 s.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:magic_companion/providers/player_zone_notifier.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class LifeDial extends ConsumerStatefulWidget {
  const LifeDial({
    super.key,
    required this.playerId,
    required this.life,
    required this.onDelta,
    this.pendingDelta = 0,
    this.textColor,
  });

  final int playerId;
  final int life;
  final void Function(int delta) onDelta;
  final int pendingDelta;
  final Color? textColor;

  @override
  ConsumerState<LifeDial> createState() => _LifeDialState();
}

class _LifeDialState extends ConsumerState<LifeDial> {
  Timer? _longPressTimer;
  Offset? _downPosition;

  /// Le pointeur actuellement surveillé pour l'appui long (le premier à
  /// s'être posé sur la zone). Round 3 de revue (Critical #1 ressuscité en
  /// multi-touch) : `_downPosition` et `_longPressTimer` sont uniques, alors
  /// que Flutter peut suivre plusieurs pointeurs en même temps sur ce widget
  /// (l'appareil est posé à plat, un second doigt sur la zone est ordinaire,
  /// pas un cas limite). Sans cette référence, le `down` d'un second doigt
  /// écrase `_downPosition` du premier et relance sa veille d'appui long ; un
  /// micro-mouvement du premier doigt est alors mesuré depuis la position du
  /// second, à des dizaines de pixels de distance, ce qui annule à tort la
  /// veille d'appui long du premier doigt sans jamais rejeter son tap.
  /// On n'arme donc la veille que pour le premier pointeur actif, et on
  /// ignore tous les autres jusqu'à ce qu'il se relâche.
  int? _trackedPointer;

  /// Le delta qu'un tap en cours émettra à son relâchement (`onTapUp`), s'il
  /// n'est pas entre-temps annulé par un glissement (`onTapCancel`) ou par
  /// l'appui long qui gagne (voir `_startLongPressWatch`).
  int? _pendingTapDelta;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _emit(int delta) {
    HapticFeedback.selectionClick();
    widget.onDelta(delta);
  }

  void _startHold(int delta) {
    _pendingTapDelta = delta;
  }

  /// `onTapUp` : le tap est confirmé — on émet son delta maintenant (et
  /// seulement maintenant : spec §2.5, un tap simple doit tout de même
  /// produire son ±1, le report au relâchement est imperceptible pour
  /// l'utilisateur), sauf si l'appui long l'a déjà annulé entre-temps.
  void _confirmTap() {
    final delta = _pendingTapDelta;
    _cancelPress();
    if (delta != null) _emit(delta);
  }

  /// `onTapCancel` (glissement détecté par le `TapGestureRecognizer`) ou
  /// appui long gagnant : annule tout net, aucun delta ne doit sortir.
  void _cancelPress() {
    _pendingTapDelta = null;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.textColor ?? AppColors.textPrimary;
    final isAdjusting =
        ref.watch(playerZoneNotifierProvider(widget.playerId)).isAdjusting;
    final notifier =
        ref.read(playerZoneNotifierProvider(widget.playerId).notifier);

    // Le long press est capté hors de l'arène de gestes des moitiés : un
    // `Listener` observe les événements bruts en parallèle des
    // `GestureDetector` imbriqués (moitiés, paliers) sans y participer, donc
    // sans jamais leur faire perdre l'arène (un `LongPressGestureRecognizer`
    // concurrent ferait perdre le tap de la moitié dès qu'il gagne, ce qui a
    // cassé le test de maintien à la ronde précédente).
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        // Round 3 (Critical #1 ressuscité) : un seul pointeur à la fois
        // arme la veille d'appui long — voir la note sur `_trackedPointer`.
        if (_trackedPointer != null) return;
        _trackedPointer = event.pointer;
        _downPosition = event.position;
        _startLongPressWatch(notifier);
      },
      onPointerMove: (event) {
        if (event.pointer != _trackedPointer) return;
        if (isAdjusting) {
          // Round 2 (Important #1) : un glissement de molette maintenu plus
          // de 500 ms ré-arme sinon un appui long qui remettrait
          // `wheelAccumulator` à zéro en plein geste — l'appui long n'a plus
          // de raison d'être dès qu'on bouge en mode ajustement.
          _cancelLongPressWatch();
          final steps = notifier.handleWheelDrag(event.delta.dy);
          if (steps != 0) _emit(steps);
        } else {
          // Round 2 (Critical #2) : un doigt « immobile » sur un écran
          // capacitif émet en continu des micro-mouvements de 1 à 3 px.
          // Annuler l'appui long au premier pixel rendrait le mode
          // ajustement quasi inatteignable sur appareil réel ; on tolère
          // donc la même marge que `LongPressGestureRecognizer`
          // ([kTouchSlop]) avant de considérer que c'est un glissement.
          final downPosition = _downPosition;
          if (downPosition != null &&
              (event.position - downPosition).distance > kTouchSlop) {
            _cancelLongPressWatch();
          }
        }
      },
      // N'arrête ici que l'appui long : le `Listener` racine reçoit le
      // relâchement *avant* que l'arène de la moitié ne se résolve (son
      // callback brut s'exécute pendant le routage, alors que `onTapUp` n'est
      // appelé qu'au balayage de l'arène qui suit) — y annuler aussi le tap
      // en attente le viderait avant que `_confirmTap` ne puisse l'émettre.
      // La moitié restant montée en permanence (voir plus bas), c'est elle
      // qui gère fiablement son propre tap via `onTapUp`/`onTapCancel`.
      onPointerUp: (event) {
        if (event.pointer != _trackedPointer) return;
        _trackedPointer = null;
        _cancelLongPressWatch();
      },
      onPointerCancel: (event) {
        if (event.pointer != _trackedPointer) return;
        _trackedPointer = null;
        _cancelLongPressWatch();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Les moitiés restent montées en permanence (jamais retirées de
          // l'arbre) : les enlever couperait net le pointeur en cours (Flutter
          // annule un geste quand le widget qu'il touche disparaît), ce qui
          // interromprait son tap en plein geste dès l'entrée en mode
          // ajustement. `IgnorePointer` les neutralise sans les démonter.
          IgnorePointer(
            ignoring: isAdjusting,
            child: Row(
              children: [
                Expanded(child: _half(-1)),
                Expanded(child: _half(1)),
              ],
            ),
          ),
          IgnorePointer(child: _readout(color)),
          if (isAdjusting) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: notifier.exitAdjustMode,
              child: const SizedBox.expand(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _stepRow(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _readout(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${widget.life}',
            style: AppTextStyles.lifeNumeral(color: color),
          ),
        ),
        if (widget.pendingDelta != 0)
          Text(
            widget.pendingDelta > 0
                ? '+${widget.pendingDelta}'
                : '${widget.pendingDelta}',
            style: AppTextStyles.lifeBadge(
              color: widget.pendingDelta > 0
                  ? AppColors.accentGreen
                  : AppColors.accentRed,
            ),
          ),
      ],
    );
  }

  /// Paliers ±5 / ±10 (spec §2.4). Ils couvrent les montants ronds ; la
  /// molette couvre le reste.
  Widget _stepRow() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final delta in const [-10, -5, 5, 10])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _emit(delta),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: delta < 0
                          ? AppColors.accentRed.withAlpha(40)
                          : AppColors.accentGreen.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      delta > 0 ? '+$delta' : '$delta',
                      style: AppTextStyles.lifeStepLabel(
                        color: delta < 0
                            ? AppColors.accentRed
                            : AppColors.accentGreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Démarre la détection manuelle de l'appui long (voir la note dans
  /// [build]). Utilise le même délai que [LongPressGestureRecognizer] par
  /// défaut, pour rester cohérent avec `WidgetTester.longPress`.
  void _startLongPressWatch(PlayerZoneNotifier notifier) {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(kLongPressTimeout, () {
      if (!mounted) return;
      // Round 2 (Critical #1) : l'appui long gagne — le tap en attente sur
      // la moitié touchée est annulé avant de basculer, pour qu'aucun ±1 ne
      // fuite au moment de l'entrée en mode ajustement.
      _cancelPress();
      HapticFeedback.mediumImpact();
      notifier.enterAdjustMode();
    });
  }

  void _cancelLongPressWatch() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  Widget _half(int delta) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(delta),
      onTapUp: (_) => _confirmTap(),
      onTapCancel: _cancelPress,
      child: const SizedBox.expand(),
    );
  }
}
