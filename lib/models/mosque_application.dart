import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a mosque profile application submitted by a user.
///
/// This model is used when a user fills out the "Register Mosque Profile" form.
/// Admins use it to review, approve, or reject applications. Once approved,
/// a new mosque is created and the applicant becomes an affiliated user.
///
/// Fields include:
/// - Mosque name and location
/// - Proof of affiliation (uploaded file URL)
/// - Applicant details
/// - Application status (pending, approved, rejected)
/// - Timestamp of submission
class MosqueApplication {
  final String id; // Firestore doc ID
  final String mosqueName;
  final Map<String, dynamic> location; // { "address": string, "geo": GeoPoint }
  final String proofUrl;  /// URL to the uploaded proof of affiliation document
  final String applicantUid;
  final String applicantUsername;
  final String status; // "pending", "approved", "rejected"
  final Timestamp timestamp;
  final bool hasWomenSection;

  MosqueApplication({
    required this.id,
    required this.mosqueName,
    required this.location,
    required this.proofUrl,
    required this.applicantUid,
    required this.applicantUsername,
    required this.status,
    required this.timestamp,
    required this.hasWomenSection,
  });

  /// Builds a [MosqueApplication] instance from a Firestore document.
  ///
  /// Provides default fallbacks for missing fields to ensure safe parsing.
  factory MosqueApplication.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MosqueApplication(
      id: doc.id,
      mosqueName: data['mosqueName'] ?? '',
      location: Map<String, dynamic>.from(data['location'] ?? {}),
      proofUrl: data['proofUrl'] ?? '',
      applicantUid: data['applicantUid'] ?? '',
      applicantUsername: data['applicantUsername'] ?? '',
      status: data['status'] ?? 'pending',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      hasWomenSection: data['hasWomenSection'] ?? false,
    );
  }
  /// Converts the application into a Firestore-friendly map.
  ///
  /// This is used when creating or updating the application in the database.
  Map<String, dynamic> toMap() {
    return {
      'mosqueName': mosqueName,
      'location': location,
      'proofUrl': proofUrl,
      'applicantUid': applicantUid,
      'applicantUsername': applicantUsername,
      'status': status,
      'timestamp': timestamp,
      'hasWomenSection': hasWomenSection,
    };
  }
}
