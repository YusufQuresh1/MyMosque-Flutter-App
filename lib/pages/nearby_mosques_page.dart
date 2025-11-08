import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mymosque/helper/format_distance.dart';
import 'package:mymosque/helper/format_text.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:mymosque/helper/navigate.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A screen that displays a map and list of nearby mosques.
///
/// Uses the user's current GPS position and combines:
/// - Mosques stored in the app's Firebase collection
/// - External results from Google Places API
///
/// Users can filter by whether mosques have women's sections,
/// tap on results for more info, view directions, or open mosque profiles.
class NearbyMosquesPage extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const NearbyMosquesPage({super.key, required this.navigatorKey});

  @override
  State<NearbyMosquesPage> createState() => _NearbyMosquesPageState();
}

class _NearbyMosquesPageState extends State<NearbyMosquesPage> {
  // Google Places API client (used to query external mosque locations)
  final GoogleMapsPlaces places =
      GoogleMapsPlaces(apiKey: dotenv.env['GOOGLE_MAPS_API_KEY']!);

  // Controller for the draggable bottom sheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  GoogleMapController? _mapController; // Controls camera movement
  final Set<Marker> _markers = {}; // Set of map markers for mosques
  List<NearbyMosque> _nearbyMosques =
      []; // Combined list of Firebase + Places results
  NearbyMosque?
      _selectedMosque; // Mosque currently selected in the bottom sheet
  Position? _currentPosition; // User’s current GPS location
  bool _filterWomenSection =
      false; // Whether to filter mosques by women’s section
  bool _isLoading = true; // Whether the map/data is still loading

  @override
  void initState() {
    super.initState();
    _initLocationAndMosques(); // Load user's location and nearby mosques
  }

