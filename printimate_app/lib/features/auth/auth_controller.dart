import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

class AuthController {
  AuthController(this._auth);
  final FirebaseAuth _auth;

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
    return _auth.currentUser!;
  }

  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user!;
  }

  Future<User> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
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
    return cred.user!;
  }

  Future<User> signInWithApple() async {
    if (kIsWeb) {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      final cred = await _auth.signInWithPopup(provider);
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
    return _auth.currentUser!;
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      await GoogleSignIn().signOut().catchError((_) => null);
    }
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref.watch(firebaseAuthProvider)),
);
