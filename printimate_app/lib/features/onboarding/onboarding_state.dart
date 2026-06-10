import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/app_preferences.dart';

class OnboardingState {
  const OnboardingState({this.name = '', this.printerId = '', this.friendIds = const [], this.completed = false});
  final String name;
  final String printerId;
  final List<String> friendIds;
  final bool completed;

  bool get profileDone => name.trim().isNotEmpty;
  bool get printerDone => printerId.trim().isNotEmpty;

  OnboardingState copyWith({String? name, String? printerId, List<String>? friendIds, bool? completed}) =>
      OnboardingState(
        name: name ?? this.name,
        printerId: printerId ?? this.printerId,
        friendIds: friendIds ?? this.friendIds,
        completed: completed ?? this.completed,
      );
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final prefs = ref.read(appPreferencesProvider);
    // DEMO: default to the one working printer ('printer1') so users are never
    // force-routed into the BLE provisioning flow. Revert this fallback once
    // provisioning is demo-ready. See onboarding/provisioning skip notes.
    final saved = prefs.savedPrinterId;
    return OnboardingState(printerId: saved.isEmpty ? 'printer1' : saved);
  }

  void setName(String v) => state = state.copyWith(name: v);
  void setPrinterId(String v) {
    state = state.copyWith(printerId: v);
    ref.read(appPreferencesProvider).setSavedPrinterId(v);
  }
  void setFriends(List<String> ids) => state = state.copyWith(friendIds: ids);
  void complete() => state = state.copyWith(completed: true);
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);
