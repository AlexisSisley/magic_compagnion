# Chantier E — journal des arbitrages

Copie du registre d'exécution (subagent-driven-development), conservée après suppression de l'espace de travail.


Branche chantier-e-tags, partie de main ccc2d47. Pas de spec séparée : la section « Décisions de l'utilisateur » du plan fait foi (recette 25/10/2026).

## Scan pré-vol

| Paire / tâche | Produit → consommé | Constat |
|---|---|---|
| T1 → T3 | CardTagCatalog.load(), cardTagCatalogProvider → suggestion à l'ouverture, regroupement | Le plan ne dit pas qui charge le provider. Ruling R1 |
| T1 → T4/T6 | provider add/rename/delete/reorder/setColor | Signatures cohérentes |
| T2 → T3 | suggestTagKeys → _suggestTagsForUntagged ; T3 supprime card_category_service | T2 recopie les motifs avant la suppression : ordre correct |
| T3 → T4 | setCardTags/resetCardTags, entrée « Tags… » provisoire → feuille | Cohérent |
| T3 → T5 | _buildTagList, en-têtes → pastilles colorées | T3 et T5 lisent le catalogue dans DeckCardListTab. Ruling R2 |
| T3 → T6 | refreshAfterTagChanges → retour de l'écran Tags | Défini en T3, appelé en T6 : OK |
| T3 → T7 | DeckCard.tagsEdited → imports | OK |
| T1 | ses tests contre son code | OK |
| T2 | ses tests contre son code | Growth Spiral → ['ramp','draw'] avec le nouveau motif : OK |
| T3 | tests (migration, tags, backup, prefs, ordre) contre son code | Supprime card_category*.dart et leurs tests : les captures citent peut-être CardCategory. À suivre via la compilation |
| T4 | tests contre son code | Feuille avec « Rendre universel » qui touche le provider : la feuille doit vivre sous ProviderScope (Consumer) |
| T5 | tests contre son code | Voir R2 |
| T6 | tests contre son code | OK |
| T7 | tests contre son code | « L'import Moxfield pose ces tags » sans test côté contrôleur. Ruling R3 |

