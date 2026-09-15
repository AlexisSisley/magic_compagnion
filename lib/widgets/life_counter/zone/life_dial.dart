// lib/widgets/life_counter/zone/life_dial.dart
// Surface de geste des points de vie (spec §2.1).
//
// Le chiffre occupe toute la zone. Tap à gauche = −1, à droite = +1, maintien
// = répétition accélérée. Le widget n'applique rien : il émet des deltas, que
// life_counter_page accumule dans son buffer de 2 s.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _emit(int delta) {
    HapticFeedback.selectionClick();
    widget.onDelta(delta);
  }

  void _startHold(int delta) {
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

  void _stopHold() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.textColor ?? AppColors.textPrimary;

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: _half(-1)),
            Expanded(child: _half(1)),
          ],
        ),
        IgnorePointer(
          child: Column(
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
          ),
        ),
      ],
    );
  }

  Widget _half(int delta) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(delta),
      onTapUp: (_) => _stopHold(),
      onTapCancel: _stopHold,
      child: const SizedBox.expand(),
    );
  }
}
