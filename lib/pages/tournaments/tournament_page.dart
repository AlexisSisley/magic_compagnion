import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/profile_service.dart';

class TournamentPlayer {
  String id;
  String name;
  TournamentPlayer({required this.id, required this.name});
  bool get isBye => name == "BYE";
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory TournamentPlayer.fromJson(Map<String, dynamic> json) => TournamentPlayer(id: json['id'], name: json['name']);
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
    required this.id, required this.roundName, required this.roundIndex,
    this.isBo3 = false, this.isLoserBracket = false, this.player1, this.player2,
    this.score1 = 0, this.score2 = 0,
  });

  bool get isFinished => isBo3 ? (score1 == 2 || score2 == 2) : (score1 == 1 || score2 == 1);
  TournamentPlayer? get winner => !isFinished ? null : (score1 > score2 ? player1 : player2);
  TournamentPlayer? get loser => !isFinished ? null : (score1 > score2 ? player2 : player1);
}

class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key});
  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> with SingleTickerProviderStateMixin {
  int _status = 0; 
  List<TournamentPlayer> _players = [];
  final TextEditingController _nameController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  
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

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tournament_status', _status);
    await prefs.setString('tournament_players', json.encode(_players.map((p) => p.toJson()).toList()));
    if (_status == 1) {
      final allMatches = [..._winnerBracket, ..._loserBracket];
      final Map<String, dynamic> matchesState = {};
      for (var m in allMatches) {
        matchesState[m.id] = {'p1': m.player1?.id, 'p2': m.player2?.id, 's1': m.score1, 's2': m.score2};
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
        _players = (json.decode(playersJson) as List).map((j) => TournamentPlayer.fromJson(j)).toList();
      }
      if (_status == 1) {
        _players.length <= 4 ? _init4PlayersBracket() : _init8PlayersBracket();
        final String? matchesJson = prefs.getString('tournament_matches');
        if (matchesJson != null) {
          final Map<String, dynamic> stateMap = json.decode(matchesJson);
          final allMatches = [..._winnerBracket, ..._loserBracket];
          for (var m in allMatches) {
            if (stateMap.containsKey(m.id)) {
              final s = stateMap[m.id];
              if (s['p1'] != null) m.player1 = _players.firstWhere((p) => p.id == s['p1'], orElse: () => TournamentPlayer(id: '?', name: '?'));
              if (s['p2'] != null) m.player2 = _players.firstWhere((p) => p.id == s['p2'], orElse: () => TournamentPlayer(id: '?', name: '?'));
              m.score1 = s['s1'] ?? 0; m.score2 = s['s2'] ?? 0;
            }
          }
        }
      }
      _isLoading = false;
    });
  }

  void _addPlayer() {
    if (_nameController.text.trim().isEmpty) return;
    if (_players.length >= 8) return;
    setState(() {
      _players.add(TournamentPlayer(id: DateTime.now().millisecondsSinceEpoch.toString(), name: _nameController.text.trim()));
      _nameController.clear();
    });
    _saveState();
  }

  Future<void> _pickFromProfiles() async {
    final profiles = await _profileService.loadProfiles();
    if (!mounted) return;
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucun profil enregistré.")));
      return;
    }
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16.0), child: Text("Choisir des joueurs", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18))),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (c, i) {
                final p = profiles[i];
                final bool isReg = _players.any((tp) => tp.name == p.name);
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Color(p.colorValue)),
                  title: Text(p.name, style: const TextStyle(color: Colors.white)),
                  trailing: Icon(isReg ? Icons.check : Icons.add, color: isReg ? Colors.green : Colors.blue),
                  enabled: !isReg,
                  onTap: () {
                    setState(() { _players.add(TournamentPlayer(id: p.id, name: p.name)); });
                    _saveState();
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _startTournament() {
    if (_players.length < 2) return;
    int target = _players.length <= 4 ? 4 : 8;
    for (int i = 0, len = _players.length; i < target - len; i++) {
      _players.add(TournamentPlayer(id: "bye_$i", name: "BYE"));
    }
    _players.shuffle();
    setState(() { target == 4 ? _init4PlayersBracket() : _init8PlayersBracket(); _status = 1; });
    _autoResolveByes(); _saveState();
  }

  // --- LOGIQUE BRACKET (Demi/Quart/Lien) ---
  void _linkWin(TournamentMatch src, TournamentMatch dest, int slot) { src.nextMatchWin = dest; src.nextSlotWin = slot; }
  void _linkLose(TournamentMatch src, TournamentMatch dest, int slot) { src.nextMatchLose = dest; src.nextSlotLose = slot; }

  void _init4PlayersBracket() {
    var wFinal = TournamentMatch(id: 'w_final', roundName: 'Finale', roundIndex: 1, isBo3: true);
    var wSemi1 = TournamentMatch(id: 'w_semi1', roundName: 'Demi', roundIndex: 0, isBo3: true, player1: _players[0], player2: _players[1]);
    var wSemi2 = TournamentMatch(id: 'w_semi2', roundName: 'Demi', roundIndex: 0, isBo3: true, player1: _players[2], player2: _players[3]);
    _linkWin(wSemi1, wFinal, 1); _linkWin(wSemi2, wFinal, 2);
    var lRound1 = TournamentMatch(id: 'l_r1', roundName: 'Repêchage', roundIndex: 0, isLoserBracket: true);
    var lFinal = TournamentMatch(id: 'l_final', roundName: 'Petite Finale', roundIndex: 1, isLoserBracket: true, isBo3: true);
    _linkLose(wSemi1, lRound1, 1); _linkLose(wSemi2, lRound1, 2);
    _linkWin(lRound1, lFinal, 2); _linkLose(wFinal, lFinal, 1);
    _winnerBracket = [wSemi1, wSemi2, wFinal]; _loserBracket = [lRound1, lFinal];
  }

  void _init8PlayersBracket() {
    var wFinal = TournamentMatch(id: 'w_final', roundName: 'Finale', roundIndex: 2, isBo3: true);
    var wSemi1 = TournamentMatch(id: 'w_semi1', roundName: 'Demi', roundIndex: 1, isBo3: true);
    var wSemi2 = TournamentMatch(id: 'w_semi2', roundName: 'Demi', roundIndex: 1, isBo3: true);
    var wQ1 = TournamentMatch(id: 'w_q1', roundName: 'Quart', roundIndex: 0, player1: _players[0], player2: _players[1]);
    var wQ2 = TournamentMatch(id: 'w_q2', roundName: 'Quart', roundIndex: 0, player1: _players[2], player2: _players[3]);
    var wQ3 = TournamentMatch(id: 'w_q3', roundName: 'Quart', roundIndex: 0, player1: _players[4], player2: _players[5]);
    var wQ4 = TournamentMatch(id: 'w_q4', roundName: 'Quart', roundIndex: 0, player1: _players[6], player2: _players[7]);
    _linkWin(wQ1, wSemi1, 1); _linkWin(wQ2, wSemi1, 2); _linkWin(wQ3, wSemi2, 1); _linkWin(wQ4, wSemi2, 2);
    _linkWin(wSemi1, wFinal, 1); _linkWin(wSemi2, wFinal, 2);
    var lQ1 = TournamentMatch(id: 'l_q1', roundName: 'Repêchage 1', roundIndex: 0, isLoserBracket: true);
    var lQ2 = TournamentMatch(id: 'l_q2', roundName: 'Repêchage 2', roundIndex: 0, isLoserBracket: true);
    var lSemi1 = TournamentMatch(id: 'l_semi1', roundName: 'Demi Loser', roundIndex: 2, isLoserBracket: true);
    var lSemi2 = TournamentMatch(id: 'l_semi2', roundName: 'Demi Loser', roundIndex: 2, isLoserBracket: true);
    var lFinal = TournamentMatch(id: 'l_final', roundName: 'Finale Loser', roundIndex: 3, isLoserBracket: true, isBo3: true);
    _linkLose(wQ1, lQ1, 1); _linkLose(wQ2, lQ1, 2); _linkLose(wQ3, lQ2, 1); _linkLose(wQ4, lQ2, 2);
    _linkWin(lQ1, lSemi1, 2); _linkLose(wSemi1, lSemi1, 1); _linkWin(lQ2, lSemi2, 2); _linkLose(wSemi2, lSemi2, 1);
    _linkWin(lSemi1, lFinal, 1); _linkWin(lSemi2, lFinal, 2);
    _winnerBracket = [wQ1, wQ2, wQ3, wQ4, wSemi1, wSemi2, wFinal]; _loserBracket = [lQ1, lQ2, lSemi1, lSemi2, lFinal];
  }

  void _updateScore(TournamentMatch m, int slot, {int delta = 1, bool auto = false}) {
    if (delta > 0 && m.isFinished) return;
    void up() {
      slot == 1 ? m.score1 = (m.score1 + delta).clamp(0, 99) : m.score2 = (m.score2 + delta).clamp(0, 99);
      if (m.isFinished) {
        if (m.nextMatchWin != null && m.winner != null) { m.nextSlotWin == 1 ? m.nextMatchWin!.player1 = m.winner : m.nextMatchWin!.player2 = m.winner; }
        if (m.nextMatchLose != null && m.loser != null) { m.nextSlotLose == 1 ? m.nextMatchLose!.player1 = m.loser : m.nextMatchLose!.player2 = m.loser; }
      } else {
        if (m.nextMatchWin != null) { m.nextSlotWin == 1 ? m.nextMatchWin!.player1 = null : m.nextMatchWin!.player2 = null; }
        if (m.nextMatchLose != null) { m.nextSlotLose == 1 ? m.nextMatchLose!.player1 = null : m.nextMatchLose!.player2 = null; }
      }
    }
    auto ? up() : setState(up); _saveState();
  }

  void _autoResolveByes() {
    for (var m in _winnerBracket.where((m) => m.roundIndex == 0)) {
      if (m.player1 != null && m.player2 != null) {
        if (m.player2!.isBye && !m.player1!.isBye) { _updateScore(m, 1, auto: true); if (m.isBo3) _updateScore(m, 1, auto: true); }
        else if (m.player1!.isBye && !m.player2!.isBye) { _updateScore(m, 2, auto: true); if (m.isBo3) _updateScore(m, 2, auto: true); }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF1A1A1A), body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Text("Arbre de Tournoi", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        actions: [if (_status != 0) IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: () => setState(() => _status = 0))],
        bottom: _status == 1 ? TabBar(controller: _tabController, indicatorColor: Colors.yellow.shade800, tabs: const [Tab(text: "Winner Bracket"), Tab(text: "Loser Bracket")]) : null,
      ),
      body: SafeArea(child: _status == 0 ? _buildRegistration() : TabBarView(controller: _tabController, children: [_buildTreeCanvas(_winnerBracket), _buildTreeCanvas(_loserBracket)])),
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
              Expanded(child: TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Nom du joueur...", filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
              IconButton(icon: const Icon(Icons.person_pin_rounded, color: Colors.blueAccent, size: 28), onPressed: _pickFromProfiles),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green, size: 32), onPressed: _addPlayer)
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: ListView.builder(itemCount: _players.length, itemBuilder: (ctx, i) => Card(color: Colors.white.withOpacity(0.05), child: ListTile(leading: CircleAvatar(backgroundColor: Colors.blueGrey, child: Text("${i+1}")), title: Text(_players[i].name, style: GoogleFonts.cinzel(color: Colors.white)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _players.removeAt(i))))))),
          ElevatedButton(onPressed: _players.length >= 2 ? _startTournament : null, style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800, foregroundColor: Colors.black), child: Text("Générer l'Arbre", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTreeCanvas(List<TournamentMatch> matches) {
    Map<int, List<TournamentMatch>> rounds = {};
    for (var m in matches) rounds.putIfAbsent(m.roundIndex, () => []).add(m);
    final sortedKeys = rounds.keys.toList()..sort();
    return SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(16), child: Row(children: sortedKeys.map((k) => Row(children: [Column(mainAxisAlignment: MainAxisAlignment.spaceAround, children: rounds[k]!.map((m) => _buildMatchCard(m)).toList()), if (k != sortedKeys.last) Container(width: 20, height: 2, color: Colors.white24)])).toList()));
  }

  Widget _buildMatchCard(TournamentMatch m) {
    final bool p1W = m.isFinished && m.score1 > m.score2;
    final bool p2W = m.isFinished && m.score2 > m.score1;
    return Container(
      width: 180, margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.black, border: Border.all(color: m.isFinished ? Colors.green.shade800 : Colors.white24), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: m.isBo3 ? Colors.purple.shade900.withOpacity(0.5) : Colors.white10), child: Text(m.roundName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white70))),
        ListTile(dense: true, title: Text(m.player1?.name ?? "...", style: TextStyle(color: p1W ? Colors.greenAccent : Colors.white, fontSize: 12)), trailing: Text("${m.score1}", style: const TextStyle(color: Colors.white)), onTap: () => _updateScore(m, 1), onLongPress: () => _updateScore(m, 1, delta: -1)),
        const Divider(height: 1, color: Colors.white10),
        ListTile(dense: true, title: Text(m.player2?.name ?? "...", style: TextStyle(color: p2W ? Colors.greenAccent : Colors.white, fontSize: 12)), trailing: Text("${m.score2}", style: const TextStyle(color: Colors.white)), onTap: () => _updateScore(m, 2), onLongPress: () => _updateScore(m, 2, delta: -1)),
      ]),
    );
  }
}