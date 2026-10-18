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
  test(
      'aucune liste de couleurs de joueur en hexadécimal en dur hors de '
      'player_skins.dart', () {
    final offenders = <String>[];
    final colorListDecl = RegExp(
      r'(?:List<Color>|List<int>)\s+\w*[Cc]olor\w*\s*=\s*(?:const\s*)?\[([^\]]*)\]',
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
}
