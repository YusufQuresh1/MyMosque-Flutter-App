import 'package:flutter/material.dart';
import 'package:mymosque/models/user.dart'; // Data model for user profiles.
import 'package:mymosque/services/database/database_provider.dart'; // Service for database interactions.
import 'package:mymosque/components/user_list_tile.dart'; // Reusable tile for displaying user info.
import 'package:mymosque/components/request_button.dart'; // Button for handling affiliation requests.
import 'package:provider/provider.dart'; // State management for accessing providers.
import 'package:mymosque/services/auth/auth_service.dart'; // Service for authentication related tasks.

/// Displays lists of followers and administrators for a specific mosque.
/// Also handles affiliation requests (viewing, accepting/rejecting for admins,
/// sending/removing for regular users).
class MosqueFollowersListPage extends StatefulWidget {
  /// The ID of the mosque whose followers/admins are being displayed.
  final String mosqueId;
  /// The name of the mosque, used for the AppBar title.
  final String mosqueName;
  /// The initial tab index to display (0 for Followers, 1 for Admins).
  final int initialTab;
  /// Navigator key passed from the parent, enabling navigation within the correct context (e.g., to user profiles).
  final GlobalKey<NavigatorState> navigatorKey;

  const MosqueFollowersListPage({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
    required this.navigatorKey,
    this.initialTab = 0,
  });

  @override
  State<MosqueFollowersListPage> createState() => _MosqueFollowersListPageState();
}

class _MosqueFollowersListPageState extends State<MosqueFollowersListPage> {
  /// Provider instance for database operations, not listening to changes.
  /// Used for fetching data and performing actions.
  late DatabaseProvider databaseProvider;
  /// Provider instance that listens for database changes.
  late DatabaseProvider listeningProvider;
  /// The UID of the currently logged-in user.
  String currentUserId = AuthService().getCurrentUid();

  // --- State Variables ---
  List<UserProfile> followers = []; // List of users following the mosque.
  List<UserProfile> admins = []; // List of mosque administrators.
  List<UserProfile> requests = []; // List of users requesting affiliation.
  bool _isLoading = true; // Controls the loading indicator visibility.
  bool isAdmin = false; // True if the current user is an admin of this mosque.
  bool isAffiliated = false; // True if the current user is affiliated (an admin) with this mosque.
  bool hasRequested = false; // True if the current user has requested affiliation.

