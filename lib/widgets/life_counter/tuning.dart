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
/// Pas encore consommée : la conversion réelle du glissement en pas vit
/// dans `PlayerZoneNotifier.handleWheelDrag` (`wheelPixelsPerUnit = 8.0`,
/// `lib/providers/player_zone_notifier.dart`), un fichier hors du périmètre
/// de cette tâche. Valeur reprise du brief, sans équivalent à cet endroit —
/// voir le rapport de tâche pour l'écart avec le littéral existant.
const double kWheelPixelsPerStep = 12.0;

/// Facteur appliqué au pas de la molette quand le geste s'allonge, pour que
/// de gros montants restent atteignables sans vingt allers-retours.
/// 1.0 désactive l'accélération.
///
/// Pas encore consommée, pour la même raison que [kWheelPixelsPerStep] :
/// l'accélération réelle (même fichier, `wheelAccelerationThreshold = 120.0`)
/// double le pas au-delà d'un seuil de distance plutôt que d'appliquer un
/// facteur continu — un mécanisme différent, pas seulement une valeur
/// différente. Valeur reprise du brief, sans équivalent à cet endroit.
const double kWheelAcceleration = 1.6;
