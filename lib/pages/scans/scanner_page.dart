// Fichier : lib/pages/scanner_page.dart
// VERSION MISE À JOUR : Ajout Recherche Manuelle (Fallback Local)

import 'dart:async'; // Ajouté pour le Debounce
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:magic_companion/pages/cards/card_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_history_page.dart'; 
import '../../services/local_card_service.dart'; // Import du service
import '../../models/scryfall_card_model.dart'; // Import du modèle

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  
  CameraController? _controller;
  final LocalCardService _localCardService = LocalCardService();
  
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;
  String _errorMessage = "";
  bool _isFlashOn = false;

  // Animation pour la ligne de scan
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _initializeCamera();
    _localCardService.loadLocalData();

    // Init Animation
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnimationController, curve: Curves.easeInOut)
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final CameraController? cameraController = _controller;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cameraController != null) {
        cameraController.dispose();
        if (mounted) setState(() => _isCameraInitialized = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (cameraController == null || !cameraController.value.isInitialized) {
         _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isPermissionDenied = false;
        _errorMessage = "";
      });
    }
    
    if (_controller != null) await _controller!.dispose();
  
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          _errorMessage = "Permission caméra refusée.";
        });
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
         if (mounted) setState(() {
            _isPermissionDenied = true;
            _errorMessage = "Aucune caméra disponible.";
          });
        return;
      }

      final firstCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back, 
          orElse: () => cameras.first
      );
      
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.max, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);

      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          _errorMessage = "Erreur caméra: ${e.toString()}";
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      print("Erreur flash: $e");
    }
  }
  
  Future<void> _onTapFocus(TapDownDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    try {
      await _controller!.setFocusPoint(offset);
      await _controller!.setExposurePoint(offset);
    } catch (e) {
      // Ignore
    }
  }

  // --- NOUVEAU : MODALE DE RECHERCHE MANUELLE ---
  void _showManualSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualSearchModal(localCardService: _localCardService),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _scanAnimationController.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scanner HD', style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0, 
        actions: [
          // Bouton Recherche Manuelle
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: "Recherche manuelle (si OCR échoue)",
            onPressed: _showManualSearch,
          ),
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            color: _isFlashOn ? Colors.yellow : Colors.white,
            onPressed: _toggleFlash,
          )
        ],       
      ),
      body: _buildCameraPreview(),
    );
  }

  Widget _buildCameraPreview() {
    if (_isPermissionDenied) {
      return Center(child: Text(_errorMessage, style: GoogleFonts.cinzel(color: Colors.red.shade300)));
    }
    
    if (_isCameraInitialized && _controller != null && _controller!.value.isInitialized) {
       return LayoutBuilder(
         builder: (context, constraints) {
           return GestureDetector(
             onTapDown: (details) => _onTapFocus(details, constraints),
             child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                _buildCardOverlay(),
                
                Positioned(
                  top: 20, left: 0, right: 0,
                  child: Text(
                    "Touchez pour focus • Loupe pour chercher",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(color: Colors.white70, fontSize: 12, shadows: [const Shadow(blurRadius: 4, color: Colors.black)]),
                  ),
                ),

                Positioned(
                  bottom: 30, left: 30,
                  child: FloatingActionButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanHistoryPage())),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    heroTag: 'history_button',
                    child: const Icon(Icons.history),
                  ),
                ),
                Positioned(
                  bottom: 30, right: 30,
                  child: FloatingActionButton.large(
                    onPressed: _onTakePicture,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    child: const Icon(Icons.camera_alt, size: 40),
                  ),
                ),
              ],
             ),
           );
         }
       );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }

  Future<void> _onTakePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile picture = await _controller!.takePicture();
      if (!mounted) return; 
      if (_isFlashOn) _toggleFlash();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecognitionResultPage(imagePath: picture.path),
        ),
      );
    } catch (e) {
      print("Erreur photo: $e");
    }
  }

  Widget _buildCardOverlay() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ScannerOverlayPainter(
            scanValue: _scanAnimation.value,
            borderColor: Colors.yellow.shade700,
          ),
          child: Container(),
        );
      },
    );
  }
}

// --- SOUS-WIDGET : MODALE DE RECHERCHE ---
class _ManualSearchModal extends StatefulWidget {
  final LocalCardService localCardService;
  const _ManualSearchModal({required this.localCardService});

  @override
  State<_ManualSearchModal> createState() => _ManualSearchModalState();
}

class _ManualSearchModalState extends State<_ManualSearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<ScryfallCard> _results = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async { // <-- async ajouté
      if (query.trim().length >= 2) {
        // Ajout du await
        final results = await widget.localCardService.searchCards(query: query); 
        if (mounted) {
          setState(() {
            _results = results;
          });
        }
      } else {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: GoogleFonts.cinzel(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Nom de la carte (FR/EN)...",
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.isEmpty 
                            ? "Tapez le nom d'une carte" 
                            : "Aucun résultat local.",
                        style: GoogleFonts.cinzel(color: Colors.white30),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        return ListTile(
                          title: Text(card.name, style: GoogleFonts.cinzel(color: Colors.white)),
                          subtitle: Text(card.typeLine, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                          onTap: () {
                            Navigator.pop(context); // Ferme la modale
                            // Navigue vers la page de détail comme si on avait scanné
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecognitionResultPage(cardName: card.name),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final double scanValue;
  final Color borderColor;

  ScannerOverlayPainter({required this.scanValue, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Dimensions de la zone de scan (Ratio Carte Magic ~ 63x88mm)
    final double cardWidth = size.width * 0.75;
    final double cardHeight = cardWidth * 1.4; 
    
    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    final Rect scanRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    final RRect scanRRect = RRect.fromRectAndRadius(scanRect, const Radius.circular(12));

    // 1. Fond sombre semi-transparent avec "trou"
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()
      ..addRRect(scanRRect);
    
    final Path overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    paint.color = Colors.black.withOpacity(0.6); // Assombrissement
    canvas.drawPath(overlayPath, paint);

    // 2. Bordure
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(scanRRect, borderPaint);

    // 3. Coins décoratifs (Style "Viseur")
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    double cornerSize = 20;
    // Coin Haut-Gauche
    canvas.drawPath(Path()..moveTo(left, top + cornerSize)..lineTo(left, top)..lineTo(left + cornerSize, top), cornerPaint);
    // Coin Haut-Droite
    canvas.drawPath(Path()..moveTo(left + cardWidth, top + cornerSize)..lineTo(left + cardWidth, top)..lineTo(left + cardWidth - cornerSize, top), cornerPaint);
    // Coin Bas-Gauche
    canvas.drawPath(Path()..moveTo(left, top + cardHeight - cornerSize)..lineTo(left, top + cardHeight)..lineTo(left + cornerSize, top + cardHeight), cornerPaint);
    // Coin Bas-Droite
    canvas.drawPath(Path()..moveTo(left + cardWidth, top + cardHeight - cornerSize)..lineTo(left + cardWidth, top + cardHeight)..lineTo(left + cardWidth - cornerSize, top + cardHeight), cornerPaint);

    // 4. Ligne de Scan (Laser)
    final double scanY = top + (cardHeight * scanValue);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [borderColor.withOpacity(0), borderColor, borderColor.withOpacity(0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(left, scanY, cardWidth, 4));
    
    canvas.drawRect(Rect.fromLTWH(left, scanY, cardWidth, 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanValue != scanValue;
  }
}