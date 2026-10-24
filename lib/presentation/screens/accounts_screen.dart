import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../core/admin_security.dart';
import '../../data/firebase_accounts_repository.dart';
import '../../domain/account_model.dart';
import '../../theme/admin_theme.dart';
import 'account_edit_dialog.dart';
import 'suspend_dialog.dart';

/// First screen after the master gate: every account is listed here and
/// stays registered (permanent forever, temporary until it dies).
///
/// The list is LIVE — backed by Firebase RTDB `onValue` under `/accounts`,
/// so any write (this device or the Firebase console) appears instantly.
class AccountsScreen extends StatefulWidget {
  AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final FirebaseAccountsRepository _repo = FirebaseAccountsRepository();
  StreamSubscription<List<AdminAccount>>? _sub;
  StreamSubscription<bool>? _connSub;
  List<AdminAccount> _accounts = <AdminAccount>[];
  bool _loading = true;
  bool _connected = true;

  /// The offline banner does NOT appear the instant `.info/connected`
  /// drops: it waits a 5 s grace period after unlock so a slow-but-alive
  /// socket handshake right after login never flashes a false alarm.
  bool _showOfflineBanner = false;
  Timer? _offlineGrace;
  String? _error;
  Timer? _uiTicker;

  @override
  void initState() {
    super.initState();
    // 1 Hz ticker re-renders the remaining-time chips (locally, no reads).
    _uiTicker = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _subscribe();
    // Ground-truth internet monitor: RTDB `.info/connected`. While it is
    // false the banner shows "الجهاز غير متصل بالإنترنت"; the moment it
    // flips back to true, Firebase re-fires onValue by itself and the
    // account list refreshes automatically — no manual refresh needed.
    _connSub = _repo.connectionStream().listen((bool up) {
      if (!mounted) return;
      final bool wasConnected = _connected;
      if (up) {
        // Back online: cancel the pending grace timer and hide the banner.
        _offlineGrace?.cancel();
        _offlineGrace = null;
        setState(() {
          _connected = true;
          _showOfflineBanner = false;
        });
        // Belt & braces re-attach after long outages.
        if (!wasConnected) _subscribe();
      } else {
        setState(() => _connected = false);
        // Grace period: only show the banner if we stay offline 5 s.
        _offlineGrace?.cancel();
        _offlineGrace = Timer(const Duration(seconds: 5), () {
          if (!mounted || _connected) return;
          setState(() => _showOfflineBanner = true);
        });
      }
    });
    // NOTE: accounts are NEVER deleted automatically anymore — not
    // permanent ones and not expired trials. The ONLY deletion path is the
    // owner pressing the delete button. Expired trials stay listed with an
    // explicit "منتهي" (expired) badge until the owner removes them.
  }

