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
