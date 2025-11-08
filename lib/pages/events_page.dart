import 'package:flutter/material.dart';
import 'package:mymosque/services/auth/auth_service.dart'; // Service for getting current user ID.
import 'package:provider/provider.dart'; // State management package.
import 'package:geolocator/geolocator.dart'; // For fetching user location and calculating distances.
import 'package:intl/intl.dart'; // For formatting dates.

import '../services/database/database_provider.dart'; // Service for database interactions.
import '../components/post_tile.dart'; // Reusable tile for displaying posts/events.
import '../models/post.dart'; // Data model for posts.
import '../helper/navigate.dart'; // Helper functions for in-app navigation.

/// Displays a list of upcoming events, sorted by proximity and grouped by date.
/// Allows filtering events based on gender restrictions.
class EventsPage extends StatefulWidget {
  /// Navigator key passed from the parent (HomePage) to enable navigation within this tab's context.
  final GlobalKey<NavigatorState> navigatorKey;

  const EventsPage({super.key, required this.navigatorKey});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  /// Stores the user's current geographical position, used for sorting events by distance.
  Position? _userPosition;
  /// Stores the selected gender filter ('male', 'female', or null for all).
  String? _genderFilter;

  @override
  void initState() {
    super.initState();
    // Attempt to load the user's location when the page initialises.
    _loadUserPosition();
  }

