import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mymosque/services/database/database_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Used to open the proof file URL.

/// A page specifically for administrators to review pending mosque creation applications.
/// It displays a list of applications with status 'pending', showing details like mosque name,
/// applicant info, location, and provides a link to view the proof document.
/// Administrators can approve or reject applications directly from this page.
class ApproveApplicationsPage extends StatefulWidget {
  const ApproveApplicationsPage({super.key});

  @override
  State<ApproveApplicationsPage> createState() => _ApproveApplicationsPageState();
}

class _ApproveApplicationsPageState extends State<ApproveApplicationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<DatabaseProvider>().loadMosqueApplications());
  }

  @override
  Widget build(BuildContext context) {
    // Watch for changes in the DatabaseProvider, specifically the applications list.
    final provider = context.watch<DatabaseProvider>();
    final applications = provider.applications.where((app) => app.status == 'pending').toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Approve Mosque Applications")),
      body: applications.isEmpty
          ? const Center(child: Text("No pending applications"))
          : ListView.builder(
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];

                // Display each application in a Card.
                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mosque Name: ${app.mosqueName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("Applicant: ${app.applicantUsername}"),
                        Text("Address: ${app.location['address']}"),
                        Text("Women's Section: ${app.hasWomenSection ? 'Yes' : 'No'}"),
                        const SizedBox(height: 6),
                        // Tappable text to view the uploaded proof file.
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.parse(app.proofUrl);
                            try {
                              // Attempt to launch the URL, preferring in-app web view.
                              final canLaunchInApp = await canLaunchUrl(uri);
                              if (canLaunchInApp) {
                                await launchUrl(uri, mode: LaunchMode.inAppWebView);
                              } else {
                                // Fallback to external browser if in-app fails.
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              // Show error if URL launching fails.
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Could not open proof file")),
                              );
                            }
                          },
                          child: Text(
                            "View Proof File",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Reject button calls the provider method.
                            TextButton(
                              onPressed: () => provider.rejectApplication(app.id),
                              child: const Text("Reject", style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 10),
                            // Approve button calls the provider method.
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.tertiary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => provider.approveApplication(app),
                              child: const Text("Approve"),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
