// Fichier : lib/controllers/deck_list_controller.dart
// Controller pour DeckListPage - extrait la logique metier de la page.

import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../data/database/app_database.dart';
import '../data/secondary_breakfast.dart';
import '../models/card_print.dart';
import '../models/deck_model.dart';
import '../providers/preferred_language_provider.dart';
import '../providers/service_providers.dart';
import '../utils/price_helper.dart';
import '../services/card_resolver.dart';
import '../services/collection_service.dart';
import '../services/deck_format_service.dart';
import '../services/deck_service.dart';
import '../services/local_card_service.dart';
import '../services/moxfield_deck_client.dart';
import '../services/moxfield_deck_mapper.dart';
import '../services/translation_worker.dart';

// --- RESULT OBJECT pour les actions ---

class DeckListActionResult {
  final bool success;
  final String message;

  const DeckListActionResult({
    this.success = true,
    this.message = '',
  });
}

// --- ETAT IMMUTABLE ---

class DeckListState {
  final List<Deck> decks;
  final List<Deck> filteredDecks;
  final Map<String, double> deckPrices;
  final bool isLoading;
  final bool isImporting;
  final String searchQuery;
  final String selectedFormat;
  final String selectedSort;
  final String? selectedIdentityName;
  final List<String>? selectedIdentityColors;

  const DeckListState({
    this.decks = const [],
    this.filteredDecks = const [],
    this.deckPrices = const {},
    this.isLoading = true,
    this.isImporting = false,
    this.searchQuery = '',
    this.selectedFormat = 'Tous',
    this.selectedSort = 'name',
    this.selectedIdentityName,
    this.selectedIdentityColors,
  });

  DeckListState copyWith({
    List<Deck>? decks,
    List<Deck>? filteredDecks,
    Map<String, double>? deckPrices,
    bool? isLoading,
    bool? isImporting,
    String? searchQuery,
    String? selectedFormat,
    String? selectedSort,
    String? selectedIdentityName,
    List<String>? selectedIdentityColors,
    bool clearIdentity = false,
  }) {
    return DeckListState(
      decks: decks ?? this.decks,
      filteredDecks: filteredDecks ?? this.filteredDecks,
      deckPrices: deckPrices ?? this.deckPrices,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedFormat: selectedFormat ?? this.selectedFormat,
      selectedSort: selectedSort ?? this.selectedSort,
      selectedIdentityName: clearIdentity ? null : (selectedIdentityName ?? this.selectedIdentityName),
      selectedIdentityColors: clearIdentity ? null : (selectedIdentityColors ?? this.selectedIdentityColors),
    );
  }
}

// --- CONTROLLER (StateNotifier) ---

class DeckListController extends StateNotifier<DeckListState> {
  final DeckService _deckService;
  final LocalCardService _localCardService;
  final CollectionService _collectionService;

  /// Vide la file de traduction apres un import. Sans ce declencheur, un
  /// utilisateur qui importe un deck accumule N taches qui ne partiront
  /// jamais : le seul autre appelant de `drain` est le bouton de langue du
  /// glossaire, que rien n'oblige a visiter.
  final TranslationWorker _translationWorker;

  /// Resolution par identifiant exact pour l'import Moxfield : chaque ligne
  /// porte deja son scryfall_id, donc aucune heuristique par nom n'est
  /// necessaire (contrairement a [importDeck], qui ne connait le tirage
  /// exact que si la ligne l'a precise).
  final CardResolver _cardResolver;

  /// Client de recuperation d'un deck Moxfield par URL.
  final MoxfieldDeckClient _moxfieldClient;

  /// Acces direct a la base pour enfiler les traductions manquantes des
  /// tirages resolus par [importDeckFromMoxfieldUrl] -- [_cardResolver]
  /// (contrairement a [CollectionService.resolveImportedEntries], utilise
  /// par [importDeck]) n'enfile rien lui-meme.
  final AppDatabase _db;

