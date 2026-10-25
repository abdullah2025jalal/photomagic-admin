import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';

import 'presentation/admin_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Native configuration (android/app/google-services.json) processed by
  // the Google Services Gradle plugin. Firebase must be ready before the
  // accounts screen opens its Realtime Database stream. A failure is
  // fatal here on purpose: the panel is useless without the database, so
  // the owner sees the reason instead of a silent empty list.
  try {
    await Firebase.initializeApp(
      // Always pass the Dart options, on every platform: the Android
      // google-services.json has NO "database_url" entry (the Realtime
      // Database lives in europe-west1), so the native plugin alone cannot
      // resolve FirebaseDatabase.instance and every operation reports
      // "الجهاز غير متصل بالإنترنت". DefaultFirebaseOptions carries the
      // explicit databaseURL, which fixes both the offline banner and the
      // persisting of created accounts.
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    runApp(_FatalFirebaseApp(message: '${e.code}: ${e.message}'));
    return;
  } catch (e) {
    runApp(_FatalFirebaseApp(message: e.toString()));
    return;
  }
  // ProviderScope is REQUIRED: AdminApp and every screen below it are
  // Riverpod Consumers (theme controller). Building a Consumer without a
  // scope throws at runtime and renders a blank gray screen in release.
  runApp(const ProviderScope(child: AdminApp()));
}

/// Full-screen failure report shown only when Firebase cannot initialize
/// (e.g. google-services.json missing/mismatched package name).
class _FatalFirebaseApp extends StatelessWidget {
  const _FatalFirebaseApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, color: Color(0xFFFF2A55), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'فشل تهيئة Firebase',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
