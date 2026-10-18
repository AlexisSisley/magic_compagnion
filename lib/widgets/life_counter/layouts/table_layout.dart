import 'dart:math' as math;
import 'dart:ui';

import 'package:magic_companion/models/table_seat.dart';
import 'package:magic_companion/widgets/life_counter/layouts/density_tier.dart'
    show kCompactShortEdge;
import 'package:magic_companion/widgets/life_counter/zone/action_hub.dart';

/// Forme que prend l'accès aux actions de partie.
enum ActionBarKind {
  /// Bouton rond au centre de la table, qui ouvre une feuille. Petit écran.
  hub,

  /// Bande horizontale entre les deux moitiés. Grand écran.
  band,
}

/// Largeur minimale d'une colonne latérale.
///
/// DÉRIVÉE de `kCompactShortEdge`, et non plus de `kZoneShortEdgeFloor`
/// (spec §1.1) : une colonne au plancher absolu tombait au cran `minimal`,
/// donc sans nom ni compteurs, pendant que son voisin de face avait cinq
/// fois la surface. Une colonne se paie désormais au cran `compact`, ou ne
/// se prend pas.
const double kSideColumnNeed = kCompactShortEdge + 26.0;

// Nombre d'actions de `_gameActions` (life_counter_page.dart), rendues à la
// fois par la bande et par le hub : 8 depuis la tâche 8a. Ce compte doit
// suivre la liste, sans quoi `kBandNeed` calcule la largeur de la bande sur
// un compte faux (test « la bande rend exactement kActionCount boutons »).
//
// Historique. Tâche 6 (ronde de correction 1) : les infos de partie, qui
// n'avaient qu'un appui long caché sur le bouton d'orientation, sont
// devenues une action à part entière -- le compte était alors passé à 9.
//
// Tâche 8a : 9 → 8. L'action « Orientation » est retirée -- ses presets
// vivent dans la barre du mode réorganisation, joignable par l'action
// `edit-mode` qui existait déjà. Laisser 9 ici surestimerait la bande d'un
// bouton : pas de débordement, mais un hub monté là où la bande tenait.
const int kActionCount = 8;

// Tâche 6 (ronde de correction 1, option C) : 36.0 était FAUX -- un
// `IconButton` Material mesure 48×48 au minimum
// (`kMinInteractiveDimension`), jamais moins, quoi qu'on lui demande. Cette
// constante mentait depuis l'origine de la bande ; `kBandNeed` sous-estimait
// donc sa largeur réelle depuis toujours (marge réelle mesurée à 8 actions :
// ~10px, jamais vérifiée avant). La neuvième action n'a fait que rendre le
// défaut visible. Porter cette valeur en dessous de 48 pour gagner de la
// place reviendrait à rétrécir la cible tactile minimale -- refusé : c'est
// précisément le bug (taper à côté sur un téléphone posé à plat) que toute
// cette refonte existe pour éliminer. Voir
// `test/widgets/life_counter/layouts/table_layout_test.dart`, groupe
// « kActionWidth reflète la vraie taille rendue », qui compare cette
// constante à la taille mesurée d'un vrai bouton de bande.
const double kActionWidth = 48.0;
const double kActionGap = 4.0;

/// Largeur naturelle de la bande d'actions : toutes les actions, sans défilement.
const double kBandNeed = kActionCount * (kActionWidth + kActionGap) + kActionGap;

/// Marge laissée autour du hub, de chaque côté.
///
/// Revue finale (M3) : ce qui restait d'estimation dans `kHubNeed` est isolé
/// ICI, plutôt que noyé dans un total rond. La valeur conserve le total
/// historique de 160 px, pour qu'aucun seuil de `tableLayoutFor` ne bouge au
/// passage — c'est un exercice d'honnêteté sur la provenance du nombre, pas
/// un changement de comportement.
const double kHubHalo = 52.0;

/// Place réservée au centre pour le hub et son pourtour tapable.
///
/// Revue finale (M3) : DÉRIVÉ du diamètre réel de `ActionHub`, plus une marge
/// de chaque côté. La valeur était auparavant posée en dur (160.0) sans
/// aucun lien avec le widget qu'elle est censée mesurer : rétrécir le hub
/// n'aurait rien changé ici. Aucun cycle d'import — `action_hub.dart` ne
/// dépend que de `material` et du thème.
///
/// Gardé par un test qui MESURE le hub rendu (même famille que le garde-fou
/// de `kActionWidth`, ruling 16).
const double kHubNeed = ActionHub.diameter + 2 * kHubHalo;

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

