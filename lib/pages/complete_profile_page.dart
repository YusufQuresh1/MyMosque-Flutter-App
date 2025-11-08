import 'package:flutter/material.dart';
import 'package:mymosque/components/button.dart';
import 'package:mymosque/components/text_field.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_service.dart';
import 'package:mymosque/pages/home_page.dart';

/// Page shown after initial authentication to collect essential user details.
/// As during Google Sign up there is not an input for gender, this page is used to add that to the user doc.
class CompleteProfilePage extends StatefulWidget {
  /// User details passed from the authentication process.
  final String uid;
  final String email;
  final String displayName;

  const CompleteProfilePage({
    super.key,
    required this.uid,
    required this.email,
    required this.displayName,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final TextEditingController nameController = TextEditingController();
  String? selectedGender; // Stores the selected gender ('male' or 'female').

  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    // Pre-fill name field with display name from authentication provider (e.g., Google).
    nameController.text = widget.displayName;
  }

  /// Validates inputs, saves profile data to Firestore, and navigates to HomePage.
  void submitProfile() async {
    if (selectedGender == null || nameController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text("Please fill out all fields."),
        ),
      );
      return;
    }

    // Calls database service to create/update the user's profile document.
    await _db.saveUserInfoInFirebase(
      email: widget.email,
      name: nameController.text.trim(),
      bio: '', // Default empty bio for new profiles.
      gender: selectedGender!,
    );

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomePage(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text("Complete Profile")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            MyTextField(controller: nameController, hintText: "Enter name", obscureText: false),
            const SizedBox(height: 20),

            const Text("Gender", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                //Gender radio buttons
                Expanded(
                  child: RadioListTile<String>(
                    title: Text("Male", style: TextStyle(color: selectedGender == "male" ? colorScheme.tertiary : colorScheme.primary)),
                    value: "male",
                    groupValue: selectedGender,
                    activeColor: colorScheme.tertiary,
                    onChanged: (val) => setState(() => selectedGender = val),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: Text("Female", style: TextStyle(color: selectedGender == "female" ? colorScheme.tertiary : colorScheme.primary)),
                    value: "female",
                    groupValue: selectedGender,
                    activeColor: colorScheme.tertiary,
                    onChanged: (val) => setState(() => selectedGender = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            MyButton(text: "Save & Continue", onTap: submitProfile),
            // Provides an option to log out if the user decides not to complete the profile at this stage.
            TextButton(
              onPressed: () async {
                await AuthService().logout();
                // AuthGate should handle navigation back to login after logout.
              },
              child: const Text("Log out"),
            )
          ],
        ),
      ),
    );
  }
}
