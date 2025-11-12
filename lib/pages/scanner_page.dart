// Fichier : lib/pages/scanner_page.dart
// VERSION CORRIGÉE (Gère le cycle de vie sans FutureBuilder)

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
  
  // Remplacent le Future
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;
  String _errorMessage = "";

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

    // Si l'app n'est plus active (pause, inactive)
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (cameraController != null) {
        cameraController.dispose();
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      // Si on revient sur l'app et que la caméra n'est pas prête
      if (cameraController == null || !cameraController.value.isInitialized) {
         _initializeCamera();
      }
    }
  }

  /// Initialise (ou ré-initialise) le contrôleur de la caméra
  Future<void> _initializeCamera() async {
    // Réinitialise l'état
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        _isPermissionDenied = false;
        _errorMessage = "";
      });
    }
    
    // Nettoyer l'ancien contrôleur s'il existe
    if (_controller != null) {
      await _controller!.dispose();
    }
  
    // 1. Demander la permission
    var status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          _errorMessage = "Permission caméra refusée. Veuillez l'activer dans les réglages.";
        });
      }
      return;
    }

    // 2. Essayer d'initialiser
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
         if (mounted) {
          setState(() {
            _isPermissionDenied = true; // Utilise le même état pour afficher l'erreur
            _errorMessage = "Aucune caméra disponible sur cet appareil.";
          });
        }
        return;
      }

      // Préfère la caméra arrière
      final firstCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back, 
          orElse: () => cameras.first
      );
      
      _controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      // 3. Attendre l'initialisation
      await _controller!.initialize();
      
      // 4. Mettre à jour l'état si la page est toujours montée
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      // Gère les erreurs d'initialisation (ex: caméra en cours d'utilisation)
      if (mounted) {
        setState(() {
          _isPermissionDenied = true;
          _errorMessage = "Erreur caméra: ${e.toString()}";
        });
      }
      print("Erreur initialisation caméra: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose(); 
    super.dispose();
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scanner', style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,        
      ),
      body: _buildCameraPreview(), // On utilise une fonction dédiée
    );
  }

  /// Construit la vue caméra en fonction de l'état
  Widget _buildCameraPreview() {
    // Cas 1 : Permission refusée ou erreur
    if (_isPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            style: GoogleFonts.cinzel(color: Colors.red.shade300, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    // Cas 2 : Caméra initialisée et prête
    if (_isCameraInitialized && _controller != null && _controller!.value.isInitialized) {
       return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          _buildCardOverlay(),
          Positioned(
            bottom: 30, // Légèrement plus haut que le FAB.large
            left: 30,
            child: FloatingActionButton(
              onPressed: _navigateToHistory,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              heroTag: 'history_button', // Tag pour éviter les conflits
              child: const Icon(Icons.history),
            ),
          ),
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton.large( // Utilise .large()
              onPressed: _onTakePicture,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              child: const Icon(
                Icons.camera_alt,
                size: 40, // Icône plus grande
              ),
            ),
          ),
        ],
      );
    }
    
    // Cas 3 : En cours d'initialisation
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }


  Future<void> _onTakePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    try {
      final XFile picture = await _controller!.takePicture();
      if (!mounted) return; 
      
      // Navigue vers la page de résultat (qui gère l'analyse OCR)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecognitionResultPage(imagePath: picture.path),
        ),
      );
    } catch (e) {
      print("Erreur en prenant la photo: $e");
    }
  }

  Widget _buildCardOverlay() {
    return Center(
      child: Container(
        width: 250, 
        height: 350, 
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 3),
          borderRadius: BorderRadius.circular(15), 
        ),
      ),
    );
  }
}