  static const Map<String, Map<String, List<String>>> colorFamilies = {
    'Mono': {
      'Blanc': ['W'], 'Bleu': ['U'], 'Noir': ['B'], 'Rouge': ['R'], 'Vert': ['G'], 'Incolore': []
    },
    'Guilde (2)': {
      'Azorius': ['W', 'U'], 'Dimir': ['U', 'B'], 'Rakdos': ['B', 'R'], 'Gruul': ['R', 'G'], 'Selesnya': ['G', 'W'],
      'Orzhov': ['W', 'B'], 'Izzet': ['U', 'R'], 'Golgari': ['B', 'G'], 'Boros': ['R', 'W'], 'Simic': ['G', 'U']
    },
    'Trio (3)': {
      'Esper': ['W', 'U', 'B'], 'Grixis': ['U', 'B', 'R'], 'Jund': ['B', 'R', 'G'], 'Naya': ['R', 'G', 'W'], 'Bant': ['G', 'W', 'U'],
      'Abzan': ['W', 'B', 'G'], 'Jeskai': ['U', 'R', 'W'], 'Sultai': ['B', 'G', 'U'], 'Mardu': ['R', 'W', 'B'], 'Temur': ['G', 'U', 'R']
    },
    'Nephilim (4)': {
      'Yore-Tiller': ['W', 'U', 'B', 'R'], 'Glint-Eye': ['U', 'B', 'R', 'G'], 'Dune-Brood': ['B', 'R', 'G', 'W'],
      'Ink-Treader': ['R', 'G', 'W', 'U'], 'Witch-Maw': ['G', 'W', 'U', 'B']
    },
    'WUBRG (5)': {
      '5 Couleurs': ['W', 'U', 'B', 'R', 'G']
    }
  };

  DeckListController({
    required DeckService deckService,
    required LocalCardService localCardService,
    required CollectionService collectionService,
    required TranslationWorker translationWorker,
    required CardResolver cardResolver,
    required MoxfieldDeckClient moxfieldClient,
    required AppDatabase db,
  })  : _deckService = deckService,
        _localCardService = localCardService,
        _collectionService = collectionService,
        _translationWorker = translationWorker,
        _cardResolver = cardResolver,
        _moxfieldClient = moxfieldClient,
        _db = db,
        super(const DeckListState()) {
    loadDecks();
  }

  // --- CHARGEMENT ---

  Future<void> loadDecks() async {
    state = state.copyWith(isLoading: true);
    await _localCardService.loadLocalData();
    final decks = await _deckService.loadDecks();

    // Calcul des prix
    final Map<String, double> prices = {};
    for (var deck in decks) {
      double total = 0.0;
      for (var card in deck.mainboard) {
        final localCard = _localCardService.getCardById(card.scryfallId);
        if (localCard != null) {
          double price = PriceHelper.bestPrice(localCard.prices);
          total += price * card.quantity;
        }
      }
      prices[deck.id] = total;
    }

    state = state.copyWith(decks: decks, deckPrices: prices, isLoading: false);
    _applyFilters();
  }

  // --- FILTRES ---

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void updateFormat(String format) {
    state = state.copyWith(selectedFormat: format);
    _applyFilters();
  }

  void updateSort(String sortCode) {
    state = state.copyWith(selectedSort: sortCode);
    _applyFilters();
  }

  void updateIdentityFilter(String name, List<String> colors) {
    state = state.copyWith(selectedIdentityName: name, selectedIdentityColors: colors);
    _applyFilters();
  }

  void clearIdentityFilter() {
    state = state.copyWith(clearIdentity: true);
    _applyFilters();
  }

