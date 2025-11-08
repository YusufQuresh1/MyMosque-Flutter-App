// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mymosque/models/inbox_notification.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/models/notification_settings.dart' as my;
import 'package:mymosque/models/post.dart';
import 'package:mymosque/models/prayer_times.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:mymosque/models/mosque_application.dart';

// The following methods are derived from a tutorial by Mitch Koko: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6&ab_channel=MitchKoko
// - postMessage
// - loadAllPosts
// - filterUserPosts
// - userProfile

/// DatabaseProvider manages application-wide state using ChangeNotifier.
/// 
/// It acts as the ViewModel layer of the app, bridging between UI widgets
/// and backend logic. Internally it relies on [DatabaseService] to perform
/// all reads and writes to Firebase (Firestore, Storage, Functions).
///
/// Responsibilities include:
/// - Managing and exposing reactive post, user, and mosque data
/// - Performing optimistic UI updates for following/friends/actions
/// - Handling prayer timetable logic and event attendance
/// - Coordinating notification triggers and settings
/// - Wrapping account management features
/// 
/// This file plays a critical architectural role as the central state
/// management class. All asynchronous interaction with Firebase is delegated
/// to [DatabaseService], while this class maintains UI state and triggers [notifyListeners]
/// when the UI should rebuild.


class DatabaseProvider extends ChangeNotifier {
  final _auth = AuthService(); // Firebase auth wrapper
  final _db = DatabaseService(); // Backend service for all Firebase access

  /// Fetches a user profile by UID from Firestore via DatabaseService.
  Future<UserProfile?> userProfile(String mosqueId) => _db.getUserFromFirebase(mosqueId);
  
  /// Fetches a mosque profile by ID from Firestore via DatabaseService.
  Future<Mosque?> mosqueProfile(String mosqueId) => _db.getMosqueFromFirebase(mosqueId);

  // =================== POSTS ===================

  List<Post> _allPosts = [];
  List<Post> _followingPosts = [];

  List<Post> get allPosts => _allPosts;
  List<Post> get followingPosts => _followingPosts;

  /// Posts a basic announcement message from the user for a given mosque.
  /// Optionally includes an uploaded image URL.
  /// Refreshes all posts after creation.
  Future<void> postMessage(String message, String mosqueId, String mosqueName, {String? imageUrl}) async {
    await _db.postMessageInFirebase(message, mosqueId, mosqueName, imageUrl: imageUrl);
    await loadAllPosts(); // reload after posting
  }

/// Posts an announcement that includes structured event metadata,
/// including optional image. Used for event announcements.
/// Refreshes all posts after posting.
  Future<void> postMessageWithEvent(
    String message,
    String mosqueId,
    String mosqueName,
    Map<String, dynamic> eventData, {
    String? imageUrl,
  }) async {
    await _db.postMessageWithEventInFirebase(message, mosqueId, mosqueName, eventData, imageUrl: imageUrl);
    await loadAllPosts(); // ensure updated view
  }

/// Loads all posts from Firestore and populates [_allPosts].
/// Also filters the 'following' tab after loading, and notifies UI.
  Future<void> loadAllPosts() async {
    final allPosts = await _db.getAllPostsFromFirebase();
    _allPosts = allPosts;
    await loadFollowingPosts(); // filter for feed view
    notifyListeners();
  }

/// Returns a filtered list of posts authored by a specific user.
  List<Post> filterUserPosts(String uid) {
    return _allPosts.where((post) => post.uid == uid).toList();
  }

  /// Deletes a post from Firestore and reloads post state.
  /// This also triggers UI refresh to reflect removal.
  Future<void> deletePost(String postId) async {
    await _db.deletePostFromFirebase(postId);
    await loadAllPosts(); // refresh local state
  }

/// Loads event attendance data for a specific post:
/// - All attendee UIDs are cached in [_attendees]
/// - Friends who are attending are cached in [_friendsAttending]
/// 
/// Used to power both "All Attendees" and "Friends Attending" views on event posts.
  Future<void> loadEventAttendance(String postId, String userId) async {
  final attendees = await _db.getEventAttendees(postId);
  _attendees[postId] = attendees;

  final friendIds = _friends[userId] ?? [];
  final attendingFriends = await _db.getFriendsAttending(postId, friendIds);
  _friendsAttending[postId] = attendingFriends;

  notifyListeners();
}

/// Returns the list of all user IDs attending a post's event.
List<String> getAllAttendees(String postId) {
  return _attendees[postId] ?? [];
}

/// Toggles the current user's attendance for an event:
/// - If attending, removes them from the event
/// - If not attending, adds them
/// Optimistically updates UI state and refreshes friend attendance.
Future<void> toggleAttendance(String postId) async {
  final userId = _auth.getCurrentUid();
  final isCurrentlyAttending = isAttending(postId, userId);

  try {
    if (isCurrentlyAttending) {
      await _db.removeAttendance(postId);
      _attendees[postId]?.remove(userId);
    } else {
      await _db.attendEvent(postId);
      _attendees.putIfAbsent(postId, () => []).add(userId);
    }

    // Refresh cached list of friends attending
    final friendIds = _friends[userId] ?? [];
    final attendingFriends = await _db.getFriendsAttending(postId, friendIds);
    _friendsAttending[postId] = attendingFriends;

    notifyListeners();
  } catch (e) {
    print("Error toggling attendance: $e");
  }
}


