// Fichier : test/providers/active_game_provider_test.dart
// Le provider qui alimente le bouton "Reprendre la partie" de l'Accueil.
// GameSessionService snapshotte deja la partie dans SharedPreferences : ce
// provider ne fait que l'exposer a l'UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_game_session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test("retourne null quand aucune partie n'est en cours", () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = await container.read(activeGameProvider.future);

    expect(session, isNull);
  });

  test("retourne le snapshot quand une partie est en cours", () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(gameSessionServiceProvider);
    await service.saveSnapshot(buildTestSession());

    final session = await container.read(activeGameProvider.future);

    expect(session, isNotNull);
    expect(session!.players, hasLength(2));
  });

  test('le provider se recharge apres clearSnapshot', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(gameSessionServiceProvider);
    await service.saveSnapshot(buildTestSession());
    expect(await container.read(activeGameProvider.future), isNotNull);

    await service.clearSnapshot();
    container.invalidate(activeGameProvider);

    expect(await container.read(activeGameProvider.future), isNull);
  });
}
