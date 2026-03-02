// Fichier : lib/pages/scans/scanner_page.dart
// CORRECTION : Fix Race Condition permission caméra + ResolutionPreset

import 'package:magic_companion/theme/app_text_styles.dart';
import 'package:magic_companion/theme/app_colors.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../router/app_router.dart';
import '../../services/local_card_service.dart';
import '../../models/scryfall_card_model.dart';
import '../../providers/service_providers.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  LocalCardService get _localCardService => ref.read(localCardServiceProvider);

  CameraController? _controller;
  
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;
  bool _isInitializing = false; // Verrou pour éviter la double initialisation
  String _errorMessage = '';
  bool _isFlashOn = false;

  // Animation pour la ligne de scan
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    // On lance l'initialisation. Le verrou _isInitializing gérera les conflits.
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
    final CameraController? cameraController = _controller;

    // Si l'app passe en pause (background ou autre app), on libère la caméra
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cameraController != null && cameraController.value.isInitialized) {
        // On ne dispose pas immédiatement pour éviter les soucis si c'est juste un switch rapide,
        // mais c'est une bonne pratique de libérer les ressources.
        // Ici, on marque juste comme non initialisé pour forcer le rebuild UI.
        if (mounted) setState(() => _isCameraInitialized = false);
        cameraController.dispose(); // Libération réelle
        _controller = null;
      }
    } 
    // Si l'app reprend
    else if (state == AppLifecycleState.resumed) {
      // On ne relance l'init que si on n'est pas déjà en train de le faire
      // et que le controller est null ou non initialisé.
      if (!_isInitializing && (_controller == null || !_controller!.value.isInitialized)) {
         _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing) return; // Sécurité anti-conflit
    _isInitializing = true;

    try {
      // 1. Vérification Permission
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          if (mounted) {
            setState(() {
              _isPermissionDenied = true;
              _errorMessage = "Permission caméra refusée. Veuillez l'activer dans les paramètres.";
              _isInitializing = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isPermissionDenied = false;
          _errorMessage = '';
        });
      }

      // 2. Récupération Caméras
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final firstCamera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      
      // 3. Création Controller
      // IMPORTANT : Utiliser ResolutionPreset.high au lieu de .max pour la stabilité sur Android
      final controller = CameraController(
        firstCamera,
        ResolutionPreset.high, 
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );
      
      _controller = controller;

      // 4. Initialisation effective
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          _errorMessage = 'Erreur caméra: $e';
          _isInitializing = false;
        });
      }
      log('Erreur Init Caméra: $e', name: 'ScannerPage');
    } finally {
      _isInitializing = false;
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
      log('Erreur flash: $e', name: 'ScannerPage');
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

  void _showManualSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
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
      backgroundColor: AppColors.textOnPrimary,
      appBar: AppBar(
        title: Text('Scanner', style: AppTextStyles.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.textOnPrimary.withValues(alpha: 0.5),
        elevation: 0, 
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
            tooltip: 'Recherche manuelle',
            onPressed: _showManualSearch,
          ),
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            color: _isFlashOn ? AppColors.primary : AppColors.textPrimary,
            onPressed: _toggleFlash,
          )
        ],       
      ),
      body: _buildCameraPreview(),
    );
  }

  Widget _buildCameraPreview() {
    if (_isPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography, size: 64, color: AppColors.accentRed),
              const SizedBox(height: 16),
              Text(
                'Accès caméra requis', 
                style: AppTextStyles.pageTitle(fontSize: 20)
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.isEmpty ? "Veuillez autoriser l'accès." : _errorMessage,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                child: const Text('Réessayer'),
              )
            ],
          ),
        )
      );
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
                    'Touchez pour focus • Loupe pour chercher',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(color: AppColors.textSecondary, fontSize: 12, shadows: [const Shadow(blurRadius: 4, color: AppColors.textOnPrimary)]),
                  ),
                ),

                Positioned(
                  bottom: 30, left: 30,
                  child: FloatingActionButton(
                    onPressed: () => context.push(AppRoutes.scanHistory),
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.textOnPrimary,
                    heroTag: 'history_button',
                    child: const Icon(Icons.history),
                  ),
                ),
                Positioned(
                  bottom: 30, right: 30,
                  child: FloatingActionButton.large(
                    onPressed: _onTakePicture,
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.textOnPrimary,
                    child: const Icon(Icons.camera_alt, size: 40),
                  ),
                ),
              ],
             ),
           );
         }
       );
    }
    return const Center(child: CircularProgressIndicator(color: AppColors.textPrimary));
  }

  Future<void> _onTakePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isInitializing) return;
    try {
      final XFile picture = await _controller!.takePicture();
      if (!mounted) return; 
      
      // On met en pause la caméra visuellement
      await _controller!.pausePreview();
      if (!mounted) return;

      // Navigation vers la page de résultat avec le flag "Continuous Scan"
      final result = await context.push(
        AppRoutes.cardDetail,
        extra: {
          'imagePath': picture.path,
          'isContinuousScan': true, // <--- ACTIVE LE MODE SÉRIE
        },
      );

      // Si le résultat est 'true', on relance immédiatement le scan
      if (result == true) {
        if (mounted && _controller != null) {
          await _controller!.resumePreview();
          // Reset flash if needed (souvent le flash s'éteint après photo)
          if (_isFlashOn) _toggleFlash(); // Remet état UI correct ou rallume
        }
      } else {
        // Sinon (retour arrière classique), on relance aussi le preview pour être prêt
        if (mounted && _controller != null) await _controller!.resumePreview();
      }

    } catch (e) {
      log('Erreur photo: $e', name: 'ScannerPage');
    }
  }

  Widget _buildCardOverlay() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: ScannerOverlayPainter(
            scanValue: _scanAnimation.value,
            borderColor: AppColors.primaryShade700,
          ),
          child: Container(),
        );
      },
    );
  }
}

