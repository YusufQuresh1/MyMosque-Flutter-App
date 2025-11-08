import 'package:flutter/material.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)

/// A reusable alert dialog widget with a text input field and two action buttons.
/// 
/// This is used throughout the app to prompt the user to enter a new value
/// (e.g. updating name, bio, or other string fields). It includes:
/// - A customizable [hintText]
/// - A [textController] to track user input
/// - A cancel button that clears the field and dismisses the dialog
/// - A confirm button with customizable label and action callback
class MyInputAlertBox extends StatelessWidget {

  final TextEditingController textController;
  final String hintText;
  final void Function()? onPressed;
  final String onPressedText;

  const MyInputAlertBox({super.key, required this.textController, required this.hintText, this.onPressed, required this.onPressedText});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8))
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
    
      content: TextField(
        controller: textController,
        decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.inversePrimary),
            borderRadius: BorderRadius.circular(12)
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            borderRadius: BorderRadius.circular(12)
          ),

          hintText: hintText,
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),

          fillColor: Theme.of(context).colorScheme.secondary
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          Navigator.pop(context);
          textController.clear();
        }, 
        child: const Text("Cancel"),
        ),
        TextButton(onPressed: () {
          Navigator.pop(context);
          onPressed?.call();
          textController.clear(); },
        child: Text(onPressedText))

      ],
    );
  }
}