import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mymosque/components/settings_tile.dart';
import 'package:mymosque/components/input_alert_box.dart';
import 'package:mymosque/models/mosque.dart';
import 'package:mymosque/pages/edit_prayer_timetable_page.dart';
import 'package:mymosque/pages/map_picker_page.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// A settings screen for a specific mosque (accessed by affiliated users).
///
/// Allows the user to:
/// - Edit the mosque’s name and description
/// - Change its map location using a location picker
/// - Toggle the women's section attribute
/// - Manage the prayer timetable
/// - Delete the mosque profile entirely
///
/// Changes are persisted to Firebase via [DatabaseProvider].
class MosqueProfileSettingsPage extends StatefulWidget {
  final Mosque mosque;

  const MosqueProfileSettingsPage({super.key, required this.mosque});

  @override
  State<MosqueProfileSettingsPage> createState() => _MosqueProfileSettingsPageState();
}

class _MosqueProfileSettingsPageState extends State<MosqueProfileSettingsPage> {
  // Controllers for editing text fields (name & description)
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();

  // Tracks current toggle state for "Women's Section" switch
  bool hasWomenSection = false;

  @override
  void initState() {
    super.initState();

    // Populate the initial form values from the mosque passed in
    nameController.text = widget.mosque.name;
    descriptionController.text = widget.mosque.description;
    hasWomenSection = widget.mosque.hasWomenSection;
  }

  @override
  void dispose() {
    // Clean up text controllers to prevent memory leaks
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  /// Shows an alert dialog to edit the mosque's name and updates it in Firestore
  void _updateName(DatabaseProvider db) {
    showDialog(
      context: context,
      builder: (_) => MyInputAlertBox(
        textController: nameController,
        hintText: "Enter new mosque name",
        onPressedText: "Update",
        onPressed: () async {
          await db.updateMosqueField(widget.mosque.id, 'name', nameController.text.trim());
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name updated.")));
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }

  /// Shows an alert dialog to edit the mosque's description and saves it to Firestore
  void _updateDescription(DatabaseProvider db) {
    showDialog(
      context: context,
      builder: (_) => MyInputAlertBox(
        textController: descriptionController,
        hintText: "Enter new description",
        onPressedText: "Update",
        onPressed: () async {
          await db.updateMosqueField(widget.mosque.id, 'description', descriptionController.text.trim());
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Description updated.")));
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }

  /// Opens the map picker and updates the mosque's stored location if a new one is chosen
  void _pickNewLocation(DatabaseProvider db) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerPage()),
    );
    if (!mounted) return;

    // If a LatLng is returned from the picker, update it in Firestore
    if (result is LatLng) {
      await db.updateMosqueField(widget.mosque.id, 'location.geo', result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location updated.")));
    }
  }

  /// Updates the hasWomenSection flag in Firestore and updates local state
  void _toggleWomenSection(DatabaseProvider db, bool value) async {
    setState(() {
      hasWomenSection = value;
    });

    await db.updateMosqueField(widget.mosque.id, 'hasWomenSection', value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully.")));
  }

/// Confirms and deletes the mosque document from Firestore.
/// Pops back with a result that signals deletion (handled in MosqueProfilePage).
void _confirmDelete(DatabaseProvider db) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Mosque Profile"),
      content: const Text("Are you sure you want to delete this mosque profile? This cannot be undone."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(), // Close the dialog
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
            try {
              await db.deleteMosque(widget.mosque.id);
              if (!mounted) return;

              // Only pop once from settings page, send result "true"
              Navigator.of(context).pop(true); 
              // DO NOT pop twice here — the calling page (MosqueProfilePage) handles the second pop.
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            }
          },
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseProvider>(context);  // Used for all update methods

    return Scaffold(
      appBar: AppBar(title: const Text("Mosque Settings")),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        children: [
          // -------- Edit Name --------
          MySettingsTile(
            title: "Edit Name",
            action: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _updateName(db),
            ),
          ),
          
          // -------- Edit Description --------
          MySettingsTile(
            title: "Edit Description",
            action: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _updateDescription(db),
            ),
          ),
          
          // -------- Change Location --------
          MySettingsTile(
            title: "Change Location",
            action: IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: () => _pickNewLocation(db),
            ),
          ),
          
          // -------- Toggle Women's Section (Custom Styled) --------
          MySettingsTile(
            title: "Women's Section",
            action: Switch(
              value: hasWomenSection,
              onChanged: (value) => _toggleWomenSection(db, value),
              activeColor:  Theme.of(context).colorScheme.tertiary,
              inactiveThumbColor:  Theme.of(context).colorScheme.primary,
            ),
          ),

          // -------- Prayer Timetable Link --------
          MySettingsTile(
            title: "Edit Prayer Timetable",
            action: IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditPrayerTimetablePage(mosqueId: widget.mosque.id),
                  ),
                );
              },
            ),
          ),

          const Divider(),

          // -------- Delete Button --------
          MySettingsTile(
            title: "Delete Mosque Profile",
            action: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDelete(db),
            ),
          ),
        ],
      ),
    );
  }
}
