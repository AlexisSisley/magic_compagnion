# SDD ledger — plan: docs/superpowers/plans/2026-10-19-chantier-d-page-deck.md

Spec: docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md §3, §6, §7 (lue)
Worktree: .claude/worktrees/chantier-cd, branche worktree-chantier-cd, à la suite du chantier C (af22381).
Mandat utilisateur (2026-10-25) : C puis D en subagents, jusqu'au push sur main.
Baseline au départ de D : 1633 passés / 7 ignorés / 0 échec ; analyze 164.

## Scan de pré-vol (plan D écrit AVANT l'exécution de C : confronté au code actuel)

| A | B | Partagé | Produit | Consommé | Constat |
|---|---|---|---|---|---|
| C (fait) | T1 | upsertDeckCard | `proxyQuantity`, `mergeVariants` (fusion au déplacement) | catégorie/verrou à propager | **Défaut 1** : le plan D ignore `mergeVariants` → Ruling 1 |
| C (fait) | T1 | test de migration v4→v5 | motif DDL figé | v5→v6 | Cohérent : copier le motif. |
| T1 | T3 | setCardCategory, champs | API | setCategory/resetCategory | Cohérent. |
| T2 | T3 | classifyCard, oracleText | fonction pure | catégorisation à l'ouverture | Cohérent. |
| T3 | T4 | viewPrefs, setGrouping/setLayout/setCategory/resetCategory, displayCategory | API | DeckCardListTab | Cohérent. |
| T4 | T5 | averageManaValue | fonction | bandeau | Cohérent. |
| C (fait) | T5 | pastilles de mana de la tuile (deck_list_card.dart) | rendu | bandeau « comme la tuile » | **Défaut 2** : deux copies du rendu de pastilles → Ruling 2 |
| C (fait) | T5 | garde `LOCAL:` + errorWidget sur l'art (deck_list_card) | règle | bandeau, art du commandant | **Défaut 3** : le plan D ne la prévoit pas → Ruling 3 |
| T4 | T6 | LongPressDraggable `{card, sourceBoard}` | données glissées | DeckBoardSelector | Cohérent. |
| T3 | T5/T6 | DeckDetailState | powerLevel, viewPrefs | page | Cohérent, séquentiel. |

| Tâche | Cohérence interne | Constat |
|---|---|---|
| T1 | tests migration + chemins d'écriture | Cohérent ; voir Ruling 1 |
| T2 | tableau de cas fait foi | Cohérent |
| T3 | catégorisation à l'ouverture, persistée en lot | Cohérent |
| T4 | goldens 10-13 à régénérer et regarder | Cohérent |
| T5 | hauteur 180 fixe dans les trois cas | Cohérent ; Rulings 2, 3 |
| T6 | test de dépôt par vrais gestes | Cohérent |
| T7 | page montable ? décidé en T6 | Cohérent |

Ruling 1: fusion au déplacement (mergeVariants) d'une carte vers un board où elle existe : la ligne CIBLE garde sa catégorie et son verrou (c'est elle qui existe déjà, peut-être corrigée à la main) ; à l'insertion, la carte déplacée apporte les siens ; changeCardVersion vers une impression absente recopie ceux de l'ancienne, vers une impression présente garde ceux de la cible. Coût si faux : une correction manuelle de la carte déplacée perdue lors d'une fusion — rare.
Ruling 2: le rendu des pastilles de couleur est extrait de deck_list_card.dart dans un petit widget partagé (ex. `lib/widgets/decks/mana_pips.dart`) utilisé par la tuile ET le bandeau, au lieu d'une seconde copie. Coût si faux : un fichier de plus.
Ruling 3: le bandeau applique la même règle d'art que la tuile : pas de `ScryfallImage` pour un identifiant `LOCAL:`, `errorWidget` = fond neutre. Coût si faux : nul.

---

## Progression