  void _applyFilters() {
    final query = state.searchQuery.toLowerCase();

    var tempDecks = state.decks.where((deck) {
      if (!deck.name.toLowerCase().contains(query)) return false;

      final bool isCommander = deck.commanderScryfallId != null;
      if (state.selectedFormat == 'Commander' && !isCommander) return false;
      if (state.selectedFormat == 'Standard' && isCommander) return false;

      if (state.selectedIdentityColors != null) {
        if (state.selectedIdentityColors!.isEmpty) {
          if (deck.colors.isNotEmpty) return false;
        } else {
          final deckSet = deck.colors.toSet();
          final filterSet = state.selectedIdentityColors!.toSet();
          if (deckSet.length != filterSet.length || !deckSet.containsAll(filterSet)) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    tempDecks.sort((a, b) {
      if (state.selectedSort == 'price_desc') {
        return (state.deckPrices[b.id] ?? 0).compareTo(state.deckPrices[a.id] ?? 0);
      } else if (state.selectedSort == 'price_asc') {
        return (state.deckPrices[a.id] ?? 0).compareTo(state.deckPrices[b.id] ?? 0);
      }
      return a.name.compareTo(b.name);
    });

    state = state.copyWith(filteredDecks: tempDecks);
  }

  // --- ACTIONS ---

  Future<void> deleteDeck(String deckId) async {
    await _deckService.deleteDeck(deckId);
    await loadDecks();
  }

  Future<void> createNewDeck(String name) async {
    if (name.isEmpty) return;
    await _deckService.createNewDeck(name);
    await loadDecks();
  }

  /// Resolves the easter egg check and returns the actual name/list to import.
  /// Returns (deckName, decklistText) after easter egg resolution.
  (String, String) resolveEasterEgg(String deckName, String decklistText) {
    if (deckName.toLowerCase() == 'second petit déjeuner') {
      return ('Nourriture et communauté', secondBreakfastDecklist);
    }
    return (deckName, decklistText);
  }

  /// Importe une decklist (texte ou CSV) en deck.
  ///
  /// Le decoupage en lignes/sections passe par [DeckFormatService] (TXT et
  /// CSV, Commander/Sideboard/Considering...) : plus de parser en doublon ici.
  /// La resolution passe par [CollectionService.resolveImportedEntries], donc
  /// par [CardResolver] : chaque carte est identifiee par son edition exacte
  /// (set + numero) quand la ligne la precise, et non par une recherche floue
  /// par nom qui rend une impression arbitraire. Aucun plafond arbitraire
  /// n'est applique : `resolveEditions` decoupe deja en lots en interne.
  ///
  /// Un import partiel n'est jamais silencieux : le message rendu a
  /// l'utilisateur nomme le nombre de cartes non identifiees.
  Future<DeckListActionResult> importDeck(String deckName, String decklistText) async {
    state = state.copyWith(isImporting: true, isLoading: true);

    final parseResult = DeckFormatService.autoDetectAndParse(decklistText);
    final List<DecklistEntry> allEntries = [
      ...parseResult.mainboard,
      ...parseResult.sideboard,
    ];

    EditionResolution resolution = const EditionResolution();
    final Map<String, List<ResolvedPrint>> printsByKey = {};

    if (allEntries.isNotEmpty) {
      final preferredLang = await readPreferredLanguage();

      resolution = await _collectionService.resolveImportedEntries(
        allEntries,
        preferredLang: preferredLang,
      );

      for (final print in resolution.resolved) {
        printsByKey.putIfAbsent(_printKey(print.name), () => []).add(print);
      }
    }

    // Couleur d'identite : accumulee au fil de la resolution de chaque
    // DeckCard ci-dessous, depuis le ResolvedPrint effectivement attribue --
    // il porte l'identite de couleur du tirage reellement resolu par
    // Scryfall, gratuite dans la reponse batch. LocalCardService ne sert
    // plus que de filet pour les cartes non resolues (notFound/failed) : le
    // bulk local (oracle-cards.json) est fige a la date de build de l'app et
    // ignorerait silencieusement toute carte plus recente.
    final Set<String> deckColors = {};

    DeckCard toDeckCard(DecklistEntry entry) {
      final print = _consumePrint(printsByKey, entry);
      if (print != null) {
        deckColors.addAll(print.colorIdentity);
        return DeckCard(
          scryfallId: print.scryfallId,
          name: entry.name,
          quantity: entry.quantity,
          isFoil: entry.isFoil,
        );
      }
      final local = _localCardService.getCardByName(entry.name);
      if (local != null) deckColors.addAll(local.colorIdentity);
      return DeckCard(
        scryfallId: 'LOCAL:${entry.name}',
        name: entry.name,
        quantity: entry.quantity,
        isFoil: entry.isFoil,
      );
    }

    // Le deck est retrouve par son IDENTIFIANT, jamais par son nom : deux
    // decks peuvent porter le meme nom, et `updateDeck` ci-dessous vide les
    // cartes du deck qu'il recoit avant de les reinserer -- viser un homonyme
    // detruirait un deck existant.
    final newDeckId = await _deckService.createNewDeck(deckName);
    final decks = await _deckService.loadDecks();
    Deck newDeck = decks.firstWhere((d) => d.id == newDeckId);
    newDeck.format = parseResult.commanderName != null ? 'Commander' : 'Standard';
    newDeck.mainboard = parseResult.mainboard.map(toDeckCard).toList();
    newDeck.sideboard = parseResult.sideboard.map(toDeckCard).toList();
    newDeck.colors = _sortedColorIdentity(deckColors);

    if (parseResult.commanderName != null) {
      final commanderCard = newDeck.mainboard
          .where((c) => c.name == parseResult.commanderName)
          .firstOrNull;
      newDeck.commanderScryfallId =
          commanderCard?.scryfallId ?? 'LOCAL:${parseResult.commanderName}';
    }

    await _deckService.updateDeck(newDeck);
    state = state.copyWith(isImporting: false, isLoading: false);
    await loadDecks();

    // Temps 2 : les traductions enfilees par la resolution ci-dessus partent
    // maintenant, sans etre attendues -- l'import a deja rendu la main et la
    // liste est deja a l'ecran. Sans ce declencheur, la file d'un import
    // restait pleine jusqu'a un hypothetique passage par le glossaire.
    unawaited(_translationWorker.drain());

    final unresolved = resolution.notFound.length + resolution.failed.length;
    final message = resolution.isComplete
        ? 'Deck importé avec succès.'
        : 'Deck importé : $unresolved carte(s) sur ${allEntries.length} n\'ont pas '
            'pu être identifiées.';

    return DeckListActionResult(success: resolution.isComplete, message: message);
  }

  /// Importe un deck depuis une URL Moxfield.
  ///
  /// Chaque carte porte son scryfall_id : la resolution se fait par
  /// identifiant exact, sans heuristique d'appariement par nom -- a la
  /// difference d'[importDeck], qui ne connait le tirage exact que si la
  /// ligne texte le precisait.
  ///
  /// Une URL non reconnue rend l'echec immediatement, avant tout appel
  /// reseau (ni Moxfield, ni Scryfall) : [extractPublicId] est pure et
  /// s'evalue avant que [state] ne bascule en import.
  Future<DeckListActionResult> importDeckFromMoxfieldUrl(String url) async {
    final publicId = extractPublicId(url);
    if (publicId == null) {
      return const DeckListActionResult(
        success: false,
        message: 'URL Moxfield non reconnue. Attendu : moxfield.com/decks/…',
      );
    }

    state = state.copyWith(isImporting: true, isLoading: true);
    try {
      final json = await _moxfieldClient.fetchDeck(publicId);
      final data = MoxfieldDeckMapper.fromJson(json);

      // Le commandant (et son eventuel partenaire) sont decrits par
      // Moxfield dans un board "commanders" distinct de `data.lines` : sans
      // les requeter eux aussi, leur identite de couleur serait absente du
      // tri WUBRG ci-dessous, et ils ne pourraient pas rejoindre le
      // mainboard s'ils n'y figurent pas deja.
      final lineIds = data.lines.map((l) => l.scryfallId).toSet();
      // TOUS les commandants, meme ceux qui figurent deja dans un board :
      // filtrer ici sur `lineIds` (qui couvre mainboard ET sideboard ET
      // considering) laisserait hors du mainboard un commandant present au
      // seul sideboard. La garde anti-duplication porte plus bas sur le seul
      // mainboard ; `lineIds` ne sert qu'a ne pas requeter deux fois le meme
      // identifiant.
      final commanderIds = [data.commanderScryfallId, data.partnerScryfallId]
          .whereType<String>()
          .toSet();

      final requetes = [
        for (final l in data.lines) PrintRequest(name: l.name, scryfallId: l.scryfallId),
        for (final id in commanderIds)
          if (!lineIds.contains(id)) PrintRequest(name: id, scryfallId: id),
      ];
      final resolution = await _cardResolver.resolveEditions(requetes);

      // Index des tirages resolus par scryfallId : la resolution etant
      // faite par identifiant exact, la correspondance est directe et sans
      // ambiguite -- contrairement a importDeck, aucune cle par nom n'est
      // necessaire.
      final parId = {for (final p in resolution.resolved) p.scryfallId: p};

      DeckCard toDeckCard(MoxfieldCardLine l) => DeckCard(
            scryfallId: parId[l.scryfallId]?.scryfallId ?? 'LOCAL:${l.name}',
            name: l.name,
            quantity: l.quantity,
            proxyQuantity: l.isProxy ? l.quantity : 0,
            isFoil: l.isFoil,
          );

      // Par identifiant, jamais par nom : le nom vient de Moxfield et
      // l'utilisateur ne le choisit pas. Importer deux fois le meme deck, ou
      // un deck homonyme d'un deck local, viderait sinon le deck le plus
      // ancien de ce nom (`updateDeck` fait clearDeckCards puis reinsere).
      final newDeckId = await _deckService.createNewDeck(data.name);
      final decks = await _deckService.loadDecks();
      final newDeck = decks.firstWhere((d) => d.id == newDeckId);

      newDeck.format = data.format;
      newDeck.mainboard =
          data.lines.where((l) => l.board == 'mainboard').map(toDeckCard).toList();
      newDeck.sideboard =
          data.lines.where((l) => l.board == 'sideboard').map(toDeckCard).toList();
      newDeck.considering =
          data.lines.where((l) => l.board == 'considering').map(toDeckCard).toList();
      newDeck.commanderScryfallId = data.commanderScryfallId;
      newDeck.commanderSecondaryScryfallId = data.partnerScryfallId;

      // Le commandant doit figurer dans le mainboard s'il n'y est pas deja,
      // comme c'est toujours le cas pour importDeck (dont le parser texte
      // range d'emblee la ligne "Commander" dans le mainboard). Moxfield ne
      // duplique pas cette ligne : sans cet ajout explicite, un deck
      // Commander importe par URL n'aurait pas son commandant au mainboard.
      for (final id in commanderIds) {
        if (newDeck.mainboard.any((c) => c.scryfallId == id)) continue;
        final print = parId[id];
        final name = print?.displayName ?? id;
        newDeck.mainboard.add(DeckCard(
          scryfallId: print != null ? id : 'LOCAL:$name',
          name: name,
          quantity: 1,
        ));
      }

      newDeck.colors =
          _sortedColorIdentity(resolution.resolved.expand((p) => p.colorIdentity));

      await _deckService.updateDeck(newDeck);

      // A la difference de CollectionService.resolveImportedEntries (utilise
      // par importDeck), CardResolver.resolveEditions n'enfile aucune
      // traduction lui-meme : sans cette boucle, `drain()` ci-dessous videra
      // une file vide, et un deck importe par URL resterait dans sa langue
      // d'origine indefiniment, meme si l'utilisateur a choisi une langue
      // preferee differente.
      final preferredLang = await readPreferredLanguage();
      for (final print in resolution.resolved) {
        if (print.lang == preferredLang) continue;
        await _db.enqueueTranslation(
          scryfallId: print.scryfallId,
          setCode: print.setCode,
          collectorNumber: print.collectorNumber,
          lang: preferredLang,
        );
      }

      // Les traductions enfilees ci-dessus partent sans etre attendues,
      // exactement comme dans importDeck.
      unawaited(_translationWorker.drain());

      final unresolved = requetes.length - resolution.resolved.length;
      return DeckListActionResult(
        success: resolution.isComplete,
        message: resolution.isComplete
            ? 'Deck « ${data.name} » importé depuis Moxfield.'
            // Le deck EST cree, meme quand des cartes manquent : le dire
            // evite que l'utilisateur ne reimporte en croyant que rien n'a
            // ete fait (le chemin texte le disait deja, pas celui-ci).
            : 'Deck « ${data.name} » créé : $unresolved carte(s) sur '
                '${requetes.length} n\'ont pas pu être identifiées.',
      );
    } on MoxfieldException catch (e) {
      return DeckListActionResult(success: false, message: e.message);
    } finally {
      state = state.copyWith(isImporting: false, isLoading: false);
      await loadDecks();
    }
  }

  // --- HELPERS ---

  /// Cle d'association entre un [DecklistEntry] et le [ResolvedPrint] qui lui
  /// correspond. Par nom, pas par set+numero : un [ResolvedPrint] porte
  /// toujours une edition concrete (celle que Scryfall a rendue), meme quand
  /// la ligne d'origine n'en precisait aucune -- cle par set+numero cote
  /// tirage et par nom cote entree ne matcheraient alors jamais. Le nom, lui,
  /// est stable entre les deux cotes (Scryfall rend le nom demande a
  /// l'identique, que la requete ait ete faite par nom ou par edition).
  ///
  /// Deux entrees de meme nom (rare : editions distinctes de la meme carte
  /// sur deux lignes) partagent alors la meme cle et se voient attribuer un
  /// tirage chacune par consommation FIFO -- pas necessairement celui
  /// demande par chacune. C'est le meme compromis, deja assume et documente,
  /// que celui de `CardResolver._identifierMatches`/`_consumeMatch` : non
  /// corrige ici, non plus.
  ///
  /// Seule la face avant entre dans la cle : `DeckFormatService._cleanCardName`
  /// coupe les noms sur `//` (la ligne "1 Fire // Ice" devient l'entree
  /// `Fire`), alors que Scryfall rend le nom complet `Fire // Ice`. Comparer
  /// les deux tels quels ne matcherait JAMAIS pour une carte recto-verso ou
  /// split : le tirage resolu etait jete, la carte retombait sur l'identifiant
  /// local `LOCAL:<nom>` -- et `isComplete` restait vrai, donc l'utilisateur
  /// n'etait prevenu de rien. Normaliser les deux cotes de la meme facon
  /// (face avant, espaces retires, minuscules) referme ce trou.
  String _printKey(String name) => name.split('//').first.trim().toLowerCase();

  /// Trie une identite de couleur dans l'ordre WUBRG (Blanc, Bleu, Noir,
  /// Rouge, Vert), toute couleur inconnue placee en queue. Partagee entre
  /// [importDeck] (couleurs accumulees carte par carte au fil de la
  /// resolution) et [importDeckFromMoxfieldUrl] (couleurs derivees des
  /// tirages resolus, chacun portant deja la sienne).
  List<String> _sortedColorIdentity(Iterable<String> colors) {
    const order = {'W': 0, 'U': 1, 'B': 2, 'R': 3, 'G': 4, 'C': 5};
    return colors.toSet().toList()
      ..sort((a, b) => (order[a] ?? 9).compareTo(order[b] ?? 9));
  }

  /// Consomme, dans [printsByKey], le tirage resolu correspondant a [entry].
  /// Rend `null` sans correspondance (carte non resolue : `notFound`,
  /// `failed`, ou file deja epuisee pour ce nom) -- l'appelant retombe alors
  /// sur le sentinel `LOCAL:<nom>`, le meme que le reste de l'app utilise
  /// deja pour signaler une carte sans identite Scryfall connue (voir
  /// `legality_service.dart`, `deck_stats_controller.dart`...).
  ResolvedPrint? _consumePrint(
    Map<String, List<ResolvedPrint>> printsByKey,
    DecklistEntry entry,
  ) {
    final bucket = printsByKey[_printKey(entry.name)];
    if (bucket != null && bucket.isNotEmpty) {
      return bucket.removeAt(0);
    }
    return null;
  }

  String getSortLabel(String code) {
    switch(code) {
      case 'price_desc': return 'Prix (Décroissant)';
      case 'price_asc': return 'Prix (Croissant)';
      default: return 'Nom (A-Z)';
    }
  }

  double getDeckPrice(String deckId) => state.deckPrices[deckId] ?? 0.0;
}

// --- PROVIDER ---

final deckListControllerProvider = StateNotifierProvider.autoDispose<DeckListController, DeckListState>(
  (ref) {
    final deckService = ref.watch(deckServiceProvider);
    final localCardService = ref.watch(localCardServiceProvider);
    final collectionService = ref.watch(collectionServiceProvider);
    final translationWorker = ref.watch(translationWorkerProvider);
    final cardResolver = ref.watch(cardResolverProvider);
    final moxfieldClient = ref.watch(moxfieldDeckClientProvider);
    final db = ref.watch(appDatabaseProvider);

    return DeckListController(
      deckService: deckService,
      localCardService: localCardService,
      collectionService: collectionService,
      translationWorker: translationWorker,
      cardResolver: cardResolver,
      moxfieldClient: moxfieldClient,
      db: db,
    );
  },
);
