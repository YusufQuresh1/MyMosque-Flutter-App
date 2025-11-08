import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart'; // Used for converting coordinates to address.
import 'package:image_picker/image_picker.dart'; // Used for selecting images from gallery.
import 'package:intl/intl.dart'; // Used for formatting dates/times.
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Used for location data.
import 'package:mymosque/helper/format_text.dart'; // Helper for text formatting.
import 'package:mymosque/models/mosque.dart'; // Mosque data model.
import 'package:mymosque/pages/map_picker_page.dart'; // Page for selecting location on a map.
import 'package:mymosque/services/database/database_provider.dart'; // Service for database interactions.
import 'package:mymosque/components/text_field.dart'; // Reusable text field component.
import 'package:provider/provider.dart'; // State management package.

/// A page for creating new posts, optionally including event details and an image.
/// Requires the user to be affiliated with at least one mosque.
class CreatePostPage extends StatefulWidget {
  /// List of mosques the current user is affiliated with, used for the dropdown selection.
  final List<Mosque> affiliatedMosques;

  const CreatePostPage({super.key, required this.affiliatedMosques});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  // Controllers for text input fields.
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _eventAddressController = TextEditingController();

  // State variables for post/event details.
  String? _selectedMosqueId; // ID of the mosque the post is associated with.
  String _selectedGender = 'None'; // Gender restriction for events ('None', 'Male', 'Female').
  DateTime? _selectedDateTime; // Start date/time for events.
  DateTime? _selectedEndDateTime; // End date/time for events.
  bool _addEvent = false; // Flag to toggle event details section visibility.
  LatLng? _selectedLatLng; // Geographic coordinates for event location.
  File? _selectedImage; // Image file selected by the user.

  @override
  void initState() {
    super.initState();
    // Pre-select the first affiliated mosque and its location if available.
    if (widget.affiliatedMosques.isNotEmpty) {
      final defaultMosque = widget.affiliatedMosques.first;
      _selectedMosqueId = defaultMosque.id;

      final location = defaultMosque.location;
      if (location != null) {
        final geo = location['geo'];
        if (geo is GeoPoint) {
          _selectedLatLng = LatLng(geo.latitude, geo.longitude);
          // Attempt to pre-fill the address based on the mosque's location.
          _reverseGeocode(_selectedLatLng!);
        }
      }
    }
  }

