import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/controllers/card_detail_controller.dart';

void main() {
  group('parsePrintFooter', () {
    test('lit set, numero et langue sur un bas de carte francais', () {
      final parsed = parsePrintFooter('146/280 C ELD FR');

      expect(parsed, isNotNull);
      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, 'fr');
    });

    test('sans code langue, la langue est nulle', () {
      final parsed = parsePrintFooter('ELD 146');

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });

    test('ignore un code langue qui n est pas supporte par Scryfall', () {
      final parsed = parsePrintFooter('146/280 C ELD ZZ');

      expect(parsed!.lang, isNull);
    });

    test('rend null sur un texte sans motif d edition', () {
      expect(parsePrintFooter('Créature : humain et éclaireur'), isNull);
    });

    // Round de correction 1 - constat 1 : le format moderne peut avoir un
    // code d'edition alphanumerique (ne commencant pas forcement par une
    // lettre). Seule la position (juste apres la rarete) l'identifie.
    test('reconnait un set alphanumerique (Double Masters)', () {
      final parsed = parsePrintFooter('150/332 M 2XM EN');

      expect(parsed!.setCode, '2XM');
      expect(parsed.collectorNumber, '150');
      expect(parsed.lang, 'en');
    });

    test('reconnait un set alphanumerique (Double Masters 2022)', () {
      final parsed = parsePrintFooter('45/332 R 2X2 FR');

      expect(parsed!.setCode, '2X2');
      expect(parsed.collectorNumber, '45');
      expect(parsed.lang, 'fr');
    });

    test('reconnait un set alphanumerique (Universes Beyond 40K)', () {
      final parsed = parsePrintFooter('10/407 M 40K EN');

      expect(parsed!.setCode, '40K');
      expect(parsed.collectorNumber, '10');
      expect(parsed.lang, 'en');
    });

    // Round de correction 1 - constats 2 et 3 : le bas d'une carte Magic
    // est imprime en MAJUSCULES. Du texte de regles en minuscules ne doit
    // jamais etre confondu avec le motif edition/numero, ni avec un code
    // langue.
    test('ignore du texte de regles ressemblant a "set cn" (turn 2)', () {
      expect(parsePrintFooter('... until end of turn 2'), isNull);
    });

    test('ignore du texte de regles ressemblant a "set cn" (put 2)', () {
      expect(parsePrintFooter('put 2 loyalty counters'), isNull);
    });

    test('n interprete pas "It" (debut de phrase) comme la langue italienne', () {
      final parsed = parsePrintFooter(
        '146/280 C ELD It was a dark and stormy night',
      );

      expect(parsed!.setCode, 'ELD');
      expect(parsed.collectorNumber, '146');
      expect(parsed.lang, isNull);
    });
  });

  group('isMissingTranslation', () {
    test('vrai pour un 404 Scryfall', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 404),
        type: DioExceptionType.badResponse,
      );

      expect(isMissingTranslation(error), isTrue);
    });

    test('faux pour une autre reponse HTTP (ex. 500)', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 500),
        type: DioExceptionType.badResponse,
      );

      expect(isMissingTranslation(error), isFalse);
    });

    test('faux pour une panne reseau sans reponse HTTP', () {
      final requestOptions = RequestOptions(path: '/cards/eld/146/fr');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );

      expect(isMissingTranslation(error), isFalse);
    });

    test('faux pour une exception qui n est pas un DioException', () {
      expect(isMissingTranslation(Exception('boom')), isFalse);
    });
  });
}
