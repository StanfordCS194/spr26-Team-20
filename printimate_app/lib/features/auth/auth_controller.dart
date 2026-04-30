import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'user_profile_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthController {
  AuthController(this._auth, this._profiles);
  final FirebaseAuth _auth;
  final UserProfileRepository _profiles;

  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await cred.user!.updateDisplayName(displayName.trim());
      await cred.user!.reload();
    }
    final user = _auth.currentUser!;
    await _profiles.upsertFromAuth(user);
    return user;
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _profiles.upsertFromAuth(cred.user!);
    return cred.user!;
  }

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await _profiles.upsertFromAuth(cred.user!);
      return cred.user!;
    }
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(code: 'cancelled', message: 'Sign-in cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final oauth = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(oauth);
    await _profiles.upsertFromAuth(cred.user!);
    return cred.user!;
  }

  Future<User> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      final cred = await _auth.signInWithPopup(provider);
      await _profiles.upsertFromAuth(cred.user!);
      return cred.user!;
    }
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw FirebaseAuthException(
        code: 'unsupported',
        message: 'Apple sign-in is only supported on iOS, macOS, and web.',
      );
    }
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );
    final cred = await _auth.signInWithCredential(oauth);
    if (cred.user != null && (cred.user!.displayName ?? '').isEmpty) {
      final fullName = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
      if (fullName.isNotEmpty) await cred.user!.updateDisplayName(fullName);
    }
    final user = _auth.currentUser!;
    await _profiles.upsertFromAuth(user);
    return user;
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    final user = _auth.currentUser;
    if (user != null) {
      await _profiles.upsertFromAuth(user);
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut().catchError((_) => null);
    }
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(
    ref.watch(firebaseAuthProvider),
    ref.watch(userProfileRepositoryProvider),
  ),
);