  /// Converts geographical coordinates (`LatLng`) into a human-readable address string.
  /// Updates the _eventAddressController.
  void _reverseGeocode(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      final placemark = placemarks.first;
      // Construct address string from placemark details.
      final address = [
        placemark.street,
        placemark.locality,
        placemark.postalCode
      ].where((e) => e != null && e.isNotEmpty).join(', ');

      setState(() {
        _eventAddressController.text = address;
      });
    } catch (_) {
      // Clear address field on error.
      setState(() {
        _eventAddressController.text = '';
      });
    }
  }

  /// Shows Date and Time pickers to select either the start or end time for an event.
  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    // Show Date Picker first.
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // Events cannot start in the past.
      lastDate: DateTime(now.year + 2), // Allow events up to 2 years in the future.
    );
    if (!mounted || pickedDate == null) return; // Exit if cancelled or widget unmounted.

    // Show Time Picker next.
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (!mounted || pickedTime == null) return; // Exit if cancelled or widget unmounted.

    // Combine selected date and time.
    final result = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Update the corresponding state variable.
    setState(() {
      if (isStart) {
        _selectedDateTime = result;
      } else {
        _selectedEndDateTime = result;
      }
    });
  }

  /// Navigates to the MapPickerPage to allow the user to select a location for the event.
  /// Uses the selected mosque's location as the initial map center.
  Future<void> _openMapPicker() async {
    // Find the currently selected mosque in the dropdown.
    final selectedMosque = widget.affiliatedMosques.firstWhere(
      (m) => m.id == _selectedMosqueId,
      orElse: () => widget.affiliatedMosques.first, // Fallback to the first mosque.
    );

    // Extract initial coordinates from the selected mosque, if available.
    LatLng? initialLatLng;
    final location = selectedMosque.location;
    if (location != null) {
      final geo = location['geo'];
      if (geo is GeoPoint) {
        initialLatLng = LatLng(geo.latitude, geo.longitude);
      }
    }

    // Push the MapPickerPage and wait for a LatLng result.
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (context) => MapPickerPage(initialLocation: initialLatLng)),
    );

    if (!mounted || result == null) return; // Exit if no location selected or widget unmounted.

    // Update selected coordinates and reverse geocode to get the address.
    setState(() => _selectedLatLng = result);
    _reverseGeocode(result);
  }

  /// Opens the device's image gallery to allow the user to select an image for the post.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Pick image from gallery with reduced quality for faster uploads.
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path); // Store the selected image file.
      });
    }
  }

  /// Uploads the selected image file to Firebase Storage and returns the download URL.
  Future<String?> _uploadImage(File imageFile) async {
    // Generate a unique filename based on timestamp.
    final filename = 'posts/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(filename);
    await ref.putFile(imageFile); // Upload the file.
    return await ref.getDownloadURL(); // Get the public URL.
  }

  /// Validates input fields and submits the post (with or without event details) to the database.
  void _submitPost() async {
    // Basic validation for post message and selected mosque.
    if (_postController.text.trim().isEmpty || _selectedMosqueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a message and select a mosque.")),
      );
      return;
    }

    final db = Provider.of<DatabaseProvider>(context, listen: false);
    final mosque = widget.affiliatedMosques.firstWhere((m) => m.id == _selectedMosqueId);
    String? imageUrl;

    // Upload image if one was selected.
    if (_selectedImage != null) {
      imageUrl = await _uploadImage(_selectedImage!);
    }

    // Handle event creation if the toggle is enabled.
    if (_addEvent) {
      // Validate event-specific fields.
      if (_eventNameController.text.isEmpty ||
          _eventAddressController.text.isEmpty ||
          _selectedDateTime == null ||
          _selectedEndDateTime == null ||
          !_selectedEndDateTime!.isAfter(_selectedDateTime!)) { // Ensure end time is after start time.
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill out all event details correctly.")),
        );
        return;
      }

      // Prepare event data map for Firestore.
      final eventData = {
        'name': _eventNameController.text.trim(),
        'date_time': Timestamp.fromDate(_selectedDateTime!), // Store as Firestore Timestamp.
        'end_time': Timestamp.fromDate(_selectedEndDateTime!),
        'gender_restriction': _selectedGender,
        'location': {
          'address': _eventAddressController.text.trim(),
          'geo': _selectedLatLng != null
              ? GeoPoint(_selectedLatLng!.latitude, _selectedLatLng!.longitude) // Store as Firestore GeoPoint.
              : GeoPoint(51.5074, -0.1278), // Default location if somehow null.
        },
      };

      // Call database provider method to create post with event.
      await db.postMessageWithEvent(
        _postController.text.trim(),
        mosque.id,
        mosque.name,
        eventData,
        imageUrl: imageUrl,
      );
    } else {
      // Call database provider method for a regular post.
      await db.postMessage(
        _postController.text.trim(),
        mosque.id,
        mosque.name,
        imageUrl: imageUrl,
      );
    }

    // Close the create post page on success.
    if (mounted) Navigator.pop(context);
  }

  /// Helper function to create themed InputDecoration for text fields and dropdowns.
  InputDecoration themedDecoration(BuildContext context, String label) {
    final color = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: color.secondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.primary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color.primary, width: 2),
      ),
      hintStyle: TextStyle(color: color.primary),
    );
  }

  /// Builds a tappable input field look-alike for displaying selected date/time.
  Widget _timeField({
    required String label,
    required DateTime? dateTime,
    required VoidCallback onTap,
  }) {
    // Format the DateTime for display, or show empty string if null.
    final displayText = dateTime == null ? '' : DateFormat.yMMMEd().add_jm().format(dateTime);

    return InkWell( // Makes the area tappable.
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: themedDecoration(context, label),
        child: Text(
          displayText.isEmpty ? " " : displayText,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Create Post")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdown to select the mosque to post as.
            DropdownButtonFormField<String>(
              value: _selectedMosqueId,
              items: widget.affiliatedMosques.map((m) {
                return DropdownMenuItem(
                  value: m.id,
                  child: Text(toTitleCase(m.name)),
                );
              }).toList(),
              onChanged: (val) {
                // Update selected mosque ID and pre-fill location.
                setState(() {
                  _selectedMosqueId = val;
                  final selected = widget.affiliatedMosques.firstWhere((m) => m.id == val);
                  final location = selected.location;
                  if (location != null) {
                    final geo = location['geo'];
                    if (geo is GeoPoint) {
                      _selectedLatLng = LatLng(geo.latitude, geo.longitude);
                      _reverseGeocode(_selectedLatLng!);
                    }
                  }
                });
              },
              decoration: themedDecoration(context, 'Select Mosque'),
            ),
            const SizedBox(height: 16),
            const Text("Post Message", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // Main text field for the post content.
            TextField(
              controller: _postController,
              maxLines: 5,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
              decoration: themedDecoration(context, "Write something...").copyWith(
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              ),
            ),
            const SizedBox(height: 12),
            // Button to add an image.
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.image, color: Colors.white,),
              label: const Text("Add Image"),
              style: ElevatedButton.styleFrom(backgroundColor: color.tertiary, foregroundColor: Colors.white),
            ),
            // Display selected image preview if available.
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, height: 150),
              ),
            ],
            const SizedBox(height: 20),
            // Switch to toggle event details section.
            SwitchListTile(
              title: const Text("Include Event"),
              value: _addEvent,
              activeColor: color.tertiary,
              inactiveThumbColor: color.primary,
              onChanged: (val) => setState(() => _addEvent = val),
              contentPadding: EdgeInsets.zero,
            ),
            // Conditional section for event details.
            if (_addEvent) ...[
              const SizedBox(height: 16),
              const Text("Event Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              MyTextField(
                controller: _eventNameController,
                hintText: "Enter event name",
                obscureText: false,
              ),
              const SizedBox(height: 16),
              // Dropdown for gender restriction.
              DropdownButtonFormField<String>(
                value: _selectedGender,
                onChanged: (val) => setState(() => _selectedGender = val!),
                items: ['None', 'Male', 'Female'].map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                decoration: themedDecoration(context, "Gender Restriction"),
              ),
              const SizedBox(height: 16),
              const Text("Event Location", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              // Button to open map picker.
              ElevatedButton.icon(
                onPressed: _openMapPicker,
                icon: Icon(Icons.location_on, color: Colors.white),
                label: Text(
                  _selectedLatLng != null ? "Edit Location" : "Select Location",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.tertiary,
                ),
              ),
              const SizedBox(height: 10),
              // Text field for event address (can be edited after geocoding).
              MyTextField(
                controller: _eventAddressController,
                hintText: "Edit address if needed",
                obscureText: false,
              ),
              const SizedBox(height: 16),
              const Text("Event Date & Time", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Row for Start and End time pickers.
              Row(
                children: [
                  Expanded(
                    child: _timeField(
                      label: "Start Time",
                      dateTime: _selectedDateTime,
                      onTap: () => _pickDateTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeField(
                      label: "End Time",
                      dateTime: _selectedEndDateTime,
                      onTap: () => _pickDateTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30), // Spacing before FAB area.
            ],
            const SizedBox(height: 80), // Extra spacing at the bottom to avoid FAB overlap.
          ],
        ),
      ),
      // Floating Action Button to submit the post.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitPost,
        backgroundColor: color.tertiary,
        label: const Text("Post"),
        icon: const Icon(Icons.send),
      ),
    );
  }
}
