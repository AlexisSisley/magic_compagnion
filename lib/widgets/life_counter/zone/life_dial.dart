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

  /// [silent] marque un delta qui n'est PAS un geste utilisateur mais une
  /// correction interne (round de correction 3, spec) : l'annulation de la
  /// molette croisée en route vers un palier (voir `_wheelSumSinceAdjust`).
  /// L'appelant ne doit alors jouer ni bulle de nombre flottant, ni
  /// pulsation/tremblement, ni retour haptique — seule la mutation de vie
  /// elle-même (déjà nette au buffer, voir `onLifeChanged`) doit avoir lieu.
  final void Function(int delta, {bool silent}) onDelta;
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

  /// Somme des deltas de molette émis depuis l'entrée en mode ajustement
  /// courante (remise à zéro par `_startLongPressWatch` à chaque nouvelle
  /// entrée).
  ///
  /// Round de correction 2 : la rangée de paliers est ANCRÉE EN BAS du
  /// cadran, donc tout glissé vers un palier est un glissé VERS LE BAS —
  /// exactement la direction de la molette (`wheelPixelsPerUnit` = 8px). Le
  /// garde `_stepUnder(event.position) == null` de la tâche 7 ne suspend la
  /// molette QUE pendant le survol du bouton, jamais pendant le TRAJET qui y
  /// mène (~80px sur un cadran de 300px, soit une dizaine de points émis en
  /// route). Le geste est pourtant censé être atomique (« du doigt posé au
  /// doigt levé ») : si le relâchement tombe sur un palier, ce palier doit
  /// être le SEUL effet du geste. On accumule donc tout ce que la molette a
  /// émis pendant le geste, pour l'annuler dans `_endAdjustGesture` si (et
  /// seulement si) le relâchement atterrit sur un palier.
  ///
  /// Round de correction 3 (Important — le commentaire précédent affirmait le
  /// contraire, à tort) : le NET est juste (le buffer de la page ne voit que
  /// la somme), mais l'annulation elle-même reste VISIBLE tant que le delta
  /// d'annulation n'est pas explicitement marqué `silent` — `onDelta` aboutit
  /// aussi à `PlayerZone._triggerChange`, qui affiche une bulle de nombre
  /// flottant et joue une pulsation/tremblement pour CHAQUE delta reçu, pas
  /// seulement le net. Sans le paramètre `silent`, l'utilisateur verrait donc
  /// les bulles de la molette prises en route, PUIS une bulle « +9 » (ou
  /// équivalent) annonçant un gain de vie qui n'a jamais eu lieu, avant celle
  /// du palier — d'où `_emit(..., silent: true)` dans `_endAdjustGesture`.
  int _wheelSumSinceAdjust = 0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _trackedPointer = null;
    _downPosition = null;
    _wheelSumSinceAdjust = 0;
    super.dispose();
  }

  void _emit(int delta, {bool silent = false}) {
    if (!silent) HapticFeedback.selectionClick();
    widget.onDelta(delta, silent: silent);
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
  int? _stepUnder(Offset globalPosition) {
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
  ///
  /// Round de correction 1 : appelée UNIQUEMENT depuis `onPointerUp` du
  /// `Listener` racine (événement brut), jamais depuis `onTapUp`/`onTapCancel`
  /// du `GestureDetector` d'une moitié. Ces deux derniers se déclenchent à la
  /// résolution de l'ARÈNE, pas au lever du doigt : `onTapCancel` en
  /// particulier part dès que le pointeur dépasse `kTouchSlop` (18px), donc en
  /// plein glissement — bien avant que le doigt n'atteigne un palier. Le
  /// relâchement brut (`PointerUpEvent`) est le seul événement qui coïncide
  /// avec le vrai lever du doigt.
  ///
  /// Round de correction 2 : un relâchement sur un palier annule d'abord tout
  /// ce que la molette a émis PENDANT ce même geste (voir le doc-comment de
  /// `_wheelSumSinceAdjust`), pour que le palier reste le seul effet net —
  /// un relâchement hors palier, lui, laisse la molette telle quelle (son
  /// usage normal).
  ///
  /// Round de correction 3 : l'annulation est émise `silent: true` — ce n'est
  /// pas un geste utilisateur, juste une correction interne, et ne doit donc
  /// déclencher ni bulle de nombre flottant, ni pulsation/tremblement, ni
  /// retour haptique (voir le doc-comment de `_wheelSumSinceAdjust` et celui
  /// de `LifeDial.onDelta`). Le palier lui-même reste émis normalement (seul
  /// retour haptique du geste).
  void _endAdjustGesture(PlayerZoneNotifier notifier, Offset globalPosition) {
    final delta = _stepUnder(globalPosition);
    if (delta != null) {
      if (_wheelSumSinceAdjust != 0) {
        _emit(-_wheelSumSinceAdjust, silent: true);
      }
      _emit(delta);
    }
    _wheelSumSinceAdjust = 0;
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
              // Tâche 7 : tant que le doigt survole un palier, la molette ne
              // doit pas accumuler en parallèle — sans quoi glisser jusqu'à
              // « -5 » ferait AUSSI tourner la molette sur tout le trajet, et
              // le relâchement appliquerait les deux à la fois (contraire à
              // « un seul geste continu, un seul effet »). La zone des
              // paliers est une cible de sélection, pas une extension de la
              // molette.
              if (_stepUnder(event.position) == null) {
                final steps = notifier.handleWheelDrag(event.delta.dy);
                if (steps != 0) {
                  // Round de correction 3 : chaque pas de molette est émis
                  // `silent: true`. Tant que le geste est en cours, on ne
                  // sait pas encore s'il se terminera sur un palier — et s'il
                  // s'y termine, ce pas sera annulé par `_endAdjustGesture`
                  // (voir `_wheelSumSinceAdjust`) : lui faire jouer bulle et
                  // haptique en temps réel produirait alors, sur un
                  // glissement réaliste vers un palier, une dizaine de bulles
                  // qui ne correspondent à aucun effet final -- exactement ce
                  // que la revue a mesuré et refusé. Le NET reste juste dans
                  // tous les cas (`onLifeChanged` est appelé pour chaque pas,
                  // silencieux ou non) : seul le retour visuel/haptique
                  // temps réel de la molette est sacrifié en mode ajustement,
                  // au profit d'un geste qui ne raconte que son effet final.
                  _emit(steps, silent: true);
                  // Round de correction 2 : mémorisé pour être annulé si le
                  // geste se termine sur un palier (voir le doc-comment de
                  // `_wheelSumSinceAdjust`).
                  _wheelSumSinceAdjust += steps;
                }
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
          // Round de correction 1 : c'est ICI, sur l'événement brut, que se
          // résout le mode ajustement — jamais sur `onTapUp`/`onTapCancel` du
          // `GestureDetector` d'une moitié (voir le doc-comment de
          // `_endAdjustGesture`). Hors mode ajustement, ce `Listener` ne fait
          // qu'arrêter la veille d'appui long ; la moitié gère alors seule son
          // propre tap via `onTapUp`/`onTapCancel`, qui restent câblés
          // uniquement sur `_confirmTap`/`_cancelPress` (jamais sur le mode
          // ajustement).
          onPointerUp: (event) {
            if (event.pointer != _trackedPointer) return;
            _trackedPointer = null;
            _cancelLongPressWatch();
            if (isAdjusting) {
              _endAdjustGesture(notifier, event.position);
            }
          },
          onPointerCancel: (event) {
            if (event.pointer != _trackedPointer) return;
            _trackedPointer = null;
            _cancelLongPressWatch();
            // Un `PointerCancelEvent` (interruption système, pas un
            // relâchement délibéré) sort du mode sans appliquer de palier :
            // il n'y a pas de position de relâchement à faire confiance ici.
            //
            // Round de correction 3 (MINOR mais porteur) : remet aussi
            // `_wheelSumSinceAdjust` à zéro ici, plutôt que de compter sur la
            // remise à zéro de la PROCHAINE entrée en mode ajustement — ce
            // chemin ne passe jamais par `_endAdjustGesture` (pas de palier à
            // résoudre), donc rien d'autre ne nettoie ce compteur, qui
            // resterait sinon sale jusqu'à la prochaine ouverture du mode et
            // fausserait son annulation.
            if (isAdjusting) notifier.exitAdjustMode();
            _wheelSumSinceAdjust = 0;
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
      // Round de correction 2 : nouvelle entrée en mode ajustement, nouveau
      // geste à comptabiliser depuis zéro (voir `_wheelSumSinceAdjust`).
      _wheelSumSinceAdjust = 0;
      HapticFeedback.mediumImpact();
      notifier.enterAdjustMode();
    });
  }

  void _cancelLongPressWatch() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  /// `onTapUp`/`onTapCancel` ne connaissent QUE le tap ±1 (spec §2.1),
  /// jamais le mode ajustement : câbler `_endAdjustGesture` ici serait faux,
  /// parce que ces deux callbacks se déclenchent à la résolution de
  /// l'ARÈNE de gestes, pas au lever du doigt — `onTapCancel` en particulier
  /// part dès que le pointeur dépasse `kTouchSlop` (18px), donc en plein
  /// glissement vers un palier, bien avant que le doigt ne l'atteigne. Voir
  /// le doc-comment de `_endAdjustGesture`, câblée uniquement sur
  /// `onPointerUp` du `Listener` racine.
  Widget _half(int delta) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _startHold(delta),
      onTapUp: (_) => _confirmTap(delta),
      onTapCancel: () => _cancelPress(delta),
      child: const SizedBox.expand(),
    );
  }
}
