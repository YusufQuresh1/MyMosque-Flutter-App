import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mymosque/components/loading_circle.dart';
import 'package:mymosque/components/user_list_tile.dart';
import 'package:mymosque/helper/format_text.dart';
import 'package:mymosque/helper/timestamp_utils.dart';
import 'package:mymosque/models/post.dart';
import 'package:mymosque/models/user.dart';
import 'package:mymosque/services/auth/auth_service.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Based on code by Mitch Koko (YouTube tutorial: https://www.youtube.com/watch?v=q8m_fSYqx0w&list=PLGrV4FhnA_DcvE5Ml4DFFqZzvloFw9lwF&index=6)
/// Functionality added by Mohammed Qureshi:
/// - Display of mosque name with tap-to-navigate
/// - Post options menu (delete/cancel for owner)
/// - Full event system support: name, time range, gender restrictions, location, Google Maps integration
/// - Attendance system: toggle button, eligibility check, status updates
/// - Friend/attendee display with modals
/// - Timestamp and posted-by user link with tap-to-navigate
/// - Image preview support in post
/// - Dynamic gender restriction logic (based on user gender)
/// - Data preloading using initState (gender, friends, attendance, affiliation)
/// - Navigation via injected GlobalKey and callback functions

class MyPostTile extends StatefulWidget {
  // A visual tile displaying a post (can include an event)
  // Used in feed views, mosque profiles, and user profiles
  final Post post;
  final void Function(String uid)? onTapUser;
  final void Function(String mosqueId)? onTapMosque;
  final GlobalKey<NavigatorState> navigatorKey;

  const MyPostTile({
    super.key,
    required this.post,
    required this.navigatorKey,
    this.onTapUser,
    this.onTapMosque,
  });

  @override
  State<MyPostTile> createState() => _MyPostTileState();
}

class _MyPostTileState extends State<MyPostTile> {
  late final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);
  late final listeningProvider = Provider.of<DatabaseProvider>(context);
  bool isAffiliated = false;   // Whether current user is affiliated with this mosque
  final currentUserId = AuthService().getCurrentUid();
  String? _userGender; // Gender of the current user (used for gender filtering)


