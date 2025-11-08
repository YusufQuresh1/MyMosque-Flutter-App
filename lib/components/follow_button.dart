import 'package:flutter/material.dart';

/// A custom follow/unfollow button used for mosque profiles.
///
/// This button:
/// - Updates its color and label dynamically based on follow status
/// - Triggers a callback when pressed
/// - Is styled with consistent padding, rounded corners, and bold text
class MyFollowButton extends StatelessWidget {
  final void Function()? onPressed;
  final bool isFollowing;

  const MyFollowButton({
    super.key,
    required this.onPressed,
    required this.isFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MaterialButton(
          padding: const EdgeInsets.all(15),
          onPressed: onPressed,
          color: isFollowing ? const Color.fromRGBO(193, 193, 193, 1) : Colors.blue,
          child: Text(
            isFollowing ? "Unfollow" : "Follow", // Label updates dynamically
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
