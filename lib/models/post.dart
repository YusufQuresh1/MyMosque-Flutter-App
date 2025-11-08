import 'package:cloud_firestore/cloud_firestore.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)
/// Functionality added by Mohammed Qureshi:
/// - Switched from [name] to [mosqueName] (mosque context for posts)
/// - Added [mosqueId] for linking posts to specific mosques
/// - Added optional [event] map for event metadata
/// - Added optional [imageUrl] field for image support
/// - Improved null safety and default fallbacks in fromDocument
/// - Enhanced [toMap()] to conditionally include optional fields


/// Represents a post made by a user on behalf of a mosque.
///
/// Posts are stored in Firestore and may optionally include:
/// - Attached event metadata (e.g., date/time, location, restrictions)
/// - An image URL if an image was uploaded
///
/// Each post is associated with:
/// - The user who created it (`uid`)
/// - The mosque it was posted for (`mosqueId`)
/// - Display details like `username` and `mosqueName` for frontend convenience
class Post {
  final String id;                    /// Firestore document ID
  final String uid;                   /// ID of the user who created the post
  final String mosqueName;            /// Display name of the mosque 
  final String username;              /// Username of the poster 
  final String message;               /// Post content
  final Timestamp timestamp;          /// Timestamp the post was created (stored as Firestore Timestamp)
  final String mosqueId;              /// ID of the mosque the post belongs to
  final Map<String, dynamic>? event;  /// Optional map containing event details (if the post represents an event)
  final String? imageUrl;             /// Optional URL to an uploaded image

  Post({
    required this.id,
    required this.uid,
    required this.mosqueName,
    required this.username,
    required this.message,
    required this.timestamp,
    required this.mosqueId,
    this.event,
    this.imageUrl,
  });

  /// Factory constructor to build a [Post] object from a Firestore document.
  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      uid: data['uid'] ?? '',
      mosqueName: data['mosqueName'] ?? '',
      username: data['username'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      mosqueId: data['mosqueId'] ?? '',
      event: data['event'] != null ? Map<String, dynamic>.from(data['event']) : null,
      imageUrl: data['imageUrl'],
    );
  }

  /// Converts the post into a map suitable for saving to Firestore.
  ///
  /// Omits `event` and `imageUrl` fields if they are null or empty.
  Map<String, dynamic> toMap() {
    final map = {
      'uid': uid,
      'mosqueName': mosqueName,
      'username': username,
      'message': message,
      'timestamp': timestamp,
      'mosqueId': mosqueId,
    };

    if (event != null) {
      map['event'] = event as Object;
    }

    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      map['imageUrl'] = url;
    }

    return map;
  }

}
