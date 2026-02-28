import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/oracle_service.dart';
import '../../providers/service_providers.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class MagicOraclePage extends ConsumerStatefulWidget {
  const MagicOraclePage({super.key});

  @override
  ConsumerState<MagicOraclePage> createState() => _MagicOraclePageState();
}

class _MagicOraclePageState extends ConsumerState<MagicOraclePage> {
  final TextEditingController _controller = TextEditingController();
  OracleService get _oracleService => ref.read(oracleServiceProvider);
  final ScrollController _scrollController = ScrollController();
  
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Salutations, Planeswalker. Je suis connecté aux Archives. Posez-moi une question sur les règles.",
      isUser: false
    )
  ];
  
  bool _isLoading = false;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await _oracleService.askQuestion(text);
    
    // --- LOG DEBUG ICI ---
    debugPrint("🤖 Réponse Oracle reçue : $response");

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    // Petit délai pour laisser le temps à l'interface de dessiner le nouveau message avant de scroller
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  void _showExampleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.purple.shade900, width: 2)),
        title: Text("Logique de l'Oracle", style: GoogleFonts.cinzel(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("L'Oracle combine les règles officielles avec le texte des cartes pour déduire la réponse.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CONTEXTE RÈGLES :", style: GoogleFonts.robotoMono(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("- 702.2. Deathtouch...\n- 704.5h. If a creature...", style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 8),
                    Text("CONTEXTE CARTE :", style: GoogleFonts.robotoMono(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("- Card: Sheoldred\n- Text: Whenever you draw...", style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.text = "Si je lance une roue avec Sheoldred sur le terrain, que se passe-t-il ?";
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800),
            child: Text("Tester cet exemple", style: GoogleFonts.cinzel(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            Text("L'Oracle", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(icon: const Icon(Icons.info_outline, color: Colors.white70), onPressed: _showExampleDialog),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                // Utilisation du widget animé personnalisé
                return _AnimatedMessageBubble(message: msg);
              },
            ),
          ),
          if (_isLoading) 
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: LinearProgressIndicator(color: Colors.purpleAccent, backgroundColor: Colors.transparent, minHeight: 2)),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: Colors.black, 
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end, // Aligne le bouton en bas si le texte grandit
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.roboto(color: Colors.white, fontSize: 16), // Police plus lisible pour la saisie
                    
                    // --- LA MAGIE TEXT AREA ---
                    minLines: 1,
                    maxLines: 5, // S'agrandit jusqu'à 5 lignes, puis scrolle
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    // --------------------------

                    decoration: InputDecoration(
                      hintText: "Posez votre question...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Bouton d'envoi
              Container(
                margin: const EdgeInsets.only(bottom: 2), // Petit ajustement visuel
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.purple.shade800,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET D'ANIMATION ---
class _AnimatedMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _AnimatedMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 400),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack, // Le rebond qui dépassait 1.0
      builder: (context, double value, child) {
        return Opacity(
          // CORRECTION ICI : On force la valeur entre 0 et 1 pour l'opacité
          opacity: value.clamp(0.0, 1.0), 
          child: Transform.translate(
            // On laisse la valeur 'value' brute ici pour garder le rebond visuel
            offset: Offset(0, 20 * (1 - value)), 
            child: child,
          ),
        );
      },
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: message.isUser ? const Color(0xFF6A1B9A) : const Color(0xFF2A2A2A), // Couleurs plus modernes
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(2),
              bottomRight: message.isUser ? const Radius.circular(2) : const Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: Colors.purpleAccent),
                    const SizedBox(width: 6),
                    Text("ORACLE", style: GoogleFonts.cinzel(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.text,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}