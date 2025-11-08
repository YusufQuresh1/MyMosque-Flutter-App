import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents daily prayer time data for a specific mosque and date.
///
/// Each document includes:
/// - Start and optional jamaat time for each daily prayer
/// - A list of khutbah times for Friday (jummah)
///
/// This model is used to load, display, and optionally save structured prayer time data from Firestore.
class PrayerTimes {
  final String date; // Document ID (e.g., '2025-04-15')

  /// Prayer times for each prayer (fajr, dhuhr, etc.), each with:
  /// - 'start' (DateTime)
  /// - optional 'jamaat' (DateTime)
  final Map<String, Map<String, DateTime?>> prayers; // start + optional jamaat
  final List<DateTime> jummah; // Jummah Jamaat times (Friday only)

  PrayerTimes({
    required this.date,
    required this.prayers,
    required this.jummah,
  });

  /// Factory constructor to build a [PrayerTimes] object from a Firestore document.
  ///
  /// Expects a Firestore structure where each prayer is stored under its name
  /// (e.g., `fajr.start`, `fajr.jamaat`) and `jummah` is an array of timestamps.
  factory PrayerTimes.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final Map<String, Map<String, DateTime?>> prayers = {};
    final List<DateTime> jummah = [];

    // Handle the 5 daily prayers
    for (final prayer in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      final times = data[prayer];
      if (times is Map<String, dynamic>) {
        final startRaw = times['start'];
        final jamaatRaw = times['jamaat'];

        prayers[prayer] = {
          'start': startRaw is Timestamp ? startRaw.toDate() : null,
          'jamaat': jamaatRaw is Timestamp ? jamaatRaw.toDate() : null,
        };
      } else {
        prayers[prayer] = {'start': null, 'jamaat': null};
      }
    }

    // Handle Jummah
    if (data['jummah'] is List) {
      final rawList = List.from(data['jummah']);
      for (var time in rawList) {
        if (time is Timestamp) {
          jummah.add(time.toDate());
        }
      }
    }

    return PrayerTimes(date: doc.id, prayers: prayers, jummah: jummah);
  }

  /// Returns the start time of a prayer as a [TimeOfDay] object (or null).
  TimeOfDay? getStartTimeOfDay(String prayer) {
    final dt = prayers[prayer]?['start'];
    return dt != null ? TimeOfDay.fromDateTime(dt) : null;
  }

  /// Returns the jamaat time of a prayer as a [TimeOfDay] object (or null)./// Get the jamaat time for a prayer as TimeOfDay
  TimeOfDay? getJamaatTimeOfDay(String prayer) {
    final dt = prayers[prayer]?['jamaat'];
    return dt != null ? TimeOfDay.fromDateTime(dt) : null;
  }

  /// Converts all Jummah times to [TimeOfDay] format.
  List<TimeOfDay> get jummahTimesAsTimeOfDay {
    return jummah.map((dt) => TimeOfDay.fromDateTime(dt)).toList();
  }

  /// Converts the internal structure to a format suitable for writing to Firestore.
  ///
  /// All DateTime fields are converted back to Firestore-compatible [Timestamp]s.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    for (var prayer in prayers.keys) {
      final start = prayers[prayer]?['start'];
      final jamaat = prayers[prayer]?['jamaat'];

      map[prayer] = {
        if (start != null) 'start': Timestamp.fromDate(start),
        if (jamaat != null) 'jamaat': Timestamp.fromDate(jamaat),
      };
    }

    if (jummah.isNotEmpty) {
      map['jummah'] = jummah.map((dt) => Timestamp.fromDate(dt)).toList();
    }

    return map;
  }

  
}
