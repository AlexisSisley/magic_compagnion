// lib/widgets/life_counter/zone/orientation_picker.dart
// Quatre flèches : le bord vers lequel le joueur regarde (spec §1.7).
//
// Remplace un bouton qui faisait tourner la zone d'un quart de tour par
// appui. Pour atteindre 270° il fallait taper trois fois, et rien
// n'indiquait où l'on allait. Ici, une touche suffit pour n'importe quelle
// orientation, et la flèche active dit où l'on est.

import 'package:flutter/material.dart';
import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

class OrientationPicker extends StatelessWidget {
  const OrientationPicker({
    super.key,
    required this.quarterTurns,
    required this.onChanged,
  });

  final int quarterTurns;
  final ValueChanged<int> onChanged;

  /// Chaque flèche désigne un CÔTÉ de la table, pas un angle : le quart de
  /// tour qu'elle émet est lu dans `TableSide.quarterTurns`
  /// (lib/models/table_seat.dart), seule correspondance côté → rotation du
  /// code (Ruling 49 -- la première version recopiait la table ici). La
  /// flèche désigne le bord de l'écran vers lequel pointe le PIED du texte de
  /// la zone, donc le côté où le joueur est assis : colonne gauche à 90° → ◀
  /// actif, colonne droite à 270° → ▶ actif, comme sur la maquette. Libellés
  /// repris tels quels du plan.
  static const Map<TableSide, (IconData, String)> _directions = {
    TableSide.bottom: (Icons.keyboard_arrow_down, 'Regarde vers le bas'),
    TableSide.left: (Icons.keyboard_arrow_left, 'Regarde vers la gauche'),
    TableSide.top: (Icons.keyboard_arrow_up, 'Regarde vers le haut'),
    TableSide.right: (Icons.keyboard_arrow_right, 'Regarde vers la droite'),
  };

  /// Taille d'une case de la croix. 48, pas les 34 de la maquette : aucune
  /// cible tactile sous `kMinInteractiveDimension`, c'est le défaut même que
  /// cette refonte existe pour éliminer.
  static const double _cell = kMinInteractiveDimension;

  @override
  Widget build(BuildContext context) {
    final active = quarterTurns % 4;
    // Croix 3×3 de la maquette : ▲ en haut au centre, ◀ et ▶ au milieu,
    // ▼ en bas, l'angle courant au centre. Les coins restent vides. Chaque
    // case est placée par son CÔTÉ ; son quart de tour vient du modèle.
    return SizedBox(
      width: _cell * 3,
      height: _cell * 3,
      child: Column(
        children: [
          Row(children: [_gap(), _arrow(TableSide.top, active), _gap()]),
          Row(children: [
            _arrow(TableSide.left, active),
            SizedBox(
              width: _cell,
              height: _cell,
              child: Center(
                child: Text(
                  '${active * 90}°',
                  key: const ValueKey('orientation-angle'),
                  style: AppTextStyles.text(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            _arrow(TableSide.right, active),
          ]),
          Row(children: [_gap(), _arrow(TableSide.bottom, active), _gap()]),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(width: _cell, height: _cell);

  Widget _arrow(TableSide side, int active) {
    final (icon, label) = _directions[side]!;
    final turns = side.quarterTurns;
    final isActive = turns == active;
    // Pas d'`IconButton` ni de `tooltip` : le `Tooltip` arme son propre appui
    // long (500 ms), qui gagnerait l'arène contre celui de `LongPressDraggable`
    // (1 s) -- on ne pourrait plus déplacer une zone en commençant le geste
    // sur une flèche. Le libellé passe donc par `Semantics`.
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: SizedBox(
        key: ValueKey('orientation-arrow-$turns'),
        width: _cell,
        height: _cell,
        // L'`InkWell` couvre toute la case de 48 : le disque visible, un peu
        // plus petit, n'est que le dessin -- la cible, elle, ne rétrécit pas.
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(turns),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isActive ? AppColors.primary : AppColors.surfaceDarkest,
                  border: isActive
                      ? null
                      : Border.all(color: AppColors.borderMedium),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 26,
                    color: isActive
                        ? AppColors.textOnPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
