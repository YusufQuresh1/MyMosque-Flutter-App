import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Used for date formatting (keys, display).
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// A page allowing affiliated users to edit the prayer timetable for a specific mosque, day by day.
class EditPrayerTimetablePage extends StatefulWidget {
  final String mosqueId;

  const EditPrayerTimetablePage({super.key, required this.mosqueId});

  @override
  State<EditPrayerTimetablePage> createState() => _EditPrayerTimetablePageState();
}

// Mixin TickerProviderStateMixin is required for the TabController animation.
class _EditPrayerTimetablePageState extends State<EditPrayerTimetablePage> with TickerProviderStateMixin {
  final List<String> _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  // Stores the timetable data, keyed by 'yyyy-MM-dd'. Nested maps hold prayer names and then 'start'/'jamaat' times.
  final Map<String, Map<String, Map<String, TimeOfDay?>>> _timetable = {};
  // Stores Jummah times, keyed by 'yyyy-MM-dd'. Only relevant for Fridays.
  final Map<String, List<TimeOfDay>> _jummahs = {};
  // Tracks which specific fields ('prayer_start', 'prayer_jamaat', 'jummah') have been modified for each date key.
  final Map<String, Set<String>> _dirtyFields = {};
  // Tracks fields that were pre-filled from the previous day but haven't been explicitly set for the current day.
  final Map<String, Set<String>> _placeholderFields = {};
  final List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late TabController _tabController;
  // Stores the DateTime for the Monday of the currently selected week.
  DateTime _selectedMonday = _getMonday(DateTime.now());
  // Index (0-6) of the currently selected day within the week (corresponds to TabController index).
  int _selectedDayIndex = DateTime.now().weekday - 1;
  bool _isSaving = false; // Controls the save button state and loading indicator.

