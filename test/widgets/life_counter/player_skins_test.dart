// test/widgets/life_counter/player_skins_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/player_skins.dart';

void main() {
  test('kPlayerSkins couvre au moins six sièges', () {
    expect(kPlayerSkins.length, greaterThanOrEqualTo(6));
  });

  test('defaultSkinForSeat boucle sans jamais sortir de la liste', () {
    for (int i = 0; i < 20; i++) {
      expect(kPlayerSkins, contains(defaultSkinForSeat(i)));
    }
  });

  // Fichiers hors du domaine « couleur de joueur » qui utilisent
  // légitimement une teinte Material 800/900 décorative, chacun son motif.
  //
  // Ruling 11 (relecture, tâche 1) : ce test filtrait avant sur
  // `entity.path.contains('life_counter')` -- un filtre de DOSSIER. Il
  // cachait un trou critique : `profile_management_page.dart` écrivait la
  // même couleur de joueur en dur (`Colors.red.shade900, ...`) sans être
  // sous `life_counter/`, et le garde ne le voyait jamais. Un filtre de
  // chemin cache un trou ; une exemption nommée documente un choix. Les
  // trois gardes scannent donc désormais le même périmètre -- tout `lib/` --
  // et toute exception doit se justifier ligne par ligne, ici.
  const shadeGuardExemptions = <String, String>{
    'lib/theme/app_colors.dart':
        'source des teintes neutres greyShade800/900, pas une couleur de joueur',
    'lib/widgets/decks/deck_stats_tab.dart':
        'palette de camembert de stats de deck (_pieColors), pas une couleur de joueur',
    'lib/chat_screen.dart': 'dégradé de bulle de chat',
    'lib/pages/cards/card_search_page.dart': 'badge de rareté "mythique"',
    'lib/pages/collections/global_stats_page.dart':
        'palette de graphique de stats de collection',
    'lib/pages/collections/set_detail_page.dart':
        'confirmation de suppression et badge de rareté',
    'lib/pages/collections/wishlist_tab.dart':
        'bordure/fond décoratifs de la liste de souhaits',
    'lib/pages/decks/deck_list_page.dart':
        'fond de swipe-to-delete (même famille que game_history_page, Ruling 2)',
    'lib/pages/oracle/magic_oracle_page.dart': "boutons de l'écran Oracle",
    'lib/pages/settings/dev_tools_page.dart':
        "bouton d'avertissement des outils dev",
    'lib/pages/tournaments/tournament_page.dart':
        'état "match terminé" / indicateur BO3',
    'lib/widgets/collections/set_detail_card_tile.dart': 'bordure de rareté',
    'lib/widgets/collections/set_detail_stats_header.dart':
        'badge de rareté "mythique"',
    'lib/widgets/decks/deck_card_title.dart':
        "pastille de couleur d'un DECK, pas d'un joueur",
    'lib/widgets/decks/deck_import_modal.dart':
        "snackbar succès/échec d'import",
    'lib/widgets/decks/deck_list_card.dart': 'fond de swipe-to-delete',
    'lib/widgets/decks/deck_suggestions_tab.dart':
        'bouton de suggestion de deck',
    'lib/widgets/decks/draw_test_simulator.dart':
        'badges de type de carte et boutons du simulateur',
    'lib/widgets/search/card_search_results_grid.dart':
        'badge de rareté "mythique"',
    'lib/widgets/search/card_search_results_list.dart':
        'badge de rareté "mythique"',
    'lib/widgets/search/search_filter_modal.dart': 'badge de rareté "mythique"',
  };

  test('aucune couleur de joueur Material en dur hors de player_skins.dart', () {
    final offenders = <String>[];
    final shades = RegExp(r'Colors\.\w+\.shade(800|900)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('player_skins.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (shadeGuardExemptions.keys.any((p) => normalized.endsWith(p))) {
        continue;
      }
      final text = entity.readAsStringSync();
      if (shades.hasMatch(text)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'Couleurs de joueur en dur : ${offenders.join(", ")}');
  });

  // Le garde ci-dessus cherche `Colors.rouge.shade900` : une teinte Material
  // NOMMÉE. Il ne voit rien quand la même couleur de joueur est recopiée en
  // entier hexadécimal, le nom Material réduit à un commentaire -- la forme
  // trouvée dans `game_setup_notifier.dart`. On ne peut pas chercher
  // `0xFF......` partout : les couleurs légitimes (mana, thème,
  // dégradés de cartes...) en sont pleines. On restreint donc cette
  // recherche aux déclarations de `List<Color>` ou `List<int>` dont le NOM
  // de variable évoque une couleur -- un signal fort qu'il s'agit d'une
  // palette proposée quelque part, pas d'une couleur isolée -- et on ne
  // regarde que le corps de CETTE déclaration pour un littéral hexadécimal.
  // Le nom est cherché en français ET en anglais (`couleur`/`color`) : ce
  // dépôt a les deux, et la troisième forme ci-dessous existait précisément
  // sous un nom français (`_couleursParDefaut`) qu'une recherche anglaise
  // seule aurait aussi ratée.
  test(
      'aucune liste de couleurs de joueur en hexadécimal en dur hors de '
      'player_skins.dart', () {
    final offenders = <String>[];
    final colorListDecl = RegExp(
      r'(?:List<Color>|List<int>)\s+\w*(?:[Cc]olor|[Cc]ouleur)\w*\s*=\s*(?:const\s*)?\[([^\]]*)\]',
    );
    final hexLiteral = RegExp(r'0xFF[0-9A-Fa-f]{6}');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('player_skins.dart')) continue;
      final text = entity.readAsStringSync();
      for (final match in colorListDecl.allMatches(text)) {
        final body = match.group(1) ?? '';
        if (hexLiteral.hasMatch(body)) {
          offenders.add(entity.path);
          break;
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Couleurs de joueur en hexadécimal : ${offenders.join(", ")}');
  });

  // Troisième forme rencontrée, qui a échappé aux DEUX gardes précédents :
  // `play_setup_page._couleursParDefaut` n'avait ni teinte Material nommée
  // (ses quatre valeurs sont des Material *500*, jamais écrites via
  // `Colors.*.shade*`), ni annotation `List<int>` sur la variable -- juste
  // `<int>[...]`, un littéral de collection à type générique explicite,
  // SANS type déclaré sur la variable elle-même. Un garde qui exige le texte
  // `List<int>` ne la voit jamais. On cherche donc ici la forme
  // `nom = <int>[...]` / `nom = <Color>[...]` séparément, sur le même
  // critère de nom (`color`/`couleur`) et le même filtrage au corps de LA
  // déclaration pour éviter le bruit des hexadécimaux légitimes ailleurs.
  test(
      'aucune liste de couleurs de joueur en collection typée (<int>[...]) '
      'en dur hors de player_skins.dart', () {
    final offenders = <String>[];
    final colorListLiteral = RegExp(
      r'\w*(?:[Cc]olor|[Cc]ouleur)\w*\s*=\s*(?:const\s*)?<(?:int|Color)>\s*\[([^\]]*)\]',
    );
    final hexLiteral = RegExp(r'0xFF[0-9A-Fa-f]{6}');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('player_skins.dart')) continue;
      final text = entity.readAsStringSync();
      for (final match in colorListLiteral.allMatches(text)) {
        final body = match.group(1) ?? '';
        if (hexLiteral.hasMatch(body)) {
          offenders.add(entity.path);
          break;
        }
      }
    }
    expect(offenders, isEmpty,
        reason:
            'Couleurs de joueur en collection typée : ${offenders.join(", ")}');
  });

  // Quatrième forme (Ruling 12, relecture) : un littéral SCALAIRE, hors
  // liste -- `const Color _fallbackPlayerColor = Color(0xFFB71C1C);` ou
  // `color: Color(0xFF8A4038)` ne matche aucune des trois regex
  // précédentes, qui cherchent toutes une LISTE nommée. On change ici
  // d'angle plutôt que de recreuser le même sillon : le filtre de CHEMIN du
  // test 1 est précisément ce qui a produit le trou critique de Ruling 11 --
  // on ne le réutilise pas. On cible le DOMAINE à la place : tout fichier
  // qui mentionne `colorValue`, `PlayerSkin` ou `kPlayerSkins` parle de
  // couleur de joueur, et n'a rien à faire avec un littéral de couleur en
  // dur, sauf exemption nommée. Ça ne mord pas sur `app_colors.dart` ni sur
  // un widget décoratif, qui ne parlent pas de `colorValue`.
  const playerColorLiteralExemptions = <String, String>{
    'lib/widgets/life_counter/player_skins.dart': 'la source elle-même',
    'lib/models/player_config.dart':
        'repli de désérialisation (Ruling 10) -- brancher sur kPlayerSkins '
            "inverserait les couches : un modèle ne dépend pas d'un widget",
    'lib/models/profile_model.dart':
        'repli de désérialisation (Ruling 10), même motif',
    'lib/data/migration/migration_service.dart':
        'migration one-shot de données déjà écrites (Ruling 9) -- changer '
            'réécrirait rétroactivement la couleur de parties passées pour '
            'un bénéfice nul',
    // Découvertes en vérifiant cette règle, HORS des « exactement quatre »
    // exemptions demandées (Ruling 12, voir task-1-report.md) : même
    // catégorie que Ruling 9/10 (repli de persistance, pas un choix
    // utilisateur), mais un défaut de COLONNE Drift versionnée, pas un
    // simple champ Dart -- le changer exigerait une migration de schéma
    // (ALTER TABLE) pour un gain nul, exactement le raisonnement de
    // Ruling 9. Signalé explicitement pour tranchage plutôt qu'ajouté en
    // silence.
    'lib/data/database/app_database.dart':
        'défaut de colonne Drift (Profiles.colorValue, '
            'PlayerConfigs.colorValue) -- changer exige une migration de '
            'schéma',
    'lib/data/database/app_database.g.dart':
        'code généré à partir du fichier ci-dessus, mêmes colonnes',
  };

  test(
      'aucun littéral de couleur en dur dans un fichier qui parle de '
      'colorValue/PlayerSkin/kPlayerSkins, hors exemptions nommées', () {
    final offenders = <String>[];
    final domainMarker = RegExp(r'colorValue|PlayerSkin|kPlayerSkins');
    final scalarLiteral =
        RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)|0xFF[0-9A-Fa-f]{6}');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (playerColorLiteralExemptions.keys.any((p) => normalized.endsWith(p))) {
        continue;
      }
      final text = entity.readAsStringSync();
      if (!domainMarker.hasMatch(text)) continue;
      if (scalarLiteral.hasMatch(text)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'Littéral de couleur dans un fichier du domaine joueur : '
            '${offenders.join(", ")}');
  });
}
