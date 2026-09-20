# Refonte navigation & direction artistique — Magic Companion

*Spec de design — 19 septembre 2026 — base v1.10 (sprint 15)*

Maquettes de référence : https://claude.ai/artifact/GBunCKcgtiYdQnNpWzvv7y

---

## 1. Problème

L'app ne tranche pas entre deux usages : outil de jeu (carte en main) et
bibliothèque (gestion de collection). Faute d'arbitrage, le sprint 15 a mis
l'outil de jeu en page racine et poussé tout le reste dans un tiroir devenu
débarras. Quatre symptômes mesurés dans le dépôt :

| # | Symptôme | Mesure |
|---|----------|--------|
| 1 | Deux modèles de navigation cohabitent : les onglets font `context.go`, les 11 entrées du tiroir font `context.push`. Ouvrir « Tournoi » sort du shell et fait disparaître la barre d'onglets. | `app_shell_scaffold.dart:_drawerItem()` |
| 2 | Le tiroir contient 11 destinations hétérogènes sans hiérarchie, rangées par ordre d'arrivée dans les sprints. | 11 entrées, 3 séparateurs, 0 regroupement |
| 3 | `/` est le compteur de vie, alors que ~70 % des pages servent hors partie. Le dashboard est dans le tiroir. | `AppRoutes.lifeCounter = '/'` |
| 4 | La palette n'a pas d'échelle : ~60 % des jetons pointent vers des couleurs Material brutes. Pas de `ThemeData` global au-delà de 4 lignes, pas de `ThemeExtension`, pas de `ThemeMode`. | `app_colors.dart`, `main.dart:144` |

Mesures complémentaires, qui cadrent le coût :

- **2 068** références `AppColors.*` réparties sur **116** fichiers (sur 147).
- **566** de ces références sont sur une ligne `const` — un widget `const` ne
  peut pas lire `Theme.of(context)`.
- **182** appels à `AppTextStyles.cinzel()` servent de corps de texte. Cinzel
  sous 14 px est le premier facteur d'illisibilité de l'app.
- Un seul `ThemeData.dark()`. Aucune occurrence de `Brightness`, `ThemeMode`
  ou `ThemeExtension`.

## 2. Décisions

Prises avec le porteur du projet le 19/09/2026, à partir des maquettes :

