import 'package:flutter/material.dart';
import 'package:mymosque/components/button.dart';
import 'package:mymosque/components/text_field.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/pages/home_page.dart';
import 'package:mymosque/services/database/database_service.dart';

/// This page handles the user registration flow.
/// Users can register via email/password or Google Sign-In,
/// and are required to provide their name and gender (used for event filtering).
///
/// After successful registration, users are redirected to the HomePage,
/// and their information is stored in Firestore via [DatabaseService].
class RegisterPage extends StatefulWidget {
  /// Callback that switches to the login page when tapped.
  final void Function()? onTap;

  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Services for auth and Firestore access
  final _auth = AuthService();
  final _db = DatabaseService();

  // Controllers for form fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmPwController = TextEditingController();

  // User-selected gender (required)
  String? _selectedGender; // "male" or "female"

  /// Handles manual email/password registration.
  /// Validates input and saves user data in Firestore.
  /// If successful, user is redirected to the [HomePage].
  void register() async {
    if (_selectedGender == null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(title: Text("Please select a gender.")),
      );
      return;
    }

    if (pwController.text == confirmPwController.text) {

      try {
        await _auth.registerEmailPassword(
          emailController.text,
          pwController.text,
        );

        if (mounted) {
          // Go to home after successful registration.
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        }

        // Store user profile info in Firestore
        await _db.saveUserInfoInFirebase(
          email: emailController.text,
          name: nameController.text,
          bio: '',
          gender: _selectedGender!,
        );
      } catch (e) {
        // Display error message on failure
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(title: Text(e.toString())),
          );
        }
      }
    } else {
      // Alert if passwords don’t match
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(title: Text("Passwords do not match")),
      );
    }
  }

  /// Handles the Google Sign-In flow.
  /// Relies on AuthGate to detect and handle the login state post-auth.
  Future<void> handleGoogleSignIn() async {

    try {
      final userCredential = await _auth.signInWithGoogle();

      if (userCredential?.user != null) {
        if (mounted) {} // No navigation here — handled by AuthGate
      } else {
        throw Exception("Google sign-in failed.");
      }
    } catch (e) {
      // Show dialog if Google sign-in fails
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Google Sign-In Failed"),
            content: Text(e.toString()),
          ),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: colorScheme.surface,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 25,
                  right: 25,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                  top: 30,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // App icon and welcome message
                        Center(child: Icon(Icons.mosque, size: 80, color: colorScheme.tertiary)),
                        const SizedBox(height: 30),
                        Center(
                          child: Text(
                            "Salaam, join us today and stay connected with your masjid.",
                            style: TextStyle(color: colorScheme.primary, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 30),

                        /// Google sign-in button with logo and fallback border
                        ElevatedButton(
                          onPressed: handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(50),
                            side: BorderSide(color: Colors.grey.shade300),
                            elevation: 1,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google_logo.png', height: 24),
                              const SizedBox(width: 12),
                              const Text("Sign up with Google"),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// Divider with label between social and manual sign-up
                        Row(
                          children: [
                            Expanded(child: Divider(thickness: 1, color: colorScheme.primary)),
                            const SizedBox(width: 10),
                            Text("or create account manually", style: TextStyle(color: colorScheme.primary, fontStyle: FontStyle.italic)),
                            const SizedBox(width: 10),
                            Expanded(child: Divider(thickness: 1, color: colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ---------------- Form Inputs ----------------
                        const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        MyTextField(controller: nameController, hintText: "Enter name", obscureText: false),
                        const SizedBox(height: 10),

                        const Text("Gender", style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text("Male", style: TextStyle(color: _selectedGender == "male" ? colorScheme.tertiary : colorScheme.primary)),
                                value: "male",
                                groupValue: _selectedGender,
                                activeColor: colorScheme.tertiary,
                                onChanged: (value) => setState(() => _selectedGender = value),
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: Text("Female", style: TextStyle(color: _selectedGender == "female" ? colorScheme.tertiary : colorScheme.primary)),
                                value: "female",
                                groupValue: _selectedGender,
                                activeColor: colorScheme.tertiary,
                                onChanged: (value) => setState(() => _selectedGender = value),
                              ),
                            ),
                          ],
                        ),

                        const Text("Email", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        MyTextField(controller: emailController, hintText: "Enter email", obscureText: false),
                        const SizedBox(height: 20),

                        const Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        MyTextField(controller: pwController, hintText: "Enter password", obscureText: true),
                        const SizedBox(height: 20),

                        const Text("Confirm Password", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        MyTextField(controller: confirmPwController, hintText: "Confirm password", obscureText: true),
                        const SizedBox(height: 30),

                        // Create account button
                        MyButton(text: "Create Account", onTap: register),
                        const SizedBox(height: 15),

                        // Switch to login flow
                        Center(
                          child: GestureDetector(
                            onTap: widget.onTap,
                            child: Text("Already have an account? Login now", style: TextStyle(color: colorScheme.primary)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }


}
