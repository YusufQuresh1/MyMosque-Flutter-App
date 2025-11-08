// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mymosque/models/inbox_notification.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/models/notification_settings.dart' as my;
import 'package:mymosque/models/post.dart';
import 'package:mymosque/models/prayer_times.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mymosque/models/mosque_application.dart';
import 'package:cloud_functions/cloud_functions.dart';

// The following methods were adapted from code by Mitch Koko from YouTube tutorial:
// https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6
// - saveUserInfoInFirebase() -- adapted to include gender
// - getUserFromFirebase()
// - updateUserBioInFirebase()
// - updateUserNameInFirebase()
// - postMessageInFirebase() -- adapted to include mosque related info and include images
// - getAllPostsFromFirebase()
// All other methods are custom and original.

/// ====================================================================
/// A service class that handles all Firebase interactions related to:
/// - User profiles
/// - Mosque profiles and data
/// - Posts and events
/// - Friend system
/// - Mosque affiliation system
/// - Notifications
/// - Prayer timetables
/// - Mosque profile applications
/// 
/// This acts as the backend logic layer used by the app's provider.
class DatabaseService {
  final _db = FirebaseFirestore.instance; // Firestore DB reference
  final _auth = FirebaseAuth.instance;    // Firebase Authentication reference

/// Creates a new user document in Firestore during registration or profile completion.
///
/// Extracts UID from the current authenticated user, derives a username from the email,
/// and stores it along with name, bio, gender, and default userType.
///
/// Called after successful registration (email or Google).
Future<void> saveUserInfoInFirebase({
  required String email,
  required String name,
  required String bio,
  required String gender,
}) async {
  try {
    String uid = _auth.currentUser!.uid;
    String username = email.split('@')[0];

    UserProfile user = UserProfile(
      uid: uid,
      email: email,
      username: username,
      name: name,
      bio: bio,
      gender: gender,
      userType: 'user',
    );

    await _db.collection("Users").doc(uid).set(user.toMap());
  } catch (e) {
    print(e);
  }
}

/// Retrieves a user's profile data from Firestore using their UID.
///
/// Returns a `UserProfile` object if found, or null otherwise.
  Future<UserProfile?> getUserFromFirebase(String uid) async {
    try {
      DocumentSnapshot userDoc = await _db.collection("Users").doc(uid).get();
      return userDoc.exists ? UserProfile.fromDocument(userDoc) : null;
    } catch (e) {
      print(e);
      return null;
    }
  }

/// Retrieves a mosque document by ID and converts it to a `Mosque` model.
///
/// Returns `null` if the document does not exist or the fetch fails.
  Future<Mosque?> getMosqueFromFirebase(String mosqueId) async {
  try {
    final doc = await _db.collection("Mosques").doc(mosqueId).get();
    return doc.exists ? Mosque.fromDocument(doc) : null;
  } catch (e) {
    print(e);
    return null;
  }
}

/// Updates the `bio` field for the currently authenticated user.
  Future<void> updateUserBioInFirebase(String bio) async {
    try {
      String uid = AuthService().getCurrentUid();
      await _db.collection("Users").doc(uid).update({'bio': bio});
    } catch (e) {
      print(e);
    }
  }

/// Updates the name field for the currently authenticated user.
  Future<void> updateUserNameInFirebase(String name) async {
    try {
      String uid = AuthService().getCurrentUid();
      await _db.collection("Users").doc(uid).update({'name': name});
    } catch (e) {
      print(e);
    }
  }

/// Adds the current user to a mosque's AffiliatedMosques subcollection.
///
/// This does not modify the mosque document — just creates an entry under the user's document.
  Future<void> affiliateWithMosque(String mosqueId) async {
    try {
      String uid = AuthService().getCurrentUid();
      await _db
          .collection("Users")
          .doc(uid)
          .collection("AffiliatedMosques")
          .doc(mosqueId)
          .set({});
    } catch (e) {
      print(e);
    }
  }

/// Removes an affiliation between the current user and the given mosque.
///
/// Deletes the mosque ID from the user's `AffiliatedMosques` subcollection.
  Future<void> removeMosqueAffiliation(String mosqueId) async {
    try {
      String uid = AuthService().getCurrentUid();
      await _db
          .collection("Users")
          .doc(uid)
          .collection("AffiliatedMosques")
          .doc(mosqueId)
          .delete();
    } catch (e) {
      print(e);
    }
  }

/// Returns a list of mosque IDs that the current user is affiliated with.
///
/// Fetches from the `AffiliatedMosques` subcollection under the user.
  Future<List<String>> getUserAffiliatedMosqueIds() async {
    try {
      String uid = AuthService().getCurrentUid();
      final snapshot = await _db
          .collection("Users")
          .doc(uid)
          .collection("AffiliatedMosques")
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print(e);
      return [];
    }
  }

/// Posts a regular announcement to the Posts collection with optional image.
///
/// Builds a [Post] model using the current user and mosque details.
Future<void> postMessageInFirebase(
  String message,
  String mosqueId,
  String mosqueName, {
  String? imageUrl,
}) async {
  try {
    String uid = _auth.currentUser!.uid;
    UserProfile? user = await getUserFromFirebase(uid);

    Post newPost = Post(
      id: '',
      uid: uid,
      mosqueName: mosqueName,
      username: user!.username,
      message: message,
      timestamp: Timestamp.now(),
      mosqueId: mosqueId,
      imageUrl: imageUrl,
    );

    await _db.collection("Posts").add(newPost.toMap());
  } catch (e) {
    print("Error creating post: $e");
  }
}

/// Posts an event announcement to the Posts collection with event data and optional image.
///
/// Used for event creation; includes event name, location, time, and optional gender restriction.
Future<void> postMessageWithEventInFirebase(
  String message,
  String mosqueId,
  String mosqueName,
  Map<String, dynamic> eventData, {
  String? imageUrl,
}) async {
  try {
    String uid = _auth.currentUser!.uid;
    UserProfile? user = await getUserFromFirebase(uid);

    Post newPost = Post(
      id: '',
      uid: uid,
      mosqueName: mosqueName,
      username: user!.username,
      message: message,
      timestamp: Timestamp.now(),
      mosqueId: mosqueId,
      event: eventData,
      imageUrl: imageUrl,
    );

    await _db.collection("Posts").add(newPost.toMap());
  } catch (e) {
    print("Error creating post with event: $e");
  }
}

/// Uploads an image file to Firebase Storage and returns its download URL.
///
/// Used for both regular posts and events.
Future<String> uploadImageAndGetUrl(File imageFile) async {
  final ref = FirebaseStorage.instance
      .ref()
      .child('post_images')
      .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

  await ref.putFile(imageFile);
  return await ref.getDownloadURL();
}

/// Permanently deletes a post from Firestore using its document ID.
  Future<void> deletePostFromFirebase(String postId) async {
    try {
      await _db.collection("Posts").doc(postId).delete();
    } catch (e) {
      print(e);
    }
  }

/// Loads all posts from Firestore ordered by timestamp (most recent first).
///
/// Returns a list of `Post` model instances.
  Future<List<Post>> getAllPostsFromFirebase() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection("Posts")
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Mosque Following System

// Adds the specified mosque to the user's following list and vice versa.
///
/// This method creates a document in:
/// - `Users/{uid}/FollowingMosques/{mosqueId}`
/// - `Mosques/{mosqueId}/Followers/{uid}`
///
/// Optionally, you can specify a `userId` to follow on their behalf (for when admins approve mosque applications).
Future<void> followMosqueInFirebase(String mosqueId, {String? userId}) async {
  final uid = userId ?? FirebaseAuth.instance.currentUser!.uid;

  await _db
      .collection("Users")
      .doc(uid)
      .collection("FollowingMosques")
      .doc(mosqueId)
      .set({});

  await _db
      .collection("Mosques")
      .doc(mosqueId)
      .collection("Followers")
      .doc(uid)
      .set({});
}

/// Removes the current user from the specified mosque's follower list.
///
/// Deletes from both:
/// - `Users/{uid}/FollowingMosques/{mosqueId}`
/// - `Mosques/{mosqueId}/Followers/{uid}`
  Future<void> unfollowMosqueInFirebase(String mosqueId) async {
    final currentUserId = _auth.currentUser!.uid;

    await _db
        .collection("Users")
        .doc(currentUserId)
        .collection("FollowingMosques")
        .doc(mosqueId)
        .delete();

    await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("Followers")
        .doc(currentUserId)
        .delete();
  }

/// Returns a list of user IDs that follow the given mosque.
///
/// Reads from `Mosques/{mosqueId}/Followers` subcollection.
  Future<List<String>> getMosqueFollowerUids(String mosqueId) async {
    final snapshot =
        await _db.collection("Mosques").doc(mosqueId).collection("Followers").get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

/// Returns a list of mosque IDs that the specified user is following.
///
/// Reads from `Users/{uid}/FollowingMosques`.
  Future<List<String>> getUserFollowingMosques(String uid) async {
    final snapshot = await _db
        .collection("Users")
        .doc(uid)
        .collection("FollowingMosques")
        .get();
    return snapshot.docs.map((doc) => doc.id).toList();
  }

/// Same as getMosqueFollowerUids, but wrapped in try-catch with fallback.
///
/// Used in cases where you want to avoid crashing on failure.
Future<List<String>> getMosqueFollowerUidsFromFirebase(String mosqueId) async {
  try {
    final snapshot = await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("Followers")
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print(e);
    return [];
  }
}

/// Returns all users who are affiliated with the given mosque.
///
/// Iterates over all users and checks their `AffiliatedMosques/{mosqueId}` doc.
Future<List<UserProfile>> getMosqueAdminsFromFirebase(String mosqueId) async {
  try {
    final usersSnapshot = await FirebaseFirestore.instance.collection('Users').get();

    List<UserProfile> admins = [];

    for (var doc in usersSnapshot.docs) {
      final affiliatedSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(doc.id)
          .collection('AffiliatedMosques')
          .doc(mosqueId)
          .get();

      if (affiliatedSnapshot.exists) {
        admins.add(UserProfile.fromDocument(doc));
      }
    }

    return admins;
  } catch (e) {
    print(e);
    return [];
  }
}


/// Searches for users whose usernames begin with the given term.
/// 
/// Uses Firestore range queries to perform a case-insensitive prefix match.
/// Returns a list of matched user profiles.
  Future<List<UserProfile>> searchUsersInFirebase(String searchTerm) async {
    try {
      // Query usernames that begin with the search term
      QuerySnapshot snapshot = await _db
          .collection("Users")
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();
      return snapshot.docs
          .map((doc) => UserProfile.fromDocument(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

/// Searches mosques whose names begin with the given query string.
/// 
/// Performs a case-insensitive prefix search using Firestore.
/// Returns a list of Mosque objects.
Future<List<Mosque>> searchMosques(String query) async {
  try {
    final snapshot = await _db
        .collection('Mosques')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .get();

    return snapshot.docs.map((doc) => Mosque.fromDocument(doc)).toList();
  } catch (e) {
    print("Error searching mosques: $e");
    return [];
  }
}

  // FRIEND SYSTEM

/// Sends a friend request to another user by creating a document in their
/// `FriendRequests` subcollection with your user ID as the doc ID.
Future<void> sendFriendRequest(String targetUserId) async {
  final currentUserId = _auth.currentUser!.uid;

  await _db
      .collection("Users")
      .doc(targetUserId)
      .collection("FriendRequests")
      .doc(currentUserId)
      .set({});
}

/// Accepts a pending friend request and establishes a two-way friendship.
/// 
/// This adds both users to each other's `Friends` subcollection and
/// deletes the friend request afterward.
Future<void> acceptFriendRequest(String requestingUserId) async {
  final currentUserId = _auth.currentUser!.uid;

   // Add each other to Friends
  await _db
      .collection("Users")
      .doc(currentUserId)
      .collection("Friends")
      .doc(requestingUserId)
      .set({});

  await _db
      .collection("Users")
      .doc(requestingUserId)
      .collection("Friends")
      .doc(currentUserId)
      .set({});

  // Remove the friend request after accepting
  await _db
      .collection("Users")
      .doc(currentUserId)
      .collection("FriendRequests")
      .doc(requestingUserId)
      .delete();
}

/// Rejects (or cancels) a friend request by deleting the document
/// in the current user's `FriendRequests` subcollection.
Future<void> rejectFriendRequest(String requestingUserId) async {
  try {
    final currentUserId = _auth.currentUser!.uid;
    // Remove the request from the current user's received requests
    await _db
        .collection("Users")
        .doc(currentUserId)
        .collection("FriendRequests")
        .doc(requestingUserId)
        .delete();
  } catch (e) {
    print(e);
  }
}

/// Removes a friend from both users' `Friends` subcollections to break the link.
Future<void> removeFriend(String friendUserId) async {
  final currentUserId = _auth.currentUser!.uid;

  // Remove each other from their respective Friends lists
  await _db
      .collection("Users")
      .doc(currentUserId)
      .collection("Friends")
      .doc(friendUserId)
      .delete();

  await _db
      .collection("Users")
      .doc(friendUserId)
      .collection("Friends")
      .doc(currentUserId)
      .delete();
}

/// Fetches a list of user IDs who are friends with the given user.
///
/// Reads from `Users/{userId}/Friends`.
Future<List<String>> getFriendUids(String userId) async {
  final snapshot = await _db
      .collection("Users")
      .doc(userId)
      .collection("Friends")
      .get();
  return snapshot.docs.map((doc) => doc.id).toList();
}

/// Fetches a list of user IDs who have sent a friend request to the user.
///
/// Reads from `Users/{userId}/FriendRequests`.
Future<List<String>> getFriendRequestUids(String userId) async {
  final snapshot = await _db
      .collection("Users")
      .doc(userId)
      .collection("FriendRequests")
      .get();
  return snapshot.docs.map((doc) => doc.id).toList();
}

/// Fetches a list of user IDs who have sent a friend request to the user.
///
/// Reads from `Users/{userId}/FriendRequests`.
Future<void> addMosqueToUserAffiliatedMosques(String mosqueId, String userId) async {
  await _db
      .collection("Users")
      .doc(userId)
      .collection("AffiliatedMosques")
      .doc(mosqueId)
      .set({});
}

/// Adds a user to a mosque’s list of affiliated users (admins).
///
/// Creates a document in `Mosques/{mosqueId}/AffiliatedUsers/{userId}`.
/// This is the other half of the affiliation.
Future<void> addUserToMosqueAffiliatedUsers(String mosqueId, String userId) async {
  await _db
      .collection("Mosques")
      .doc(mosqueId)
      .collection("AffiliatedUsers")
      .doc(userId)
      .set({});
}

/// Sends an affiliation request to a mosque (to become an admin).
///
/// Creates a document under `Mosques/{mosqueId}/AffiliationRequests/{userId}`.
Future<void> sendAffiliationRequest(String mosqueId, String userId) async {
  try {
    await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("AffiliationRequests")
        .doc(userId)
        .set({
          'timestamp': FieldValue.serverTimestamp(),
        });
  } catch (e) {
    print("Error sending affiliation request: $e");
  }
}

/// Accepts an affiliation request by establishing the relationship,
/// making the user an admin and follower of the mosque.
Future<void> acceptAffiliationRequest(String mosqueId, String userId) async {
  try {
    await addMosqueToUserAffiliatedMosques(mosqueId, userId);
    await addUserToMosqueAffiliatedUsers(mosqueId, userId);

    // Also automatically follow the mosque (affiliation implies following)
    await _db
        .collection("Users")
        .doc(userId)
        .collection("FollowingMosques")
        .doc(mosqueId)
        .set({});

    await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("Followers")
        .doc(userId)
        .set({});

    // Remove the original request
    await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("AffiliationRequests")
        .doc(userId)
        .delete();
  } catch (e) {
    print("Error accepting affiliation request: $e");
  }
}

/// Declines an affiliation request by simply deleting it from Firestore.
Future<void> declineAffiliationRequest(String mosqueId, String userId) async {
  try {
    await _db
        .collection("Mosques")
        .doc(mosqueId)
        .collection("AffiliationRequests")
        .doc(userId)
        .delete();
  } catch (e) {
    print("Error declining affiliation request: $e");
  }
}

/// Marks the current user as attending an event by adding their UID
/// to the `Attendees` subcollection of the post.
Future<void> attendEvent(String postId) async {
  try {
    String uid = _auth.currentUser!.uid;
    await _db
        .collection("Posts")
        .doc(postId)
        .collection("Attendees")
        .doc(uid)
        .set({'timestamp': FieldValue.serverTimestamp()});
  } catch (e) {
    print("Error attending event: $e");
  }
}

/// Removes the user's attendance from a post’s `Attendees` subcollection.
Future<void> removeAttendance(String postId) async {
  try {
    String uid = _auth.currentUser!.uid;
    await _db
        .collection("Posts")
        .doc(postId)
        .collection("Attendees")
        .doc(uid)
        .delete();
  } catch (e) {
    print("Error removing attendance: $e");
  }
}

/// Returns a list of user IDs who are attending the given event post.
Future<List<String>> getEventAttendees(String postId) async {
  try {
    final snapshot = await _db
        .collection("Posts")
        .doc(postId)
        .collection("Attendees")
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  } catch (e) {
    print("Error fetching attendees: $e");
    return [];
  }
}

/// Filters a list of friends and returns only those attending a post.
///
/// Uses batched queries (in chunks of 10) for efficiency with Firestore limits.
Future<List<String>> getFriendsAttending(String postId, List<String> friendIds) async {
  try {
    if (friendIds.isEmpty) return [];

    List<String> friendsAttending = [];
    const int batchSize = 10;

    // Firestore has a 10-item limit for `whereIn`, so split into batches
    for (var i = 0; i < friendIds.length; i += batchSize) {
      final chunk = friendIds.sublist(
        i,
        i + batchSize > friendIds.length ? friendIds.length : i + batchSize,
      );

      final snapshot = await _db
          .collection("Posts")
          .doc(postId)
          .collection("Attendees")
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      friendsAttending.addAll(snapshot.docs.map((doc) => doc.id));
    }

    return friendsAttending;
  } catch (e) {
    print("Error fetching friends attending: $e");
    return [];
  }
}

//MOSQUE APPLICATION

/// Uploads a proof of affiliation file (PDF/image) to Firebase Storage
/// and returns the download URL.
///
/// Used during mosque application submission by regular users.
Future<String> uploadProofFile(File file) async {
  try {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = FirebaseStorage.instance.ref().child('proof_documents/$fileName');

    print("Uploading to: proof_documents/$fileName");
    print("File path: ${file.path}");
    print("File exists: ${file.existsSync()}");

    final uploadTask = await ref.putFile(file); // Uploads the file
    final downloadUrl = await uploadTask.ref.getDownloadURL(); // Gets the public URL

    return downloadUrl;
  } catch (e) {
    print("Error uploading proof file: $e");
    rethrow;
  }
}

/// Submits a new mosque application to Firestore.
///
/// The application is stored in the `mosque_applications` collection.
/// Admins will review and approve/reject from there.
Future<void> submitMosqueApplication(MosqueApplication application) async {
  try {
    await _db
        .collection("mosque_applications")
        .doc(application.id)
        .set(application.toMap());
  } catch (e) {
    print("Error submitting mosque application: $e");
    rethrow;
  }
}

/// Retrieves all pending mosque applications (for admin review).
///
/// Admins use this to see submissions and act on them.
Future<List<MosqueApplication>> getAllMosqueApplications() async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection("mosque_applications").get();
    return snapshot.docs.map((doc) => MosqueApplication.fromDocument(doc)).toList();
  } catch (e) {
    print("Error fetching applications: $e");
    return [];
  }
}

/// Approves a pending mosque application:
/// - Creates the mosque document in `Mosques`
/// - Affiliates and follows the applicant
/// - Deletes the original application doc
///
/// Returns the new mosque document ID.
Future<String> approveMosqueApplication(MosqueApplication app) async {
  try {
    final mosqueRef = _db.collection("Mosques").doc();

     // Create the mosque document
    await mosqueRef.set({
      'name': (app.mosqueName).toLowerCase(),
      'description': '',
      'hasWomenSection': app.hasWomenSection,
      'location': {
        'geo': app.location['geo'],
        'address': app.location['address'],
      },
    });

    // Add applicant as affiliated user and follower
    await addUserToMosqueAffiliatedUsers(mosqueRef.id, app.applicantUid);
    await addMosqueToUserAffiliatedMosques(mosqueRef.id, app.applicantUid);
    await followMosqueInFirebase(mosqueRef.id, userId: app.applicantUid);

    // Remove original application
    await _db.collection("mosque_applications").doc(app.id).delete();

    return mosqueRef.id;
  } catch (e) {
    print("Error approving mosque application: $e");
    rethrow;
  }
}

/// Rejects a mosque application:
/// - Deletes the document from `mosque_applications`
/// - Returns the data for optional confirmation messages
Future<Map<String, dynamic>?> rejectMosqueApplication(String applicationId) async {
  try {
    final docRef = _db.collection("mosque_applications").doc(applicationId);
    final appDoc = await docRef.get();

    if (!appDoc.exists) {
      print("Application not found");
      return null;
    }

    final appData = appDoc.data();
    await docRef.delete();

    return appData;
  } catch (e) {
    print("Error rejecting application: $e");
    return null;
  }
}

//PRAYER TIMES

/// Saves a week's worth of prayer times and Jummah times for a mosque.
///
/// This method uses a Firestore batch write for efficiency and ensures that:
/// - Each day's document (Mon–Sun) under `/Mosques/{mosqueId}/PrayerTimes/` is updated
/// - All start/jamaat times are stored as Firestore `Timestamp` values
/// - Jummah times (if any) are also included per day
///
/// Parameters:
/// - [mosqueId]: Target mosque document ID
/// - [monday]: A DateTime representing the Monday of the week
/// - [timetable]: A 7-day map of start/jamaat times for each prayer
/// - [jummahs]: A map of optional jummah times per day
Future<void> saveWeeklyPrayerTimetable({
  required String mosqueId,
  required DateTime monday,
  required Map<String, Map<String, Map<String, TimeOfDay?>>> timetable,
  required Map<String, List<TimeOfDay>> jummahs,
}) async {
  final batch = _db.batch(); // Firestore batch for atomic multi-day update

  for (int i = 0; i < 7; i++) {
    final date = monday.add(Duration(days: i));
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final docRef = _db
        .collection('Mosques')
        .doc(mosqueId)
        .collection('PrayerTimes')
        .doc(dateKey);

    final prayerData = <String, Map<String, Timestamp>>{};

    final prayers = timetable[dateKey];
    if (prayers != null) {
      prayers.forEach((prayer, times) {
        final start = times['start'];
        final jamaat = times['jamaat'];

        if (start != null || jamaat != null) {
          prayerData[prayer] = {
            if (start != null)
              'start': Timestamp.fromDate(DateTime(
                date.year,
                date.month,
                date.day,
                start.hour,
                start.minute,
              )),
            if (jamaat != null)
              'jamaat': Timestamp.fromDate(DateTime(
                date.year,
                date.month,
                date.day,
                jamaat.hour,
                jamaat.minute,
              )),
          };
        }
      });
    }

    final data = <String, dynamic>{...prayerData};

    // Add Jummah times if provided
    if (jummahs.containsKey(dateKey)) {
      data['jummah'] = jummahs[dateKey]!
          .map((time) => Timestamp.fromDate(DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              )))
          .toList();
    }

    // Merge to preserve existing times if not overwritten
    batch.set(docRef, data, SetOptions(merge: true));
  }

  await batch.commit(); // Execute batch write
}

/// Retrieves the prayer timetable for a specific mosque and date.
///
/// It reads from `/Mosques/{mosqueId}/PrayerTimes/{yyyy-MM-dd}`
/// and returns a `PrayerTimes` model if found.
///
/// Returns null if the document doesn't exist.
Future<PrayerTimes?> fetchPrayerTimes(String mosqueId, DateTime date) async {
  final dateKey = DateFormat('yyyy-MM-dd').format(date);
  final doc = await FirebaseFirestore.instance
      .collection('Mosques')
      .doc(mosqueId)
      .collection('PrayerTimes')
      .doc(dateKey)
      .get();

  if (!doc.exists) return null;
  return PrayerTimes.fromDocument(doc);
}

//NOTIFICATIONS

/// Saves the user's notification preferences for a specific mosque.
///
/// This includes:
/// - Whether to receive post notifications
/// - Whether to receive prayer start/jamaat notifications
///
/// After saving, it schedules today's pending prayer notifications.
///
/// Parameters:
/// - [mosqueId]: The mosque whose notifications are being configured
/// - [settings]: The user's `NotificationSettings` model
Future<void> saveNotificationSettings(String mosqueId, my.NotificationSettings settings) async {
  final uid = _auth.currentUser!.uid;

  // Save structured notification settings under:
  // Users/{uid}/NotificationSettings/{mosqueId}
  await _db
      .collection('Users')
      .doc(uid)
      .collection('NotificationSettings')
      .doc(mosqueId)
      .set(settings.toMap());

  // Attempt to retrieve FCM token and reschedule today's prayer alerts
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null && token.isNotEmpty) {
    await scheduleTodayPrayerNotifications(token);
  }
}

/// Retrieves the stored notification preferences for a given mosque for a user.
///
/// Parameters:
/// - [mosqueId]: The mosque whose preferences to retrieve
///
/// Returns:
/// - A `NotificationSettings` object if found, otherwise null
Future<my.NotificationSettings?> getNotificationSettings(String mosqueId) async {
  final uid = _auth.currentUser!.uid;
  final doc = await _db
      .collection('Users')
      .doc(uid)
      .collection('NotificationSettings')
      .doc(mosqueId)
      .get();

  if (!doc.exists) return null;
  return my.NotificationSettings.fromMap(doc.data()!);
}

/// Sends an immediate push notification to a user via HTTP Cloud Function.
///
/// Uses an external Cloud Function endpoint (`sendDirectNotification`) to
/// send a single notification to a specific FCM token.
///
/// Parameters:
/// - [token]: The FCM token of the target user
/// - [title]: The notification title
/// - [body]: The message body
/// - [data]: Optional payload for in-app routing/handling
Future<void> sendDirectNotification({
  required String token,
  required String title,
  required String body,
  Map<String, String>? data,
}) async {
  try {
    final uri = Uri.parse(
        'https://europe-west2-mymosque-a506e.cloudfunctions.net/sendDirectNotification');

    final httpClient = HttpClient();
    final request = await httpClient.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');

    final payload = json.encode({
      'token': token,
      'title': title,
      'body': body,
      'data': data ?? {},
    });

    request.add(utf8.encode(payload));
    final response = await request.close();

    if (response.statusCode == 200) {
      print("NOTIFICATION SENT SUCCESFULLY TO $token");
    } else {
      print("Failed to send notification: ${response.statusCode}");
    }
  } catch (e) {
    print('Failed to send notification: $e');
  }
}

/// Schedules prayer notifications for the current day using a callable Cloud Function.
///
/// This function offloads scheduling logic to Firebase Functions,
/// which evaluates the user's preferences and the day's timetable,
/// then creates delayed FCM notifications via Cloud Tasks.
///
/// Parameters:
/// - [token]: The user’s current FCM token
Future<void> scheduleTodayPrayerNotifications(String token) async {
  try {
    final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
      .httpsCallable('scheduleTodayPrayerNotifications');
    await callable.call({"token": token});
    print("Scheduled today's remaining notifications");
  } catch (e) {
    print("Error scheduling prayer notifications: $e");
  }
}

/// Stores a new in-app inbox notification for the given user.
///
/// These are not push notifications — they show in the app's inbox tab.
/// Used for: friend requests, affiliation requests, application updates, etc.
///
/// Parameters:
/// - [receiverId]: The UID of the user receiving the message
/// - [type]: One of: 'friend_request', 'affiliation_request', 'mosque_application', etc.
/// - [title]: The inbox title shown in bold
/// - [body]: The short description shown in the list
/// - [relatedId]: Optional ID of the related user/mosque
Future<void> createInboxNotification({
  required String receiverId,
  required String type,
  required String title,
  required String body,
  String? relatedId,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection("Users")
        .doc(receiverId)
        .collection("InboxNotifications")
        .add({
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  } catch (e) {
    print("Error creating inbox notification: $e");
  }
}

/// Fetches all inbox notifications for the current user,
/// sorted with the newest on top.
///
/// Returns:
/// - A list of `InboxNotification` models from Firestore
Future<List<InboxNotification>> fetchInboxNotifications() async {
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection("Users")
        .doc(uid)
        .collection("InboxNotifications")
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => InboxNotification.fromDocument(doc))
        .toList();
  } catch (e) {
    print("Error fetching inbox notifications: $e");
    return [];
  }
}

/// Marks a specific inbox notification as read.
///
/// Triggered when the user taps the notification tile.
///
/// Parameters:
/// - [notificationId]: The Firestore document ID to update
Future<void> markNotificationAsRead(String notificationId) async {
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection("Users")
        .doc(uid)
        .collection("InboxNotifications")
        .doc(notificationId)
        .update({'read': true});
  } catch (e) {
    print("Error marking notification as read: $e");
  }
}

//ACCOUNT SETTINGS

/// Updates the current user's password in Firebase Authentication.
///
/// Only works for users who signed up using email and password.
/// Should be called after reauthentication.
///
/// Parameters:
/// - [newPassword]: The new password to set
Future<void> updateUserPassword(String newPassword) async {
  try {
    await FirebaseAuth.instance.currentUser?.updatePassword(newPassword);
  } catch (e) {
    print("Error updating password: $e");
    rethrow;
  }
}

/// Permanently deletes a user’s entire account and all associated data.
///
/// This method performs the following steps:
/// 1. Removes the user from other users' friends and friend requests
/// 2. Removes the user from mosque followers, affiliations, and requests
/// 3. Removes the user from event attendance lists
/// 4. Deletes all subcollections under the user’s document
/// 5. Deletes the user document itself
/// 6. Deletes the Firebase Auth account (logs them out)
///
/// Parameters:
/// - [uid]: The user’s UID (must match currently signed-in user)
Future<void> deleteUserAccountFromFirebase(String uid) async {
  final db = FirebaseFirestore.instance;

  // 1. Remove references from all other users (friends and requests)
  final usersSnapshot = await db.collection('Users').get();
  for (final doc in usersSnapshot.docs) {
    final otherUid = doc.id;
    if (otherUid == uid) continue;
    await db.collection('Users').doc(otherUid).collection('Friends').doc(uid).delete();
    await db.collection('Users').doc(otherUid).collection('FriendRequests').doc(uid).delete();
  }

  // 2. Remove references from all mosques (followers, affiliations, requests)
  final mosquesSnapshot = await db.collection('Mosques').get();
  for (final mosque in mosquesSnapshot.docs) {
    final mosqueId = mosque.id;
    await db.collection('Mosques').doc(mosqueId).collection('Followers').doc(uid).delete();
    await db.collection('Mosques').doc(mosqueId).collection('AffiliatedUsers').doc(uid).delete();
    await db.collection('Mosques').doc(mosqueId).collection('AffiliationRequests').doc(uid).delete();
  }

  // 3. Remove attendance records from all posts
  final postsSnapshot = await db.collection('Posts').get();
  for (final post in postsSnapshot.docs) {
    await post.reference.collection('Attendees').doc(uid).delete();
  }

  // 4. Delete all user subcollections (following, affiliations, inbox, etc.)
  final userRef = db.collection('Users').doc(uid);
  final subcollections = [
    'FollowingMosques',
    'AffiliatedMosques',
    'Friends',
    'FriendRequests',
    'NotificationSettings',
    'InboxNotifications',
  ];

  for (final sub in subcollections) {
    final subSnap = await userRef.collection(sub).get();
    for (final doc in subSnap.docs) {
      await doc.reference.delete();
    }
  }

  // 5. Delete user document from Firestore
  await userRef.delete();

  // 6. Remove FCM token and delete FirebaseAuth account
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseMessaging.instance.deleteToken();
    await user.delete(); // Triggers sign-out automatically
  }
  print("SERVICE METHOD COMPLETE");
}