| Question | Décision |
|----------|----------|
| Le scanner garde-t-il un onglet ? | **Oui.** Cinq onglets, l'ordre actuel est conservé ; seul le `tab 0` change. |
| Sortie du mode Jeu | **Sortie libre, sans confirmation.** La partie reste en cours, l'Accueil affiche « Reprendre la partie ». |
| Direction artistique | **Grimoire** (noir d'encre + or patiné, continuité MTG). La direction « Mana » (accent contextuel WUBRG) est écartée pour l'instant. |
| Light mode « Table » | **Chantier séparé, après.** Grimoire devient le thème sombre officiel ; le light arrive dans un lot ultérieur, écran par écran. |

## 3. Non-objectifs

Explicitement hors périmètre de cette spec :

- Migrer les 2 068 références `AppColors.*` vers la `ThemeExtension`. Seuls
  les écrans neufs la consomment.
- Livrer le thème clair « Table ». Le socle le rend possible ; la spec ne le
  livre pas.
- Adopter la direction artistique « Mana ». Le socle de jetons reste
  compatible avec un passage ultérieur.
- Migrer `GameSessionService` de SharedPreferences vers Drift. L'incohérence
  est connue et sans impact ici.
- Toute refonte fonctionnelle des écrans existants. On déplace et on
  réhabille, on ne réécrit pas les fonctionnalités.

---

## 4. Navigation

### 4.1 Structure

`ShellRoute` devient **`StatefulShellRoute.indexedStack`** avec cinq branches.
Chaque branche conserve sa propre pile : revenir sur un onglet le retrouve là
où il a été laissé.

| Index | Onglet | Racine | Routes de la branche |
|-------|--------|--------|----------------------|
| 0 | **Accueil** *(remplace Compteur)* | `/` | `/game-history`, `/game-history/detail` |
| 1 | Scanner | `/scanner` | `/scanner/history` |
| 2 | Rechercher | `/search` | — |
| 3 | Decks | `/decks` | `/decks/detail` |
| 4 | Collection | `/collection` | `/collection/set`, `/collection/set/stats`, `/collection/stats`, `/wishlists/detail` |

L'ordre des onglets 1 à 4 est inchangé pour ne pas désorienter les
utilisateurs existants.

### 4.2 La fiche carte

`/cards/detail` est atteignable depuis les cinq branches (depuis un deck,
depuis la collection, depuis un scan, depuis une recherche, depuis
l'historique). Aujourd'hui elle sort du shell.

**Décision :** elle est déclarée en **sous-route relative dans chaque
branche**, produite par un helper unique :

```dart
/// Retourne la GoRoute de la fiche carte, à greffer dans chaque branche.
/// Le path est relatif : la fiche hérite de la branche appelante et
/// conserve la barre d'onglets.
GoRoute cardDetailRoute() => GoRoute(
      path: 'card/:id',
      builder: (context, state) => CardDetailPage(id: state.pathParameters['id']!),
    );
```

Conséquence : la fiche carte garde la barre d'onglets et revient dans la
branche d'où elle a été ouverte.

### 4.3 Règle unique de navigation

- `go` uniquement pour **changer de branche** (les onglets).
- `push` uniquement pour **descendre dans la branche courante**.
- Le double modèle `go`/`push` du tiroir disparaît avec le tiroir.

### 4.4 Routes hors shell

Plein écran assumé, sans barre d'onglets :

- `/onboarding`
- `/play` et tous ses enfants (§5)
- `/table-view`

### 4.5 Suppression du Drawer

`_buildDrawer()` et `_drawerItem()` sont supprimés de
`app_shell_scaffold.dart`. Le scaffold ne garde que la barre d'onglets et le
fond.

`_checkDriveBackupOnStart()` et `_performAutoBackup()` sortent du scaffold :
ce sont des effets de cycle de vie applicatif, pas de la navigation. Ils
partent dans un observer dédié, monté au-dessus du routeur.

---

## 5. Mode Jeu

Route racine `/play`, plein écran, sans barre d'onglets.

```
/play/setup        mise en place : format, points de vie, joueurs
/play/counter      le compteur de vie (ex tab 0)
/play/tournament   ex-tiroir « Gestion Tournoi »
/play/oracle       ex-tiroir « Oracle (IA) »
/play/glossary     ex-tiroir « Glossaire »
/play/odds         ex-tiroir « Calculateur Proba »
```

**Barre d'outils interne** au mode Jeu, en bas : `Vies · Tournoi · Oracle ·
Règles · Probas · Fin`. Elle remplace la barre d'onglets de l'app pendant la
partie.

*Amendement du 20/09/2026, après implémentation.* La spec annonçait d'abord
`Vies · Dés · Oracle · Règles · Fin`. Deux erreurs : **aucun lanceur de dés
n'existe dans l'app ni n'est planifié** — il avait été inventé en écrivant la
spec ; et Tournoi et Probas manquaient alors que `/play/tournament` et
`/play/odds` sont deux des six routes du mode Jeu. Sans leur bouton, ce sont
des routes sans entrée.

### 5.1 Cycle de vie d'une partie

`GameSessionService` existe déjà et snapshotte la partie dans
SharedPreferences (`saveSnapshot`, `loadSnapshot`, `hasActiveGame`,
`clearSnapshot`). Rien à construire côté persistance.

- **Entrer** — depuis l'Accueil, bouton principal « Lancer une partie » →
  `/play/setup`.
- **Sortir** — sans confirmation, à tout moment. Le snapshot est conservé.
- **Reprendre** — l'Accueil lit le snapshot via un provider Riverpod et
  affiche « Reprendre la partie » quand il est non nul.
- **Terminer** — « Fin » écrit dans `GameHistoryItems` puis appelle
  `clearSnapshot()`. Le bouton de reprise disparaît de l'Accueil.

---

## 6. Réglages

`/settings` devient un écran à sections, atteint par **l'avatar en haut de
l'Accueil** (convention connue : le compte est sous l'avatar).

Sections : Sauvegarde & Drive · Joueurs · Apparence · Développeur · À propos.

### 6.1 Redistribution des onze entrées du tiroir

| Entrée du tiroir | Destination | Justification |
|------------------|-------------|---------------|
| Dashboard | **Devient l'onglet Accueil** | Page d'ouverture naturelle hors partie. |
| Historique Parties | Accueil › Parties | On y va après avoir joué. |
| Gestion Tournoi | Mode Jeu | Ne s'utilise que sur place. |
| Oracle (IA) | Mode Jeu + fiche carte | Une question de règles se pose en partie ou devant une carte. |
| Calculateur Proba | Mode Jeu + fiche deck | Test de deck, ou calcul de topdeck en jeu. |
| Glossaire | Mode Jeu + Rechercher | Mot-clé croisé en jeu, ou consulté à froid. |
| Gestion des Profils | Réglages › Joueurs | Configuration, pas usage quotidien. |
| Paramètres & Sauvegarde | Avatar → Réglages | Convention connue. |
| Bloc Google Drive | Réglages › Sauvegarde | Un `FutureBuilder` de connexion n'a rien à faire dans un menu. |
| À propos & Licences | Réglages › À propos | Obligation légale Wizards, pas une destination. |
| Grimoire Code *(debug)* | Réglages › Développeur | Déjà sous `kDebugMode`. |

---

## 7. Direction artistique — Grimoire

### 7.1 Couleur

Échelle de surfaces explicite, en remplacement des valeurs ad hoc :

| Jeton | Valeur | Usage |
|-------|--------|-------|
| `surface/canvas` | `#0E0E11` | fond de page |
| `surface/raised` | `#191820` | cartes, tuiles |
| `surface/overlay` | `#2A2733` | modales, menus |
| `surface/line` | `#3A3646` | séparateurs |
| `ink/primary` | `#F2EFE6` | texte principal |
| `ink/secondary` | `#A9A396` | texte secondaire |
| `ink/muted` | `#75705F` | non textuel uniquement |
| `ink/accent` | `#C9A227` | or patiné — remplace `Colors.yellow` |

**Correction fonctionnelle, pas cosmétique :** aujourd'hui
`AppColors.success` et `AppColors.manaGreen` valent tous deux du vert
Material, et `AppColors.error` / `manaRed` du rouge Material. Un badge
« possédée » et une carte verte se confondent donc à l'œil. Les familles
sémantiques et les familles de domaine sont séparées :

- **Sémantique** — `feedback/success` `#6FD98F`, `feedback/warning` `#FFA94D`,
  `feedback/danger` `#FF7A6E`, `feedback/info` `#7FB2FF`.
- **Domaine** — `mana/W…G` et l'incolore, `rarity/*` (4 niveaux), `power/*`
  (casual → cEDH), `badge/*` (foil, possédée, wishlist).

Aucune valeur des deux familles ne doit être partagée.

### 7.2 Typographie

- **Cinzel** est réservé aux titres : `pageTitle`, `sectionTitle`,
  `cardTitle`, titre d'AppBar.
- Le corps de texte passe sur **Source Sans 3** — face humaniste dessinée
  pour l'interface en petite taille, dont les proportions classiques
  s'accordent avec une romaine comme Cinzel. Elle est disponible via
  `google_fonts`, déjà au projet. Le choix est isolé dans
  `AppTextStyles.body()` et reste donc substituable en un point.
- Les **182** sites `AppTextStyles.cinzel()` employés comme corps de texte
  sont convertis vers une nouvelle échappatoire `AppTextStyles.text()`, et
  `AppTextStyles.cinzel()` est **supprimée**.

  *Amendement du 20/09/2026, après implémentation.* La spec disait d'abord
  « convertir vers `body()` » et « garder `cinzel()` ». Les deux étaient
  faux : `body()` n'accepte ni `fontWeight` ni `fontStyle`, or une
  quarantaine des 182 sites en passent un — la conversion les aurait perdus
  en silence. Et garder `cinzel()` laissait l'échappatoire ouverte, alors
  que c'est précisément son existence qui a fait dériver toute l'app vers
  Cinzel. `text()` reprend la signature complète de `cinzel()` sur Source
  Sans 3, et sa suppression est verrouillée par un test qui balaie `lib/`.

### 7.3 Texture

`background_texture_black.png` est conservée sur l'Accueil et le mode Jeu,
et retirée des écrans denses (Collection, Decks, fiche carte) où elle bruite
la lecture.

### 7.4 API de thème

Une `ThemeExtension<MagicPalette>` est ajoutée **à côté** des `AppColors`
const existants, et branchée sur le `ThemeData` de `main.dart`.

- Les écrans **neufs** (Accueil, Réglages, mode Jeu) la consomment dès le
  départ, via `MagicPalette.of(context)`.
- Les **2 068** sites existants restent sur `AppColors.*` et migrent
  ultérieurement, au moment du chantier light « Table ».

Cette coexistence est délibérée : elle évite d'empiler une migration de
116 fichiers sur une refonte de navigation.

---

## 8. Lots de livraison

L'ordre compte : les jetons d'abord, sinon la refonte de nav se fait sur une
DA qu'on change ensuite, et on repasse deux fois sur les mêmes écrans.

| Lot | Contenu | Validation |
|-----|---------|------------|
| **1a** | `ThemeExtension<MagicPalette>` introduite **à valeurs identiques** à l'existant. Aucun pixel ne bouge. | 1332 tests verts |
| **1b** | Valeurs Grimoire appliquées + séparation sémantique/domaine + typo (182 sites de corps de texte). | **Captures d'écran** |
| **2** | `StatefulShellRoute.indexedStack`, 5 branches, `cardDetailRoute()`, suppression du Drawer, sortie des effets Drive du scaffold. | Tests de navigation neufs |
| **3** | `/settings` à sections, absorbe les 11 entrées du tiroir. | Tests + captures |
| **4** | Mode Jeu `/play/*`, barre d'outils de partie, « Reprendre la partie » sur l'Accueil. | **Captures d'écran** |
| **5** | `AppCard`, `AppButton`, `AppScaffold`, `AppEmptyState`, puis migration écran par écran en commençant par les plus vus. | **Captures d'écran** |
| — | Light « Table » | Chantier séparé, hors de cette spec |

**Règle de validation :** un lot qui déplace des pixels ne se clôt pas sur
des tests verts. Les lots 1b, 4 et 5 se valident sur captures d'écran.

---

## 9. Risques

| Risque | Parade |
|--------|--------|
| Le lot 2 touche tout `lib/router/` d'un coup ; une régression de navigation est invisible aux tests unitaires. | Écrire les tests de navigation **avant** la bascule : un test par branche vérifiant que la pile est préservée et que la barre reste visible sur un détail. |
| `cardDetailRoute()` greffée dans 5 branches peut produire des chemins ambigus. | Chemin relatif (`card/:id`), jamais absolu. Un test par branche vérifiant que le retour ramène dans la bonne branche. |
| Le lot 1b change les pixels de 116 fichiers sans que les tests le voient. | Le lot 1a sert de filet : il prouve que la plomberie du thème n'a rien cassé avant qu'on touche aux valeurs. |
| La coexistence `AppColors` const / `MagicPalette` peut dériver en deux systèmes concurrents. | Règle écrite : tout écran **neuf** consomme `MagicPalette`, aucun nouveau site `AppColors.*` n'est ajouté. |
| Le mode Jeu récupère quatre écrans du tiroir dont l'Oracle, qui dépend d'un service IA. | Les écrans sont **déplacés**, pas réécrits. Aucun changement de leur logique interne dans le lot 4. |

## 10. Critères d'acceptation

1. Le `Drawer` n'existe plus dans le code ; les 11 entrées sont accessibles à
   leurs nouvelles destinations.
2. Chaque onglet conserve sa pile : quitter Collection en plein détail
   d'édition et y revenir depuis un autre onglet retrouve ce détail.
3. Une fiche carte ouverte depuis n'importe laquelle des 5 branches affiche la
   barre d'onglets et revient dans sa branche d'origine.
4. Aucun `context.push` ne franchit une frontière de branche.
5. Lancer une partie, quitter le mode Jeu sans confirmation, revenir sur
   l'Accueil : « Reprendre la partie » est affiché et fonctionne.
6. Terminer une partie écrit dans l'historique et fait disparaître le bouton
   de reprise.
7. `AppColors.success` et `AppColors.manaGreen` ont des valeurs distinctes ;
   idem `error` / `manaRed`.
8. Aucun texte de corps n'est rendu en Cinzel sous 14 px.
9. La suite de tests passe au vert à chaque fin de lot.
10. Les lots 1b, 4 et 5 sont accompagnés de captures d'écran avant/après.
