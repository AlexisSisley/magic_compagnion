// Fichier : lib/pages/scanner_page.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:magic_companion/pages/card_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_history_page.dart'; 

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  
  CameraController? _controller;
  
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;
  String _errorMessage = "";
  
  // NOUVEAU : Gestion du flash
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _initializeCamera();
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
      
      // AMÉLIORATION : Utilisation de ResolutionPreset.max pour une meilleure OCR
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.max, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      await _controller!.initialize();
      
      // Désactiver le flash par défaut au démarrage
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
  
  // NOUVEAU : Focus manuel au toucher
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
      // Ignorer les erreurs de focus sur certains appareils
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scanner HD', style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0, 
        actions: [
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
                
                // Instructions
                Positioned(
                  top: 20, 
                  left: 0, 
                  right: 0,
                  child: Text(
                    "Touchez l'écran pour faire la mise au point",
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
      
      // Arrêt du flash après la photo pour économiser la batterie
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
    return Center(
      child: Container(
        width: 280, // Un peu plus large pour capter le texte du titre
        height: 390, 
        decoration: BoxDecoration(
          border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(15), 
        ),
        child: Column(
          children: [
            // Zone prioritaire pour le titre (Haut de la carte)
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: Colors.yellow.withOpacity(0.3))),
              ),
              child: Center(child: Icon(Icons.title, color: Colors.yellow.withOpacity(0.5))),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}