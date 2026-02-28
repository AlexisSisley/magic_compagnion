# Sprint 3 - Analyse Business : Tests et CI/CD
> Agent : Zorro (Business Analyst) | Date : 26/02/2026

---

## 1. Contexte

Sprint 1 (Fondations) et Sprint 2 (Riverpod) sont terminés. Le projet a :
- 0% de couverture de tests (1 seul test smoke)
- Un pipeline CI qui exécute `flutter test` mais sans couverture
- 5 services core testables unitairement (CollectionService, DeckService, WishlistService, BackupService, LocalCardService)
- 4 modèles avec sérialisation JSON (DeckCard, Deck, Wishlist, ScryfallCard, Profile)

**Objectif Sprint 3** : Atteindre >40% de couverture sur les services, valider la sérialisation des modèles, intégrer la couverture au pipeline CI.

---

## 2. User Stories

### US-S3-01 : Tests de sérialisation des modèles
**En tant que** développeur,
**Je veux** des tests qui valident le roundtrip fromJson/toJson de chaque modèle,
**Afin de** détecter immédiatement toute régression de sérialisation.

**Critères d'acceptation :**
- [ ] DeckCard : roundtrip JSON, valeurs par défaut (proxyQuantity=0, isFoil=false, tags=[])
- [ ] Deck : roundtrip JSON avec 4 zones (mainboard, sideboard, considering, wishlist), commander nullable
- [ ] Wishlist : roundtrip JSON, totalCards getter
- [ ] ScryfallCard : roundtrip fromJson avec card_faces (double-face), image fallback, purchase_uris
- [ ] Profile : roundtrip JSON, colorValue par défaut, commander nullable

**Priorité** : P1 | **Effort** : 0.5j

---

### US-S3-02 : Tests unitaires CollectionService
**En tant que** développeur,
**Je veux** tester toutes les opérations CRUD de CollectionService,
**Afin de** garantir la fiabilité de la gestion de collection.

**Critères d'acceptation :**
- [ ] loadCollection() retourne [] quand SharedPreferences est vide
- [ ] upsertCardInCollection() ajoute une nouvelle carte
- [ ] upsertCardInCollection() met à jour la quantité d'une carte existante
- [ ] upsertCardInCollection() supprime la carte quand quantité <= 0
- [ ] Distinction Foil/Non-Foil : deux entrées séparées pour le même scryfallId
- [ ] Gestion des tags (ajout, modification)
- [ ] clearCollection() vide la collection
- [ ] getAllUniqueTags() retourne les tags triés sans doublons
- [ ] recordDailyValue() + getEvolutionSince() : historique financier

**Priorité** : P1 | **Effort** : 1j

---

### US-S3-03 : Tests unitaires DeckService
**En tant que** développeur,
**Je veux** tester toutes les opérations de DeckService,
**Afin de** garantir la fiabilité de la gestion de decks.

**Critères d'acceptation :**
- [ ] createNewDeck() crée un deck avec les bons défauts (format Standard, listes vides)
- [ ] deleteDeck() supprime le bon deck
- [ ] upsertCardInDeck() fonctionne sur les 4 boards (main, side, considering, wishlist)
- [ ] upsertCardInDeck() gère ajout/modification/suppression
- [ ] setCommander() met le format à Commander automatiquement
- [ ] unsetCommander() remet le format à Standard si plus aucun commandant
- [ ] clearDeck() vide toutes les zones et reset le format
- [ ] moveCard() déplace une carte d'une zone à l'autre
- [ ] Deck non trouvé → StateError

**Priorité** : P1 | **Effort** : 1j

---

### US-S3-04 : Tests unitaires WishlistService
**En tant que** développeur,
**Je veux** tester WishlistService y compris la migration legacy,
**Afin de** garantir la compatibilité arrière et le bon fonctionnement des wishlists.

**Critères d'acceptation :**
- [ ] loadWishlists() crée une wishlist par défaut si aucune donnée
- [ ] createWishlist() ajoute une wishlist
- [ ] deleteWishlist() supprime la bonne wishlist
- [ ] renameWishlist() renomme correctement
- [ ] clearWishlistCards() vide les cartes sans supprimer la wishlist
- [ ] upsertCard() gère ajout/modification/suppression/foil
- [ ] setWishlistIcon() met à jour l'icône
- [ ] Migration v1→v2 : données legacy transférées, ancienne clé supprimée

**Priorité** : P1 | **Effort** : 0.5j

---

### US-S3-05 : Tests unitaires BackupService
**En tant que** développeur,
**Je veux** tester la génération et restauration de sauvegardes JSON,
**Afin de** garantir qu'aucune donnée n'est perdue lors du backup/restore.

**Critères d'acceptation :**
- [ ] generateBackupJson() inclut backup_date et app_version
- [ ] generateBackupJson() gère les types String, int, bool, JSON-in-String
- [ ] restoreFromJson() restaure correctement tous les types de données
- [ ] Roundtrip : generate → restore → generate produit le même résultat
- [ ] restoreFromJson() avec JSON corrompu → Exception

**Priorité** : P2 | **Effort** : 0.5j

---

### US-S3-06 : Tests fonction de recherche locale
**En tant que** développeur,
**Je veux** tester la fonction _executeSearch de LocalCardService,
**Afin de** valider que la recherche/filtrage fonctionne correctement.

**Critères d'acceptation :**
- [ ] Recherche par nom (contient, insensible à la casse)
- [ ] Recherche par printedName (nom imprimé/traduit)
- [ ] Filtre par type de carte
- [ ] Filtre par code d'extension (setCode)
- [ ] Filtre par rareté
- [ ] Filtre par CMC (min/max)
- [ ] Filtre par couleurs (identité de couleur)
- [ ] Filtre par keyword (texte de règles)
- [ ] Combinaison de filtres multiples

**Priorité** : P1 | **Effort** : 0.5j

---

### US-S3-07 : Couverture de tests dans le pipeline CI
**En tant que** développeur,
**Je veux** que le pipeline CI vérifie la couverture de tests,
**Afin de** prévenir les régressions de couverture.

**Critères d'acceptation :**
- [ ] `flutter test --coverage` exécuté dans le pipeline
- [ ] Rapport de couverture généré (lcov.info)
- [ ] Seuil minimum de couverture vérifié (>=30% global au démarrage)
- [ ] Le build échoue si la couverture est en dessous du seuil

**Priorité** : P1 | **Effort** : 0.5j

---

## 3. Risques

| ID | Risque | Impact | Mitigation |
|----|--------|--------|------------|
| R1 | SharedPreferences mock fragile | Moyen | Utiliser `SharedPreferences.setMockInitialValues({})` officiel |
| R2 | LocalCardService singleton complexe à tester | Moyen | Tester `_executeSearch` directement (top-level function) |
| R3 | BackupService dépend de file_picker/share_plus | Faible | Ne tester que generateBackupJson/restoreFromJson (logique pure) |
| R4 | ScryfallCard.fromJson complexe (double-face) | Moyen | Couvrir les 2 cas : carte simple et carte double-face |
| R5 | Couverture <40% au final | Faible | Les 5 services + modèles = ~1500 lignes testables, 40% est atteignable |

---

## 4. Hors scope Sprint 3

- Tests d'intégration (widgets, navigation)
- Tests E2E
- Tests des services externes (EDHRec, Google Drive, Oracle)
- Mocking HTTP pour importBatchCards
