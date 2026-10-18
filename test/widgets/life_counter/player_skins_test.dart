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

  test('aucune couleur de joueur Material en dur hors de player_skins.dart', () {
    final offenders = <String>[];
    final shades = RegExp(r'Colors\.\w+\.shade(800|900)');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('player_skins.dart')) continue;
      final text = entity.readAsStringSync();
      // Seuls les fichiers du life counter sont concernés : une couleur
      // Material ailleurs n'est pas une couleur de joueur.
      if (!entity.path.contains('life_counter')) continue;
      if (shades.hasMatch(text)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty,
        reason: 'Couleurs de joueur en dur : ${offenders.join(", ")}');
  });

  // Le garde ci-dessus cherche `Colors.rouge.shade900` : une teinte Material
  // NOMMÉE. Il ne voit rien quand la même couleur de joueur est recopiée en
  // entier hexadécimal, avec le nom Material réduit à un commentaire
  // (`0xFFB71C1C, // Colors.red.shade900`) -- exactement la forme trouvée
  // dans `game_setup_notifier.dart`, hors du dossier `life_counter`, donc
  // hors de la portée du garde ci-dessus de toute façon. On ne peut pas
  // chercher `0xFF......` partout : les couleurs légitimes (mana, thème,
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

  // Ce que ces trois gardes ne couvrent délibérément PAS :
  // `lib/data/migration/migration_service.dart` retombe sur un unique
  // littéral `0xFF2196F3` pour les anciennes parties déjà enregistrées sans
  // couleur -- un repli SCALAIRE (pas une liste proposée à l'utilisateur)
  // dans une migration one-shot de données déjà écrites. Le changer
  // réécrirait rétroactivement la couleur de parties passées pour un
  // bénéfice nul : ne pas le "corriger" par réflexe (Ruling 9, tâche 1).
}
