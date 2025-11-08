import 'package:flutter/material.dart';
import 'package:mymosque/helper/format_text.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/helper/navigate.dart';

/// A reusable tile widget used to display basic information about a mosque.
///
/// - Shows the mosque's name and description
/// - Tapping the tile navigates to the mosque's profile page
/// - Uses theme colors for consistency with app styling
///
/// Used in search results, affiliated mosque lists, and nearby mosques.
class MyMosqueTile extends StatelessWidget {
  final Mosque mosque;
  final GlobalKey<NavigatorState> navigatorKey;

  const MyMosqueTile({
    super.key,
    required this.mosque,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      // ListTile is used for simple vertical layout of icon + text
      child: ListTile(
        title: Text(toTitleCase(mosque.name)),
        titleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        subtitle: Text(mosque.description),
        subtitleTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
        ),
        leading: Icon(
          Icons.mosque,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        onTap: () => goToMosquePage(navigatorKey, mosque),
      ),
    );
  }
}
