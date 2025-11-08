import 'package:flutter/material.dart';
import 'package:mymosque/helper/timestamp_utils.dart';
import 'package:mymosque/models/inbox_notification.dart';

/// A UI tile widget for displaying a single notification from the inbox.
///
/// - Highlights unread notifications
/// - Displays a title, body message, and timestamp
/// - Tapping the tile triggers a callback (e.g. to mark as read or navigate)
class NotificationTile extends StatelessWidget {
  final InboxNotification notification; // Data model for the individual notification
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.read;

    return ListTile(
      onTap: onTap,
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            formatTimestamp(notification.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      // Show a small blue dot if unread
      trailing: isUnread
          ? const Icon(Icons.circle, color: Colors.blue, size: 10)
          : null,
      isThreeLine: true,
    );
  }
}
