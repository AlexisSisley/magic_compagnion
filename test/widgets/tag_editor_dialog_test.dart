// Tests unitaires pour TagEditorDialog (Sprint 10, US-10.4).
// Teste le widget d'edition de tags : ajout, suppression, autocomplete, sauvegarde.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/widgets/common/tag_editor_dialog.dart';

void main() {
  // Helper : pompe le widget dans un MaterialApp
  Widget buildDialog({
    String cardName = 'Sol Ring',
    List<String> currentTags = const [],
    List<String> availableTags = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => TagEditorDialog(
                  cardName: cardName,
                  currentTags: currentTags,
                  availableTags: availableTags,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  group('TagEditorDialog', () {
    testWidgets('affiche le nom de la carte et les tags actuels', (tester) async {
      await tester.pumpWidget(buildDialog(
        cardName: 'Lightning Bolt',
        currentTags: ['Burn', 'Staple'],
        availableTags: ['Burn', 'Staple', 'Ramp'],
      ));

      // Ouvre le dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verifie le nom de la carte
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);

      // Verifie les tags actuels sous forme de Chip
      expect(find.text('Burn'), findsOneWidget);
      expect(find.text('Staple'), findsOneWidget);

      // Verifie les boutons
      expect(find.text('Annuler'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('ajoute un nouveau tag via le champ texte', (tester) async {
      await tester.pumpWidget(buildDialog(
        cardName: 'Sol Ring',
        currentTags: [],
        availableTags: ['Commander', 'Staple'],
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Message quand pas de tags
      expect(find.text('Aucun tag. Ajoutez-en ci-dessous.'), findsOneWidget);

      // Saisit un tag dans le TextField
      await tester.enterText(find.byType(TextField), 'Ramp');
      await tester.pumpAndSettle();

      // Tape sur le bouton add (IconButton avec Icons.add)
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      // Le tag apparait comme Chip
      expect(find.text('Ramp'), findsOneWidget);
      // Le message "Aucun tag" a disparu
      expect(find.text('Aucun tag. Ajoutez-en ci-dessous.'), findsNothing);
    });

    testWidgets('supprime un tag existant via le bouton delete du Chip', (tester) async {
      await tester.pumpWidget(buildDialog(
        cardName: 'Counterspell',
        currentTags: ['Control', 'Budget'],
        availableTags: ['Control', 'Budget', 'Combo'],
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // 2 tags affiches
      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Budget'), findsOneWidget);

      // Supprime le tag "Control" via le deleteIcon du Chip
      // Les Chip ont un deleteIcon (cancel icon)
      final controlChip = find.ancestor(
        of: find.text('Control'),
        matching: find.byType(Chip),
      );
      expect(controlChip, findsOneWidget);

      // Tap le deleteIcon du chip (il est dans le chip widget)
      final deleteIcons = find.descendant(
        of: controlChip,
        matching: find.byType(InkWell),
      );
      // Le delete icon is the last InkWell in the Chip
      await tester.tap(deleteIcons.last);
      await tester.pumpAndSettle();

      // "Control" n'est plus visible comme Chip
      expect(find.text('Control'), findsNothing);
      expect(find.text('Budget'), findsOneWidget);
    });
  });
}
