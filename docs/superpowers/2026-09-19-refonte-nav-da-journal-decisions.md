# SDD ledger — plan: docs/superpowers/plans/2026-09-19-refonte-nav-da.md

Spec: docs/superpowers/specs/2026-09-19-refonte-nav-da-design.md (autorité liante)
Worktree: .claude/worktrees/refonte-nav-da, branche worktree-refonte-nav-da
Base de branche: e66567a
Baseline attendue: 1332 tests, 3 skippés, exit 0

Contrainte utilisateur, qui écarte la skill sur un point : **un seul
implémenteur enchaîne les tâches** au lieu d'un agent neuf par tâche.
Le reste de la machinerie SDD est conservé (registre, paquet de revue,
task reviewer, boucle de correction).

Implémenteur en cours : lancé sur Tasks 1→4, s'arrête à la Task 5
(CAPTURE BLOQUANTE).

---

## Scan de conflits pré-vol

### Paires de tâches partageant un fichier ou une interface

| Tâches | Produit → consommé | Constat |
|---|---|---|
| 1 → 2, 3 | `MagicPalette`, `darkPalette`, `buildAppTheme()` | OK |
| 1 → 2 | Test « lot A ne change aucune valeur » vs. changement des jetons sémantiques | Géré : la Task 2 Step 1 remplace explicitement ce test |
| **2 (interne)** | Son test de remplacement assert `p.warning == AppColors.warning`, mais son Step 3 pose `warning: 0xFFD99B36` | **CONFLIT — la tâche se contredit elle-même** |
| **2 → 3** | Le test de remplacement assert `p.onAccent == AppColors.textOnPrimary` ; la Task 3 change `onAccent` en `0xFF14120B` | **CONFLIT — la Task 3 casse un test que la Task 2 vient d'écrire, sans le dire** |
| 3 → 15 | `darkPalette.raised` en fond de barre d'onglets, posé deux fois (thème + widget) | Redondant, non bloquant |
| 4 → 5, 7, 10 | `AppTextStyles.text()` | OK |
| 4 → 17 | Suppression de `cinzel()` vs. usages résiduels | OK, le test de la Task 4 balaie `lib/` |
| 6 → 7 | Constantes `AppRoutes.play*` | OK |
| 6 → 14 | `/` sert encore `LifeCounterPage` pendant que `/play/counter` la sert aussi | Transitoire, une seule instance montée à la fois. Surveiller le mode immersif + wakelock posés dans `initState` |
| 7 → 12 | `AppRoutes.home`, créé en avance par la Task 7 | OK, explicité dans le plan |
| **10 → 11** | `BackupSection` (Task 10) appelle `_performAutoBackup()`, méthode **privée** du scaffold que la Task 11 n'a pas encore extraite | **CONFLIT — inaccessible depuis un autre fichier** |
| 12 → 13 | `cardDetailRoute()` dans `homeBranchRoute()` | Géré : le plan dit d'exécuter 13 avant 12 |
| 13 → 14 | `cardDetailRoute()` greffé dans les 5 branches | OK |
| **14 → 15** | La Task 14 appelle `AppShellScaffold(navigationShell:)`, signature créée par la Task 15 ; le test de la Task 15 appelle `createAppRouter()`, réécrit par la Task 14 | **CONFLIT — dépendance mutuelle, aucune des deux ne compile seule** |
| 15 → 16 | `find.text('Collection')` peut matcher le libellé d'onglet ET un titre de page | Risque de finder ambigu, non bloquant |
| 15 → 17 | Suppression de `locationToTabIndex` | OK |

### Cohérence interne de chaque tâche

| Tâche | Ses tests vs. son code | Ses fichiers créés vs. touchés | Constat |
|---|---|---|---|
| 1 | cohérent | cohérent | OK |
| 2 | **incohérent** (voir ci-dessus) | cohérent | CONFLIT |
| 3 | cohérent | cohérent | OK (mais casse un test de la Task 2) |
| 4 | cohérent | 59 fichiers par `sed`, `flutter analyze` prévu | OK |
| 5 | captures, pas d'assertion | cohérent | OK par nature |
| 6 | cohérent | cohérent | OK |
| 7 | cohérent | cohérent | OK |
| 8 | `buildTestSession()` défini localement, réutilisé en Task 12 | extrait en `test/support/` à la Task 12 | OK, explicité |
| 9 | captures | cohérent | OK par nature |
| 10 | cohérent | **dépend d'une privée d'un autre fichier** | CONFLIT |
| 11 | cohérent | cohérent | OK |
| 12 | cohérent | dépend de la Task 13 | OK, explicité |
| 13 | cohérent | cohérent | OK |
| 14 | cohérent | dépend de la Task 15 | CONFLIT |
| 15 | son test dépend de la Task 14 | cohérent | CONFLIT |
| 16 | cohérent | cohérent | OK |
| 17 | cohérent | cohérent | OK |

