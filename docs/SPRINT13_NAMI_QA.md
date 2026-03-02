# Sprint 13 - Plan QA : Polish UI & Ajustements Visuels
> Agent : Nami (QA Lead) | Date : 02/03/2026
> Mode : Verification Active + Conseil

---

## VERDICT PRE-SPRINT : PASS

### Resume
- Stack detectee : Flutter / Dart 3.9+ (Flutter 3.35.6)
- Tests : **298+/298+ PASS**
- flutter analyze : 0 errors
- Sprint 12 : BACKLOG (features avancees planifiees)
- Impact Sprint 13 : **Tres faible** (2 constantes de layout modifiees)

### Constat de Sante Avant Sprint 13

| Metrique | Valeur | Statut |
|----------|--------|--------|
| flutter analyze errors | 0 | OK |
| flutter analyze warnings | 0 | OK |
| Tests existants | 298+ PASS | OK |
| Fichier modifie | 1 (deck_detail_page.dart) | OK |
| Lignes modifiees | 2 | OK |

---

## 1. Analyse de Testabilite

| Dimension | Note | Explication |
|-----------|------|-------------|
| Observabilite | **Haute** | Changement purement visuel, observable directement sur l'emulateur |
| Controlabilite | **N/A** | Aucune logique metier modifiee |
| Decomposabilite | **N/A** | Modification isolee dans un seul fichier |
| Stabilite | **Haute** | Constantes de layout ne dependant d'aucun service |
| Comprehensibilite | **Haute** | Changement trivial, 2 valeurs numeriques modifiees |

**Implications** : Ce sprint est un changement cosmetic pur. Aucun test unitaire ou d'integration supplementaire n'est necessaire. Un test visuel manuel suffit.

---

## 2. Matrice de Risques

| Zone / US | Risque Business | Risque Technique | Priorite Test | Profondeur |
|-----------|-----------------|------------------|---------------|------------|
| US-13.1 : Top bar agrandie | Tres faible | Nul | P2 | Test visuel uniquement |
| Regression tests existants | N/A | Nul | P0 | Automatise (CI) |

### Top Risques

Aucun risque majeur identifie. Le changement est purement cosmetic (2 constantes numeriques).

---

## 3. Strategie de Test

### Tests automatises
- **0 nouveau test requis** : Le changement porte sur des constantes de layout qui n'affectent aucune logique testable.
- **298+ tests existants** : Doivent tous passer (regression automatisee via CI).

### Test manuel (obligatoire)

| # | Scenario | Action | Resultat attendu |
|---|----------|--------|-----------------|
| 1 | TabBar visible et aeree | Ouvrir la page detail d'un deck | Les onglets sont bien espaces, lisibles |
| 2 | Navigation par onglets | Cliquer sur chaque onglet (Main, Side, Considering, Wishlist, Tokens, Stats, Suggestions, Legalite) | Chaque onglet navigue correctement, indicateur visible |
| 3 | Drag & drop onglets | Drag une carte vers un onglet different | La carte se deplace, snackbar de confirmation |
| 4 | Petit ecran | Tester sur un ecran de 5 pouces | Les onglets scrollent horizontalement sans overflow |
| 5 | Grand ecran / tablette | Tester sur un ecran de 10 pouces | La zone TabBar ne parait pas disproportionnee |

---

## 4. Criteres PASS/FAIL

| Critere | Seuil | Statut |
|---------|-------|--------|
| flutter analyze : 0 errors | 0 | PASS |
| Tests existants | 298+ / 298+ PASS | A VERIFIER (CI) |
| Test visuel TabBar | Onglets lisibles et navigables | A VERIFIER |
| Regression fonctionnelle | 0 | A VERIFIER |

---

## 5. Verdict

**PASS CONDITIONNEL** : Le changement est trivial et sans risque. Le sprint peut etre livre des que le test visuel sur emulateur confirme le rendu.
