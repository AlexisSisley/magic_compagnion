# SDD ledger — plan: docs/superpowers/plans/2026-10-19-chantier-c-bibliotheque-decks.md

Spec: docs/superpowers/specs/2026-10-18-mythic-moxfield-design.md §2, §6, §7 (lue)
Worktree: .claude/worktrees/chantier-cd, branche worktree-chantier-cd, depuis main 17ffb29
Mandat utilisateur (2026-10-25) : exécuter C puis D en subagents, jusqu'au push sur main.
oracle-cards.json : lien dur créé. Baseline : 1524 passés / 6 ignorés / 0 échec ; analyze 166.

## Scan de pré-vol

| A | B | Partagé | A produit | B consomme | Constat |
|---|---|---|---|---|---|
| T1 | T2 | deck_model, app_database | colonnes tags/updatedAt, champs | lecture/écriture, horodatage | Cohérent, séquentiel. |
| T2 | T7 | DeckService.updateDeckTags | méthode | controller.updateDeckTags | Cohérent. |
| T3 | T5 | DeckListController | clearAllFilters, activeFilterCount | état vide filtré | Cohérent. |
| T3 | T6 | DeckSort, DeckFilterCriteria, updateTags/updatePriceRange | API | barre + feuille | Cohérent. Entre T3 et T6 la page garde ses vieilles pilules : 'Commander' / 'Standard' matchent deck.format — pas de casse. |
| T4 | T7 | DeckListCard.onLongPress | paramètre | ouverture de la feuille | Cohérent. |
| T4,T5,T6 | — | deck_list_page.dart | — | — | Séquentiel, zones distinctes (tuile, liste→grille, pilules). |
| T5,T6 | T8 | DeckLibraryGrid, DeckFilterBar | widgets | captures | Cohérent. |

| Tâche | Cohérence interne | Constat |
|---|---|---|
| T1 | test de migration depuis DDL v4 écrit à la main ; `from == 4` saute les marches < 4 | Cohérent |
| T2 | horloge injectée dans DeckService (défaut DateTime.now) pour tests déterministes | Cohérent |
| T3 | selectedSort passe de String à DeckSort : tests existants de DeckListState à adapter (écrit) | Cohérent |
| T4 | golden 23 à régénérer et regarder (écrit) | Cohérent |
| T5 | fond opaque local, shell inchangé | Cohérent |
| T6 | réutilise showDeckIdentityFilterModal | Cohérent |
| T7 | décision du plan (appui long) validée par l'utilisateur avec le plan | Cohérent |
| T8 | DeckListPage non montable → captures des widgets | Cohérent |

Scan propre, aucun ruling de pré-vol.

---

## Progression

### Tâche 1
- BASE = 17ffb29. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, be968d6, 1528/6/0, 4 mutations. Doute « DeckService ne lit/écrit pas encore tags/updatedAt » = périmètre de la tâche 2.
- Relecture (sonnet) : SPEC ✅, QUALITÉ approuvée. DDL v4 vérifié fidèle au schéma réel de 17ffb29. ⚠️ persistance DeckService → résolu : c'est la tâche 2.
- Tâche 1: minor (deferred): `dynamic raw` dans le helper de migration (sqlite3 non dépendance directe).
- Tâche 1: minor (deferred): `updatedAt` mal formé → null silencieux, non testé.
Tâche 1: complete (commits 17ffb29..be968d6, review clean)

### Tâche 2
- BASE = be968d6. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 6586649, 1537/6/0, 15 mutations. Écarts : proxyQuantity propagé par upsertCardInDeck et le mixin ; import de sauvegarde restaure enfin proxyQuantity. Doutes : updateDeck d'un Deck périmé écrase les tags ; moveCard vers carte existante remplace proxy/foil.
- Relecture (sonnet) : SPEC ❌, Needs fixes. 2 importants : (1) fusion moveCard/changeCardVersion vers carte existante remplace proxy/foil au lieu de fusionner (proxys perdus, §6.1) ; (2) updateDeck écrit les tags d'un Deck périmé (deck_detail_controller:197) → écraserait updateDeckTags.

