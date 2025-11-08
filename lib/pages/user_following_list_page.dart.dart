import 'package:flutter/material.dart';
import 'package:mymosque/components/mosque_list_tile.dart';
import 'package:mymosque/components/user_list_tile.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// Displays a tabbed page showing a user's connections:
/// - Mosques they follow
/// - Mosques they are affiliated with
/// - Friends (plus pending friend requests if it's their own profile)
///
/// This page is accessible from a user profile by tapping on the stats (Mosques or Friends).
class UserFollowingListPage extends StatefulWidget {
  /// UID of the user whose following data is being viewed.
  final String uid;

  /// Determines which tab is initially selected (0 = Following, 1 = Affiliated, 2 = Friends).
  final int initialTabIndex;

  /// Navigator key used to enable nested navigation without breaking the tab view.
  final GlobalKey<NavigatorState> navigatorKey;

  const UserFollowingListPage({
    super.key,
    required this.uid,
    this.initialTabIndex = 0,
    required this.navigatorKey,
  });

  @override
  State<UserFollowingListPage> createState() => _UserFollowingListPageState();
}

class _UserFollowingListPageState extends State<UserFollowingListPage> {
  // Providers for managing app-wide data and state access
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

  // Lists to hold retrieved data
  List<Mosque> followingMosques = [];
  List<Mosque> affiliatedMosques = [];
  List<UserProfile> friends = [];
  List<UserProfile> requests = [];

  // UID of the currently logged-in user
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = AuthService().getCurrentUid(); // Retrieve current user's UID from Firebase
    loadAllData(); // Load all necessary data for the tabs
  }

  /// Loads all three types of user connections:
  /// 1. Mosques the user follows
  /// 2. Mosques the user is affiliated with
  /// 3. Friends and pending friend requests
  ///
  /// This method is also called to refresh the page after accepting or rejecting requests.
  Future<void> loadAllData() async {
    final mosques = await databaseProvider.getFollowingMosques(widget.uid);
    final affiliated = await databaseProvider.getUserAffiliatedMosques(uid: widget.uid);
    await databaseProvider.loadFriends(widget.uid);
    await databaseProvider.loadFriendRequests(widget.uid);

    final friendUids = databaseProvider.getFriends(widget.uid);
    final requestUids = databaseProvider.getFriendRequests(widget.uid);

    List<UserProfile> friendProfiles = [];
    List<UserProfile> requestProfiles = [];

    // Fetch profile data for all friends
    for (var uid in friendUids) {
      final user = await databaseProvider.userProfile(uid);
      if (user != null) friendProfiles.add(user);
    }

    // Fetch profile data for all pending requests
    for (var uid in requestUids) {
      final user = await databaseProvider.userProfile(uid);
      if (user != null) requestProfiles.add(user);
    }

    // Update UI state once all data is loaded
    if (mounted) {
      setState(() {
        followingMosques = mosques;
        affiliatedMosques = affiliated;
        friends = friendProfiles;
        requests = requestProfiles;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Three tabs: Following, Affiliated, Friends
      initialIndex: widget.initialTabIndex, // Which tab should be shown first
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          bottom: TabBar(
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: const [
              Tab(text: "Following"),
              Tab(text: "Affiliated"),
              Tab(text: "Friends"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMosqueList(followingMosques, "Not following any mosques"),
            _buildMosqueList(affiliatedMosques, "No mosque affiliations"),
            _buildFriendsList(),
          ],
        ),
      ),
    );
  }

  /// Renders a list of mosques using [MyMosqueTile].
  /// If the list is empty, shows a fallback message.
  Widget _buildMosqueList(List<Mosque> mosques, String emptyMessage) {
    return mosques.isEmpty
        ? Center(child: Text(emptyMessage))
        : ListView.builder(
            itemCount: mosques.length,
            itemBuilder: (context, index) {
              final mosque = mosques[index];
              return MyMosqueTile(
                mosque: mosque,
                navigatorKey: widget.navigatorKey,
              );
            },
          );
  }

  /// Builds the Friends tab, showing:
  /// - Incoming friend requests (only visible to the current user)
  /// - Accepted friends
  ///
  /// Each user is displayed via [MyUserTile], which supports actions like Accept or Reject.
  Widget _buildFriendsList() {
    return ListView(
      children: [
        // Show friend requests if this is the current user's own profile
        if (widget.uid == currentUserId && requests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Friend Requests",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        // Display friend request tiles with Accept/Reject actions
        if (widget.uid == currentUserId)
          ...requests.map((user) => MyUserTile(
                user: user,
                navigatorKey: widget.navigatorKey,
                isRequest: true,
                onAccept: () async {
                  await databaseProvider.acceptFriendRequest(user.uid);
                  await loadAllData(); // Refresh list after accepting
                },
                onReject: () async {
                  await databaseProvider.rejectFriendRequest(user.uid);
                  await loadAllData(); // Refresh list after rejecting
                },
              )),
        // Friends section (visible to any viewer)
        if (friends.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Friends",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        
        // List of accepted friends
        ...friends.map((user) => MyUserTile(
              user: user,
              navigatorKey: widget.navigatorKey,
            )),

        // Message shown if the user has no friends or requests
        if (requests.isEmpty && friends.isEmpty)
          const Center(child: Text("No friends yet")),
      ],
    );
  }

}