Ruling R1: CardTagCatalogController charge le catalogue dans son constructeur. DeckDetailController lit le catalogue directement en base via CardTagCatalog(db).load() pour la suggestion (la base est la source de vérité) — évite un état vide au premier rendu — coût si faux : une lecture AppSettings de plus à l'ouverture d'un deck.
Ruling R2: DeckCardListTab reçoit le catalogue en paramètre (`List<CardTagDef> tagCatalog`), passé par deck_detail_page qui fait `ref.watch(cardTagCatalogProvider)`. Le widget reste testable sans provider — coût si faux : un paramètre de plus à faire suivre.
Ruling R3: la tâche 7 ajoute un test contrôleur `moxfield import applies authorTags` en plus du test du mapper — le plan exige le câblage sans test qui le prouve (leçon « un plan oublie de dire qui appelle ») — coût : un test.
Task 1: dispatched (base ccc2d47, sonnet)
Task 1: complete (commits ccc2d47..64e9da4, review clean)
Task 1: minor (deferred): setColor avant la fin du load() du constructeur sauve [] et efface le catalogue (controller:65-80)
Task 1: minor (deferred): usageCount compte via une transaction d'écriture (card_tag_catalog.dart:409)
Task 1: minor (deferred): test « old backup keeps catalog » non discriminant ; branche export catalogue illisible non testée
Task 1: minor (deferred): attente fixe 50 ms dans card_tag_catalog_test.dart:655
Task 1: minor (deferred): rename sauve le catalogue puis réécrit les decks en deux étapes non atomiques
Task 2: dispatched (base 64e9da4, sonnet)
Task 2: Ruling: garder l'exclusion tutor sur la recherche de terrain à poser (Rampant Growth = ramp seul) — reproduit le comportement du classeur D, évite un faux Tuteur sur tout le ramp — coût si faux : un Tuteur manquant sur ces cartes, corrigeable à la main
Task 2: complete (commits 64e9da4..504ac03, review clean)
Task 2: minor (deferred): aucun test n'isole la branche « exile up to » du blink
Task 3: dispatched (base 504ac03, opus)
Task 3: implemented d2152d5 (1853 passed / 8 skipped, analyze 154 = baseline) ; review dispatched (opus)
Task 3: minor (deferred): au premier rendu groupé par tags, tous les tags passent pour des tags de deck (ordre alpha) tant que cardTagCatalogProvider charge
Task 3: complete (commits 504ac03..d2152d5, review clean ; aucun PNG dans le commit vérifié)
Task 3: minor (deferred): tri des tags de deck sensible aux accents (« Éclair » après « Zèbre ») dans _buildTagList
Task 3: minor (deferred): _suggestTagsForUntagged pose les tags en mémoire même sur une ligne que l'UPDATE conditionnel a sautée
Task 4: dispatched (base d2152d5, sonnet)
Task 4: complete (commits d2152d5..372264b, review clean)
Task 4: minor (deferred): test wiring « Suggestion auto … rend la carte » mal nommé (n'affirme que l'absence)
Task 4: minor (deferred): message d'erreur de la feuille reste affiché après un ajout réussi / une saisie
Task 5: dispatched (base 372264b, sonnet)
Task 5: Ruling: en regroupement par type, les points de la vignette grille montrent TOUS les tags (principal compris), comme la liste compacte — sinon le tag principal n'apparaît nulle part en grille+type — coût si faux : un point de plus par vignette en vue Type
Task 5: review — Important: vignette grille ignore la règle « vue Type = tous les tags » ; fix round 1 dispatché (reprise implémenteur)
Task 5: minor (deferred): « Sans tag » reconnu par chaîne magique (group.title == 'Sans tag') ; un tag utilisateur homonyme prendrait la couleur neutre
Task 5: fix round 1/5 (1 addressed, 0 open; commits d47c1af..6003d11)
Task 5: complete (commits 372264b..6003d11, review clean)
Task 6: dispatched (base 6003d11, sonnet)
Task 6: complete (commits 6003d11..11f503e, review clean) — corrige aussi le minor T1 « setColor avant load »
Task 6: minor (deferred): filtre d'erreur « overflowed » trop large dans deck_detail_page_wiring_test (artefact police de test sur libellés préexistants)
Task 6: minor (deferred): _refreshCounts non protégé contre des exécutions concurrentes (sous-titre qui clignote après renommage)
Ruling: trailers Co-Authored-By Sonnet sur certains commits de sous-agents laissés tels quels — sans effet fonctionnel — coût : attribution inexacte dans l'historique
Task 7: dispatched (base 11f503e, sonnet)
Task 7: controller visual check — feuille de tags : « Enregistrer » sur or sombre (primaryShade800), texte peu contrasté ; le bouton « Nouveau tag » de l'écran Tags utilise l'or normal → à aligner (finding pour la revue finale)
Task 7: complete (commits 11f503e..a028770, review clean)
Task 7: minor (deferred): const _sectionNames insérée entre le doc-comment et parseDecklistCsv
Task 7: minor (deferred → à corriger en revue finale) : les tags importés ne prennent pas l'orthographe du catalogue (« ramp » importé ne se groupe pas avec « Ramp ») — contraire à la contrainte globale
Final review: dispatched (opus, base ccc2d47)
Final review: with fixes — I1 page deck périmée après renommage depuis Paramètres ; I2 imports sans orthographe du catalogue ; I3 migration bloque la suggestion multi-rôles ; I4 (préexistant) BackupService de prod sans base Drift ; m1 or sombre « Enregistrer » ; m2 pertes CSV ; m3 tag « Sans tag » ; m4 conversions anciennes au libellé par défaut
Ruling: I3 — une catégorie NON verrouillée n'est plus convertie en tag (la carte reste vide, tagsEdited faux, et reçoit la suggestion multi-rôles à l'ouverture) ; une catégorie verrouillée reste le tag principal. S'applique à la migration v7 et à la conversion des anciennes sauvegardes/JSON — la catégorie non verrouillée était une déduction automatique, la nouvelle suggestion en est un sur-ensemble (décision 1 : « l'app propose ») — coût si faux : une carte dont l'ancien rôle auto n'est plus reconnu par les nouveaux motifs se retrouve sans tag (corrigeable à la main)
Ruling: I4 hors périmètre (préexistant) — signalé à l'utilisateur, pas corrigé dans E — coût : le catalogue n'est pas sauvegardé par l'export de prod
Ruling: fix wave = I1, I2, I3, m1, m3 + guillemets échappés à l'export CSV (m2 partiel) ; m2 reste (Commander filtré, , et ; dans un nom, homonymes multi-sections) et m4 restent différés — limites du format CSV / cas rares
Final fix wave: dispatched (sonnet, base a028770)
Final fix wave: 6 addressed, 0 open (commits a028770..2329cd4) ; minors différés : rechargement aussi sur add/reorder/setColor, ordre des imports
