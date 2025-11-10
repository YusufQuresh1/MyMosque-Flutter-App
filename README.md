# MyMosque - Mosque Community App (Final Year Dissertation)

Welcome! This repository contains the source code for "MyMosque," a Flutter-based mobile application developed as my final year university dissertation.

The app is a high-fidelity prototype of a social network designed to digitally connect Muslim users with their local mosques and wider community. It features distinct user roles (General User vs. Mosque Admin), a real-time social feed, a map-based mosque finder, and much more.

---

## 🚀 How to Demo (Recommended Method)

For the quickest way to see the app in action, you don't need to build it from the source. You can install the pre-compiled `.apk` file directly onto an Android device or emulator.

1.  **[Download the APK here from the "Releases" tab.](https://github.com/YusufQuresh1/MyMosque-Flutter-App/releases)**
2.  Transfer the `.apk` file to your Android device.
3.  You may need to enable **"Install from unknown sources"** on your device.
4.  Tap the file to install and run.
5.  When prompted, enable permissions for notifications and location.

---

## 🔑 Live Demo Admin Account

To test the admin-only features (like approving mosque applications), you can use the pre-made system admin account.

* **Email:** `mymosque@gmail.com`
* **Password:** `Pass123`

---

## ✨ Core Features

### General User Features
* **Nearby Page:** Navigate via the bottom bar to view a map and list of nearby mosques, complete with markers.
* **Mosque Profiles:** View detailed mosque profiles, see their posts/events, and follow them.
* **Social Feed:** A main home page displaying posts from followed mosques and other users.
* **Social System:** Create a profile, send/accept friend requests, and follow other users.
* **Events:** View and add mosque events to a personal "My Events" list.
* **Notifications:** Receive real-time push notifications for friend requests, accepted applications, etc.

### Mosque Admin Features
* **Mosque Application:** A user can apply to register their mosque via a detailed form in the settings page.
* **Admin Approval:** A system admin (using the demo account above) can review and approve pending mosque applications.
* **Post Creation:** Once approved, mosque admins can create announcement and event posts for their followers.
* **Prayer Timetable:** Admins can set and update the 5 daily prayer and jamaat (congregation) times, which display on the mosque's profile.
* **Affiliation:** Admins can approve requests from other users to become affiliated with and help manage the mosque profile.

---

## 🛠️ Tech Stack
* **Framework:** Flutter
* **Backend (BaaS):** Google Firebase
    * **Authentication:** Firebase Authentication (Email/Password & Google Sign-In)
    * **Database:** Cloud Firestore
    * **Storage:** Firebase Cloud Storage
    * **Notifications:** Firebase Cloud Messaging (FCM)
* **APIs:** Google Maps API, Google Places API
* **State Management:** Provider

---

## 👨‍💻 How to Build from Source

### Requirements
* **Flutter SDK:** Version 3.16.0 (or latest stable)
* **Java Development Kit (JDK):** **Java 17** is required.
* **Android SDK:** API Level 34+
* **VS Code** (with Flutter and Dart extensions)

### 1. 🚨 Security & API Setup (CRITICAL)

**This repository does not contain any secret API keys.** To run the project, you must provide your own.

**A) Firebase Setup (Database & Auth)**
1.  Create a new project in the [Firebase Console](https://console.firebase.google.com/).
2.  Register your Android app (package name: `com.example.mymosque`).
3.  Download the generated `google-services.json` file and place it in `mymosque/android/app/`.
4.  Install the Firebase CLI: `npm install -g firebase-tools`
5.  Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
6.  Run `flutterfire configure` from the project root to generate `lib/firebase_options.dart`.

**B) Google Maps Setup (Maps & Places)**
1.  Go to the [Google Cloud Console](https://console.cloud.google.com/) and enable the **Maps SDK for Android** and **Places API**.
2.  Create a new API Key. **Restrict this key** to your Android app (using your package name and SHA-1 certificate).
3.  Install the `flutter_dotenv` package: `flutter pub add flutter_dotenv`
4.  Create a file named `.env` in the root of the `mymosque` project.
5.  Add your new, restricted key to this file:
    ```
    GOOGLE_MAPS_API_KEY=your_new_google_maps_key_here
    ```
6.  Ensure your `pubspec.yaml` lists `.env` as an asset.
7.  The `main.dart` file is already configured to load this key at startup.

### 2. Run the App

```bash
# Install project dependencies
flutter pub get

# Run the app on a connected device or emulator
flutter run
☕ A Note on Java & Gradle
This project requires JDK 17 for the Gradle build process.

Ensure your JAVA_HOME environment variable is set to your local JDK 17 installation (e.g., C:\Program Files\Java\jdk-17).

The gradle.properties file in this project is portable and relies on JAVA_HOME.

If the build fails, you can try manually setting the Java path in mymosque/android/gradle.properties by adding this line (adjusted for your system): org.gradle.java.home=C:\\Program Files\\Java\\jdk-17

📁 Project File Structure
/mymosque/
├── android/            → Android-specific platform files
├── assets/
│   └── images/         → App assets (images)
├── functions/          → Firebase Cloud Functions (backend logic)
├── lib/                → Main Flutter app source code
│   ├── components/     → Reusable UI widgets
│   ├── helper/         → Helper functions and navigation utilities
│   ├── models/         → Dart models for data structures (User, Post, Mosque)
│   ├── pages/          → App screens/views
│   ├── services/       → Firebase integration and data handling
│   │   ├── auth/       → Authentication services
│   │   └── database/   → Firestore database services
│   ├── themes/         → Light and dark theme definitions
│   └── firebase_options.dart → Firebase config (auto-generated by FlutterFire)
├── main.dart           → Main app entry point
.firebaserc             → Firebase project configuration
.gitignore              → Specifies files to be ignored by Git
analysis_options.yaml   → Dart linter rules
firebase.json           → Firebase Cloud Functions configuration
pubspec.yaml            → Flutter project configuration and package dependencies
README.md               → This file
