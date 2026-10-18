// test/widgets/life_counter/tuning_test.dart
// Garde-fou de plausibilité : empêche qu'un réglage jamais calibré ne dérive
// vers une valeur absurde (ex. un appui long de 5 minutes) sans que personne
// ne le remarque. Ne valide PAS le bon réglage — personne ne le connaît
// encore, c'est tout l'objet de ce fichier.
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/life_counter/tuning.dart';

void main() {
  test('les réglages ont des valeurs utilisables', () {
    expect(kLongPressTimeout.inMilliseconds, inInclusiveRange(200, 600));
    expect(kDamageBufferWindow.inMilliseconds, inInclusiveRange(1000, 5000));
    expect(kWheelPixelsPerStep, greaterThan(0));
    expect(kWheelAcceleration, greaterThanOrEqualTo(1.0));
  });
}
