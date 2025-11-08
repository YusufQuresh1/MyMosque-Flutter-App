import 'package:flutter/material.dart';
import 'package:mymosque/pages/login_page.dart';
import 'package:mymosque/pages/register_page.dart';

// Based on Mitch Koko's login/register toggle page from:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6

/// This widget acts as a gatekeeper between the login and registration screens.
/// It conditionally displays either the [LoginPage] or the [RegisterPage]
/// based on user interaction.
///
/// The two pages are toggled using a callback (`onTap`) passed to each screen,
/// allowing the user to switch between them without navigating away.
///
/// This component is used by AuthGate to determine which part of the
/// authentication flow to show when the user is not signed in.
class LoginOrRegister extends StatefulWidget {
  const LoginOrRegister({super.key});

  @override
  State<LoginOrRegister> createState() => _LoginOrRegisterState();
}

class _LoginOrRegisterState extends State<LoginOrRegister> {
  
  /// Tracks whether to show the login page or the register page.
  /// Starts as `true`, meaning the login page is shown first.
  bool showLoginPage = true;

  /// Toggles the UI between the login and registration pages.
  /// This is triggered when the user taps the "Register" or "Login" link on each respective page.
  void togglePages(){
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Conditionally returns either the login or register page,
    // with the toggle function passed down as a callback.
    if (showLoginPage) {
      return LoginPage(onTap: togglePages,);
    } else {
      return RegisterPage(onTap: togglePages,);
    }
  }
}