  /// Helper to calculate the date of the Monday for any given date.
  static DateTime _getMonday(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

  @override
  void initState() {
    super.initState();
    _initializeWeek(_selectedMonday); // Set up initial data structure for the week.
    _tabController = TabController(length: 7, vsync: this);
    _tabController.index = _selectedDayIndex; // Start on the current day.
    // Listener to update selected day and potentially load data when tab changes.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newIndex = _tabController.index;
        setState(() => _selectedDayIndex = newIndex);
        // Load data for the newly selected day, potentially pre-filling from the previous day.
        _maybeLoadDay(_selectedMonday.add(Duration(days: newIndex)), preloadFromPrevious: true);
      }
    });
    _loadWeekData(_selectedMonday); // Fetch data for the initial week.
  }

  /// Creates the basic map structure for each day of the given week in `_timetable` and `_jummahs`.
  void _initializeWeek(DateTime monday) {
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      _timetable[key] = {
        for (final p in _prayers) p: {'start': null, 'jamaat': null}
      };
      // Only initialize Jummah list for Friday.
      if (i == 4) _jummahs[key] = [];
    }
  }

  /// Iterates through the week starting from `monday` and loads data for each day.
  Future<void> _loadWeekData(DateTime monday) async {
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      // Preload from previous day only if it's not the first day (Monday).
      await _maybeLoadDay(date, preloadFromPrevious: i > 0);
    }
    // Update UI after loading all week data.
    if (mounted) setState(() {});
  }

  /// Loads prayer times for a specific `date`. If no data exists and `preloadFromPrevious` is true,
  /// it copies data from the previous day and marks it as placeholder data.
  Future<void> _maybeLoadDay(DateTime date, {bool preloadFromPrevious = false}) async {
    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final key = DateFormat('yyyy-MM-dd').format(date);
    final prevKey = DateFormat('yyyy-MM-dd').format(date.subtract(const Duration(days: 1)));

    final pt = await db.fetchPrayerTimes(widget.mosqueId, date);
    // Check if the fetched data actually contains any times.
    final hasData = pt != null &&
        (_prayers.any((p) => pt.getStartTimeOfDay(p) != null || pt.getJamaatTimeOfDay(p) != null));

    if (hasData) {
      // Populate timetable with fetched data.
      _timetable[key] = {
        for (final p in _prayers)
          p: {
            'start': pt.getStartTimeOfDay(p),
            'jamaat': pt.getJamaatTimeOfDay(p),
          }
      };
      _jummahs[key] = pt.jummahTimesAsTimeOfDay;
      // Clear any placeholder flags for this day as we have real data.
      _placeholderFields.remove(key);
    } else if (preloadFromPrevious && _timetable.containsKey(prevKey)) {
      // If no data and preloading is enabled, copy from the previous day.
      _timetable[key] = {
        for (final p in _prayers)
          p: {
            'start': _timetable[prevKey]?[p]?['start'],
            'jamaat': _timetable[prevKey]?[p]?['jamaat'],
          }
      };
      // Mark these copied fields as placeholders.
      _placeholderFields.putIfAbsent(key, () => <String>{});
      for (final p in _prayers) {
        if (_timetable[key]?[p]?['start'] != null) _placeholderFields[key]!.add('${p}_start');
        if (_timetable[key]?[p]?['jamaat'] != null) _placeholderFields[key]!.add('${p}_jamaat');
      }
      // Copy Jummah times only if it's Friday and previous day data exists.
      _jummahs[key] = date.weekday == DateTime.friday && _jummahs.containsKey(prevKey)
          ? List.from(_jummahs[prevKey]!)
          : [];
    }
    // Ensure UI updates after potentially loading/preloading.
    if (mounted) setState(() {});
  }

  /// Shows a time picker and updates the state for a specific prayer time field.
  /// Marks the field as dirty and removes any placeholder status.
  Future<void> _pickTime(String key, String prayer, String field) async {
    final initialTime = _timetable[key]?[prayer]?[field] ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        _timetable[key]![prayer]![field] = picked;
        final fieldKey = '${prayer}_$field';
        // Record that this specific field on this day has been changed.
        _dirtyFields.putIfAbsent(key, () => {}).add(fieldKey);
        // If it was a placeholder, it's now explicitly set, so remove the flag.
        _placeholderFields[key]?.remove(fieldKey);
      });
    }
  }

  /// Shows a time picker and adds a new Jummah time for the given date key.
  Future<void> _pickJummahTime(String key) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        _jummahs[key]?.add(picked);
        // Mark 'jummah' as dirty for this day.
        _dirtyFields.putIfAbsent(key, () => {}).add('jummah');
      });
    }
  }

  /// Builds a row widget for displaying and editing start/jamaat times for a single prayer.
  Widget _buildTimeRow(String key, String prayer) {
    final start = _timetable[key]?[prayer]?['start'];
    final jamaat = _timetable[key]?[prayer]?['jamaat'];

    final startKey = '${prayer}_start';
    final jamaatKey = '${prayer}_jamaat';

    /// Determines the text style based on whether the field is a placeholder or has been explicitly set.
    TextStyle styleFor(String fieldKey) {
      final isFieldDirty = _dirtyFields[key]?.contains(fieldKey) ?? false;
      final isPlaceholderField = _placeholderFields[key]?.contains(fieldKey) ?? false;
      // Use placeholder style only if it's marked as placeholder AND hasn't been modified.
      final usePlaceholderStyle = isPlaceholderField && !isFieldDirty;

      return TextStyle(
        fontStyle: usePlaceholderStyle ? FontStyle.italic : FontStyle.normal,
        color: usePlaceholderStyle
            ? Colors.grey // Distinct color for placeholders.
            : Theme.of(context).colorScheme.inversePrimary,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2, // Give more space to the prayer name.
              child: Text(prayer.capitalize(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.inversePrimary,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            Expanded( // Start time button.
              child: TextButton(
                onPressed: () => _pickTime(key, prayer, 'start'),
                child: Text(start?.format(context) ?? '--', style: styleFor(startKey)),
              ),
            ),
            Expanded( // Jamaat time button.
              child: TextButton(
                onPressed: () => _pickTime(key, prayer, 'jamaat'),
                child: Text(jamaat?.format(context) ?? '--', style: styleFor(jamaatKey)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the section for adding/viewing/deleting Jummah times, only visible on Fridays.
  Widget _buildJummahSection(String key, DateTime date) {
    if (date.weekday != DateTime.friday) return const SizedBox.shrink(); // Return empty space if not Friday.
    final jummahs = _jummahs[key] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text("Jummah Jamaats", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        // Display each added Jummah time with a delete button.
        for (int i = 0; i < jummahs.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${i + 1}${_ordinalSuffix(i + 1)} Jamaat"),
                Text(jummahs[i].format(context), style: const TextStyle(fontWeight: FontWeight.w500)),
                IconButton(
                  onPressed: () => setState(() {
                    jummahs.removeAt(i);
                    // Mark 'jummah' as dirty when a time is removed.
                    _dirtyFields.putIfAbsent(key, () => {}).add('jummah');
                  }),
                  icon: const Icon(Icons.delete_outline, size: 20)
                ),
              ],
            ),
          ),
        // Button to add a new Jummah time.
        TextButton.icon(
          onPressed: () => _pickJummahTime(key),
          icon: const Icon(Icons.add),
          label: const Text("Add Jamaat Time"),
        ),
      ],
    );
  }

  /// Shows a date picker to allow the user to select a different week.
  void _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonday,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // Allow selecting past year.
      lastDate: DateTime.now().add(const Duration(days: 365)), // Allow selecting future year.
    );

    if (picked != null) {
      final newMonday = _getMonday(picked);
      _initializeWeek(newMonday); // Reset data structure for the new week.
      setState(() {
        _selectedMonday = newMonday;
        _selectedDayIndex = picked.weekday - 1; // Update selected day based on picked date.
        _tabController.index = _selectedDayIndex; // Sync TabController.
        // Clear dirty/placeholder flags when changing week.
        _dirtyFields.clear();
        _placeholderFields.clear();
      });
      await _loadWeekData(newMonday); // Load data for the newly selected week.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the date and corresponding key for the currently selected tab.
    final selectedDate = _selectedMonday.add(Duration(days: _selectedDayIndex));
    final dayKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Prayer Timetable"),
        actions: [
          // Calendar icon to trigger week selection.
          IconButton(onPressed: _pickWeek, icon: const Icon(Icons.calendar_month))
        ],
        // TabBar displaying the days of the selected week.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Allows tabs to scroll if they don't fit.
          labelColor: Theme.of(context).colorScheme.inversePrimary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            // Generate a tab for each day of the week.
            for (int i = 0; i < daysOfWeek.length; i++)
              Tab(text: "${daysOfWeek[i]}\n${DateFormat('d/M').format(_selectedMonday.add(Duration(days: i)))}"),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            // Use SingleChildScrollView to allow content to scroll if it overflows.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Build time rows for each standard prayer.
                  // Add Start / Jamaat headings ONCE at the top
                  Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(flex: 2, child: SizedBox()), // Matches prayer name column width (empty placeholder)
                          Expanded(
                            flex: 1, // Matches 'Start' column width
                            child: Align(
                              alignment: Alignment.center, // Center the 'Start' text
                              child: Text(
                                'Start',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.inversePrimary,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1, // Matches 'Jamaat' column width
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                'Jamaat',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.inversePrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8), // Spacing below the headings
                      // Now build the prayer time rows
                      for (final prayer in _prayers) _buildTimeRow(dayKey, prayer),
                    ],
                  ),

                  // Build the Jummah section (only appears on Fridays).
                  _buildJummahSection(dayKey, selectedDate),
                ],
              ),
            ),
          ),
          // Save button section at the bottom.
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              // Disable button while saving or if no changes have been made to the current day.
              onPressed: _isSaving || !(_dirtyFields.containsKey(dayKey) && _dirtyFields[dayKey]!.isNotEmpty)
                  ? null
                  : () async {
                      final db = Provider.of<DatabaseProvider>(context, listen: false);
                      // Redundant check (already handled by onPressed logic), but safe.
                      // if (!(_dirtyFields.containsKey(dayKey) && _dirtyFields[dayKey]!.isNotEmpty)) {
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     const SnackBar(content: Text("No changes to save.")),
                      //   );
                      //   return;
                      // }

                      setState(() => _isSaving = true);
                      try {
                        // Call database provider to save only the data for the current day.
                        await db.savePrayerTimetable(
                          mosqueId: widget.mosqueId,
                          monday: _selectedMonday,
                          timetable: {dayKey: _timetable[dayKey]!}, // Pass only the current day's timetable.
                          jummahs: {dayKey: _jummahs[dayKey] ?? []}, // Pass only the current day's Jummah times.
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Prayer timetable saved for this day.")),
                          );
                          // Clear dirty flags for the saved day.
                          _dirtyFields.remove(dayKey);
                          // Also clear placeholder flags as data is now saved explicitly.
                          _placeholderFields.remove(dayKey);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error saving timetable: $e")),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isSaving = false);
                      }
                    },
              // Show loading indicator or save icon based on _isSaving state.
              icon: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_isSaving ? "Saving..." : "Save Timetable", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48), // Make button full width.
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                // Style for disabled state (when no changes or saving).
                disabledBackgroundColor: Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper function to get the correct ordinal suffix (st, nd, rd, th) for a number.
  String _ordinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}

// Simple extension method to capitalize the first letter of a string.
extension StringCasingExtension on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
