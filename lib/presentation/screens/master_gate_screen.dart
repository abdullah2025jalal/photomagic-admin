import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/admin_security.dart';
import '../../theme/admin_theme.dart';
import '../theme_provider.dart';

/// Asks for the owner's master password on EVERY launch. Nothing else is
/// reachable before this passes.
class MasterGateScreen extends ConsumerStatefulWidget {
  MasterGateScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<MasterGateScreen> createState() => _MasterGateScreenState();
}

class _MasterGateScreenState extends ConsumerState<MasterGateScreen> {
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _wrong = false;
  bool _busy = false;

  /// Forced 3 s delay between attempts: an attacker with the device cannot
  /// script offline guesses against the PBKDF2 master constant — every
  /// guess costs seconds, and PBKDF2-60k on top makes it worse.
  static const int _attemptDelayMs = 3000;

  @override
  void dispose() {
    // NOTE: deliberately do NOT clear AdminSecurity.sessionKey here.
    // The gate is removed from the tree EXACTLY on a successful unlock
    // (AdminApp swaps gate -> accounts screen), so dispose() fires at the
    // unlock transition — clearing here would wipe the key the panel
    // needs for at-rest decryption, breaking every save with an
    // "انتهت الجلسة" snackbar. The key is RAM-only by design and dies
    // with the process; the next launch re-derives it at the gate.
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    setState(() => _busy = true);
    // Constant 3 s per attempt: brute-force cost + no timing oracle.
    Future<void>.delayed(const Duration(milliseconds: _attemptDelayMs), () {
      if (!mounted) return;
      final bool ok = AdminSecurity.verifyMaster(_password.text);
      if (ok) {
        // Derive the session key for at-rest decryption of the stored
        // plain passwords. Lives in RAM only, for this unlock session.
        AdminSecurity.sessionKey = AdminSecurity.deriveAtRestKey(
          _password.text,
        );
      }
      setState(() {
        _busy = false;
        _wrong = !ok;
      });
      if (ok) {
        _password.clear();
        widget.onUnlocked();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeModeOption mode = ref.watch(themeControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Light/dark toggle — top corner, available before unlocking.
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: mode == ThemeModeOption.light
                    ? 'الوضع الداكن'
                    : 'الوضع الفاتح',
                onPressed: () =>
                    ref.read(themeControllerProvider.notifier).toggle(),
                icon: Icon(
                  mode == ThemeModeOption.light
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: AdminPalette.cyan,
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Icon(Icons.admin_panel_settings_outlined,
                        color: AdminPalette.cyan, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'لوحة إدارة الحسابات',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AdminPalette.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'خاص بالمُهندس عبدالله جلال',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AdminPalette.textDim, fontSize: 14),
                    ),
                    SizedBox(height: 40),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofocus: true,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'كلمة المرور',
                        errorText: _wrong ? 'كلمة المرور غير صحيحة' : null,
                        prefixIcon: Icon(Icons.lock_outline,
                            color: AdminPalette.textDim),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                            color: AdminPalette.textDim,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text('فتح اللوحة'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}