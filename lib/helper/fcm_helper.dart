// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Firebase Cloud Messaging instance used for push notifications
final FirebaseMessaging _fcm = FirebaseMessaging.instance;

// Plugin used for showing local (in-app foreground) notifications
final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

/// Initializes Firebase Cloud Messaging (FCM) and foreground notification handling.
///
/// This setup function does the following:
/// - Requests notification permission from the user
/// - Retrieves and saves the FCM token to Firestore (under the current user)
/// - Configures the local notification system to show push notifications
///   even when the app is open (foreground)
///
/// This is typically called during app startup
Future<void> setupFCM() async {
  // Request notification permissions
  NotificationSettings settings = await _fcm.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Notification permission granted');

    // Save the FCM token in Firestore under the current user's document
    final token = await _fcm.getToken();
    print('FCM Token: $token');

    if (token != null && FirebaseAuth.instance.currentUser != null) {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'fcmToken': token});
    }

    // Configure the plugin to show notifications while the app is open
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotificationsPlugin.initialize(initSettings);

    // Listen for incoming FCM messages while app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      
      // Show a local notification using system UI if message contains one
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
