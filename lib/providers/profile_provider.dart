// Fichier : lib/providers/profile_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import 'service_providers.dart';

class ProfileNotifier extends AsyncNotifier<List<Profile>> {
  @override
  Future<List<Profile>> build() async {
    final service = ref.read(profileServiceProvider);
    return service.loadProfiles();
  }

  Future<void> saveProfile(Profile profile) async {
    final service = ref.read(profileServiceProvider);
    await service.saveProfile(profile);
    ref.invalidateSelf();
  }

  Future<void> deleteProfile(String id) async {
    final service = ref.read(profileServiceProvider);
    await service.deleteProfile(id);
    ref.invalidateSelf();
  }

  Future<void> reload() async {
    ref.invalidateSelf();
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, List<Profile>>(
  ProfileNotifier.new,
);
