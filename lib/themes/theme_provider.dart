import 'package:flutter/material.dart';
import 'package:mymosque/themes/dark_mode.dart';
import 'package:mymosque/themes/light_mode.dart';

// Based on Mitch Koko's theme provider setup from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6

/// A ChangeNotifier-based class that manages the app's current theme state.
/// This allows switching between dark and light mode and notifies any listening widgets
/// so they can update their appearance accordingly.
///
/// This provider is injected at the top level of the app (see main.dart),
/// enabling dynamic theming across all screens.
class ThemeProvider with ChangeNotifier{

  /// Holds the currently active theme. Defaults to light mode.
  ThemeData _themeData = lightMode;

  /// Exposes the current ThemeData so that widgets can use it for styling.
  ThemeData get themeData => _themeData;

  /// Boolean getter to determine whether the current theme is dark mode.
  bool get isDarkMode => _themeData == darkMode;

  /// Allows external widgets or logic to directly set the theme,
  /// and triggers UI rebuilds by notifying all listeners.
  set themeData(ThemeData themeData) {
    _themeData = themeData;

    notifyListeners();
  }

  /// Toggles between light mode and dark mode themes.
  /// This is  triggered by a switch in settings.
  void toggleTheme() {
    if (_themeData == lightMode) {
      themeData = darkMode;
    } else {
      themeData = lightMode;
    }
  }
}