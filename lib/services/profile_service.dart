// Fichier : lib/services/profile_service.dart

import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database/app_database.dart';
import '../models/profile_model.dart';

class ProfileService {
  static const _key = 'user_profiles';
  final AppDatabase? _db;

  ProfileService({AppDatabase? database}) : _db = database;

  Future<List<Profile>> loadProfiles() async {
    if (_db != null) {
      final dbProfiles = await _db!.getAllProfiles();
      return dbProfiles.map((p) => Profile(
        id: p.id,
        name: p.name,
        colorValue: p.colorValue,
        commanderScryfallId: p.commanderScryfallId,
        commanderName: p.commanderName,
        commanderArtCropUrl: p.commanderArtCropUrl,
        secondaryCommanderScryfallId: p.secondaryCommanderScryfallId,
        secondaryCommanderName: p.secondaryCommanderName,
        secondaryCommanderArtCropUrl: p.secondaryCommanderArtCropUrl,
      )).toList();
    }
    // Fallback SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => Profile.fromJson(e)).toList();
  }

  Future<void> saveProfile(Profile profile) async {
    if (_db != null) {
      await _db!.upsertProfile(ProfilesCompanion(
        id: Value(profile.id),
        name: Value(profile.name),
        colorValue: Value(profile.colorValue),
        commanderScryfallId: Value(profile.commanderScryfallId),
        commanderName: Value(profile.commanderName),
        commanderArtCropUrl: Value(profile.commanderArtCropUrl),
        secondaryCommanderScryfallId: Value(profile.secondaryCommanderScryfallId),
        secondaryCommanderName: Value(profile.secondaryCommanderName),
        secondaryCommanderArtCropUrl: Value(profile.secondaryCommanderArtCropUrl),
      ));
      return;
    }
    // Fallback SharedPreferences
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index != -1) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await _saveList(profiles);
  }

  Future<void> deleteProfile(String id) async {
    if (_db != null) {
      await _db!.deleteProfile(id);
      return;
    }
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveList(profiles);
  }

  Future<void> _saveList(List<Profile> profiles) async {
    if (_db != null) return;
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(profiles.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
