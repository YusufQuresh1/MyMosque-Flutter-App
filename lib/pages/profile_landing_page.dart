import 'package:flutter/material.dart';
import 'package:mymosque/components/mosque_list_tile.dart';
import 'package:mymosque/components/prayer_times_card.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/models/prayer_times.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/helper/navigate.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// The landing page for the user's profile tab.
///
/// This displays a quick overview of:
/// - the current user (as a tappable card),
/// - their primary mosque (if one is set), along with today's prayer times,
/// - and any mosques they are affiliated with.
///
/// It also provides access to the settings page through the top-right icon.
class ProfileLandingPage extends StatefulWidget {
  /// Used to enable navigation while preserving the bottom navigation bar.
  final GlobalKey<NavigatorState> navigatorKey;

  const ProfileLandingPage({super.key, required this.navigatorKey});

  @override
  State<ProfileLandingPage> createState() => _ProfileLandingPageState();
}

class _ProfileLandingPageState extends State<ProfileLandingPage> {
  late DatabaseProvider databaseProvider;     // Used for calling data-fetching methods
  late DatabaseProvider listeningProvider;    // Used to listen for changes (e.g. primary mosque updates)
  late String currentUserId;                  // ID of the currently signed-in user

  UserProfile? user;                          // The current user's profile data
  List<Mosque> affiliatedMosques = [];        // Mosques the user is affiliated with
  Mosque? primaryMosque;                      // The user’s selected primary mosque (optional)
  PrayerTimes? primaryPrayerTimes;            // Today's prayer times for the primary mosque
  bool isLoading = true;                      // Tracks loading state for the entire screen

  @override
  void initState() {
    super.initState();
    databaseProvider = context.read<DatabaseProvider>();
    currentUserId = AuthService().getCurrentUid();

    // Load user and affiliated mosque data after initial frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up a second provider listener for reactive updates
    listeningProvider = Provider.of<DatabaseProvider>(context);
    
    // Refresh primary mosque info when dependencies update (e.g. after changing primary
    _loadPrimaryMosque();
  }

  /// Loads the current user profile and affiliated mosques.
  /// This is called initially and when the screen is refreshed.
  Future<void> _loadData() async {
    final fetchedUser = await databaseProvider.userProfile(currentUserId);
    final fetchedMosques = await databaseProvider.getUserAffiliatedMosques();

    if (mounted) {
      setState(() {
        user = fetchedUser;
        affiliatedMosques = fetchedMosques;
      });
    }

    // Load primary mosque info afterwards
    await _loadPrimaryMosque();
  }

  /// Loads the user's primary mosque (if set), and retrieves today's prayer times.
  /// If no primary mosque exists, both fields are cleared.
  Future<void> _loadPrimaryMosque() async {

    await databaseProvider.loadPrimaryMosqueId();
    final primaryMosqueId = databaseProvider.primaryMosqueId;

    if (primaryMosqueId != null) {
      final mosque = await databaseProvider.mosqueProfile(primaryMosqueId);
      final times = await databaseProvider.fetchTodayPrayerTimes(primaryMosqueId);
      if (mounted) {
        setState(() {
          primaryMosque = mosque;
          primaryPrayerTimes = times;
          isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          primaryMosque = null;
          primaryPrayerTimes = null;
          isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      
      // Top app bar with title and settings button
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => goToSettingsPage(widget.navigatorKey), // Navigates to settings page
          ),
        ],
      ),
      /// Pull-to-refresh functionality to reload user and mosque data     
      body: RefreshIndicator(
        onRefresh: _loadData, // Reloads user and mosque data
        child: isLoading
            ? const Center(child: CircularProgressIndicator()) // While loading, show spinner

            // Show fallback if user data couldn't be loaded
            : user == null
                ? const Center(child: Text("User not found")) // Fallback if user not found

                // Main profile content
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // -------------------------- User Profile Card --------------------------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // Makes the entire tile tappable (navigates to full profile)
                        child: InkWell(
                          onTap: () => goToUserPage(widget.navigatorKey, user!.uid),
                          child: Row(
                            children: [
                              // Profile icon
                              const CircleAvatar(
                                radius: 24,
                                child: Icon(Icons.person, size: 24),
                              ),
                              const SizedBox(width: 12),
                              // User name and username display
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user!.name,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.inversePrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '@${user!.username}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Navigation indicator
                              Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // -------------------------- Primary Mosque Section --------------------------
                      if (primaryMosque != null) ...[
                        Text(
                          "Primary Mosque",
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.inversePrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),

                        // Primary mosque tile (tappable to open profile)
                        MyMosqueTile(mosque: primaryMosque!, navigatorKey: widget.navigatorKey),
                        const SizedBox(height: 8),

                        // Today's prayer times (if available)
                        if (primaryPrayerTimes != null)
                          PrayerTimesCard(prayerTimes: primaryPrayerTimes!),
                        const SizedBox(height: 16),
                      ],

                      // -------------------------- Affiliated Mosques Section --------------------------
                      Text(
                        "Affiliated Mosques",
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Show either a message or the list of affiliated mosques
                      affiliatedMosques.isEmpty
                          ? Text(
                              "You're not affiliated with any mosques.",
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
                            )
                          // List all affiliated mosques using MyMosqueTile component
                          : ListView.separated(
                              physics: const NeverScrollableScrollPhysics(), // Prevent nested scrolling
                              shrinkWrap: true,
                              itemCount: affiliatedMosques.length,
                              separatorBuilder: (_, __) => const Divider(height: 10),
                              itemBuilder: (context, index) {
                                return MyMosqueTile(
                                  mosque: affiliatedMosques[index],
                                  navigatorKey: widget.navigatorKey,
                                );
                              },
                            ),
                    ],
                  ),
      ),

    );
  }
}
