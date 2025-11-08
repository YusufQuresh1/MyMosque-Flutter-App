import 'package:flutter/material.dart';

// Based on theme setup by Mitch Koko from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6

/// Defines the light theme configuration for the app using Flutter's [ThemeData] system.
///
/// This is used by the ThemeProvider to apply a consistent light-mode color scheme
/// across all widgets. The theme is based on a custom [ColorScheme] that defines
/// key UI colors such as primary, secondary, surface, and tertiary.
///
/// This file provides a clean separation of style logic, making theming easy to
/// manage and update.
ThemeData lightMode = ThemeData(
  colorScheme: ColorScheme.light(
    surface: Colors.white,                              // Main background colour
    primary: Colors.grey.shade500,                      // Icons & secondary level text
    secondary: Colors.grey.shade200,                    // Background cards
    tertiary: const Color.fromARGB(255, 127, 196, 171), // Main accent colour used for buttons and highlighting
    inversePrimary: Colors.grey.shade800,               // Main text colour
  )
);