Ruling 1: fusion = proxyQuantity sommé et borné par la quantité finale, isFoil = OU ; appliqué dans upsertDeckCard (branche existante) via un mode de fusion, et dans le repli SharedPreferences. Coût si faux : un foil « contaminant » une pile non foil lors d'un déplacement.
Ruling 2: updateDeck n'écrit plus les tags (seul updateDeckTags les écrit). Coût si faux : un futur appelant qui voudrait écrire tags+cartes d'un coup doit faire deux appels.
Ruling 3 (mineur promu): le recalcul automatique des couleurs à l'ouverture d'un deck ne fait PAS avancer updatedAt — ce n'est pas une modification de l'utilisateur, et sinon le tri « Modifié récemment » (tâche 3) mentirait. Coût si faux : aucun.
- Fix round 1/5 dispatché (resume implémenteur).
- Fix round 1 rendu : DONE, ceb4769, 1543/6/0, 7 mutations. Drapeau `mergeVariants` sur upsertDeckCard et le mixin ; updateDeck n'écrit plus les tags ; `touch: false` pour le recalcul des couleurs.
- Tâche 2: minor (deferred, préexistant): changeCardVersion vers une impression déjà présente REMPLACE sa quantité (2x v1 → v2 qui avait 1x = 2x au lieu de 3x). Perte de copies, antérieure au chantier, hors brief → à trier en revue finale.
- Re-relecture (sonnet) : 3/3 ADRESSÉS, aucune casse.
- Tâche 2: fix round 1/5 (3 addressed, 0 open; commits 6586649..ceb4769)
- Tâche 2: minor (deferred): plafonnement des proxys fusionnés non testé ; repli prefs de « Deck périmé garde ses tags » non testé.
- Tâche 2: minor (deferred, préexistant): moveCard/changeCardVersion suppriment puis réinsèrent sans transaction.
Tâche 2: complete (commits be968d6..ceb4769, re-review clean)

### Tâche 3
- BASE = ceb4769. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, c49a28e, 1560/6/0, 10 mutations. selectedFormat devient String? (null=tous). Méthodes contrôleur updateTags/updatePriceRange/clearAllFilters/availableTags sans test contrôleur (construction lourde).
- Relecture (sonnet) : SPEC ✅ (⚠️ union des formats), Needs fixes. 1 important : câblage contrôleur non testé (élagage après loadDecks, clearAllFilters, updateTags, availableTags) alors que le helper `_createImportController` existe.
- ⚠️ résolu par moi : le brief exige « liste des formats proposés = union des deck.format présents » → manque réel, ajouté au round (getter availableFormats).
- Fix round 1/5 dispatché : tests contrôleur + availableFormats + mineurs (sentinelle 'Tous' → la page passe null ; ordre des imports).
- Fix round 1 rendu : DONE, 8a6518d, 1566/6/0, 9 mutations. availableFormats ajouté, page passe null.
- Re-relecture (haiku) : 3/3 ADRESSÉS.
- Tâche 3: fix round 1/5 (3 addressed, 0 open; commits c49a28e..8a6518d)
- Tâche 3: minor (deferred): helper `build` de test dupliqué ; selectedFormat non élagué quand le dernier deck de ce format disparaît (filtre fantôme, même défaut que celui corrigé pour les tags).
Tâche 3: complete (commits ceb4769..8a6518d, re-review clean)

