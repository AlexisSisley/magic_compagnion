# Sprint 13 - Architecture Technique : Polish UI & Ajustements Visuels
> Agent : Sanji (Architecte) | Date : 02/03/2026

---

## Phase 1 : Comprehension du Probleme & Perimetre

### Perimetre fonctionnel
- **Inclus** : Agrandissement de la top bar (AppBar + TabBar) dans `deck_detail_page.dart`
- **Exclu** : Redesign complet, nouvelles features, modifications des controllers

### Stack existante (inchangee)
- **Langage** : Dart 3.9+ / Flutter 3.35.6
- **State Management** : Riverpod (StateNotifier + AutoDispose)
- **Navigation** : go_router
- **Tests** : 298+ tests, flutter_test

### NFR
- 0 regression fonctionnelle
- 298+ tests verts en permanence
- Aucun impact sur les performances de rendu

### Projet existant
**PROJECT_PATH** = `C:/Users/Alexi/Documents/projet/magic_compagnion/`

---

## Phase 2 : Choix Techniques

| Choix | Decision | Justification |
|-------|----------|---------------|
| Hauteur TabBar | Passer de 50px a 58px | +8px offre plus d'espace tactile sans trop agrandir la zone non-content |
| Padding vertical tabs | Passer de 6px a 10px | +4px par cote ameliore la lisibilite et la zone de tap |
| Approche | Modification in-place des constantes | Changement minimal, aucun refactoring necessaire |

---

## Phase 3 : Architecture des Changements

### 3.1 US-13.1 : Agrandir la top bar Deck Detail

#### Fichier modifie : `lib/pages/decks/deck_detail_page.dart`

**Changement 1** : `PreferredSize` hauteur

```dart
// AVANT (ligne 367)
preferredSize: const Size.fromHeight(50),

// APRES
preferredSize: const Size.fromHeight(58),
```

**Changement 2** : `TabBar` padding vertical

```dart
// AVANT (ligne 382)
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

// APRES
padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
```

#### Impact
- **Fichiers modifies** : 1 (`deck_detail_page.dart`)
- **Lignes modifiees** : 2
- **Risque de regression** : Nul (changement purement visuel sur des constantes de layout)
- **Nouvelles dependances** : 0

---

## Phase 4 : Plan de Livraison

| # | Tache | Effort | Dependance | Statut |
|---|-------|--------|------------|--------|
| 1 | Modifier PreferredSize de 50 a 58px | 5min | -- | FAIT |
| 2 | Modifier padding vertical de 6 a 10px | 5min | -- | FAIT |
| 3 | Verifier flutter analyze : 0 errors | 2min | 1, 2 | FAIT |
| 4 | Test visuel sur emulateur | 10min | 3 | A FAIRE |

**Effort total** : 0.5j (incluant verification et test visuel)
