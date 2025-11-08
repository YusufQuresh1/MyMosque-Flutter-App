import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart'; // Used for converting coordinates to address.
import 'package:mymosque/components/button.dart';
import 'package:mymosque/components/loading_circle.dart'; // Helper for showing/hiding loading dialog.
import 'package:mymosque/components/text_field.dart';
import 'package:mymosque/pages/map_picker_page.dart'; // Page for selecting location on a map.
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; // Used for selecting the proof file.
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A page for users to submit an application to register a new mosque profile.
class CreateMosqueApplicationPage extends StatefulWidget {
  const CreateMosqueApplicationPage({super.key});

  @override
  State<CreateMosqueApplicationPage> createState() => _CreateMosqueApplicationPageState();
}

class _CreateMosqueApplicationPageState extends State<CreateMosqueApplicationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  LatLng? selectedLocation; // Stores coordinates selected from the map.
  File? selectedProofFile; // Stores the selected affiliation proof file.
  bool hasWomenSection = false; // Tracks the state of the women's section checkbox.

  /// Opens the MapPickerPage and updates the location and address fields upon selection.
  void pickLocation() async {
    // Navigate to MapPickerPage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MapPickerPage()),
    );

    if (result is LatLng) {
      setState(() {
        selectedLocation = result;
      });

      // Attempt to reverse geocode the selected coordinates to pre-fill the address.
      try {
        final placemarks = await placemarkFromCoordinates(result.latitude, result.longitude);
        final placemark = placemarks.first;
        // Construct a formatted address string.
        final address = [
          placemark.street,
          placemark.locality,
          placemark.postalCode
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        setState(() {
          addressController.text = address;
        });
      } catch (e) {
        // Clear address field if geocoding fails.
        setState(() {
          addressController.text = '';
        });
      }
    }
  }

  /// Uses file_picker to allow the user to select a proof document.
  void pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    // Ensure a file was picked and its path is available.
    if (result != null && result.files.single.path != null) {
      setState(() {
        selectedProofFile = File(result.files.single.path!);
      });
    }
  }

  /// Validates inputs and submits the mosque creation application via DatabaseProvider.
  void submitApplication() async {
    // Basic validation for required fields.
    if (nameController.text.isEmpty || selectedLocation == null || addressController.text.isEmpty || selectedProofFile == null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(title: Text("Please complete all fields.")),
      );
      return;
    }

    showLoadingCircle(context);
    try {
      // Call the database provider method to handle application submission.
      await Provider.of<DatabaseProvider>(context, listen: false).applyToCreateMosque(
        mosqueName: nameController.text,
        geo: GeoPoint(selectedLocation!.latitude, selectedLocation!.longitude), // Convert LatLng to GeoPoint.
        address: addressController.text,
        proofFile: selectedProofFile!,
        hasWomenSection: hasWomenSection,
      );

      // Handle successful submission.
      if (mounted) {
        hideLoadingCircle(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application submitted successfully.")));
      }
    } catch (e) {
      if (!mounted) return;
      hideLoadingCircle(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(title: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text("Register Mosque Profile")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Center(
                child: Icon(
                  Icons.mosque,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              // Informational text about the application process.
              Text(
                "Use this form to submit an application to register a mosque profile within the app. This helps ensure authenticity and accuracy for our users.",
                style: TextStyle(color: colorScheme.primary, fontSize: 14, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 30),
              const Text("Mosque Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              MyTextField(
                controller: nameController,
                hintText: "Enter mosque name",
                obscureText: false,
              ),
              const SizedBox(height: 20),
              const Text("Mosque Location", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              // Button to trigger the map picker.
              ElevatedButton.icon(
                onPressed: pickLocation,
                icon: Icon(Icons.location_on, color: Colors.white),
                label: Text(
                  selectedLocation != null ? "Location selected" : "Select Location",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 20),
              const Text("Address", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              // Address field, pre-filled by pickLocation.
              MyTextField(
                controller: addressController,
                hintText: "Edit address if needed",
                obscureText: false,
              ),
              const SizedBox(height: 20),
              const Text("Women's Section", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              // Checkbox for indicating women's section availability.
              Row(
                children: [
                  Checkbox(
                    value: hasWomenSection,
                    onChanged: (value) {
                      setState(() {
                        hasWomenSection = value ?? false;
                      });
                    },
                    activeColor: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text("This mosque includes a dedicated space for women."),
                  )
                ],
              ),
              const SizedBox(height: 20),
              const Text("Proof of Affiliation", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(
                "Please upload an official document proving your affiliation with the mosque, such as a letter from the mosque or similar.",
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: colorScheme.primary),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: pickFile,
                icon: Icon(Icons.attach_file, color: Colors.white), // White icon
                label: Text(
                  selectedProofFile != null ? "File selected" : "Upload Proof",
                  style: const TextStyle(color: Colors.white), // White text
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary, // Use tertiary color
                ),
              ),
              const SizedBox(height: 30),
              MyButton(
                text: "Submit Application",
                onTap: submitApplication,
              ),
              const SizedBox(height: 30),
              // Final informational text about the review process.
              Text(
                "Once submitted, your application will be reviewed by our team. If approved, the mosque profile will be created and you will be listed as an affiliated user.",
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: colorScheme.primary),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
