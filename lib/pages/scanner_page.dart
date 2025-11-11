// Fichier : lib/pages/scanner_page.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:magic_companion/pages/card_detail_page.dart';
import 'package:permission_handler/permission_handler.dart';

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
    // On démarre l'initialisation de la caméra dès que la page est chargée
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Étape 1 : Demander la permission
    var status = await Permission.camera.request();
    if (status.isGranted) {
      // Étape 2 : Obtenir la liste des caméras
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Sélectionner la première caméra (généralement celle de dos)
        final firstCamera = cameras.first;

        // Étape 3 : Créer et initialiser le contrôleur
        _controller = CameraController(
          firstCamera,
          ResolutionPreset.high, // On veut une haute résolution pour l'OCR
          enableAudio: false, // On n'a pas besoin du son
        );

        // L'initialisation retourne un Future, qu'on stocke
        setState(() {
          _initializeControllerFuture = _controller!.initialize();
        });
      }
    } else {
      // Gérer le cas où l'utilisateur refuse la permission
      // Pour l'instant, on ne fait rien, mais on pourrait afficher un message
      print("Permission de la caméra refusée.");
    }
  }

  @override
  void dispose() {
    // TRÈS IMPORTANT : Libérer les ressources de la caméra
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fond noir pour la page de scan
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && _controller != null && _controller!.value.isInitialized) {
            // ----- Si la caméra est prête, on l'affiche -----
            return Stack(
              fit: StackFit.expand,
              children: [
                // La prévisualisation de la caméra
                CameraPreview(_controller!),
                
                // (Optionnel) Un cadre pour aider l'utilisateur à centrer la carte
                _buildCardOverlay(),

                // Le bouton pour prendre la photo
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
            // ----- Sinon, on affiche un indicateur de chargement -----
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  // Une fonction pour prendre la photo
  Future<void> _onTakePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      // Prend la photo et la stocke en mémoire
      final XFile picture = await _controller!.takePicture();

      // Vérifie si le widget est toujours monté avant de naviguer
      if (!mounted) return; 

      // NAVIGUE vers la page de résultats en passant le chemin de la photo
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

  // Un widget d'aide visuelle (cadre)
  Widget _buildCardOverlay() {
    return Center(
      child: Container(
        width: 250, // Largeur approx. d'une carte
        height: 350, // Hauteur approx. d'une carte
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.7), width: 3),
          borderRadius: BorderRadius.circular(15), // Bords arrondis
        ),
      ),
    );
  }
}