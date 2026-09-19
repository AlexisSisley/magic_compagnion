// Tests du parser d'export de collection Moxfield.
// Dart pur : aucune dependance Flutter, aucun mock, aucune base.
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/moxfield_import.dart';
import 'package:magic_companion/services/moxfield_collection_parser.dart';

const _entete =
    '"Count","Tradelist Count","Name","Edition","Condition","Language","Foil",'
    '"Tags","Last Modified","Collector Number","Alter","Proxy","Purchase Price"';

String _ligne({
  String count = '1',
  String name = 'Sol Ring',
  String edition = 'ltc',
  String language = 'en',
  String foil = '',
  String cn = '284',
}) =>
    '"$count","0","$name","$edition","Near Mint","$language","$foil","",'
    '"2026-09-19","$cn","","",""';

void main() {
  group('Colonnes', () {
    test('un entete Moxfield complet est entierement reconnu', () {
      final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne()}');

      expect(r.refusal, isNull);
      expect(r.isDegraded, isFalse);
      expect(r.missingIdentityColumns, isEmpty);
      expect(r.recognizedColumns,
          containsAll(['Count', 'Name', 'Edition', 'Collector Number', 'Language', 'Foil']));
      expect(r.entries.single.name, 'Sol Ring');
      expect(r.entries.single.setCode, 'ltc');
      expect(r.entries.single.collectorNumber, '284');
    });

    test('la casse et les espaces de l entete sont tolerés', () {
      final r = MoxfieldCollectionParser.parse(
          ' count , NAME , edition , collector number \n1,Sol Ring,ltc,284');

      expect(r.refusal, isNull);
      expect(r.entries.single.setCode, 'ltc');
    });

    test('les colonnes peuvent etre dans n importe quel ordre', () {
      final r = MoxfieldCollectionParser.parse(
          'Name,Edition,Collector Number,Count\nSol Ring,ltc,284,3');

      expect(r.entries.single.quantity, 3);
      expect(r.entries.single.setCode, 'ltc');
    });

    test('Quantity est un alias de Count', () {
      final r = MoxfieldCollectionParser.parse('Quantity,Name\n2,Sol Ring');

      expect(r.refusal, isNull);
      expect(r.entries.single.quantity, 2);
    });

    test('sans colonne Name, l import REFUSE et nomme la colonne', () {
      final r = MoxfieldCollectionParser.parse('Count,Edition\n1,ltc');

      expect(r.refusal, isNotNull);
      expect(r.refusal, contains('Name'));
      expect(r.entries, isEmpty);
    });

    test('sans colonne de quantite, l import REFUSE et nomme la colonne', () {
      final r = MoxfieldCollectionParser.parse('Name,Edition\nSol Ring,ltc');

      expect(r.refusal, isNotNull);
      expect(r.refusal, contains('Count'));
      expect(r.entries, isEmpty);
    });

    test('sans edition ni numero, le mode degrade est signale mais on continue', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\n1,Sol Ring');

      expect(r.refusal, isNull);
      expect(r.isDegraded, isTrue);
      expect(r.missingIdentityColumns, containsAll(['Edition', 'Collector Number']));
      expect(r.entries.single.setCode, isNull);
    });
  });

  group('Valeurs', () {
    test('les marqueurs de foil reconnus valent tous foil', () {
      for (final v in ['foil', 'Foil', 'true', '1', 'yes', 'etched']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(foil: v)}');
        expect(r.entries.single.isFoil, isTrue, reason: 'valeur "$v"');
      }
    });

    test('les marqueurs de non-foil reconnus valent tous non-foil', () {
      for (final v in ['', 'nonFoil', 'normal', 'false', 'none']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(foil: v)}');
        expect(r.entries.single.isFoil, isFalse, reason: 'valeur "$v"');
      }
    });

    test('la langue accepte le code, le nom anglais et le nom francais', () {
      for (final v in ['fr', 'FR', 'French', 'Français']) {
        final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(language: v)}');
        expect(r.entries.single.lang, 'fr', reason: 'valeur "$v"');
      }
    });

    test('une langue inconnue vaut "pas de langue" et ne perd pas la ligne', () {
      final r = MoxfieldCollectionParser.parse('$_entete\n${_ligne(language: 'klingon')}');

      expect(r.entries, hasLength(1));
      expect(r.entries.single.lang, isNull);
    });

    test('un nom contenant une virgule entre guillemets reste entier', () {
      final r = MoxfieldCollectionParser.parse(
          'Count,Name\n1,"Erebos, God of the Dead"');

      expect(r.entries.single.name, 'Erebos, God of the Dead');
    });
  });

  group('Lignes illisibles', () {
    test('une quantite non numerique rend la ligne illisible, jamais devinee', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\nbeaucoup,Sol Ring');

      expect(r.entries, isEmpty);
      expect(r.unreadableLines, hasLength(1));
      expect(r.unreadableLines.single, contains('Sol Ring'));
    });

    test('un nom vide rend la ligne illisible', () {
      final r = MoxfieldCollectionParser.parse('Count,Name\n1,');

      expect(r.entries, isEmpty);
      expect(r.unreadableLines, hasLength(1));
    });

    test('une ligne tronquee est illisible et n interrompt pas le reste', () {
      final r = MoxfieldCollectionParser.parse(
          'Count,Name,Edition\n1,Sol Ring,ltc\n1\n2,Cultivate,m21');

      expect(r.entries, hasLength(2));
      expect(r.unreadableLines, hasLength(1));
    });
  });

  group('Invariant de somme', () {
    test('entrees + illisibles = lignes lues', () {
      final csv = [
        'Count,Name,Edition,Collector Number',
        '1,Sol Ring,ltc,284',
        'beaucoup,Cultivate,m21,177',
        '2,Counterspell,mh2,267',
        '1,,eld,146',
      ].join('\n');

      final r = MoxfieldCollectionParser.parse(csv);

      expect(r.linesRead, 4);
      expect(r.entries.length + r.unreadableLines.length, r.linesRead);
    });

    test('un fichier vide ne leve pas et refuse proprement', () {
      final r = MoxfieldCollectionParser.parse('');

      expect(r.refusal, isNotNull);
      expect(r.entries, isEmpty);
      expect(r.linesRead, 0);
    });
  });
}