### Rulings pré-vol

**Ruling 1 (Task 2)** — Le test de remplacement de la Task 2 n'assert plus
que les jetons que la Task 2 ne touche pas : `canvas`, `raised`, `overlay`,
`line`, `inkPrimary`, `inkSecondary`, `inkMuted`, `accent`, `onAccent`.
`warning` en sort. — *Pourquoi :* un test qui assert l'inverse de ce que sa
propre tâche vient de poser est un défaut de plan, pas une exigence de spec ;
la spec §7.1 impose la séparation sémantique/mana, pas la conservation de
`warning`. — *Coût si faux :* nul, le test vérifie moins que prévu à cette
étape ; la Task 3 le remplace par le test de contraste qui est le vrai garde.

**Ruling 2 (Task 3)** — À la Task 3, le test « valeurs inchangées » est
supprimé, pas amendé. — *Pourquoi :* après la Task 3 chaque jeton a bougé,
y compris `onAccent` ; le test n'a plus de contenu. Sa fonction — prouver que
la plomberie n'a rien déplacé — appartenait au lot A et est remplie. Le
`contrast_test.dart` de la Task 3 devient le garde-fou. — *Coût si faux :*
on perd un test devenu vide ; le contraste reste verrouillé.

**Ruling 3 (Task 10)** — `BackupSection` n'appelle pas `_performAutoBackup()`
du scaffold. Elle appelle directement `backupService.generateBackupJson()`
puis `driveService.uploadBackup(...)`, c'est-à-dire le corps de cette méthode.
— *Pourquoi :* une méthode privée d'un `State` n'est pas accessible depuis un
autre fichier ; le plan décrit un appel impossible. Ça rend aussi la Task 11
indépendante au lieu de séquentielle. — *Coût si faux :* deux endroits
répètent trois lignes d'appel de service. Acceptable, et la Task 11 peut les
factoriser dans l'observer si le reviewer le demande.

**Ruling 4 (Tasks 14 et 15)** — Les Tasks 14 et 15 sont exécutées comme une
seule unité : la réécriture du scaffold et la bascule du routeur sont écrites
ensemble, commitées ensemble, et les deux fichiers de test passent après. Le
plan les présente comme deux commits ; ce n'est pas réalisable. — *Pourquoi :*
la Task 14 appelle une signature que la Task 15 crée, et le test de la Task 15
appelle un routeur que la Task 14 réécrit. Aucune des deux ne compile seule.
— *Coût si faux :* un commit plus gros que prévu, donc un diff de revue plus
large. Aucun risque fonctionnel.

**Ruling 5 (Task 6 → 14)** — L'état transitoire où `LifeCounterPage` est
servie à la fois par `/` et par `/play/counter` est accepté. — *Pourquoi :*
une seule instance est montée à la fois ; l'alternative serait de fusionner
les lots C et E, ce qui rendrait le Drawer inutilisable au milieu.
— *Coût si faux :* si le mode immersif ou le wakelock posés dans `initState`
fuient d'une instance à l'autre, ça se verra au lot E. À surveiller.

---

## Progression

- Setup: worktree créé, fast-forward sur main local (e66567a), `flutter pub get` OK.
- Implémenteur dispatché sur Tasks 1→4, arrêt prévu Task 5.

Task 1: complete (commit b257ebe, appelant vérifié dans lib/main.dart:144)
  flutter test : 1335 tests, 3 skippés, exit 0 (1332 baseline + 3 nouveaux)

Task 2: bloquée par l'implémenteur sur contradiction de plan. Ruling 6 ci-dessous.

**Ruling 6 (Tasks 2 et 3, et spec §7.1)** — Les quatre valeurs sémantiques
changent ; le seuil de 60 unités RGB ne bouge pas.

    success  #4FA96B -> #6FD98F   (distance à manaGreen : 27,8 -> 83,4)
    danger   #D9554F -> #FF7A6E   (distance à manaRed   : 38,7 -> 84,4)
    info     #4C8DF5 -> #7FB2FF   (distance à manaBlue  : 11,7 -> 75,3)
    warning  #D99B36 -> #FFA94D   (distance à l'accent  : 23,0 -> 66,4)

