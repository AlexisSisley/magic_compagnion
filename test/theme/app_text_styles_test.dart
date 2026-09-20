// Fichier : test/theme/app_text_styles_test.dart
// Verrouille la repartition des polices : Cinzel aux titres, Source Sans 3
// au texte courant. Sous 14px, Cinzel — une romaine a capitales — n'est plus
// lisible ; c'est le premier facteur d'illisibilite de l'app avant ce lot.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// `GoogleFonts.cinzel()` produit un fontFamily de la forme 'Cinzel_regular'
/// ou 'Cinzel'. On teste donc le prefixe, pas l'egalite stricte.
bool _isCinzel(String? family) => family?.startsWith('Cinzel') ?? false;

/// Nom de famille du style produit par [build], calcule dans une zone a soi.
///
/// Meme parade que les tests de capture du depot (voir `_runGuarded` dans
/// test/captures/identite_tirage_langue_captures_test.dart) :
/// `googleFontsTextStyle` laisse derriere lui une Future de chargement reseau
/// rejetee, que `allowRuntimeFetching = false` coupe mais n'absorbe pas. Sans
/// une zone a soi, le test reste marque [E] alors que la valeur mesuree est
/// correcte.
///
/// La zone n'enveloppe QUE le calcul du style, jamais les `expect` : une zone
/// avale ce qui leve a l'interieur, et un `expect` qui echoue y passerait pour
/// un succes. Les assertions restent donc dans le corps du test.
Future<String?> _familyOf(TextStyle Function() build) async {
  final result = Completer<String?>();
  runZonedGuarded(() async {
    result.complete(build().fontFamily);
  }, (error, stack) {
    // Rejet POSTERIEUR au calcul (le chargement de police avorte) : sans
    // interet ici, `result` est deja complete et ce `completeError` ne fait
    // rien.
    //
    // Mais si c'est `build()` LUI-MEME qui a leve, alors rien n'est encore
    // complete, et il faut propager. Completer a `null` ferait rendre `false`
    // a `_isCinzel(null)`, et les huit assertions `isFalse` du fichier
    // passeraient sans avoir rien mesure -- un test vert qui ne teste plus.
    if (!result.isCompleted) result.completeError(error, stack);
  });
  return result.future;
}

void main() {
  setUpAll(() {
    // Sans ca, chaque appel a un helper declenche un telechargement de la
    // police chez Google, qui echoue dans un test headless et fait tomber
    // l'assertion sur une erreur reseau plutot que sur la police. Le nom de
    // famille, lui, est calcule sans la police : c'est tout ce qu'on mesure
    // ici.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('les titres restent en Cinzel', () {
    test('pageTitle, sectionTitle, cardTitle et appBarTitle sont en Cinzel',
        () async {
      expect(_isCinzel(await _familyOf(AppTextStyles.pageTitle)), isTrue);
      expect(_isCinzel(await _familyOf(AppTextStyles.sectionTitle)), isTrue);
      expect(_isCinzel(await _familyOf(AppTextStyles.cardTitle)), isTrue);
      expect(_isCinzel(await _familyOf(AppTextStyles.appBarTitle)), isTrue);
    });
  });

  group("le texte courant n'est plus en Cinzel", () {
    test('body, subtitle, label, buttonText, bold et les onglets', () async {
      expect(_isCinzel(await _familyOf(AppTextStyles.body)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.subtitle)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.label)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.buttonText)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.bold)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.tabActive)), isFalse);
      expect(_isCinzel(await _familyOf(AppTextStyles.tabInactive)), isFalse);
    });

    test("text() est l'echappatoire generique, et n'est pas en Cinzel",
        () async {
      expect(_isCinzel(await _familyOf(AppTextStyles.text)), isFalse);
    });
  });

  group("l'echappatoire cinzel() a disparu du code", () {
    /// Tous les .dart sous lib/, avec leur chemin normalise en separateurs
    /// POSIX pour que les exclusions marchent aussi sous Windows.
    Iterable<(String, List<String>)> fichiersLib() sync* {
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        yield (entity.path.replaceAll(r'\', '/'), entity.readAsLinesSync());
      }
    }

    test('plus aucun appel a AppTextStyles.cinzel( sous lib/', () {
      final offenders = <String>[];
      for (final (chemin, lignes) in fichiersLib()) {
        for (var i = 0; i < lignes.length; i++) {
          if (lignes[i].contains('AppTextStyles.cinzel(')) {
            offenders.add('$chemin:${i + 1}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'Migrer ces appels vers text() (texte courant) ou vers '
              'sectionTitle()/cardTitle() (titres) :\n${offenders.join('\n')}');
    });

    test('aucun appel direct a GoogleFonts.cinzel( hors du fichier de styles',
        () {
      // L'autre facon de rouvrir l'echappatoire : contourner AppTextStyles et
      // appeler google_fonts directement. Le depot en comptait 325 avant la
      // centralisation ; rien n'empeche d'en reintroduire un.
      const source = 'lib/theme/app_text_styles.dart';
      final offenders = <String>[];
      for (final (chemin, lignes) in fichiersLib()) {
        if (chemin.endsWith(source)) continue;
        for (var i = 0; i < lignes.length; i++) {
          if (lignes[i].contains('GoogleFonts.cinzel(')) {
            offenders.add('$chemin:${i + 1}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: "Cinzel ne se choisit qu'au travers d'AppTextStyles, et "
              'seulement pour un titre. Passer par un helper de titre :\n'
              '${offenders.join('\n')}');
    });
  });
}
