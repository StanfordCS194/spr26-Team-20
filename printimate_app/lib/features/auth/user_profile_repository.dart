import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

class UserProfileRepository {
  UserProfileRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  Future<bool> isUsernameTaken(String username) async {
    final snap = await _users
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
  Future<void> setUsername(String uid, String username) async {
    await _users.doc(uid).update({'username': username});
  }
  Future<void> upsertFromAuth(User user) async {
    final doc = _users.doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final snap = await doc.get();
    
    final isNew = !snap.exists;
    String? defaultUsername;
    if (isNew) {
      final base = (user.displayName?.replaceAll(' ', '').toLowerCase() ??
              user.email?.split('@').first.toLowerCase() ??
              'user')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
      final suffix = user.uid.substring(0, 4);
      defaultUsername = '${base}_$suffix';
    }


    final data = <String, dynamic>{
      'uid': user.uid,
      if (isNew && defaultUsername != null) 'username': defaultUsername,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'phoneNumber': user.phoneNumber,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
      'providerIds': user.providerData.map((p) => p.providerId).toList(),
      'tenantId': user.tenantId,
      'updatedAt': now,
      'lastSignInAt': now,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
    
    await doc.set(data, SetOptions(merge: true));
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(firestoreProvider)),
);
