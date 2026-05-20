import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeenIntroTour = 'seen_intro_tour_v1';

class AppPreferences {
  AppPreferences(this._prefs);
  final SharedPreferences _prefs;

  bool get hasSeenIntroTour => _prefs.getBool(_kSeenIntroTour) ?? false;
  Future<void> markIntroTourSeen() => _prefs.setBool(_kSeenIntroTour, true);
  Future<void> clearAll() => _prefs.clear();
}

final appPreferencesProvider = Provider<AppPreferences>((_) {
  throw UnimplementedError('appPreferencesProvider must be overridden in main()');
});
