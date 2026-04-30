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

  Future<void> upsertFromAuth(User user) async {
    final doc = _users.doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'uid': user.uid,
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
      'createdAt': FieldValue.serverTimestamp(),
    };

    final snap = await doc.get();
    if (snap.exists) {
      data.remove('createdAt');
    }
    await doc.set(data, SetOptions(merge: true));
  }
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(firestoreProvider)),
);