*Pourquoi :* j'avais écrit les valeurs ET le seuil sans jamais calculer la
distance entre les deux. Les trois premières échouaient au critère de sortie
n°7 du plan. Baisser le seuil pour accepter les valeurs, ce serait ajuster le
test au code — l'inverse de ce que ce test existe pour faire. Les nouvelles
valeurs gardent la même teinte, éclaircie et désaturée : c'est aussi ce qu'un
thème sombre demande, les sémantiques y sont plus claires que les couleurs
d'identité. Contraste WCAG sur canvas `#0E0E11` vérifié : 11,0 / 7,6 / 8,9.

*Quatrième collision, trouvée en vérifiant :* `warning #D99B36` était à 23
unités de l'accent de marque `#C9A227`. Un avertissement qui ressemble à la
couleur de l'app. Corrigé dans le même mouvement, bien que non couvert par le
test (le plan ne teste que success/danger/info).

*Coût si faux :* quatre couleurs de feedback plus claires que prévu. Visible
aux captures de la Task 5, annulable en changeant quatre constantes dans
`lib/theme/app_theme.dart`. Spec et plan mis à jour pour rester l'autorité.

Task 2: minor (deferred) — `warning` reste à 48,7 unités de `manaMulti`
  (`#D4AF37`). Orange et or multicolore sont des teintes voisines par nature.
  Contextes d'usage disjoints (puce d'avertissement vs pastille de couleur de
  carte). À trancher par la revue finale.

Task 5: le plan dit d'enregistrer la police `'Source Sans 3'` dans le préambule
  de capture. **Faux** : `google_fonts` pose un nom composé par poids
  (`SourceSans3_regular`, `SourceSans3_600`…) et ne met le nom nu que dans
  `fontFamilyFallback`, qui ne prend pas le relais dans ce binding. Relevé par
  l'implémenteur en lisant `test/captures/life_counter_captures_test.dart:140-190`.
  À corriger quand la Task 5 démarrera.

