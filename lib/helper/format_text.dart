/// Converts a string to title case by capitalizing the first letter of each word.
///
/// Example:
/// toTitleCase("example text") // returns "Example Mosque"
///
/// Handles:
/// - Leading/trailing/multiple spaces
/// - Mixed-case input (e.g., "mY moSque")
/// - Empty strings safely
///
/// Used throughout the app to display names and titles in a more readable, consistent format.
String toTitleCase(String input) {
  return input
      .split(' ')
      .map((word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}