  // =================== FOLLOWING SYSTEM ===================

  final Map<String, List<String>> _followers = {}; // mosqueId -> user UIDs
  final Map<String, List<String>> _following = {}; // userId -> mosque IDs
  final Map<String, int> _followerCount = {}; // mosqueId -> count
  final Map<String, int> _followingCount = {}; // userId -> count
  final Map<String, List<String>> _attendees = {}; // postId -> userIds
  final Map<String, List<String>> _friendsAttending = {}; // postId -> userIds

/// Returns true if the specified user is attending the given post.
  bool isAttending(String postId, String userId) {
    return _attendees[postId]?.contains(userId) ?? false;
  }


/// Returns a list of friend UIDs attending a given event post.
  List<String> getFriendsAttending(String postId) {
    return _friendsAttending[postId] ?? [];
  }

/// Returns the total number of users following a mosque.
  int getFollowerCount(String mosqueId) => _followerCount[mosqueId] ?? 0;
  
  /// Returns the total number of mosques followed by a user.
  int getFollowingCount(String userId) => _followingCount[userId] ?? 0;

/// Checks if the current user follows a given mosque.
/// Ensures fresh state by loading the latest list from Firestore.
Future<bool> isFollowingMosque(String mosqueId) async {
  final currentUserId = _auth.getCurrentUid();
  await loadMosqueFollowers(mosqueId); // ensure fresh followers
  return _followers[mosqueId]?.contains(currentUserId) ?? false;
}

/// Loads the list of followers for a given mosque and caches:
/// - [mosqueId] → follower UIDs
/// - [mosqueId] → count
  Future<void> loadMosqueFollowers(String mosqueId) async {
    final followerUids = await _db.getMosqueFollowerUidsFromFirebase(mosqueId);
    _followers[mosqueId] = followerUids;
    _followerCount[mosqueId] = followerUids.length;
    notifyListeners();
  }

/// Loads the list of mosque IDs that a given user follows.
/// Caches both the IDs and their count.
  Future<void> loadUserFollowing(String userId) async {
    final followingMosqueIds = await _db.getUserFollowingMosques(userId);
    _following[userId] = followingMosqueIds;
    _followingCount[userId] = followingMosqueIds.length;
    notifyListeners();
  }

/// Filters [_allPosts] to populate [_followingPosts] with
/// posts from mosques that the current user follows.
/// This method supports the "Following" tab in the home feed.
Future<void> loadFollowingPosts() async {
  final currentUid = _auth.getCurrentUid();

  _allPosts = await _db.getAllPostsFromFirebase();

  final followingMosqueIds = await _db.getUserFollowingMosques(currentUid);
  _followingPosts = _allPosts
      .where((post) => followingMosqueIds.contains(post.mosqueId))
      .toList();

  notifyListeners();
}

/// Follows a mosque and updates both local and remote state.
///
/// This method applies optimistic UI updates by updating [_followers],
/// [_followerCount], [_following], and [_followingCount] before the Firestore call.
/// If the Firestore write fails, the local state is rolled back.
  Future<void> followMosque(String mosqueId) async {
    final currentUserId = _auth.getCurrentUid();
    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(mosqueId, () => []);

    if (!_followers[mosqueId]!.contains(currentUserId)) {
      _followers[mosqueId]!.add(currentUserId);
      _followerCount[mosqueId] = (_followerCount[mosqueId] ?? 0) + 1;
      _following[currentUserId]?.add(mosqueId);
      _followingCount[currentUserId] = (_followingCount[currentUserId] ?? 0) + 1;
    }
    notifyListeners();

    try {
      await _db.followMosqueInFirebase(mosqueId);
      await loadMosqueFollowers(mosqueId);
      await loadUserFollowing(currentUserId);
    } catch (e) {
      // Rollback UI state if Firestore write failed
      _followers[mosqueId]?.remove(currentUserId);
      _followerCount[mosqueId] = (_followerCount[mosqueId] ?? 1) - 1;
      _following[currentUserId]?.remove(mosqueId);
      _followingCount[currentUserId] = (_followingCount[currentUserId] ?? 1) - 1;
      notifyListeners();
    }
  }

/// Unfollows a mosque and updates both local and remote state.
///
/// Like [followMosque], this method uses optimistic updates to remove
/// the mosque from local state immediately and rolls back if needed.
  Future<void> unfollowMosque(String mosqueId) async {
    final currentUserId = _auth.getCurrentUid();
    _following.putIfAbsent(currentUserId, () => []);
    _followers.putIfAbsent(mosqueId, () => []);

    if (_followers[mosqueId]!.contains(currentUserId)) {
      // Rollback local changes if error occurs
      _followers[mosqueId]?.remove(currentUserId);
      _followerCount[mosqueId] = (_followerCount[mosqueId] ?? 1) - 1;
      _following[currentUserId]?.remove(mosqueId);
      _followingCount[currentUserId] = (_followingCount[currentUserId] ?? 1) - 1;
    }
    notifyListeners();

    try {
      await _db.unfollowMosqueInFirebase(mosqueId);
      await loadMosqueFollowers(mosqueId);
      await loadUserFollowing(currentUserId);
    } catch (e) {
      _followers[mosqueId]?.add(currentUserId);
      _followerCount[mosqueId] = (_followerCount[mosqueId] ?? 0) + 1;
      _following[currentUserId]?.add(mosqueId);
      _followingCount[currentUserId] = (_followingCount[currentUserId] ?? 0) + 1;
      notifyListeners();
    }
  }

/// Returns a list of full [Mosque] objects that the user is currently following.
///
/// This method fetches mosque documents from Firestore by ID.
/// Only mosques with a valid document are included in the return list.
  Future<List<Mosque>> getFollowingMosques(String userId) async {
    try {
      final mosqueIds = await _db.getUserFollowingMosques(userId);
      List<Mosque> mosques = [];

      for (String mosqueId in mosqueIds) {
        final mosqueDoc = await FirebaseFirestore.instance
            .collection("Mosques")
            .doc(mosqueId)
            .get();
        if (mosqueDoc.exists) {
          mosques.add(Mosque.fromDocument(mosqueDoc));
        }
      }
      return mosques;
    } catch (e) {
      print(e);
      return [];
    }
  }

/// Returns the number of mosques the user is currently following.
  Future<int> getFollowingMosquesCount(String userId) async {
    final mosqueIds = await _db.getUserFollowingMosques(userId);
    return mosqueIds.length;
  }

/// Fetches the UIDs of users who follow the given mosque.
/// This method accesses Firestore directly through [DatabaseService].
  Future<List<String>> getMosqueFollowerUids(String mosqueId) {
  return _db.getMosqueFollowerUidsFromFirebase(mosqueId);
}


