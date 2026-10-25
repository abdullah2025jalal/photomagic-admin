// Firebase configuration for PhotoMagic Admin (project photomagic-2a69e).
//
// Hand-maintained equivalent of the `flutterfire configure` output, with one
// critical addition: the android/app/google-services.json processed by the
// Gradle plugin contains NO "database_url" entry (the Realtime Database is
// provisioned in europe-west1), so on Android FirebasePlugin cannot hand
// FirebaseDatabase.instance a working URL and every operation surfaces as
// "الجهاز غير متصل بالإنترنت". Dart options DO carry the databaseURL, so
// main() always passes DefaultFirebaseOptions.currentPlatform — on every
// platform — to Firebase.initializeApp.
//
// The API key is public by design (protected by RTDB security rules).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyCHTnOn5a566OoWDKX4L12KLWAEv9w8h8Q',
      appId: '1:341423679429:android:9726ca946e152a7e6e4dac',
      messagingSenderId: '341423679429',
      projectId: 'photomagic-2a69e',
      authDomain: 'photomagic-2a69e.firebaseapp.com',
      storageBucket: 'photomagic-2a69e.firebasestorage.app',
      databaseURL:
          'https://photomagic-2a69e-default-rtdb.europe-west1.firebasedatabase.app',
    );
  }
}
