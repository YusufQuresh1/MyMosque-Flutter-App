import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mymosque/pages/nearby_mosques_page.dart'; // Page for displaying nearby mosques.
import 'package:mymosque/pages/profile_landing_page.dart'; // Landing page for user profile related actions.
import 'package:provider/provider.dart'; // State management package.
import 'package:mymosque/components/post_tile.dart'; // Reusable tile for displaying posts.
import 'package:mymosque/helper/navigate.dart'; // Helper functions for in-app navigation.
import 'package:mymosque/models/post.dart'; // Data model for posts.
import 'package:mymosque/pages/create_post_page.dart'; // Page for creating new posts.
import 'package:mymosque/pages/events_page.dart'; // Page for displaying upcoming events.
import 'package:mymosque/pages/search_page.dart'; // Page for searching users/mosques.
import 'package:mymosque/services/auth/auth_service.dart'; // Service for authentication.
import 'package:mymosque/services/database/database_provider.dart'; // Service for database interactions.

/// The main landing page of the app, hosting the bottom navigation bar
/// and the different top-level sections (Home Feed, Events, Search, Nearby, Profile).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Index of the currently selected tab in the bottom navigation bar.
  int _currentIndex = 0;
  /// List of GlobalKeys, one for each tab's Navigator. This allows each tab
  /// to maintain its own navigation stack independently.
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(5, (_) => GlobalKey<NavigatorState>());

  /// Non-listening provider instance for database actions initiated from HomePage.
  late final databaseProvider =
      Provider.of<DatabaseProvider>(context, listen: false);
  /// UID of the currently logged-in user.
  final String currentUserId = AuthService().getCurrentUid();
  /// Stores the gender of the current user, used for filtering posts/events.
  String? _userGender;

  @override
  void initState() {
    super.initState();
    debugPrint("HomePage initState called");
    // Load initial user data and posts after the first frame build.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint("Running _initUserData()");
      await _initUserData();
      debugPrint("Finished loading user data");
    });
  }

  /// Loads essential data when the HomePage initialises or is refreshed.
  /// Fetches user affiliations, following lists, posts, and notifications.
  /// Also fetches the user's profile to get their gender for filtering.
  Future<void> _initUserData() async {
    await databaseProvider.loadUserAffiliatedMosqueIds();
    await databaseProvider.loadUserFollowing(currentUserId);
    await databaseProvider.loadAllPosts(); // Load posts for the "For You" feed.
    await databaseProvider.loadInboxNotifications(); // Load notifications for the badge count.

    // Fetch user profile to determine gender for filtering.
    final profile = await databaseProvider.userProfile(currentUserId);
    if (mounted) {
      setState(() {
        _userGender = profile?.gender.toLowerCase();
      });
    }
  }

  /// Opens the Create Post page. Checks if the user is affiliated with any mosque first.
  void _openPostPage() async {
    // Fetch the list of mosques the user is affiliated with.
    final affiliatedMosques = await databaseProvider.getUserAffiliatedMosques();

    // Prevent navigation if the user isn't affiliated with any mosque.
    if (affiliatedMosques.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be affiliated with a mosque to post.")),
      );
      return;
    }
    // Navigate to the CreatePostPage if affiliations exist.
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(affiliatedMosques: affiliatedMosques),
        fullscreenDialog: true, // Presents the page as a modal dialog.
      ),
    );
  }

  /// Builds the list of widgets corresponding to each tab in the bottom navigation bar.
  /// Each tab is wrapped in `_buildTabNavigator` to manage its navigation stack.
  List<Widget> _tabViews() => [
        _buildTabNavigator(0, _homeTab(_navigatorKeys[0])), // Home feed tab
        _buildTabNavigator(1, EventsPage(navigatorKey: _navigatorKeys[1])), // Events tab
        _buildTabNavigator(2, SearchPage(navigatorKey: _navigatorKeys[2])), // Search tab
        _buildTabNavigator(3, NearbyMosquesPage(navigatorKey: _navigatorKeys[3])), // Nearby Mosques tab
        _buildTabNavigator(4, ProfileLandingPage(navigatorKey: _navigatorKeys[4])), // Profile tab
      ];

  /// Wraps each tab's root widget in an Offstage and a Navigator.
  /// The Offstage widget hides inactive tabs while preserving their state.
  /// The Navigator allows each tab to have its own navigation history.
  Widget _buildTabNavigator(int index, Widget child) {
    return Offstage(
      // Only show the widget if it's the currently selected tab.
      offstage: _currentIndex != index,
      // Each tab gets its own Navigator with a unique key.
      child: Navigator(
        key: _navigatorKeys[index],
        // Define the initial route for this tab's Navigator.
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
      ),
    );
  }

  /// Builds the content for the first tab (Home), which includes "For You" and "Following" feeds.
  Widget _homeTab(GlobalKey<NavigatorState> navigatorKey) {
    // DefaultTabController manages the state for the inner tabs ("For You", "Following").
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("MyMosque"),
          actions: [
            // Inbox icon with notification badge.
            Consumer<DatabaseProvider>(
              builder: (context, db, _) {
                // Calculate the number of unread notifications.
                final unreadCount =
                    db.inboxNotifications.where((n) => !n.read).length;
                return IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.inbox,
                          size: 28,
                          color: Theme.of(context).colorScheme.inversePrimary),
                      // Display badge only if there are unread notifications.
                      if (unreadCount > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Navigate to the Inbox page using the home tab's navigator key.
                  onPressed: () => goToInboxPage(navigatorKey),
                );
              },
            ),
          ],
          // Inner TabBar for "For You" and "Following".
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.tertiary,
            tabs: const [
              Tab(text: "For You"),
              Tab(text: "Following"),
            ],
          ),
        ),
        // Body contains the TabBarView for the inner tabs.
        body: Consumer<DatabaseProvider>( // Use Consumer to rebuild when posts change.
          builder: (context, db, _) => TabBarView(
            children: [
              // "For You" Tab Content with pull-to-refresh.
              RefreshIndicator(
                onRefresh: () async {
                  // Reload posts and notifications on refresh.
                  await db.loadAllPosts();
                  await db.loadInboxNotifications();
                },
                // Build the filtered post list for the "For You" feed.
                child: _buildFilteredPostList(db.allPosts, navigatorKey),
              ),
              // "Following" Tab Content with pull-to-refresh.
              RefreshIndicator(
                onRefresh: () async {
                  // Reload posts from followed sources and notifications.
                  await db.loadFollowingPosts();
                  await db.loadInboxNotifications();
                },
                // Build the post list using only posts from followed sources.
                child: _buildPostList(db.followingPosts, navigatorKey),
              ),
            ],
          ),
        ),
        // Floating Action Button to create a new post.
        // Uses FutureBuilder to only show the button if the user is affiliated with a mosque.
        floatingActionButton: FutureBuilder<List<dynamic>>( // Specify type for clarity
          future: databaseProvider.getUserAffiliatedMosques(),
          builder: (context, snapshot) {
            // Show button only if data is loaded and the list is not empty.
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink(); // Return empty widget if no affiliations.
            }
            return FloatingActionButton(
              onPressed: _openPostPage,
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              child: const Icon(Icons.post_add),
              tooltip: 'Create Post',
            );
          },
        ),
      ),
    );
  }

  /// Builds a ListView of posts using the MyPostTile component.
  Widget _buildPostList(List<Post> posts, GlobalKey<NavigatorState> navigatorKey) {
    return Container(

      color: Theme.of(context).colorScheme.secondary,
      child: posts.isEmpty
          ? const Center(child: Text("No posts available")) // Message when list is empty.
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return MyPostTile(
                  post: post,
                  navigatorKey: navigatorKey, // Pass key for navigation within the tile.
                  // Navigate to user profile on tap.
                  onTapUser: (uid) => goToUserPage(navigatorKey, uid),
                  // Navigate to mosque profile on tap.
                  onTapMosque: (mosqueId) async {
                    // Fetch mosque details before navigating.
                    final mosque = await databaseProvider.mosqueProfile(mosqueId);
                    if (mosque != null) {
                      goToMosquePage(navigatorKey, mosque);
                    }
                  },
                );
              },
            ),
    );
  }

  /// Filters the list of all posts for the "For You" feed.
  /// Excludes user's own posts, expired events, and events with mismatched gender restrictions.
  Widget _buildFilteredPostList(List<Post> posts, GlobalKey<NavigatorState> navigatorKey) {
    final now = DateTime.now();
    final filtered = posts.where((post) {
      // Exclude posts made by the current user.
      if (post.uid == currentUserId) return false;

      final eventData = post.event;
      if (eventData != null) {
        // Exclude events that have already ended.
        final endTime = (eventData['end_time'] as Timestamp?)?.toDate();
        if (endTime != null && endTime.isBefore(now)) return false;

        // Exclude events based on gender restriction
        final restriction = (eventData['gender_restriction'] as String?)?.toLowerCase();
        if (_userGender != null) { // Only apply gender filter if user's gender is set.
          if (restriction == 'male' && _userGender != 'male') return false;
          if (restriction == 'female' && _userGender != 'female') return false;
        }
      }

      // If none of the exclusion criteria match, include the post.
      return true;
    }).toList();

    // Build the list view with the filtered posts.
    return _buildPostList(filtered, navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a Stack to layer the Offstage navigators. Only the active one is visible.
      body: Stack(children: _tabViews()),
      // Bottom Navigation Bar setup.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex, // Highlight the active tab.
        onTap: (index) => setState(() => _currentIndex = index), // Update state on tap.
        selectedItemColor: Theme.of(context).colorScheme.tertiary, 
        unselectedItemColor: Theme.of(context).colorScheme.primary,
        type: BottomNavigationBarType.fixed, // Ensures all items are always visible.
        showSelectedLabels: false, 
        showUnselectedLabels: false,
        items: const [
          // Define each item in the navigation bar.
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 35),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event, size: 35),
            label: "Events",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search, size: 35),
            label: "Search",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on, size: 35),
            label: "Nearby",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, size: 35),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