  // =================== AFFILIATION ===================

  /// Returns a list of [Mosque] objects the current user is affiliated with.
  /// If [uid] is provided, it fetches affiliations for that user instead.
  /// This reads directly from the `AffiliatedMosques` subcollection.
  Future<List<Mosque>> getUserAffiliatedMosques({String? uid}) async {
    try {
      final userId = uid ?? _auth.getCurrentUid();
      final snapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("AffiliatedMosques")
          .get();

      List<Mosque> mosques = [];

      for (var doc in snapshot.docs) {
        final mosqueDoc = await FirebaseFirestore.instance
            .collection("Mosques")
            .doc(doc.id)
            .get();
        if (mosqueDoc.exists) {
          mosques.add(Mosque.fromDocument(mosqueDoc));
        }
      }

      return mosques;
    } catch (e) {
      print(e);
      return [];
    }
  }

/// Returns a list of mosque IDs the current user is affiliated with.
/// Delegates to [DatabaseService] for Firestore read.
  Future<List<String>> getUserAffiliatedMosqueIds() async {
    return await _db.getUserAffiliatedMosqueIds();
  }

/// Returns a list of [UserProfile]s who are admins of the given mosque.
/// Admins are determined by checking who has that mosque ID in their `AffiliatedMosques`.
  Future<List<UserProfile>> getMosqueAdmins(String mosqueId) async {
  return await _db.getMosqueAdminsFromFirebase(mosqueId);
}

Set<String> _affiliatedMosqueIds = {}; // Cached local set of user's affiliations

/// Loads and caches the current user's affiliated mosque IDs locally.
/// Used by [isAffiliatedWithMosque] for efficient lookup.
Future<void> loadUserAffiliatedMosqueIds() async {
  try {
    final ids = await _db.getUserAffiliatedMosqueIds();
    _affiliatedMosqueIds = ids.toSet();
    notifyListeners();
  } catch (e) {
    print("Failed to load affiliated mosque IDs: $e");
  }
}

/// Checks if the current user is affiliated with a specific mosque.
/// Uses locally cached [_affiliatedMosqueIds] for performance.
bool isAffiliatedWithMosque(String mosqueId) {
  return _affiliatedMosqueIds.contains(mosqueId);
}

/// Sends an affiliation request to a mosque:
/// - Creates a document in AffiliationRequests subcollection of the mosque
/// - Sends push + inbox notification to all mosque admins
Future<void> sendAffiliationRequest(String mosqueId) async {
  final currentUserId = _auth.getCurrentUid();
  await _db.sendAffiliationRequest(mosqueId, currentUserId);

  // Fetch sender info
  final user = await _db.getUserFromFirebase(currentUserId);
  if (user == null) return;

  final displayName = "${user.name} (@${user.username})";

  // Get mosque name
  final mosqueDoc =
      await FirebaseFirestore.instance.collection("Mosques").doc(mosqueId).get();
  final mosqueName = mosqueDoc.data()?['name'] ?? "Your mosque";

  // Get mosque admins
  final admins = await _db.getMosqueAdminsFromFirebase(mosqueId);

  for (final admin in admins) {
    // Push notification to admins
    if (admin.fcmToken != null && admin.fcmToken!.isNotEmpty) {
      await _db.sendDirectNotification(
        token: admin.fcmToken!,
        title: "Affiliation Request",
        body: "$displayName wants to help manage $mosqueName",
        data: {
          "type": "affiliation_request",
          "fromUid": currentUserId,
          "mosqueId": mosqueId,
          "mosqueName": mosqueName,
          "name": displayName,
        },
      );
    }

    // Inbox notification to admins
    await _db.createInboxNotification(
      receiverId: admin.uid,
      type: "affiliation_request",
      title: "Affiliation Request",
      body: "$displayName wants to help manage $mosqueName",
      relatedId: currentUserId,
    );
  }
}

/// Removes the current user’s affiliation with a mosque.
/// After removal, refreshes local cache of affiliated mosques.
Future<void> removeMosqueAffiliation(String mosqueId) async {
  await _db.removeMosqueAffiliation(mosqueId);
  await getUserAffiliatedMosqueIds(); // optional refresh if you're caching
  notifyListeners();
}

/// Loads the UIDs of users who have requested affiliation with the given mosque.
Future<List<String>> getAffiliationRequestUids(String mosqueId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection("Mosques")
      .doc(mosqueId)
      .collection("AffiliationRequests")
      .get();

  return snapshot.docs.map((doc) => doc.id).toList();
}

/// Accepts an affiliation request:
/// - Adds user to mosque’s affiliated users
/// - Adds mosque to user’s affiliations
/// - Sends push + inbox notification to the user
/// - Also auto-follows the mosque on behalf of the user
Future<void> acceptAffiliationRequest(String mosqueId, String userId) async {
  await _db.acceptAffiliationRequest(mosqueId, userId);

  // Fetch updated info
  final userDoc =
      await FirebaseFirestore.instance.collection("Users").doc(userId).get();
  final token = userDoc.data()?['fcmToken'];

  final mosqueDoc =
      await FirebaseFirestore.instance.collection("Mosques").doc(mosqueId).get();
  final mosqueName = mosqueDoc.data()?['name'] ?? "Your mosque";

  if (token != null && token.isNotEmpty) {
    await _db.sendDirectNotification(
      token: token,
      title: "Affiliation Approved",
      body: "Your request to join $mosqueName was accepted.",
      data: {
        "type": "affiliation",
        "status": "approved",
        "mosqueId": mosqueId,
        "mosqueName": mosqueName,
      },
    );
  }

  await _db.createInboxNotification(
    receiverId: userId,
    type: "affiliation",
    title: "Affiliation Approved",
    body: "Your request to join $mosqueName was accepted.",
    relatedId: mosqueId,
  );

  await loadUserAffiliatedMosqueIds();
  notifyListeners();
}

/// Declines a pending affiliation request for a mosque.
/// This simply deletes the `AffiliationRequests/{userId}` document.
Future<void> declineAffiliationRequest(String mosqueId, String userId) async {
  await _db.declineAffiliationRequest(mosqueId, userId);
}

/// Loads the list of mosques the current user is affiliated with and caches their IDs.
/// This ensures the affiliation list is refreshed properly, fixing UI updates like the settings icon.
Future<void> loadAffiliatedMosques() async {
  try {
    final ids = await _db.getUserAffiliatedMosqueIds();
    _affiliatedMosqueIds = ids.toSet();
    notifyListeners();
  } catch (e) {
    print("Error loading affiliated mosques: $e");
  }
}


