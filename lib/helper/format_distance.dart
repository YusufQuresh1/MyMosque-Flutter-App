/// Converts a distance from meters to a formatted string in miles.
///
/// This is used to display how far a mosque or event is from the user’s current location.
///
/// Example:
/// formatDistance(1200) // returns "0.75 miles away"
///
/// - Uses the conversion: 1 mile = 1609.34 meters (≈ 0.000621371 miles per meter)
/// - Rounds the output to 2 decimal places for readability
///
/// Typically used in mosque listings, event listings, and map overlays.
String formatDistance(double distanceInMeters) {
  // Convert meters to miles (1 mile = 1609.34 meters)
  final miles = distanceInMeters * 0.000621371;

  // Return formatted string with 2 decimal places
  return '${miles.toStringAsFixed(2)} miles away';
}
