import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a notification that appears in the user's in-app inbox.
///
/// These notifications are different from push notifications —
/// they are stored in Firestore and displayed persistently inside the app.
///
/// Supported types include:
/// - `friend_request` — someone sent a friend request
/// - `affiliation_request` — someone requested to join a mosque
/// - `mosque_application` — a mosque application was approved
///
/// Additional context may be included via `relatedId` (e.g., userId or mosqueId).
class InboxNotification {
  final String id;
  final String type; // e.g. 'friend_request', 'affiliation_request', 'mosque_application'
  final String title;
  final String body;
  final String? relatedId; // optional: userId or mosqueId, etc.
  final Timestamp timestamp;
  final bool read;

  InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.read,
    this.relatedId,
  });

  /// Factory constructor to build an [InboxNotification] from a Firestore document.
  ///
  /// Defaults to `read: false` if the field is missing.
  factory InboxNotification.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InboxNotification(
      id: doc.id,
      type: data['type'],
      title: data['title'],
      body: data['body'],
      relatedId: data['relatedId'],
      timestamp: data['timestamp'],
      read: data['read'] ?? false,
    );
  }

  /// Converts this notification to a map suitable for storing in Firestore.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'timestamp': timestamp,
      'read': read,
    };
  }

  /// Returns a copy of this object with modified fields.
  ///
  /// Useful for marking the notification as read or updating text/title.
  InboxNotification copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    String? relatedId,
    Timestamp? timestamp,
    bool? read,
  }) {
    return InboxNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      relatedId: relatedId ?? this.relatedId,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }
}