### Tâche 1
- BASE = af22381. Implémenteur dispatché (sonnet), Ruling 1 porté.
- Rendu : DONE_WITH_CONCERNS, d72ec4c, 1658/7/0, 10 mutations. Ajout AppDatabase.setDeckCardCategory (effacement). Assertion user_version du test v5 passée à 6. setCardCategory touche updatedAt → OK pour une correction manuelle ; À PORTER EN T3 : la catégorisation automatique à l'ouverture ne doit PAS toucher updatedAt.
- Relecture (sonnet) : approuvée. Tous les chemins d'écriture de lib/ préservent catégorie/verrou ; test v6 détecte un addColumn manquant.
- ⚠️ résolu par moi, PORTÉ EN T3 : deck_detail_controller (recalcul des couleurs ~l.197) appelle updateDeck(deck, touch:false) avec un Deck capturé avant les appels réseau ; updateDeck vide et réinsère les cartes → écraserait les catégories posées par la catégorisation automatique de la même ouverture. T3 doit rendre la catégorisation et ce recalcul non conflictuels (écriture des couleurs seule, ou relecture du deck, ou ordre garanti) et le tester.
- Tâche 1: minor (deferred): _migrateDeckCards sans test de catégorie ; import de sauvegarde sur ligne existante avec category null ne l'efface pas.
Tâche 1: complete (commits af22381..d72ec4c, review clean)

### Tâche 2
- BASE = d72ec4c. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 8b9f9cf, 1683/7/0, 4 mutations. Écarts (le tableau prime) : terrain-créature → creatures dès la règle 1 ; règle 7 accepte « has ». Texte oracle recopié de mémoire.
- Relecture (sonnet) : approuvée, mais erreurs systématiques venues des MOTIFS DU PLAN (plan-mandated) : dégâts chiffrés ratés (Lightning Bolt → other) ; « each creature » attrape « each creature you control » (faux wipes) ; « exile target » classe le clignotement en removal (Ephemerate) ; shroud absent (Lightning Greaves → other) ; verbe donneur cherché dans tout le texte (« gain 2 life » + indestructible → Protection) ; MDFC « Sort // Terrain » → lands ; Exploration → other.
- ⚠️ porté en T3 : oracleText vaut '' pour tout ScryfallCard non construit par fromJson → vérifier que fullCardData vient de fromJson.

