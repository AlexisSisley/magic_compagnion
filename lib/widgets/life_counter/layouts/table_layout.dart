import 'dart:math' as math;
import 'dart:ui';

import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart';

/// Forme que prend l'accès aux actions de partie.
enum ActionBarKind {
  /// Bouton rond au centre de la table, qui ouvre une feuille. Petit écran.
  hub,

  /// Bande horizontale entre les deux moitiés. Grand écran.
  band,
}

/// Largeur minimale d'une colonne latérale : le plancher de la zone, plus une
/// marge de respiration sans laquelle la colonne est techniquement conforme et
/// visuellement inutilisable.
const double kSideColumnNeed = kZoneShortEdgeFloor + 26.0;

const int kActionCount = 8;
const double kActionWidth = 36.0;
const double kActionGap = 4.0;

/// Largeur naturelle de la bande d'actions : les huit actions, sans défilement.
const double kBandNeed = kActionCount * (kActionWidth + kActionGap) + kActionGap;

/// Place réservée au centre pour le hub et son pourtour tapable.
const double kHubNeed = 160.0;

/// Petit côté à partir duquel un écran est considéré comme grand.
const double kLargeScreenShortEdge = 600.0;

/// Décision de disposition pour un écran et un nombre de joueurs donnés.
class TableLayout {
  const TableLayout({
    required this.useSideColumns,
    required this.sideWidth,
    required this.barKind,
    required this.seats,
  });

  final bool useSideColumns;
  final double sideWidth;
  final ActionBarKind barKind;

  /// Sièges effectivement retenus. En cas de repli, ce sont ceux du
  /// face-à-face : le reste du code n'a pas à connaître la règle.
  final List<TableSeat> seats;
}

/// Décide de la disposition (spec §3 et §4).
///
/// Le défaut que cette fonction existe pour empêcher : le lot 6 donnait 30 % de
/// la largeur à chaque colonne latérale, quoi qu'il arrive. Sur un écran large,
/// deux joueurs mangeaient 60 % de la surface et la barre d'actions n'avait plus
/// de place — elle se réduisait silencieusement à ses deux premières icônes.
///
/// Ici, une colonne latérale doit être payée EN ENTIER, sur deux critères
/// indépendants, et à défaut il n'y en a aucune.
TableLayout tableLayoutFor(Size size, int playerCount) {
  final shortEdge = math.min(size.width, size.height);
  final barKind = shortEdge < kLargeScreenShortEdge
      ? ActionBarKind.hub
      : ActionBarKind.band;

  TableLayout fallback() => TableLayout(
        useSideColumns: false,
        sideWidth: 0.0,
        barKind: barKind,
        seats: seatsFor(playerCount, allowSideColumns: false),
      );

  final wanted = seatsFor(playerCount);
  final wantsSides = wanted.any(
      (s) => s.side == TableSide.left || s.side == TableSide.right);
  if (!wantsSides) return fallback();

  // Condition de forme : paysage, ou grand écran. Sur un téléphone en
  // portrait, une colonne latérale donne une bande verticale trop étroite pour
  // être lisible même quand elle passe le plancher numérique.
  final shapeAllows =
      size.width > size.height || shortEdge >= kLargeScreenShortEdge;
  if (!shapeAllows) return fallback();

  // Condition de budget : le centre garde d'abord de quoi loger les actions.
  final centreNeed = barKind == ActionBarKind.band ? kBandNeed : kHubNeed;
  if (size.width - 2 * kSideColumnNeed < centreNeed) return fallback();

  // 0.17 est un réglage esthétique pour les grands écrans, JAMAIS la garantie
  // du plancher : celle-ci est portée par le `math.max` ci-dessous, en dur.
  final sideWidth = math.max(
    kSideColumnNeed,
    math.min(size.width * 0.17, (size.width - centreNeed) / 2),
  );

  return TableLayout(
    useSideColumns: true,
    sideWidth: sideWidth,
    barKind: barKind,
    seats: wanted,
  );
}
