import 'package:flutter/material.dart';

// Based on theme setup by Mitch Koko from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6

/// A reusable, stylized button widget for general actions across the app.
///
/// Features:
/// - Accepts a tap callback (`onTap`)
/// - Accepts a dynamic text label (`text`)
/// - Uses app theming for consistent design (tertiary color)
/// - Rounded corners and padded layout
///
/// Common use cases: form submissions, confirm actions, etc.
class MyButton extends StatelessWidget {
  final String text;
  final void Function()? onTap;
  const MyButton({
    super.key,
    required this.text,
    required this.onTap
    });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary, 
          borderRadius: BorderRadius.circular(12)
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),)),
      )
    );
  }
}