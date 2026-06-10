import 'package:cloud_firestore/cloud_firestore.dart';

// Get list of printer IDs for a given user
Future<List<String>> fetchPrintersList(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists) {
    throw Exception('User not found');
  }

  final data = doc.data();
  final ownedPids = List<String>.from(data?['ownedPids'] ?? []);
  final friendedPids = List<String>.from(data?['friendedPids'] ?? []);

  final printerIds = {...ownedPids, ...friendedPids}.toList();

  if (printerIds.isEmpty) {
    return ['printer1']; // fallback
  }

  return printerIds;
}

/// A printer the user can see, tagged with whether they own it (vs. were
/// granted access to a friend's printer).
class PrinterEntry {
  final String pid;
  final bool owned;
  const PrinterEntry({required this.pid, required this.owned});
}

/// Like [fetchPrintersList] but preserves whether each printer is owned or
/// friended, so the UI can offer a "remove" action on friended printers only.
Future<List<PrinterEntry>> fetchPrintersDetailed(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!doc.exists) {
    throw Exception('User not found');
  }

  final data = doc.data();
  final ownedPids = List<String>.from(data?['ownedPids'] ?? []);
  final friendedPids = List<String>.from(data?['friendedPids'] ?? []);

  final entries = <PrinterEntry>[];
  final seen = <String>{};
  for (final pid in ownedPids) {
    if (seen.add(pid)) entries.add(PrinterEntry(pid: pid, owned: true));
  }
  for (final pid in friendedPids) {
    if (seen.add(pid)) entries.add(PrinterEntry(pid: pid, owned: false));
  }
  return entries;
}

/// Removes a friend's printer from the current user's accessible list by
/// dropping it from their `friendedPids`. The user owns this document, so this
/// is an atomic, self-authorized write (no server round-trip needed).
Future<void> removeFriendedPrinter(String uid, String pid) async {
  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'friendedPids': FieldValue.arrayRemove([pid]),
  });
}

// Check if a printer exists
Future<bool> fetchPrinterExists(String pid) async {
  final doc = await FirebaseFirestore.instance
      .collection('printers')
      .doc(pid)
      .get();

  return doc.exists;
}

Future<List<Map<String, dynamic>>> fetchFriendRequests(String uid) async {
  // Get the user's owned printers
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();

  if (!userDoc.exists) throw Exception('User not found');

  final ownedPids = List<String>.from(userDoc.data()?['ownedPids'] ?? []);

  if (ownedPids.isEmpty) return [];

  // Fetch permission requests for each owned printer
  final results = <Map<String, dynamic>>[];

  for (final pid in ownedPids) {
    final requestDoc = await FirebaseFirestore.instance
        .collection('permissionRequests')
        .doc(pid)
        .get();

    if (requestDoc.exists) {
      final fromUids = List<String>.from(requestDoc.data()?['fromUid'] ?? []);
      for (final requesterUid in fromUids) {
        results.add({'pid': pid, 'requesterUid': requesterUid});
      }
    }
  }

  return results;
}
// Future<bool> friendRequestExists(String uid, String pid) async {
//   final doc = await FirebaseFirestore.instance
//       .collection('permissionRequests')
//       .doc(pid)
//       .get();
//   if (!doc.exists) return false;
//   final fromUids = List<String>.from(doc.data()?['fromUid'] ?? []);
//   return fromUids.contains(uid);
// }

Future<String> fetchUsername(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  if (!doc.exists) return uid; // fallback to uid if not found
  return doc.data()?['username'] as String? ?? uid;
}

Future<List<Map<String, dynamic>>> fetchSentFriendRequests(String uid) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('permissionRequests')
      .get();
  final results = <Map<String, dynamic>>[];
  for (final doc in snapshot.docs) {
    final fromUids = List<String>.from(doc.data()['fromUid'] ?? []);
    if (fromUids.contains(uid)) {
      results.add({'pid': doc.id});
    }
  }
  return results;
}