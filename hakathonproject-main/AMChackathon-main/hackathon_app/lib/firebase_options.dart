import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options for project: amchackathon (AMCHACKATHON)
///
/// Note: This file was generated manually because FlutterFire CLI failed with:
/// "Exception: `UnsupportedError` not found in web".
///
/// If FlutterFire works later, you can safely overwrite this file.
///
/// This class is used by `Firebase.initializeApp(options: ...)` in `main.dart`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // iOS/macOS config files were not generated in this workspace yet.
        // Run FlutterFire again to add iOS/macOS support.
        throw UnsupportedError(
            'DefaultFirebaseOptions are not configured for iOS/macOS in this project yet.');
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        throw UnsupportedError(
            'DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAH32F_8XuFUuwQFTTi6p0_uH_FwyoiyUw',
    appId: '1:514400916496:android:6ec26badd52f54e570e695',
    messagingSenderId: '514400916496',
    projectId: 'amchackathon',
    storageBucket: 'amchackathon.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAH32F_8XuFUuwQFTTi6p0_uH_FwyoiyUw',
    appId: '1:514400916496:web:0eb9fcc21e2688a370e695',
    messagingSenderId: '514400916496',
    projectId: 'amchackathon',
    authDomain: 'amchackathon.firebaseapp.com',
    storageBucket: 'amchackathon.firebasestorage.app',
  );
}
