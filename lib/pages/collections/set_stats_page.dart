// Fichier : lib/pages/collections/set_stats_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/scryfall_set_model.dart';
import '../../models/scryfall_card_model.dart';
import '../../models/deck_model.dart';

class SetStatsPage extends StatefulWidget {
  final ScryfallSet targetSet;
  final List<DeckCard> myCollection; // Vos cartes appartenant à ce set
  final List<ScryfallCard> fullSetData; // La liste officielle Scryfall du set

  const SetStatsPage({
    Key? key,
    required this.targetSet,
    required this.myCollection,
    required this.fullSetData,
  }) : super(key: key);

  @override
  State<SetStatsPage> createState() => _SetStatsPageState();
}

class _SetStatsPageState extends State<SetStatsPage> {
  // Indicateurs clés
  int totalSetCards = 0;
  int uniqueOwnedCount = 0;
  int totalOwnedQuantity = 0;
  double completionPercentage = 0.0;
  double estimatedSetValuation = 0.0;

  // Répartition
  int normalCount = 0;
  int foilCount = 0;
  
  // Listes d'analyse
  List<ScryfallCard> missingCards = [];
  List<ScryfallCard> upgradeOpportunities = []; // Cartes possédées en Normal mais pas en Foil

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    // 1. Initialisation
    final fullList = widget.fullSetData;
    // On exclut parfois les tokens ou cartes spéciales si on veut un compte "réel", 
    // mais ici on prend tout ce que l'API renvoie pour ce set.
    totalSetCards = fullList.length; 

    // Création d'une Map pour accès rapide à ma collection : ID -> Quantité/Infos
    Map<String, List<DeckCard>> myCollectionMap = {};
    for (var c in widget.myCollection) {
      if (!myCollectionMap.containsKey(c.scryfallId)) {
        myCollectionMap[c.scryfallId] = [];
      }
      myCollectionMap[c.scryfallId]!.add(c);
    }

    int tempUnique = 0;
    int tempQty = 0;
    int tempNormal = 0;
    int tempFoil = 0;
    double tempValue = 0.0;
    
    List<ScryfallCard> tempMissing = [];
    List<ScryfallCard> tempUpgrades = [];

    // 2. Boucle principale sur le Set Officiel (Source de Vérité)
    for (var scryfallCard in fullList) {
      final myCopies = myCollectionMap[scryfallCard.id];

      // Calcul du prix (pour la valeur possédée et manquante)
      double priceNormal = double.tryParse(scryfallCard.prices['eur'] ?? '0') ?? 0.0;
      double priceFoil = double.tryParse(scryfallCard.prices['eur_foil'] ?? '0') ?? 0.0;

      if (myCopies != null && myCopies.isNotEmpty) {
        // POSSÉDÉ
        tempUnique++;
        
        bool hasFoil = false;
        bool hasNormal = false;

        for (var copy in myCopies) {
          tempQty += copy.quantity;
          if (copy.isFoil) {
            tempFoil += copy.quantity;
            hasFoil = true;
            tempValue += (priceFoil > 0 ? priceFoil : priceNormal) * copy.quantity;
          } else {
            tempNormal += copy.quantity;
            hasNormal = true;
            tempValue += priceNormal * copy.quantity;
          }
        }

        // Détection d'opportunité d'upgrade (J'ai la carte, mais pas en foil)
        // On ne propose l'upgrade que si une version foil existe (prix > 0)
        if (hasNormal && !hasFoil && priceFoil > 0) {
          tempUpgrades.add(scryfallCard);
        }

      } else {
        // MANQUANT
        tempMissing.add(scryfallCard);
      }
    }

    // Tri des listes
    tempMissing.sort((a, b) {
      // Tri par prix décroissant pour voir les plus chères manquantes
      double pA = double.tryParse(a.prices['eur'] ?? '0') ?? 0;
      double pB = double.tryParse(b.prices['eur'] ?? '0') ?? 0;
      return pB.compareTo(pA);
    });