### Tâche 4
- BASE = 8a6518d. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 98e9f20, 1574/6/0, analyze 164 (-2), 8 mutations. Golden 23 regardé par le contrôleur : conforme maquette ; 4e tuile coupée par le cadre de capture (taille fixture), pas un débordement. Art réel jamais vu (réseau coupé) → lisibilité sur art clair à vérifier sur appareil.
- Relecture (sonnet) : Needs fixes. 1 important : le nom est dans la partie faible du dégradé (alpha ~0,24-0,45) → ~2:1 de contraste sur art clair, sous le seuil 3:1 du grand texte.
- Fix round 1/5 dispatché (resume) : dégradé à paliers + ombre légère sur le nom ; + mineur test du pluriel « 1 carte ».
- Tâche 4: minor (deferred): runZonedGuarded du test de tuile avale toutes les erreurs async ; golden 23 ne montre pas le « — » (4e tuile coupée).
- Fix round 1 rendu : DONE, e475eed, 1576/6/0. Dégradé [0,0.25,1]/[0,0.6,0.9] + ombre.
- Re-relecture (haiku) : 2/2 ADRESSÉS. Contraste estimé ≈ 5:1 sous le nom.
- Tâche 4: fix round 1/5 (2 addressed, 0 open; commits 98e9f20..e475eed)
- Tâche 4: minor (deferred): libellé de test > 80 colonnes.
Tâche 4: complete (commits 8a6518d..e475eed, re-review clean)

### Tâche 5
- BASE = e475eed. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, e1f77ce, 1586/6/0, 5 mutations. DeckListState.criteria ajouté (source unique). Doutes : param prices inutilisé ; recherche sans résultat affiche « Aucun deck pour l'instant ».
- Relecture (sonnet) : Needs fixes. 1 important : une recherche sans résultat affiche « Aucun deck pour l'instant » ; « Effacer les filtres » laisse la recherche, la liste peut rester vide. Risques (b) criteria = getter dérivé, pas de dérive ; (c) identité stable (KeyedSubtree + findChildIndexCallback).

Ruling 4: l'état vide distingue « bibliothèque vide » (decks.isEmpty → « Aucun deck pour l'instant », pas de bouton) de « rien ne correspond » (bibliothèque non vide → « Aucun deck ne correspond », bouton « Tout effacer » qui vide recherche ET filtres). Écart au brief, qui ne distinguait que les filtres. Coût si faux : un bouton qui efface aussi le texte tapé.
Ruling 5: le paramètre `prices` de DeckLibraryGrid, exigé par le plan mais jamais lu, est retiré. Coût si faux : nul.
- Fix round 1/5 dispatché (resume) : Ruling 4, Ruling 5, `dart format` de la page.
- Fix round 1 rendu : DONE_WITH_CONCERNS, 0c55c51, 1587/6/0. clearSearchAndFilters ajouté ; page dart-formatée (gros diff de forme).
- Re-relecture (sonnet) : 3/3 ADRESSÉS (format partiel assumé : contrôleur et son test non formatés pour ne pas noyer le diff).
- Tâche 5: fix round 1/5 (3 addressed, 0 open; commits e1f77ce..0c55c51)
- Tâche 5: minor (deferred): `_searchController.clear()` non testable (page non montable) → contrôle à l'œil ; test 16:9 sur Container, pas sur la vraie tuile à 310 px de large → captures tâche 8 ; clearAllFilters sans appelant page.
Tâche 5: complete (commits e475eed..0c55c51, re-review clean)

### Tâche 6
- BASE = 0c55c51. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS (visuel), 94060ec, 1611/6/0, 8 mutations. Écart : butée droite du curseur = (min, infinity) → « Dès X € » sans couper les decks au-delà du plafond ; plage entière = filtre retiré.
- Relecture (sonnet) : SPEC ✅, QUALITÉ approuvée. Infini confiné à applyDeckFilters et au libellé ; chaque croix efface son filtre ; feuille resynchronisée après la modale d'identité.
- Tâche 6: minor (deferred): plafond recalculé à chaque ouverture → fourchette clampée affichée « Tous les prix » alors que le filtre reste actif ; bornes dégénérées « 50–50 € » / « Sous 0 € » ; modale d'identité « Identite Couleur » sans accent et Colors.yellow en dur (fichier préexistant) ; getSortLabel inutilisé.
Tâche 6: complete (commits 0c55c51..94060ec, review clean)

### Tâche 7
- BASE = 94060ec. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 5812386, 1620/6/0, 4 mutations. Branchement page de l'appui long non testable ; concurrence appui long / Dismissible à vérifier.
- Relecture (sonnet) : approuvée. Gestes : un seul InkWell, l'arène départage appui long et glissement ; clavier : isScrollControlled + viewInsets.
- Tâche 7: minor (deferred): pas de test du doublon présent seulement dans `current` (retirer current de _merge passerait) ; casse divergente current/known → puce non cochée ; clavier non testé.
Tâche 7: complete (commits 94060ec..5812386, review clean)