Tasks 1-4: complete (commits b257ebe..b7e7b03)
Tasks 1-4: fix round 1/5 (6 findings adressés, 0 ouvert; commits 82df57f..8f4d88f)
  C-1 corrigé et le test regarde désormais le ThemeData construit, pas les
  jetons seuls — c'est le trou par lequel C-1 était passé.
  I-1: 24 sites repromus, pas 13 (l'heuristique en a trouvé 11 de plus).
  I-4: les 14 goldens sortaient en TOFU à la première régénération. Les 3
  fichiers n'enregistraient que Cinzel. Attrapé en les regardant.

Vérifications du contrôleur sur le round 1 :
  - 142 sites `primaryShade*`, 75 `Colors.amber*`, 14 `Colors.yellow` : comptes confirmés.
  - `AppColors.primary` vaut bien `0xFFC9A227` après la Task 4b.
  - Golden `05` : chevauchement des labels flottants **PRÉ-EXISTANT**, établi en
    extrayant `8f4d88f~1:test/captures/goldens/05_*.png` — identique au pixel près.
  - Tofu : clos. Les 3 fichiers de capture ont chacun ≥ 1 golden vérifié net
    (agent : 01, 10, 05, 22_moxfield ; contrôleur : 13, 05). L'enregistrement
    des polices étant global par fichier, un golden net vaut pour son fichier.

**Ruling 9 (rampe d'accent)** — La rampe `primaryShade700/800/900` est adoptée,
dérivée de l'accent : `#B8922A` (6,59:1), `#A37E22` (5,11:1), `#8A6A1B`
(3,82:1). *Pourquoi :* 142 sites lisent encore `Colors.yellow.shade*`, donc
l'app porte deux accents concurrents — l'or patiné et le jaune Material vif.
N'importe quelle rampe cohérente vaut mieux que deux accents. `shade900` sous
AA est acceptable : ses usages sont des fonds et des bordures, pas du texte.
*Coût si faux :* une rampe à retoucher, trois constantes.

**Ruling 10 (FAB)** — `foregroundColor` du FAB passe de `textPrimary` (blanc) à
`onAccent` (encre sombre). *Pourquoi :* blanc sur `primaryShade800` donne
**1,97:1** aujourd'hui, et 3,77 même avec la nouvelle rampe — inutilisable dans
les deux cas. Défaut pré-existant, révélé par le calcul de la rampe. Hors
périmètre du plan au sens strict, mais c'est une ligne et le FAB est illisible.
*Coût si faux :* une ligne à revenir.

**Ruling 11 (89 couleurs Material en dur)** — Les 75 `Colors.amber*` et 14
`Colors.yellow` écrits en dur sont **différés au lot composants**, pas corrigés
ici. *Pourquoi :* `AppColors.amber` est documenté « foil, prix » — l'ambre y a
un rôle sémantique réel, distinct de l'accent. Les convertir en bloc
écraserait cette distinction ; les trier demande la passe écran par écran qui
est précisément l'objet du lot composants. *Coût si faux :* quelques éléments
restent en jaune Material jusqu'à ce lot, dont le « 0 cartes » de la liste de
decks. Visible, et assumé.

Tasks 1-4: fix round 2/5 (Rulings 9+10 appliqués; commit 8ca6ff5)
Tasks 6,7,8: complete (commits 9eea57a..bd94088) — 1384 tests, 5 skippés, exit 0

**Ruling 12 (fuite wakelock, Ruling 5 invalidé)** — Le bouton « Fin » pointe sur
`/play/setup` jusqu'à la Task 12, pas sur `home`. *Pourquoi :* l'agent a sondé
l'ordre réel et c'est `initState` de l'arrivée PUIS `dispose` du départ. Comme
`home` vaut `/` qui sert encore `LifeCounterPage`, « Fin » enchaîne
compteur → compteur et on ressort **wakelock désactivé, barres système
revenues** : l'écran peut s'éteindre en pleine partie. Mon Ruling 5 acceptait
cet état transitoire en pariant qu'une seule instance serait montée à la fois ;
le pari était faux, les deux se chevauchent. *Coût si faux :* « Fin » ramène à
la mise en place au lieu de l'accueil pendant six tâches. Bénin.

**Ruling 13 (« Fin » ne se lit pas comme une fin)** — Séparateur vertical avant
« Fin », et son icône et son libellé en `danger`, jamais en `accent`.
*Pourquoi :* ma propre grille de lecture de la Task 9 exigeait qu'elle « se
lise comme une action destructive de contexte » ; la capture montre qu'elle est
indiscernable des cinq outils. *Coût si faux :* du rouge dans une barre sinon
neutre. La confirmation de fin de partie n'est PAS ajoutée ici — le vrai
comportement de « Fin » (écrire l'historique + `clearSnapshot`) n'est pas encore
construit, elle ira avec.

**Ruling 14 (écran de mise en place creux)** — `PlaySetupPage` ouvre la feuille
de configuration au montage, et son état vide porte un bouton « Configurer la
partie » explicite. *Pourquoi :* la capture montre un écran qui promet trois
choix et n'en offre aucun. L'écart n°4 de l'agent est un bon diagnostic
(`GameSetupModal` finit par `Navigator.pop`), mais sa conséquence est un écran
mort dans un parcours que cette refonte existe pour raccourcir. *Coût si faux :*
une feuille qui s'ouvre toute seule peut surprendre ; annulable.

**Ruling 15 (accents dans l'UI)** — « Regles » devient « Règles ». *Pourquoi :*
la convention « sans accents » du dépôt vise les **commentaires de code**, pas
le texte affiché — le reste de l'UI dit « Détail Carte ». C'est mon plan qui a
confondu les deux. « Probas » reste sans accent, c'est une abréviation.

Trous de couverture visuelle, assumés et consignés :
  - Le compteur de vie n'est monté dans aucune capture (il tire toute la chaîne
    de services de partie). Le critère « lisible bras tendus » n'est pas couvert.
  - L'effet de la rampe sur les tuiles de deck n'est couvert par aucune capture :
    seule la variante COMMANDER lit `primaryShade900`, et un deck commandant
    déclenche une image réseau qui bloque le binding de test.
  - Réserve de l'agent sur `PlaySetupPage` : une partie lancée par snapshot
    n'exécute pas le reset des zones que `_startNewGame` fait. À vérifier quand
    le compteur sera testé en vrai (lot E).

Différés: `lib/chat_screen.dart:128` pose du texte sur `primaryShade900`
  (4,16:1 même avec une encre noire). Écran Grimoire Code, `kDebugMode`
  seulement. Non corrigé.

Tasks 10,11: complete (commits 1b64379..fd4ede5) — 1398 tests
Tasks 12-17: complete (commits c791d8b..f64175d) — 1423 tests, 25 commits depuis e66567a
Revue lots C+D: 5 Importants, 0 Critique → Rulings 17, 18, 19 + S-3, S-4, I-1, I-2, I-5 corrigés (ec2b79d)

**Ruling 16 (spec §5, barre d'outils)** — La spec annonçait `Vies · Dés ·
Oracle · Règles · Fin`. **Le lanceur de dés n'existe pas dans l'app** et n'est
pas planifié : je l'avais inventé en écrivant la spec. Tournoi et Probas
manquaient alors que ce sont deux des six routes du mode Jeu. Spec corrigée sur
l'implémentation, qui avait raison. *Coût si faux :* nul.

**Ruling 17 (mes Rulings 12 et 14 se composent mal)** — La feuille de
configuration ne s'ouvre au montage que si `activeGameProvider` est `null`.
*Pourquoi :* composés, le 12 (« Fin » → `/play/setup`) et le 14 (feuille au
montage) faisaient surgir « configurer une nouvelle partie » juste après avoir
quitté une partie — l'inverse du geste. Aucun des deux n'avait examiné l'autre.
*Coût si faux :* nul, le cas creux que le 14 visait reste couvert.

**Ruling 18 (trou de plan : accès hors partie)** — L'Accueil gagne une rangée
`Oracle · Règles · Probas` vers `/play/<outil>` sans exiger de partie.
*Pourquoi :* la spec §6.1 promettait l'Oracle depuis une fiche carte et les
probas depuis une fiche deck ; ces entrées n'ont jamais été construites, ni
dans le plan ni ailleurs, alors que les entrées du tiroir étaient supprimées.
Poser une question de règles imposait de créer une partie. *Coût si faux :* une
rangée à retirer. Les entrées contextuelles restent différées.

**Ruling 19 (Ruling 10 appliqué à moitié)** — Le correctif du FAB doit atteindre
le `TextStyle` de l'enfant, et le garde doit voir les couleurs posées par
l'enfant. *Pourquoi :* une couleur explicite sur le `TextStyle` gagne sur le
`foregroundColor` ; le FAB avait une icône noire et un libellé blanc toujours à
3,77:1. Le garde ne regardait que `foregroundColor`. 5 boutons corrigés au
final, pas 2. *Coût si faux :* nul.

**Ruling 20 (réserve écart n°5)** — `resetPlayerZones` extrait et appelé par les
deux chemins de démarrage. *Pourquoi :* une partie lancée depuis
`PlaySetupPage` passait par snapshot et sautait le reset que `_startNewGame`
fait ; une zone laissée en mode ajustement rouvrait en ajustement. Vérifié sur
pièce, pas déduit. *Coût si faux :* aucun, c'était un bug.

**Ruling 21 (deux blancs concurrents)** — `AppColors.textPrimary` → `#F2EFE6`,
`textSecondary` → `#A9A396`. **`textMuted` reste `white54`** : `inkMuted` tombe
à 3,55:1, ce serait la faute C-1 reproduite 224 fois. *Pourquoi :* même logique
que le Ruling 7 — aligner les `const` pour que la DA atterrisse sans convertir
les sites. *Coût si faux :* deux constantes.

**Ruling 22 (texte coupé sur l'Accueil)** — Corrigé. La cause n'était pas une
contrainte de hauteur : le contenu était coupé net au bord du viewport d'un
`SingleChildScrollView`, sans rien perdre.

**Ruling 23 puis 24 (navigation en double sur l'Accueil)** — Le 23 gardait
Scanner et « Nouveau deck ». **Les deux moitiés étaient fausses** : Scanner EST
un onglet (écrit en ayant la barre sous les yeux), et « Nouveau deck » fait
`go(AppRoutes.decks)` donc n'ouvre que l'onglet Decks — un libellé qui promet
une action qu'il n'exécute pas. Le Ruling 24 retire la rangée entièrement.
*Coût si faux :* un widget pré-existant retiré d'un écran, réversible.

Différés au lot composants, assumés :
  - Entrées contextuelles Oracle (fiche carte) et Probas (fiche deck).
  - Création de deck depuis l'Accueil (`_showCreateDeckDialog` est privé à
    `DeckListPage` et n'a aucune adresse).
  - `primaryGold` / `primaryBright` / `primaryDark` restent des ors Material :
    une quatrième famille d'or, 24 sites cosmétiques qui ne jurent pas.
  - Les 75 `Colors.amber*` et 14 `Colors.yellow` en dur (Ruling 11).
  - Texture par écran (spec §7.3).
  - `GlossaryPage` sans Scaffold propre ; `/glossary/detail` et guide de tour en
    routes racine ; `chat_screen.dart:128` ; deux `unused_import` ; `_tag` inutilisé.

Environnement: `assets/json/oracle-cards.json` (166 Mo) est gitignoré, donc
  absent d'un worktree neuf, et sans lui aucun test ne tourne (échec de build
  du bundle d'assets). L'implémenteur a posé un lien dur vers le dépôt
  principal. À refaire à chaque nouveau worktree.
