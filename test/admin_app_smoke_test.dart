import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photomagic_admin/presentation/admin_app.dart';

/// Regression guard for the blank-screen bug: building [AdminApp] outside a
/// [ProviderScope] throws at runtime (release builds render this as a blank
/// gray screen), while static analysis and unit tests cannot catch it.
void main() {
  testWidgets('AdminApp renders master gate inside ProviderScope',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AdminApp()));
    await tester.pump();

    // The unlock gate is the first screen; its title must be visible.
    expect(find.text('لوحة إدارة الحسابات'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
  });
}
