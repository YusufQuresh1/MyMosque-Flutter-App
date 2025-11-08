import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart'; // Package for integrating Google Places Autocomplete search UI.
import 'package:google_maps_webservice/places.dart'; // Package for interacting with Google Maps web services (like Places API).
import 'package:geolocator/geolocator.dart'; // Package for getting the device's current location.
import 'package:flutter_dotenv/flutter_dotenv.dart';

final String kGoogleApiKey = dotenv.env['GOOGLE_MAPS_API_KEY']!;
// Instance of the Google Maps Places service client, initialized with the API key.
final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

/// A page that displays a Google Map allowing the user to select a geographical location.
///
/// Users can tap on the map or use the search functionality (via Google Places Autocomplete)
/// to find and select a location. The selected `LatLng` coordinates are returned
/// to the calling page via `Navigator.pop`.
class MapPickerPage extends StatefulWidget {
  /// An optional initial location to center the map on when it first loads.
  /// If null, the map attempts to center on the device's current location.
  final LatLng? initialLocation;

  const MapPickerPage({super.key, this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  /// The currently selected geographical coordinates, marked on the map. Null until a selection is made.
  LatLng? _selectedLatLng;

  /// Controller for programmatically interacting with the Google Map widget (e.g., animating camera).
  GoogleMapController? _mapController;

  /// The initial position the map camera will focus on. Defaults to London,
  /// but updated asynchronously based on `widget.initialLocation` or the device's current location.
  LatLng _initialPosition =
      const LatLng(51.5074, -0.1278); // Default: London, UK

  @override
  void initState() {
    super.initState();
    // Determine the initial map center asynchronously after the widget is initialised.
    _initializeMap();
  }

  /// Determines the initial map center based on provided `initialLocation` or device's current location.
  /// Updates the map camera if the controller is ready, otherwise relies on `onMapCreated`.
  Future<void> _initializeMap() async {
    try {
      LatLng target;
      if (widget.initialLocation != null) {
        // Prioritize the explicitly provided initial location.
        target = widget.initialLocation!;
      } else {
        // Attempt to get the device's current location as a fallback.
        // Assumes location permissions are handled before navigating here.
        final position = await Geolocator.getCurrentPosition();
        target = LatLng(position.latitude, position.longitude);
      }

      // Update state with the determined initial position.
      // Also sets the selected location initially if it hasn't been set yet (e.g., by tapping).
      // This ensures a marker is shown immediately if using current location.
      setState(() {
        _initialPosition = target;
        _selectedLatLng ??=
            target; // Set selected location only if it's currently null
      });

      // If the map controller is already available (e.g., if `initState` completes after `onMapCreated`),
      // move the camera immediately.
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(target,
              17), // Zoom level 17 provides a good detailed enough view.
        );
      }
    } catch (e) {
      // If location fetching fails (e.g., permissions denied, service disabled),
      // the map will remain centered on the default `_initialPosition` (London).
      // Log the error for debugging purposes.
      debugPrint("Error initializing map location: $e");
    }
  }

  /// Callback function executed when the user taps directly on the map.
  /// Updates the `_selectedLatLng` state to reflect the tapped coordinates, moving the marker.
  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLatLng = position;
    });
  }

  /// Handles the place search functionality using Google Places Autocomplete.
  /// Opens the search overlay, retrieves details for the selected place,
  /// and updates the map camera and selected location marker.
  Future<void> _handleSearch() async {
    try {
      // Show the autocomplete search UI provided by the flutter_google_places package.
      final prediction = await PlacesAutocomplete.show(
        context: context,
        apiKey: kGoogleApiKey,
        mode: Mode
            .overlay, // Display search results as an overlay on top of the current screen.
        language: "en",
        components: [
          Component(Component.country, "uk")
        ], // Restrict search results to the UK.
      );

      // Exit if the user cancels the search or no valid place is selected.
      if (prediction?.placeId == null) return;

      // Fetch detailed information about the selected place using its unique place ID.
      final detail = await _places.getDetailsByPlaceId(prediction!.placeId!);

      // Extract the location coordinates (latitude, longitude) from the place details.
      final location = detail.result.geometry?.location;
      if (location == null) {
        // Handle cases where coordinates might be missing for a place.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not retrieve coordinates for this place.")),
        );
        return;
      }

      final newLatLng = LatLng(location.lat, location.lng);

      if (!mounted) return;
      // Update the selected location state, moving the marker.
      setState(() {
        _selectedLatLng = newLatLng;
      });

      // Animate the map camera to the newly selected location.
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newLatLng, 17),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick a Location"),
        actions: [
          // Search icon button in the AppBar to trigger the place search overlay.
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _handleSearch,
            tooltip: 'Search location',
          ),
        ],
      ),
      body: GoogleMap(
        // Set the initial camera position based on the determined `_initialPosition`.
        initialCameraPosition: CameraPosition(
          target: _initialPosition,
          zoom: 17,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
          // Ensure the map animates to the correct initial position once the controller is available,
          // especially if `_initializeMap` in `initState` finished before the map was ready.
          _initializeMap();
        },
        // Register the callback for map tap events.
        onTap: _onMapTapped,
        // Display a marker at the `_selectedLatLng` if one has been selected.
        markers: _selectedLatLng != null
            ? {
                // Use a Set<Marker> for map markers.
                Marker(
                  markerId: const MarkerId(
                      "selected-location"), // Unique ID for the marker.
                  position:
                      _selectedLatLng!, // Position the marker at the selected coordinates.
                ),
              }
            : {}, // Provide an empty set if no location is selected yet.
        myLocationEnabled: true, // Show the device's current location blue dot.
        myLocationButtonEnabled: true,
      ),
      // Floating action button to confirm the selection and return to the previous screen.
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        onPressed: () {
          // Only allow confirmation if a location has actually been selected.
          if (_selectedLatLng != null) {
            // Return the selected LatLng data to the screen that pushed this page.
            Navigator.pop(context, _selectedLatLng);
          } else {
            // Inform the user if they haven't selected a location yet.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Please tap on the map or search to select a location."),
              ),
            );
          }
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