  /// Handles location permissions, retrieves the current GPS location,
  /// loads mosque data from Firebase and Google Places, and sorts by distance.
  Future<void> _initLocationAndMosques() async {
    try {
      // Request location permission if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // Get user’s current GPS position
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() => _currentPosition = position);

      // Load mosque data from Firebase and external Google Place
      final firebaseMosques = await _loadFirebaseMosques(position);
      final placeMosques = await _loadPlaceMosques(position, firebaseMosques);

      // Combine and sort by distance
      final allMosques = [...firebaseMosques, ...placeMosques]
        ..sort((a, b) => a.distance.compareTo(b.distance));

      // Show error if location or loading fails
      if (mounted) {
        setState(() {
          _nearbyMosques = allMosques;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading mosques: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tertiary = Theme.of(context).colorScheme.tertiary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.secondary,
      appBar: AppBar(
        title: const Text('Nearby Mosques'),
        // Filter icon in the app bar opens the bottom sheet filter
        actions: [
          IconButton(
            icon: Icon(
              _filterWomenSection
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined, // Fill icon if active
            ),
            tooltip: "Filter",
            onPressed: _openFilterSheet,
          )
        ],
      ),
      body: _isLoading || _currentPosition == null
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loading while waiting for GPS/data
          : Stack(
              children: [
                // ----------- MAIN MAP LAYER -----------
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    zoom: 13,
                  ),
                  markers: _markers, // Firebase + Google markers
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _mapController = controller,
                ),

                // ----------- BOTTOM DRAGGABLE SHEET -----------
                DraggableScrollableSheet(
                  controller: _sheetController,
                  initialChildSize: 0.33,
                  minChildSize: 0.12,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                      ),

                      // Show either the mosque list or selected mosque details
                      child: _selectedMosque == null
                          ? _buildMosqueList(scrollController, tertiary)
                          : _buildSelectedMosque(scrollController, tertiary),
                    );
                  },
                ),
              ],
            ),
    );
  }

  /// Loads mosque documents from Firebase Firestore.
  ///
  /// For each mosque:
  /// - Retrieves its location
  /// - Calculates distance to the user
  /// - Creates a [Marker] for the map
  /// - Wraps data in a [NearbyMosque] model
  Future<List<NearbyMosque>> _loadFirebaseMosques(Position position) async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('Mosques').get();
    List<NearbyMosque> mosques = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final geo = data['location']?['geo'];

      // Ensure the mosque has a valid GeoPoint location
      if (geo is GeoPoint) {
        final latLng = LatLng(geo.latitude, geo.longitude);

        // Compute straight-line distance between user and mosque
        final distance = Geolocator.distanceBetween(position.latitude,
            position.longitude, latLng.latitude, latLng.longitude);

        // Add custom-colored marker to the map for each Firebase mosque
        _markers.add(Marker(
          markerId: MarkerId(doc.id),
          position: latLng,
          infoWindow: InfoWindow(title: toTitleCase(data['name'])),
          icon: BitmapDescriptor.defaultMarkerWithHue(
              160.0), // Slightly teal hue for Firebase
        ));

        // Construct the nearby mosque model
        mosques.add(NearbyMosque(
          id: doc.id,
          name: data['name'],
          location: latLng,
          distance: distance,
          address: data['location']['address'] ?? 'No address available',
          hasWomenSection: data['hasWomenSection'] ?? false,
          isFromFirebase: true,
        ));
      }
    }
    return mosques;
  }

  /// Loads nearby mosques from Google Places API, using "mosque" as the keyword.
  ///
  /// Filters out any results that are too close to Firebase mosques (within 50 meters) to prevent duplicates.
  Future<List<NearbyMosque>> _loadPlaceMosques(
      Position position, List<NearbyMosque> firebaseMosques) async {
    final response = await places.searchNearbyWithRadius(
      Location(lat: position.latitude, lng: position.longitude),
      5000, // 5km radius
      keyword: 'mosque',
      type: 'mosque',
    );

    // Exit early if request fails or returns no results
    if (response.status != 'OK' || response.results.isEmpty) return [];

    List<NearbyMosque> mosques = [];

    for (var result in response.results) {
      final loc = result.geometry?.location;
      if (loc == null) continue;

      final latLng = LatLng(loc.lat, loc.lng);

      // Skip if a Firebase mosque is already very close to this one
      final isDuplicate = firebaseMosques.any((fbMosque) {
        final distance = Geolocator.distanceBetween(
          fbMosque.location.latitude,
          fbMosque.location.longitude,
          latLng.latitude,
          latLng.longitude,
        );
        return distance < 50;
      });

      if (isDuplicate) continue;

      // Calculate distance to user
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        latLng.latitude,
        latLng.longitude,
      );

      // Add Google marker to map
      _markers.add(Marker(
        markerId: MarkerId(result.placeId),
        position: latLng,
        infoWindow: InfoWindow(title: result.name),
      ));

      // Construct the nearby mosque model
      mosques.add(NearbyMosque(
        id: result.placeId,
        name: result.name,
        location: latLng,
        distance: distance,
        address: result.vicinity ?? 'No address available',
        isFromFirebase: false,
      ));
    }

    return mosques;
  }

  /// Animates the map camera to focus on the selected mosque's location,
  /// and updates the UI to show its expanded details in the bottom sheet.
  void _zoomToMosque(NearbyMosque mosque) async {
    _mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(mosque.location, 15));

    // Animate sheet to original height and show details
    await _sheetController.animateTo(0.33,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    if (mounted) setState(() => _selectedMosque = mosque);
  }

  /// Resets the bottom sheet to show the full list instead of a selected mosque.
  ///
  /// Also animates the sheet to the mid-height level and resets internal state.
  void _clearSelectedMosque() {
    setState(() => _selectedMosque = null);

    // Animate sheet back to default position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sheetController.animateTo(0.33,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  /// Opens Google Maps to show directions from the user’s location to the selected mosque.
  ///
  /// Falls back to an error SnackBar if Google Maps cannot be launched.
  void _openDirections(LatLng location) async {
    final uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch Google Maps")),
      );
    }
  }

  /// Opens a modal bottom sheet with a toggle filter for mosques that have a women's section.
  ///
  /// Uses a temporary flag so users can preview before applying changes.
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        bool tempFilter = _filterWomenSection;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sheet title
                  Row(
                    children: [
                      Icon(Icons.filter_alt,
                          size: 20,
                          color: Theme.of(context).colorScheme.inversePrimary),
                      SizedBox(width: 8),
                      Text("Filters",
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.inversePrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),

                  // Filter switch for women's section
                  SwitchListTile(
                    value: tempFilter,
                    title: const Text("Women's Section Available"),
                    onChanged: (value) =>
                        setModalState(() => tempFilter = value),
                    activeColor: Theme.of(context).colorScheme.tertiary,
                    inactiveThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 15),

                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _filterWomenSection = tempFilter);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Apply"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Builds the default bottom sheet content: a list of all nearby mosques.
  ///
  /// If the women's section filter is active, only mosques that have one are shown.
  /// Each item is tappable to reveal more details and zoom into the map.
  Widget _buildMosqueList(ScrollController scrollController, Color tertiary) {
    // Apply filtering if enabled
    final filteredMosques = _filterWomenSection
        ? _nearbyMosques.where((m) => m.hasWomenSection).toList()
        : _nearbyMosques;

    return Column(
      children: [
        // Handle bar for draggable sheet
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Scrollable list of mosque tiles
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: filteredMosques.length,
            itemBuilder: (context, index) {
              final mosque = filteredMosques[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),

                  // Firebase mosques have a border to distinguish them
                  border: mosque.isFromFirebase
                      ? Border.all(color: tertiary, width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2))
                  ],
                ),
                // Tapping zooms to that mosque and shows details
                child: InkWell(
                  onTap: () => _zoomToMosque(mosque),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with mosque icon (if from Firebase)
                      Row(
                        children: [
                          if (mosque.isFromFirebase)
                            Icon(Icons.mosque, color: tertiary, size: 20),
                          if (mosque.isFromFirebase) const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              mosque.isFromFirebase
                                  ? toTitleCase(mosque.name)
                                  : mosque.name,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Display distance in readable format (e.g. 0.3 miles)
                      Text(formatDistance(mosque.distance)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(mosque.address,
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Builds the detail view for a selected mosque when tapped in the list.
  ///
  /// Includes name, location, women’s section, and action buttons to view the
  /// profile (if Firebase-based) or get directions via Google Maps.
  Widget _buildSelectedMosque(
      ScrollController scrollController, Color tertiary) {
    return SizedBox(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Drag handle at the top
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Mosque name and distance
          Text(
            _selectedMosque!.isFromFirebase
                ? toTitleCase(_selectedMosque!.name)
                : _selectedMosque!.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(formatDistance(_selectedMosque!.distance)),
          const SizedBox(height: 6),

          // Address row
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: tertiary),
              const SizedBox(width: 6),
              Expanded(child: Text(_selectedMosque!.address)),
            ],
          ),

          // Optional women's section badge
          if (_selectedMosque!.hasWomenSection)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.female, size: 16, color: tertiary),
                  const SizedBox(width: 6),
                  const Text("Women's section available"),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Action buttons: View Profile / Get Directions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMosque!.isFromFirebase
                        ? tertiary
                        : Colors.grey,
                    foregroundColor: Colors.white,
                  ),

                  // Only open Firebase-linked profiles
                  onPressed: _selectedMosque!.isFromFirebase
                      ? () async {
                          final doc = await FirebaseFirestore.instance
                              .collection('Mosques')
                              .doc(_selectedMosque!.id)
                              .get();
                          if (doc.exists) {
                            final fullMosque = Mosque.fromDocument(doc);
                            goToMosquePage(widget.navigatorKey, fullMosque);
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Mosque profile not found.")),
                            );
                          }
                        }
                      : null,
                  child: const Text("View Profile"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tertiary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _openDirections(_selectedMosque!.location),
                  child: const Text("Get Directions"),
                ),
              ),
            ],
          ),
          // Back button to return to the full list
          TextButton(
              onPressed: _clearSelectedMosque,
              child: const Text("Back to list")),
        ],
      ),
    );
  }
}

/// A simplified data model representing a mosque shown in the NearbyMosquesPage.
///
/// This model combines data from two possible sources:
/// - Firebase mosque documents (registered in the app)
/// - Google Places API results (external mosques)
///
/// It holds enough detail for sorting, map display, and filtering.
/// Firebase mosques can be opened as profiles, whereas external ones can only be viewed on the map.
class NearbyMosque {
  final String id;

  /// Unique ID — either a Firestore document ID or a Google Place ID.
  final String name;

  /// The mosque's display name.
  final LatLng location;

  /// Geographic coordinates of the mosque.
  final double distance;

  /// Straight-line distance from the user (in meters).
  final String address;

  /// Human-readable address string.
  final bool hasWomenSection;

  /// Whether the mosque is marked as having a women’s prayer section.
  final bool isFromFirebase;

  /// True if this mosque came from Firebase. False if it's from Google Places.
  /// Determines styling and whether the "View Profile" button is enabled.

  NearbyMosque({
    required this.id,
    required this.name,
    required this.location,
    required this.distance,
    required this.address,
    this.hasWomenSection = false,
    this.isFromFirebase = true,
  });
}
