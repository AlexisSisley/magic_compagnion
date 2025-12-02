// Fichier : lib/pages/tournaments/tournament_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- MODÈLES ---

class TournamentPlayer {
  String id;
  String name;
  TournamentPlayer({required this.id, required this.name});

  bool get isBye => name == "BYE";

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(id: json['id'], name: json['name']);
  }
}

class TournamentMatch {
  final String id; 
  final String roundName;
  final int roundIndex;
  
  TournamentPlayer? player1;
  TournamentPlayer? player2;
  
  int score1;
  int score2;
  
  bool isBo3;
  bool isLoserBracket;
  
  TournamentMatch? nextMatchWin;
  TournamentMatch? nextMatchLose;
  
  int? nextSlotWin; 
  int? nextSlotLose;

  TournamentMatch({
    required this.id,
    required this.roundName,
    required this.roundIndex,
    this.isBo3 = false,
    this.isLoserBracket = false,
    this.player1,
    this.player2,
    this.score1 = 0,
    this.score2 = 0,
  });

  bool get isFinished {
    if (isBo3) return score1 == 2 || score2 == 2;
    return score1 == 1 || score2 == 1; 
  }

  TournamentPlayer? get winner {
    if (!isFinished) return null;
    return score1 > score2 ? player1 : player2;
  }

  TournamentPlayer? get loser {
    if (!isFinished) return null;
    return score1 > score2 ? player2 : player1;
  }
}

