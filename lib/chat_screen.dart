import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Pour l'effet de flou (Glassmorphism)

// --- 1. MODÈLE ---
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;

  ChatMessage({required this.text, required this.isUser, this.isLoading = false});
}

// --- 2. GESTION D'ÉTAT (RIVERPOD) ---
class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([
    ChatMessage(text: "Salutations. Je suis l'Esprit du Code. Quelle connaissance cherchez-vous ?", isUser: false),
  ]);

  final Dio _dio = Dio();
  // Adresse pour l'émulateur Android (10.0.2.2 = localhost du PC)
  static const String apiUrl = 'http://127.0.0.1:8000/chat';

  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty) return;

    // Ajout message utilisateur + loading
    state = [
      ...state,
      ChatMessage(text: query, isUser: true),
      ChatMessage(text: '...', isUser: false, isLoading: true),
    ];

    try {
      final response = await _dio.post(apiUrl, data: {'query': query});
      final botResponse = response.data['response'] as String;

      // Remplacement du loading par la réponse
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(text: botResponse, isUser: false),
      ];
    } catch (e) {
      state = [
        ...state.sublist(0, state.length - 1),
        ChatMessage(text: 'Le lien arcanique est rompu... (Vérifiez que le serveur Python tourne)', isUser: false),
      ];
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier();
});

// --- 3. UI (WRAPPER) ---
// On utilise un Wrapper pour injecter le ProviderScope localement
// Cela évite de devoir modifier le main.dart
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _ChatScreenContent(),
    );
  }
}

// --- 4. CONTENU DE L'ÉCRAN ---
class _ChatScreenContent extends ConsumerStatefulWidget {
  const _ChatScreenContent();

  @override
  ConsumerState<_ChatScreenContent> createState() => _ChatScreenContentState();
}

class _ChatScreenContentState extends ConsumerState<_ChatScreenContent> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), 
          side: const BorderSide(color: AppColors.accentOrange, width: 2) // Bordure Indigo pour matcher le thème
        ),
        title: Text('Assistant RAG', style: AppTextStyles.bold()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cet assistant analyse votre code source Flutter pour répondre à vos questions techniques.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary, 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: AppColors.borderSubtle)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FONCTIONNEMENT :', style: GoogleFonts.robotoMono(color: AppColors.primaryShade900, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('1. Recherche des fichiers pertinents (Embeddings).', style: GoogleFonts.robotoMono(color: AppColors.textMuted, fontSize: 11)),
                    Text('2. Envoi des extraits de code au LLM.', style: GoogleFonts.robotoMono(color: AppColors.textMuted, fontSize: 11)),
                    Text('3. Génération de la réponse technique.', style: GoogleFonts.robotoMono(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Fermer', style: TextStyle(color: AppColors.textMuted))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Exemple de question technique pertinente pour ton projet
              _controller.text = 'Comment fonctionne la sauvegarde des decks ?';
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryShade900),
            child: Text('Tester un exemple', style: AppTextStyles.cinzel()),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);

    // Auto-scroll
    ref.listen(chatProvider, (previous, next) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });

    return Scaffold(
      extendBodyBehindAppBar: true, // Important pour le design immersif
      appBar: AppBar(
        title: Text('Grimoire Code', style: AppTextStyles.cinzel(fontWeight: FontWeight.w900, color: AppColors.primaryBright)),
        backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.4),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)), // Icônes dorées
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: AppColors.transparent),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _showInfoDialog),
        ],
      ),
      body: Stack(
        children: [
          // 1. IMAGE DE FOND (Sombre et mystérieuse)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F1115), // Fond de secours
              image: DecorationImage(
                image: AssetImage('assets/images/background_texture_black.png'), // Ton image existante
                fit: BoxFit.cover,
                opacity: 0.5, // On l'assombrit pour la lisibilité
              ),
            ),
          ),

          // 2. LISTE DES MESSAGES
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 120, 16, 20), // Marge haute pour l'AppBar
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildModernBubble(messages[index]);
                  },
                ),
              ),
              
              // 3. BARRE DE SAISIE FLOTTANTE
              _buildMagicalInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    // Couleurs locales pour ne pas dépendre du main.dart
    final userGradient = [Colors.purple.shade900.withValues(alpha: 0.8), Colors.deepPurple.shade800.withValues(alpha: 0.8)];
    final botGradient = [const Color(0xFF2A2D35).withValues(alpha: 0.85), const Color(0xFF1E2129).withValues(alpha: 0.85)];
    final borderColor = isUser ? AppColors.accentPurple.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.2);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isUser ? userGradient : botGradient),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: AppColors.textOnPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: msg.isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber)),
                  const SizedBox(width: 10),
                  Text('Invocation...', style: AppTextStyles.cinzel(color: AppColors.amber, fontSize: 12))
                ],
              )
            : isUser
                ? Text(msg.text, style: GoogleFonts.roboto(color: AppColors.textPrimary, fontSize: 15))
                : MarkdownBody(
                    data: msg.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 15, height: 1.5),
                      strong: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.bold),
                      code: GoogleFonts.firaCode(
                        backgroundColor: AppColors.overlayDark, 
                        color: AppColors.accentGreen, 
                        fontSize: 13
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: const Color(0xFF101216),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildMagicalInputArea() {
    // Effet de verre givré en bas de l'écran
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1115).withValues(alpha: 0.7),
            border: const Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          // AJOUT DU SAFEAREA ICI
          child: SafeArea(
            top: false, // Important : on ne veut pas de marge en haut
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.primaryShade900.withValues(alpha: 0.3)),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Posez votre question...',
                          hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.3), fontStyle: FontStyle.italic),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Bouton d'envoi Magique
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.accentOrange, Colors.orange]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primaryShade900.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: AppColors.overlayVeryDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendMessage() {
    ref.read(chatProvider.notifier).sendMessage(_controller.text);
    _controller.clear();
  }
}
