// Firebase web options for PhotoMagic Admin.
//
// NOTE: This app will be registered in the NEW Firebase project together
// with PhotoMagic (com.abodycode.photomagic). Android reads its native
// configuration from android/app/google-services.json; the values below are
// only used by the web build (`flutter run -d chrome` / `flutter build web`).
//
// Once the project's google-services.json is available, replace this file
// with the generated equivalent (apiKey, appId, messagingSenderId,
// projectId, authDomain, storageBucket, databaseURL).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase web options are not configured yet. Add this app to the '
        'Firebase project, download google-services.json, then update '
        'lib/firebase_options.dart.',
      );
}
