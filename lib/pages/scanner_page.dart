// Fichier : lib/pages/scanner_page.dart
// VERSION CORRIGÉE (Gère le cycle de vie de la caméra)

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

// Ajout de 'WidgetsBindingObserver'
class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // S'inscrire aux événements
    WidgetsBinding.instance.addObserver(this); 
    _initializeCamera();
  }

  // NOUVELLE FONCTION pour gérer les états de l'app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_controller == null) {
      return;
    }
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // La page n'est plus active (navigation vers l'historique)
      // On libère la caméra pour éviter le crash
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      // L'utilisateur revient sur la page du scanner
      // On ré-initialise la caméra
      _initializeCamera();
    }
  }

  /// Initialise (ou ré-initialise) le contrôleur de la caméra
  Future<void> _initializeCamera() async {
    // Nettoyer l'ancien contrôleur s'il existe
    if (_controller != null) {
      await _controller!.dispose();
    }
  
    var status = await Permission.camera.request();
    if (status.isGranted) {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        final firstCamera = cameras.first;
        _controller = CameraController(
          firstCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        setState(() {
          _initializeControllerFuture = _controller!.initialize();
        });
      }
    } else {
      print("Permission de la caméra refusée.");
      setState(() {
         _initializeControllerFuture = Future.error("Permission caméra refusée");
      });
    }
  }

  @override
  void dispose() {
    // Se désinscrire et nettoyer
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scanner', style: GoogleFonts.cinzel(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des scans',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScanHistoryPage()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData && _controller != null && _controller!.value.isInitialized) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller!),
                  _buildCardOverlay(),
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton(
                        onPressed: _onTakePicture,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        child: const Icon(Icons.camera),
                      ),
                    ),
                  ),
                ],
              );
            }
            if(snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Impossible d'initialiser la caméra. Veuillez vérifier les permissions dans les réglages de votre téléphone.",
                    style: GoogleFonts.cinzel(color: Colors.red.shade300, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Future<void> _onTakePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    try {
      final XFile picture = await _controller!.takePicture();
      if (!mounted) return; 
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