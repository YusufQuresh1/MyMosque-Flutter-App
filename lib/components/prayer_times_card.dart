import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/prayer_times.dart';

/// A styled widget that displays the prayer timetable for a specific date.
///
/// It shows:
/// - A header with the formatted date
/// - A list of Jummah times (if Friday)
/// - A table of all 5 daily prayers, with start and jamaat times
/// - Highlights the current prayer (based on current time)
///
/// Used on the Mosque Profile page and Profile Landing page to show today’s timings for a particular mosque.
class PrayerTimesCard extends StatelessWidget {
  final PrayerTimes prayerTimes;

  const PrayerTimesCard({super.key, required this.prayerTimes});

  @override
  Widget build(BuildContext context) {
    final isFriday = DateTime.now().weekday == DateTime.friday;

    // Check if all prayers are missing both start and jamaat times
    final allTimesEmpty = prayerTimes.prayers.values.every(
      (v) => v['start'] == null && v['jamaat'] == null,
    );

    final now = DateTime.now();

    // Format the current date in long readable format
    final formattedDate = DateFormat("EEEE d'th' MMMM yyyy").format(DateTime.parse(prayerTimes.date));

    // Collect valid prayers that have start times for sorting & now-highlighting
    final validPrayers = prayerTimes.prayers.entries
        .where((e) => e.value['start'] != null)
        .toList();

    validPrayers.sort((a, b) => a.value['start']!.compareTo(b.value['start']!));

    // Determine which prayer is currently active
    String? currentPrayer;

    for (int i = 0; i < validPrayers.length; i++) {
      final start = validPrayers[i].value['start']!;
      final nextStart = (i + 1 < validPrayers.length) ? validPrayers[i + 1].value['start'] : null;

      if (now.isAfter(start) && (nextStart == null || now.isBefore(nextStart))) {
        currentPrayer = validPrayers[i].key;
        break;
      }
    }

    // Default to first available prayer if no match was found
    currentPrayer ??= validPrayers.isNotEmpty ? validPrayers.first.key : null;

    return Card(
      color: const Color.fromARGB(255, 150, 163, 255),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Jummah section (if Friday and times exist)
            if (isFriday && prayerTimes.jummah.isNotEmpty) ...[
              Text(
                "Jummah",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.inversePrimary,
                ),
              ),
              const SizedBox(height: 8),
              // Display each Jummah time with ordinal label (1st, 2nd, etc.)
              ...prayerTimes.jummah.asMap().entries.map((entry) {
                final index = entry.key;
                final time = entry.value;
                final label = "${index + 1}${_ordinalSuffix(index + 1)} Jamaat";

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat.jm().format(time),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],

            // Header row for 5 daily prayers
            Row(
              children: const [
                Expanded(flex: 2, child: Text("Prayer", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text("Start", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("Jamaat", style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
            Divider(color: Colors.grey.shade200, thickness: 3),

            // If no times at all
            if (allTimesEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Center(
                  child: Text(
                    "No prayer times for today",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.inversePrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            // Else display all available prayers
            else
              ...prayerTimes.prayers.entries.map((entry) {
                final key = entry.key;
                final name = key.capitalize();
                final start = entry.value['start'];
                final jamaat = entry.value['jamaat'];
                final isNow = key == currentPrayer;

                if (start == null && jamaat == null) return const SizedBox();

                final formattedStart = start != null ? DateFormat.jm().format(start) : '--';
                final formattedJamaat = jamaat != null ? DateFormat.jm().format(jamaat) : '--';

                final baseTextStyle = TextStyle(
                  fontSize: 16,
                  color: isNow
                      ? Theme.of(context).colorScheme.surface
                      : Theme.of(context).colorScheme.inversePrimary,
                );

                return Container(
                  decoration: BoxDecoration(
                    color: isNow ? Theme.of(context).colorScheme.tertiary : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: baseTextStyle.copyWith(
                            fontWeight: isNow ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(child: Text(formattedStart, style: baseTextStyle)),
                      ),
                      Expanded(
                        child: Center(child: Text(formattedJamaat, style: baseTextStyle)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _ordinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

extension StringCasingExtension on String {
  String capitalize() =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}