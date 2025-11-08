/// Represents notification preferences for a single prayer time.
///
/// Each prayer (e.g. Fajr, Dhuhr) has:
/// - `start`: notify at the actual start time
/// - `jamaat`: notify 30 minutes before the jamaat time
class PrayerNotification {
  final bool start;
  final bool jamaat;

  PrayerNotification({required this.start, required this.jamaat});

  /// Creates a [PrayerNotification] from a Firestore map.
  /// If a field is missing, defaults to false.
  factory PrayerNotification.fromMap(Map<String, dynamic> data) {
    return PrayerNotification(
      start: data['start'] ?? false,
      jamaat: data['jamaat'] ?? false,
    );
  }

  /// Converts the object to a map suitable for Firestore storage.
  Map<String, dynamic> toMap() => {
    'start': start,
    'jamaat': jamaat,
  };
}

/// Stores the full notification settings for a user per mosque.
///
/// Includes:
/// - `posts`: whether the user wants push notifications when the mosque posts
/// - `prayerNotifications`: a map of prayer names (e.g., 'fajr') to [PrayerNotification]
class NotificationSettings {
  final bool posts;
  final Map<String, PrayerNotification> prayerNotifications;

  NotificationSettings({
    required this.posts,
    required this.prayerNotifications,
  });

  /// Parses Firestore data into a [NotificationSettings] object.
  ///
  /// Expects a structure like:
  /// {
  ///   posts: true,
  ///   prayer_notifications: {
  ///     fajr: { start: true, jamaat: false },
  ///     dhuhr: { ... },
  ///     ...
  ///   }
  /// }
  factory NotificationSettings.fromMap(Map<String, dynamic> data) {
    Map<String, dynamic> rawPrayer = data['prayer_notifications'] ?? {};
    Map<String, PrayerNotification> prayers = {};
    for (final entry in rawPrayer.entries) {
      prayers[entry.key] = PrayerNotification.fromMap(entry.value);
    }
    return NotificationSettings(
      posts: data['posts'] ?? false,
      prayerNotifications: prayers,
    );
  }

  /// Converts the entire object to a map for storing in Firestore
  Map<String, dynamic> toMap() {
    final prayerMap = {
      for (var entry in prayerNotifications.entries)
        entry.key: entry.value.toMap(),
    };
    return {
      'posts': posts,
      'prayer_notifications': prayerMap,
    };
  }
}
