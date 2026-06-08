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

// Check if a printer exists
Future<bool> fetchPrinterExists(String pid) async {
  final doc = await FirebaseFirestore.instance
      .collection('printers')
      .doc(pid)
      .get();

  return doc.exists;
}