// Fichier : lib/pages/scanner_page.dart
// VERSION MISE À JOUR (avec AppBar et lien vers l'Historique)

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // <-- 1. AJOUT DE L'IMPORT
import 'package:magic_companion/pages/card_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scan_history_page.dart'; // <-- 2. AJOUT DE L'IMPORT

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // ... (Logique inchangée) ...
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
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      
      // --- 3. AJOUT DE L'APPBAR ---
      appBar: AppBar(
        title: Text(
          'Scanner',
          style: GoogleFonts.cinzel(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black.withOpacity(0.5), // Semi-transparent
        elevation: 0, // Pas d'ombre
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Historique des scans',
            onPressed: () {
              // Navigation vers notre nouvelle page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScanHistoryPage()),
              );
            },
          ),
        ],
      ),
      // --- FIN DE L'AJOUT ---

      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _controller != null && _controller!.value.isInitialized) {
            // ... (Reste de la page inchangé) ...
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
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<void> _onTakePicture() async {
    // ... (Logique inchangée) ...
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
    // ... (Logique inchangée) ...
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