  // =================== SEARCH ===================

// Stores list of users matching a username query (from searchUsers or searchAll)
  List<UserProfile> _searchResults = [];

  // Public getter to expose search results for users
  List<UserProfile> get searchResult => _searchResults;

  /// Performs a user search based on a partial username match.
/// Updates [_searchResults] and notifies listeners.
  Future<void> searchUsers(String searchTerm) async {
    try {
      final results = await _db.searchUsersInFirebase(searchTerm);
      _searchResults = results;
      notifyListeners();
    } catch (e) {
      print(e);
    }
  }

  // Stores list of mosques matching a name query (from searchMosques or searchAll)
  List<Mosque> _searchMosqueResults = [];

  // Public getter for mosque search results
  List<Mosque> get searchMosqueResult => _searchMosqueResults;

/// Performs a mosque search based on a partial name match.
/// Updates [_searchMosqueResults] and notifies listeners.
Future<void> searchMosques(String query) async {
  _searchMosqueResults = await _db.searchMosques(query);
  notifyListeners();
}

/// Runs both user and mosque search queries in parallel for the same input [query].
/// Updates both [_searchResults] and [_searchMosqueResults] with matching results.
Future<void> searchAll(String query) async {
  try {
    final users = await _db.searchUsersInFirebase(query);
    final mosques = await _db.searchMosques(query);

    _searchResults = users;
    _searchMosqueResults = mosques;

    notifyListeners();
  } catch (e) {
    print("Error during combined search: $e");
  }
}

/// Clears both user and mosque search results.
/// Useful when navigating away from the search screen or resetting search input.
void clearSearchResults() {
  _searchResults = [];
  _searchMosqueResults = [];
  notifyListeners();
}

// ================= FRIEND SYSTEM =================

// Stores each user's confirmed friends (userId → list of friend UIDs)
final Map<String, List<String>> _friends = {};

// Stores each user's incoming friend requests (userId → list of requester UIDs)
final Map<String, List<String>> _friendRequests = {};

// Getter: Returns friend list for a given user ID
List<String> getFriends(String userId) => _friends[userId] ?? [];

// Getter: Returns incoming friend request UIDs for a given user
List<String> getFriendRequests(String userId) => _friendRequests[userId] ?? [];

/// Loads a user's confirmed friend list from Firestore using the service.
/// Updates the local [_friends] map and notifies listeners.
Future<void> loadFriends(String userId) async {
  final friendUids = await _db.getFriendUids(userId);
  _friends[userId] = friendUids;
  notifyListeners();
}

/// Loads a user's pending friend requests from Firestore.
/// Updates the [_friendRequests] map and notifies listeners.
Future<void> loadFriendRequests(String userId) async {
  final requestUids = await _db.getFriendRequestUids(userId);
  _friendRequests[userId] = requestUids;
  notifyListeners();
}

/// Sends a friend request from the current user to [targetUserId].
/// Triggers both a push notification and inbox notification for the receiver.
Future<void> sendFriendRequest(String targetUserId) async {
  await _db.sendFriendRequest(targetUserId);
  await loadFriendRequests(targetUserId); // Ensure UI reflects updated state

  final currentUserId = _auth.getCurrentUid();
  final sender = await _db.getUserFromFirebase(currentUserId);
  final receiverDoc =
      await FirebaseFirestore.instance.collection("Users").doc(targetUserId).get();
  final fcmToken = receiverDoc.data()?['fcmToken'];

  if (sender != null) {
    final displayName = "${sender.name} (@${sender.username})";

    // Push notification to recipient
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await _db.sendDirectNotification(
        token: fcmToken,
        title: "New Friend Request",
        body: "$displayName sent you a friend request",
        data: {
          "type": "friend_request",
          "fromUid": sender.uid,
          "name": displayName,
        },
      );
    }

    //Inbox notification
    await _db.createInboxNotification(
      receiverId: targetUserId,
      type: "friend_request",
      title: "New Friend Request",
      body: "$displayName sent you a friend request.",
      relatedId: sender.uid,
    );
  }
}

