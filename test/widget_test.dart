import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/main.dart';
import 'package:magic_companion/pages/onboarding/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_companion/services/drive_lifecycle_observer.dart';
import 'package:magic_companion/theme/magic_palette.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Sans ce drapeau, le redirect envoie sur l'onboarding et le shell n'est
    // jamais monte.
    SharedPreferences.setMockInitialValues({kHasSeenOnboarding: true});
  });

  /// Le Navigator du routeur n'existe pas des la premiere frame : le redirect
  /// d'onboarding est asynchrone. Quelques pompes suffisent -- et le fait
  /// qu'il en faille est precisement pourquoi l'observer trace ses sorties
  /// sur contexte nul au lieu de les avaler.
  Future<void> pompe(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('MagicCompanionApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MagicCompanionApp(),
      ),
    );

    // Verify the app title is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets("l'observer de sauvegarde Drive est monte au-dessus du routeur",
      (WidgetTester tester) async {
    // Le piege recurrent de ce depot : un composant correct, teste, et jamais
    // branche. drive_lifecycle_observer_test.dart prouve que l'observer
    // fonctionne ; celui-ci prouve que l'app le monte -- sans quoi la
    // sauvegarde automatique ne s'executerait jamais, en silence.
    await tester.pumpWidget(
      ProviderScope(
        child: MagicCompanionApp(),
      ),
    );
    await pompe(tester);

    final observer = tester
        .widget<DriveLifecycleObserver>(find.byType(DriveLifecycleObserver));

    // Pas seulement "la cle existe" : qu'elle resolve vers un contexte
    // UTILISABLE. C'est tout ce dont depend la moitie affichage de
    // l'observer -- dialogue de restauration, SnackBars, navigation -- et
    // que la reecriture au-dessus de MaterialApp a mise en danger.
    final contexte = observer.navigatorKey.currentContext;
    expect(contexte, isNotNull,
        reason: 'sans contexte, le dialogue de restauration ne peut pas '
            "s'afficher : celui de l'observer est au-dessus de MaterialApp");

    expect(Theme.of(contexte!).extension<MagicPalette>(), isNotNull,
        reason: 'MagicPalette.of(context) y est appele pour colorer le '
            'dialogue');
    expect(Navigator.maybeOf(contexte), isNotNull,
        reason: 'showDialog et Navigator.pop en dependent');
    expect(ScaffoldMessenger.maybeOf(contexte), isNotNull,
        reason: 'les SnackBars de restauration en dependent');
    expect(MaterialLocalizations.of(contexte), isNotNull,
        reason: 'showDialog exige des MaterialLocalizations');
  });
}
