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
    this.textColor,
  });

  final int playerId;
  final int life;
  final void Function(int delta) onDelta;
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

  /// Dernière position brute connue du pointeur (mise à jour à chaque
  /// `onPointerDown`/`onPointerMove` du `Listener` racine, quel que soit le
  /// mode). Sert de secours à `_endAdjustGesture` quand `onTapCancel` se
  /// déclenche : contrairement à `onTapUp`, `TapCancelDetails` ne porte
  /// aucune position, alors que la fermeture du mode ajustement doit tout de
  /// même pouvoir résoudre le palier survolé.
  Offset? _lastGlobalPosition;

  /// Les deltas dont le tap est en cours (posés, pas encore relâchés), en
  /// attente d'émission à `onTapUp`.
  ///
  /// Round 3 de revue (Important, chevauchement multi-touch) : un seul
  /// nullable partagé entre les deux moitiés se faisait écraser quand un
  /// second doigt se posait sur l'autre moitié pendant que le premier était
  /// encore en cours — au mieux le premier delta ne sortait jamais, au pire
  /// le relâchement du premier doigt émettait le delta laissé par le second
  /// (un tap sur « −1 » appliquant en fait « +1 »). Indexé par moitié (le
  /// delta lui-même, -1 ou +1, sert de clé stable) plutôt que par pointeur :
  /// restreindre au pointeur suivi par l'appui long (`_trackedPointer`)
  /// aurait bloqué le tap légitime d'un second doigt tant que le premier
  /// reste posé, ce qui n'est pas souhaitable sur un appareil à plat à
  /// quatre joueurs.
  final Set<int> _pendingTaps = {};

  /// Fraction de la largeur de la zone laissée libre de chaque côté de la
  /// rangée de paliers (spec §5.4). La rangée pleine largeur retombait
  /// exactement là où le pouce arrive au relâchement, ce qui faisait
  /// modifier les PV par accident — voir le bug rapporté sur cette tâche.
  static const double _stepRowSideMargin = 0.18;

  /// Une `GlobalKey` par palier, pour retrouver son rectangle à l'écran sans
  /// jamais calculer sa position à la main (`_stepUnder`).
  final Map<int, GlobalKey> _stepKeys = {
    for (final delta in const [-10, -5, 5, 10]) delta: GlobalKey(),
  };

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _trackedPointer = null;
    _downPosition = null;
    _lastGlobalPosition = null;
    super.dispose();
  }

  void _emit(int delta) {
    HapticFeedback.selectionClick();
    widget.onDelta(delta);
  }

  void _startHold(int delta) {
    _pendingTaps.add(delta);
  }

  /// `onTapUp` de la moitié `delta` : le tap est confirmé — on émet ce delta
  /// précis maintenant (et seulement maintenant : spec §2.5, un tap simple
  /// doit tout de même produire son ±1, le report au relâchement est
  /// imperceptible pour l'utilisateur), sauf si l'appui long l'a déjà annulé
  /// entre-temps.
  void _confirmTap(int delta) {
    if (_pendingTaps.remove(delta)) _emit(delta);
  }

  /// `onTapCancel` de la moitié `delta` (glissement détecté par le
  /// `TapGestureRecognizer`) : annule ce tap précis, sans toucher à l'autre
  /// moitié si elle a elle aussi un tap en cours.
  void _cancelPress(int delta) {
    _pendingTaps.remove(delta);
  }

  /// L'appui long gagne : les deux moitiés doivent être annulées, pas
  /// seulement celle sous le pointeur suivi — voir le doc-comment de
  /// `_pendingTaps`.
  void _cancelAllPendingTaps() {
    _pendingTaps.clear();
  }

  /// Palier dont le bouton contient [globalPosition], ou `null`.
  ///
  /// Les boutons sont retrouvés par leur `GlobalKey` : aucune position n'est
  /// calculée à la main, ce qui reste juste quelle que soit la rotation du
  /// siège — un point sur lequel ce projet s'est déjà trompé neuf fois.
  int? _stepUnder(Offset? globalPosition) {
    if (globalPosition == null) return null;
    for (final entry in _stepKeys.entries) {
      final box = entry.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final origin = box.localToGlobal(Offset.zero);
      if ((origin & box.size).contains(globalPosition)) return entry.key;
    }
    return null;
  }

  /// Fin du geste en mode ajustement : on applique le palier survolé, s'il y
  /// en a un, puis on sort du mode dans tous les cas.
  ///
  /// Le mode ne survit pas au doigt (spec §5.1). L'amendement de la spec V4
  /// §2.5 avait écarté cette fermeture au motif que les paliers deviendraient
  /// inatteignables — ce qui n'est vrai que s'il faut LEVER le doigt pour
  /// taper. Avec un glissé-relâché, ils restent atteignables sans jamais
  /// rompre le contact.
  void _endAdjustGesture(PlayerZoneNotifier notifier, Offset? globalPosition) {
    final delta = _stepUnder(globalPosition);
    if (delta != null) _emit(delta);
    notifier.exitAdjustMode();
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
    //
    // `LayoutBuilder` donne à la rangée de paliers sa propre largeur
    // (`_stepRow` en a besoin pour ses marges latérales, spec §5.4) sans la
    // faire descendre depuis `PlayerZone` : `LifeDial` la lit lui-même.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            // Round 3 (Critical #1 ressuscité) : un seul pointeur à la fois
            // arme la veille d'appui long — voir la note sur `_trackedPointer`.
            _lastGlobalPosition = event.position;
            if (_trackedPointer != null) return;
            _trackedPointer = event.pointer;
            _downPosition = event.position;
            _startLongPressWatch(notifier);
          },
          onPointerMove: (event) {
            _lastGlobalPosition = event.position;
            if (event.pointer != _trackedPointer) return;
            if (isAdjusting) {
              // Round 2 (Important #1) : un glissement de molette maintenu plus
              // de 500 ms ré-arme sinon un appui long qui remettrait
              // `wheelAccumulator` à zéro en plein geste — l'appui long n'a plus
              // de raison d'être dès qu'on bouge en mode ajustement.
              _cancelLongPressWatch();
              // Tâche 7 : tant que le doigt survole un palier, la molette ne
              // doit pas accumuler en parallèle — sans quoi glisser jusqu'à
              // « -5 » ferait AUSSI tourner la molette sur tout le trajet, et
              // le relâchement appliquerait les deux à la fois (contraire à
              // « un seul geste continu, un seul effet »). La zone des
              // paliers est une cible de sélection, pas une extension de la
              // molette.
              if (_stepUnder(event.position) == null) {
                final steps = notifier.handleWheelDrag(event.delta.dy);
                if (steps != 0) _emit(steps);
              }
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
          // qui gère fiablement son propre tap via `onTapUp`/`onTapCancel`, et
          // désormais aussi la fermeture du mode ajustement (`_endAdjustGesture`).
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
                    Expanded(child: _half(-1, isAdjusting, notifier)),
                    Expanded(child: _half(1, isAdjusting, notifier)),
                  ],
                ),
              ),
              IgnorePointer(child: _readout(color)),
              if (isAdjusting)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _stepRow(constraints.maxWidth),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _readout(Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${widget.life}',
        style: AppTextStyles.lifeNumeral(color: color),
      ),
    );
  }

  /// Paliers ±5 / ±10 (spec §2.4). Ils couvrent les montants ronds ; la
  /// molette couvre le reste.
  ///
  /// Aucun bouton ne porte plus son propre `GestureDetector` : la sélection
  /// se fait en glissant le doigt de l'appui long jusqu'ici, sans jamais le
  /// lever (`_endAdjustGesture` résout le palier survolé via `_stepKeys` au
  /// relâchement). Chaque bouton ne sert donc que de cible géométrique.
  Widget _stepRow(double zoneWidth) {
    final inset = zoneWidth * _stepRowSideMargin;
    return Padding(
      // La clé porte sur la `Row`, pas sur ce `Padding` : un `Padding` qui
      // déflate puis relaie une largeur illimitée à son enfant (une `Row` en
      // `mainAxisSize.max`, le défaut) reprend exactement la largeur qu'il
      // vient de retirer — son PROPRE rendu mesure donc toujours la largeur
      // du parent, quel que soit `inset`. Le test de géométrie (§5.4) doit
      // mesurer la largeur réellement resserrée, pas celle de ce wrapper.
      padding: EdgeInsets.fromLTRB(inset, 8, inset, 8),
      // `IntrinsicHeight` borne la hauteur de la rangée à celle de son
      // contenu : sans lui, chaque bouton (dont le `Container` a un
      // `alignment` non nul) s'étire pour remplir toute la hauteur lâche mais
      // bornée que lui offre l'`Align(bottomCenter)` du `Stack` — soit
      // quasiment toute la hauteur du cadran, ce qui rendrait n'importe quel
      // relâchement (même loin du bas visuel) éligible à un palier.
      child: IntrinsicHeight(
        child: Row(
          key: const ValueKey('life_step_row'),
          children: [
            for (final delta in const [-10, -5, 5, 10])
              Expanded(
                child: Padding(
                  key: ValueKey('life_step_$delta'),
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    key: _stepKeys[delta],
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
          ],
        ),
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
      // Round 2 (Critical #1) : l'appui long gagne — tout tap en attente,
      // sur l'une ou l'autre moitié, est annulé avant de basculer, pour
      // qu'aucun ±1 ne fuite au moment de l'entrée en mode ajustement.
      _cancelAllPendingTaps();
      HapticFeedback.mediumImpact();
      notifier.enterAdjustMode();
    });
  }

  void _cancelLongPressWatch() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  /// [isAdjusting] et [notifier] sont capturés au moment du `build()` : la
  /// moitié restant montée en permanence (voir la note dans [build]), c'est
  /// le `RawGestureDetectorState` sous-jacent qui met à jour ces callbacks à
  /// chaque reconstruction, sans jamais perdre le pointeur qu'il suit déjà —
  /// ce qui permet à `onTapUp`/`onTapCancel` de refléter le mode courant même
  /// pour un doigt posé avant l'entrée en mode ajustement.
  Widget _half(int delta, bool isAdjusting, PlayerZoneNotifier notifier) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(delta),
      onTapUp: (details) {
        if (isAdjusting) {
          _endAdjustGesture(notifier, details.globalPosition);
        } else {
          _confirmTap(delta);
        }
      },
      onTapCancel: () {
        if (isAdjusting) {
          _endAdjustGesture(notifier, _lastGlobalPosition);
        } else {
          _cancelPress(delta);
        }
      },
      child: const SizedBox.expand(),
    );
  }
}
