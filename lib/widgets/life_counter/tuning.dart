// lib/widgets/life_counter/tuning.dart
// Les réglages du life counter qui n'ont JAMAIS été éprouvés en partie
// réelle. Les specs v4 (§6) et table multijoueur v2 les listaient comme
// « à calibrer en usage réel » ; ils étaient dispersés dans le code de
// production, donc introuvables au moment où l'on voulait les toucher.
//
// Aucune de ces valeurs n'est exposée dans les Réglages : ce fichier existe
// pour qu'un ajustement après une partie soit un geste, pas une fouille.
//
// Ce regroupement ne change AUCUN comportement observable : chaque valeur
// reprend ce que le code faisait déjà avant ce fichier (voir le rapport de
// tâche pour l'origine de chacune, et l'écart signalé sur l'appui long).

/// Durée d'appui avant l'entrée en mode ajustement.
///
/// `life_dial.dart` n'avait pas de définition locale à « sortir » : il
/// s'appuyait implicitement sur la constante par défaut de
/// [LongPressGestureRecognizer] (`kLongPressTimeout` exportée par
/// `package:flutter/gestures.dart`), qui vaut 500 ms. On recopie cette
/// valeur réellement en vigueur plutôt que d'en introduire une nouvelle :
/// ce chantier ne change aucun réglage sans décision explicite.
const Duration kLongPressTimeout = Duration(milliseconds: 500);

/// Fenêtre pendant laquelle les changements de vie successifs sont cumulés
/// en un seul delta affiché, et pendant laquelle la rangée d'attribution de
/// dégâts de commandant reste ouverte.
///
/// Les 2 s d'origine (`life_counter_page._updateLife`) n'ont jamais été
/// validées. C'est le PREMIER réglage à éprouver en partie réelle.
const Duration kDamageBufferWindow = Duration(seconds: 2);

/// Distance en pixels que le doigt doit parcourir, en mode ajustement, pour
/// faire bouger le total d'une unité à vitesse nominale.
///
/// Déplacée depuis `PlayerZoneNotifier.wheelPixelsPerUnit` (membre statique
/// de classe dans `lib/providers/player_zone_notifier.dart`), consommée par
/// `handleWheelDrag` — nom conservé à l'identique, c'est celui que le code et
/// ses commentaires emploient déjà. Introduite telle quelle au moment de la
/// réécriture V4 du contrôleur (commit `276719d4`, « feat: rewrite
/// PlayerZoneController as PlayerZoneNotifier for V4 ») : aucune justification
/// de 8.0 n'est documentée dans cet historique ou ailleurs — je ne sais pas
/// d'où vient cette valeur précise, seulement qu'elle est celle en vigueur.
const double wheelPixelsPerUnit = 8.0;

/// Au-delà de ce déplacement (px) dans un seul geste, la molette accélère.
///
/// Déplacée depuis `PlayerZoneNotifier.wheelAccelerationThreshold`, même
/// origine et même réserve que [wheelPixelsPerUnit] : aucune justification
/// documentée pour 120.0.
///
/// Mécanisme RÉEL (voir `handleWheelDrag`) : ce n'est PAS un facteur continu
/// appliqué en permanence. Tant que la distance totale du geste reste sous ce
/// seuil, chaque pixel compte pour un pixel. Au-delà, le reste du geste est
/// DOUBLÉ (`magnitude * 2`, codé en dur dans `player_zone_notifier.dart`,
/// hors de ce fichier) avant conversion en pas via [wheelPixelsPerUnit]. Un
/// ancien brief de cette tâche avait supposé un `kWheelAcceleration` en
/// facteur continu réglable — ce réglage n'existe pas dans le code, et n'a
/// donc pas sa place ici tant que le mécanisme n'est pas réellement
/// paramétrable.
const double wheelAccelerationThreshold = 120.0;
