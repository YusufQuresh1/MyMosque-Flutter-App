import 'package:cloud_firestore/cloud_firestore.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)
/// Functionality added by Mohammed Qureshi:
/// - Added [gender] field for user profile and filtering
/// - Added [fcmToken] for storing Firebase Messaging tokens
/// - Added [primaryMosqueId] to support primary mosque selection
/// - Enhanced fromDocument with default fallbacks for optional fields
/// - [toMap] omits optional fields unless present (clean Firestore writes)

/// Represents the data structure for a user profile within the application.
/// This class encapsulates all user-specific information stored in Firestore,
/// such as identification, contact details, personal info, and app-related settings.
class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String name;
  final String bio;
  final String gender;
  final String userType;          /// The type of user ('user', 'admin'). Determines permissions/capabilities.
  final String? fcmToken;         /// The Firebase Cloud Messaging (FCM) token for sending push notifications to the user's device.
  final String? primaryMosqueId;  /// The ID of the mosque the user has marked as their primary mosque.

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.name,
    required this.bio,
    required this.gender,
    required this.userType,
    this.fcmToken,
    this.primaryMosqueId,
  });

  /// Factory constructor to create a [UserProfile] instance from a Firestore [DocumentSnapshot].
  /// Handles potential null values for optional fields like bio, gender, fcmToken, and primaryMosqueId.
  factory UserProfile.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: data['uid'] as String,
      email: data['email'] as String,
      username: data['username'] as String,
      name: data['name'] as String,
      bio: data['bio'] as String? ?? '', // Default to empty string if null.
      gender: data['gender'] as String? ?? '', // Default to empty string if null.
      userType: data['userType'] as String,
      fcmToken: data['fcmToken'] as String?,
      primaryMosqueId: data['primaryMosqueId'] as String?,
    );
  }

  /// Converts the [UserProfile] instance into a Map suitable for storing in Firestore.
  /// Omits optional fields (fcmToken, primaryMosqueId) from the map if they are null.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'name': name,
      'bio': bio,
      'gender': gender,
      'userType': userType,
      if (fcmToken != null) 'fcmToken': fcmToken,
      if (primaryMosqueId != null) 'primaryMosqueId': primaryMosqueId,
    };
  }
}
