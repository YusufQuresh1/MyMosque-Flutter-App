import 'package:flutter/material.dart';
import 'package:mymosque/helper/format_text.dart'; // Helper for text formatting (e.g., title casing).
import 'package:mymosque/models/notification_settings.dart' as my; // Custom notification settings model, aliased to avoid name clashes.
import 'package:mymosque/components/follow_button.dart'; // Reusable button component for follow/unfollow actions.
import 'package:mymosque/components/post_tile.dart'; // Reusable widget to display a single post.
import 'package:mymosque/components/profile_stats.dart'; // Reusable widget to display profile statistics (posts, followers, etc.).
import 'package:mymosque/components/prayer_times_card.dart'; // Widget to display prayer times.
import 'package:mymosque/helper/navigate.dart'; // Helper functions for navigation within the app.
import 'package:mymosque/models/mosque.dart'; // Data model representing a mosque.
import 'package:mymosque/models/prayer_times.dart'; // Data model representing prayer times.
import 'package:mymosque/pages/mosque_followers_list_page.dart'; // Page to display lists of followers and admins.
import 'package:mymosque/pages/mosque_profile_settings_page.dart'; // Page for mosque admins to edit profile settings.
import 'package:mymosque/services/database/database_provider.dart'; // Central class for database interactions (fetching/updating data).
import 'package:provider/provider.dart'; // State management package used for accessing DatabaseProvider.
import 'package:url_launcher/url_launcher.dart'; // Package to launch external URLs (like Google Maps).

/// A StatefulWidget that displays the profile page for a specific mosque.
///
/// It shows mosque details, allows following/unfollowing, displays posts,
/// events, prayer times, and provides access to settings and notification preferences.
class MosqueProfilePage extends StatefulWidget {
  /// The [Mosque] object containing the data for the profile being displayed.
  final Mosque mosque;
  /// A [GlobalKey] for the [NavigatorState] of the parent tab.
  /// This is used to perform navigation actions (like going to a user profile)
  /// from within this page, ensuring it happens within the correct navigation stack.
  final GlobalKey<NavigatorState> navigatorKey;

  const MosqueProfilePage({
    super.key,
    required this.mosque,
    required this.navigatorKey,
  });

  @override
  State<MosqueProfilePage> createState() => _MosqueProfilePageState();
}

/// The State class associated with [MosqueProfilePage].
///
/// Manages the dynamic data and user interactions for the mosque profile.
class _MosqueProfilePageState extends State<MosqueProfilePage> {
  /// Provides access to the [DatabaseProvider] and listens for changes.
  /// Used for parts of the UI that need to reactively update when data in the provider changes
  /// (e.g., the list of posts, follower count).
  late final listeningProvider = Provider.of<DatabaseProvider>(context);

  /// Provides access to the [DatabaseProvider] *without* listening for changes.
  /// Used for one-time actions like fetching initial data or calling methods
  /// that update the database (e.g., follow/unfollow, save settings), preventing
  /// unnecessary rebuilds of this widget when unrelated data changes.
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

  /// Tracks whether the currently logged-in user is following the mosque displayed on this page.
  /// Determines the appearance and action of the follow button.
  bool _isFollowing = false;

  /// Controls the visibility of a loading indicator.
  /// True when initial profile data is being fetched, false otherwise.
  bool _isLoading = true;

  /// Stores the number of users following this mosque. Displayed in the profile header.
  int _followerCount = 0;

  /// Stores the number of administrators (affiliated users) for this mosque. Displayed in the profile header.
  int _adminCount = 0;

  /// Stores the fetched prayer times for the current day for this mosque.
  /// Can be null if no prayer times are available.
  PrayerTimes? _prayerTimes;


  @override
  void initState() {
    super.initState();
    // `addPostFrameCallback` ensures that `loadProfileData` runs after the first frame
    // has been built. This is important because `loadProfileData` uses `context`
    // (via Provider) which might not be fully available during the initial `initState` execution.
    WidgetsBinding.instance.addPostFrameCallback((_) => loadProfileData());
  }

