// Generates the PhotoMagic Admin launcher icon set:
// a white shield with a keyhole on a violet→blue gradient — "protected
// accounts" — drawn directly with Dart so no external tooling is required.
//
// Run: dart run tool/generate_app_icon.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Future<void> main() async {
  // Android legacy launcher icons (all densities).
  const Map<int, String> targets = <int, String>{
    48: 'mdpi',
    72: 'hdpi',
    96: 'xhdpi',
    144: 'xxhdpi',
    192: 'xxxhdpi',
  };

  for (final MapEntry<int, String> t in targets.entries) {
    final Uint8List png = _renderPng(t.key);
    final String dir = 'android/app/src/main/res/mipmap-${t.value}';
    Directory(dir).createSync(recursive: true);
    File('$dir/ic_launcher.png').writeAsBytesSync(png);
    stdout.writeln('wrote $dir/ic_launcher.png (${t.key}px)');
  }

  // Adaptive-icon foreground (108dp), transparent background, artwork kept
  // inside the 66dp safe zone.
  const Map<int, String> foregroundTargets = <int, String>{
    108: 'mdpi',
    162: 'hdpi',
    216: 'xhdpi',
    324: 'xxhdpi',
    432: 'xxxhdpi',
  };

  for (final MapEntry<int, String> t in foregroundTargets.entries) {
    final Uint8List png = _renderPng(
      t.key,
      shieldScale: 0.52,
      transparent: true,
    );
    final String dir = 'android/app/src/main/res/mipmap-${t.value}';
    Directory(dir).createSync(recursive: true);
    File('$dir/ic_launcher_foreground.png').writeAsBytesSync(png);
    stdout.writeln(
        'wrote $dir/ic_launcher_foreground.png (${t.key}px)');
  }

  // Web / PWA icons.
  Directory('web/icons').createSync(recursive: true);
  File('web/icons/Icon-192.png')
      .writeAsBytesSync(_renderPng(192, shieldScale: 0.60));
  File('web/icons/Icon-512.png')
      .writeAsBytesSync(_renderPng(512, shieldScale: 0.60));
  // Maskable icons need the artwork inside the safe zone: smaller shield
  // on a full-bleed background so no launcher mask clips it.
  File('web/icons/Icon-maskable-192.png')
      .writeAsBytesSync(_renderPng(192, shieldScale: 0.44, fullBleed: true));
  File('web/icons/Icon-maskable-512.png')
      .writeAsBytesSync(_renderPng(512, shieldScale: 0.44, fullBleed: true));
  File('web/favicon.png')
      .writeAsBytesSync(_renderPng(64, shieldScale: 0.62));
  stdout.writeln('wrote web/icons/*.png and web/favicon.png');
}

// ---------------------------------------------------------------- encoding
Uint8List _renderPng(
  int size, {
  double shieldScale = 0.60,
  bool fullBleed = false,
  bool transparent = false,
}) {
  final List<int> raw = <int>[];
  for (int y = 0; y < size; y++) {
    raw.add(0); // filter: none
    for (int x = 0; x < size; x++) {
      final int c = _pixel(x, y, size, shieldScale, fullBleed, transparent);
      raw.addAll(<int>[
        (c >> 16) & 0xFF,
        (c >> 8) & 0xFF,
        c & 0xFF,
        (c >> 24) & 0xFF,
      ]);
    }
  }

  final List<int> idat = ZLibEncoder().convert(raw);

  final BytesBuilder out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final ByteData len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final List<int> body = <int>[...type.codeUnits, ...data];
    out.add(body);
    final ByteData crc = ByteData(4)..setUint32(0, _crc32(body));
    out.add(crc.buffer.asUint8List());
  }

  out.add(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ByteData ihdr = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // color type: truecolor with alpha (RGBA)
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', idat);
  chunk('IEND', <int>[]);

  return out.toBytes();
}

