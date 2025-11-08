// ignore_for_file: avoid_print

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mymosque/firebase_options.dart';
import 'package:mymosque/services/auth/auth_gate.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:mymosque/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Based on structural setup by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)
/// Functionality added by Mohammed Qureshi:
/// - Full Firebase Messaging (FCM) integration
/// - Local notifications setup
/// - Auto-save of FCM token to Firestore
/// - Foreground message handling with notification UI
/// - Async-safe initialization structure
/// - Provider structure expanded to include [DatabaseProvider]

// Firebase Cloud Messaging instance used to handle push notifications
final FirebaseMessaging _fcm = FirebaseMessaging.instance;

// Flutter plugin for displaying local (in-app) notifications
final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Configures Firebase Cloud Messaging (FCM) for the app.
/// This includes:
/// - Requesting notification permissions from the user
/// - Retrieving and storing the device FCM token in Firestore
/// - Initialising local notifications for displaying alerts while app is in the foreground
Future<void> setupFCM() async {
  NotificationSettings settings = await _fcm.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Notification permission granted');

    // Retrieve the FCM token and store it in the user’s Firestore document.
    final token = await _fcm.getToken();
    print('FCM Token: $token');

    if (token != null && FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'fcmToken': token});
    }

    // Set up Android-specific configuration for displaying local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotificationsPlugin.initialize(initSettings);

    // Handle foreground messages by showing a local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'default_channel',
              'Default',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  } else {
    print('Notification permission not granted');
  }
}

/// Entry point of the application. Initialises Firebase and the notification system.
/// Wraps the app with providers for managing theme and database state.
void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Required to initialize Flutter's engine before calling any plugins or Firebase setup.
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform); // Firebase core setup

  await setupFCM(); // Setup push notification system

  // Lock orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (context) =>
                ThemeProvider()), // Manages dark/light theme switching

        // Makes the app's Firebase-related state (e.g. user info, posts, mosque data)
        // available throughout the app. This allows widgets to access and respond to
        // real-time data changes by listening to a single, shared provider.
        ChangeNotifierProvider(create: (context) => DatabaseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Root widget of the application.
/// Determines theme and displays initial screen based on authentication state.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:
          false, // Removes debug banner from top-right corner
      home:
          AuthGate(), // Navigates user to either login or home depending on auth state (prevents user logging in on each app open)
      theme: Provider.of<ThemeProvider>(context)
          .themeData, // Applies current theme selection
    );
  }
}
