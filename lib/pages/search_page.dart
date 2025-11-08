import 'package:flutter/material.dart';
import 'package:mymosque/helper/format_text.dart';
import 'package:mymosque/helper/navigate.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:provider/provider.dart';

/// A page that allows users to search for other users or mosques in real-time.
/// It uses a shared `DatabaseProvider` to query Firestore and display results.
/// Results are shown live as the user types, and the page supports navigation to
/// both user and mosque profile pages.
class SearchPage extends StatefulWidget {
  /// Navigator key used to enable nested navigation without leaving the current tab view.
  final GlobalKey<NavigatorState> navigatorKey;

  const SearchPage({super.key, required this.navigatorKey});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  /// Controller for the search input field.
  final _searchController = TextEditingController();

  /// Stores the most recent search query to determine what should be displayed.
  String _lastQuery = "";

  @override
  void dispose() {
    _searchController.dispose(); // Clean up controller to avoid memory leaks
    super.dispose();
  }

  /// Handles logic whenever the user types something in the search box.
  /// Converts input to lowercase, clears results if the input is empty,
  /// otherwise performs a combined search for users and mosques.
  void _handleSearch(String input) async {
    final query = input.trim().toLowerCase();

    // Update local state to trigger UI changes
    setState(() {
      _lastQuery = query;
    });

    final db = Provider.of<DatabaseProvider>(context, listen: false);

    if (query.isEmpty) {
      db.clearSearchResults(); // Clears cached results when input is cleared
    } else {
      await db.searchAll(query); // Performs both user and mosque searches
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get access to the provider which contains the current search results
    final results = Provider.of<DatabaseProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,

      // The app bar contains a styled text field for search input
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
            decoration: InputDecoration(
              hintText: "Search users or mosques...",
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: _handleSearch, // Called every time the input changes
          ),
        ),
      ),

      // Main content of the page depends on the search query and results
      body: _lastQuery.isEmpty
          // Initial message prompting the user to start searching
          ? const Center(child: Text("Start typing to search"))
          
          // If query exists but no results were returned
          : (results.searchResult.isEmpty && results.searchMosqueResult.isEmpty)
              ? const Center(child: Text("No results found"))

              // If results exist, display them in a scrollable list
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: ListView(
                    children: [
                      // Display user search results
                      ...results.searchResult.map((user) => ListTile(
                            leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                            title: Text(
                              user.name,
                              style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "@${user.username}",
                              style: TextStyle(color: Theme.of(context).colorScheme.primary),
                            ),
                            onTap: () => goToUserPage(widget.navigatorKey, user.uid),
                          )),

                      // Display mosque search results
                      ...results.searchMosqueResult.map((mosque) => ListTile(
                            leading: Icon(Icons.mosque, color: Theme.of(context).colorScheme.tertiary),
                            title: Text(
                              toTitleCase(mosque.name),
                              style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary, fontWeight: FontWeight.w600),
                            ),
                            subtitle: mosque.description.isNotEmpty == true
                                ? Text(
                                    mosque.description,
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                  )
                                : null,
                            onTap: () => goToMosquePage(widget.navigatorKey, mosque),
                          )),
                    ],
                  ),
                ),


    );
  }
}