### Tâche 8
- BASE = 5812386. Implémenteur dispatché (sonnet).
- Rendu : DONE_WITH_CONCERNS, 2147e68. 5 captures. Défauts vus par l'implémenteur ET confirmés à l'œil par le contrôleur :
  (1) à 390 px la puce « Sous 300 € » est hors champ (défilement horizontal sans indice) alors que le badge dit 2 ;
  (2) « Enregistrer » (feuille Dossiers) en lilas sur fond or, contraste faible ; « Tout effacer » lilas aussi. Harnais = vrai buildAppTheme → défaut de production.

Ruling 6: les puces de filtres actifs passent à la ligne (Wrap) quand elles ne tiennent pas, au lieu de défiler hors champ ; la pilule Filtres et le tri restent sur la première ligne. Motif : un filtre actif invisible ment sur l'état de la liste. Coût si faux : une barre de deux lignes sur téléphone quand plusieurs filtres sont actifs.
Ruling 7: les boutons pleins or (« Enregistrer », et tout FilledButton des nouveaux écrans) portent explicitement un texte sombre `AppColors.textOnPrimary` ; « Tout effacer » prend la couleur d'accent or. Si la cause est le thème global (onPrimary lilas), corriger le thème plutôt que chaque bouton, après avoir vérifié l'effet sur les autres écrans. Coût si faux : un changement de thème qui touche d'autres boutons — à constater dans les captures existantes.
- Fix round 1/5 dispatché (resume implémenteur tâche 8).
- Fix round 1 rendu : DONE, cc5125b, 1622/7/0 (7e ignoré = nouveau fichier capture). Lilas = primary de ThemeData.dark() → corrigé localement (thème global non touché, il changerait sliders/switches de toute l'app). Puces : 2e ligne sous 600 px. Fichiers reformatés par erreur : différence EOL seule, restaurés par le contrôleur (vérifié --ignore-cr-at-eol).
- Relecture tâche 8 + correctifs (sonnet) : approuvée, captures conformes ; aucun bouton or resté lilas.
- Tâche 8: minor (deferred): puce d'un tag très long → RenderFlex overflow dans le Wrap (tag non borné) ; seuil 600 de la barre mesuré sur largeur interne (≠ grille) ; ondulation lilas du TextButton « Tout effacer » de la feuille de filtres ; feuille de filtres non capturée.
Tâche 8: complete (commits 5812386..cc5125b, review clean)

## Revue finale chantier C
- Merge-base : 17ffb29.
- Revue finale (opus) : « avec corrections ». 3 importants : changeCardVersion perd des copies (absoluteQuantity) ; icône d'image cassée quand l'art ne charge pas (LOCAL: et hors ligne) ; « Identite Couleur » + Colors.yellow (régression vs main). Triage complet des mineurs reportés dans son rapport.
Ruling 8: la consigne du plan « modale d'identité réutilisée telle quelle » cède devant la contrainte « libellés accentués » : on corrige l'accent et la couleur. Coût si faux : nul.
- Vague finale dispatchée (sonnet) : F1-F9 (final-fix-findings.md).
- Vague finale rendue : DONE_WITH_CONCERNS, 8 commits cc5125b..525cc42, 1633/7/0, analyze 164. 5 goldens sans rapport (01,02,03,05,30) modifiés par la régénération locale → remis, non commités.
- Re-relecture de la vague finale (sonnet) : F1-F9 ADRESSÉS, aucune casse. Mineur : excludeSemantics retire format et prix du lecteur d'écran (choix assumé).
- Hors périmètre : `--update-goldens` local altère 5 goldens sans rapport (01,02,03,05,30) — non commités ; écart de rendu local préexistant à investiguer à part.

Chantier C : COMPLET (17ffb29..525cc42), revue finale propre après une vague.
