import 'package:flutter/foundation.dart';

import '../data/profile_repository.dart';
import '../models/profile.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository);

  final ProfileRepository _repository;
  Profile _profile = Profile.empty;
  bool _loaded = false;

  Profile get profile => _profile;
  bool get loaded => _loaded;

  Future<void> load() async {
    _profile = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> completeOnboarding({required String name, required String level}) async {
    _profile = Profile(name: name, level: level, onboardingComplete: true);
    await _repository.save(_profile);
    notifyListeners();
  }
}