/// Accepts an incoming friend request from [requestingUserId].
/// Updates both users’ friend lists, sends push + inbox notifications,
/// and reloads friend data for both users.
Future<void> acceptFriendRequest(String requestingUserId) async {
  await _db.acceptFriendRequest(requestingUserId);

  final currentUserId = _auth.getCurrentUid();
  final accepter = await _db.getUserFromFirebase(currentUserId);
  final requesterDoc = await FirebaseFirestore.instance
      .collection("Users")
      .doc(requestingUserId)
      .get();
  final fcmToken = requesterDoc.data()?['fcmToken'];

  if (accepter != null) {
    final displayName = "${accepter.name} (@${accepter.username})";

    // Push notification to sender
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await _db.sendDirectNotification(
        token: fcmToken,
        title: "Friend Request Accepted",
        body: "$displayName has accepted your friend request",
        data: {
          "type": "friend_accept",
          "name": displayName,
        },
      );
    }

    // Inbox notification
    await _db.createInboxNotification(
      receiverId: requestingUserId,
      type: "friend_accept",
      title: "Friend Request Accepted",
      body: "$displayName has accepted your friend request.",
      relatedId: currentUserId,
    );
  }

  // Reload both users’ state
  await loadFriends(currentUserId);
  await loadFriends(requestingUserId);
  await loadFriendRequests(currentUserId);
}

