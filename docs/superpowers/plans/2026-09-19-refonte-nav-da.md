# Refonte navigation & direction artistique — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le couple `ShellRoute` + Drawer fourre-tout par cinq onglets à pile indépendante plus un mode Jeu plein écran, et poser un socle de thème « Grimoire » que l'app consomme par jetons sémantiques au lieu de couleurs Material brutes.

**Architecture:** Le thème d'abord (une `ThemeExtension<MagicPalette>` branchée sur le `ThemeData`, d'abord à valeurs identiques pour prouver que la plomberie ne casse rien, puis aux valeurs Grimoire). Le mode Jeu et l'écran Réglages ensuite, pendant que le Drawer existe encore et sert de porte d'entrée temporaire. La bascule vers `StatefulShellRoute.indexedStack` et la suppression du Drawer en dernier, quand chaque écran du tiroir a déjà une nouvelle adresse.

**Tech Stack:** Flutter (Dart SDK `^3.9.2`), `go_router ^17.1.0`, `flutter_riverpod ^3.0.3`, `google_fonts ^6.2.1`, `drift ^2.22.1`, `shared_preferences ^2.2.3`.

**Spec:** `docs/superpowers/specs/2026-09-19-refonte-nav-da-design.md`

## Global Constraints

- **Ordre des lots corrige par rapport a la spec** (la spec sera mise a jour en consequence). La spec livre la nav (son lot 2) avant le mode Jeu (son lot 4) et les Réglages (son lot 3). C'est impossible : le Drawer est le **seul** accès à Tournoi, Oracle, Glossaire, Calculateur, Profils, Drive et À propos. Le supprimer avant que `/play` et `/settings` existent orpheline sept écrans. L'ordre exécutable est : socle de thème → mode Jeu → Réglages → nav.
- **La suite de tests doit être verte à la fin de chaque tâche.** Commande : `flutter test`. Référence de départ : 652 tests.
- **Les captures visuelles sont des goldens tagués.** Génération : `flutter test --tags capture --run-skipped --update-goldens <fichier>`. Elles vivent dans `test/captures/`, les PNG dans `test/captures/goldens/`. `flutter test` seul les ignore (voir `dart_test.yaml`).
- **Un lot qui déplace des pixels ne se clôt pas sur des tests verts.** Les tâches marquées **CAPTURE BLOQUANTE** exigent qu'un humain regarde les PNG avant de passer à la suite.
- **Frontière des jetons :** `MagicPalette` porte ce qui change avec le thème (surfaces, encres, accent, sémantique). `AppColors` garde ce qui ne change pas avec le thème — les couleurs de domaine Magic (`mana*`, `rarity*`, `power*`, `badge*`). Aucune valeur n'est partagée entre les deux familles.
- **Aucun écran neuf n'ajoute de site `AppColors.*` de surface, d'encre ou de sémantique.** Les écrans créés par ce plan consomment `MagicPalette.of(context)`. Les 2 068 sites existants ne sont pas migrés ici (hors périmètre, voir spec §3).
- **Convention de fichier du dépôt :** chaque fichier Dart commence par `// Fichier : lib/...` suivi d'une ligne de rôle. Commentaires en français, sans accents dans les commentaires de code existants — suivre le style du fichier voisin.
- **Un commit par tâche**, message en français, préfixe conventionnel (`feat:`, `refactor:`, `test:`, `style:`).

**Hors périmètre de ce plan :** le lot « composants » de la spec (`AppCard`, `AppButton`, `AppScaffold`, `AppEmptyState` + migration écran par écran) et le thème clair « Table ». Ils font l'objet de leurs propres plans, parce que leur découpage en tâches dépend de ce que donnent les captures des lots ci-dessous.

---

# Lot A — Le socle de thème (invisible)

Objectif : brancher la plomberie sans qu'aucun pixel ne bouge. C'est le filet de sécurité du lot B.

---

### Task 1: MagicPalette, à valeurs identiques à l'existant

**Files:**
- Create: `lib/theme/magic_palette.dart`
- Create: `lib/theme/app_theme.dart`
- Modify: `lib/main.dart:144-155` (le bloc `theme: ThemeData.dark().copyWith(...)`)
- Test: `test/theme/magic_palette_test.dart`

**Interfaces:**
- Produces: `MagicPalette` (classe `ThemeExtension<MagicPalette>`) avec les champs `canvas`, `raised`, `overlay`, `line`, `inkPrimary`, `inkSecondary`, `inkMuted`, `accent`, `onAccent`, `success`, `warning`, `danger`, `info` — tous `Color`. Accès : `MagicPalette.of(BuildContext) → MagicPalette`.
- Produces: `buildAppTheme() → ThemeData`, à appeler depuis `MaterialApp.router(theme: ...)`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/theme/magic_palette_test.dart` :

```dart
// Fichier : test/theme/magic_palette_test.dart
// Verifie que MagicPalette est atteignable depuis le contexte et que le lot A
// n'a change aucune valeur : chaque jeton doit valoir exactement la couleur
// AppColors qu'il remplace.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:magic_companion/theme/app_theme.dart';
import 'package:magic_companion/theme/magic_palette.dart';