/// Updates a single field for a specific mosque document.
///
/// This is a generic update method to modify any top-level field
/// like name, description, hasWomenSection, or location.
///
/// Parameters:
/// - [mosqueId]: ID of the mosque document
/// - [field]: The field key to update (e.g. "description")
/// - [value]: The new value to assign to the field
Future<void> updateMosqueField(String mosqueId, String field, dynamic value) async {
  await FirebaseFirestore.instance
      .collection('Mosques')
      .doc(mosqueId)
      .update({field: value});
}

/// Permanently deletes a mosque profile and all associated data.
///
/// Steps performed:
/// 1. Deletes all mosque subcollections (followers, admins, requests, prayer times)
/// 2. Deletes all posts by the mosque (and attendees for each post)
/// 3. Deletes the mosque document itself
/// 4. Removes mosque from all users’ `FollowingMosques` and `AffiliatedMosques`
///
/// Parameters:
/// - [mosqueId]: ID of the mosque to delete
Future<void> deleteMosqueProfile(String mosqueId) async {
  try {
    final mosqueRef = _db.collection("Mosques").doc(mosqueId);

    // Step 1: Delete all relevant subcollections under the mosque
    final subcollections = [
      'Followers',
      'AffiliationRequests',
      'AffiliatedUsers',
      'PrayerTimes',
    ];

    for (final sub in subcollections) {
      final snap = await mosqueRef.collection(sub).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    // Step 2: Delete all posts by the mosque (and attendees)
    final postsSnapshot = await _db
        .collection("Posts")
        .where('mosqueId', isEqualTo: mosqueId)
        .get();

    for (final post in postsSnapshot.docs) {
      final attendeesSnapshot =
          await post.reference.collection("Attendees").get();
      for (final attendee in attendeesSnapshot.docs) {
        await attendee.reference.delete();
      }

      await post.reference.delete();
    }

    // 3. Delete the mosque document itself
    await mosqueRef.delete();

    // 4. Remove mosque from all users' FollowingMosques
    final followerUids = await getMosqueFollowerUids(mosqueId);
    for (final uid in followerUids) {
      await _db
          .collection("Users")
          .doc(uid)
          .collection("FollowingMosques")
          .doc(mosqueId)
          .delete();
    }

    // Step 4b: Remove from every user's AffiliatedMosques
    final admins = await getMosqueAdminsFromFirebase(mosqueId);
    for (final admin in admins) {
      await _db
          .collection("Users")
          .doc(admin.uid)
          .collection("AffiliatedMosques")
          .doc(mosqueId)
          .delete();
    }
  } catch (e) {
    print("Error deleting mosque profile: $e");
    rethrow;
  }
}

/// Sets or unsets the primary mosque for the current user.
///
/// Parameters:
/// - [mosqueId]: ID of the mosque to mark as primary.
///   Pass `null` to remove the current primary.
Future<void> setPrimaryMosque(String mosqueId) async {
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection("Users").doc(uid).update({
      'primaryMosqueId': mosqueId,
    });
  } catch (e) {
    print("Error setting primary mosque: $e");
  }
}

/// Fetches the ID of the user’s currently selected primary mosque.
///
/// Returns:
/// - The mosque ID as a string, or null if not set
Future<String?> getPrimaryMosqueId() async {
  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _db.collection("Users").doc(uid).get();
    final data = doc.data();
    return data?['primaryMosqueId'] as String?;
  } catch (e) {
    print("Error getting primary mosque: $e");
    return null;
  }
}
}