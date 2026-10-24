import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which palette the admin panel uses. [light] is the default: the panel
/// is operated outdoors under direct sunlight.
enum ThemeModeOption { light, dark }

class ThemeController extends StateNotifier<ThemeModeOption> {
  ThemeController() : super(ThemeModeOption.light) {
    _load();
  }

  static const String _key = 'photomagic_admin.theme_mode_v1';

  Future<void> _load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      state = raw == ThemeModeOption.dark.name
          ? ThemeModeOption.dark
          : ThemeModeOption.light;
    } catch (_) {
      state = ThemeModeOption.light;
    }
  }

  Future<void> setMode(ThemeModeOption mode) async {
    state = mode;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {
      // Best-effort persistence.
    }
  }

  void toggle() => setMode(
      state == ThemeModeOption.light ? ThemeModeOption.dark : ThemeModeOption.light);
}

/// Global theme mode controller for the admin app.
final StateNotifierProvider<ThemeController, ThemeModeOption>
    themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeModeOption>(
  (Ref ref) => ThemeController(),
);
