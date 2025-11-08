import 'package:flutter/material.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)

/// A reusable widget to display a user's or mosque's bio/description section.
///
/// Features:
/// - Displays placeholder text ("Empty bio") if input is empty
/// - Themed styling with secondary background and inversePrimary text
/// - Consistent padding and margin for profile layouts
///
/// Commonly used on profile pages for users and mosques.
class MyBioBox extends StatelessWidget {
  final String text;
  const MyBioBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(8)
      ),
      padding: const EdgeInsets.all(25),
      margin: const EdgeInsets.symmetric(horizontal: 25),
      child: Text(
        text.isNotEmpty ? text : "Empty bio",
        style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary)
        )
    );
  }
}