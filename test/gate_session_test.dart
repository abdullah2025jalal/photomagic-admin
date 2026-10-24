import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photomagic_admin/core/admin_security.dart';
import 'package:photomagic_admin/presentation/screens/master_gate_screen.dart';

/// Regression for the "انتهت الجلسة" bug: the gate used to clear
/// AdminSecurity.sessionKey in dispose(), which fires EXACTLY on a
/// successful unlock (AdminApp swaps gate -> accounts screen), wiping the
/// key the panel needs before the first save. dispose() must leave the
/// key alone.
void main() {
  testWidgets('gate dispose does NOT clear the session key',
      (WidgetTester tester) async {
    AdminSecurity.sessionKey = Uint8List.fromList(
      List<int>.generate(32, (int i) => i),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: MasterGateScreen(onUnlocked: () {})),
      ),
    );
    expect(AdminSecurity.sessionKey, isNotNull);

    // Unmount the gate (as AdminApp does on unlock) -> dispose() runs.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(
      AdminSecurity.sessionKey,
      isNotNull,
      reason: 'dispose() must not wipe the session key on unlock transition',
    );

    AdminSecurity.sessionKey = null; // test hygiene
  });
}