// --- PAGE ---

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key});

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> with SingleTickerProviderStateMixin {
  int _status = 0; 
  
  List<TournamentPlayer> _players = [];
  final TextEditingController _nameController = TextEditingController();
  
  List<TournamentMatch> _winnerBracket = [];
  List<TournamentMatch> _loserBracket = [];
  
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- PERSISTANCE ---

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tournament_status', _status);
    final String playersJson = json.encode(_players.map((p) => p.toJson()).toList());
    await prefs.setString('tournament_players', playersJson);

    if (_status == 1) {
      final allMatches = [..._winnerBracket, ..._loserBracket];
      final Map<String, dynamic> matchesState = {};
      for (var match in allMatches) {
        matchesState[match.id] = {
          'p1': match.player1?.id,
          'p2': match.player2?.id,
          's1': match.score1,
          's2': match.score2,
        };
      }
      await prefs.setString('tournament_matches', json.encode(matchesState));
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _status = prefs.getInt('tournament_status') ?? 0;
      final String? playersJson = prefs.getString('tournament_players');
      if (playersJson != null) {
        final List<dynamic> decoded = json.decode(playersJson);
        _players = decoded.map((j) => TournamentPlayer.fromJson(j)).toList();
      }

      if (_status == 1) {
        if (_players.length <= 4) _init4PlayersBracket();
        else _init8PlayersBracket();

        final String? matchesJson = prefs.getString('tournament_matches');
        if (matchesJson != null) {
          final Map<String, dynamic> matchesState = json.decode(matchesJson);
          final allMatches = [..._winnerBracket, ..._loserBracket];

          for (var match in allMatches) {
            if (matchesState.containsKey(match.id)) {
              final state = matchesState[match.id];
              if (state['p1'] != null) {
                match.player1 = _players.firstWhere((p) => p.id == state['p1'], orElse: () => TournamentPlayer(id: '?', name: '?'));
              }
              if (state['p2'] != null) {
                match.player2 = _players.firstWhere((p) => p.id == state['p2'], orElse: () => TournamentPlayer(id: '?', name: '?'));
              }
              match.score1 = state['s1'] ?? 0;
              match.score2 = state['s2'] ?? 0;
            }
          }
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tournament_status');
    await prefs.remove('tournament_players');
    await prefs.remove('tournament_matches');
  }

  // --- LOGIQUE METIER ---

  void _addPlayer() {
    if (_nameController.text.trim().isEmpty) return;
    if (_players.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 8 joueurs.")));
      return;
    }
    setState(() {
      _players.add(TournamentPlayer(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim()
      ));
      _nameController.clear();
    });
    _saveState();
  }

  void _startTournament() {
    if (_players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Il faut au moins 2 joueurs.")));
      return;
    }

    int targetSize = _players.length <= 4 ? 4 : 8;
    int byesNeeded = targetSize - _players.length;

    for (int i = 0; i < byesNeeded; i++) {
      _players.add(TournamentPlayer(id: "bye_$i", name: "BYE"));
    }
    
    _players.shuffle();
    
    setState(() {
      if (targetSize == 4) _init4PlayersBracket();
      else _init8PlayersBracket();
      _status = 1;
    });

    _autoResolveByes();
    _saveState();
  }

  void _autoResolveByes() {
    List<TournamentMatch> firstRoundMatches = _winnerBracket.where((m) => m.roundIndex == 0).toList();
    
    for (var match in firstRoundMatches) {
      if (match.player1 != null && match.player2 != null) {
        if (match.player2!.isBye && !match.player1!.isBye) {
          _updateScore(match, 1, auto: true); 
          if (match.isBo3) _updateScore(match, 1, auto: true);
        } else if (match.player1!.isBye && !match.player2!.isBye) {
          _updateScore(match, 2, auto: true);
          if (match.isBo3) _updateScore(match, 2, auto: true);
        } else if (match.player1!.isBye && match.player2!.isBye) {
          _updateScore(match, 1, auto: true);
          if (match.isBo3) _updateScore(match, 1, auto: true);
        }
      }
    }
  }

  void _init4PlayersBracket() {
    var wFinal = TournamentMatch(id: 'w_final', roundName: 'Finale', roundIndex: 1, isBo3: true);
    var wSemi1 = TournamentMatch(id: 'w_semi1', roundName: 'Demi', roundIndex: 0, isBo3: true, player1: _players[0], player2: _players[1]);
    var wSemi2 = TournamentMatch(id: 'w_semi2', roundName: 'Demi', roundIndex: 0, isBo3: true, player1: _players[2], player2: _players[3]);

    _linkWin(wSemi1, wFinal, 1);
    _linkWin(wSemi2, wFinal, 2);

    var lFinal = TournamentMatch(id: 'l_final', roundName: 'Petite Finale', roundIndex: 1, isLoserBracket: true, isBo3: true);
    var lRound1 = TournamentMatch(id: 'l_r1', roundName: 'Repêchage', roundIndex: 0, isLoserBracket: true);

    _linkLose(wSemi1, lRound1, 1);
    _linkLose(wSemi2, lRound1, 2);
    _linkWin(lRound1, lFinal, 2);
    _linkLose(wFinal, lFinal, 1);

    _winnerBracket = [wSemi1, wSemi2, wFinal];
    _loserBracket = [lRound1, lFinal];
  }

  void _init8PlayersBracket() {
    var wFinal = TournamentMatch(id: 'w_final', roundName: 'Finale', roundIndex: 2, isBo3: true);
    var wSemi1 = TournamentMatch(id: 'w_semi1', roundName: 'Demi', roundIndex: 1, isBo3: true);
    var wSemi2 = TournamentMatch(id: 'w_semi2', roundName: 'Demi', roundIndex: 1, isBo3: true);
    
    var wQ1 = TournamentMatch(id: 'w_q1', roundName: 'Quart', roundIndex: 0, player1: _players[0], player2: _players[1]);
    var wQ2 = TournamentMatch(id: 'w_q2', roundName: 'Quart', roundIndex: 0, player1: _players[2], player2: _players[3]);
    var wQ3 = TournamentMatch(id: 'w_q3', roundName: 'Quart', roundIndex: 0, player1: _players[4], player2: _players[5]);
    var wQ4 = TournamentMatch(id: 'w_q4', roundName: 'Quart', roundIndex: 0, player1: _players[6], player2: _players[7]);

    _linkWin(wQ1, wSemi1, 1); _linkWin(wQ2, wSemi1, 2);
    _linkWin(wQ3, wSemi2, 1); _linkWin(wQ4, wSemi2, 2);
    _linkWin(wSemi1, wFinal, 1); _linkWin(wSemi2, wFinal, 2);

    var lFinal = TournamentMatch(id: 'l_final', roundName: 'Finale Loser', roundIndex: 3, isLoserBracket: true, isBo3: true);
    var lSemi1 = TournamentMatch(id: 'l_semi1', roundName: 'Demi Loser', roundIndex: 2, isLoserBracket: true);
    var lSemi2 = TournamentMatch(id: 'l_semi2', roundName: 'Demi Loser', roundIndex: 2, isLoserBracket: true);
    var lQ1 = TournamentMatch(id: 'l_q1', roundName: 'Repêchage 1', roundIndex: 0, isLoserBracket: true);
    var lQ2 = TournamentMatch(id: 'l_q2', roundName: 'Repêchage 2', roundIndex: 0, isLoserBracket: true);

    _linkLose(wQ1, lQ1, 1); _linkLose(wQ2, lQ1, 2);
    _linkLose(wQ3, lQ2, 1); _linkLose(wQ4, lQ2, 2);

    _linkWin(lQ1, lSemi1, 2); _linkLose(wSemi1, lSemi1, 1);
    _linkWin(lQ2, lSemi2, 2); _linkLose(wSemi2, lSemi2, 1);

    _linkWin(lSemi1, lFinal, 1); _linkWin(lSemi2, lFinal, 2);

    _winnerBracket = [wQ1, wQ2, wQ3, wQ4, wSemi1, wSemi2, wFinal];
    _loserBracket = [lQ1, lQ2, lSemi1, lSemi2, lFinal];
  }

  void _linkWin(TournamentMatch src, TournamentMatch dest, int slot) {
    src.nextMatchWin = dest;
    src.nextSlotWin = slot;
  }
  
  void _linkLose(TournamentMatch src, TournamentMatch dest, int slot) {
    src.nextMatchLose = dest;
    src.nextSlotLose = slot;
  }

  // --- MISE À JOUR DU SCORE (CORRIGÉE) ---

  void _updateScore(TournamentMatch match, int playerSlot, {int delta = 1, bool auto = false}) {
    // Si on veut AJOUTER et que c'est fini, on bloque.
    // MAIS si on veut RETIRER (delta < 0), on autorise même si c'est fini (pour corriger).
    if (delta > 0 && match.isFinished) return;

    void update() {
      if (playerSlot == 1) {
        match.score1 = (match.score1 + delta).clamp(0, 99);
      } else {
        match.score2 = (match.score2 + delta).clamp(0, 99);
      }

      if (match.isFinished) {
        _propagateResult(match);
      } else {
        // Si le match n'est PLUS fini (on a retiré le point de la victoire),
        // on doit annuler la propagation (retirer le joueur du match suivant).
        _clearPropagation(match);
      }
    }

    if (auto) {
      update();
    } else {
      setState(update);
      _saveState();
    }
  }

  void _propagateResult(TournamentMatch match) {
    if (match.nextMatchWin != null && match.winner != null) {
      if (match.nextSlotWin == 1) match.nextMatchWin!.player1 = match.winner;
      else match.nextMatchWin!.player2 = match.winner;
    }
    if (match.nextMatchLose != null && match.loser != null) {
      if (match.nextSlotLose == 1) match.nextMatchLose!.player1 = match.loser;
      else match.nextMatchLose!.player2 = match.loser;
    }
  }

  // Nouvelle méthode pour nettoyer l'arbre en cas de correction
  void _clearPropagation(TournamentMatch match) {
    if (match.nextMatchWin != null) {
      if (match.nextSlotWin == 1) match.nextMatchWin!.player1 = null;
      else match.nextMatchWin!.player2 = null;
    }
    if (match.nextMatchLose != null) {
      if (match.nextSlotLose == 1) match.nextMatchLose!.player1 = null;
      else match.nextMatchLose!.player2 = null;
    }
  }

  void _resetMatch(TournamentMatch match) {
    setState(() {
      match.score1 = 0;
      match.score2 = 0;
      _clearPropagation(match); // On nettoie aussi la suite
    });
    _saveState();
  }

  void _hardReset() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Nouveau Tournoi ?", style: GoogleFonts.cinzel(color: Colors.white)),
        content: const Text("Cela effacera l'arbre actuel.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(c), child: const Text("Non")),
          TextButton(onPressed: () {
            Navigator.pop(c);
            _clearState();
            setState(() {
              _status = 0;
              _players.clear();
              _winnerBracket.clear();
              _loserBracket.clear();
            });
          }, child: const Text("Oui", style: TextStyle(color: Colors.red))),
        ],
      )
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF1A1A1A), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Arbre de Tournoi", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [
          if (_status != 0) IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: _hardReset),
        ],
        bottom: _status == 1 ? TabBar(
          controller: _tabController,
          indicatorColor: Colors.yellow.shade800,
          labelColor: Colors.yellow.shade800,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Winner Bracket", icon: Icon(Icons.emoji_events)),
            Tab(text: "Loser Bracket", icon: Icon(Icons.heart_broken)),
          ],
        ) : null,
      ),
      body: SafeArea(
        child: _status == 0 ? _buildRegistration() : _buildBracketTabs(),
      ),
    );
  }

  Widget _buildRegistration() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Inscriptions (2 à 8)", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Nom du joueur...",
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true, fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _addPlayer(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: _addPlayer)
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _players.length,
              itemBuilder: (ctx, i) => Card(
                color: Colors.white.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blueGrey, child: Text("${i+1}")),
                  title: Text(_players[i].name, style: GoogleFonts.cinzel(color: Colors.white)),
                  trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () {
                    setState(() => _players.removeAt(i));
                    _saveState();
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _players.length < 2 
                ? "Ajoutez au moins 2 joueurs."
                : (_players.length == 4 || _players.length == 8 
                    ? "Prêt à lancer !" 
                    : "Sera complété par des 'BYE' jusqu'à ${_players.length <= 4 ? 4 : 8}."),
            style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: (_players.length >= 2) ? _startTournament : null,
            icon: const Icon(Icons.play_arrow),
            label: Text("Générer l'Arbre", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade800,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: Colors.grey.shade800,
              disabledForegroundColor: Colors.white24
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBracketTabs() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTreeCanvas(_winnerBracket),
        _buildTreeCanvas(_loserBracket),
      ],
    );
  }

  Widget _buildTreeCanvas(List<TournamentMatch> matches) {
    if (matches.isEmpty) return const Center(child: Text("Pas de matchs.", style: TextStyle(color: Colors.white54)));

    Map<int, List<TournamentMatch>> rounds = {};
    for (var m in matches) {
      rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    }
    
    final sortedKeys = rounds.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: sortedKeys.map((roundIdx) {
          final roundMatches = rounds[roundIdx]!;
          return Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: roundMatches.map((m) => _buildMatchCard(m)).toList(),
              ),
              if (roundIdx != sortedKeys.last)
                Container(width: 20, height: 2, color: Colors.white24),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMatchCard(TournamentMatch match) {
    final bool p1Win = match.isFinished && match.score1 > match.score2;
    final bool p2Win = match.isFinished && match.score2 > match.score1;
    
    final bool isGhost = (match.player1?.isBye ?? false) && (match.player2?.isBye ?? false);
    final Color cardColor = isGhost ? Colors.white.withOpacity(0.05) : Colors.black;

    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: match.isFinished ? (isGhost ? Colors.white10 : Colors.green.shade800) : Colors.white24),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            width: double.infinity,
            decoration: BoxDecoration(
              color: match.isBo3 ? Colors.purple.shade900.withOpacity(0.5) : Colors.white10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8))
            ),
            child: Text(
              match.isBo3 ? "${match.roundName} (BO3)" : match.roundName,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: () => _updateScore(match, 1),
            onLongPress: () => _updateScore(match, 1, delta: -1), // Décrémenter pour corriger
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: p1Win ? Colors.green.withOpacity(0.2) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(match.player1?.name ?? "...", style: TextStyle(color: p1Win ? Colors.greenAccent : (match.player1?.isBye==true ? Colors.white30 : Colors.white), fontSize: 12))),
                  Text("${match.score1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          InkWell(
            onTap: () => _updateScore(match, 2),
            onLongPress: () => _updateScore(match, 2, delta: -1), // Décrémenter pour corriger
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: p2Win ? Colors.green.withOpacity(0.2) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(match.player2?.name ?? "...", style: TextStyle(color: p2Win ? Colors.greenAccent : (match.player2?.isBye==true ? Colors.white30 : Colors.white), fontSize: 12))),
                  Text("${match.score2}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if ((match.score1 > 0 || match.score2 > 0) && !isGhost)
            InkWell(
              onTap: () => _resetMatch(match),
              child: Container(width: double.infinity, padding: const EdgeInsets.all(2), child: const Icon(Icons.refresh, size: 12, color: Colors.white24)),
            )
        ],
      ),
    );
  }
}