import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  const OnboardingState({this.name = '', this.printerId = '', this.friendIds = const []});
  final String name;
  final String printerId;
  final List<String> friendIds;

  bool get profileDone => name.trim().isNotEmpty;
  bool get printerDone => printerId.trim().isNotEmpty;

  OnboardingState copyWith({String? name, String? printerId, List<String>? friendIds}) =>
      OnboardingState(
        name: name ?? this.name,
        printerId: printerId ?? this.printerId,
        friendIds: friendIds ?? this.friendIds,
      );
}

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setName(String v) => state = state.copyWith(name: v);
  void setPrinterId(String v) => state = state.copyWith(printerId: v);
  void setFriends(List<String> ids) => state = state.copyWith(friendIds: ids);
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingState>(OnboardingController.new);
