import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/user_profile_repository.dart';

/// A single pending request from another user to access one of your printers.
class IncomingRequest {
  final String pid;
  final String requesterUid;
  const IncomingRequest({required this.pid, required this.requesterUid});
}

/// Realtime stream of pending friend (printer-access) requests addressed to
/// printers the current user owns.
///
/// Listens directly to the `permissionRequests` documents for the user's owned
/// printers, so the badge/banner update live as requests are created, accepted,
/// or rejected — no manual refresh required.
final incomingRequestsProvider =
    StreamProvider.autoDispose<List<IncomingRequest>>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return Stream.value(const []);

  // React to ownedPids changes via the live user-profile doc.
  final profile = ref.watch(userProfileDocProvider(user.uid)).asData?.value;
  final ownedPids =
      List<String>.from(profile?.data()?['ownedPids'] ?? const []);
  if (ownedPids.isEmpty) return Stream.value(const []);

  // Firestore whereIn supports up to 30 values; demo users own only a few.
  final pids = ownedPids.take(30).toList();

  return ref
      .watch(firestoreProvider)
      .collection('permissionRequests')
      .where(FieldPath.documentId, whereIn: pids)
      .snapshots()
      .map((snap) {
    final requests = <IncomingRequest>[];
    for (final doc in snap.docs) {
      final fromUids = List<String>.from(doc.data()['fromUid'] ?? const []);
      for (final requesterUid in fromUids) {
        requests.add(IncomingRequest(pid: doc.id, requesterUid: requesterUid));
      }
    }
    return requests;
  });
});
