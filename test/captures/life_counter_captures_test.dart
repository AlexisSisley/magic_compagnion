// test/captures/life_counter_captures_test.dart
//
// Captures visuelles bloquantes du lot 5 (compteurs personnalises), voir
// docs/superpowers/plans/2026-09-17-life-counter-v4-lot5-compteurs-personnalises.md,
// section "Criteres de sortie du lot > Visuels -- bloquants". Ce fichier ne
// verifie rien par assertion : il rend ces cinq ecrans en PNG reel via
// `matchesGoldenFile`, pour qu'un humain les regarde avant merge -- un test
// de widget mesure des contraintes, il ne dit rien de la lisibilite.
//
// Tag `capture` (voir dart_test.yaml) : ces PNG dependent du rendu de police
// de la machine qui les produit, donc `flutter test` seul (CI) les ignore.
// Pour les (re)generer :
//   flutter test --tags capture --run-skipped --update-goldens test/captures/life_counter_captures_test.dart
//
// `--run-skipped` est necessaire EN PLUS de `--tags capture` : la config
// `skip:` de dart_test.yaml s'applique meme quand le tag est explicitement
// selectionne (verifie empiriquement -- `--tags capture` seul les laisse
// skippes). C'est une garantie supplementaire, pas un defaut : personne ne
// regenere ces PNG par accident en tapant seulement `--tags capture`.
//
// Polices reelles (voir `_loadSystemFont` / `setUpAll` plus bas) : le binding
// de test headless de cette machine ne rend AUCUN glyphe reel par defaut
// (texte Material par defaut compris, pas seulement `GoogleFonts.cinzel`) --
// verifie en regardant une premiere capture produite sans ce chargement :
// tout le texte y etait du tofu illisible. On lit donc de vraies polices
// systeme sur disque (Segoe UI, Consolas) et on les enregistre sous les noms
// de famille attendus par le rendu ('Roboto' -- repli Flutter par defaut,
// 'Cinzel' -- `AppTextStyles`, 'Roboto Mono' -- chiffre de compteur), avant
// tout `pumpWidget`. Aucune police n'est copiee dans le depot, aucune
// dependance n'est ajoutee au pubspec -- un fichier systeme est lu tel quel,
// a l'execution. Si ce fichier est absent, le test echoue bruyamment (voir
// `_loadSystemFont`) plutot que de produire a nouveau du tofu en silence.
@Tags(['capture'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magic_companion/models/counter_type.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/widgets/life_counter/layouts/adaptive_grid.dart';
import 'package:magic_companion/widgets/life_counter/zone/commander_damage_grid.dart';
import 'package:magic_companion/widgets/life_counter/zone/conditional_handle.dart';
import 'package:magic_companion/widgets/life_counter/zone/counter_editor_dialog.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_drawer.dart';
import 'package:magic_companion/widgets/life_counter/zone/player_skin_picker.dart'
    show playerSkinColorOptions;

// Compteurs personnalises reutilises entre les captures 1, 3 et 4 -- memes
// donnees "realistes" partout plutot que de les redecrire a chaque fois.
const _rage = CounterType(
  id: 'rage',
  name: 'Rage',
  emoji: '🔥',
  color: 0xFFE64A19,
  maxValue: 8,
);
const _focus = CounterType(
  id: 'focus',
  name: 'Concentration',
  emoji: '🧠',
  color: 0xFF3F51B5,
);

final _poison = CounterType.builtInCounters.firstWhere((c) => c.id == 'poison');
final _energy = CounterType.builtInCounters.firstWhere((c) => c.id == 'energy');
final _commanderTax =
    CounterType.builtInCounters.firstWhere((c) => c.id == 'commander_tax');

ThemeData _appTheme() => ThemeData(
      brightness: Brightness.dark,
      // `fontFamily: 'Roboto'` explicite (pas seulement `ThemeData.dark()`
      // par defaut) : c'est la famille que tout `Text`/bouton sans style de
      // police propre (donc `fontFamily` null) resout via le `TextTheme`
      // issu de ce theme -- voir le commentaire de fichier sur `_loadSystemFont`.
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
    );

/// Charge une police REELLE du systeme (jamais copiee dans le depot, jamais
/// une dependance pubspec) et l'enregistre sous [family] pour ce process de
/// test -- voir le commentaire de fichier.
///
/// Echoue bruyamment (`fail`, pas une exception avalee) si [absolutePath]
/// n'existe pas : une capture qui retombe silencieusement sur du tofu est
/// exactement le piege que ce mecanisme existe pour eviter, pas une
/// degradation acceptable.
///
/// Lecture SYNCHRONE (`readAsBytesSync`), pas `await file.readAsBytes()` --
/// verifie empiriquement (probe isole) que la variante async reste bloquee
/// indefiniment dans ce binding de test : la notification de fin d'E/S
/// asynchrone semble ne jamais atteindre la zone du test tant que rien ne la
/// pompe (le meme symptome, en substance, que le fetch reseau ecarte plus
/// haut). La lecture synchrone d'un petit fichier local est un simple appel
/// bloquant, sans cette dependance -- pas la meme classe de risque qu'un
/// `tester.runAsync` sur un appel reseau (explicitement ecarte).
Future<void> _loadSystemFont(String family, String absolutePath) async {
  final file = File(absolutePath);
  if (!file.existsSync()) {
    fail(
      'Police systeme introuvable : "$absolutePath" (attendue pour charger '
      'la famille "$family"). Sans elle, cette capture rendrait du texte en '
      'tofu illisible au lieu d\'echouer -- voir le commentaire de fichier '
      'sur `_loadSystemFont`. Ajuste le chemin pour la machine qui '
      'regenere ces PNG.',
    );
  }
  final bytes = file.readAsBytesSync();
  final byteData = ByteData.view(Uint8List.fromList(bytes).buffer);
  final loader = FontLoader(family)..addFont(Future.value(byteData));
  await loader.load();
}

/// Repertoire des polices Windows -- via `%SystemRoot%` plutot qu'un
/// `C:\Windows` en dur, au cas ou une autre machine l'aurait installe
/// ailleurs (rare, mais gratuit a couvrir).
String get _windowsFontsDir {
  final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  return '$systemRoot\\Fonts';
}

/// Charge les polices reelles dont le rendu de ces captures a besoin (voir
/// le commentaire de fichier) : Segoe UI pour le texte courant ('Roboto',
/// repli Flutter par defaut) ET pour celui de `AppTextStyles` (Cinzel).
///
/// **Trouvaille (probe isole, a consigner) :** `fontFamilyFallback` ne
/// prend PAS le relais quand la famille primaire est introuvable, contre
/// l'attente initiale -- verifie sur trois variantes cote a cote dans un
/// meme probe (`TextStyle(fontFamily: 'Cinzel')` direct : net ; le meme
/// texte via `GoogleFonts.cinzel()`, dont le style rendu porte pourtant
/// `fontFamilyFallback: ['Cinzel']` : tofu ; un `fontFamilyFallback:
/// ['Cinzel']` pose a la main sur une famille primaire volontairement
/// absente : tofu aussi). `google_fonts` ne fixe jamais `fontFamily` a
/// 'Cinzel' -- il fixe un nom COMPOSE, unique par poids (`familyWithVariant.
/// toString()`, ex. `'Cinzel_600'`), et ne retombe sur 'Cinzel' que dans
/// `fontFamilyFallback`. Il faut donc enregistrer la police reelle sous ce
/// nom compose exact (primaire), pas sous le nom nu (fallback, inefficace
/// ici) : identifie en imprimant `AppTextStyles.cardTitle().fontFamily` et
/// `AppTextStyles.body().fontFamily` dans un probe -- 'Cinzel_600' et
/// 'Cinzel_regular' respectivement, les deux seuls utilises par ces
/// captures (`cardTitle`/`body`). Si une future capture utilise un autre
/// style `AppTextStyles` (poids different, ou `lifeNumeral`/`Roboto Mono`),
/// reimprime son `.fontFamily` et ajoute la famille composee correspondante
/// ici -- le nom nu ('Cinzel', 'Roboto Mono') ne suffit pas.
Future<void> _loadRealFontsForCaptures() async {
  await _loadSystemFont('Roboto', '$_windowsFontsDir\\segoeui.ttf');
  await _loadSystemFont('Cinzel_600', '$_windowsFontsDir\\segoeui.ttf'); // AppTextStyles.cardTitle()
  await _loadSystemFont('Cinzel_regular', '$_windowsFontsDir\\segoeui.ttf'); // AppTextStyles.body()

  // Bonus (pas demande explicitement, mais gratuit et directement utile a
  // la lisibilite de ces captures) : les boutons +/- (`Icons.remove`/
  // `Icons.add`) et l'icone de retrait rendent sans lui en tofu. La police
  // 'MaterialIcons' n'est ni un fichier du depot ni une police Windows --
  // c'est un artefact DEJA present sur cette machine parce qu'il est fourni
  // par le SDK Flutter installe (`$FLUTTER_ROOT/bin/cache/artifacts/
  // material_fonts/`), donc toujours au meme endroit relatif au SDK qui
  // execute ce test, sur n'importe quelle machine qui a `flutter test` --
  // toujours pas une dependance pubspec ni une police copiee dans le depot.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final materialIconsPath =
        '$flutterRoot\\bin\\cache\\artifacts\\material_fonts\\MaterialIcons-Regular.otf';
    if (File(materialIconsPath).existsSync()) {
      await _loadSystemFont('MaterialIcons', materialIconsPath);
    }
    // Absent : pas de `fail()` ici (contrairement a `_loadSystemFont`) --
    // ce n'est pas une des trois polices minimales demandees, seulement un
    // bonus. Les icones +/- resteraient alors en tofu, visible et signale
    // dans le rapport, jamais une illisibilite qui se cache.
  }
}

/// Fixe la taille de la fenetre de test (et la restaure a la fin), comme
/// `life_counter_page_test.dart:1449` -- dpr 1.0 pour que la taille logique
/// demandee soit la taille physique rendue, sans surprise d'echelle.
void _setSurfaceSize(WidgetTester tester, Size size) {
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// Execute [body] (typiquement `pumpWidget` suivi de `tap`/`pumpAndSettle`)
/// de sorte que l'exception `google_fonts` residuelle (voir le commentaire
/// au-dessus de `main()`) ne fasse pas echouer CE test.
///
/// Pourquoi `pumpAndSettle()` a l'interieur de [body] et pas un
/// `pump(duration)` borne
/// (contrairement a la regle habituelle de ce depot, "jamais pumpAndSettle"
/// -- valable pour `CriticalOverlay`, qui boucle indefiniment) : ces
/// captures n'ont aucune animation en boucle, et `pumpAndSettle()` avance
/// l'horloge FICTIVE du binding de test jusqu'a la prochaine echeance
/// programmee (au lieu d'attendre un temps REEL) -- c'est ce qui permet au
/// futur de chargement de police, rejete, de se resoudre tout de suite
/// plutot que de rester pendant (verifie : un `await` nu sur ce futur, hors
/// de tout `pump`, reste bloque 10 minutes ici, jusqu'au timeout du test).
///
/// **Doit envelopper TOUT appel qui declenche un premier rendu
/// `AppTextStyles.cardTitle()`/`.body()`**, `pumpWidget` inclus -- pas
/// seulement le `pumpAndSettle()` final. Trouvaille (ronde 1 de cette
/// fonction) : en enveloppant seulement le `pumpAndSettle()` d'ouverture du
/// tiroir, les tests 01-03 passaient (leur premier `pumpWidget` ne rend
/// qu'un bouton par-defaut, sans Cinzel -- le tiroir n'ouvre qu'ensuite,
/// DANS la zone). Le test 04, qui rend ses quatre zones (et leur Cinzel) au
/// tout premier `pumpWidget`, restait marque [E] : ce premier appel avait
/// lieu HORS de toute zone protegee, la Future orpheline s'echappait donc
/// vers la zone du test avant que cette fonction ne soit meme appelee.
Future<void> _runGuarded(Future<void> Function() body) async {
  final done = Completer<void>();
  // `runZonedGuarded`, pas seulement un `try/catch` local : verifie que le
  // `try/catch` seul ne suffit PAS (le test restait marque [E] malgre lui,
  // et malgre un `tester.takeException()` derriere -- les deux essayes et
  // ecartes). La `loadingFuture` orpheline de `googleFontsTextStyle` (jamais
  // `await`-ee par le widget lui-meme, voir le commentaire de fichier) n'est
  // pas la Future que `pumpWidget`/`pumpAndSettle()` renvoie -- son rejet
  // remonte directement au gestionnaire d'erreurs non capturees de la zone
  // COURANTE au moment ou elle est cree, pas a un `catch` place autour d'un
  // `await` different. L'executer dans une zone a soi, avec son propre
  // `onError`, est le seul point d'interception qui la precede.
  runZonedGuarded(() async {
    try {
      await body();
    } finally {
      if (!done.isCompleted) done.complete();
    }
  }, (error, stack) {
    // Repli attendu (voir le commentaire de fichier) : le rendu ne depend
    // pas de cette Future, chargee sous une police reelle en `setUpAll`.
    if (!done.isCompleted) done.complete();
  });
  await done.future;
}

/// Ouvre le tiroir joueur avec des donnees fixees par l'appelant, sur un
/// ecran de taille telephone portrait -- pas la taille de test par defaut.
Future<void> _pumpDrawer(
  WidgetTester tester, {
  required String playerName,
  required List<CounterType> activeCounters,
  required Map<String, int> counters,
  List<CommanderDamageOpponent> commanderDamage = const [],
  int lethalCommanderDamage = 0,
  bool isMonarch = false,
}) async {
  _setSurfaceSize(tester, const Size(390, 844));
  await _runGuarded(() async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _appTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPlayerDrawer(
                  context: context,
                  playerName: playerName,
                  activeCounters: activeCounters,
                  counters: counters,
                  isMonarch: isMonarch,
                  isEliminated: false,
                  onCounterDelta: (_, _) {},
                  onToggleMonarch: () {},
                  onEliminate: () {},
                  onResetCounters: () {},
                  commanderDamage: commanderDamage,
                  onCommanderDamageDelta: (_, _) {},
                  lethalCommanderDamage: lethalCommanderDamage,
                  onCreateCounter: (_) async =>
                      (success: true, message: 'Compteur cree.'),
                  onRemoveCounter: (_) {},
                ),
                child: const Text('Ouvrir le tiroir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  });
}

/// Un rectangle simplifie mais fidele a la geometrie reelle de
/// `PlayerZone` (en-tete 40px, cadran au milieu, `ConditionalHandle` en bas
/// -- voir `player_zone.dart`) : suffisant pour juger la largeur reellement
/// disponible pour les puces de la poignee dans une zone a 4 joueurs, sans
/// tirer toute la machinerie Riverpod/services de `PlayerZone`.
Widget _mockZone({
  required String name,
  required int life,
  required Color color,
  required CounterSummary summary,
}) {
  return Container(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.borderSubtle, width: 1),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              name,
              style: AppTextStyles.body(color: AppColors.textPrimary),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              '$life',
              style: AppTextStyles.cardTitle(fontSize: 40),
            ),
          ),
        ),
        ConditionalHandle(summary: summary),
      ],
    ),
  );
}