// --- SOUS-WIDGET : MODALE DE RECHERCHE (Inchangé) ---
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
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length >= 2) {
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
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: AppTextStyles.cinzel(),
                      decoration: const InputDecoration(
                        hintText: 'Nom de la carte (FR/EN)...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: InputBorder.none,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(color: AppColors.borderLight, height: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.isEmpty 
                            ? "Tapez le nom d'une carte" 
                            : 'Aucun résultat local.',
                        style: AppTextStyles.cinzel(color: AppColors.textDisabled),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        return ListTile(
                          title: Text(card.name, style: AppTextStyles.cinzel()),
                          subtitle: Text(card.typeLine, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.borderMedium),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(AppRoutes.cardDetail, extra: {'cardName': card.name});
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

// --- PAINTER POUR L'OVERLAY (Inchangé) ---
class ScannerOverlayPainter extends CustomPainter {
  final double scanValue;
  final Color borderColor;

  ScannerOverlayPainter({required this.scanValue, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final double cardWidth = size.width * 0.75;
    final double cardHeight = cardWidth * 1.4; 
    
    final double left = (size.width - cardWidth) / 2;
    final double top = (size.height - cardHeight) / 2;
    final Rect scanRect = Rect.fromLTWH(left, top, cardWidth, cardHeight);
    final RRect scanRRect = RRect.fromRectAndRadius(scanRect, const Radius.circular(12));

    final Path backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cutoutPath = Path()..addRRect(scanRRect);
    
    final Path overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    paint.color = AppColors.textOnPrimary.withValues(alpha: 0.6);
    canvas.drawPath(overlayPath, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRRect(scanRRect, borderPaint);

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    double cornerSize = 20;
    canvas.drawPath(Path()..moveTo(left, top + cornerSize)..lineTo(left, top)..lineTo(left + cornerSize, top), cornerPaint);
    canvas.drawPath(Path()..moveTo(left + cardWidth, top + cornerSize)..lineTo(left + cardWidth, top)..lineTo(left + cardWidth - cornerSize, top), cornerPaint);
    canvas.drawPath(Path()..moveTo(left, top + cardHeight - cornerSize)..lineTo(left, top + cardHeight)..lineTo(left + cornerSize, top + cardHeight), cornerPaint);
    canvas.drawPath(Path()..moveTo(left + cardWidth, top + cardHeight - cornerSize)..lineTo(left + cardWidth, top + cardHeight)..lineTo(left + cardWidth - cornerSize, top + cardHeight), cornerPaint);

    final double scanY = top + (cardHeight * scanValue);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [borderColor.withValues(alpha: 0), borderColor, borderColor.withValues(alpha: 0)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(left, scanY, cardWidth, 4));
    
    canvas.drawRect(Rect.fromLTWH(left, scanY, cardWidth, 2), laserPaint);
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) => oldDelegate.scanValue != scanValue;
}