void main() {
  testWidgets('MagicPalette est resolvable depuis le contexte', (tester) async {
    MagicPalette? palette;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        palette = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(palette, isNotNull);
  });

  testWidgets('lot A ne change aucune valeur', (tester) async {
    late MagicPalette p;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        p = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(p.canvas, AppColors.scaffoldBackground);
    expect(p.raised, AppColors.cardBackground);
    expect(p.overlay, AppColors.dialogBackground);
    expect(p.line, AppColors.borderMedium);
    expect(p.inkPrimary, AppColors.textPrimary);
    expect(p.inkSecondary, AppColors.textSecondary);
    expect(p.inkMuted, AppColors.textMuted);
    expect(p.accent, AppColors.primary);
    expect(p.onAccent, AppColors.textOnPrimary);
    expect(p.success, AppColors.success);
    expect(p.warning, AppColors.warning);
    expect(p.danger, AppColors.error);
    expect(p.info, AppColors.info);
  });

  test('lerp interpole chaque jeton', () {
    const a = MagicPalette(
      canvas: Color(0xFF000000), raised: Color(0xFF000000),
      overlay: Color(0xFF000000), line: Color(0xFF000000),
      inkPrimary: Color(0xFF000000), inkSecondary: Color(0xFF000000),
      inkMuted: Color(0xFF000000), accent: Color(0xFF000000),
      onAccent: Color(0xFF000000), success: Color(0xFF000000),
      warning: Color(0xFF000000), danger: Color(0xFF000000),
      info: Color(0xFF000000),
    );
    const b = MagicPalette(
      canvas: Color(0xFFFFFFFF), raised: Color(0xFFFFFFFF),
      overlay: Color(0xFFFFFFFF), line: Color(0xFFFFFFFF),
      inkPrimary: Color(0xFFFFFFFF), inkSecondary: Color(0xFFFFFFFF),
      inkMuted: Color(0xFFFFFFFF), accent: Color(0xFFFFFFFF),
      onAccent: Color(0xFFFFFFFF), success: Color(0xFFFFFFFF),
      warning: Color(0xFFFFFFFF), danger: Color(0xFFFFFFFF),
      info: Color(0xFFFFFFFF),
    );

    final mid = a.lerp(b, 0.5);

    expect(mid.canvas, Color.lerp(a.canvas, b.canvas, 0.5));
    expect(mid.accent, Color.lerp(a.accent, b.accent, 0.5));
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/theme/magic_palette_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:magic_companion/theme/magic_palette.dart'`

- [ ] **Step 3: Écrire MagicPalette**

Créer `lib/theme/magic_palette.dart` :

```dart
// Fichier : lib/theme/magic_palette.dart
// Jetons de couleur qui dependent du theme, exposes via ThemeExtension.
//
// Frontiere avec AppColors : ici vivent les couleurs qui changeront quand le
// theme clair "Table" arrivera (surfaces, encres, accent, semantique). Les
// couleurs de domaine Magic (mana, rarete, power level, badges) restent des
// const dans AppColors : elles ne dependent pas du theme.

import 'package:flutter/material.dart';

@immutable
class MagicPalette extends ThemeExtension<MagicPalette> {
  const MagicPalette({
    required this.canvas,
    required this.raised,
    required this.overlay,
    required this.line,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Fond de page.
  final Color canvas;

  /// Fond des cartes et tuiles posees sur le canvas.
  final Color raised;

  /// Fond des modales et menus.
  final Color overlay;

  /// Separateurs et contours.
  final Color line;

  final Color inkPrimary;
  final Color inkSecondary;

  /// Reserve aux elements non textuels (icones decoratives, puces).
  /// Ne jamais s'en servir pour du texte : le contraste n'est pas garanti.
  final Color inkMuted;

  final Color accent;

  /// Couleur de texte posee SUR l'accent.
  final Color onAccent;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Raccourci d'acces. Leve si le ThemeData n'enregistre pas l'extension —
  /// c'est voulu : un ecran sans palette est un bug de configuration, pas un
  /// cas a rattraper silencieusement par des couleurs par defaut.
  static MagicPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<MagicPalette>();
    assert(palette != null,
        'MagicPalette absente du ThemeData. Utiliser buildAppTheme().');
    return palette!;
  }

  @override
  MagicPalette copyWith({
    Color? canvas,
    Color? raised,
    Color? overlay,
    Color? line,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkMuted,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return MagicPalette(
      canvas: canvas ?? this.canvas,
      raised: raised ?? this.raised,
      overlay: overlay ?? this.overlay,
      line: line ?? this.line,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  MagicPalette lerp(ThemeExtension<MagicPalette>? other, double t) {
    if (other is! MagicPalette) return this;
    return MagicPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      line: Color.lerp(line, other.line, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
```

- [ ] **Step 4: Écrire buildAppTheme et sortir le thème de main.dart**

Créer `lib/theme/app_theme.dart` :

```dart
// Fichier : lib/theme/app_theme.dart
// Construction du ThemeData de l'application. Sorti de main.dart pour que le
// theme soit testable sans monter toute l'app.

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'magic_palette.dart';

/// Palette du theme sombre.
///
/// Lot A : valeurs strictement identiques aux AppColors actuelles, pour que
/// l'introduction de l'extension ne deplace aucun pixel. Les valeurs Grimoire
/// arrivent au lot B.
const MagicPalette darkPalette = MagicPalette(
  canvas: AppColors.scaffoldBackground,
  raised: AppColors.cardBackground,
  overlay: AppColors.dialogBackground,
  line: AppColors.borderMedium,
  inkPrimary: AppColors.textPrimary,
  inkSecondary: AppColors.textSecondary,
  inkMuted: AppColors.textMuted,
  accent: AppColors.primary,
  onAccent: AppColors.textOnPrimary,
  success: AppColors.success,
  warning: AppColors.warning,
  danger: AppColors.error,
  info: AppColors.info,
);

ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: darkPalette.canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: darkPalette.onAccent,
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: darkPalette.onAccent.withValues(alpha: 0.9),
      selectedItemColor: AppColors.primaryShade800,
      unselectedItemColor: darkPalette.inkMuted,
      type: BottomNavigationBarType.fixed,
    ),
    extensions: const <ThemeExtension<dynamic>>[darkPalette],
  );
}
```

Puis remplacer dans `lib/main.dart` le bloc `theme: ThemeData.dark().copyWith(...)` (lignes 144-155) par :

```dart
      theme: buildAppTheme(),
```

et ajouter l'import `import 'theme/app_theme.dart';` en haut de `lib/main.dart`. Retirer l'import `app_colors.dart` de `main.dart` s'il n'y est plus utilisé ailleurs (vérifier avec `grep -n "AppColors" lib/main.dart`).

- [ ] **Step 5: Lancer le test pour vérifier qu'il passe**

Run: `flutter test test/theme/magic_palette_test.dart`
Expected: PASS — 3 tests

- [ ] **Step 6: Lancer toute la suite**

Run: `flutter test`
Expected: PASS — aucune régression (652 tests de référence)

- [ ] **Step 7: Commit**

```bash
git add lib/theme/magic_palette.dart lib/theme/app_theme.dart lib/main.dart test/theme/magic_palette_test.dart
git commit -m "feat(theme): introduit MagicPalette a valeurs identiques

ThemeExtension branchee sur le ThemeData, valeurs strictement egales aux
AppColors actuelles. Aucun pixel ne bouge : c'est le filet de securite
avant de toucher aux valeurs au lot B.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Lot B — Les valeurs Grimoire

Objectif : la DA retenue. Ce lot déplace des pixels.

---

### Task 2: Séparer les couleurs sémantiques des couleurs de mana

Aujourd'hui `AppColors.success` vaut `Colors.green` (`0xFF4CAF50`) et `AppColors.manaGreen` vaut `0xFF4CAF50` — **la même couleur, exactement**. Un badge « possédée » et une carte verte sont indiscernables. `AppColors.error` (`0xFFF44336`) et `manaRed` (`0xFFEB4034`) sont distincts sur le papier mais séparés de quelques unités : indiscernables à l'œil aussi.

**Files:**
- Modify: `lib/theme/app_theme.dart` (la `darkPalette`)
- Test: `test/theme/magic_palette_test.dart` (ajout d'un groupe)

**Interfaces:**
- Consumes: `MagicPalette`, `darkPalette` (Task 1).
- Produces: aucun nouveau symbole. Les valeurs de `darkPalette.success`, `.warning`, `.danger`, `.info` cessent d'être égales aux `AppColors` correspondantes.

- [ ] **Step 1: Écrire le test qui échoue**

Ajouter à `test/theme/magic_palette_test.dart`, dans un nouveau `group` :

```dart
  group('separation semantique / domaine Magic', () {
    /// Distance euclidienne dans l'espace RGB. Grossiere, mais suffisante
    /// pour detecter deux couleurs qu'un oeil ne separera pas : en-dessous
    /// de 60, les deux pastilles se confondent sur un fond sombre.
    double rgbDistance(Color a, Color b) {
      final dr = ((a.r - b.r) * 255).abs();
      final dg = ((a.g - b.g) * 255).abs();
      final db = ((a.b - b.b) * 255).abs();
      return math.sqrt(dr * dr + dg * dg + db * db);
    }

    test('le vert succes ne se confond pas avec le vert mana', () {
      expect(rgbDistance(darkPalette.success, AppColors.manaGreen),
          greaterThan(60));
    });

    test('le rouge danger ne se confond pas avec le rouge mana', () {
      expect(rgbDistance(darkPalette.danger, AppColors.manaRed),
          greaterThan(60));
    });

    test('le bleu info ne se confond pas avec le bleu mana', () {
      expect(rgbDistance(darkPalette.info, AppColors.manaBlue),
          greaterThan(60));
    });
  });
```

Ajouter en haut du fichier : `import 'dart:math' as math;` et `import 'package:magic_companion/theme/app_theme.dart';` s'ils manquent.

Le test « lot A ne change aucune valeur » de la Task 1 va casser sur `success`, `danger` et `info`. C'est attendu : le remplacer par la version ci-dessous, qui ne verrouille plus que les jetons non touchés par ce lot.

```dart
  testWidgets('les jetons de surface et d\'encre sont inchanges au lot B', (tester) async {
    late MagicPalette p;

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: Builder(builder: (context) {
        p = MagicPalette.of(context);
        return const SizedBox.shrink();
      }),
    ));

    expect(p.onAccent, AppColors.textOnPrimary);
    expect(p.warning, AppColors.warning);
  });
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/theme/magic_palette_test.dart`
Expected: FAIL — « Expected: a value greater than <60> Actual: <0.0> » sur le vert

- [ ] **Step 3: Donner leurs propres valeurs aux jetons sémantiques**

Dans `lib/theme/app_theme.dart`, remplacer les quatre lignes sémantiques de `darkPalette` :

```dart
  // Semantique : valeurs propres, volontairement decalees des couleurs de
  // mana. Avant ce lot, success valait exactement manaGreen (0xFF4CAF50) et
  // un badge "possedee" etait indiscernable d'une carte verte.
  success: Color(0xFF4FA96B),
  warning: Color(0xFFD99B36),
  danger: Color(0xFFD9554F),
  info: Color(0xFF4C8DF5),
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/theme/magic_palette_test.dart`
Expected: PASS

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart test/theme/magic_palette_test.dart
git commit -m "fix(theme): separe les couleurs semantiques des couleurs de mana

success valait exactement manaGreen (0xFF4CAF50) : un badge 'possedee' et
une carte verte etaient indiscernables. Les quatre jetons de feedback ont
desormais leurs propres valeurs, verrouillees par une distance RGB minimale.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Les valeurs Grimoire, sous contrainte de contraste

**Files:**
- Modify: `lib/theme/app_theme.dart` (la `darkPalette`)
- Create: `test/theme/contrast_test.dart`

**Interfaces:**
- Consumes: `darkPalette` (Tasks 1-2).
- Produces: aucun nouveau symbole. `darkPalette` porte les valeurs Grimoire définitives.

- [ ] **Step 1: Écrire le test de contraste qui échoue**

Créer `test/theme/contrast_test.dart` :

```dart
// Fichier : test/theme/contrast_test.dart
// Verrouille les ratios de contraste WCAG de la palette Grimoire. Une valeur
// de couleur peut etre changee ; elle ne peut pas l'etre au point de rendre
// un texte illisible sans que ce test le dise.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_theme.dart';

/// Luminance relative WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// Ratio de contraste WCAG 2.1, entre 1 et 21.
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final p = darkPalette;

  group('contraste sur le fond de page', () {
    test('le texte principal atteint AAA (7:1)', () {
      expect(contrastRatio(p.inkPrimary, p.canvas), greaterThanOrEqualTo(7.0));
    });

    test('le texte secondaire atteint AA (4.5:1)', () {
      expect(contrastRatio(p.inkSecondary, p.canvas), greaterThanOrEqualTo(4.5));
    });

    test('l\'accent atteint AA (4.5:1)', () {
      expect(contrastRatio(p.accent, p.canvas), greaterThanOrEqualTo(4.5));
    });
  });

  group('contraste sur les surfaces surelevees', () {
    test('le texte principal atteint AAA sur une carte', () {
      expect(contrastRatio(p.inkPrimary, p.raised), greaterThanOrEqualTo(7.0));
    });

    test('le texte secondaire atteint AA sur une carte', () {
      expect(contrastRatio(p.inkSecondary, p.raised), greaterThanOrEqualTo(4.5));
    });
  });

  group('contraste des jetons semantiques', () {
    test('chaque couleur de feedback atteint AA sur le fond de page', () {
      for (final entry in {
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
        'info': p.info,
      }.entries) {
        expect(contrastRatio(entry.value, p.canvas), greaterThanOrEqualTo(4.5),
            reason: '${entry.key} est illisible sur le fond de page');
      }
    });
  });

  group('contraste du texte pose sur l\'accent', () {
    test('onAccent atteint AA sur accent', () {
      expect(contrastRatio(p.onAccent, p.accent), greaterThanOrEqualTo(4.5));
    });
  });

  group('hierarchie des surfaces', () {
    test('canvas, raised et overlay sont trois valeurs distinctes et croissantes', () {
      expect(_luminance(p.canvas), lessThan(_luminance(p.raised)));
      expect(_luminance(p.raised), lessThan(_luminance(p.overlay)));
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/theme/contrast_test.dart`
Expected: FAIL sur « hierarchie des surfaces » — aujourd'hui `canvas` vaut `0xFF1A1A1A` et `overlay` (`dialogBackground`) `0xFF1A1A2E` : l'échelle n'est pas monotone. Le test échoue aussi potentiellement sur `danger` et `info`, à confirmer en lisant la sortie.

- [ ] **Step 3: Appliquer les valeurs Grimoire**

Dans `lib/theme/app_theme.dart`, remplacer la déclaration complète de `darkPalette` :

```dart
/// Palette Grimoire — theme sombre officiel.
///
/// Noir d'encre et or patine. L'or remplace `Colors.yellow` : le jaune pur
/// vibre sur fond noir et fatigue en lecture longue.
///
/// Les trois surfaces forment une echelle monotone croissante en luminance
/// (canvas < raised < overlay) : c'est ce qui permet de lire l'elevation
/// d'un element sans lui ajouter une ombre.
const MagicPalette darkPalette = MagicPalette(
  canvas: Color(0xFF0E0E11),
  raised: Color(0xFF191820),
  overlay: Color(0xFF2A2733),
  line: Color(0xFF3A3646),

  inkPrimary: Color(0xFFF2EFE6),
  inkSecondary: Color(0xFFA9A396),
  inkMuted: Color(0xFF75705F),

  accent: Color(0xFFC9A227),
  onAccent: Color(0xFF14120B),

  success: Color(0xFF4FA96B),
  warning: Color(0xFFD99B36),
  danger: Color(0xFFD9554F),
  info: Color(0xFF4C8DF5),
);
```

Puis, dans `buildAppTheme()`, remplacer `selectedItemColor: AppColors.primaryShade800` par `selectedItemColor: darkPalette.accent` et `backgroundColor: darkPalette.onAccent.withValues(alpha: 0.9)` par `backgroundColor: darkPalette.raised`. Retirer l'import `app_colors.dart` de `app_theme.dart` s'il devient inutile.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/theme/contrast_test.dart`
Expected: PASS — 8 tests

Run: `flutter test`
Expected: PASS. Si un test existant verrouillait une couleur littérale, le corriger vers le jeton correspondant plutôt que de restaurer l'ancienne valeur.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart test/theme/contrast_test.dart
git commit -m "feat(theme): applique les valeurs Grimoire

Noir d'encre et or patine a la place du jaune Material, echelle de surfaces
monotone en luminance. Les ratios de contraste WCAG sont desormais verrouilles
par un test plutot que par l'oeil.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Rendre la typographie lisible

Tous les styles de `AppTextStyles` sont en Cinzel — `body()`, `subtitle()`, `label()`, `buttonText()`, `bold()`, `tabActive()`, `tabInactive()` compris. Cinzel est une romaine à capitales : sous 14 px elle est illisible. S'y ajoutent **182** appels à l'échappatoire générique `AppTextStyles.cinzel()`, documentée « à utiliser en dernier recours » et devenue le style par défaut de l'app.

**Files:**
- Modify: `lib/theme/app_text_styles.dart:33-149`
- Modify: ~50 fichiers sous `lib/` (remplacement mécanique, voir Step 4)
- Create: `test/theme/app_text_styles_test.dart`

**Interfaces:**
- Produces: `AppTextStyles.text({Color? color, double? fontSize, FontWeight? fontWeight, FontStyle? fontStyle}) → TextStyle` — l'échappatoire générique, en Source Sans 3.
- Removes: `AppTextStyles.cinzel(...)`. Tout appelant migre vers `text()` (texte courant) ou vers `pageTitle()` / `sectionTitle()` / `cardTitle()` / `appBarTitle()` (titres).

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/theme/app_text_styles_test.dart` :

```dart
// Fichier : test/theme/app_text_styles_test.dart
// Verrouille la repartition des polices : Cinzel aux titres, Source Sans 3
// au texte courant. Sous 14px, Cinzel — une romaine a capitales — n'est plus
// lisible ; c'est le premier facteur d'illisibilite de l'app avant ce lot.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/theme/app_text_styles.dart';

/// `GoogleFonts.cinzel()` produit un fontFamily de la forme 'Cinzel_regular'
/// ou 'Cinzel'. On teste donc le prefixe, pas l'egalite stricte.
bool _isCinzel(String? family) => family?.startsWith('Cinzel') ?? false;

void main() {
  group('les titres restent en Cinzel', () {
    test('pageTitle, sectionTitle, cardTitle et appBarTitle sont en Cinzel', () {
      expect(_isCinzel(AppTextStyles.pageTitle().fontFamily), isTrue);
      expect(_isCinzel(AppTextStyles.sectionTitle().fontFamily), isTrue);
      expect(_isCinzel(AppTextStyles.cardTitle().fontFamily), isTrue);
      expect(_isCinzel(AppTextStyles.appBarTitle().fontFamily), isTrue);
    });
  });

  group('le texte courant n\'est plus en Cinzel', () {
    test('body, subtitle, label, buttonText, bold et les onglets', () {
      expect(_isCinzel(AppTextStyles.body().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.subtitle().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.label().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.buttonText().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.bold().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.tabActive().fontFamily), isFalse);
      expect(_isCinzel(AppTextStyles.tabInactive().fontFamily), isFalse);
    });

    test('text() est l\'echappatoire generique, et n\'est pas en Cinzel', () {
      expect(_isCinzel(AppTextStyles.text().fontFamily), isFalse);
    });
  });

  group('l\'echappatoire cinzel() a disparu du code', () {
    test('plus aucun appel a AppTextStyles.cinzel( sous lib/', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('AppTextStyles.cinzel(')) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'Migrer ces appels vers text() (texte courant) ou vers '
              'sectionTitle()/cardTitle() (titres) :\n${offenders.join('\n')}');
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/theme/app_text_styles_test.dart`
Expected: FAIL — `AppTextStyles.text` n'existe pas, et 182 offenders listés

- [ ] **Step 3: Basculer les helpers de texte courant sur Source Sans 3**

Dans `lib/theme/app_text_styles.dart` :

Remplacer chaque `GoogleFonts.cinzel(` par `GoogleFonts.sourceSans3(` dans les helpers `subtitle`, `label`, `buttonText`, `body`, `bold`, `tabActive`, `tabInactive`. **Ne pas toucher** à `pageTitle`, `sectionTitle`, `cardTitle`, `appBarTitle`.

Puis remplacer le bloc `SHORTCUT` (lignes 132-149) par :

```dart
  // ============================================================
  // ECHAPPATOIRE GENERIQUE
  // ============================================================

  /// Texte courant, pour les cas non couverts par les methodes ci-dessus.
  ///
  /// Source Sans 3 : humaniste dessinee pour l'interface, lisible en petite
  /// taille, et de proportions classiques qui s'accordent avec Cinzel.
  /// Le choix de la police est isole ici et dans les helpers ci-dessus : il
  /// reste substituable en un point.
  ///
  /// Remplace l'ancien `cinzel()`, qui etait documente "a utiliser en dernier
  /// recours" et servait de style par defaut sur 182 sites.
  static TextStyle text({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
  }) =>
    GoogleFonts.sourceSans3(
      color: color ?? AppColors.textPrimary,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
    );
```

- [ ] **Step 4: Migrer mécaniquement les 182 appels**

```bash
grep -rl "AppTextStyles\.cinzel(" lib --include=*.dart \
  | xargs sed -i 's/AppTextStyles\.cinzel(/AppTextStyles.text(/g'
grep -rc "AppTextStyles\.text(" lib --include=*.dart | grep -v ":0" | wc -l
```

Ce remplacement est volontairement aveugle : il met tout le monde en texte courant. Les titres qui y perdent leur caractère seront repromus vers `sectionTitle()` ou `cardTitle()` à la lecture des captures de la Task 5 — c'est plus fiable que de deviner ici quels appels sont des titres.

Vérifier que le fichier `lib/router/tools_routes.dart` compile encore : il utilise `AppTextStyles.cinzel()` dans le titre d'AppBar du glossaire (ligne 49). Celui-là est un vrai titre — le passer à la main en `AppTextStyles.appBarTitle()`.

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/theme/app_text_styles_test.dart`
Expected: PASS — 4 tests, zéro offender

Run: `flutter analyze`
Expected: aucune erreur

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/theme/app_text_styles.dart lib/ test/theme/app_text_styles_test.dart
git commit -m "style(theme): reserve Cinzel aux titres

Tous les styles etaient en Cinzel, body() et label() compris. Cinzel est une
romaine a capitales : illisible sous 14px. Le texte courant passe sur Source
Sans 3, l'echappatoire cinzel() (182 sites) devient text(), et un test
interdit son retour.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Captures visuelles du lot B — **CAPTURE BLOQUANTE**

**Files:**
- Create: `test/captures/grimoire_captures_test.dart`
- Create: `test/captures/goldens/20_grimoire_*.png` (générés)

**Interfaces:**
- Consumes: `buildAppTheme()`, `darkPalette`, `MagicPalette` (Tasks 1-3), `AppTextStyles` (Task 4).

- [ ] **Step 1: Écrire le test de capture**

Créer `test/captures/grimoire_captures_test.dart`. Reprendre **tel quel** le préambule de chargement de polices système de `test/captures/life_counter_captures_test.dart` (l'en-tête `@Tags(['capture'])`, la fonction `_loadSystemFont` et le bloc `setUpAll`), en y ajoutant l'enregistrement de la famille `'Source Sans 3'` à côté de `'Cinzel'` et `'Roboto'` — sans quoi le texte courant sera rendu en tofu.

Corps du fichier :

```dart
void main() {
  // setUpAll de chargement des polices : voir preambule.

  Widget harness(Widget child) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      );

  testWidgets('20 — echelle des surfaces et des encres', (tester) async {
    await tester.pumpWidget(harness(Builder(builder: (context) {
      final p = MagicPalette.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in {
            'canvas': p.canvas,
            'raised': p.raised,
            'overlay': p.overlay,
            'line': p.line,
          }.entries)
            Container(
              height: 60,
              color: entry.value,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(entry.key, style: AppTextStyles.text(fontSize: 14)),
            ),
        ],
      );
    })));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/20_grimoire_surfaces.png'));
  });

  testWidgets('21 — semantique contre couleurs de mana', (tester) async {
    await tester.pumpWidget(harness(Builder(builder: (context) {
      final p = MagicPalette.of(context);
      return ColoredBox(
        color: p.canvas,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final c in [p.success, p.warning, p.danger, p.info])
                  CircleAvatar(backgroundColor: c, radius: 22),
              ],
            ),
            const SizedBox(height: 24),
            Text('feedback', style: AppTextStyles.text(fontSize: 13)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final c in [
                  AppColors.manaWhite, AppColors.manaBlue, AppColors.manaBlack,
                  AppColors.manaRed, AppColors.manaGreen,
                ])
                  CircleAvatar(backgroundColor: c, radius: 22),
              ],
            ),
            const SizedBox(height: 24),
            Text('mana', style: AppTextStyles.text(fontSize: 13)),
          ],
        ),
      );
    })));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/21_grimoire_semantique_vs_mana.png'));
  });

  testWidgets('22 — echelle typographique complete', (tester) async {
    await tester.pumpWidget(harness(Builder(builder: (context) {
      final p = MagicPalette.of(context);
      return ColoredBox(
        color: p.canvas,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Titre de page', style: AppTextStyles.pageTitle()),
              Text('Titre de section', style: AppTextStyles.sectionTitle()),
              Text('Titre de carte', style: AppTextStyles.cardTitle()),
              const SizedBox(height: 20),
              Text('Sol Ring est un artefact incolore qui produit deux manas '
                  'incolores. Il est banni en Legacy et restreint en Vintage.',
                  style: AppTextStyles.body()),
              const SizedBox(height: 12),
              Text('Sous-titre', style: AppTextStyles.subtitle()),
              Text('Label 12px', style: AppTextStyles.label()),
              Text('Texte bold', style: AppTextStyles.bold()),
            ],
          ),
        ),
      );
    })));

    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/22_grimoire_typographie.png'));
  });
}
```

- [ ] **Step 2: Générer les PNG**

Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/grimoire_captures_test.dart`
Expected: 3 PNG créés dans `test/captures/goldens/`

- [ ] **Step 3: Regarder les trois PNG — étape humaine, bloquante**

Ouvrir `test/captures/goldens/20_grimoire_surfaces.png`, `21_grimoire_semantique_vs_mana.png` et `22_grimoire_typographie.png`.

Trois choses à vérifier à l'œil, qu'aucun test ne dira :
1. Les quatre surfaces se distinguent les unes des autres sans avoir l'air d'une erreur de rendu.
2. Les pastilles de feedback et les pastilles de mana ne se confondent plus, vert contre vert et rouge contre rouge.
3. Le texte courant est confortable et les titres gardent leur caractère.

Ne pas passer à la Task 6 avant cette lecture.

- [ ] **Step 4: Repromouvoir les titres perdus lors de la migration aveugle**

La Task 4 a mis 182 sites en texte courant, dont certains vrais titres. Parcourir les écrans les plus vus — `lib/pages/collections/collection_page.dart`, `lib/pages/decks/deck_list_page.dart`, `lib/pages/cards/card_detail_page.dart` — et repromouvoir vers `sectionTitle()` ou `cardTitle()` les textes qui sont manifestement des titres.

Vérifier après coup : `flutter test` reste vert.

- [ ] **Step 5: Commit**

```bash
git add test/captures/grimoire_captures_test.dart test/captures/goldens lib/pages
git commit -m "test(captures): captures visuelles de la palette Grimoire

Trois captures bloquantes : echelle des surfaces, semantique contre mana,
echelle typographique. Plus la repromotion des titres perdus lors de la
migration mecanique de la Task 4.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Lot C — Le mode Jeu

Objectif : créer `/play` **pendant que le Drawer existe encore**. Le Drawer gagne une entrée « Mode Jeu » et perd quatre entrées qui déménagent sous `/play`. Rien ne devient inaccessible.

---

### Task 6: Les routes du mode Jeu

**Files:**
- Modify: `lib/router/app_routes.dart`
- Create: `lib/router/play_routes.dart`
- Modify: `lib/router/app_router.dart:60-75`
- Modify: `lib/router/tools_routes.dart` (retirer tournoi, oracle, calculateur, glossaire)
- Test: `test/router/play_routes_test.dart`

**Interfaces:**
- Produces: constantes `AppRoutes.play`, `playSetup`, `playCounter`, `playTournament`, `playOracle`, `playGlossary`, `playOdds` — toutes `String`.
- Produces: `playRoutes() → List<RouteBase>`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/router/play_routes_test.dart` :

```dart
// Fichier : test/router/play_routes_test.dart
// Verifie l'arbre de routes du mode Jeu : toutes les sous-routes vivent sous
// /play, et les anciennes adresses du tiroir ont disparu.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_routes.dart';

void main() {
  group('arbre de routes du mode Jeu', () {
    test('toutes les sous-routes vivent sous /play', () {
      for (final route in [
        AppRoutes.playSetup,
        AppRoutes.playCounter,
        AppRoutes.playTournament,
        AppRoutes.playOracle,
        AppRoutes.playGlossary,
        AppRoutes.playOdds,
      ]) {
        expect(route.startsWith('${AppRoutes.play}/'), isTrue,
            reason: '$route devrait etre sous ${AppRoutes.play}');
      }
    });

    test('les chemins sont ceux attendus', () {
      expect(AppRoutes.play, '/play');
      expect(AppRoutes.playSetup, '/play/setup');
      expect(AppRoutes.playCounter, '/play/counter');
      expect(AppRoutes.playTournament, '/play/tournament');
      expect(AppRoutes.playOracle, '/play/oracle');
      expect(AppRoutes.playGlossary, '/play/glossary');
      expect(AppRoutes.playOdds, '/play/odds');
    });

    test('les routes sont uniques', () {
      final routes = [
        AppRoutes.play, AppRoutes.playSetup, AppRoutes.playCounter,
        AppRoutes.playTournament, AppRoutes.playOracle,
        AppRoutes.playGlossary, AppRoutes.playOdds,
      ];
      expect(routes.toSet().length, routes.length);
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/router/play_routes_test.dart`
Expected: FAIL — `The getter 'play' isn't defined for the class 'AppRoutes'`

- [ ] **Step 3: Ajouter les constantes**

Dans `lib/router/app_routes.dart`, ajouter après le bloc des onglets :

```dart
  // Mode Jeu (plein ecran, hors shell). Regroupe tout ce qui s'utilise
  // carte en main : le compteur, et les quatre outils qui etaient dans le
  // Drawer.
  static const String play = '/play';
  static const String playSetup = '/play/setup';
  static const String playCounter = '/play/counter';
  static const String playTournament = '/play/tournament';
  static const String playOracle = '/play/oracle';
  static const String playGlossary = '/play/glossary';
  static const String playOdds = '/play/odds';
```

Supprimer les constantes `tournament`, `oracle` et `calculator` — elles sont remplacées. **Garder** `glossary`, `turnGuide` et `glossaryDetail` : le glossaire reste aussi consultable à froid depuis l'onglet Rechercher (spec §6.1).

- [ ] **Step 4: Écrire playRoutes()**

Créer `lib/router/play_routes.dart` :

```dart
// Fichier : lib/router/play_routes.dart
// Routes du mode Jeu. Plein ecran, hors du shell d'onglets : pendant une
// partie, le telephone est pose sur la table et la barre d'onglets n'a rien
// a y faire.
//
// Ces ecrans venaient du Drawer (tournoi, oracle, glossaire, calculateur) ou
// de l'onglet 0 (compteur). Ils sont deplaces, pas reecrits.

import 'package:go_router/go_router.dart';

import '../pages/glossary/glossary_page.dart';
import '../pages/life_counter/life_counter_page.dart';
import '../pages/oracle/magic_oracle_page.dart';
import '../pages/play/play_setup_page.dart';
import '../pages/tools/hypergeometric_page.dart';
import '../pages/tournaments/tournament_page.dart';
import 'app_routes.dart';
import 'play_shell.dart';

/// Routes du mode Jeu, greffees a la racine du router (hors ShellRoute).
List<RouteBase> playRoutes() {
  return [
    // La mise en place n'a pas de barre d'outils de partie : il n'y a pas
    // encore de partie.
    GoRoute(
      path: AppRoutes.playSetup,
      builder: (context, state) => const PlaySetupPage(),
    ),

    ShellRoute(
      builder: (context, state, child) => PlayShell(
        currentLocation: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: AppRoutes.playCounter,
          builder: (context, state) => const LifeCounterPage(isInShell: true),
        ),
        GoRoute(
          path: AppRoutes.playTournament,
          builder: (context, state) => const TournamentPage(),
        ),
        GoRoute(
          path: AppRoutes.playOracle,
          builder: (context, state) => const MagicOraclePage(),
        ),
        GoRoute(
          path: AppRoutes.playGlossary,
          builder: (context, state) => const GlossaryPage(),
        ),
        GoRoute(
          path: AppRoutes.playOdds,
          builder: (context, state) => const HypergeometricPage(),
        ),
      ],
    ),
  ];
}
```

Dans `lib/router/tools_routes.dart`, supprimer les `GoRoute` de `tournament`, `oracle` et `calculator`, et remplacer la route `glossary` (qui construisait un `Scaffold` inline) par une route propre qui sert la consultation à froid depuis l'onglet Rechercher. Garder `grimoire`, `turnGuide` et `glossaryDetail`.

Dans `lib/router/app_router.dart`, ajouter `...playRoutes(),` dans la liste `routes:` après `...toolsRoutes(),`, et l'import correspondant.

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/router/play_routes_test.dart`
Expected: PASS — 3 tests

Run: `flutter test`
Expected: FAIL attendu sur `test/router/app_router_test.dart`, qui assertait `AppRoutes.tournament`, `oracle` et `calculator`. Mettre ce test à jour pour pointer sur les nouvelles constantes `play*`.

Relancer : `flutter test` → PASS

- [ ] **Step 6: Commit**

```bash
git add lib/router test/router
git commit -m "feat(nav): cree l'arbre de routes du mode Jeu

Tournoi, Oracle, Glossaire et Calculateur quittent le Drawer pour /play/*.
Ecrans deplaces, pas reecrits. Le Drawer existe encore et gagnera une entree
Mode Jeu a la tache suivante.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Le shell du mode Jeu et sa barre d'outils

**Files:**
- Create: `lib/router/play_shell.dart`
- Modify: `lib/router/app_shell_scaffold.dart` (ajout d'une entrée « Mode Jeu » au Drawer, suppression des quatre entrées déménagées)
- Test: `test/router/play_shell_test.dart`

**Interfaces:**
- Consumes: `AppRoutes.play*` (Task 6).
- Produces: `PlayShell({required String currentLocation, required Widget child})` — widget.
- Produces: `playToolIndex(String location) → int` — 0 Vies, 1 Tournoi, 2 Oracle, 3 Règles, 4 Probabilités.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/router/play_shell_test.dart` :

```dart
// Fichier : test/router/play_shell_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/app_routes.dart';
import 'package:magic_companion/router/play_shell.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  group('playToolIndex', () {
    test('associe chaque route a son outil', () {
      expect(playToolIndex(AppRoutes.playCounter), 0);
      expect(playToolIndex(AppRoutes.playTournament), 1);
      expect(playToolIndex(AppRoutes.playOracle), 2);
      expect(playToolIndex(AppRoutes.playGlossary), 3);
      expect(playToolIndex(AppRoutes.playOdds), 4);
    });

    test('retombe sur le compteur pour une route inconnue', () {
      expect(playToolIndex('/play/inconnu'), 0);
    });
  });

  testWidgets('PlayShell affiche les cinq outils et aucune barre d\'onglets app',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: PlayShell(
        currentLocation: AppRoutes.playCounter,
        child: const Text('contenu'),
      ),
    ));

    expect(find.text('contenu'), findsOneWidget);
    for (final label in ['Vies', 'Tournoi', 'Oracle', 'Regles', 'Fin']) {
      expect(find.text(label), findsOneWidget,
          reason: '$label manque dans la barre d\'outils de partie');
    }
    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: 'le mode Jeu ne doit pas porter la barre d\'onglets de l\'app');
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/router/play_shell_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../play_shell.dart'`

- [ ] **Step 3: Écrire PlayShell**

Créer `lib/router/play_shell.dart` :

```dart
// Fichier : lib/router/play_shell.dart
// Shell du mode Jeu : barre d'outils de partie a la place de la barre
// d'onglets de l'app.
//
// La sortie est libre et sans confirmation (spec, decision du 19/09) : la
// partie reste en cours dans GameSessionService, et l'Accueil affiche
// "Reprendre la partie". Confirmer une sortie protegerait la partie d'un
// geste accidentel, mais couterait une friction a chaque fois qu'on va
// verifier un prix en plein milieu d'une game.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_text_styles.dart';
import '../theme/magic_palette.dart';
import 'app_routes.dart';

/// Index de l'outil actif dans la barre de partie.
int playToolIndex(String location) {
  if (location.startsWith(AppRoutes.playTournament)) return 1;
  if (location.startsWith(AppRoutes.playOracle)) return 2;
  if (location.startsWith(AppRoutes.playGlossary)) return 3;
  if (location.startsWith(AppRoutes.playOdds)) return 4;
  return 0;
}

class PlayShell extends StatelessWidget {
  const PlayShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  static const _tools = <({String label, IconData icon, String route})>[
    (label: 'Vies', icon: Icons.favorite, route: AppRoutes.playCounter),
    (label: 'Tournoi', icon: Icons.emoji_events_outlined, route: AppRoutes.playTournament),
    (label: 'Oracle', icon: Icons.all_inclusive, route: AppRoutes.playOracle),
    (label: 'Regles', icon: Icons.menu_book, route: AppRoutes.playGlossary),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final active = playToolIndex(currentLocation);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: p.raised,
            border: Border(top: BorderSide(color: p.line)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < _tools.length; i++)
                Expanded(
                  child: _ToolButton(
                    label: _tools[i].label,
                    icon: _tools[i].icon,
                    selected: i == active,
                    onTap: () => context.go(_tools[i].route),
                  ),
                ),
              Expanded(
                child: _ToolButton(
                  label: 'Fin',
                  icon: Icons.flag_outlined,
                  selected: false,
                  // La sortie ne detruit rien : le snapshot de partie reste.
                  onTap: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);
    final color = selected ? p.accent : p.inkSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.text(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
```

`AppRoutes.home` n'existe pas encore — il est créé à la Task 12. En attendant, utiliser `AppRoutes.lifeCounter` (qui vaut `'/'`) et laisser un `// TODO lot E` serait un placeholder. À la place : **ajouter dès maintenant** dans `app_routes.dart` la constante `static const String home = '/';` à côté de `lifeCounter`, et faire pointer `lifeCounter` dessus. Les deux coexistent jusqu'à la Task 17, qui supprime `lifeCounter`.

- [ ] **Step 4: Mettre le Drawer à jour**

Dans `lib/router/app_shell_scaffold.dart`, dans `_buildDrawer` :

- Supprimer les quatre `_drawerItem` / `ListTile` de Tournoi, Oracle, Calculateur et Glossaire.
- Ajouter en tête de la section JEU, juste après le bloc Drive :

```dart
          ListTile(
            leading: Icon(Icons.sports_esports, color: MagicPalette.of(context).accent),
            title: Text('Mode Jeu', style: AppTextStyles.sectionTitle()),
            subtitle: Text('Compteur, tournoi, oracle, regles',
                style: AppTextStyles.text(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              context.go(AppRoutes.playSetup);
            },
          ),
```

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/router/play_shell_test.dart`
Expected: PASS — 3 tests

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/router test/router/play_shell_test.dart
git commit -m "feat(nav): shell du mode Jeu avec barre d'outils de partie

Vies, Tournoi, Oracle, Regles, Fin. Sortie libre sans confirmation. Le Drawer
perd les quatre entrees deplacees et gagne une entree Mode Jeu.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: L'écran de mise en place et la reprise de partie

**Files:**
- Create: `lib/pages/play/play_setup_page.dart`
- Create: `lib/providers/active_game_provider.dart`
- Test: `test/providers/active_game_provider_test.dart`

**Interfaces:**
- Consumes: `gameSessionServiceProvider` (déjà dans `lib/providers/service_providers.dart:131`), `GameSession` (`lib/models/game_session.dart`).
- Produces: `activeGameProvider` — `FutureProvider<GameSession?>`.
- Produces: `PlaySetupPage()` — widget sans paramètre.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/providers/active_game_provider_test.dart` :

```dart
// Fichier : test/providers/active_game_provider_test.dart
// Le provider qui alimente le bouton "Reprendre la partie" de l'Accueil.
// GameSessionService snapshotte deja la partie dans SharedPreferences : ce
// provider ne fait que l'exposer a l'UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/providers/service_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('retourne null quand aucune partie n\'est en cours', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final session = await container.read(activeGameProvider.future);

    expect(session, isNull);
  });

  test('retourne le snapshot quand une partie est en cours', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final service = container.read(gameSessionServiceProvider);
    // Construire une GameSession minimale conforme au modele du depot.
    // Lire lib/models/game_session.dart pour les champs requis avant
    // d'ecrire cette ligne.
    await service.saveSnapshot(buildTestSession());

    final session = await container.read(activeGameProvider.future);

    expect(session, isNotNull);
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
```

`buildTestSession()` doit être écrit d'après `lib/models/game_session.dart` — lire ce fichier et construire une instance avec ses champs requis réels, en haut du fichier de test.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/providers/active_game_provider_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../active_game_provider.dart'`

- [ ] **Step 3: Écrire le provider**

Créer `lib/providers/active_game_provider.dart` :

```dart
// Fichier : lib/providers/active_game_provider.dart
// Expose le snapshot de partie en cours a l'UI.
//
// Rien a persister ici : GameSessionService ecrit deja le snapshot dans
// SharedPreferences a chaque modification. Ce provider ne fait que le lire,
// pour que l'Accueil sache s'il doit afficher "Reprendre la partie".
//
// A invalider apres saveSnapshot() et apres clearSnapshot() : le provider ne
// surveille pas SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_session.dart';
import 'service_providers.dart';

final activeGameProvider = FutureProvider<GameSession?>((ref) async {
  return ref.watch(gameSessionServiceProvider).loadSnapshot();
});
```

- [ ] **Step 4: Écrire l'écran de mise en place**

Créer `lib/pages/play/play_setup_page.dart`. L'écran réutilise le modal de configuration existant plutôt que de réinventer la sélection de joueurs : lire `lib/widgets/life_counter/game_setup_modal.dart` et en extraire le corps en un widget réutilisable, ou l'appeler tel quel depuis cette page.

Structure attendue, dans l'ordre vertical :
1. Une ligne de titre : bouton fermer (`context.go(AppRoutes.home)`) + « Nouvelle partie » en `AppTextStyles.sectionTitle()`.
2. Des chips de format, alimentés par la table Drift `GameFormats`.
3. Un stepper de points de vie.
4. La liste des joueurs, alimentée par `PlayerConfigs`.
5. Un bouton primaire « Démarrer » → `context.go(AppRoutes.playCounter)`.
6. Si `activeGameProvider` est non nul, un bouton secondaire « Reprendre la partie en cours » → `context.go(AppRoutes.playCounter)`.

Toutes les couleurs viennent de `MagicPalette.of(context)` — aucun `AppColors` de surface, d'encre ou de sémantique (contrainte globale).

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/providers/active_game_provider_test.dart`
Expected: PASS — 3 tests

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/pages/play lib/providers/active_game_provider.dart test/providers/active_game_provider_test.dart
git commit -m "feat(play): ecran de mise en place et provider de partie en cours

GameSessionService snapshottait deja la partie : activeGameProvider ne fait
que l'exposer, pour que l'Accueil puisse proposer la reprise.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Captures du mode Jeu — **CAPTURE BLOQUANTE**

**Files:**
- Create: `test/captures/play_mode_captures_test.dart`
- Create: `test/captures/goldens/30_play_*.png` (générés)

**Interfaces:**
- Consumes: `PlayShell`, `PlaySetupPage` (Tasks 7-8).

- [ ] **Step 1: Écrire le test de capture**

Créer `test/captures/play_mode_captures_test.dart`, avec le même préambule de chargement de polices que la Task 5. Trois captures :

- `30_play_setup.png` — `PlaySetupPage` avec trois joueurs configurés et un format Commander sélectionné.
- `31_play_counter.png` — `PlayShell` autour de `LifeCounterPage(isInShell: true)`, outil « Vies » actif.
- `32_play_barre_outils.png` — la barre d'outils seule, agrandie, les cinq entrées visibles, « Oracle » actif.

- [ ] **Step 2: Générer les PNG**

Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/play_mode_captures_test.dart`
Expected: 3 PNG créés

- [ ] **Step 3: Regarder les trois PNG — étape humaine, bloquante**

Vérifier à l'œil :
1. La barre d'outils de partie est atteignable au pouce, et ses cinq libellés ne se tronquent pas sur une largeur de téléphone.
2. Le compteur reste lisible bras tendus, téléphone posé sur la table.
3. « Fin » ne se confond pas avec les quatre outils — c'est une action destructive de contexte, elle doit se lire comme telle.

- [ ] **Step 4: Commit**

```bash
git add test/captures/play_mode_captures_test.dart test/captures/goldens
git commit -m "test(captures): captures visuelles du mode Jeu

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Lot D — Les Réglages

Objectif : donner une adresse aux sept entrées du Drawer qui ne sont pas parties en mode Jeu, pour que le lot E puisse le supprimer.

---

### Task 10: L'écran Réglages à sections

**Files:**
- Modify: `lib/pages/settings/settings_page.dart`
- Create: `lib/pages/settings/sections/backup_section.dart`
- Create: `lib/pages/settings/sections/about_section.dart`
- Modify: `lib/router/settings_routes.dart`
- Test: `test/pages/settings/settings_page_test.dart`

**Interfaces:**
- Consumes: `googleDriveServiceProvider`, `backupServiceProvider` (`lib/providers/service_providers.dart`), `MagicPalette` (Task 1).
- Produces: `BackupSection()` et `AboutSection()` — widgets sans paramètre.
- Produces: `SettingsPage` rend cinq sections nommées « Sauvegarde », « Joueurs », « Apparence », « Développeur » (seulement en `kDebugMode`), « À propos ».

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/pages/settings/settings_page_test.dart` :

```dart
// Fichier : test/pages/settings/settings_page_test.dart
// L'ecran Reglages absorbe sept entrees du Drawer. Ce test verrouille leur
// presence : c'est ce qui autorise le lot E a supprimer le Drawer sans
// rendre un ecran inatteignable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/pages/settings/settings_page.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  testWidgets('les cinq sections sont presentes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: buildAppTheme(), home: const SettingsPage()),
    ));
    await tester.pumpAndSettle();

    for (final section in ['Sauvegarde', 'Joueurs', 'Apparence', 'A propos']) {
      expect(find.textContaining(section, findRichText: true), findsWidgets,
          reason: 'la section $section manque');
    }
  });

  testWidgets('la section Sauvegarde porte l\'entree Google Drive',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: buildAppTheme(), home: const SettingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Drive', findRichText: true), findsWidgets);
  });

  testWidgets('la section A propos porte les licences Wizards',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: buildAppTheme(), home: const SettingsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Licences', findRichText: true), findsWidgets);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/settings/settings_page_test.dart`
Expected: FAIL — les sections n'existent pas encore

- [ ] **Step 3: Extraire les sections du Drawer**

Créer `lib/pages/settings/sections/backup_section.dart` en y déplaçant, **sans le réécrire**, le `FutureBuilder<bool>` de connexion Drive qui vit aujourd'hui dans `app_shell_scaffold.dart:_buildDrawer` (le bloc « INDICATEUR DE CONNEXION DRIVE », lignes ~230-300) : état connecté/déconnecté, email, bouton de déconnexion avec sa `showDialog` de confirmation, et le `signIn(silent: false)` suivi de la première sauvegarde.

Créer `lib/pages/settings/sections/about_section.dart` en y déplaçant `_showAppAboutDialog` (`app_shell_scaffold.dart`, fin de fichier) : `PackageInfo`, `showAboutDialog`, la légende Wizards of the Coast.

- [ ] **Step 4: Composer SettingsPage**

Dans `lib/pages/settings/settings_page.dart`, rendre les cinq sections dans cet ordre, chacune introduite par un `AppTextStyles.sectionTitle()` :

1. **Sauvegarde** — `BackupSection()`.
2. **Joueurs** — une tuile qui pousse `ProfileManagementPage` (route `AppRoutes.profiles`, conservée).
3. **Apparence** — une seule ligne pour l'instant : « Thème : Grimoire (sombre) », non modifiable, avec la mention que le thème clair arrive. C'est l'emplacement réservé du chantier « Table », pas un placeholder de plan : la ligne est rendue et lisible.
4. **Développeur** — visible seulement sous `if (kDebugMode)`, une tuile vers `AppRoutes.grimoire`.
5. **À propos** — `AboutSection()`.

Couleurs par `MagicPalette.of(context)` uniquement.

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/pages/settings/settings_page_test.dart`
Expected: PASS — 3 tests

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/pages/settings lib/router/settings_routes.dart test/pages/settings
git commit -m "feat(settings): ecran Reglages a sections

Absorbe Drive, Profils, A propos et Developpeur depuis le Drawer, plus un
emplacement Apparence pour le futur theme clair. Blocs deplaces, pas
reecrits.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Sortir les effets Google Drive du scaffold de navigation

`AppShellScaffold` porte aujourd'hui `_checkDriveBackupOnStart()`, `_performAutoBackup()`, `_restoreFromDrive()` et un `WidgetsBindingObserver`. Ce sont des effets de cycle de vie applicatif dans un widget de navigation — et le lot E va réécrire ce widget.

**Files:**
- Create: `lib/services/drive_lifecycle_observer.dart`
- Modify: `lib/router/app_shell_scaffold.dart` (retrait des quatre membres et du mixin)
- Modify: `lib/main.dart` (montage de l'observer au-dessus du routeur)
- Test: `test/services/drive_lifecycle_observer_test.dart`

**Interfaces:**
- Consumes: `googleDriveServiceProvider`, `backupServiceProvider`.
- Produces: `DriveLifecycleObserver({required Widget child})` — widget qui enveloppe l'app.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/services/drive_lifecycle_observer_test.dart` :

```dart
// Fichier : test/services/drive_lifecycle_observer_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/services/drive_lifecycle_observer.dart';

void main() {
  testWidgets('rend son enfant sans le modifier', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: DriveLifecycleObserver(child: Text('app')),
      ),
    ));

    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('se desabonne du binding a la destruction', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: DriveLifecycleObserver(child: Text('app')),
      ),
    ));

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Text('autre')),
    ));

    // Une notification de cycle de vie apres destruction ne doit pas lever.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/services/drive_lifecycle_observer_test.dart`
Expected: FAIL — fichier inexistant

- [ ] **Step 3: Déplacer les quatre membres**

Créer `lib/services/drive_lifecycle_observer.dart` : un `ConsumerStatefulWidget` avec `WidgetsBindingObserver`, qui reprend **tel quel** le corps de `_performAutoBackup()`, `_checkDriveBackupOnStart()` et `_restoreFromDrive()` depuis `app_shell_scaffold.dart`, ainsi que `initState`/`dispose`/`didChangeAppLifecycleState`. Son `build` retourne `widget.child`.

Une correction à apporter au passage, pas un simple copier-coller : `_restoreFromDrive` termine par `context.go(AppRoutes.lifeCounter)`, qui renvoyait sur le compteur. Remplacer par `context.go(AppRoutes.home)` — après une restauration, on veut voir sa collection revenue, pas un compteur de vie.

Dans `lib/router/app_shell_scaffold.dart`, supprimer les quatre méthodes, le mixin `WidgetsBindingObserver`, `initState` et `dispose`.

Dans `lib/main.dart`, envelopper `MaterialApp.router` :

```dart
    return DriveLifecycleObserver(
      child: MaterialApp.router(
        // ... inchange
      ),
    );
```

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/services/drive_lifecycle_observer_test.dart`
Expected: PASS — 2 tests

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_lifecycle_observer.dart lib/router/app_shell_scaffold.dart lib/main.dart test/services
git commit -m "refactor(drive): sort les effets de sauvegarde du scaffold de nav

Sauvegarde auto, verification au demarrage et restauration vivaient dans le
widget de navigation. Elles passent dans un observer dedie, monte au-dessus
du routeur — avant que le lot E ne reecrive ce scaffold.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

# Lot E — La navigation

Objectif : la bascule. À ce stade, chaque écran du Drawer a déjà une nouvelle adresse.

---

### Task 12: L'Accueil

**Files:**
- Create: `lib/pages/home/home_page.dart`
- Modify: `lib/router/app_routes.dart`
- Create: `lib/router/home_routes.dart`
- Test: `test/pages/home/home_page_test.dart`

**Interfaces:**
- Consumes: `activeGameProvider` (Task 8), `DashboardPage` (`lib/pages/dashboard/dashboard_page.dart`, constructeur `const DashboardPage({super.key})`), `MagicPalette`.
- Produces: `HomePage()` — widget sans paramètre.
- Produces: `homeBranchRoute() → GoRoute` (racine `/`, sous-routes `game-history` et `game-history/detail`).

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/pages/home/home_page_test.dart` :

```dart
// Fichier : test/pages/home/home_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/models/game_session.dart';
import 'package:magic_companion/pages/home/home_page.dart';
import 'package:magic_companion/providers/active_game_provider.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  Widget harness(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: buildAppTheme(), home: const HomePage()),
      );

  testWidgets('sans partie en cours, propose de lancer une partie',
      (tester) async {
    await tester.pumpWidget(harness([
      activeGameProvider.overrideWith((ref) async => null),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Lancer une partie'), findsOneWidget);
    expect(find.text('Reprendre la partie'), findsNothing);
  });

  testWidgets('avec une partie en cours, propose de la reprendre',
      (tester) async {
    await tester.pumpWidget(harness([
      activeGameProvider.overrideWith((ref) async => buildTestSession()),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre la partie'), findsOneWidget);
  });

  testWidgets('porte un acces aux reglages', (tester) async {
    await tester.pumpWidget(harness([
      activeGameProvider.overrideWith((ref) async => null),
    ]));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Reglages'), findsOneWidget);
  });
}
```

Réutiliser le `buildTestSession()` écrit à la Task 8 — l'extraire dans `test/support/test_game_session.dart` et l'importer des deux côtés plutôt que de le dupliquer.

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/pages/home/home_page_test.dart`
Expected: FAIL — `home_page.dart` n'existe pas

- [ ] **Step 3: Écrire HomePage**

Créer `lib/pages/home/home_page.dart`. Structure verticale :

1. Une ligne d'en-tête : titre « Accueil » en `AppTextStyles.pageTitle()`, et à droite un `IconButton` `tooltip: 'Reglages'` qui pousse `AppRoutes.settings`.
2. Le corps de `DashboardPage` — la page existe et n'est pas réécrite ; l'inclure comme enfant.
3. Un bouton primaire en bas : « Reprendre la partie » si `activeGameProvider` est non nul (`context.go(AppRoutes.playCounter)`), sinon « Lancer une partie » (`context.go(AppRoutes.playSetup)`).

Les deux libellés doivent être **exactement** ceux du test.

Créer `lib/router/home_routes.dart` :

```dart
// Fichier : lib/router/home_routes.dart
// Branche Accueil du shell : la racine, plus l'historique des parties, qui
// s'y consulte apres avoir joue.

import 'package:go_router/go_router.dart';

import '../models/game_history_model.dart';
import '../pages/home/home_page.dart';
import '../pages/life_counter/game_history_detail_page.dart';
import '../pages/life_counter/game_history_page.dart';
import 'app_routes.dart';
import 'card_detail_route.dart';
import 'page_transitions.dart';

GoRoute homeBranchRoute() {
  return GoRoute(
    path: AppRoutes.home,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const HomePage(),
    ),
    routes: [
      GoRoute(
        path: 'game-history',
        builder: (context, state) => const GameHistoryPage(),
        routes: [
          GoRoute(
            path: 'detail',
            builder: (context, state) =>
                GameHistoryDetailPage(game: state.extra as GameHistoryItem),
          ),
        ],
      ),
      cardDetailRoute(),
    ],
  );
}
```

`cardDetailRoute()` est écrit à la Task 13 — écrire cette Task 13 avant de compiler celle-ci, ou retirer temporairement la ligne et la remettre à la Task 13. Préférer : **exécuter la Task 13 avant la Task 12**, l'ordre entre les deux est libre.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/pages/home/home_page_test.dart`
Expected: PASS — 3 tests

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/pages/home lib/router/home_routes.dart lib/router/app_routes.dart test/pages/home test/support
git commit -m "feat(home): ecran d'accueil avec reprise de partie

Le dashboard remonte du Drawer a la racine et gagne l'entree en mode Jeu,
plus l'acces aux reglages par l'avatar.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: La fiche carte, greffée dans les cinq branches

C'est le cas dur de la refonte : `/cards/detail` est atteignable depuis les cinq branches et sort aujourd'hui du shell, ce qui fait disparaître la barre d'onglets.

**Files:**
- Create: `lib/router/card_detail_route.dart`
- Modify: les appelants qui poussent `AppRoutes.cardDetail` (les trouver avec `grep -rn "AppRoutes.cardDetail" lib`)
- Test: `test/router/card_detail_route_test.dart`

**Interfaces:**
- Produces: `cardDetailRoute() → GoRoute` — chemin **relatif** `'card'`, à greffer dans chaque branche.
- Produces: `pushCardDetail(BuildContext context, {String? cardName, String? imagePath, bool isContinuousScan = false}) → void`.
- Produces: `branchRootOf(String location) → String` — visible pour les tests.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/router/card_detail_route_test.dart` :

```dart
// Fichier : test/router/card_detail_route_test.dart
// La fiche carte est atteignable depuis les cinq branches. Greffee en
// sous-route relative dans chacune, elle garde la barre d'onglets et revient
// dans la branche d'ou elle a ete ouverte.

import 'package:flutter_test/flutter_test.dart';
import 'package:magic_companion/router/card_detail_route.dart';

void main() {
  group('branchRootOf', () {
    test('reconnait chaque branche a sa racine', () {
      expect(branchRootOf('/scanner'), '/scanner');
      expect(branchRootOf('/scanner/history'), '/scanner');
      expect(branchRootOf('/search'), '/search');
      expect(branchRootOf('/decks/detail'), '/decks');
      expect(branchRootOf('/collection/set/stats'), '/collection');
    });

    test('la branche Accueil a une racine vide', () {
      expect(branchRootOf('/'), '');
      expect(branchRootOf('/game-history'), '');
    });

    test('produit un chemin de fiche carte valide pour chaque branche', () {
      for (final location in ['/', '/scanner', '/search', '/decks', '/collection']) {
        final path = '${branchRootOf(location)}/card';
        expect(path.startsWith('/'), isTrue);
        expect(path.contains('//'), isFalse,
            reason: '$location produit un chemin malforme : $path');
      }
    });
  });

  group('cardDetailRoute', () {
    test('le chemin est relatif, pour se greffer dans chaque branche', () {
      expect(cardDetailRoute().path, 'card');
      expect(cardDetailRoute().path.startsWith('/'), isFalse,
          reason: 'un chemin absolu sortirait de la branche');
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/router/card_detail_route_test.dart`
Expected: FAIL — fichier inexistant

- [ ] **Step 3: Écrire le helper**

Créer `lib/router/card_detail_route.dart` :

```dart
// Fichier : lib/router/card_detail_route.dart
// La fiche carte, greffee dans les cinq branches du shell.
//
// Elle s'ouvre depuis un deck, une collection, un scan, une recherche ou
// l'historique. Declaree une seule fois a la racine, elle sortirait du shell
// et ferait disparaitre la barre d'onglets — c'est le comportement d'avant la
// refonte. Declaree en sous-route RELATIVE dans chaque branche, elle herite
// de la branche appelante : la barre reste visible, et le retour ramene dans
// la branche d'ou on venait.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/cards/card_detail_page.dart';

/// Racines des branches du shell, la branche Accueil mise a part : sa racine
/// est '/', et un prefixe vide evite de produire '//card'.
const _branchRoots = <String>['/scanner', '/search', '/decks', '/collection'];

/// Racine de la branche qui contient [location].
String branchRootOf(String location) {
  for (final root in _branchRoots) {
    if (location == root || location.startsWith('$root/')) return root;
  }
  return '';
}

/// La GoRoute de la fiche carte, a greffer dans chaque branche.
GoRoute cardDetailRoute() {
  return GoRoute(
    path: 'card',
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>?;
      return RecognitionResultPage(
        cardName: extra?['cardName'] as String?,
        imagePath: extra?['imagePath'] as String?,
        isContinuousScan: extra?['isContinuousScan'] as bool? ?? false,
      );
    },
  );
}

/// Pousse la fiche carte dans la branche courante.
///
/// A utiliser partout a la place de `context.push(AppRoutes.cardDetail, ...)`,
/// qui sortait du shell.
void pushCardDetail(
  BuildContext context, {
  String? cardName,
  String? imagePath,
  bool isContinuousScan = false,
}) {
  final root = branchRootOf(GoRouterState.of(context).matchedLocation);
  context.push('$root/card', extra: <String, dynamic>{
    'cardName': cardName,
    'imagePath': imagePath,
    'isContinuousScan': isContinuousScan,
  });
}
```

- [ ] **Step 4: Migrer les appelants**

```bash
grep -rn "AppRoutes.cardDetail" lib --include=*.dart
```

Remplacer chaque `context.push(AppRoutes.cardDetail, extra: {...})` par `pushCardDetail(context, cardName: ..., imagePath: ..., isContinuousScan: ...)`, en reprenant les valeurs qui étaient dans la map `extra`. Ajouter l'import `card_detail_route.dart` dans chaque fichier touché.

Supprimer `cardDetailRoutes()` de `lib/router/cards_routes.dart` et son appel dans `app_router.dart`. Garder `cardSearchShellRoute()`.

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/router/card_detail_route_test.dart`
Expected: PASS — 4 tests

Run: `flutter analyze`
Expected: aucune erreur

Run: `flutter test`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lib/router lib/pages lib/widgets test/router/card_detail_route_test.dart
git commit -m "feat(nav): greffe la fiche carte dans chaque branche du shell

Declaree une fois a la racine, elle sortait du shell et faisait disparaitre
la barre d'onglets. Sous-route relative dans les cinq branches : la barre
reste, et le retour ramene dans la branche d'origine.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: StatefulShellRoute à cinq branches

**Files:**
- Modify: `lib/router/app_router.dart:41-80`
- Modify: `lib/router/scanner_routes.dart`, `cards_routes.dart`, `decks_routes.dart`, `collections_routes.dart`
- Delete: `lib/router/dashboard_routes.dart`, `lib/router/life_counter_routes.dart`
- Test: `test/router/shell_branches_test.dart`

**Interfaces:**
- Consumes: `homeBranchRoute()` (Task 12), `cardDetailRoute()` (Task 13), `AppShellScaffold` (Task 15).
- Produces: chaque `*ShellRoute()` existant gagne ses sous-routes de détail et `cardDetailRoute()`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/router/shell_branches_test.dart` :

```dart
// Fichier : test/router/shell_branches_test.dart
// Verrouille la structure a cinq branches. Une regression de navigation est
// invisible aux tests unitaires d'ecran : ces assertions sont le seul filet.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/router/app_router.dart';

void main() {
  StatefulShellRoute findShell(List<RouteBase> routes) {
    for (final route in routes) {
      if (route is StatefulShellRoute) return route;
    }
    fail('aucune StatefulShellRoute a la racine du router');
  }

  group('structure du shell', () {
    test('le shell porte exactement cinq branches', () {
      final shell = findShell(createAppRouter().configuration.routes);
      expect(shell.branches.length, 5);
    });

    test('les racines de branche sont dans l\'ordre attendu', () {
      final shell = findShell(createAppRouter().configuration.routes);
      final roots = shell.branches
          .map((b) => (b.routes.first as GoRoute).path)
          .toList();

      expect(roots, ['/', '/scanner', '/search', '/decks', '/collection']);
    });

    test('chaque branche porte la sous-route de fiche carte', () {
      final shell = findShell(createAppRouter().configuration.routes);

      for (final branch in shell.branches) {
        final root = branch.routes.first as GoRoute;
        final hasCard = root.routes
            .whereType<GoRoute>()
            .any((r) => r.path == 'card');
        expect(hasCard, isTrue,
            reason: 'la branche ${root.path} ne peut pas ouvrir de fiche carte '
                'sans sortir du shell');
      }
    });
  });

  group('plus aucune route de detail a la racine', () {
    test('les racines sont le shell, l\'onboarding et le mode Jeu', () {
      final roots = createAppRouter()
          .configuration
          .routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      for (final leaked in ['/dashboard', '/game-history', '/decks/detail',
          '/collection/set', '/cards/detail']) {
        expect(roots, isNot(contains(leaked)),
            reason: '$leaked doit vivre dans une branche, pas a la racine');
      }
    });
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/router/shell_branches_test.dart`
Expected: FAIL — « aucune StatefulShellRoute a la racine du router »

- [ ] **Step 3: Donner ses sous-routes à chaque branche**

Dans `lib/router/scanner_routes.dart`, remplacer les deux fonctions par une seule :

```dart
GoRoute scannerBranchRoute() {
  return GoRoute(
    path: AppRoutes.scanner,
    pageBuilder: (context, state) => FadeThroughPage(
      key: state.pageKey,
      child: const ScannerPage(),
    ),
    routes: [
      GoRoute(
        path: 'history',
        builder: (context, state) => const ScanHistoryPage(),
      ),
      cardDetailRoute(),
    ],
  );
}
```

Appliquer le même patron aux trois autres :

- `cards_routes.dart` → `searchBranchRoute()` : racine `/search`, sous-routes `[cardDetailRoute()]`.
- `decks_routes.dart` → `decksBranchRoute()` : racine `/decks`, sous-routes `detail` (`state.extra as Deck`) et `cardDetailRoute()`.
- `collections_routes.dart` → `collectionBranchRoute()` : racine `/collection`, sous-routes `stats`, `set`, `set/stats`, `wishlist-detail` (reprendre les `builder` existants tels quels, en passant les chemins d'absolus à relatifs), et `cardDetailRoute()`.

Mettre à jour `AppRoutes` : les constantes de détail deviennent les chemins complets résultants (`/scanner/history`, `/decks/detail`, `/collection/set`, …). Elles ne changent pas de valeur — elles changent seulement de propriétaire.

Supprimer `lib/router/dashboard_routes.dart` (l'Accueil le remplace) et `lib/router/life_counter_routes.dart` (le compteur est passé sous `/play`, l'historique sous la branche Accueil). Garder la route `/table-view` en la déplaçant dans `play_routes.dart`, hors du `ShellRoute` du mode Jeu — elle a besoin du plein écran sans barre d'outils.

- [ ] **Step 4: Basculer le router**

Dans `lib/router/app_router.dart`, remplacer le bloc `ShellRoute(...)` et la liste des routes de détail par :

```dart
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [homeBranchRoute()]),
          StatefulShellBranch(routes: [scannerBranchRoute()]),
          StatefulShellBranch(routes: [searchBranchRoute()]),
          StatefulShellBranch(routes: [decksBranchRoute()]),
          StatefulShellBranch(routes: [collectionBranchRoute()]),
        ],
      ),

      // Hors shell, plein ecran assume.
      ...playRoutes(),
      ...toolsRoutes(),
      ...settingsRoutes(),
```

et changer `initialLocation: AppRoutes.lifeCounter` en `initialLocation: AppRoutes.home`.

- [ ] **Step 5: Lancer les tests**

Run: `flutter test test/router/shell_branches_test.dart`
Expected: PASS — 4 tests

Run: `flutter test`
Expected: PASS après mise à jour de `test/router/app_router_test.dart` (ses listes de constantes citent des routes supprimées).

- [ ] **Step 6: Commit**

```bash
git add lib/router test/router
git commit -m "feat(nav): StatefulShellRoute a cinq branches

Chaque onglet garde sa propre pile : revenir dessus le retrouve la ou il a
ete laisse. Les routes de detail descendent de la racine dans leur branche.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: Le scaffold sans Drawer

**Files:**
- Modify: `lib/router/app_shell_scaffold.dart` (réécriture — le fichier passe de 482 lignes à ~90)
- Modify: `lib/router/app_routes.dart` (suppression de `locationToTabIndex`)
- Test: `test/router/app_shell_scaffold_test.dart`

**Interfaces:**
- Consumes: `StatefulNavigationShell` (go_router), `MagicPalette`.
- Produces: `AppShellScaffold({required StatefulNavigationShell navigationShell})` — la signature change : plus de `currentLocation` ni de `child`.
- Removes: `locationToTabIndex(String)`, `_buildDrawer`, `_drawerItem`, `_showAppAboutDialog`.

- [ ] **Step 1: Écrire le test qui échoue**

Créer `test/router/app_shell_scaffold_test.dart` :

```dart
// Fichier : test/router/app_shell_scaffold_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  testWidgets('le shell porte cinq onglets et aucun Drawer', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: createAppRouter(),
      ),
    ));
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar));
    expect(bar.items.length, 5);
    expect(bar.items.map((i) => i.label).toList(),
        ['Accueil', 'Scanner', 'Rechercher', 'Decks', 'Collection']);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawer, isNull,
        reason: 'le Drawer doit avoir disparu : ses entrees ont toutes une '
            'nouvelle adresse');
  });

  testWidgets('l\'app s\'ouvre sur l\'Accueil, pas sur le compteur',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: createAppRouter(),
      ),
    ));
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar));
    expect(bar.currentIndex, 0);
    expect(find.text('Accueil'), findsWidgets);
  });
}
```

- [ ] **Step 2: Lancer le test pour vérifier qu'il échoue**

Run: `flutter test test/router/app_shell_scaffold_test.dart`
Expected: FAIL — la signature d'`AppShellScaffold` ne correspond plus, et le Drawer est encore là

- [ ] **Step 3: Réécrire le scaffold**

Remplacer tout `lib/router/app_shell_scaffold.dart` par :

```dart
// Fichier : lib/router/app_shell_scaffold.dart
// Shell d'onglets. Ne fait plus que ca.
//
// Avant la refonte, ce fichier portait aussi un Drawer de onze entrees, la
// sauvegarde automatique Google Drive, la restauration au demarrage et une
// boite "A propos" — 482 lignes. Le Drawer a disparu (ses entrees sont dans
// /play et /settings) et les effets Drive sont dans DriveLifecycleObserver.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/magic_palette.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  /// Pilote les cinq branches : `currentIndex` dit laquelle est active,
  /// `goBranch` bascule en conservant la pile de chacune.
  final StatefulNavigationShell navigationShell;

  static const _items = <BottomNavigationBarItem>[
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
    BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'Scanner'),
    BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Rechercher'),
    BottomNavigationBarItem(icon: Icon(Icons.style_outlined), label: 'Decks'),
    BottomNavigationBarItem(
        icon: Icon(Icons.inventory_2_outlined), label: 'Collection'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = MagicPalette.of(context);

    return Stack(
      children: [
        const _BackgroundTexture(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: navigationShell),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            // initialLocation: true renvoie a la racine de la branche quand on
            // retape l'onglet deja actif — le geste attendu pour "remonter en
            // haut". Sur un autre onglet, la pile est conservee.
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            type: BottomNavigationBarType.fixed,
            backgroundColor: p.raised,
            selectedItemColor: p.accent,
            unselectedItemColor: p.inkSecondary,
            items: _items,
          ),
        ),
      ],
    );
  }
}

class _BackgroundTexture extends StatelessWidget {
  const _BackgroundTexture();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background_texture_black.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
```

Supprimer `locationToTabIndex` de `lib/router/app_routes.dart` : `navigationShell.currentIndex` le remplace.

- [ ] **Step 4: Lancer les tests**

Run: `flutter test test/router/app_shell_scaffold_test.dart`
Expected: PASS — 2 tests

Run: `flutter test`
Expected: PASS après suppression, dans `test/router/app_router_test.dart`, des assertions sur `locationToTabIndex`.

- [ ] **Step 5: Commit**

```bash
git add lib/router test/router
git commit -m "feat(nav): supprime le Drawer

482 lignes qui melaient navigation, sauvegarde Drive et boite A propos
tombent a 90. Cinq onglets, l'Accueil en tab 0, et retaper l'onglet actif
remonte a la racine de sa branche.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 16: Les tests de préservation de pile

Le vrai gain de `StatefulShellRoute` est invisible aux tests écrits jusqu'ici : chaque onglet garde son historique. C'est aussi ce qui casse le plus silencieusement.

**Files:**
- Create: `test/router/branch_stack_test.dart`

**Interfaces:**
- Consumes: `createAppRouter()` (Task 14), `AppShellScaffold` (Task 15).

- [ ] **Step 1: Écrire les tests**

Créer `test/router/branch_stack_test.dart` :

```dart
// Fichier : test/router/branch_stack_test.dart
// Le gain de StatefulShellRoute : chaque onglet garde sa pile. Invisible aux
// tests d'ecran, et c'est ce qui casse le plus silencieusement.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:magic_companion/router/app_router.dart';
import 'package:magic_companion/theme/app_theme.dart';

void main() {
  late GoRouter router;

  Future<void> pumpApp(WidgetTester tester) async {
    router = createAppRouter();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        theme: buildAppTheme(),
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
  }

  String currentLocation() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('une branche retrouve sa position apres un aller-retour',
      (tester) async {
    await pumpApp(tester);

    router.go('/collection');
    await tester.pumpAndSettle();
    router.push('/collection/stats');
    await tester.pumpAndSettle();
    expect(currentLocation(), '/collection/stats');

    // On passe sur Decks, puis on revient sur Collection.
    router.go('/decks');
    await tester.pumpAndSettle();
    router.go('/collection');
    await tester.pumpAndSettle();

    expect(currentLocation(), '/collection/stats',
        reason: 'la branche Collection doit retrouver sa pile');
  });

  testWidgets('la barre d\'onglets reste visible sur un ecran de detail',
      (tester) async {
    await pumpApp(tester);

    router.go('/decks');
    await tester.pumpAndSettle();
    router.push('/decks/card');
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget,
        reason: 'un detail pousse dans une branche garde la barre');
  });

  testWidgets('le mode Jeu, lui, n\'a pas la barre d\'onglets',
      (tester) async {
    await pumpApp(tester);

    router.go('/play/setup');
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: 'le mode Jeu est plein ecran, c\'est voulu');
  });

  testWidgets('retaper l\'onglet actif remonte a la racine de sa branche',
      (tester) async {
    await pumpApp(tester);

    router.go('/collection');
    await tester.pumpAndSettle();
    router.push('/collection/stats');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();

    expect(currentLocation(), '/collection');
  });
}
```

- [ ] **Step 2: Lancer les tests**

Run: `flutter test test/router/branch_stack_test.dart`
Expected: PASS — 4 tests.

Si le premier échoue, la cause est presque toujours que `goBranch` est appelé avec `initialLocation: true` inconditionnellement dans `AppShellScaffold` : relire la Task 15, Step 3.

- [ ] **Step 3: Commit**

```bash
git add test/router/branch_stack_test.dart
git commit -m "test(nav): verrouille la preservation des piles de branche

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

### Task 17: Nettoyage et captures finales — **CAPTURE BLOQUANTE**

**Files:**
- Modify: `lib/router/app_routes.dart`
- Modify: `test/router/app_router_test.dart`
- Create: `test/captures/navigation_captures_test.dart`
- Create: `test/captures/goldens/40_nav_*.png` (générés)

**Interfaces:**
- Removes: `AppRoutes.lifeCounter`, `AppRoutes.dashboard`, `AppRoutes.tournament`, `AppRoutes.oracle`, `AppRoutes.calculator`, `AppRoutes.cardDetail`.

- [ ] **Step 1: Supprimer les constantes mortes**

Dans `lib/router/app_routes.dart`, supprimer `lifeCounter` (remplacée par `home`), `dashboard` (l'Accueil), `cardDetail` (remplacée par `cardDetailRoute()`), et les trois constantes d'outils déjà retirées à la Task 6 si elles traînent encore.

Vérifier qu'aucune référence ne subsiste :

```bash
grep -rn "AppRoutes.lifeCounter\|AppRoutes.dashboard\|AppRoutes.cardDetail" lib test
```

Expected: aucune sortie.

- [ ] **Step 2: Remettre app_router_test.dart à jour**

Dans `test/router/app_router_test.dart`, remplacer les trois listes de constantes par la liste réelle post-refonte, et remplacer le test « tab routes match expected paths » par :

```dart
    test('les routes d\'onglet sont celles du shell a cinq branches', () {
      expect(AppRoutes.home, '/');
      expect(AppRoutes.scanner, '/scanner');
      expect(AppRoutes.search, '/search');
      expect(AppRoutes.decks, '/decks');
      expect(AppRoutes.collection, '/collection');
    });
```

Supprimer le test « drawer routes have meaningful paths » — il n'y a plus de Drawer.

- [ ] **Step 3: Écrire les captures de navigation**

Créer `test/captures/navigation_captures_test.dart`, même préambule de polices que la Task 5. Quatre captures, montées sur `createAppRouter()` :

- `40_nav_accueil.png` — l'Accueil, sans partie en cours.
- `41_nav_accueil_reprise.png` — l'Accueil avec `activeGameProvider` surchargé sur une partie en cours, bouton « Reprendre la partie » visible.
- `42_nav_barre_onglets.png` — la barre d'onglets seule, agrandie, les cinq libellés visibles sans troncature.
- `43_nav_reglages.png` — l'écran Réglages, ses cinq sections déroulées.

- [ ] **Step 4: Générer les PNG**

Run: `flutter test --tags capture --run-skipped --update-goldens test/captures/navigation_captures_test.dart`
Expected: 4 PNG créés

- [ ] **Step 5: Regarder les quatre PNG — étape humaine, bloquante**

Vérifier :
1. Les cinq libellés d'onglet tiennent sans troncature sur une largeur de téléphone — c'est la contrepartie du choix de garder le Scanner.
2. Le bouton de reprise de partie se distingue du bouton de lancement.
3. Les Réglages ne ressemblent pas à l'ancien tiroir remis à plat : les sections doivent se lire comme une hiérarchie.

- [ ] **Step 6: Lancer toute la suite**

Run: `flutter analyze`
Expected: aucune erreur

Run: `flutter test`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/router/app_routes.dart test/router test/captures
git commit -m "chore(nav): supprime les constantes mortes et capture la nav finale

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Critères de sortie du plan

Repris de la spec §10, vérifiables une fois la Task 17 close :

1. Le `Drawer` n'existe plus dans le code ; les onze entrées sont accessibles à leurs nouvelles destinations — `/play/*` pour quatre d'entre elles, `/settings` pour cinq, l'onglet Accueil pour deux.
2. Chaque onglet conserve sa pile (Task 16, test 1).
3. Une fiche carte ouverte depuis n'importe laquelle des cinq branches affiche la barre d'onglets et revient dans sa branche d'origine (Tasks 13 et 16).
4. Aucun `context.push` ne franchit une frontière de branche.
5. Lancer une partie, quitter le mode Jeu sans confirmation, revenir sur l'Accueil : « Reprendre la partie » est affiché et fonctionne (Tasks 8 et 12).
6. Terminer une partie écrit dans l'historique et fait disparaître le bouton de reprise.
7. `darkPalette.success` et `AppColors.manaGreen` sont à plus de 60 unités RGB l'un de l'autre (Task 2).
8. Aucun texte de corps n'est rendu en Cinzel : `AppTextStyles.cinzel(` a disparu de `lib/` (Task 4).
9. `flutter test` est vert.
10. Les Tasks 5, 9 et 17 ont produit leurs PNG et un humain les a regardés.

## Ce qui reste après ce plan

- **La texture de fond (spec §7.3).** La spec demande de garder `background_texture_black.png` sur l'Accueil et le mode Jeu, et de la retirer des écrans denses (Collection, Decks, fiche carte). Ce plan ne le fait pas : la texture vit dans le `Stack` du shell (Task 15), donc derrière les cinq onglets indistinctement. La retirer par écran suppose de la remonter dans chaque page — c'est un changement par écran, qui appartient au lot composants. Inscrit ici pour que le manque soit visible plutôt que silencieux.
- **Lot composants** — `AppCard`, `AppButton`, `AppScaffold`, `AppEmptyState`, puis migration écran par écran en commençant par Collection, Decks et fiche carte. Son découpage dépend de ce que montrent les captures des Tasks 5 et 17. C'est là que la texture par écran se règle.
- **Thème clair « Table »** — c'est là que les 2 068 références `AppColors` migrent vers `MagicPalette`, dont 566 qui perdront leur `const`. Le mode Jeu reste sombre dans les deux thèmes et échappe à la migration.