/// Rejects a pending friend request from [requestingUserId].
/// Updates Firestore and reloads local request list.
Future<void> rejectFriendRequest(String requestingUserId) async {
  await _db.rejectFriendRequest(requestingUserId);
  await loadFriendRequests(_auth.getCurrentUid());
}

/// Removes an existing friend connection with [friendUserId] for both users.
/// Refreshes the friend lists on both sides.
Future<void> removeFriend(String friendUserId) async {
  await _db.removeFriend(friendUserId);
  await loadFriends(_auth.getCurrentUid());
  await loadFriends(friendUserId);
}

//MOSQUE APPLICATION

/// Submits a new mosque profile application on behalf of the user.
///
/// This involves:
/// - Uploading the user's proof document to Firebase Storage
/// - Creating a new [MosqueApplication] object with metadata
/// - Saving the application in Firestore under `mosque_applications`
///
/// Throws an error if the user profile is missing or upload fails.
Future<void> applyToCreateMosque({
  required String mosqueName,
  required GeoPoint geo,
  required String address,
  required File proofFile,
  required bool hasWomenSection,
}) async {
  try {
    final applicantUid = _auth.getCurrentUid();
    final user = await _db.getUserFromFirebase(applicantUid);
    if (user == null) throw Exception("User profile not found");

    final proofUrl = await _db.uploadProofFile(proofFile);
    final applicationId = const Uuid().v4();

    final application = MosqueApplication(
      id: applicationId,
      mosqueName: mosqueName,
      location: {
        'address': address,
        'geo': geo,
      },
      proofUrl: proofUrl,
      applicantUid: applicantUid,
      applicantUsername: user.username,
      status: "pending",
      timestamp: Timestamp.now(),
      hasWomenSection: hasWomenSection,
    );

    await _db.submitMosqueApplication(application);
    print("Mosque profile application submitted.");
  } catch (e) {
    print("Error applying to create mosque: $e");
    rethrow;
  }
}

// =================== MOSQUE APPLICATION APPROVAL ===================

// Stores all pending applications loaded from Firestore
List<MosqueApplication> _applications = [];
List<MosqueApplication> get applications => _applications;

/// Loads all mosque applications from Firestore.
/// Updates [_applications] and notifies listeners.
Future<void> loadMosqueApplications() async {
  try {
    _applications = await _db.getAllMosqueApplications();
    notifyListeners();
  } catch (e) {
    print("Failed to load applications: $e");
  }
}

/// Admin approval process for a mosque application.
///
/// This:
/// - Creates a new mosque document
/// - Affiliates and follows the applicant to the new mosque
/// - Deletes the application
/// - Sends notifications (push + inbox) to applicant
/// - Updates affiliated/followed lists in local state
Future<void> approveApplication(MosqueApplication app) async {
  try {
    final mosqueId = await _db.approveMosqueApplication(app);

    // Remove from local list before reload
    _applications.removeWhere((a) => a.id == app.id);

    // Send notification to applicant
    final userDoc = await FirebaseFirestore.instance
        .collection("Users")
        .doc(app.applicantUid)
        .get();

    final token = userDoc.data()?['fcmToken'];
    final mosqueName = app.mosqueName;

    // Send push notification if FCM token is valid
    if (token != null && token.isNotEmpty) {
      await _db.sendDirectNotification(
        token: token,
        title: "Mosque Profile Approved",
        body: "Your application for $mosqueName has been approved.",
        data: {
          "type": "mosque_application",
          "status": "approved",
          "mosqueName": mosqueName,
        },
      );
    }

    // Send inbox notification
    await _db.createInboxNotification(
      receiverId: app.applicantUid,
      type: "mosque_application",
      title: "Mosque Profile Approved",
      body: "Your application for $mosqueName has been approved.",
      relatedId: mosqueId,
    );

    await loadMosqueApplications();
    await loadUserAffiliatedMosqueIds();
    await loadUserFollowing(_auth.getCurrentUid());
  } catch (e) {
    print("Error approving application: $e");
  }
}

/// Rejects a mosque profile application by its ID.
///
/// - Deletes the application document
/// - Sends rejection notifications to the applicant (push + inbox)
Future<void> rejectApplication(String applicationId) async {
  try {
    final appData = await _db.rejectMosqueApplication(applicationId);
    if (appData == null) return;

    final applicantUid = appData['applicantUid'];
    final mosqueName = appData['mosqueName'] ?? "Your mosque";

    final userDoc = await FirebaseFirestore.instance.collection("Users").doc(applicantUid).get();
    final token = userDoc.data()?['fcmToken'];

    // Send push notification
    if (token != null && token.isNotEmpty) {
      await _db.sendDirectNotification(
        token: token,
        title: "Mosque Application Rejected",
        body: "Your application for $mosqueName has been rejected.",
        data: {
          "type": "mosque_application",
          "status": "rejected",
          "mosqueName": mosqueName,
        },
      );
    }

    // Send inbox notification
    await _db.createInboxNotification(
      receiverId: applicantUid,
      type: "mosque_application",
      title: "Mosque Application Rejected",
      body: "Your application for $mosqueName has been rejected.",
      relatedId: null,
    );

    await loadMosqueApplications();
  } catch (e) {
    print("Error rejecting application: $e");
  }
}