Ruling 4: les motifs du plan sont corrigés (la fidélité au rôle de jeu prime sur la lettre du plan, qui n'est qu'un premier jet) : (a) dégâts : expression « deals (\d+|x) damage to (any target|target creature|target creature or planeswalker|target permanent|target player or planeswalker) » → removal ; (b) « each creature » ne compte pas s'il est suivi de « you control » ; (c) « exile target » n'est pas du removal si le texte ramène la carte (« return it » / « return that card » / « return them » … « to the battlefield ») ; (d) « shroud » rejoint les mots-clés de protection ; (e) le verbe donneur (gain/gains/have/has) doit être dans la MÊME phrase que le mot-clé ; (f) terrain = type de la face AVANT (avant « // ») ; (g) « play an additional land » → ramp. Chaque correction a son cas réel au tableau. Coût si faux : une catégorie différente de l'attente d'un joueur — corrigeable à la main (verrou).
- Fix round 1/5 dispatché (resume).
- Fix round 1 rendu : DONE_WITH_CONCERNS, 570f47e, 1694/7/0, 7 mutations. Écart (f) : motifs « add { » ignorés quand le verso est un terrain ; motif « draw that many cards » ajouté.
- Re-relecture (sonnet) : (a)-(g) ADRESSÉS.
- Tâche 2: fix round 1/5 (7 addressed, 0 open; commits 8b9f9cf..570f47e)
- Tâche 2: minor (deferred): spellWithLandBack touche aussi les créatures MDFC productrices de mana (Tangled Florahedron → creatures) — recommandé : restreindre aux faces avant non créature ; Swords to Plowshares sans cas de table post-blink ; _blink ne reconnaît pas « return those cards » ; « additional land » large ; oracle recopié de mémoire.
Tâche 2: complete (commits d72ec4c..570f47e, re-review clean)

### Tâche 3
- BASE = 570f47e. Implémenteur dispatché (opus) : écriture concurrente à l'ouverture.
- Rendu : DONE, de4e936, 1705/7/0, 19 mutations. R-a : lot transactionnel sans touch. R-b : DeckService.updateDeckColors remplace updateDeck(touch:false) (qui n'était même pas attendu) ; le lot ne touche que category null & non verrouillé (condition dans la requête).
- Relecture (sonnet) : approuvée. updateDeckColors ne perd aucun effet utile ; garde SQL ferme la course automatique/manuel.
- ⚠️ porté en T4 : setGrouping/setLayout/setCategory/resetCategory n'ont encore aucun appelant hors tests → T4 doit les câbler depuis la page.
- Tâche 3: minor (deferred): mutation en mémoire même si la garde SQL a ignoré la ligne (affichage transitoire) ; clés deck_view orphelines à la restauration (effacement à déplacer dans deleteDeckAndCards) ; repli prefs non atomique ; commentaire de updateDeck(touch:false) périmé.
Tâche 3: complete (commits 570f47e..de4e936, review clean)

### Tâche 4
- BASE = de4e936. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 9d56863, 1731/7/0, 12 mutations. Câblage des 4 instances prouvé par test de page RÉELLE (montable avec base en mémoire : test/pages/decks/deck_detail_page_wiring_test.dart) — à réutiliser en T6/T7. Goldens 10-13 inchangés (scryfallCard null). Écart maquette : quantité dans la barre −/+ du bas (le coin haut-droit porte déjà le coût de mana).
- Relecture (sonnet) : approuvée. Payload du glisser intact ; mode Type inchangé ; averageManaValue source unique.
- Tâche 4: minor (deferred): quantité en barre −/+ du bas au lieu de la pastille haut-droite de la maquette (disposition) ; boutons −/+ de 20 px sous 48 (préexistant) ; pas de cadenas en mode liste ; indentation ; pied de vignette à regarder à 390 px.
Tâche 4: complete (commits de4e936..9d56863, review clean)

### Tâche 5
- BASE = 9d56863. Implémenteur dispatché (sonnet), Rulings 2 et 3 portés.
- Rendu : DONE_WITH_CONCERNS (visuel), 666ffe7, 1746/7/0, analyze 154, 8 mutations. mana_pips.dart partagé (Ruling 2) ; repli d'art ColoredBox(raised) sans icône (Ruling 3) ; powerLevel avec sentinelle ; buildAppTheme ajouté au test de câblage.
- Relecture (sonnet) : Needs fixes. 2 importants : pas d'ombre de texte sur le bandeau (art clair, haut du nom à ~55 % de noir) ; titre d'AppBar vide → la route n'a plus de nom pour TalkBack.
- Fix round 1/5 dispatché (resume) : ombre + Semantics(header, namesRoute) ; mineurs promus : power level recalculé après quantité/déplacement (pilule périmée sinon) ; séparateur « · » solidaire de son élément.
- Fix round 1 rendu : DONE, 7ca3280, 1750/7/0, 5 mutations.
- Re-relecture (haiku) : 4/4 ADRESSÉS.
- Tâche 5: fix round 1/5 (4 addressed, 0 open; commits 666ffe7..7ca3280)
- Tâche 5: minor (deferred): test de recalcul du power level ne couvre que updateTags (quantité/déplacement vérifiés par lecture) ; bandeau jamais vu à l'écran → captures T7.
Tâche 5: complete (commits 9d56863..7ca3280, re-review clean)

### Tâche 6
- BASE = 7ca3280. Implémenteur dispatché (opus) : point de régression le plus probable.
- Rendu : DONE_WITH_CONCERNS, c979937, 1768/7/0, 17 mutations. Hors brief : bug PRÉEXISTANT corrigé — le glisser ne démarrait jamais (l'appui long de la tuile ouvrait le menu) ; le LongPressDraggable porte les deux gestes, menu au relâchement sans mouvement. TabBar déplacée sous le bandeau ; DeckLegalityTab(embedded). Concern : à 360 px la puce Wishlist hors champ (défilement horizontal) alors que c'est une cible de dépôt.
- Relecture (opus) : Needs fixes. 1 important : plus aucune action sémantique d'appui long sur la vignette de grille → menu de carte inaccessible au lecteur d'écran dans la vue par défaut. Parité de l'ancien onglet confirmée pour la Wishlist hors champ (l'ancienne TabBar défilait aussi).

Ruling 5: les puces de board passent à la ligne (Wrap) quand elles ne tiennent pas, au lieu de défiler : une cible de dépôt hors champ est inatteignable pendant un glisser. Au-delà de la parité avec l'ancien onglet, la spec veut que le dépôt marche ; même raisonnement que le Ruling 6 du chantier C. Coût si faux : une rangée de puces sur deux lignes à 360 px.
- Fix round 1/5 dispatché (resume) : Semantics longPress sur la vignette + Ruling 5 + déplacement net au lieu de cumul pour le seuil du menu.
- Tâche 6: minor (deferred): hauteur utile sur téléphone (bandeau 180 fixe + onglets + puces) → à trancher à l'œil ; ValueKey(board) jette le cache _displays à chaque changement de board.
- Fix round 1 rendu : DONE_WITH_CONCERNS, d1797f7, 1771/7/0, 3 mutations.
- Re-relecture (sonnet) : 3/3 ADRESSÉS.
- Tâche 6: fix round 1/5 (3 addressed, 0 open; commits c979937..d1797f7)
- Tâche 6: minor (deferred): carte promenée puis relâchée près du départ ouvre le menu (conséquence du déplacement net) ; puces sur 2 lignes à 360 px (~56 px) à valider à l'œil ; ressenti de l'appui long à valider sur appareil ; barre d'outils de T4 sur une ligne à part (maquette : même rangée).
Tâche 6: complete (commits 7ca3280..d1797f7, re-review clean)

### Tâche 7
- BASE = d1797f7. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, d650283, 10 captures de la VRAIE page. Regardées par le contrôleur (un_commandant_840, grille_defilee_390) : conformes pour l'essentiel. Écarts de disposition vs maquette : barre Catégorie|Type + grille/liste centrée sur sa propre ligne (maquette : à droite des puces) ; quantité en stepper bas (maquette : pastille haut-droite).
- Relecture (haiku) : Needs fixes (petit lot) : _runGuarded avale les erreurs du corps ; aucune mutation pour l'assertion de hauteur 180. Fix round 1/5 dispatché (resume) + addTearDown(db.close).
- Fix round 1 rendu : DONE, af763f8. Mutation hauteur +10 → 6 captures bandeau échouent (180 vs 190) + 4 goldens.
- Re-relecture (haiku) : 3/3 ADRESSÉS.
- Tâche 7: fix round 1/5 (3 addressed, 0 open; commits d650283..af763f8)
- Tâche 7: minor (deferred): MissingPluginException avalée pour tout plugin ; erreur orpheline après la fin du corps perdue ; goldens « bandeau » = haut de page entière ; spinner d'art figé hors ligne dans les goldens.
Tâche 7: complete (commits d1797f7..af763f8, re-review clean)

## Revue finale chantier D
- Base : af22381.
- Revue finale (opus) : « avec corrections ». 3 importants : Power calculé sur les 4 boards (et « recalcul » sans effet) ; Power reste après « Vider » ; hauteur utile sur téléphone (~1,5 rangée visible à 390 px).
Ruling 6: la hauteur utile sur téléphone (bandeau 180 fixe + onglets + puces sur 2 lignes + barre d'outils sur sa ligne) N'EST PAS restructurée dans ce chantier : c'est une décision de design (bandeau qui défile, ou barre d'outils dans la rangée des puces) qui demande l'œil de l'utilisateur sur les captures 390 px ; la changer en fin de chantier risquerait le glisser-déposer, tout juste stabilisé. Soumis à l'utilisateur. Coût si faux : ~1,5 rangée de cartes visibles sur téléphone jusqu'à la décision.
- Vague finale dispatchée (sonnet) : F1-F8 (final-fix-findings.md).
- Vague finale rendue : DONE, 4 commits af763f8..d1dd88b, 1777 passés / 8 ignorés (8e = fichier capture de T7, pas un test désactivé), analyze 154, 8 mutations.
- Re-relecture de la vague finale (sonnet) : F1-F8 ADRESSÉS, aucune casse. Mineur : le facteur Mana Base change nettement avec la répétition par quantité (plus fidèle au deck joué), non couvert par un test.

Chantier D : COMPLET (af22381..d1dd88b), revue finale propre après une vague.
