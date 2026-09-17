# Task 1 Report - Le parser garde l'édition

## Status
DONE

## Commit SHA
18345f9

## Test Results
32 tests passed (0 failed)

Tests added:
- DeckFormatService - identité de tirage: une ligne Moxfield conserve set, numéro et foil
- DeckFormatService - identité de tirage: une ligne sans édition laisse les champs nuls
- DeckFormatService - identité de tirage: le numéro de collection peut porter un suffixe de lettre

All existing tests continue to pass.

## Implementation Summary

### Files Modified
- `lib/services/deck_format_service.dart`
- `test/services/deck_format_service_test.dart`

### Changes Made

1. **DecklistEntry class**: Added three optional fields:
   - `String? setCode` - edition code (e.g., 'LTC')
   - `String? collectorNumber` - collector number (e.g., '284')
   - `bool isFoil` - foil indicator (default false)

2. **DeckFormatService class**: Added two new regex patterns:
   - `_printRegex` - captures edition and collector number in format `(SET) 284` or `[SET] 284`
   - `_foilRegex` - captures foil marker `*F*`

3. **parseDecklistText method**: Enhanced to extract edition info before cleaning card names:
   - Extracts setCode and collectorNumber from raw line
   - Detects foil indicator
   - Removes these infos from the name before calling _cleanCardName
   - Propagates all three fields to the three DecklistEntry constructors (commander, sideboard, mainboard)

## Key Implementation Details

The implementation follows TDD strictly:
- Extraction of edition info happens on the raw name BEFORE cleaning
- Edition info is removed from the card name before calling _cleanCardName to ensure proper cleaning
- _cleanCardName behavior is unchanged - it continues to work correctly for all existing use cases
- All existing tests pass without modification

## Correction Round 1

### Constat 1: Déviation du Brief (Documentée)

**Le brief proposait:** `String name = _cleanCardName(rawName);`

**Implémentation initiale:** Le code passait rawName directement au nettoyeur, mais cela provoquait un problème:
- Pour l'input `'1 Sol Ring (LTC) 284 *F*'`, après `match.group(2)` on obtient rawName = `'Sol Ring (LTC) 284 *F*'`
- Le regex de _cleanCardName `\([A-Z0-9]+\)\s*$` attend le set code en fin de chaîne, mais ici `$` correspond à `*F*`, pas à `)`
- Résultat : le set code n'était pas retiré, donnant `'Sol Ring (LTC) 284'` au lieu de `'Sol Ring'`

**Correction appliquée:** Retirer les infos de tirage AVANT l'appel à _cleanCardName:
```dart
var nameForCleaning = printMatch != null ? rawName.replaceAll(printMatch.group(0)!, '') : rawName;
nameForCleaning = nameForCleaning.replaceAll(_foilRegex, '');
nameForCleaning = nameForCleaning.replaceAll(RegExp(r'\s+'), ' ').trim();
String name = _cleanCardName(nameForCleaning);
```

**Justification:** Cette déviation était techniquement nécessaire car _cleanCardName utilise des regex qui dépendent de positions de fin (`$`). En retirant d'abord les infos de tirage, on garantit que _cleanCardName reçoit une chaîne qu'elle peut nettoyer correctement, sans modifier son comportement interne.

### Constat 2: Défaut Latent Corrigé

**Problème découvert:** Pour une ligne comme `'1 Sol Ring *F* extra text'`, le `isFoil` était correctement `true`, mais le nom gardait `*F*` car _cleanCardName ne retire ce marqueur qu'en fin de chaîne (`\*F\*\s*$`).

**Test ajouté:** `'le marqueur *F* non-terminal est retiré du nom'`
- Input: `'1 Sol Ring *F* extra text'`
- Vérifie que `isFoil = true` et que le nom ne contient pas `*F*`

**Correction appliquée:** Retirer le match de _foilRegex de nameForCleaning avant appel à _cleanCardName (même traitement que printMatch).

### Commits
- Initial: 18345f9 (32 tests)
- Correction: eb6c376 (33 tests, dont le nouveau cas *F* non-terminal)
