// Fichier : lib/widgets/life_counter/player_zone.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart'; 
import '../../models/player_model.dart';
import '../../models/scryfall_card_model.dart'; 
import '../../services/local_card_service.dart'; 
// Import du sélecteur de versions pour choisir l'artwork
import '../cards/versions_selector_sheet.dart'; 

enum CounterMode { life, poison, energy, commanderTax }

class _FloatingNumber {
  final int id;
  final String text;
  final Color color;
  double top = 20.0;
  double opacity = 1.0;

  _FloatingNumber({required this.id, required this.text, required this.color});
}

class PlayerZone extends StatefulWidget {
  const PlayerZone({
    super.key,
    required this.player,
    required this.onLifeChanged, 
    required this.onShowCommanderDamage,
    required this.onColorChanged,
    this.onStatChanged, 
    this.onRotationChanged,
    this.onSkinChanged, 
    this.quarterTurns = 0,
    this.isCommander = false,
    this.isHighlighted = false,
  });

  final Player player;
  final int quarterTurns;
  final bool isCommander;
  final bool isHighlighted;
  final Function(int) onLifeChanged;
  final Function(String type, int val)? onStatChanged; 
  final Function(Color) onColorChanged;
  final Function(int)? onRotationChanged;
  final Function(String?)? onSkinChanged; 
  final VoidCallback onShowCommanderDamage;

  @override
  State<PlayerZone> createState() => _PlayerZoneState();
}

class _PlayerZoneState extends State<PlayerZone> {
  final List<_FloatingNumber> _floatingNumbers = [];
  final LocalCardService _localCardService = LocalCardService();
  
  int _nextNumberId = 0;
  CounterMode _editMode = CounterMode.life;
  Timer? _resetModeTimer;
  double _dragAccumulator = 0.0;
  Offset _lastLongPressPosition = Offset.zero;
  final double _rotationThreshold = 40.0;

  final List<Color> _colorOptions = [
    Colors.red.shade900, Colors.blue.shade900, Colors.green.shade800,
    Colors.grey.shade800, Colors.purple.shade900, Colors.orange.shade900,
    Colors.teal.shade900, Colors.pink.shade900, Colors.brown.shade800, 
    Colors.indigo.shade900, Colors.blueGrey.shade800, Colors.black
  ];

  @override
  void initState() {
    super.initState();
    // Préchauffage du service pour la recherche d'artwork
    if (!_localCardService.isLoaded) {
      _localCardService.loadLocalData();
    }
  }

  void _triggerChange(int change) {
    _resetAutoReturnTimer(); 
    if (_editMode == CounterMode.life) {
      widget.onLifeChanged(change);
      _showFloatingNumber(change, isLife: true);
    } else {
      setState(() {
        if (_editMode == CounterMode.poison) widget.player.poison = (widget.player.poison + change).clamp(0, 99);
        if (_editMode == CounterMode.energy) widget.player.energy = (widget.player.energy + change).clamp(0, 99);
        if (_editMode == CounterMode.commanderTax) widget.player.commanderCastCount = (widget.player.commanderCastCount + change).clamp(0, 99);
      });
      _showFloatingNumber(change, isLife: false);
      widget.onStatChanged?.call(_editMode.toString(), change);
    }
  }

  void _showFloatingNumber(int change, {bool isLife = true}) {
    final String text = (change > 0) ? '+$change' : '$change';
    Color color;
    if (isLife) {
      color = (change > 0) ? Colors.greenAccent : Colors.redAccent;
    } else {
      color = _getModeColor(_editMode);
    }
    
    final int id = _nextNumberId++;
    final number = _FloatingNumber(id: id, text: text, color: color);
    
    if(mounted) setState(() => _floatingNumbers.add(number));

    Timer(const Duration(milliseconds: 50), () {
      if(mounted) setState(() { number.top = -50.0; number.opacity = 0.0; });
    });

    Timer(const Duration(milliseconds: 600), () {
      if(mounted) setState(() => _floatingNumbers.removeWhere((n) => n.id == id));
    });
  }

