// Fichier : lib/services/profile_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_model.dart';

class ProfileService {
  static const _key = 'user_profiles';

  Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_key);
    if (jsonStr == null) return [];
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => Profile.fromJson(e)).toList();
  }

  Future<void> saveProfile(Profile profile) async {
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
    final profiles = await loadProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveList(profiles);
  }

  Future<void> _saveList(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(profiles.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}