/// Arrangement retenu pour un écran et un nombre de joueurs (spec §1.4).
///
/// **La règle du grand côté.** Une zone est orientée de façon à ce que son
/// sens de lecture suive son GRAND côté. Une zone plus haute que large
/// reçoit donc un quart de tour ; une zone plus large que haute n'en reçoit
/// pas. C'est pourquoi l'écran déplié (zone 420×350) reste en face-à-face
/// alors que l'écran replié (zone 195×422) passe en colonnes.
///
/// Ruling 23 (18/10/2026) : cette règle ne s'applique QU'À 4 JOUEURS --
/// l'effectif où le tableau du §1.4 la formule et où l'utilisateur l'a
/// demandée. La spec §1.1 fige la disposition des autres effectifs
/// INDÉPENDAMMENT de la forme de l'écran : 2 joueurs en face-à-face, 3
/// joueurs en bandes égales. Une première version de ce brief écrivait la
/// règle pour `playerCount <= 4` : sur les trois formats de téléphone
/// portrait les plus répandus (390×844, 412×915, 360×800), ça retournait
/// `columnPairs` à 2 joueurs -- un joueur à gauche tourné à 90°, l'autre à
/// droite à 270°, au lieu du duel face-à-face haut/bas qui est la
/// configuration la PLUS FRÉQUENTE de l'application. Aucun test ne
/// l'attrapait, le harnais existant ne tournant qu'en paysage 800×600 : voir
/// le groupe « ruling 23 » de `table_layout_test.dart`, qui verrouille ce
/// cas sur les trois formats en cause.
///
/// Au-delà de 4 joueurs, une grille égale n'est pas réalisable et
/// l'arrangement `around` reprend la main — sous réserve que les colonnes
/// soient payables, ce que `tableLayoutFor` vérifie ensuite.
TableArrangement arrangementFor(Size size, int playerCount) {
  if (playerCount > 4) return TableArrangement.around;
  if (playerCount != 4) return TableArrangement.faceToFace;

  // Grille égale à 4 joueurs : 2 colonnes, 2 rangées.
  final zone = Size(size.width / 2, size.height / 2);

  return zone.height > zone.width
      ? TableArrangement.columnPairs
      : TableArrangement.faceToFace;
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

  // Ruling 21 (18/10/2026) : une étape 3bis avait un temps restreint la bande
  // aux dispositions à « frontière pleine largeur » (2 joueurs, et au-delà de
  // 4), en partant d'une capture où la table était INÉQUITABLE -- deux
  // joueurs à 67 % de la largeur, deux à 13 %. Dans cet état, une bande entre
  // les deux rangées aggravait un déséquilibre déjà là. Mais c'est
  // l'inéquité elle-même, pas la bande, qui causait le défaut constaté : une
  // fois les quatre zones rendues égales (ce que cette tâche fait par
  // ailleurs), une bande horizontale entre les deux rangées retire la MÊME
  // hauteur à tout le monde -- elle ne lèse plus personne, à 3 et 4 joueurs
  // comme ailleurs. Restreindre `barKind` au nombre de joueurs aurait
  // supprimé l'affichage permanent du chrono de partie (porté par la bande)
  // pour les effectifs Commander les plus courants, sans que ce soit demandé
  // ni validé sur aucune maquette. `barKind` ne dépend donc que de la forme
  // de l'écran, comme avant cette tâche.
  final barKind = shortEdge < kLargeScreenShortEdge
      ? ActionBarKind.hub
      : ActionBarKind.band;

  TableLayout fallback() => TableLayout(
        useSideColumns: false,
        sideWidth: 0.0,
        barKind: barKind,
        seats: seatsFor(playerCount, allowSideColumns: false),
      );

  final arrangement = arrangementFor(size, playerCount);

  // Équité : jusqu'à 4 joueurs, la grille est égale et personne n'est
  // relégué dans une bande. Les colonnes latérales n'existent plus que là
  // où une grille égale est impossible.
  if (arrangement != TableArrangement.around) {
    return TableLayout(
      useSideColumns: false,
      sideWidth: 0.0,
      barKind: barKind,
      seats: seatsForArrangement(playerCount, arrangement),
    );
  }

  final wanted = seatsForArrangement(playerCount, arrangement);
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
