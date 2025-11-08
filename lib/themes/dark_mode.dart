import 'package:flutter/material.dart';

// Based on theme setup by Mitch Koko from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6


/// Defines the dark theme configuration for the app using Flutter's [ThemeData] system.
///
/// This is used by the ThemeProvider to apply a consistent dark-mode color scheme
/// across all widgets. The theme is based on a custom [ColorScheme] that defines
/// key UI colors such as primary, secondary, surface, and tertiary.
///
/// This file provides a clean separation of style logic, making theming easy to
/// manage and update.
ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    surface: Color.fromARGB(225,20,20,20),              // Main background colour
    primary: Color.fromARGB(223, 167, 167, 167),        // Icons & secondary level text
    secondary: Color.fromARGB(224, 50, 50, 50),         // Background cards
    tertiary: const Color.fromRGBO(109, 207, 171, 1),   // Main accent colour used for buttons and highlighting
    inversePrimary: Colors.grey.shade300,               // Main text colour
  )
);