@override
void initState() {
  super.initState();
  final userId = AuthService().getCurrentUid();
  final postId = widget.post.id;
  

  // Load gender once so can apply gender restrictions later
  databaseProvider.userProfile(userId).then((profile) {
    if (mounted) {
      setState(() {
        _userGender = profile?.gender.toLowerCase();
      });
    }
  });

  // If the post is an event, load friends and attendance status
  if (widget.post.event != null) {
    databaseProvider.loadFriends(userId).then((_) {
      databaseProvider.loadEventAttendance(postId, userId);
    });
    checkAffiliation(); // Also check if the user is affiliated with the posting mosque
  }
}

  /// Checks whether the current user is affiliated with the mosque of this post
  Future<void> checkAffiliation() async {
    final affiliatedIds = await databaseProvider.getUserAffiliatedMosqueIds();
    if (mounted) {
      setState(() {
        isAffiliated = affiliatedIds.contains(widget.post.mosqueId);
      });
    }
  }

  /// Shows a bottom sheet with post actions
  void _showOptions() {
    final currentUid = AuthService().getCurrentUid();
    final isOwnPost = widget.post.uid == currentUid;

    if (isOwnPost) {
      showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text("Delete"),
                  onTap: () async {
                    Navigator.pop(context);
                    await databaseProvider.deletePost(widget.post.id);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text("Cancel"),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  /// Opens the location of the event in Google Maps
  void _openInGoogleMaps() async {
    final geo = widget.post.event?['location']?['geo'];
    if (geo is GeoPoint) {
      final uri = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${geo.latitude},${geo.longitude}");
      if (!mounted) return;
      showLoadingCircle(context);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }

      if (!mounted) return;
      hideLoadingCircle(context);
    }
  }

  /// Displays a bottom sheet list of users
  void _showModalWithUsers(String title, List<UserProfile> users) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.inversePrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.primary),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  return MyUserTile(
                    user: users[index],
                    navigatorKey: widget.navigatorKey,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats event start/end time into a single readable string
  String formatEventRange(Timestamp start, Timestamp? end) {
    final startDate = start.toDate();
    final startStr = DateFormat('EEE, MMM d • h:mm a').format(startDate);
    if (end == null) return startStr;
    final endStr = DateFormat('h:mm a').format(end.toDate());
    return '$startStr – $endStr';
  }

  /// Converts raw gender string into display format
  String _formatGender(dynamic value) {
    final lower = value.toString().toLowerCase();
    if (lower == 'male') return 'Brothers only';
    if (lower == 'female') return 'Sisters only';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.post.event;
    final hasEvent = event != null;
    
    final isAttending = listeningProvider.isAttending(widget.post.id, currentUserId);
    final friendsAttending = listeningProvider.getFriendsAttending(widget.post.id);
    final allAttendees = listeningProvider.getAllAttendees(widget.post.id);

    final DateTime now = DateTime.now();
    final DateTime? start = hasEvent ? (event['date_time'] as Timestamp?)?.toDate() : null;
    final DateTime? end = hasEvent ? (event['end_time'] as Timestamp?)?.toDate() : null;
    final bool isUpcoming = hasEvent && start != null && end != null && now.isBefore(end);
    final genderText = _formatGender(event?['gender_restriction']);

// Determines if the user is allowed to see/join based on gender restriction
final eventGender = event?['gender_restriction']?.toString().toLowerCase();
final isAllowedGender = eventGender == null || eventGender.isEmpty || eventGender == 'none' || eventGender == _userGender;
final isUnrestricted = eventGender == null || eventGender.isEmpty || eventGender == 'none';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.onTapMosque?.call(widget.post.mosqueId),
                child: Row(
                  children: [
                    Icon(
                      Icons.mosque,
                      color: HSLColor.fromColor(Theme.of(context).colorScheme.tertiary)
                          .withSaturation(0.2)
                          .toColor(),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      toTitleCase(widget.post.mosqueName),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.inversePrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showOptions,
                child: Icon(
                  Icons.more_horiz,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.post.message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
          ),
          // Post image if it exists
          if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.post.imageUrl!,
                fit: BoxFit.cover,
              ),
            ),
          ],
          // If this post has an event, show its details block
          if (hasEvent) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event['name'] ?? 'Event',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.inversePrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Date & time
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Text(
                        formatEventRange(event['date_time'], event['end_time']),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.inversePrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Gender restriction info if present

                  if (isUnrestricted || genderText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isUnrestricted) ...[
                          Icon(Icons.people_alt, size: 18, color: Theme.of(context).colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            "Brothers & Sisters",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 14,
                            ),
                          ),
                        ] else ...[
                          Icon(
                            eventGender == 'male' ? Icons.man : Icons.woman,
                            size: 18,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            genderText,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Location
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _openInGoogleMaps,
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 20, color: Theme.of(context).colorScheme.tertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            event['location']?['address'] ?? '',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Attendance button or restriction text
                  if (isUpcoming && isAllowedGender)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAttending
                            ? const Color.fromARGB(255, 167, 167, 167)
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                      onPressed: () {
                        databaseProvider.toggleAttendance(widget.post.id);
                      },
                      child: Text(
                        isAttending ? 'Attending InshaAllah' : 'Add to My Events',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else if (isUpcoming && !isAllowedGender)
                    Text(
                      "You are not eligible to attend this event.",
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontStyle: FontStyle.italic),
                    )
                  else
                    Text(
                      "Event has ended",
                      style: TextStyle(color: Theme.of(context).colorScheme.primary,fontSize: 14, fontStyle: FontStyle.italic),
                    ),

                  // Display friends attending / all attendees (if affiliated)
                  if (friendsAttending.isNotEmpty || (isAffiliated && allAttendees.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (friendsAttending.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final profiles = await Future.wait(
                                friendsAttending.map((uid) => databaseProvider.userProfile(uid)),
                              );
                              _showModalWithUsers("Friends Attending", profiles.whereType<UserProfile>().toList());
                            },
                            child: Text(
                              "${friendsAttending.length} friend${friendsAttending.length > 1 ? 's' : ''} attending",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.inversePrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (isAffiliated && allAttendees.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final profiles = await Future.wait(
                                allAttendees.map((uid) => databaseProvider.userProfile(uid)),
                              );
                              _showModalWithUsers("All Attendees", profiles.whereType<UserProfile>().toList());
                            },
                            child: Text(
                              "${allAttendees.length} attendee${allAttendees.length != 1 ? 's' : ''}",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.inversePrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Row with username and timestamp
          Row(
            children: [
              GestureDetector(
                onTap: () => widget.onTapUser?.call(widget.post.uid),
                child: Text(
                  'Posted by @${widget.post.username}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                formatTimestamp(widget.post.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