    setState(() {
      uniqueOwnedCount = tempUnique;
      totalOwnedQuantity = tempQty;
      normalCount = tempNormal;
      foilCount = tempFoil;
      estimatedSetValuation = tempValue;
      missingCards = tempMissing;
      upgradeOpportunities = tempUpgrades;
      
      if (totalSetCards > 0) {
        completionPercentage = (uniqueOwnedCount / totalSetCards).clamp(0.0, 1.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.targetSet.name, style: GoogleFonts.cinzel(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Statistiques & Progression", style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 1. BANDEAU RÉSUMÉ ---
            _buildSummaryHeader(),
            const SizedBox(height: 24),

            // --- 2. PROGRESSION ---
            _buildSectionTitle("Avancement"),
            _buildCompletionIndicator(),
            const SizedBox(height: 24),

            // --- 3. GRAPHIQUE FOIL vs NORMAL ---
            _buildSectionTitle("Finitions"),
            Row(
              children: [
                Expanded(child: _buildStatCard("Normal", "$normalCount", Icons.copy, Colors.blueGrey.shade200)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("Foil", "$foilCount", Icons.star, Colors.amber)),
              ],
            ),
            const SizedBox(height: 24),

            // --- 4. OPPORTUNITÉS FOIL ---
            if (upgradeOpportunities.isNotEmpty) ...[
              _buildSectionTitle("Opportunités Foil (${upgradeOpportunities.length})"),
              _buildExpandableList(
                title: "Voir les cartes upgradables",
                cards: upgradeOpportunities,
                icon: Icons.auto_awesome,
                iconColor: Colors.amber,
              ),
              const SizedBox(height: 24),
            ],

            // --- 5. CARTES MANQUANTES (Top 10 Chères) ---
            if (missingCards.isNotEmpty) ...[
              _buildSectionTitle("Manquantes les plus chères"),
              _buildExpandableList(
                title: "Voir le Top 10 manquant",
                cards: missingCards.take(10).toList(),
                icon: Icons.shopping_cart_outlined,
                iconColor: Colors.redAccent,
                showPrice: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          // Icône du Set
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Image.network(
              widget.targetSet.iconSvgUri ?? "",
              width: 40, height: 40,
              color: Colors.white,
              errorBuilder: (_,__,___) => const Icon(Icons.category, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(width: 16),
          // Textes
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$uniqueOwnedCount / $totalSetCards cartes uniques",
                  style: GoogleFonts.cinzel(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "$totalOwnedQuantity cartes au total",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  "Valeur estimée : ${estimatedSetValuation.toStringAsFixed(2)} €",
                  style: GoogleFonts.roboto(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCompletionIndicator() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: completionPercentage,
            minHeight: 20,
            backgroundColor: Colors.white10,
            color: _getProgressColor(completionPercentage),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${(completionPercentage * 100).toStringAsFixed(1)}% Complété",
          style: GoogleFonts.cinzel(color: _getProgressColor(completionPercentage), fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Color _getProgressColor(double pct) {
    if (pct < 0.3) return Colors.redAccent;
    if (pct < 0.7) return Colors.orangeAccent;
    if (pct < 1.0) return Colors.lightGreenAccent;
    return Colors.amberAccent; // 100% Or
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpandableList({
    required String title,
    required List<ScryfallCard> cards,
    required IconData icon,
    required Color iconColor,
    bool showPrice = false,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.cinzel(color: Colors.white)),
          ],
        ),
        iconColor: iconColor,
        collapsedIconColor: Colors.white54,
        children: cards.map((card) {
          final price = card.prices['eur'] ?? '--';
          return ListTile(
            dense: true,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(card.smallImageUrl ?? '', width: 30, errorBuilder: (_,__,___)=>const Icon(Icons.image, size: 20)),
            ),
            title: Text(card.name, style: const TextStyle(color: Colors.white)),
            subtitle: Text("#${card.collectorNumber} • ${card.rarity}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
            trailing: showPrice 
                ? Text("$price €", style: TextStyle(color: Colors.yellow.shade700, fontWeight: FontWeight.bold))
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.cinzel(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold));
  }
}