  @override
  void initState() {
    super.initState();
    // Initialize providers and load user data after the first frame.
    // `context.read` is used here as it's inside initState's callback, equivalent to listen: false.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      listeningProvider = context.read<DatabaseProvider>();
      databaseProvider = context.read<DatabaseProvider>();
      loadUsers();
    });
  }

  /// Fetches all necessary user lists (followers, admins, requests) and determines
  /// the current user's status (admin, affiliated, requested) relative to the mosque.
  Future<void> loadUsers() async {
    // Fetch UIDs first, then fetch full profiles in parallel.
    final followerUids = await databaseProvider.getMosqueFollowerUids(widget.mosqueId);
    final fetchedFollowers = await Future.wait(
      followerUids.map((uid) => databaseProvider.userProfile(uid)),
    );

    // Fetch admin profiles directly.
    final adminProfiles = await databaseProvider.getMosqueAdmins(widget.mosqueId);

    // Fetch request UIDs and then their profiles.
    final requestUids = await databaseProvider.getAffiliationRequestUids(widget.mosqueId);
    List<UserProfile> requestProfiles = [];
    for (var uid in requestUids) {
      final user = await databaseProvider.userProfile(uid);
      if (user != null) requestProfiles.add(user);
    }

    // Get the list of mosques the current user is affiliated with.
    final affiliatedIds = await databaseProvider.getUserAffiliatedMosqueIds();

    // Update state only if the widget is still mounted.
    if (!mounted) return;

    setState(() {
      // Filter out null profiles just in case.
      followers = fetchedFollowers.whereType<UserProfile>().toList();
      admins = adminProfiles;
      requests = requestProfiles;
      // Determine user status based on fetched data.
      isAdmin = adminProfiles.any((admin) => admin.uid == currentUserId);
      isAffiliated = affiliatedIds.contains(widget.mosqueId);
      hasRequested = requestUids.contains(currentUserId);
      _isLoading = false; // Hide loading indicator.
    });
  }

  @override
  Widget build(BuildContext context) {
    // DefaultTabController manages the state for the TabBar and TabBarView.
    return DefaultTabController(
      length: 2, // Two tabs: Followers and Admins.
      initialIndex: widget.initialTab, // Set the starting tab.
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.mosqueName), // Display mosque name.
          // TabBar below the AppBar.
          bottom: TabBar(
            dividerColor: Colors.transparent, // Cleaner look without divider.
            labelColor: Theme.of(context).colorScheme.inversePrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.primary,
            indicatorColor: Theme.of(context).colorScheme.secondary, // Use secondary color for indicator.
            tabs: const [
              Tab(text: "Followers"),
              Tab(text: "Admins"),
            ],
          ),
        ),
        // Show loading indicator or the tab content.
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Followers Tab Content.
                  _buildUserList(followers, "No followers yet."),
                  // Admins Tab Content (includes requests and affiliation button).
                  _buildAdminList(),
                ],
              ),
      ),
    );
  }

  /// Builds a simple list view for displaying users (used for Followers).
  Widget _buildUserList(List<UserProfile> users, String emptyMessage) {
    return users.isEmpty
        ? Center(child: Text(emptyMessage)) // Show message if list is empty.
        : ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              // Use the reusable MyUserTile component.
              return MyUserTile(
                user: user,
                navigatorKey: widget.navigatorKey, // Pass navigator key for profile navigation.
              );
            },
          );
  }

  /// Builds the content for the Admins tab, including pending requests,
  /// the list of current admins, and the affiliation request button.
  Widget _buildAdminList() {
    return Column(
      children: [
        // The scrollable list part containing requests and admins.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Section for pending affiliation requests (visible only if requests exist).
              if (requests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Pending Requests",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Map each request user to a MyUserTile with accept/reject actions.
                ...requests.map((user) => MyUserTile(
                      user: user,
                      navigatorKey: widget.navigatorKey,
                      isRequest: true, // Indicates this tile represents a request.
                      // Callback for accepting the request.
                      onAccept: () async {
                        await databaseProvider.acceptAffiliationRequest(widget.mosqueId, user.uid);
                        await loadUsers(); // Reload data to reflect changes.
                      },
                      // Callback for rejecting the request.
                      onReject: () async {
                        await databaseProvider.declineAffiliationRequest(widget.mosqueId, user.uid);
                        await loadUsers(); // Reload data to reflect changes.
                      },
                    )),
                const SizedBox(height: 16), // Spacing between sections.
              ],
              // Section for current admins.
              if (admins.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Admins",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Map each admin user to a standard MyUserTile.
                ...admins.map((user) => MyUserTile(
                      user: user,
                      navigatorKey: widget.navigatorKey,
                    )),
              ] else
                // Show message if there are no admins.
                const Center(child: Text("No admins yet.")),
            ],
          ),
        ),
        // Bottom section containing the affiliation request button.
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: ClipRRect( // Apply rounded corners to the button container.
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity, // Make button take full width.
              // Use the reusable MyRequestButton component.
              child: MyRequestButton(
                requestType: 'affiliation', // Specify the type of request.
                isRequested: hasRequested, // Pass current request status.
                isAccepted: isAffiliated, // Pass current affiliation status.
                // Callback for sending an affiliation request.
                onRequest: () async {
                  await databaseProvider.sendAffiliationRequest(widget.mosqueId);
                  // Optimistically update UI, assuming request was sent.
                  setState(() => hasRequested = true);
                },
                // Callback for removing affiliation (or cancelling request).
                onRemove: () async {
                  await databaseProvider.removeMosqueAffiliation(widget.mosqueId);
                  await loadUsers(); // Reload data to reflect changes.
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
