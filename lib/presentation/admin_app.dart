import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/master_gate_screen.dart';
import 'screens/accounts_screen.dart';
import 'theme_provider.dart';
import '../theme/admin_theme.dart';

/// Root widget of the admin app.
///
/// The master password is requested on EVERY launch (no session
/// persistence, per the owner's requirement) and the gate is structural:
/// the accounts manager widget tree simply does not exist until it is
/// unlocked, so it cannot be reached by the back button or any navigation.
///
/// Theme: runtime-switchable light/dark. Light is the DEFAULT (outdoor
/// sunlight work); the choice persists via [themeControllerProvider].
class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  bool _unlocked = false;

  void _onUnlocked() => setState(() => _unlocked = true);

  @override
  Widget build(BuildContext context) {
    final ThemeModeOption mode = ref.watch(themeControllerProvider);

    final AdminPaletteSpec spec = mode == ThemeModeOption.light
        ? AdminPaletteSpec.light
        : AdminPaletteSpec.dark;
    AdminPalette.use(spec);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.fromSpec(spec),
      home: _unlocked
          ? AccountsScreen()
          : MasterGateScreen(onUnlocked: _onUnlocked),
    );
  }
}