// ------------------------------------------------------------------- art
int _pixel(
    int x, int y, int size, double shieldScale, bool fullBleed, bool transparent) {
  final double u = x / size; // 0..1
  final double v = y / size;
  final double cx = (u - 0.5) * 2; // -1..1
  final double cy = (v - 0.5) * 2;

  // Rounded-square background (skipped for maskable / full-bleed / adaptive).
  if (!fullBleed && !transparent && !_roundedSquare(cx, cy, 0.62)) {
    return 0x00000000;
  }
  if (transparent && !_roundedSquare(cx, cy, 0.62)) return 0x00000000;

  if (transparent) {
    // Transparent background; only the shield+keyhole are drawn.
    final double sx = cx;
    final double sy = cy + 0.02;
    final bool inShieldOuter = _shield(sx, sy, 0.62 * shieldScale);
    final bool inShieldInner = _shield(sx, sy, 0.50 * shieldScale);

    if (inShieldOuter && !inShieldInner) return 0xFFFFFFFF;
    if (inShieldInner) {
      final int face = 0xFF111C33;
      return _keyhole(sx, sy, shieldScale) ? 0xFFF8FAFC : face;
    }
    return 0x00000000;
  }

  // Violet → blue gradient (top-left to bottom-right).
  final int base = _lerpColor(0xFF7C3AED, 0xFF2563EB, (cx + cy + 2) / 4);

  // Shield outline.
  final double sx = cx;
  final double sy = cy + 0.02;
  final bool inShieldOuter = _shield(sx, sy, 0.62 * shieldScale);
  final bool inShieldInner = _shield(sx, sy, 0.50 * shieldScale);

  if (inShieldOuter && !inShieldInner) return _mix(base, 0xFFF8FAFC, 0.92);

  if (inShieldInner) {
    // Dark navy shield face.
    final int face = _lerpColor(0xFF111C33, 0xFF0A1222, (cy + 1) / 2);
    // Keyhole glyph: circle + widening stem, white.
    return _keyhole(sx, sy, shieldScale) ? 0xFFF8FAFC : face;
  }

  return base;
}

bool _keyhole(double x, double y, double shieldScale) {
  // Normalize against the INNER shield (same scale the face is drawn at),
  // so the glyph keeps its proportions on the smaller maskable variants.
  final double s = 0.50 * shieldScale;
  final double px = x / s;
  final double py = y / s;

  // Circle.
  final double dx = px;
  final double dy = py + 0.12;
  if (dx * dx + dy * dy <= 0.22 * 0.22) return true;

  // Stem: widens towards the bottom.
  if (py >= -0.04 && py <= 0.44) {
    final double halfWidth = 0.07 + (py + 0.04) * 0.38;
    return px.abs() <= halfWidth;
  }
  return false;
}

bool _roundedSquare(double x, double y, double r) {
  final double k = 1.0 - r;
  final double dx = x.abs() - k;
  final double dy = y.abs() - k;
  if (dx <= 0 || dy <= 0) return x.abs() <= 1 && y.abs() <= 1;
  return sqrt(dx * dx + dy * dy) <= r;
}

bool _shield(double x, double y, double scale) {
  // Shield: top edge flat, sides curve into a bottom point.
  final double px = x / scale;
  final double py = y / scale;
  if (py < -0.62 || py > 0.78) return false;
  if (py <= -0.30) {
    return px.abs() <= 0.86;
  }
  final double t = (py + 0.30) / 1.08; // 0 at shoulder, 1 at tip
  final double halfWidth = 0.86 - 0.86 * t * t;
  return px.abs() <= halfWidth;
}

// ------------------------------------------------------------------ util
int _lerpColor(int a, int b, double t) {
  t = t.clamp(0.0, 1.0);
  final int ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
  final int br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
  final int r = (ar + (br - ar) * t).round();
  final int g = (ag + (bg - ag) * t).round();
  final int bl = (ab + (bb - ab) * t).round();
  return 0xFF000000 | (r << 16) | (g << 8) | bl;
}

int _mix(int base, int over, double alpha) =>
    _lerpColor(base, over, alpha);

int _crc32(List<int> data) {
  const int poly = 0xEDB88320;
  final List<int> table = List<int>.generate(256, (int i) {
    int c = i;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) == 1 ? poly ^ (c >>> 1) : c >>> 1;
    }
    return c;
  });
  int crc = 0xFFFFFFFF;
  for (final int b in data) {
    crc = table[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