  /// Fetches the user's current location using Geolocator.
  /// Handles requesting permissions if necessary.
  Future<void> _loadUserPosition() async {
    try {
      // Check and request location permissions.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        // Exit if permission is still denied.
        if (permission == LocationPermission.denied) return;
      }
      // Exit if permission is permanently denied.
      if (permission == LocationPermission.deniedForever) return;

      // Fetch the current position with high accuracy.
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      // Update state if the widget is still mounted.
      setState(() => _userPosition = pos);
    } catch (e) {
      // Log errors during location fetching (e.g., location services disabled).
      debugPrint("Error fetching location: $e");
    }
  }

  /// Helper function to reliably get the event start time from a Post object.
  /// Prioritises 'start_time' field, falls back to 'date_time', otherwise returns a past date.
  DateTime getEventStartTime(Post post) {
    // Return a past date if event data is missing to ensure it sorts correctly.
    if (post.event == null) return DateTime.now().subtract(const Duration(days: 1));
    if (post.event!['start_time'] != null) return post.event!['start_time'].toDate();
    if (post.event!['date_time'] != null) return post.event!['date_time'].toDate();
    return DateTime.now().subtract(const Duration(days: 1));
  }

  //Checks if an event is available for male attendees (male restricted or no restriction)
  bool isEventForBrothers(Map<String, dynamic> event) {
  final restriction = event['gender_restriction']?.toString().toLowerCase();
  return restriction == null || restriction.isEmpty || restriction == 'none' || restriction == 'male';
  }

  //Checks if an event is available for female attendees (female restricted or no restriction)
  bool isEventForSisters(Map<String, dynamic> event) {
    final restriction = event['gender_restriction']?.toString().toLowerCase();
    return restriction == null || restriction.isEmpty || restriction == 'none' || restriction == 'female';
  }

  /// Opens a modal bottom sheet to allow the user to select a gender filter.
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        String? tempFilter = _genderFilter;
        // StatefulBuilder allows the sheet's content to update independently.
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.filter_alt, size: 20, color: Theme.of(context).colorScheme.inversePrimary),
                      SizedBox(width: 8),
                      Text("Filters", style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary,fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  // Radio buttons for filter options.
                  RadioListTile<String?>(
                    title: const Text("All Events"),
                    value: null, // Represents no filter.
                    groupValue: tempFilter,
                    onChanged: (val) => setModalState(() => tempFilter = val),
                    activeColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  RadioListTile<String?>(
                    title: const Text("Brothers Events"),
                    value: 'male',
                    groupValue: tempFilter,
                    onChanged: (val) => setModalState(() => tempFilter = val),
                    activeColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  RadioListTile<String?>(
                    title: const Text("Sisters Events"),
                    value: 'female',
                    groupValue: tempFilter,
                    onChanged: (val) => setModalState(() => tempFilter = val),
                    activeColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Reset button clears the filter.
                      TextButton(
                        onPressed: () {
                          setState(() => _genderFilter = null);
                          Navigator.pop(context);
                        },
                        child: const Text("Reset"),
                      ),
                      const Spacer(),
                      // Apply button sets the selected filter.
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _genderFilter = tempFilter);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Apply"),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get all posts
    final posts = Provider.of<DatabaseProvider>(context).allPosts;
    final now = DateTime.now();

    // Filter posts to get only upcoming events that match the gender filter.
    final eventPosts = posts.where((post) {
      final eventTime = getEventStartTime(post);
      // Check if the filter is null (all) or matches the event's restriction.
      final matchesGender = _genderFilter == null ||
        (_genderFilter == 'male' && post.event != null && isEventForBrothers(post.event!)) ||
        (_genderFilter == 'female' && post.event != null && isEventForSisters(post.event!));



      // Include if it's an event, it's in the future, and matches the gender filter.
      return post.event != null && eventTime.isAfter(now) && matchesGender;
    }).toList();

    // Sort events: Primarily by start time, secondarily by distance.
    if (_userPosition != null) {
      eventPosts.sort((a, b) {
        final aGeo = a.event!['location']['geo'];
        final bGeo = b.event!['location']['geo'];
        // Calculate distance from user to each event.
        final aDist = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, aGeo.latitude, aGeo.longitude);
        final bDist = Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, bGeo.latitude, bGeo.longitude);
        final aTime = getEventStartTime(a);
        final bTime = getEventStartTime(b);
        // Compare times first.
        final timeCompare = aTime.compareTo(bTime);
        // If times are the same, compare distances.
        return timeCompare != 0 ? timeCompare : aDist.compareTo(bDist);
      });
    } else {
      // If user location isn't available, sort only by start time.
      eventPosts.sort((a, b) => getEventStartTime(a).compareTo(getEventStartTime(b)));
    }

    // Group sorted events by date for display.
    final grouped = <String, List<Post>>{};
    for (var post in eventPosts) {
      // Format the date string used as the group key.
      final date = DateFormat('EEEE, d MMM').format(getEventStartTime(post));
      // Add the post to the list for that date, creating the list if it doesn't exist.
      grouped.putIfAbsent(date, () => []).add(post);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upcoming Events"),
        actions: [
          // Filter button in the AppBar.
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            tooltip: "Filter",
            onPressed: _openFilterSheet,
          )
        ],
      ),
      // Show loading indicator initially if location is still loading and there are no events yet.
      body: _userPosition == null && eventPosts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator( // Enable pull-to-refresh.
              onRefresh: () async {
                // Reload posts and attempt to reload user position on refresh.
                await Provider.of<DatabaseProvider>(context, listen: false).loadAllPosts();
                await _loadUserPosition(); // update location as well
              },
              child: ListView( // Main scrollable list containing grouped events.
                children: [
                  // Button to navigate to the user's own events (on their profile).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to the current user's profile page.
                        final currentUserId = AuthService().getCurrentUid();
                        goToUserPage(widget.navigatorKey, currentUserId);
                      },
                      icon: Icon(Icons.event, color: Colors.white,),
                      label: const Text("View My Events"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ...grouped.entries.expand((entry) {
                    // Return a list containing the date header and the event tiles for that date.
                    return [
                      // Date header.
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      // Map each post in the group to a MyPostTile.
                      ...entry.value.map((post) => MyPostTile(
                            post: post,
                            navigatorKey: widget.navigatorKey, // Pass navigator key for navigation within the tile.
                            // Define actions for tapping user/mosque names within the tile.
                            onTapUser: (uid) => goToUserPage(widget.navigatorKey, uid),
                            onTapMosque: (mosqueId) async {
                              // Fetch mosque details before navigating.
                              final mosque = await Provider.of<DatabaseProvider>(context, listen: false).mosqueProfile(mosqueId);
                              if (mosque != null) {
                                goToMosquePage(widget.navigatorKey, mosque);
                              }
                            },
                          )),
                    ];
                  }),
                ],
              ),
            ),
    );
  }
}