/// Refreshes user-related data such as mosque following and affiliations.
///
/// This method is typically called after login or after user account changes.
/// Notifies listeners on completion.
Future<void> refreshUserState() async {
  final uid = _auth.getCurrentUid();
  await loadUserFollowing(uid);
  await loadUserAffiliatedMosqueIds();
  notifyListeners();
}

/// Loads upcoming events and sorts them first by start time, then by distance.
///
/// Used on the "Nearby Events" page to display relevant posts with distance metadata.
/// 
/// Returns a list of maps, each containing:
/// - 'post': Post object
/// - 'startTime': DateTime of event start
/// - 'distance': double (in meters) from user
Future<List<Map<String, dynamic>>> loadUpcomingEventsSortedWithDistance(Position userLocation) async {
  if (_allPosts.isEmpty) {
    await loadAllPosts();
  }

  final now = DateTime.now();

  // Filter to only future events
  final filtered = _allPosts.where((post) {
    final event = post.event;
    final endTime = (event?['end_time'] as Timestamp?)?.toDate();
    return event != null && endTime != null && endTime.isAfter(now);
  });

  // Attach metadata for sorting
  final withMeta = filtered.map((post) {
    final event = post.event!;
    final startTime = (event['start_time'] as Timestamp).toDate();
    final geo = event['geo'] as GeoPoint?;
    final distance = geo == null
        ? double.infinity
        : Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            geo.latitude,
            geo.longitude,
          );
    return {
      'post': post,
      'startTime': startTime,
      'distance': distance,
    };
  }).toList();

  // Sort: first by start time, then by distance
  withMeta.sort((a, b) {
    final timeA = a['startTime'] as DateTime;
    final timeB = b['startTime'] as DateTime;
    final distA = a['distance'] as double;
    final distB = b['distance'] as double;

    final timeCompare = timeA.compareTo(timeB);
    return timeCompare != 0 ? timeCompare : distA.compareTo(distB);
  });

  return withMeta;
}

/// Fetches today's prayer times from Firestore for the given mosque.
///
/// Returns a [PrayerTimes] object or null if not available.
Future<PrayerTimes?> fetchTodayPrayerTimes(String mosqueId) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final doc = await FirebaseFirestore.instance
      .collection('Mosques')
      .doc(mosqueId)
      .collection('PrayerTimes')
      .doc(today)
      .get();

  if (!doc.exists) return null;
  return PrayerTimes.fromDocument(doc);
}

/// Saves a full weekly prayer timetable to Firestore using a helper in [DatabaseService].
///
/// Each day's data includes optional start, jamaat, and jummah timings.
/// This is used by mosque admins when editing prayer schedules.
Future<void> savePrayerTimetable({
  required String mosqueId,
  required DateTime monday,
  required Map<String, Map<String, Map<String, TimeOfDay?>>> timetable,
  required Map<String, List<TimeOfDay>> jummahs,
}) async {
  await _db.saveWeeklyPrayerTimetable(
    mosqueId: mosqueId,
    monday: monday,
    timetable: timetable,
    jummahs: jummahs,
  );
}

/// Loads prayer times for a specific mosque and date.
Future<PrayerTimes?> fetchPrayerTimes(String mosqueId, DateTime date) {
  return _db.fetchPrayerTimes(mosqueId, date);
}

//NOTIFICATIONS

/// Retrieves the current user's notification settings for a specific mosque.
///
/// Returns a [my.NotificationSettings] object, or null if no settings found.
Future<my.NotificationSettings?> getNotificationSettings(String mosqueId) async {
  return await _db.getNotificationSettings(mosqueId);
}

/// Saves the user's notification preferences for a specific mosque to Firestore.
///
/// Also triggers prayer notification scheduling for the rest of the day.
Future<void> saveNotificationSettings(String mosqueId, my.NotificationSettings settings) async {
  await _db.saveNotificationSettings(mosqueId, settings);
}

StreamSubscription<String>? _fcmTokenSubscription;

