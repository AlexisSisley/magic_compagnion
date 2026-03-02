# Sprint 13 - Analyse Business : Polish UI & Ajustements Visuels
> Agent : Zorro (Business Analyst) | Date : 02/03/2026

---

## 1. Reformulation du Probleme

**Domaine metier** : Application Flutter mobile pour joueurs de Magic: The Gathering (Magic Companion).

**Parties prenantes** : Developpeur solo (Alexis), utilisateurs joueurs MTG (deckbuilders Commander, collectionneurs, joueurs competitifs multi-formats).

**Point de douleur central** : Apres 12 sprints (8 techniques + 4 features), l'application est fonctionnellement riche et techniquement solide (score 9.0/10, 298+ tests). Cependant, des irritants visuels mineurs subsistent dans l'interface utilisateur, notamment :

### A. Top bar Deck Detail trop compacte

1. **Top bar deck detail page** : La barre de navigation par onglets (TabBar) dans la page de detail d'un deck est visuellement trop serree. Les onglets (Main, Side, Considering, Wishlist, Tokens, Stats, Suggestions, Legalite) sont ecrases verticalement avec un padding insuffisant, ce qui degrade l'experience tactile et la lisibilite sur les petits ecrans.

---

## 2. Analyse de la Cause Racine

1. **TabBar trop compacte** : La `PreferredSize` du composant `bottom` de l'AppBar etait fixee a 50px avec un padding vertical de seulement 6px. Sur 8 onglets scrollables (dont certains avec icones), cette hauteur est insuffisante pour un confort tactile optimal. La zone de tap est trop petite et le texte parait ecrase.

---

## 3. Inventaire des Assets Existants

### Infrastructure existante reutilisable

| Composant | Etat | Utilite Sprint 13 |
|-----------|------|-------------------|
| `deck_detail_page.dart` | 604 lignes, AppBar + TabBar | Fichier principal a modifier |
| `AppTextStyles` | Centralise dans `lib/theme/` | Styles deja utilises dans le TabBar |
| `AppColors` | Centralise dans `lib/theme/` | Couleurs deja utilisees dans le TabBar |

### Metriques actuelles

| Metrique | Valeur Sprint 12 |
|----------|-----------------|
| Tests | 298+ |
| flutter analyze errors | 0 |
| Score qualite | 9.0/10 |

---

## 4. User Stories

### US-13.1 : Agrandir la top bar de la page Deck Detail

**En tant que** joueur de MTG utilisant Magic Companion,
**je veux** que la barre d'onglets dans le detail d'un deck soit plus aere et lisible,
**afin de** pouvoir naviguer confortablement entre les differents onglets (Main, Side, Considering, Wishlist, Tokens, Stats, Suggestions, Legalite) sans cliquer a cote.

**Criteres d'acceptation :**
- La hauteur de la zone TabBar passe de 50px a 58px
- Le padding vertical des tabs passe de 6px a 10px
- Les labels des onglets restent lisibles et bien centres
- L'indicateur de selection (bordure warning) reste visible et bien positionne
- Le drag & drop entre onglets continue de fonctionner
- 0 regression visuelle sur le reste de la page
- 0 regression fonctionnelle (les 8 onglets restent navigables)

**Story points** : 1 (XS)
**Priorite** : P1

#### Scenarios Gherkin

```gherkin
Feature: US-13.1 - Top bar deck detail agrandie

  Scenario: Les onglets sont lisibles et bien espaces
    Given je suis sur la page de detail d'un deck
    When la page se charge
    Then la zone des onglets a une hauteur d'au moins 58px
    And le padding vertical des onglets est de 10px
    And les labels sont lisibles et bien centres

  Scenario: Navigation par onglets fonctionne
    Given je suis sur la page de detail d'un deck
    When je clique sur l'onglet "Side"
    Then le contenu du sideboard s'affiche
    And l'indicateur de selection est visible sous l'onglet "Side"

  Scenario: Drag & drop entre onglets fonctionne
    Given je suis sur la page de detail d'un deck avec des cartes
    When je drag une carte vers l'onglet "Considering"
    Then la carte est deplacee vers le board Considering
    And un snackbar de confirmation s'affiche
```

---

## 5. Estimation et Budget

| Sprint | Duree | Effort Total | Complexite |
|--------|-------|--------------|------------|
| Sprint 13 : Polish UI | 1 jour | 0.5j | Tres faible |

---

## 6. Hors Scope

- Redesign complet de l'AppBar
- Ajout de nouvelles fonctionnalites dans les onglets
- Modification du commander header
- Changement de couleurs ou de polices
