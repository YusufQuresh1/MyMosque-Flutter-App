import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mymosque/components/button.dart'; // Reusable button component.
import 'package:mymosque/components/text_field.dart'; // Reusable text field component.
import 'package:mymosque/services/auth/auth_service.dart'; // Service handling authentication logic.

/// The login page, allowing users to sign in via email/password or Google.
class LoginPage extends StatefulWidget {
  /// Callback function triggered when the user taps the "Register now" text.
  /// Used to switch to the registration page.
  final void Function()? onTap;

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  
  final _auth = AuthService();                                            /// Instance of the authentication service.
  final TextEditingController emailController = TextEditingController();  /// Controller for the email input field.
  final TextEditingController pwController = TextEditingController();     /// Controller for the password input field.

  /// Adapted from Mitch Koko's tutorial login logic (email/password auth with timeout):
  /// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6
  /// Extended by Mohammed Qureshi:
  /// - Firestore profile existence check (prevents access without registration)
  /// - Clean error dialog messaging
  /// - Removed loading spinner logic (restructured navigation flow)
  /// 
  /// Attempts to log in the user using email and password.
  /// Displays an error dialog if login fails or if the user profile doesn't exist in Firestore.
  void login() async {
    try {
      // Attempt email/password sign-in via AuthService.
      final userCredential = await _auth.loginEmailPassword(
        emailController.text.trim(),
        pwController.text.trim(),
      ).timeout(const Duration(seconds: 10)); // Add timeout to prevent indefinite loading.

      // After successful Firebase Auth login, verify the user profile exists in Firestore.
      if (userCredential.user != null) {
        final uid = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection("Users")
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 5)); // Timeout for Firestore read.

        // If the Firestore document doesn't exist, treat it as an error.
        // This prevents users who only completed Firebase Auth registration (but not profile creation) from logging in.
        if (!userDoc.exists) {
          throw Exception("No user profile found. Please register first.");
        }
        // If both Firebase Auth and Firestore profile check pass, login is successful (handled by AuthGate).
      }
    } catch (e) {
      // Display any errors (Firebase Auth errors, Firestore errors, timeouts, custom exceptions) in a dialog.
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Login Error"),
            // Display the specific error message, cleaning up the "Exception: " prefix.
            content: Text(e.toString().replaceFirst("Exception: ", "")),
          ),
        );
      }
    }
  }

  /// Handles the Google Sign-In process.
  /// Creates a basic user profile in Firestore if the user is signing in for the first time via Google.
  Future<void> handleGoogleSignIn() async {
    try {
      // Initiate Google Sign-In flow via AuthService.
      final userCredential = await _auth.signInWithGoogle();

      if (userCredential?.user != null) {
        final user = userCredential.user!;
        final uid = user.uid;
        final email = user.email ?? '';
        final displayName = user.displayName ?? '';
        // Generate a default username from the email prefix.
        final username = email.split('@')[0];

        // Check if a user profile already exists in Firestore for this Google user.
        final userDocRef = FirebaseFirestore.instance.collection("Users").doc(uid);
        final userDoc = await userDocRef.get().timeout(const Duration(seconds: 5));

        // If no profile exists, create a new one with basic information from Google.
        if (!userDoc.exists) {
          await userDocRef.set({
            'uid': uid,
            'email': email,
            'username': username,
            'name': displayName, // Use Google display name as default name.
            'bio': '', // Default empty bio.
            'gender': '', // Default empty gender.
            'userType': 'user', // Default user type.
          });
          // Login proceeds automatically after profile creation (handled by AuthGate).
        }
        // If profile exists, login proceeds automatically.
      } else {
        throw Exception("Google sign-in failed or was cancelled. Please try again.");
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Google Sign-In Failed"),
            content: Text(e.toString().replaceFirst("Exception: ", "")),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true, // Ensure UI resizes when keyboard appears.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Allow dismissing keyboard by dragging down.
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 25, right: 25,
                // Adjust bottom padding based on keyboard visibility.
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                top: 30,
              ),
              child: ConstrainedBox(
                // Ensure the content takes at least the full viewport height.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight( // Ensure Column children stretch vertically if needed.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- Proof of Concept Banner ---
                      // This banner provides important context for users testing the app.
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Text(
                          "⚠️ This app is a proof of concept and not ready for production. "
                          "Features may be incomplete, experimental, or subject to change.",
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // --- App Logo/Icon ---
                      Icon(Icons.mosque, size: 80, color: colorScheme.tertiary),
                      const SizedBox(height: 30),
                      Text(
                        "Salaam, please login to continue",
                        style: TextStyle(color: colorScheme.primary, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),

                      // --- Google Sign-In Button ---
                      ElevatedButton(
                        onPressed: handleGoogleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // Standard Google button style.
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50), // Full width button.
                          side: BorderSide(color: Colors.grey.shade300),
                          elevation: 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google logo asset.
                            Image.asset('assets/images/google_logo.png', height: 24),
                            const SizedBox(width: 12),
                            const Text("Sign in with Google"),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // --- "Or" Divider ---
                      Row(
                        children: [
                          Expanded(child: Divider(thickness: 1, color: colorScheme.primary)),
                          const SizedBox(width: 10),
                          Text("or login with email", style: TextStyle(color: colorScheme.primary, fontStyle: FontStyle.italic)),
                          const SizedBox(width: 10),
                          Expanded(child: Divider(thickness: 1, color: colorScheme.primary)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- Email Field ---
                      const Align(alignment: Alignment.centerLeft, child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 5),
                      MyTextField(controller: emailController, hintText: "Enter email", obscureText: false),
                      const SizedBox(height: 20),

                      // --- Password Field ---
                      const Align(alignment: Alignment.centerLeft, child: Text("Password", style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(height: 5),
                      MyTextField(controller: pwController, hintText: "Enter password", obscureText: true),
                      const SizedBox(height: 30),

                      // --- Login Button ---
                      MyButton(text: "Login", onTap: login),
                      const SizedBox(height: 20),

                      // --- Register Link ---
                      GestureDetector(
                        onTap: widget.onTap, // Triggers the callback to switch pages.
                        child: Text("Don't have an account? Register now", style: TextStyle(color: colorScheme.primary)),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
