import 'package:flutter/material.dart';

/// A versatile action button for friend or mosque affiliation requests.
///
/// This button intelligently updates its label, color, and behavior
/// based on the request status:
/// - Not sent: shows "Send Friend Request" or "Request Affiliation"
/// - Sent: shows "Requested" and disables interaction
/// - Accepted: shows "Remove Friend" or "Remove Affiliation"
/// - Incoming (friend only): shows "Accept Friend Request"
///
/// Used in profile pages to manage social or admin relationships.
class MyRequestButton extends StatelessWidget {
  final String requestType; // 'friend' or 'affiliation'
  final bool isRequested;   /// Whether a request has already been sent by the current user
  final bool isAccepted;    /// Whether the request was accepted (i.e. they are now friends or affiliated)
  final bool hasIncomingRequest; /// Whether there is a pending incoming friend request
  final VoidCallback onRequest; /// Called when the user initiates the request
  final VoidCallback? onRemove; /// Called to remove the friend or affiliation
  final VoidCallback? onAccept; /// Called to accept an incoming friend request

  const MyRequestButton({
    super.key,
    required this.requestType,
    required this.isRequested,
    required this.isAccepted,
    this.hasIncomingRequest = false,
    required this.onRequest,
    this.onRemove,
    this.onAccept,
  });

  /// Dynamically sets the button label based on the current state
  String get buttonText {
    if (isAccepted) {
      return requestType == 'friend' ? 'Remove Friend' : 'Remove Affiliation';
    }
    if (hasIncomingRequest && requestType == 'friend') return 'Accept Friend Request';
    if (isRequested) return 'Requested';
    return requestType == 'friend' ? 'Send Friend Request' : 'Request Affiliation';
  }

  /// Determines what callback to use for the button
  ///
  /// - If already accepted: allow removing
  /// - If there's an incoming friend request: allow accepting
  /// - If already requested: do nothing (button disabled)
  /// - Otherwise: allow sending the request
  VoidCallback get onPressed {
    if (isAccepted) return onRemove ?? () {};
    if (hasIncomingRequest && requestType == 'friend') return onAccept ?? () {};
    if (isRequested) return () {};
    return onRequest;
  }

  /// Styles the button color based on its current state
  Color get buttonColor {
    if (isAccepted || isRequested) {
      return const Color.fromARGB(255, 193, 193, 193);
    } else {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MaterialButton(
          padding: const EdgeInsets.all(15),
          onPressed: onPressed,
          color: buttonColor,
          child: Text(
            buttonText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
