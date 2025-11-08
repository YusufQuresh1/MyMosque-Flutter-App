import 'package:flutter/material.dart';

/// Type alias for profile stat entries.
/// Each stat is a map with:
/// - 'label': display name (e.g. "Posts")
/// - 'count': numerical value (e.g. 12)
/// - optional 'onTap': callback to trigger when tapped (e.g. open list)

typedef Stat = Map<String, dynamic>; // e.g. {'label': 'Posts', 'count': 12}

/// A flexible widget for displaying user or mosque profile statistics in a row.
///
/// Each stat shows a count and label (e.g. "12\nPosts"), and can be tappable
/// if an `onTap` function is provided.
///
/// Used in:
/// - User profiles (Posts, Mosques, Friends)
/// - Mosque profiles (Posts, Followers, Admins)
class MyProfileStats extends StatelessWidget {
  final List<Stat> stats;
  final MainAxisAlignment alignment;

  const MyProfileStats({
    super.key,
    required this.stats,
    this.alignment = MainAxisAlignment.spaceEvenly,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: stats.map((stat) {
        return GestureDetector(
          onTap: stat['onTap'],
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat['count'].toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat['label'],
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}