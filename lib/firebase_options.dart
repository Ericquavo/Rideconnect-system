// File: lib/firebase_options.dart
// Generated from Firebase Console for project: rideconnect-da009
//
// IMPORTANT: Fill in your actual Firebase API key from the Firebase Console:
// https://console.firebase.google.com/project/rideconnect-da009/settings/general
//
// You can pass it via --dart-define=FIREBASE_API_KEY=your_key_here
// or hardcode it below for development.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: 'AIzaSyD-REPLACE_WITH_YOUR_ACTUAL_API_KEY',
    ),
    appId: '1:647214372709:android:6d8a2e4e70e095fa7ee5b1',
    messagingSenderId: '647214372709',
    projectId: 'rideconnect-da009',
    storageBucket: 'rideconnect-da009.appspot.com',
  );
}
