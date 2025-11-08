// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Based on code by Mitch Koko from tutorial:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6
//
// Additions by Mohammed Qureshi:
// - Guard clause for `getCurrentUid()` to prevent null access
// - Deletes local FCM token during logout to prevent notification leaks
// - Google sign-in handling

/// A service class responsible for handling all authentication-related functionality
/// in the app, including email/password login, registration, Google Sign-In, 
/// and logout. It acts as a wrapper around Firebase Authentication, providing
/// error handling and simplifying usage in the UI.
class AuthService {
  final _auth = FirebaseAuth.instance;

  /// Returns the currently authenticated [User], or null if no user is logged in.
  User? getCurrentUser() => _auth.currentUser;

  /// Returns the UID of the currently logged-in user.
  /// Throws an exception if no user is logged in — used to enforce authentication in logic layers.
  String getCurrentUid() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in");
    }
    return user.uid;
  }

  /// Attempts to log in a user using Firebase Authentication with email and password.
  /// Returns a [UserCredential] on success.
  /// On failure, throws an exception with the Firebase error code for further handling in the UI.
  Future<UserCredential> loginEmailPassword(String email, password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return userCredential;
    }

    on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  /// Signs in a user using their Google account via OAuth.
  /// Retrieves the Google access token and ID token, then uses it to sign in via Firebase.
  /// This allows single-tap login for users who already have a Google account.
  signInWithGoogle() async {
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

    // Obtain the authentication tokens for the Google user
    final GoogleSignInAuthentication gAuth = await gUser!.authentication;

    // Create a Firebase credential from the tokens and sign in
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Registers a new user with an email and password using Firebase Authentication.
  /// Returns a [UserCredential] on success or throws an exception on failure.
  Future<UserCredential> registerEmailPassword(String email, password) async {
    try{
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return userCredential;
    }
    on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  /// Signs the user out of Firebase Authentication and deletes their FCM token from the device.
  /// The FCM token removal ensures that the device no longer receives notifications intended for that account after a logout.
  Future<void> logout() async {
    try {
      // Delete FCM token from the device
      await FirebaseMessaging.instance.deleteToken();
      print("FCM token deleted locally");
    } catch (e) {
      print("Error deleting FCM token: $e");
    }

    await FirebaseAuth.instance.signOut();
  }

}