  void _subscribe() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _sub?.cancel();
    _sub = _repo.watchAll().listen(
      (List<AdminAccount> accounts) {
        if (!mounted) return;
        setState(() {
          _accounts = accounts;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    _offlineGrace?.cancel();
    _sub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final AdminAccount? created = await showDialog<AdminAccount>(
      context: context,
      builder: (_) => AccountEditDialog.create(),
    );
    if (created != null) {
      await _repo.save(created);
      // The onValue stream refreshes the list automatically.
    }
  }

  Future<void> _openEditDialog(AdminAccount account) async {
    final AdminAccount? updated = await showDialog<AdminAccount>(
      context: context,
      builder: (_) => AccountEditDialog.edit(account),
    );
    if (updated != null) {
      // Rename-safe: remove the old key when the username changed.
      if (updated.username != account.username) {
        await _repo.delete(account.username);
      }
      await _repo.save(updated);
    }
  }

  /// Permanent or timed suspension. Timed suspensions lift automatically;
  /// permanent ones stay until the owner presses "تفعيل".
  Future<void> _suspendAccount(AdminAccount account) async {
    final SuspendChoice? choice = await showDialog<SuspendChoice>(
      context: context,
      builder: (_) => SuspendDialog(username: account.username),
    );
    if (choice == null) return;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final AdminAccount updated = choice.temporary
        ? account.copyWith(
            suspended: true,
            suspendedUntilMs: nowMs + choice.durationMs,
          )
        : account.copyWith(suspended: true, suspendedUntilMs: 0);
    await _repo.save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(choice.temporary
            ? 'تم إيقاف الحساب مؤقتاً'
            : 'تم إيقاف الحساب نهائياً'),
      ),
    );
  }

  /// Lifts any suspension (permanent or timed) immediately.
  Future<void> _activateAccount(AdminAccount account) async {
    await _repo
        .save(account.copyWith(clearSuspension: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تفعيل الحساب')),
    );
  }

  Future<void> _confirmDelete(AdminAccount account) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('حذف الحساب؟'),
        content: Text(
          'سيتم حذف الحساب "${account.username}" نهائياً ولن يستطيع صاحبه تسجيل الدخول.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminPalette.alarm),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _repo.delete(account.username);
    }
  }

  void _copyCredentials(AdminAccount account) {
    final String text = 'اسم المستخدم: ${account.username}\n'
        'كلمة المرور: ${account.displayPassword() ?? "(غير محفوظة)"}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ اسم المستخدم وكلمة المرور'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    return Scaffold(
      appBar: AppBar(
        title: Text('إدارة الحسابات'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            icon: Icon(Icons.refresh, color: AdminPalette.cyan),
            onPressed: _subscribe,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AdminPalette.cyan,
        foregroundColor: Colors.black,
        icon: Icon(Icons.person_add_alt),
        label: Text('إنشاء حساب',
            style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: _openCreateDialog,
      ),
      body: Column(
        children: <Widget>[
          // Only after the 5 s grace period — never during a normal,
          // fast handshake right after entering the master password.
          if (!_connected && _showOfflineBanner) _OfflineBanner(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _subscribe)
                    : _accounts.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد حسابات بعد.\nاضغط "إنشاء حساب" لإضافة أول زبون.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AdminPalette.textDim, height: 1.6),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 96),
                      itemCount: _accounts.length,
                      separatorBuilder: (_, _) => SizedBox(height: 10),
                      itemBuilder: (BuildContext ctx, int index) {
                        final AdminAccount a = _accounts[index];
                        return _AccountCard(
                          account: a,
                          nowMs: now,
                          onEdit: () => _openEditDialog(a),
                          onDelete: () => _confirmDelete(a),
                          onCopy: () => _copyCredentials(a),
                          onSuspend: () => _suspendAccount(a),
                          onActivate: () => _activateAccount(a),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

/// Shown whenever the RTDB socket is down: covers both the WiFi toggle
/// being off AND a router with no actual uplink (real reachability),
/// because `.info/connected` reflects the actual server connection.
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: AdminPalette.amber.withValues(alpha: 0.14),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off, color: AdminPalette.amber, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'الجهاز غير متصل بالإنترنت — سيتم عرض الحسابات تلقائياً عند عودة الاتصال',
              style: TextStyle(
                color: AdminPalette.amber,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off, color: AdminPalette.alarm, size: 44),
            SizedBox(height: 12),
            Text(
              'تعذّر الوصول إلى قاعدة البيانات',
              style: TextStyle(
                  color: AdminPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AdminPalette.textDim, fontSize: 12),
            ),
            SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text('إعادة المحاولة')),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  _AccountCard({
    required this.account,
    required this.nowMs,
    required this.onEdit,
    required this.onDelete,
    required this.onCopy,
    required this.onSuspend,
    required this.onActivate,
  });

  final AdminAccount account;
  final int nowMs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onSuspend;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final bool expired = account.isExpiredAt(nowMs);
    final bool suspended = account.isSuspendedAt(nowMs);
    final Color typeColor =
        account.permanent ? AdminPalette.phosphor : AdminPalette.amber;
    final Color stateColor = suspended
        ? AdminPalette.alarm
        : expired
            ? AdminPalette.alarm
            : typeColor;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPalette.glass,
        border: Border.all(color: stateColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            account.permanent ? Icons.verified_user_outlined : Icons.hourglass_top,
            color: stateColor,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Username: FULL horizontal display on its own row —
                // never truncated, never ellipsized, never wrapped. The
                // text renders at its natural width even if it overflows
                // the card, so the owner always reads the complete name.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.person_outline,
                          size: 15, color: AdminPalette.textDim),
                    ),
                    SizedBox(width: 5),
                    Text(
                      account.username,
                      softWrap: false,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        color: AdminPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(Icons.key_outlined,
                        size: 14, color: AdminPalette.textDim),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        account.displayPassword() ?? '(غير محفوظة)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: account.displayPassword() == null
                              ? AdminPalette.textDim
                              : AdminPalette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          fontStyle: account.displayPassword() == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    if (account.displayPassword() != null)
                      IconButton(
                        tooltip: 'نسخ كلمة المرور',
                        icon: Icon(Icons.copy,
                            size: 14, color: AdminPalette.textDim),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(
                              text: account.displayPassword() ?? ''));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم نسخ كلمة المرور'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (expired ? AdminPalette.alarm : typeColor)
                            .withValues(alpha: 0.15),
                        border: Border.all(
                            color:
                                expired ? AdminPalette.alarm : typeColor),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        suspended
                            ? (account.suspendedUntilMs > 0
                                ? 'موقوف مؤقتاً'
                                : 'موقوف دائم')
                            : expired
                                ? 'منتهي'
                                : account.permanent
                                    ? 'دائمي'
                                    : 'تجريبي ${account.remainingFormatted(nowMs)}',
                        style: TextStyle(
                          color:
                              suspended ? AdminPalette.alarm : typeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
              ],
            ),
          ),
          IconButton(
            tooltip: 'نسخ بيانات الدخول',
            icon: Icon(Icons.copy, size: 18, color: AdminPalette.textDim),
            onPressed: onCopy,
          ),
          IconButton(
            tooltip: 'إيقاف الحساب',
            icon: Icon(Icons.pause_circle_outline,
                size: 20, color: AdminPalette.amber),
            onPressed: onSuspend,
          ),
          IconButton(
            tooltip: 'تفعيل الحساب (إلغاء الإيقاف)',
            icon: Icon(Icons.play_circle_outline,
                size: 20, color: AdminPalette.phosphor),
            onPressed: onActivate,
          ),
          IconButton(
            tooltip: 'تعديل',
            icon: Icon(Icons.edit, size: 18, color: AdminPalette.cyan),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline,
                size: 18, color: AdminPalette.alarm),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Convenience accessor used by the dialog when generating a password.
String generatePassword() => AdminSecurity.newPassword();