// lib/widgets/life_counter/zone/life_dial.dart
// Surface de geste des points de vie (spec §2.1).
//
// Le chiffre occupe toute la zone. Tap à gauche = −1, à droite = +1, maintien
// = répétition accélérée. Le widget n'applique rien : il émet des deltas, que
// life_counter_page accumule dans son buffer de 2 s.

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

  /// Délai avant que le maintien ne commence à répéter.
  static const Duration holdRepeatInitialDelay = Duration(milliseconds: 400);

  /// Cadence la plus rapide que la répétition puisse atteindre.
  static const Duration holdRepeatMinInterval = Duration(milliseconds: 60);

  @override
  ConsumerState<LifeDial> createState() => _LifeDialState();
}

class _LifeDialState extends ConsumerState<LifeDial> {
  Timer? _repeatTimer;
  int _repeatCount = 0;
  Timer? _longPressTimer;
  Timer? _pendingEmitTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _longPressTimer?.cancel();
    _pendingEmitTimer?.cancel();
    super.dispose();
  }

  void _emit(int delta) {
    HapticFeedback.selectionClick();
    widget.onDelta(delta);
  }

  /// Le premier delta d'un appui est différé d'un tick (délai nul, imperceptible
  /// pour l'utilisateur réel) plutôt qu'émis en synchrone dans `onTapDown`.
  ///
  /// Sans ce report, un glissement vertical qui démarre sur une moitié (hors
  /// mode ajustement, où le glissement ne doit rien faire — spec §2.5)
  /// émettrait quand même son ±1 initial avant que le `TapGestureRecognizer`
  /// n'ait eu la chance de détecter le mouvement et de rejeter le tap. Le
  /// report laisse `onTapCancel` (déclenché par ce rejet, voir `_cancelPress`)
  /// annuler l'émission avant qu'elle n'ait lieu.
  void _startHold(int delta) {
    _pendingEmitTimer?.cancel();
    _pendingEmitTimer = Timer(Duration.zero, () => _commitHold(delta));
  }

  void _commitHold(int delta) {
    if (!mounted) return;
    _emit(delta);
    _repeatCount = 0;
    _repeatTimer?.cancel();
    _repeatTimer = Timer(
      LifeDial.holdRepeatInitialDelay,
      () => _repeat(delta),
    );
  }

  /// Répétition accélérée : l'intervalle se resserre à chaque coup, jusqu'à
  /// [LifeDial.holdRepeatMinInterval]. Sans accélération, retirer 8 points au
  /// maintien serait plus lent que huit taps.
  ///
  /// Le pas de 40 ms (plutôt que 20) est calibré pour qu'une fenêtre de 500 ms
  /// prise après le délai initial produise strictement plus de répétitions
  /// que la fenêtre des 500 ms précédente (voir le test de répétition
  /// accélérée) : avec un pas de 20 ms, les deux fenêtres produisent le même
  /// nombre de deltas et le test échoue.
  void _repeat(int delta) {
    if (!mounted) return;
    _emit(delta);
    _repeatCount++;
    final ms = (260 - _repeatCount * 40)
        .clamp(LifeDial.holdRepeatMinInterval.inMilliseconds, 260);
    _repeatTimer = Timer(Duration(milliseconds: ms), () => _repeat(delta));
  }

  /// Relâchement normal (`onTapUp`) : arrête la répétition mais laisse
  /// l'émission différée en cours suivre son cours — un tap bref doit tout de
  /// même émettre son delta.
  void _stopHold() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatCount = 0;
  }

  /// `onTapCancel` : le `TapGestureRecognizer` vient de rejeter le tap, le
  /// plus souvent parce que le pointeur a bougé au-delà de la tolérance —
  /// c'est un glissement, pas un tap. On annule aussi l'émission différée :
  /// hors mode ajustement, un glissement ne doit produire aucun delta.
  void _cancelPress() {
    _pendingEmitTimer?.cancel();
    _pendingEmitTimer = null;
    _stopHold();
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
    // sans jamais leur faire perdre l'arène (voir le test de maintien qui
    // répète pendant 1.5 s sans jamais basculer en mode ajustement).
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _startLongPressWatch(notifier),
      onPointerMove: (event) {
        if (isAdjusting) {
          final steps = notifier.handleWheelDrag(event.delta.dy);
          if (steps != 0) _emit(steps);
        } else if ((event.delta.dx.abs() > 0 || event.delta.dy.abs() > 0)) {
          _cancelLongPressWatch();
        }
      },
      // Le relâchement (ou l'annulation) arrête la répétition ici, au
      // niveau racine : si le mode ajustement a basculé pendant un maintien
      // sur une moitié, celle-ci a disparu de l'arbre et son propre
      // `onTapUp`/`onTapCancel` ne se déclenchera pas — sans ce filet, la
      // répétition ne s'arrêterait jamais (voir le test « relâcher arrête
      // la répétition »).
      onPointerUp: (_) {
        _stopHold();
        _cancelLongPressWatch();
      },
      onPointerCancel: (_) {
        _stopHold();
        _cancelLongPressWatch();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Les moitiés restent montées en permanence (jamais retirées de
          // l'arbre) : les enlever couperait net le pointeur en cours (Flutter
          // annule un geste quand le widget qu'il touche disparaît), ce qui
          // arrêterait la répétition en plein maintien dès l'entrée en mode
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
      onTapUp: (_) => _stopHold(),
      onTapCancel: _cancelPress,
      child: const SizedBox.expand(),
    );
  }
}
