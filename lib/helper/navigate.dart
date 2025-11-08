import 'package:flutter/material.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/pages/create_post_page.dart';
import 'package:mymosque/pages/user_profile_page.dart';
import 'package:mymosque/pages/mosque_profile_page.dart';
import 'package:mymosque/pages/inbox_page.dart';
import 'package:mymosque/pages/profile_landing_page.dart';
import 'package:mymosque/pages/settings_page.dart';

/// Navigates to a user profile page using the provided [uid].
///
/// Used when tapping a user's avatar, username, or name anywhere in the app.
void goToUserPage(GlobalKey<NavigatorState> navigatorKey, String uid) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ProfilePage(
        uid: uid,
        navigatorKey: navigatorKey,
      ),
    ),
  );
}

/// Navigates to a mosque profile page given a [Mosque] object.
///
/// Typically used when tapping on the mosque name in a post or a tile.
Future<void> goToMosquePage(GlobalKey<NavigatorState> navigatorKey, Mosque mosque) async {
  final result = await navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => MosqueProfilePage(
        mosque: mosque,
        navigatorKey: navigatorKey,
      ),
    ),
  );

  // If mosque was deleted, pop back to landing page and refresh it
  if (result == true) {
    navigatorKey.currentState?.pop(); // Pop out of the tile tap
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ProfileLandingPage(navigatorKey: navigatorKey),
      ),
    );
  }
}


/// Navigates to the user’s inbox page, where stored notifications are displayed.
void goToInboxPage(GlobalKey<NavigatorState> navigatorKey) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => const InboxPage(),
    ),
  );
}

/// Navigates to the profile landing page, which shows account info,
/// affiliated mosques, primary mosque info, and access to settings
void goToProfileLandingPage(GlobalKey<NavigatorState> navigatorKey) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => ProfileLandingPage(navigatorKey: navigatorKey),
    ),
  );
}

/// Navigates to the app’s settings page from any tab.
void goToSettingsPage(GlobalKey<NavigatorState> navigatorKey) {
  navigatorKey.currentState?.push(
    MaterialPageRoute(
      builder: (_) => const SettingsPage(),
    ),
  );
}

/// Opens the post creation screen with a list of [affiliatedMosques] to choose from.
///
/// Uses the standard [BuildContext] instead of navigatorKey since this is often
/// launched from a button or FAB in a visible scaffold.
///
/// The route is opened as a fullscreen modal.
void goToCreatePostPage(BuildContext context, List<Mosque> affiliatedMosques) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CreatePostPage(affiliatedMosques: affiliatedMosques),
      fullscreenDialog: true,
    ),
  );
}
