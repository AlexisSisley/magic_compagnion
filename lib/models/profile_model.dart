import '../services/scryfall_api.dart';

class Profile {
  final String id;
  String name;
  int colorValue;
  String? commanderScryfallId;
  String? commanderName;
  String? commanderArtCropUrl;
  // NOUVEAUX CHAMPS
  String? secondaryCommanderScryfallId;
  String? secondaryCommanderName;
  String? secondaryCommanderArtCropUrl;

  Profile({
    required this.id,
    required this.name,
    this.colorValue = 0xFF2196F3,
    this.commanderScryfallId,
    this.commanderName,
    this.commanderArtCropUrl,
    this.secondaryCommanderScryfallId,
    this.secondaryCommanderName,
    this.secondaryCommanderArtCropUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'commanderScryfallId': commanderScryfallId,
    'commanderName': commanderName,
    'commanderArtCropUrl': commanderArtCropUrl,
    'secondaryCommanderScryfallId': secondaryCommanderScryfallId,
    'secondaryCommanderName': secondaryCommanderName,
    'secondaryCommanderArtCropUrl': secondaryCommanderArtCropUrl,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'],
    name: json['name'],
    colorValue: json['colorValue'] ?? 0xFF2196F3,
    commanderScryfallId: json['commanderScryfallId'],
    commanderName: json['commanderName'],
    commanderArtCropUrl: json['commanderArtCropUrl'],
    secondaryCommanderScryfallId: json['secondaryCommanderScryfallId'],
    secondaryCommanderName: json['secondaryCommanderName'],
    secondaryCommanderArtCropUrl: json['secondaryCommanderArtCropUrl'],
  );

  /// URL art_crop : utilise l'URL directe stockée, sinon fallback sur le redirect endpoint.
  String? get commanderImageUrl {
    if (commanderArtCropUrl != null) return commanderArtCropUrl;
    if (commanderScryfallId == null) return null;
    return ScryfallApi.artCropRedirectUrl(commanderScryfallId!);
  }

  String? get secondaryCommanderImageUrl {
    if (secondaryCommanderArtCropUrl != null) return secondaryCommanderArtCropUrl;
    if (secondaryCommanderScryfallId == null) return null;
    return ScryfallApi.artCropRedirectUrl(secondaryCommanderScryfallId!);
  }
}