  /// Asynchronously fetches all necessary data for the mosque profile from the database.
  ///
  /// This includes:
  /// - Checking if the current user is affiliated with the mosque.
  /// - Loading the list of followers for the mosque (to get the count).
  /// - Checking if the current user is following this mosque.
  /// - Getting the follower count (potentially updated by the previous load).
  /// - Fetching the list of admins (affiliated users) to get the count.
  /// - Fetching today's prayer times for the mosque.
  /// - Loading the user's primary mosque ID to check if it matches this mosque.
  /// Updates the local state variables and sets `_isLoading` to false upon completion.
  Future<void> loadProfileData() async {
    // Always refresh the affiliated mosques list first.
    await databaseProvider.loadAffiliatedMosques();

    // Load follower data (needed for count and potentially follow status).
    await databaseProvider.loadMosqueFollowers(widget.mosque.id);
    _isFollowing = await databaseProvider.isFollowingMosque(widget.mosque.id);

    // Get follower count from the listening provider (might have updated).
    // Note: Using listeningProvider here ensures we get the latest count if it changed elsewhere.
    _followerCount = listeningProvider.getFollowerCount(widget.mosque.id);

    // Fetch admin users to get the count.
    final admins = await databaseProvider.getMosqueAdmins(widget.mosque.id);
    _adminCount = admins.length;

    // Fetch prayer times for today.
    _prayerTimes = await databaseProvider.fetchTodayPrayerTimes(widget.mosque.id);

    // Load the user's primary mosque setting.
    await databaseProvider.loadPrimaryMosqueId();

    // Check if the widget is still mounted before calling setState.
    // This prevents errors if the user navigates away before the async operations complete.
    if (!mounted) return;


    // Update the state to reflect the loaded data and hide the loading indicator.
    // `setState` triggers a rebuild of the widget to display the new data.
    if (mounted) { // Double-check mounted status before setState
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Attempts to launch Google Maps (or a web equivalent) to show the mosque's location.
  ///
  /// Extracts the latitude and longitude from the mosque's data and constructs
  /// a Google Maps query URL. Uses the `url_launcher` package.
  void _openInGoogleMaps() async {
    // Safely access nested location data.
    final geo = widget.mosque.location?['geo'];
    // Exit if geo data (latitude/longitude) is missing.
    if (geo == null) return;

    // Construct the Google Maps URL.
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${geo.latitude},${geo.longitude}");

    // Check if the URL can be launched before attempting.
    if (await canLaunchUrl(uri)) {
      // Launch the URL in an external application (usually the Maps app).
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // If launching fails, show a message to the user.
      // Check mounted status again before accessing context.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  /// Handles the logic for following or unfollowing the mosque.
  ///
  /// Updates the UI optimistically (changes state immediately) and then calls the
  /// corresponding database method. If the database operation fails, it reverts
  /// the UI state change and shows an error message.
  /// Includes a confirmation dialog before unfollowing.
  Future<void> toggleFollow() async {
    if (_isFollowing) {
      // --- Unfollowing Logic ---
      // Show a confirmation dialog before proceeding.
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Unfollow"),
          content: const Text("Are you sure you want to unfollow this mosque?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes")),
          ],
        ),
      );

      // Only proceed if the user confirmed (dialog returned true).
      if (confirm == true) {
        // Optimistic UI update: Assume success.
        setState(() {
          _isFollowing = false;
          _followerCount--; // Decrement follower count locally.
        });
        try {
          // Perform the database operation.
          await databaseProvider.unfollowMosque(widget.mosque.id);
          // If successful, no further UI change needed.
        } catch (_) {
          // Revert UI changes on failure.
          setState(() {
            _isFollowing = true;
            _followerCount++; // Increment follower count back.
          });
          // Show error message.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to unfollow. Please try again.")),
          );
        }
      }
    } else {
      // --- Following Logic ---
      // Optimistic UI update: Assume success.
      setState(() {
        _isFollowing = true;
        _followerCount++; // Increment follower count locally.
      });
      try {
        // Perform the database operation.
        await databaseProvider.followMosque(widget.mosque.id);
        // If successful, no further UI change needed.
      } catch (_) {
        // Revert UI changes on failure.
        setState(() {
          _isFollowing = false;
          _followerCount--; // Decrement follower count back.
        });
        // Show error message.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to follow. Please try again.")),
        );
      }
    }
  }

  /// Displays a modal bottom sheet allowing the user to configure notification
  /// preferences specically for this mosque.
  ///
  /// Fetches current settings, provides toggles for post notifications and
  /// individual prayer time (start/jamaat) notifications, and saves the
  /// changes back to the database. Uses a `StatefulBuilder` to manage the
  /// state *within* the bottom sheet independently of the main page state.
  void _showNotificationSettingsSheet(BuildContext context) async {
    // Use the non-listening provider for database operations.
    final db = databaseProvider;

    // Fetch existing notification settings for this mosque.
    my.NotificationSettings? settings = await db.getNotificationSettings(widget.mosque.id);
    // Define the standard list of prayers for iteration.
    final List<String> prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    // If no settings exist, create a default object with all notifications off.
    settings ??= my.NotificationSettings(
      posts: false, // Default: no post notifications.
      prayerNotifications: {
        // Default: no notifications for any prayer start or jamaat time.
        for (var p in prayers) p: my.PrayerNotification(start: false, jamaat: false),
      },
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take up more height if needed.
      builder: (context) {
        // StatefulBuilder creates a localized state for the bottom sheet content.
        // `setModalState` is like `setState` but only rebuilds the sheet's content.
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView( // Allows content to scroll if it exceeds height.
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Take only necessary vertical space.
                  children: [
                    // --- Modal Title ---
                    Text('Notification Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.inversePrimary)),

                    // --- General toggle for post alerts ---
                    SwitchListTile(
                      title: Text('Notify me when this mosque posts', style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary)),
                      value: settings!.posts, // Use the current state of 'posts' notifications.
                      onChanged: (val) {
                        setModalState(() {
                          settings = my.NotificationSettings(
                            posts: val, // Update the posts value.
                            prayerNotifications: settings!.prayerNotifications, // Keep existing prayer settings.
                          );
                        });
                      },
                      inactiveThumbColor: Theme.of(context).colorScheme.primary,
                      activeColor: Theme.of(context).colorScheme.tertiary,
                    ),
                    const Divider(),

                    // --- Prayer-specific toggles ---
                    const Text('Prayer Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                    // Iterate through the prayer list to create controls for each.
                    ...prayers.map((prayer) {
                      // Get the current notification settings for this specific prayer,
                      final current = settings!.prayerNotifications[prayer] ?? my.PrayerNotification(start: false, jamaat: false);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(prayer.toUpperCase()), // Display prayer name.
                            Row(
                              children: [
                                // Checkbox for 'Start' time notification.
                                Checkbox(
                                  value: current.start,
                                  onChanged: (val) {
                                    // Update the specific prayer's settings within the main 'settings' object.
                                    settings!.prayerNotifications[prayer] = my.PrayerNotification(
                                      start: val ?? false, // Update start value.
                                      jamaat: current.jamaat, // Keep jamaat value.
                                    );
                                    // Trigger rebuild of the modal sheet content.
                                    setModalState(() {});
                                  },
                                  activeColor: Theme.of(context).colorScheme.tertiary,
                                ),
                                const Text('Start'),

                                // Checkbox for 'Jamaat' time notification.
                                Checkbox(
                                  value: current.jamaat,
                                  onChanged: (val) {
                                    // Update the specific prayer's settings.
                                    settings!.prayerNotifications[prayer] = my.PrayerNotification(
                                      start: current.start, // Keep start value.
                                      jamaat: val ?? false, // Update jamaat value.
                                    );
                                    // Trigger rebuild of the modal sheet content.
                                    setModalState(() {});
                                  },
                                  activeColor: Theme.of(context).colorScheme.tertiary,
                                ),
                                const Text('Jamaat'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // --- Save button ---
                    ElevatedButton(
                      onPressed: () async {
                        // Save the modified 'settings' object to the database.
                        await db.saveNotificationSettings(widget.mosque.id, settings!);
                        // Close the bottom sheet.
                        Navigator.pop(context);
                        // Show confirmation message.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preferences saved')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white, // Text color on the button.
                      ),
                      child: const Text('Save'),
                    ),

                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter posts from the global list to get only those belonging to this mosque.
    // Uses the listeningProvider to ensure the list updates if new posts arrive.
    final mosquePosts = listeningProvider.allPosts.where((p) => p.mosqueId == widget.mosque.id).toList();

    // Further filter the mosque's posts to find upcoming events.
    // An event is upcoming if it has a date_time that is in the future.
    final upcomingEvents = mosquePosts.where((post) =>
        post.event != null && // Check if event data exists.
        post.event!['date_time'] != null && // Check if the specific date field exists.
        post.event!['date_time'].toDate().isAfter(DateTime.now()) // Check if the date is in the future.
    ).toList();

    // Location details for display.
    final geo = widget.mosque.location?['geo'];
    final address = widget.mosque.location?['address'];

    // Manages the state for the TabBar and TabBarView.
    return DefaultTabController(
      length: 3, // Number of tabs.
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          // Actions appear on the right side of the AppBar.
        actions: [
          Consumer<DatabaseProvider>(
            builder: (context, db, _) {
              final isAffiliated = db.isAffiliatedWithMosque(widget.mosque.id);
              return isAffiliated
                  ? IconButton(
                      icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                      tooltip: "Mosque Settings",
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MosqueProfileSettingsPage(mosque: widget.mosque),
                          ),
                        );
                        if (result == true) {
                          Navigator.of(context).pop();
                        }
                      },
                    )
                  : const SizedBox.shrink();
            },
          ),
          // Keep your star and bell icons as they are.
          Consumer<DatabaseProvider>(
            builder: (context, dbProvider, _) {
              final isPrimary = dbProvider.primaryMosqueId == widget.mosque.id;
              return IconButton(
                icon: Icon(
                  isPrimary ? Icons.star : Icons.star_border,
                  color: isPrimary ? Colors.amber : Theme.of(context).colorScheme.primary,
                ),
                tooltip: isPrimary ? "Unmark as Primary Mosque" : "Mark as Primary Mosque",
                onPressed: () async {
                  if (isPrimary) {
                    await databaseProvider.setPrimaryMosque(null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Primary mosque removed")),
                    );
                  } else {
                    await databaseProvider.setPrimaryMosque(widget.mosque.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Marked as your primary mosque")),
                    );
                  }
                },
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.primary),
            tooltip: "Notification Settings",
            onPressed: () => _showNotificationSettingsSheet(context),
          ),
        ],

        ),
        // Show a loading indicator while data is being fetched, otherwise show the profile content.
body: RefreshIndicator(
  onRefresh: () async {
    setState(() => _isLoading = true);
    await loadProfileData();
  },
  child: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Enables swipe even if content is short
          child: Column(
            children: [
              // -------- Profile Header Section --------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mosque Icon
                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Icon(
                              Icons.mosque,
                              color: HSLColor.fromColor(Theme.of(context).colorScheme.tertiary)
                                  .withSaturation(0.2)
                                  .toColor(),
                              size: 48,
                            ),
                          ),
                        ),
                        // Name and Stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                toTitleCase(widget.mosque.name),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.inversePrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              MyProfileStats(
                                alignment: MainAxisAlignment.start,
                                stats: [
                                  {"label": "Posts", "count": mosquePosts.length},
                                  {
                                    "label": "Followers",
                                    "count": _followerCount,
                                    "onTap": () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MosqueFollowersListPage(
                                          mosqueId: widget.mosque.id,
                                          mosqueName: toTitleCase(widget.mosque.name),
                                          initialTab: 0,
                                          navigatorKey: widget.navigatorKey,
                                        ),
                                      ),
                                    ),
                                  },
                                  {
                                    "label": "Admins",
                                    "count": _adminCount,
                                    "onTap": () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MosqueFollowersListPage(
                                          mosqueId: widget.mosque.id,
                                          mosqueName: toTitleCase(widget.mosque.name),
                                          initialTab: 1,
                                          navigatorKey: widget.navigatorKey,
                                        ),
                                      ),
                                    ),
                                  },
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (geo != null && address != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: _openInGoogleMaps,
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Theme.of(context).colorScheme.tertiary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (widget.mosque.hasWomenSection)
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Row(
                              children: [
                                Icon(Icons.female, size: 16, color: Theme.of(context).colorScheme.tertiary),
                                const SizedBox(width: 4),
                                Text(
                                  "Women's section",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        widget.mosque.description,
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: MyFollowButton(
                        onPressed: toggleFollow,
                        isFollowing: _isFollowing,
                      ),
                    ),
                  ],
                ),
              ),
              // -------- Tab Bar Section --------
              TabBar(
                dividerColor: Colors.transparent,
                labelColor: Theme.of(context).colorScheme.inversePrimary,
                unselectedLabelColor: Theme.of(context).colorScheme.primary,
                indicatorColor: Theme.of(context).colorScheme.tertiary,
                tabs: const [
                  Tab(text: "Prayer Times"),
                  Tab(text: "Posts"),
                  Tab(text: "Upcoming Events"),
                ],
              ),
              // -------- Tab Content Section --------
              SizedBox(
                height: MediaQuery.of(context).size.height, // Force enough height for scrolling
                child: TabBarView(
                  children: [
                    _prayerTimes != null
                        ? SingleChildScrollView(child: PrayerTimesCard(prayerTimes: _prayerTimes!))
                        : const Center(child: Text("Prayer times not available for today")),
                    mosquePosts.isEmpty
                        ? const Center(child: Text("No posts yet..."))
                        : ListView.builder(
                            itemCount: mosquePosts.length,
                            itemBuilder: (context, index) => MyPostTile(
                              post: mosquePosts[index],
                              navigatorKey: widget.navigatorKey,
                              onTapUser: (uid) => goToUserPage(widget.navigatorKey, uid),
                              onTapMosque: (mosqueId) async {
                                final mosque = await databaseProvider.mosqueProfile(mosqueId);
                                if (mosque != null) goToMosquePage(widget.navigatorKey, mosque);
                              },
                            ),
                          ),
                    upcomingEvents.isEmpty
                        ? const Center(child: Text("No upcoming events..."))
                        : ListView.builder(
                            itemCount: upcomingEvents.length,
                            itemBuilder: (context, index) => MyPostTile(
                              post: upcomingEvents[index],
                              navigatorKey: widget.navigatorKey,
                              onTapUser: (uid) => goToUserPage(widget.navigatorKey, uid),
                              onTapMosque: (mosqueId) async {
                                final mosque = await databaseProvider.mosqueProfile(mosqueId);
                                if (mosque != null) goToMosquePage(widget.navigatorKey, mosque);
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
),

      ),
    );
  }
}
