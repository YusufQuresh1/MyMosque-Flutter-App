import 'package:flutter/material.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/helper/navigate.dart';

/// A reusable user tile for displaying a user's name and username in a list.
///
/// Can optionally be used to show friend request actions (accept/reject).
/// Tapping the tile navigates to the user’s profile.
///
/// Used in followers/friends lists, inbox notifications, or admin views.
class MyUserTile extends StatelessWidget {
  final UserProfile user;
  final bool isRequest;
  final VoidCallback? onAccept;   /// Called when the accept icon is tapped (used for friend requests)
  final VoidCallback? onReject;   /// Called when the reject icon is tapped (used for friend requests)
  final GlobalKey<NavigatorState> navigatorKey; /// Navigator used to push to the user profile without breaking tab navigation

  const MyUserTile({
    super.key,
    required this.user,
    required this.navigatorKey,
    this.isRequest = false,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: ListTile(
        title: Text(user.name),
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        subtitle: Text('@${user.username}'),
        subtitleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
        leading: Icon(
          Icons.person,
          color: Theme.of(context).colorScheme.primary,
        ),
        trailing: isRequest
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: onAccept,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: onReject,
                  ),
                ],
              )
            : null,
        // Tap opens the user’s profile page using the nested navigator
        onTap: () => goToUserPage(navigatorKey, user.uid),
      ),
    );
  }
}