  void _setEditMode(CounterMode mode) {
    setState(() => _editMode = mode);
    if (mode != CounterMode.life) {
      _resetAutoReturnTimer();
    } else {
      _resetModeTimer?.cancel();
    }
  }

  void _resetAutoReturnTimer() {
    _resetModeTimer?.cancel();
    if (_editMode != CounterMode.life) {
      _resetModeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _editMode = CounterMode.life);
      });
    }
  }

  Color _getModeColor(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison: return Colors.greenAccent; 
      case CounterMode.energy: return Colors.blueAccent; 
      case CounterMode.commanderTax: return Colors.amber; 
      default: return Colors.white;
    }
  }

  IconData _getModeIcon(CounterMode mode) {
    switch (mode) {
      case CounterMode.poison: return Icons.science; 
      case CounterMode.energy: return Icons.flash_on; 
      case CounterMode.commanderTax: return Icons.local_police; 
      default: return Icons.favorite; 
    }
  }

  String _getDisplayValue() {
    switch (_editMode) {
      case CounterMode.poison: return '${widget.player.poison}';
      case CounterMode.energy: return '${widget.player.energy}';
      case CounterMode.commanderTax: return '${widget.player.commanderCastCount}';
      default: return '${widget.player.life}';
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && widget.onSkinChanged != null) {
        widget.onSkinChanged!(image.path);
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Erreur image picker: $e");
    }
  }

  // --- OUVERTURE RECHERCHE ---
  void _openArtworkSearch() {
    Navigator.pop(context); // Fermer le menu couleur
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (context) => _ArtworkSearchModal(
        localCardService: _localCardService,
        onCardSelected: (ScryfallCard card) {
          // On génère l'URL "Art Crop" pour avoir l'illustration plein cadre
          final String artUrl = "https://api.scryfall.com/cards/${card.id}?format=image&version=art_crop";
          if (widget.onSkinChanged != null) {
            widget.onSkinChanged!(artUrl);
          }
        },
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("Personnalisation J${widget.player.id + 1}", style: GoogleFonts.cinzel(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Artwork
            ElevatedButton.icon(
              onPressed: _openArtworkSearch,
              icon: const Icon(Icons.palette, color: Colors.black),
              label: Text("Choisir un Artwork", style: GoogleFonts.cinzel(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow.shade800, foregroundColor: Colors.black),
            ),
            const SizedBox(height: 8),
            // Bouton Galerie
            OutlinedButton.icon(
              onPressed: _pickImage, 
              icon: const Icon(Icons.photo_library), 
              label: const Text("Depuis la galerie"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
            ),
            
            if (widget.player.backgroundImagePath != null)
               TextButton(
                 onPressed: () {
                   widget.onSkinChanged?.call(null); // Reset
                   Navigator.pop(ctx);
                 }, 
                 child: const Text("Supprimer l'image", style: TextStyle(color: Colors.redAccent))
               ),
            const Divider(color: Colors.white24),
            const Text("Couleur unie :", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12, runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colorOptions.map((c) => GestureDetector(
                onTap: () { widget.onColorChanged(c); Navigator.pop(ctx); },
                child: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(
                    color: c, 
                    shape: BoxShape.circle, 
                    border: Border.all(color: Colors.white54, width: 2),
                    boxShadow: [BoxShadow(color: c.withOpacity(0.5), blurRadius: 8)]
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      )
    );
  }

  void _rotate90Degrees() {
    if (widget.onRotationChanged != null) {
      final nextRot = (widget.player.quarterTurns + 1) % 4;
      widget.onRotationChanged!(nextRot);
      HapticFeedback.lightImpact();
    }
  }

  void _handleRotationDrag(double delta) {
    if (widget.onRotationChanged == null) return;
    _dragAccumulator += delta;
    if (_dragAccumulator.abs() > _rotationThreshold) {
      int direction = _dragAccumulator > 0 ? 1 : -1;
      int newRot = (widget.player.quarterTurns + direction) % 4;
      if (newRot < 0) newRot += 4; 
      widget.onRotationChanged!(newRot);
      HapticFeedback.mediumImpact(); 
      _dragAccumulator = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = Color(widget.player.colorValue);
    
    // --- GESTION DU SKIN ---
    DecorationImage? bgImage;
    if (widget.player.backgroundImagePath != null) {
      final String path = widget.player.backgroundImagePath!;
      
      ImageProvider? provider;
      if (path.startsWith('http')) {
        // Artwork Scryfall (URL)
        provider = NetworkImage(path);
      } else {
        // Galerie locale (Fichier)
        final file = File(path);
        if (file.existsSync()) {
          provider = FileImage(file);
        }
      }

      if (provider != null) {
        bgImage = DecorationImage(
          image: provider,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken),
        );
      }
    }

    Widget content = Container(
      decoration: BoxDecoration(
        color: bgColor,
        image: bgImage, // Application du skin
        borderRadius: BorderRadius.circular(18),
        border: widget.isHighlighted 
            ? Border.all(color: Colors.white, width: 4) 
            : Border.all(color: Colors.white12, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(2,2))]
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 1,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _triggerChange(-1),
                    onLongPress: () => _triggerChange(-5),
                    splashColor: Colors.black12,
                    child: Center(
                      child: FittedBox(child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.remove, color: Colors.white.withOpacity(0.6), size: 48))),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1, 
                child: GestureDetector(
                  onTap: () { if (_editMode != CounterMode.life) _setEditMode(CounterMode.life); },
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_editMode != CounterMode.life)
                          Icon(_getModeIcon(_editMode), color: _getModeColor(_editMode).withOpacity(0.8), size: 24),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _getDisplayValue(),
                              style: GoogleFonts.cinzel(
                                fontSize: 60, 
                                fontWeight: FontWeight.bold, 
                                color: _editMode == CounterMode.life ? Colors.white : _getModeColor(_editMode), 
                                shadows: [const Shadow(blurRadius: 5, color: Colors.black45)]
                              ),
                            ),
                          ),
                        ),
                        if (_editMode != CounterMode.life)
                          Text(
                            _editMode.name.toUpperCase().replaceAll('COMMANDERTAX', 'TAX'),
                            style: GoogleFonts.roboto(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _triggerChange(1),
                    onLongPress: () => _triggerChange(5),
                    splashColor: Colors.black12,
                    child: Center(
                      child: FittedBox(child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(Icons.add, color: Colors.white.withOpacity(0.6), size: 48))),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: _floatingNumbers.map((n) => AnimatedPositioned(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  top: n.top, 
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    opacity: n.opacity,
                    child: Text(n.text, style: GoogleFonts.cinzel(fontSize: 48, fontWeight: FontWeight.bold, color: n.color, shadows: [const Shadow(blurRadius: 4, color: Colors.black)])),
                  ),
                )).toList(),
              ),
            ),
          ),
          Positioned(
            top: 0, right: 0, 
            child: IconButton(
              icon: const Icon(Icons.palette, color: Colors.white24, size: 20),
              onPressed: _showColorPicker,
            ),
          ),
          Positioned(
            top: 0, left: 0, 
            child: GestureDetector(
              onTap: _rotate90Degrees,
              onLongPressStart: (details) {
                _dragAccumulator = 0.0;
                _lastLongPressPosition = details.localPosition;
                HapticFeedback.selectionClick();
              },
              onLongPressMoveUpdate: (details) {
                final double delta = details.localPosition.dx - _lastLongPressPosition.dx;
                _lastLongPressPosition = details.localPosition;
                _handleRotationDrag(delta);
              },
              child: Container(
                padding: const EdgeInsets.all(12), 
                color: Colors.transparent,
                child: const Icon(Icons.rotate_right, color: Colors.white24, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 8, left: 0, right: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniCounter(CounterMode.poison, widget.player.poison),
                  const SizedBox(width: 8),
                  _buildMiniCounter(CounterMode.energy, widget.player.energy),
                  if (widget.isCommander) ...[
                    const SizedBox(width: 8),
                    _buildMiniCounter(CounterMode.commanderTax, widget.player.commanderCastCount),
                    const SizedBox(width: 8),
                    _buildCmdDamageIndicator(),
                  ]
                ],
              ),
            ),
          ),
          if (widget.isHighlighted)
            Container(
              color: Colors.black45,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8)),
                child: Text("Start ?", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );

    return RotatedBox(
      quarterTurns: widget.player.quarterTurns,
      child: content,
    );
  }

  Widget _buildMiniCounter(CounterMode mode, int value) {
    final bool isActive = _editMode == mode;
    final Color color = _getModeColor(mode);
    final IconData icon = _getModeIcon(mode);
    final double opacity = (value > 0 || isActive) ? 1.0 : 0.7;

    return GestureDetector(
      onTap: () => _setEditMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.black54 : Colors.black26, 
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: color, width: 1) : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color.withOpacity(opacity)),
            const SizedBox(width: 4),
            Text("$value", style: TextStyle(color: color.withOpacity(opacity), fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCmdDamageIndicator() {
    return GestureDetector(
      onTap: widget.onShowCommanderDamage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.shield, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text('${widget.player.totalCommanderDamage}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- SOUS-WIDGET : MODALE DE RECHERCHE D'ARTWORK ---
class _ArtworkSearchModal extends StatefulWidget {
  final LocalCardService localCardService;
  final Function(ScryfallCard) onCardSelected;

  const _ArtworkSearchModal({required this.localCardService, required this.onCardSelected});

  @override
  State<_ArtworkSearchModal> createState() => _ArtworkSearchModalState();
}

class _ArtworkSearchModalState extends State<_ArtworkSearchModal> {
  final TextEditingController _controller = TextEditingController();
  List<ScryfallCard> _results = [];
  Timer? _debounce;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.trim().length >= 2) {
        // Utilisation du service local existant pour une recherche fluide
        final results = await widget.localCardService.searchCards(query: query); 
        if (mounted) {
          setState(() {
            _results = results.take(20).toList();
          });
        }
      } else {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  // --- OUVERTURE SELECTEUR VERSION ---
  void _openVersionSelector(ScryfallCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VersionsSelectorSheet(
        oracleId: card.oracleId,
        currentCardId: card.id,
        onVersionSelected: (version) {
           // 1. Ferme le sélecteur
           // (Le sélecteur se ferme lui-même après sélection, 
           // mais s'il ne le fait pas, ce n'est pas grave)
           
           // 2. Renvoie la carte choisie
           widget.onCardSelected(version);
           
           // 3. Ferme la modale de recherche (self)
           Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text("Choisir un Artwork", style: GoogleFonts.cinzel(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              style: GoogleFonts.cinzel(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Nom de la carte...",
                hintStyle: TextStyle(color: Colors.white30),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.black45,
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _results.isEmpty
                  ? Center(child: Text("Tapez le nom d'une carte", style: GoogleFonts.cinzel(color: Colors.white30)))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        childAspectRatio: 0.7, 
                        crossAxisSpacing: 8, 
                        mainAxisSpacing: 8
                      ),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final card = _results[index];
                        final imgUrl = card.smallImageUrl ?? '';
                        
                        return GestureDetector(
                          // Au clic, on ouvre le sélecteur de version pour choisir l'artwork précis
                          onTap: () => _openVersionSelector(card),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=>Container(color: Colors.grey.shade800)),
                                // Petit indicateur qu'il y a plusieurs versions
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    color: Colors.black54,
                                    child: const Icon(Icons.grid_view, size: 12, color: Colors.white70),
                                  ),
                                )
                              ],
                            ),
                          ),
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