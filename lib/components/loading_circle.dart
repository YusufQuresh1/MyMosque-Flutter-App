import 'package:flutter/material.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)
/// Functionality added by Mohammed Qureshi:
/// - Modified [hideLoadingCircle] to use the root navigator to support the app's nested navigation structure

/// Displays a modal loading spinner over the current UI.
/// 
/// This is typically used during asynchronous operations like login,
/// account deletion, or remote data fetching. The dialog is non-dismissible
/// to prevent users from closing it manually.
void showLoadingCircle(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent user from dismissing the dialog
    builder: (dialogContext) => const Center(
      child: CircularProgressIndicator(), // Flutter’s built-in loading spinner
    ),
  );
}

/// Hides the loading spinner previously shown by [showLoadingCircle].
/// 
/// Uses the root navigator to ensure the dialog is closed even if shown from
/// a nested route or modal context.
void hideLoadingCircle(BuildContext context) {
  // Use root navigator to ensure closing the dialog even if nested
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
}
