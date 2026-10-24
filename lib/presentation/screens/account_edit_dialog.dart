import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/admin_security.dart';
import '../../domain/account_model.dart';
import '../../theme/admin_theme.dart';

/// Create (create mode) or edit (edit mode) one account.
///
/// * Type choice (دائمي / تجريبي) is shown BEFORE creation, per spec.
/// * Temporary accounts get an hh:mm:ss picker (hours : minutes : seconds)
///   with unlimited magnitude for hours.
/// * Editing may change username, password, type and duration.
class AccountEditDialog extends StatefulWidget {
  AccountEditDialog.create({super.key}) : existing = null;

  AccountEditDialog.edit(AdminAccount account, {super.key})
      : existing = account;

  final AdminAccount? existing;

  @override
  State<AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends State<AccountEditDialog> {
  late final TextEditingController _username;
  late final TextEditingController _password;
  late bool _permanent;
  late int _hours;
  late int _minutes;
  late int _seconds;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    final AdminAccount? a = widget.existing;
    _username = TextEditingController(text: a?.username ?? '');
    _password = TextEditingController(); // never pre-fill the hash source
    _permanent = a?.permanent ?? true;
    final int remaining = a == null || a.permanent
        ? 12 * 3600 * 1000
        : (a.expiryMs - DateTime.now().millisecondsSinceEpoch)
            .clamp(0, 1 << 40);
    _hours = remaining ~/ 3600000;
    _minutes = (remaining % 3600000) ~/ 60000;
    _seconds = (remaining % 60000) ~/ 1000;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isCreate => widget.existing == null;

  void _generatePassword() {
    setState(() => _password.text = AdminSecurity.newPassword());
  }

  AdminAccount? _buildAccount() {
    final String username = _username.text.trim().toLowerCase();
    setState(() {
      _usernameError =
          username.isEmpty ? 'اسم المستخدم مطلوب' : null;
    });
    if (username.isEmpty) return null;

    if (_isCreate && _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أدخل كلمة المرور أو اضغط توليد')),
      );
      return null;
    }

    final AdminAccount? existing = widget.existing;
    final Uint8List? _key = AdminSecurity.sessionKey;
    if (_key == null) {
      // Session key lost (process restart): refuse the save rather than
      // writing plaintext.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('انتهت الجلسة — أعد فتح اللوحة وحاول مجدداً')),
      );
      return null;
    }
    final String salt = existing?.salt ?? AdminSecurity.newSalt();
    final String passwordHash;
    final bool passwordChanged = _password.text.isNotEmpty;
    if (passwordChanged) {
      passwordHash = AdminSecurity.hash(salt, _password.text);
    } else if (existing != null) {
      // Editing without touching the password keeps the stored hash.
      passwordHash = existing.passwordHash;
    } else {
      return null;
    }

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int durationMs =
        _hours * 3600000 + _minutes * 60000 + _seconds * 1000;

    // Editing a temporary account restarts the countdown from NOW so the
    // owner can extend a trial precisely (spec: editable duration).
    final int expiryMs = _permanent
        ? 0
        : (_isCreate ? nowMs + durationMs : nowMs + durationMs);

    return AdminAccount(
      username: username,
      salt: salt,
      passwordHash: passwordHash,
      permanent: _permanent,
      expiryMs: expiryMs,
      createdAtMs: existing?.createdAtMs ?? nowMs,
      // Store the display password ENCRYPTED AT REST (master-key blob).
      // * Password changed -> seal the new one.
      // * Untouched -> re-seal the legacy plaintext on first edit, or keep
      //   the existing blob as-is.
      plainPassword: passwordChanged
          ? AdminSecurity.encryptAtRest(_password.text, _key!)
          : (existing?.plainPassword == null
              ? null
              : (AdminSecurity.isEncryptedAtRest(existing!.plainPassword!)
                  ? existing.plainPassword
                  : (AdminSecurity.sessionKey == null
                      ? existing.plainPassword
                      : AdminSecurity.encryptAtRest(
                          existing.plainPassword!, AdminSecurity.sessionKey!)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isCreate ? 'إنشاء حساب جديد' : 'تعديل الحساب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: _username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                errorText: _usernameError,
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _password,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: !_isCreate && _password.text.isEmpty,
              decoration: InputDecoration(
                labelText: _isCreate
                    ? 'كلمة المرور'
                    : 'كلمة مرور جديدة (اتركها فارغة للإبقاء)',
                suffixIcon: IconButton(
                  tooltip: 'توليد كلمة مرور',
                  icon: Icon(Icons.casino_outlined,
                      color: AdminPalette.cyan),
                  onPressed: _generatePassword,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('نوع الحساب:',
                style: TextStyle(color: AdminPalette.textDim, fontSize: 13)),
            SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                    value: true, label: Text('دائمي'), icon: Icon(Icons.all_inclusive)),
                ButtonSegment<bool>(
                    value: false,
                    label: Text('تجريبي (مؤقت)'),
                    icon: Icon(Icons.hourglass_top)),
              ],
              selected: <bool>{_permanent},
              onSelectionChanged: (Set<bool> s) =>
                  setState(() => _permanent = s.first),
            ),
            if (!_permanent) ...<Widget>[
              SizedBox(height: 14),
              Text('مدة الصلاحية (ساعات : دقائق : ثواني):',
                  style: TextStyle(color: AdminPalette.textDim, fontSize: 13)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _numField(_hours, 0, 1000000, (int v) => setState(() => _hours = v)),
                  _colon(),
                  _numField(_minutes, 0, 59, (int v) => setState(() => _minutes = v)),
                  _colon(),
                  _numField(_seconds, 0, 59, (int v) => setState(() => _seconds = v)),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final AdminAccount? account = _buildAccount();
            if (account != null) Navigator.of(context).pop(account);
          },
          child: Text(_isCreate ? 'إنشاء' : 'حفظ'),
        ),
      ],
    );
  }

  Widget _colon() => Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text(':',
            style: TextStyle(
                color: AdminPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
      );

  Widget _numField(int value, int min, int max, ValueChanged<int> onChanged) {
    final TextEditingController c =
        TextEditingController(text: value.toString());
    return SizedBox(
      width: 72,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 7,
        style: TextStyle(
            color: AdminPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800),
        decoration: InputDecoration(counterText: ''),
        onChanged: (String s) {
          final int? v = int.tryParse(s);
          if (v == null) return;
          onChanged(v.clamp(min, max));
        },
      ),
    );
  }
}