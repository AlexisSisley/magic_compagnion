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
}
