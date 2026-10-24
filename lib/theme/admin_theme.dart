import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One complete color specification. Two built-in variants exist:
/// [AdminPaletteSpec.light] (daylight paper look — tuned for direct
/// sunlight, the default) and [AdminPaletteSpec.dark] (the original
/// Carbon Slate instrument look for night work).
class AdminPaletteSpec {
  const AdminPaletteSpec({
    required this.background,
    required this.surface,
    required this.frame,
    required this.textPrimary,
    required this.textDim,
    required this.glass,
    required this.brightness,
  });

  final Color background;
  final Color surface;
  final Color frame;
  final Color textPrimary;
  final Color textDim;
  final Color glass;
  final Brightness brightness;

  /// Sunlight-first palette: paper white background, near-black text and
  /// deepened accent hues so every glyph keeps contrast under direct sun.
  static const AdminPaletteSpec light = AdminPaletteSpec(
    background: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    frame: Color(0xFFC3CAD8),
    textPrimary: Color(0xFF101423),
    textDim: Color(0xFF5A6478),
    glass: Color(0x14646F87),
    brightness: Brightness.light,
  );

  /// Night palette: the original Carbon Slate look.
  static const AdminPaletteSpec dark = AdminPaletteSpec(
    background: Color(0xFF12131C),
    surface: Color(0xFF1A1B26),
    frame: Color(0xFF2A2C3D),
    textPrimary: Color(0xFFE8F0FF),
    textDim: Color(0xFF8A93AC),
    glass: Color(0x141E2233),
    brightness: Brightness.dark,
  );
}

/// Runtime-switchable palette accessors. [use] installs the variant;
/// defaults to LIGHT because the panel is operated outdoors.
class AdminPalette {
  AdminPalette._();

  static AdminPaletteSpec _spec = AdminPaletteSpec.light;

  static AdminPaletteSpec get spec => _spec;
  static void use(AdminPaletteSpec spec) => _spec = spec;
  static bool get isLight => _spec == AdminPaletteSpec.light;

  static Color get background => _spec.background;
  static Color get surface => _spec.surface;
  static Color get frame => _spec.frame;
  static Color get textPrimary => _spec.textPrimary;
  static Color get textDim => _spec.textDim;
  static Color get glass => _spec.glass;

  /// Primary accent (buttons, highlights).
  static Color get cyan => isLight ? const Color(0xFF0087A3) : const Color(0xFF00F2FE);

  /// Success / permanent account / activate action.
  static Color get phosphor => isLight ? const Color(0xFF00A34A) : const Color(0xFF00FF87);

  /// Alarm / expired / delete.
  static Color get alarm => isLight ? const Color(0xFFD21243) : const Color(0xFFFF2A55);

  /// Temporary accounts / suspension warnings.
  static Color get amber => isLight ? const Color(0xFFB26B00) : const Color(0xFFFFC24B);
}

/// Application themes for both modes.
class AdminTheme {
  AdminTheme._();

  static ThemeData fromSpec(AdminPaletteSpec spec) {
    final bool light = spec == AdminPaletteSpec.light;
    final Color accent =
        light ? const Color(0xFF0087A3) : const Color(0xFF00F2FE);

    final ColorScheme scheme = ColorScheme(
      brightness: spec.brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: AdminPalette.phosphor,
      onSecondary: Colors.white,
      error: AdminPalette.alarm,
      onError: Colors.white,
      surface: spec.surface,
      onSurface: spec.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: spec.background,
      appBarTheme: AppBarTheme(
        backgroundColor: spec.background,
        foregroundColor: spec.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: spec.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.4),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: spec.surface,
        hintStyle: TextStyle(color: spec.textDim),
        labelStyle: TextStyle(color: spec.textDim),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: spec.frame),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: spec.frame),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: spec.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: spec.frame),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            light ? const Color(0xFF101423) : const Color(0xFF1A1B26),
        contentTextStyle: TextStyle(
          color: light ? const Color(0xFFF6F8FC) : const Color(0xFFE8F0FF),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? Colors.white : spec.textDim,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (Set<WidgetState> s) =>
                s.contains(WidgetState.selected) ? accent : Colors.transparent,
          ),
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: spec.frame)),
        ),
      ),
    );
  }

  static ThemeData light() => fromSpec(AdminPaletteSpec.light);
  static ThemeData dark() => fromSpec(AdminPaletteSpec.dark);
}
