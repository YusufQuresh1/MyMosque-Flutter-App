import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mymosque/pages/home_page.dart';
import 'package:mymosque/pages/complete_profile_page.dart';
import 'package:mymosque/services/auth/login_or_register.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// This widget acts as the main entry point for handling authentication flow.
/// It listens to Firebase Authentication state changes and decides:
/// - whether to show the login/home page UI,
/// - complete the user's profile if needed,
/// - or proceed to the main HomePage.
///
/// This is injected as the home of the app in `main.dart`.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Determines the next screen based on the user's authentication and profile completion status.
  ///
  /// This method is called when Firebase confirms that a user is logged in.
  /// It:
  /// - Checks if the user exists in Firestore; creates a document if they don’t.
  /// - Updates their FCM token for push notifications.
  /// - Reschedules daily prayer time notifications for the user.
  ///   As FCM token is new, previously scheduled notifications will not be received so must be rescheduled to the new token
  /// - Decides whether to send the user to the HomePage or CompleteProfilePage.
  /// - Will go back to Login page if no user is logged in (i.e on Logout or Delete Account)
  Future<Widget> _handleAuth(User user, BuildContext context) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);

    // Forces a fresh ID token (to avoid users who may have used the same device getting incorrect notifications)
    await user.getIdToken(true);

    // Reference to the Firestore document for the authenticated user
    final userDocRef = FirebaseFirestore.instance.collection("Users").doc(user.uid);
    var doc = await userDocRef.get();

    // If this is a new user, create their profile document
    if (!doc.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'username': user.email?.split('@')[0] ?? '',
        'name': user.displayName ?? '',
        'gender': '',
        'userType': 'user',
      });
      doc = await userDocRef.get();
    }

    // Only proceed with post-login logic if the authenticated user is still current
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == user.uid) {
      await db.updateFcmToken(user); // Store device token for push notifications
      await db.scheduleTodayPrayerNotificationsForUser(user.uid); // Schedule remaining prayer notifications for the day
    }

    // If the profile has a gender, profile is complete and go to home
    if ((doc.data()?['gender'] ?? '').toString().isNotEmpty) {
      return const HomePage();
    }

    // Otherwise, direct the user to complete their profile - when using Google to sign up as no gender is entered
    return CompleteProfilePage(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    
    // This StreamBuilder structure was used as a base from code by Mitch Koko:
    // https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=4
    // It has been heavily extended to include user document checks, profile completion flow, and notification setup.

    return StreamBuilder<User?>(  // Listen for authentication state changes via Firebase
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking auth state, show a loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // If user is logged in, run additional logic to verify profile and route
        if (user != null) {
          return FutureBuilder<Widget>(
            future: _handleAuth(user, context),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              } else if (futureSnapshot.hasError) {
                return const Scaffold(
                  body: Center(child: Text("Something went wrong.")),
                );
              } else {
                // Show the resolved page: Home or CompleteProfile
                return futureSnapshot.data ?? const LoginOrRegister();
              }
            },
          );
        } else {
          // If no user is logged in, show login/register page
          return const LoginOrRegister();
        }
      },
    );
  }
}
