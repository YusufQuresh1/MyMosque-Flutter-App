import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mymosque/components/loading_circle.dart';
import 'package:mymosque/components/settings_tile.dart';
import 'package:mymosque/components/input_alert_box.dart';
import 'package:mymosque/services/auth/auth_gate.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// AccountSettingsPage allows users to manage personal account details.
/// 
/// Features include:
/// - Updating display name and bio
/// - Changing password (for email/password users)
/// - Deleting the account (with reauthentication)
/// 
/// Supports both email/password and Google sign-in accounts.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final nameController = TextEditingController();       // Controller for name input field in update dialog
  final bioController = TextEditingController();        // Controller for bio input field in update dialog
  final passwordController = TextEditingController();   // Controller for password change dialog

  bool isPasswordUser = false;    // Used to determine if the current user signed in with email/password (vs Google)

  @override
  void initState() {
    super.initState();
    checkProviderType(); // Determine if this user can change password
  }

  /// Checks whether the currently signed-in user uses the email/password provider
  /// This affects whether the "Change Password" option is shown
  Future<void> checkProviderType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (final info in user.providerData) {
        if (info.providerId == 'password') {
          setState(() {
            isPasswordUser = true;
          });
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void safePopDialog() {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  /// Utility method to safely pop any open dialog (used in multiple actions)
  /// Opens a dialog allowing the user to update their display name.
  /// Saves the new name to Firestore through the DatabaseProvider.
  void _showNameDialog(DatabaseProvider db) {
    showDialog(
      context: context,
      builder: (_) => MyInputAlertBox(
        textController: nameController,
        hintText: "Enter your new name",
        onPressedText: "Update",
        onPressed: () async {
          await db.updateUserName(nameController.text.trim());
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Name updated.")),
          );
          safePopDialog();
        },
      ),
    );
  }

  /// Opens a dialog allowing the user to update their bio.
  /// Bio is saved to the user's Firestore profile document.
  void _showBioDialog(DatabaseProvider db) {
    showDialog(
      context: context,
      builder: (_) => MyInputAlertBox(
        textController: bioController,
        hintText: "Enter your new bio",
        onPressedText: "Update",
        onPressed: () async {
          await db.updateUserBio(bioController.text.trim());
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bio updated.")),
          );
          safePopDialog();
        },
      ),
    );
  }

  /// Opens a form allowing the user to change their password (email/password users only).
  /// Requires current password for reauthentication before allowing password change.
  void _showPasswordDialog(DatabaseProvider db) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Enter current password",
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.inversePrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Enter new password",
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.inversePrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Confirm new password",
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.inversePrimary),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: safePopDialog,
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final currentPassword = currentPasswordController.text.trim();
              final newPassword = newPasswordController.text.trim();
              final confirmPassword = confirmPasswordController.text.trim();

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("New passwords do not match.")),
                );
                return;
              }

              try {
                final uid = AuthService().getCurrentUid();
                final user = await db.userProfile(uid);
                if (user == null) throw Exception("User not found");

                // Reauthenticate before changing password
                final credential = EmailAuthProvider.credential(
                  email: user.email,
                  password: currentPassword,
                );

                await FirebaseAuth.instance.currentUser!
                    .reauthenticateWithCredential(credential);

                await db.updateUserPassword(newPassword);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated.")),
                );
                /// Utility method to safely pop any open dialog 
                safePopDialog();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Change"),
          ),
        ],
      ),
    );
  }

/// Prompts the user to confirm and securely delete their account.
///
/// This handles both email/password users and Google sign-in users:
/// - Email/password users are reauthenticated using their current password
/// - Google users are reauthenticated using their Google credentials
/// 
/// After reauthentication, calls deleteUserAccount to remove user data,
/// signs them out, and navigates them back to the login screen.
/// 
/// Includes full error handling, loading feedback, and safety guards.
void _confirmDeleteAccount(DatabaseProvider db) {
  final user = FirebaseAuth.instance.currentUser;
  final providerId = user?.providerData.first.providerId;

  // Handle email/password users with password confirmation before deleting - Firebase requirement
  if (providerId == 'password') {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Password"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: "Enter your password",
          ),
        ),
        actions: [
          TextButton(
            onPressed: safePopDialog,
            child: const Text("Cancel"),
          ),
          TextButton(
            child: const Text("Continue", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              final password = passwordController.text.trim();
              safePopDialog();
              showLoadingCircle(context);

              try {
                final email = user!.email!;
                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: password,
                );

                // Reauthenticate before deletion
                await user.reauthenticateWithCredential(credential);
                await db.deleteUserAccount(); // Deletes from Firestore/Auth
                if (!mounted) return;
                hideLoadingCircle(context);
                // Navigate to login screen and remove all previous routes
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                hideLoadingCircle(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  } 
  // Handle Google Sign-In
  else {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text("Are you sure you want to permanently delete your account?"),
        actions: [
          TextButton(onPressed: safePopDialog, child: const Text("Cancel")),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              safePopDialog();
              showLoadingCircle(context);

              try {
                // Attempt to reauthenticate using Google credentials
                final googleUser = await GoogleSignIn().signIn();
                final googleAuth = await googleUser?.authentication;
                final credential = GoogleAuthProvider.credential(
                  idToken: googleAuth?.idToken,
                  accessToken: googleAuth?.accessToken,
                );

                await user!.reauthenticateWithCredential(credential);
                await db.deleteUserAccount();
                if (!mounted) return;
                hideLoadingCircle(context);
                // Navigate to AuthGate
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                hideLoadingCircle(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    // Access the app’s database provider (used for updating user fields)
    final db = Provider.of<DatabaseProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Account Settings")),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          // ====== Update Display Name ======
          MySettingsTile(
            title: "Edit Name",
            action: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showNameDialog(db),
            ),
          ),
          // ====== Update Bio/Description ======
          MySettingsTile(
            title: "Edit Bio",
            action: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showBioDialog(db),
            ),
          ),
          // ====== Password Reset Option (only shown if using email/password sign-in) ======
          if (isPasswordUser)
            MySettingsTile(
              title: "Change Password",
              action: IconButton(
                icon: const Icon(Icons.lock),
                onPressed: () => _showPasswordDialog(db),
              ),
            ),
          const Divider(),
          // ====== Account Deletion Button ======
          MySettingsTile(
            title: "Delete Account",
            action: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteAccount(db),
            ),
          ),
        ],
      ),
    );
  }
}