// `AppTextStyles.cardTitle()`/`.body()` chargent Cinzel via `google_fonts`,
// qui tente par defaut une requete reseau reelle vers fonts.gstatic.com.
// `GoogleFonts.config.allowRuntimeFetching = false` (voir `main()`) coupe
// cette tentative -- mais NE PAS attendre `GoogleFonts.pendingFonts()`
// ensuite : verifie empiriquement (10 minutes de timeout, cinq fois
// identiques, un par test) que ce futur reste indefiniment pendant dans ce
// binding de test des que le fetch reseau est coupe, qu'on l'attende sous
// une vraie horloge (`tester.runAsync`) ou sous l'horloge virtualisee
// ordinaire. Sans l'attendre, ce futur orphelin ne bloque rien : le rendu
// n'en depend pas -- `fontFamilyFallback: ['Cinzel']` (pose par
// `google_fonts` sur le `TextStyle` qu'il rend, AVANT meme de tenter de
// charger quoi que ce soit) resout deja vers la VRAIE police Segoe UI
// chargee sous ce nom par `_loadRealFontsForCaptures` ci-dessous, que ce
// futur en arriere-plan echoue, reussisse ou ne se termine jamais.
void main() {
  setUpAll(() async {
    // Bloque tout fetch reseau de `google_fonts` (jamais fiable dans le
    // binding de test -- voir le commentaire au-dessus de `main()`) : le
    // repli sur 'Cinzel' / 'Roboto Mono' ci-dessous est ce qui rendra
    // reellement le texte.
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRealFontsForCaptures();
  });

  group('Captures -- lot 5, compteurs personnalises', () {
    testWidgets('01 - tiroir joueur en Commander (4 compteurs actifs)',
        (tester) async {
      await _pumpDrawer(
        tester,
        playerName: 'Alexis',
        activeCounters: [_poison, _energy, _commanderTax, _rage],
        counters: const {
          'poison': 4,
          'energy': 6,
          'commander_tax': 3,
          'rage': 5,
        },
        commanderDamage: const [
          CommanderDamageOpponent(
              playerId: 2, name: 'Théo', colorValue: 0xFF1976D2, damage: 6),
          CommanderDamageOpponent(
              playerId: 3, name: 'Nina', colorValue: 0xFF7B1FA2, damage: 0),
          CommanderDamageOpponent(
              playerId: 4, name: 'Marc', colorValue: 0xFF388E3C, damage: 12),
        ],
        lethalCommanderDamage: 21,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/01_tiroir_commander.png'),
      );
    });

    testWidgets(
        '02 - tiroir joueur en Standard (2 compteurs, sans taxe de commandant)',
        (tester) async {
      await _pumpDrawer(
        tester,
        playerName: 'Camille',
        activeCounters: [_poison, _energy],
        counters: const {'poison': 1, 'energy': 3},
        // Standard : maxCommanderDamage = 0 (game_format.dart) -> pas de
        // grille de degats de commandant dans le tiroir. C'est la preuve
        // visuelle du defaut corrige par ce lot (le tiroir affichait "Taxe
        // de commandant" en Standard avant la tache 2).
        commanderDamage: const [],
        lethalCommanderDamage: 0,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/02_tiroir_standard.png'),
      );
    });

    testWidgets(
        '03 - tiroir avec deux compteurs personnalises a cote des integres',
        (tester) async {
      await _pumpDrawer(
        tester,
        playerName: 'Yohann',
        activeCounters: [_poison, _energy, _rage, _focus],
        counters: const {
          'poison': 0,
          'energy': 2,
          'rage': 5,
          'focus': 1,
        },
        commanderDamage: const [],
        lethalCommanderDamage: 0,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/03_tiroir_compteurs_personnalises.png'),
      );
    });

    testWidgets(
        '04 - poignee conditionnelle en debordement, a la largeur d\'une '
        'zone de partie a 4 joueurs',
        (tester) async {
      // 360x800 : largeur de telephone d'entree de gamme courante, pas
      // l'ecran confortable des tests par defaut. AdaptiveGrid a 4 joueurs
      // (playerCount=4, pas de sous-grille -- reservee a 8) partage cette
      // largeur en 2 colonnes : chaque zone recoit ~360/2 - marges, la
      // largeur reelle que voit `ConditionalHandle._band`'s LayoutBuilder.
      _setSurfaceSize(tester, const Size(360, 800));

      final crowded = CounterSummary(
        counters: [
          MapEntry(_poison, 10), // sature
          MapEntry(_energy, 8),
          MapEntry(_commanderTax, 5),
          MapEntry(_rage, 6),
          MapEntry(_focus, 3),
        ],
        worstCommanderDamage: 14,
      );
      final modest = CounterSummary(
        counters: [MapEntry(_poison, 1), MapEntry(_energy, 2)],
      );
      const calm = CounterSummary();
      const singleThreat = CounterSummary(worstCommanderDamage: 9);

      await _runGuarded(() async {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _appTheme(),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: AdaptiveGrid(
                    playerZones: [
                      _mockZone(
                        name: 'Alexis',
                        life: 32,
                        color: Colors.red.shade900,
                        summary: crowded,
                      ),
                      _mockZone(
                        name: 'Camille',
                        life: 38,
                        color: Colors.blue.shade900,
                        summary: modest,
                      ),
                      _mockZone(
                        name: 'Théo',
                        life: 40,
                        color: Colors.green.shade800,
                        summary: calm,
                      ),
                      _mockZone(
                        name: 'Nina',
                        life: 27,
                        color: Colors.purple.shade900,
                        summary: singleThreat,
                      ),
                    ],
                    centralBar: SizedBox(
                      height: 36,
                      child: Center(
                        child: Text(
                          'Partie a 4 joueurs',
                          style: AppTextStyles.body(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/04_poignee_debordement_4_joueurs.png'),
      );
    });

    testWidgets(
        '05 - dialogue de creation de compteur, rempli, telephone portrait',
        (tester) async {
      _setSurfaceSize(tester, const Size(375, 812));

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _appTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => CounterEditorDialog.show(context),
                  child: const Text('Nouveau compteur'),
                ),
              ),
            ),
          ),
        ),
      );
      await _runGuarded(() async {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();
      });

      await tester.enterText(
        find.byKey(const ValueKey('counter_editor_name')),
        'Fureur',
      );
      await tester.enterText(
        find.byKey(const ValueKey('counter_editor_emoji')),
        '🔥',
      );
      await tester.enterText(
        find.byKey(const ValueKey('counter_editor_max_value')),
        '6',
      );
      // Une couleur nettement distincte des defauts (rouge intégré/vert) --
      // teal, pour que le choix soit visible dans la capture.
      final tealSwatch = playerSkinColorOptions.firstWhere(
        (c) => c.toARGB32() == Colors.teal.shade900.toARGB32(),
      );
      await tester.tap(
        find.byKey(ValueKey('counter_editor_color_${tealSwatch.toARGB32()}')),
      );
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/05_dialogue_creation_compteur.png'),
      );
    });
  });
}
