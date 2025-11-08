import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a mosque profile stored in Firestore.
///
/// This model includes:
/// - Core identifying information (name, description)
/// - Optional structured location data (address + GeoPoint)
/// - Boolean indicating whether a women’s section is available
///
/// Used throughout the app to load mosque details, display them in profiles,
/// and update them via the settings page or application system.
class Mosque {
  final String id;    
  final String name;
  final String description;
  final Map<String, dynamic>? location;
  final bool hasWomenSection;   /// Whether the mosque offers a women's prayer area

  Mosque({
    required this.id,
    required this.name,
    required this.description,
    this.location,
    this.hasWomenSection = false,
  });

  /// Creates a [Mosque] instance from a Firestore document.
  ///
  /// Gracefully handles missing or malformed fields.
  /// The `location` field is only included if both `geo` and `address` are present.
factory Mosque.fromDocument(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  // Extract and validate the location field
  Map<String, dynamic>? location;
  if (data['location'] != null && data['location'] is Map<String, dynamic>) {
    final loc = Map<String, dynamic>.from(data['location']);
    if (loc['geo'] is GeoPoint && loc['address'] is String) {
      location = {
        'address': loc['address'],
        'geo': loc['geo'],
      };
    }
  }

  return Mosque(
    id: doc.id,
    name: data['name'] ?? '',
    description: data['description'] ?? '',
    location: location,
    hasWomenSection: data['hasWomenSection'] ?? false,
  );
}

  /// Converts the mosque data into a map format suitable for storing in Firestore.
  ///
  /// The `location` map can include an address string and a Firestore `GeoPoint`.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'hasWomenSection': hasWomenSection,
    };
  }
}
