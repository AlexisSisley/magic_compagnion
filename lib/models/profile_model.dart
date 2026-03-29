import 'dart:convert';
import '../services/scryfall_api.dart';

/// A single commander entry in a profile's gallery.
class CommanderEntry {
  final String scryfallId;
  final String name;
  final String? artCropUrl;

  const CommanderEntry({
    required this.scryfallId,
    required this.name,
    this.artCropUrl,
  });

  String? get imageUrl {
    if (artCropUrl != null) return artCropUrl;
    return ScryfallApi.artCropRedirectUrl(scryfallId);
  }

  Map<String, dynamic> toJson() => {
    'scryfallId': scryfallId,
    'name': name,
    'artCropUrl': artCropUrl,
  };

  factory CommanderEntry.fromJson(Map<String, dynamic> json) => CommanderEntry(
    scryfallId: json['scryfallId'] as String,
    name: json['name'] as String,
    artCropUrl: json['artCropUrl'] as String?,
  );
}

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

  /// Gallery of saved commanders — allows quick artwork switching in-game.
  List<CommanderEntry> commanderGallery;

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
    this.commanderGallery = const [],
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
    'commanderGallery': commanderGallery.map((e) => e.toJson()).toList(),
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
    commanderGallery: (json['commanderGallery'] as List?)
        ?.map((e) => CommanderEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  /// Encodes commanderGallery as a JSON string for DB storage.
  String get commanderGalleryJson => json.encode(
    commanderGallery.map((e) => e.toJson()).toList(),
  );

  /// Decodes a JSON string into a list of CommanderEntry.
  static List<CommanderEntry> galleryFromJson(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => CommanderEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

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