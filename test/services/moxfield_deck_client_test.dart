import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/moxfield_deck_client.dart';

Dio _mockDio(Object Function(RequestOptions) handler) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, h) {
    final result = handler(options);
    if (result is int) {
      h.reject(DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: result),
        type: DioExceptionType.badResponse,
      ));
      return;
    }
    h.resolve(Response(requestOptions: options, statusCode: 200, data: result));
  }));
  return dio;
}

void main() {
  group('extractPublicId', () {
    test('extrait l identifiant d une URL de deck', () {
      expect(extractPublicId('https://moxfield.com/decks/f-27i01CpkmBPljy89HQeA'),
          'f-27i01CpkmBPljy89HQeA');
    });

    test('accepte le sous-domaine www et une barre finale', () {
      expect(extractPublicId('https://www.moxfield.com/decks/abc123/'), 'abc123');
    });

    test('rend null sur une URL Moxfield qui n est pas un deck', () {
      expect(extractPublicId('https://moxfield.com/users/Noruk'), isNull);
    });

    test('rend null sur un autre site', () {
      expect(extractPublicId('https://archidekt.com/decks/12345'), isNull);
    });

    test('rend null sur du texte quelconque', () {
      expect(extractPublicId('bonjour'), isNull);
    });

    test('accepte des parametres de requete (?utm_source=...)', () {
      expect(
          extractPublicId(
              'https://moxfield.com/decks/abc123?utm_source=twitter'),
          'abc123');
    });

    test('accepte un fragment (#primer)', () {
      expect(extractPublicId('https://moxfield.com/decks/abc123#primer'),
          'abc123');
    });

    test('accepte une sous-page du deck (/primer)', () {
      expect(extractPublicId('https://moxfield.com/decks/abc123/primer'),
          'abc123');
    });

    test('rend null quand le separateur apres l identifiant est absent '
        '(abc123.evil.com)', () {
      expect(
          extractPublicId('https://moxfield.com/decks/abc123.evil.com'),
          isNull);
    });

    test('rend null sur un domaine usurpe par sous-domaine '
        '(moxfield.com.evil.com)', () {
      expect(
          extractPublicId('https://moxfield.com.evil.com/decks/abc123'),
          isNull);
    });

    test('rend null sur un chemin qui ne correspond pas exactement a '
        '/decks/ (/decksomething/abc)', () {
      expect(
          extractPublicId('https://moxfield.com/decksomething/abc'),
          isNull);
    });

    test('rend null sur un domaine usurpe par userinfo '
        '(moxfield.com@evil.com)', () {
      expect(
          extractPublicId('https://moxfield.com@evil.com/decks/abc123'),
          isNull);
    });

    test('rend null quand l identifiant de deck est vide (/decks/)', () {
      expect(extractPublicId('https://moxfield.com/decks/'), isNull);
    });
  });

  group('fetchDeck', () {
    test('rend le JSON du deck sur 200', () async {
      final client = MoxfieldDeckClient(
          dio: _mockDio((_) => {'name': 'Invincible toph', 'boards': {}}));

      final deck = await client.fetchDeck('f-27i01CpkmBPljy89HQeA');

      expect(deck['name'], 'Invincible toph');
    });

    test('un 404 devient notPublic avec un message parlant', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 404));

      expect(
        () => client.fetchDeck('inconnu'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.notPublic)
            .having((e) => e.message, 'message', contains('public'))),
      );
    });

    test('un 403 devient accessDenied et oriente vers l export', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 403));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.accessDenied)
            .having((e) => e.message, 'message', contains('export'))),
      );
    });

    test('un 429 devient transient', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 429));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.transient)),
      );
    });

    test('un 500 devient transient', () async {
      final client = MoxfieldDeckClient(dio: _mockDio((_) => 500));

      expect(
        () => client.fetchDeck('abc'),
        throwsA(isA<MoxfieldException>()
            .having((e) => e.kind, 'kind', MoxfieldError.transient)),
      );
    });

    test('l URL appelee est bien la route v3 des decks', () async {
      late String chemin;
      final client = MoxfieldDeckClient(dio: _mockDio((options) {
        chemin = options.uri.toString();
        return {'name': 'x', 'boards': {}};
      }));

      await client.fetchDeck('abc123');

      expect(chemin, contains('api2.moxfield.com/v3/decks/all/abc123'));
    });
  });
}
