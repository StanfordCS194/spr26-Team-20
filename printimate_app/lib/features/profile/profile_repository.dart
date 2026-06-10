import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/user_profile_repository.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (_) => FirebaseStorage.instance,
);

class ProfileRepository {
  ProfileRepository(this._auth, this._db, this._storage);
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentProfile() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser!;
    final trimmed = name.trim();
    await user.updateDisplayName(trimmed);
    await _db.collection('users').doc(user.uid).set(
      {'displayName': trimmed, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
  Future<void> updateUsername(String username) async {
    final user = _auth.currentUser!;

    if (user.uid == null) throw Exception('Not signed in');

    await _db.collection('users').doc(user.uid).set(
      {'username': username, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final ownedPids = List<String>.from(userDoc.data()?['ownedPids'] ?? []);
      if (ownedPids.isEmpty) return;

    final updatedPids = <String>[];

    for (final oldPid in ownedPids) {
      // Skip if already has a username suffix (idempotent)
      if (oldPid.contains('-$username')) {
        updatedPids.add(oldPid);
        continue;
      }

      final base = oldPid.contains('-')
        ? oldPid.substring(0, oldPid.lastIndexOf('-'))
        : oldPid;
      final newPid = '$base-$username';

      // 3. Copy printer doc to new ID
      final oldPrinterRef = _db.collection('printers').doc(oldPid);
      final newPrinterRef = _db.collection('printers').doc(newPid);

      final oldPrinterDoc = await oldPrinterRef.get();
      if (oldPrinterDoc.exists) {
        final data = Map<String, dynamic>.from(oldPrinterDoc.data()!);

        // 4. Copy messages subcollection
        final messagesSnap = await oldPrinterRef.collection('messages').get();

        final batch = _db.batch();
        batch.set(newPrinterRef, data);
        for (final msgDoc in messagesSnap.docs) {
          batch.set(
            newPrinterRef.collection('messages').doc(msgDoc.id),
            msgDoc.data(),
          );
        }
        // 5. Delete old printer doc (messages subcollection docs deleted separately)
        for (final msgDoc in messagesSnap.docs) {
          batch.delete(oldPrinterRef.collection('messages').doc(msgDoc.id));
        }
        batch.delete(oldPrinterRef);

        await batch.commit();
      }

      updatedPids.add(newPid);
    }

    // 6. Update ownedPids with new names
    await _db.collection('users').doc(user.uid).update({
      'ownedPids': updatedPids,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadAvatar(Uint8List bytes,
      {String contentType = 'image/jpeg'}) async {
    final user = _auth.currentUser!;
    final ref = _storage.ref('users/${user.uid}/avatar.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    await user.updatePhotoURL(url);
    await _db.collection('users').doc(user.uid).set(
      {'photoURL': url, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    return url;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  ),
);
