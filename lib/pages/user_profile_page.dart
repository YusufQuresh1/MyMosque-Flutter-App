import 'package:flutter/material.dart';
import 'package:mymosque/components/request_button.dart';
import 'package:mymosque/components/post_tile.dart';
import 'package:mymosque/components/profile_stats.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/pages/mosque_profile_page.dart';
import 'package:mymosque/pages/user_following_list_page.dart.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// Displays a user profile page including name, username, stats (posts, mosques followed, friends),
/// bio, posts, and events. 
/// If the viewed profile is not the current user, the page also includes friend request functionality.
///
/// It supports dynamic content based on whether the viewer is the profile owner or not.
class ProfilePage extends StatefulWidget {
  final String uid;
  final GlobalKey<NavigatorState> navigatorKey;

  const ProfilePage({
    super.key,
    required this.uid,
    required this.navigatorKey,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Providers for accessing global data and functions.
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

  final String currentUserId = AuthService().getCurrentUid();
  UserProfile? user;                  // User being viewed
  bool _isLoading = true;             // Used to show loading spinner
  int _followingCount = 0;            // Number of mosques the user follows
  int _friendCount = 0;               // Number of users this user is friends with
  List<String> attendingPostIds = []; // List of post IDs where this user is marked as attending


  @override
  void initState() {
    super.initState();
    loadUser(); // Load profile data when the page is first opened
  }

  /// Loads user profile data, followed mosques, friend info,
  /// and event attendance. Called on page load and pull-to-refresh.
  Future<void> loadUser() async {
    user = await databaseProvider.userProfile(widget.uid);
    _followingCount = await databaseProvider.getFollowingMosquesCount(widget.uid);
    await databaseProvider.loadFriends(widget.uid);
    await databaseProvider.loadFriendRequests(currentUserId);
    await databaseProvider.loadFriendRequests(widget.uid);
    _friendCount = databaseProvider.getFriends(widget.uid).length;

    // Load event attendance and track which events the user is attending
    final allPosts = listeningProvider.allPosts;
    for (final post in allPosts) {
      if (post.event != null) {
        await databaseProvider.loadEventAttendance(post.id, widget.uid);
        if (listeningProvider.isAttending(post.id, widget.uid)) {
          attendingPostIds.add(post.id);
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Builds the content of the "Events" tab.
  /// Filters and sorts event posts based on whether the profile user is attending.
  /// Friends can view each other's events; non-friends cannot.
  Widget _buildEventTab(bool isOwnProfile) {
  final allEvents = listeningProvider.allPosts.where((post) {
    return post.event != null && attendingPostIds.contains(post.id);
  }).toList()
    ..sort((a, b) {
      final aTime = (a.event?['start_time'] ?? a.event?['date_time'])?.toDate();
      final bTime = (b.event?['start_time'] ?? b.event?['date_time'])?.toDate();
      return (bTime ?? DateTime(0)).compareTo(aTime ?? DateTime(0));
    });

  return allEvents.isEmpty
      ? Center(child: Text(isOwnProfile ? "No events yet..." : "No events attended..."))
      : ListView.builder(
          itemCount: allEvents.length,
          itemBuilder: (context, index) => MyPostTile(
            post: allEvents[index],
            navigatorKey: widget.navigatorKey,
            onTapUser: (uid) {
              widget.navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(
                    uid: uid,
                    navigatorKey: widget.navigatorKey,
                  ),
                ),
              );
            },
            onTapMosque: (mosqueId) async {
              final mosque = await databaseProvider.mosqueProfile(mosqueId);
              if (mosque != null) {
                widget.navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => MosqueProfilePage(
                      mosque: mosque,
                      navigatorKey: widget.navigatorKey,
                    ),
                  ),
                );
              }
            },
          ),
        );
}


  @override
  Widget build(BuildContext context) {
    final allUserPosts = listeningProvider.filterUserPosts(widget.uid);
    final isOwnProfile = widget.uid == currentUserId;
    final isFriend = listeningProvider.getFriends(currentUserId).contains(widget.uid);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Profile Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile display picture and user details
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: const Icon(Icons.person, size: 48),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? "User",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "@${user?.username ?? "username"}",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Stats: Posts, Mosques followed, Friends
                                  MyProfileStats(
                                    alignment: MainAxisAlignment.start,
                                    stats: [
                                      {"label": "Posts", "count": allUserPosts.length},
                                      {
                                        "label": "Mosques",
                                        "count": _followingCount,
                                        "onTap": () => widget.navigatorKey.currentState?.push(
                                              MaterialPageRoute(
                                                builder: (_) => UserFollowingListPage(
                                                  uid: widget.uid,
                                                  initialTabIndex: 0,
                                                  navigatorKey: widget.navigatorKey,
                                                ),
                                              ),
                                            )
                                      },
                                      {
                                        "label": "Friends",
                                        "count": _friendCount,
                                        "onTap": () => widget.navigatorKey.currentState?.push(
                                              MaterialPageRoute(
                                                builder: (_) => UserFollowingListPage(
                                                  uid: widget.uid,
                                                  initialTabIndex: 2,
                                                  navigatorKey: widget.navigatorKey,
                                                ),
                                              ),
                                            )
                                      },
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // User bio
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            user?.bio ?? "",
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Friend request button for visiting someone else's profile
                        if (!isOwnProfile)
                          SizedBox(
                            width: double.infinity,
                            child: MyRequestButton( //Dynamic button based on friend status
                              requestType: 'friend',
                              isRequested: listeningProvider.getFriendRequests(widget.uid).contains(currentUserId),
                              hasIncomingRequest: listeningProvider.getFriendRequests(currentUserId).contains(widget.uid),
                              isAccepted: isFriend,
                              onRequest: () => databaseProvider.sendFriendRequest(widget.uid),
                              onRemove: () => databaseProvider.removeFriend(widget.uid),
                              onAccept: () async {
                                await databaseProvider.acceptFriendRequest(widget.uid);
                                setState(() {}); // Refresh UI after accepting
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Tabs for Posts and Events
                  TabBar(
                    dividerColor: Colors.transparent,
                    labelColor: Theme.of(context).colorScheme.inversePrimary,
                    unselectedLabelColor: Theme.of(context).colorScheme.primary,
                    indicatorColor: Theme.of(context).colorScheme.tertiary,
                    tabs: const [
                      Tab(text: "Posts"),
                      Tab(text: "Events"),
                    ],
                  ),
                  // Tab views: User posts and attended events
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: loadUser, // Pull to refresh the whole profile
                      child: TabBarView(
                        children: [
                          allUserPosts.isEmpty
                              ? const Center(child: Text("No posts yet..."))
                              : ListView.builder(
                                  itemCount: allUserPosts.length,
                                  itemBuilder: (context, index) => MyPostTile(
                                    post: allUserPosts[index],
                                    navigatorKey: widget.navigatorKey,
                                    onTapUser: (uid) { // Go to user's profile page when username is tapped
                                      widget.navigatorKey.currentState?.push(
                                        MaterialPageRoute(
                                          builder: (_) => ProfilePage(
                                            uid: uid,
                                            navigatorKey: widget.navigatorKey,
                                          ),
                                        ),
                                      );
                                    },
                                    onTapMosque: (mosqueId) async { // Go to mosque's profile page when username is tapped
                                      final mosque = await databaseProvider.mosqueProfile(mosqueId);
                                      if (mosque != null) {
                                        widget.navigatorKey.currentState?.push(
                                          MaterialPageRoute(
                                            builder: (_) => MosqueProfilePage(
                                              mosque: mosque,
                                              navigatorKey: widget.navigatorKey,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                          // Show event tab content only to self or friends
                          isOwnProfile || isFriend
                              ? _buildEventTab(isOwnProfile)
                              : const Center(child: Text("Only friends can see this user's events.")),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
      ),
    );
  }
}
