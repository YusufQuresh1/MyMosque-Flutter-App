import 'package:flutter/material.dart';
import 'package:mymosque/helper/navigate.dart'; // Helper functions for in-app navigation.
import 'package:provider/provider.dart';
import '../services/database/database_provider.dart'; // Service for database interactions.
import '../components/notification_tile.dart'; // Reusable tile for displaying a single notification.

/// Displays a list of notifications for the current user.
/// Notifications can be related to user follows, mosque posts, etc.
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to ensure the context is available when accessing the provider.
    // This loads the notifications shortly after the widget is built.
    Future.microtask(() {
      // Check if the widget is still mounted before accessing context.
      if (!mounted) return;
      // Trigger loading of notifications using the DatabaseProvider (without listening).
      context.read<DatabaseProvider>().loadInboxNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use context.watch to listen for changes in DatabaseProvider,
    // specifically for `inboxNotifications` and `isLoadingNotifications`.
    final db = context.watch<DatabaseProvider>();
    final notifications = db.inboxNotifications;

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: db.isLoadingNotifications // Show loading indicator while notifications are being fetched.
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty // Show a message if there are no notifications.
              ? const Center(child: Text('No notifications yet.'))
              : ListView.builder( // Display the list of notifications.
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return NotificationTile(
                      notification: notification,
                      onTap: () async {
                        // Mark the notification as read if it isn't already.
                        if (!notification.read) {
                          await context.read<DatabaseProvider>().markNotificationAsRead(notification.id);
                        }

                        // Get the ID related to the notification (e.g., user ID, mosque ID).
                        final id = notification.relatedId;
                        if (id == null) return; // Exit if there's no related ID to navigate to.

                        // Attempt to determine if the related ID is a user or a mosque
                        // and navigate to the appropriate profile page.

                        // Check if it's a user profile.
                        final user = await context.read<DatabaseProvider>().userProfile(id);
                        if (user != null && mounted) {
                          // Use the navigator key associated with this page's context for navigation.
                          goToUserPage(Navigator.of(context).widget.key as GlobalKey<NavigatorState>, id);
                          return;
                        }

                        // Check if it's a mosque profile.
                        final mosque = await context.read<DatabaseProvider>().mosqueProfile(id);
                        if (mosque != null && mounted) {
                          // Use the navigator key for navigation.
                          goToMosquePage(Navigator.of(context).widget.key as GlobalKey<NavigatorState>, mosque);
                          return;
                        }

                        // If neither user nor mosque profile is found, do nothing further.
                      }
                    );
                  },
                ),
    );
  }
}
