import 'package:flutter/material.dart';
import 'package:mymosque/components/settings_tile.dart';
import 'package:mymosque/pages/account_settings.dart';
import 'package:mymosque/pages/create_mosque_application_page.dart';
import 'package:mymosque/pages/approve_applications_page.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:mymosque/services/database/database_service.dart';
import 'package:mymosque/themes/theme_provider.dart';
import 'package:provider/provider.dart';

// Original structue based on Mitch Koko’s settings page structure.
// https://www.youtube.com/watch?v=q8m_fSYqx0w
//
// Extended by Mohammed Qureshi:
// - Implemented admin-only settings (Approve Applications)
// - Added Account Settings and Register Mosque buttons
// - Integrated logout with state clearing and confirmation


/// A user settings screen that allows configuration of UI preferences, account information,
/// logout, and (if admin) mosque application approval access.
///
/// The options on this screen adapt dynamically based on the user's role (e.g. system admin).
/// It uses a custom reusable [MySettingsTile] widget for consistent layout.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// Used to track whether the current user has admin privileges.
  /// Admins are shown additional options such as "Approve Mosque Applications".
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    checkAdminStatus(); // Check user role on load
  }

  /// Checks the current user's type by fetching their profile from Firestore.
  /// If the user is marked as an admin, updates the local state to display admin-only options.
  Future<void> checkAdminStatus() async {
    final uid = AuthService().getCurrentUid(); // Get current user's UID
    final user = await DatabaseService().getUserFromFirebase(uid); // Fetch user profile

    // Only show admin options if user exists and has role set as 'admin'
    if (user != null && user.userType == 'admin') {
      setState(() => isAdmin = true);
    }
  }

  /// Handles the logout flow.
  /// Shows a confirmation dialog before:
  /// - Clearing local app state from the [DatabaseProvider]
  /// - Logging the user out of Firebase
  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    // Prevent using context after async gap if widget was disposed
    if (!mounted) return;

    if (confirmed == true) {
      final db = Provider.of<DatabaseProvider>(context, listen: false);
      db.clearState(); // Reset app state (e.g. cached posts, users, etc.)
      await AuthService().logout(); // Sign out of Firebase and remove FCM token
    }
  }


  @override
  Widget build(BuildContext context) {
    // Used to access and modify the current theme (dark/light)
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          /// Toggle switch for enabling or disabling dark mode.
          /// Uses [ThemeProvider] to update theme across the entire app.
          MySettingsTile(
            title: "Dark Mode",
            action: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.toggleTheme(),
            ),
          ),

          /// Navigates to a screen where the user can update their account info
          MySettingsTile(
            title: "Account Settings",
            action: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
                );
              },
            ),
          ),
          /// Allows any user to apply for creating a mosque profile
          MySettingsTile(
            title: "Register Mosque Profile",
            action: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateMosqueApplicationPage()),
                );
              },
            ),
          ),

          /// This admin-only option appears only if the user's `userType` is "admin".
          /// It opens a page where pending mosque profile applications can be reviewed and approved.
          if (isAdmin)
            MySettingsTile(
              title: "Approve Mosque Applications",
              action: IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApproveApplicationsPage()),
                  );
                },
              ),
            ),
          const Divider(),

          /// Triggers logout confirmation and signs the user out.
          /// App state is cleared and Firebase session is ended.
          MySettingsTile(
            title: "Logout",
            action: IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }
}
