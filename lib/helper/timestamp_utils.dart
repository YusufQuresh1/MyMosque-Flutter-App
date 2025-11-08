import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Converts a Firestore [Timestamp] to a [TimeOfDay] object.
///
/// This is useful when working with UI widgets like TimePickers or formatted
/// prayer schedules, which use Flutter's [TimeOfDay] instead of full [DateTime].
///
/// Returns `null` if the input is not a valid [Timestamp].
TimeOfDay? getTimeOfDayFromTimestamp(dynamic timestamp) {
  if (timestamp is Timestamp) {
    final dateTime = timestamp.toDate();
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }
  return null;
}

/// Formats a Firestore [Timestamp] for display in post metadata.
///
/// - If the post was created within:
///   - the last 60 seconds: returns "Just now"
///   - the last hour: returns "X minutes ago"
///   - the same day: returns "X hours ago"
///   - the last 7 days: returns "X days ago"
///   - otherwise: returns the date in `DD/MM/YYYY` format.
///
/// This function helps make your post timestamps feel more natural and readable,
/// similar to how social media platforms present time since a post was created.
String formatTimestamp(Timestamp timestamp) {
  DateTime postTime = timestamp.toDate();
  DateTime now = DateTime.now();
  Duration diff = now.difference(postTime);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  } else if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  } else {
    return '${postTime.day}/${postTime.month}/${postTime.year}';
  }
}