/// Updates the FCM (Firebase Cloud Messaging) token in Firestore for the current user.
///
/// Also listens for token refreshes and re-applies them when detected.
Future<void> updateFcmToken(User user) async {
  final fcm = FirebaseMessaging.instance;
  final token = await fcm.getToken();

  if (token != null && token.isNotEmpty) {
    await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
      'fcmToken': token,
    });
  }

  _fcmTokenSubscription = fcm.onTokenRefresh.listen((newToken) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == user.uid) {
      FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
        'fcmToken': newToken,
      });
    } else {
      print("Skipped token update: old UID (${user.uid}) vs current UID ($currentUid)");
    }
  });
}

/// Stores inbox notifications fetched from Firestore.
  List<InboxNotification> _inboxNotifications = [];
  
  /// Tracks whether notifications are being fetched.
  bool _isLoadingNotifications = false;

  /// Exposed read-only state for UI to use.
  List<InboxNotification> get inboxNotifications => _inboxNotifications;
  bool get isLoadingNotifications => _isLoadingNotifications;

  /// Loads all inbox notifications for the current user from Firestore.
  ///
  /// Notifies listeners on completion.
  Future<void> loadInboxNotifications() async {
    _isLoadingNotifications = true;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      _inboxNotifications = await _db.fetchInboxNotifications();
    } catch (e) {
      print("Error loading inbox notifications: \$e");
    }

    _isLoadingNotifications = false;
    notifyListeners();
  }

  /// Marks a single inbox notification as read and updates local state.
  Future<void> markNotificationAsRead(String notificationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _db.markNotificationAsRead(notificationId);

    final index = _inboxNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _inboxNotifications[index] =
          _inboxNotifications[index].copyWith(read: true);
      notifyListeners();
    }
  }

/// Schedules prayer notifications for today based on user preferences and mosque timings.
///
/// This is triggered after saving new notification settings or login.
  Future<void> scheduleTodayPrayerNotificationsForUser(String userId) async {
  final tokenDoc = await FirebaseFirestore.instance.collection("Users").doc(userId).get();
  final token = tokenDoc.data()?['fcmToken'];

  if (token != null && token.isNotEmpty) {
    await _db.scheduleTodayPrayerNotifications(token);
  }
}

  //ACCOUNT SETTINGS

/// Updates the current user's display name.
  Future<void> updateUserName(String name) async {
  await _db.updateUserNameInFirebase(name);
  notifyListeners();
}

/// Updates the user's bio in Firestore.
Future<void> updateUserBio(String bio) async {
  await _db.updateUserBioInFirebase(bio);
  notifyListeners();
}

/// Updates the FirebaseAuth password for the current user.
Future<void> updateUserPassword(String newPassword) async {
  await _db.updateUserPassword(newPassword);
}

/// Fully deletes the user account and related Firestore data.
///
/// Also clears local provider state and cancels token subscriptions.
Future<void> deleteUserAccount() async {
  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid;
  if (uid == null) throw Exception("User already logged out or deleted.");
  clearState();
  await _db.deleteUserAccountFromFirebase(uid);

}

/// Updates a single field on a mosque document in Firestore.
Future<void> updateMosqueField(String mosqueId, String field, dynamic value) async {
  await _db.updateMosqueField(mosqueId, field, value);
  notifyListeners();
}

/// Deletes the mosque document and all its related subcollections.
///
/// Re-throws any errors after logging for visibility.
Future<void> deleteMosque(String mosqueId) async {
  try {
    await _db.deleteMosqueProfile(mosqueId);
  } catch (e) {
    print("Provider error deleting mosque: $e");
    rethrow;
  }
}

/// Internal cache of user's primary mosque (used for star toggle)
String? _primaryMosqueId;
String? get primaryMosqueId => _primaryMosqueId;

/// Loads and returns the user's primary mosque ID from Firestore.
Future<void> loadPrimaryMosqueId() async {
  final primaryId = await _db.getPrimaryMosqueId();
  _primaryMosqueId = primaryId;
  notifyListeners();
}

/// Sets or unsets the user's primary mosque (used for dashboard or bookmarks).
Future<void> setPrimaryMosque(String? mosqueId) async {
  final uid = _auth.getCurrentUid();
  await FirebaseFirestore.instance.collection("Users").doc(uid).update({
    'primaryMosqueId': mosqueId,
  });
  _primaryMosqueId = mosqueId;
  notifyListeners();
}

/// Clears all local state managed by this provider, including listeners and caches.
///
/// Used on logout or account deletion.
void clearState() {
  _fcmTokenSubscription?.cancel();
  _fcmTokenSubscription = null;
  _allPosts = [];
  _followingPosts = [];
  _followers.clear();
  _following.clear();
  _followerCount.clear();
  _followingCount.clear();
  _attendees.clear();
  _friendsAttending.clear();
  _affiliatedMosqueIds.clear();
  _searchResults = [];
  _searchMosqueResults = [];
  _friends.clear();
  _friendRequests.clear();
  _inboxNotifications = [];
  _applications = [];
  _primaryMosqueId = null;
  notifyListeners();
}
}
