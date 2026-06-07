import 'package:shared_preferences/shared_preferences.dart';

class AppIntroRepository {
  static const _hasSeenIntroKey = 'has_seen_app_intro';

  Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenIntroKey) ?? false;
  }

  Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenIntroKey, true);
  }
}
