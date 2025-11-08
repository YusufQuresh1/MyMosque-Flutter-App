import 'package:flutter/material.dart';

// Based on theme setup by Mitch Koko from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6


/// A reusable styled settings tile for displaying a labeled row with an action widget.
///
/// This widget is typically used in settings pages where each row represents
/// a configurable item (e.g. toggle, navigation arrow, icon button).
///
/// Example use cases:
/// - "Dark Mode" toggle
/// - "Edit Name" button
/// - "Logout" button with icon
class MySettingsTile extends StatelessWidget {

  final String title;
  final Widget action;

  const MySettingsTile({
    super.key,
    required this.title,
    required this.action,
    });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12)
      ),
      margin: const EdgeInsets.only(left: 25, right: 25, top: 10),
      padding: EdgeInsets.all(25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
              Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
              action,
        ]
        ),
    );
  }
}