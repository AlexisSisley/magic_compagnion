import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/widgets/collection/moxfield_import_report.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('le bilan affiche les quatre compteurs', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 1247, added: 1114, updated: 133, tagged: 12,
        taggedNames: ['Sol Ring', 'Chaos Warp'],
      ),
    )));
    await tester.pumpAndSettle();

    // Assertions exactes plutot que "contains" : '12' est une sous-chaine de
    // '1247', donc find.textContaining('12') passerait meme si la ligne
    // "Tagees a verifier" n'etait pas rendue du tout. find.text() exige une
    // egalite stricte du contenu du widget Text, donc chaque assertion ne
    // peut etre satisfaite que par la ligne de compteur qu'elle vise.
    expect(find.text('1247'), findsOneWidget);
    expect(find.text('1114'), findsOneWidget);
    expect(find.text('133'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('les cartes tagees sont NOMMEES, pas seulement comptees', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 2, tagged: 2,
        taggedNames: ['Sol Ring', 'Chaos Warp'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sol Ring'), findsOneWidget);
    expect(find.textContaining('Chaos Warp'), findsOneWidget);
  });

  testWidgets('sans carte tagee, le bloc ambre n apparait pas', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(imported: 10, added: 10),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('à vérifier'), findsNothing);
  });

  testWidgets('les lignes illisibles sont citees telles quelles', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 1,
        unreadableLines: ['beaucoup,Sol Ring,ltc,284'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('beaucoup,Sol Ring'), findsOneWidget);
  });

  // Les trois champs ci-dessous (notIdentified, failedTransient,
  // notIdentifiedNames) ont ete ajoutes a CollectionImportResult apres
  // l'ecriture du plan pour respecter l'invariant "aucune ligne ne
  // disparait". Le brief ne les decrit pas, mais le bilan doit les
  // distinguer : une carte non identifiee (definitif, Scryfall ne la
  // connait pas) ne dit pas la meme chose qu'un echec reseau transitoire
  // (reessayer l'import peut suffire). Aucune des deux ne doit rester
  // invisible, et elles ne doivent jamais se confondre l'une avec l'autre.

  testWidgets('les cartes non identifiees sont nommees et invitent a verifier la ligne', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 3,
        notIdentified: 2,
        notIdentifiedNames: ['Carte Inconnue', 'Fantome Introuvable'],
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Carte Inconnue'), findsOneWidget);
    expect(find.textContaining('Fantome Introuvable'), findsOneWidget);
    expect(find.textContaining('ne connaît pas'), findsOneWidget);
    // Ne doit pas se confondre avec le message des echecs reseau.
    expect(find.textContaining('réessaie'), findsNothing);
  });

  testWidgets('les echecs reseau invitent a reessayer, sans etre confondus avec les non identifiees', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(
        imported: 3,
        failedTransient: 4,
      ),
    )));
    await tester.pumpAndSettle();

    // Assertion exacte sur la ligne de compteur (pas juste "contient '4'",
    // qui matcherait aussi un fragment de la phrase d'explication).
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('réessaie'), findsOneWidget);
    // Ne doit pas se confondre avec le message des non identifiees.
    expect(find.textContaining('ne connaît pas'), findsNothing);
  });

  testWidgets('sans notIdentified ni failedTransient, aucun de ces panneaux n apparait', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(imported: 10, added: 10),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('ne connaît pas'), findsNothing);
    expect(find.textContaining('réessaie'), findsNothing);
  });

  testWidgets('les compteurs utilisent des chiffres tabulaires', (tester) async {
    await tester.pumpWidget(_host(const MoxfieldImportReport(
      result: CollectionImportResult(imported: 5, added: 5),
    )));
    await tester.pumpAndSettle();

    final textWidget = tester.widget<Text>(find.text('5').first);
    expect(
      textWidget.style?.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });
}
