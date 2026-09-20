// Fichier : test/providers/active_game_lifecycle_test.dart
// `activeGameProvider` suit-il le VRAI cycle de vie d'une partie ?
//
// active_game_provider_test.dart prouve que le provider lit bien le service,
// mais son test de rechargement appelle lui-meme `container.invalidate()` :
// il prouve que Riverpod fonctionne, pas que l'app l'appelle. Ici, aucun
// `invalidate` n'est ecrit par le test -- tout part d'un geste sur le
// compteur.
//
// Ce que ca protege :
//   - critere n6 du plan : terminer une partie fait disparaitre le bouton de
//     reprise. Sans invalidation, l'Accueil lit un cache et propose de
//     reprendre une partie effacee ;
//   - le pendant du ruling sur l'ouverture automatique de la feuille : si une
//     partie demarre depuis le compteur alors que l'Accueil a `null` en
//     cache, la mise en place ouvrirait "configurer une nouvelle partie"
//     par-dessus une partie en cours.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/life_counter/life_counter_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:magic_companion/services/game_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_game_session.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpCompteur(WidgetTester tester,
      {GameSession? snapshot}) async {
    SharedPreferences.setMockInitialValues({
      if (snapshot != null)
        'active_game_snapshot': json.encode(snapshot.toJson()),
    });

    container = ProviderContainer(overrides: [
      gameHistoryServiceProvider.overrideWithValue(GameHistoryService()),
    ]);
    addTearDown(container.dispose);

    // Un abonnement garde le provider vivant entre les lectures : sans lui,
    // chaque `read` reconstruirait une instance neuve et relirait le disque,
    // ce qui masquerait exactement le defaut de cache qu'on veut mesurer.
    final sub = container.listen(activeGameProvider, (_, __) {});
    addTearDown(sub.close);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: LifeCounterPage())),
    ));
    await tester.pumpAndSettle();
  }

  /// Les deux points d'entree `@visibleForTesting` de `LifeCounterPage`.
  /// `as dynamic` comme le reste du depot : le State est prive, on ne peut
  /// pas le nommer d'ici.
  dynamic etatDuCompteur(WidgetTester tester) =>
      tester.state(find.byType(LifeCounterPage)) as dynamic;

  testWidgets('terminer une partie retire le bouton de reprise',
      (tester) async {
    await pumpCompteur(tester, snapshot: buildTestSession());

    // L'Accueil voit bien une partie avant la fin de celle-ci.
    expect(await container.read(activeGameProvider.future), isNotNull,
        reason: 'le snapshot de depart doit etre lu');

    // Le geste : designer un gagnant, ce que fait le dialogue de fin.
    await etatDuCompteur(tester).finalizeGameSaveForTest(0, 'Dommages');
    await tester.pumpAndSettle();
    // Temps simule, pas `runAsync` : SharedPreferences est mocke et se
    // resout dans l'horloge du test. `runAsync` reveillerait le canal du
    // wakelock et le telechargement de polices, qui n'ont rien a voir ici.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(await container.read(activeGameProvider.future), isNull,
        reason: "critere n6 : l'Accueil ne doit plus proposer de reprendre "
            'une partie terminee');
  });

  testWidgets('une partie sauvegardee depuis le compteur devient visible',
      (tester) async {
    // Depart sans partie : c'est l'etat que l'Accueil a en cache.
    await pumpCompteur(tester);
    expect(await container.read(activeGameProvider.future), isNull);

    // Le geste : le compteur ecrit son snapshot, comme a chaque mutation.
    etatDuCompteur(tester).saveSnapshotForTest();
    // Au-dela du debounce de 500 ms du SnapshotWriter.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(await container.read(activeGameProvider.future), isNotNull,
        reason: "sans ca, la mise en place ouvrirait sa feuille de "
            'configuration par-dessus une partie en cours');
  });
}
