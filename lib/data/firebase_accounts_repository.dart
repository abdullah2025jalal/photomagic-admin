import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../domain/account_model.dart';
import 'accounts_repository.dart';

/// Firebase Realtime Database-backed account store (the real backend).
///
/// Node schema (identical to the aligner app's `UserAccount` contract):
/// ```
/// /accounts/{username}
///   salt:        <hex32>     // random per account
///   hash:        <hex64>     // sha256(salt + password)
///   permanent:   bool
///   expiry_at:   <epoch ms>  // omitted for permanent accounts
///   created_at:  <epoch ms>
/// ```
///
/// This admin app OWNS the store: it creates, edits and deletes accounts
/// (including the global expiry sweep). The aligner app only reads.
class FirebaseAccountsRepository implements AccountsRepository {
  FirebaseAccountsRepository({FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  /// Canonical key: lower-cased, trimmed username.
  static String canonicalKey(String username) =>
      username.trim().toLowerCase();

  @override
  Future<List<AdminAccount>> loadAll() async {
    final DataSnapshot snap = await _db.ref('accounts').get();
    if (!snap.exists) return <AdminAccount>[];
    final Object? value = snap.value;
    if (value is! Map) return <AdminAccount>[];
    final List<AdminAccount> accounts = <AdminAccount>[];
    value.forEach((Object? key, Object? raw) {
      final AdminAccount? account =
          AdminAccount.fromRtdb(key.toString(), raw);
      if (account != null) accounts.add(account);
    });
    // Newest-created first, mirroring the in-memory implementation.
    accounts.sort((AdminAccount a, AdminAccount b) =>
        b.createdAtMs.compareTo(a.createdAtMs));
    return accounts;
  }

  @override
  Future<void> save(AdminAccount account) async {
    await _db
        .ref('accounts/${canonicalKey(account.username)}')
        .set(account.toRtdb());
  }

  @override
  Future<void> delete(String username) async {
    await _db.ref('accounts/${canonicalKey(username)}').remove();
  }

  /// Live RTDB socket state (`.info/connected`): true only when this
  /// device actually holds an open connection to the database server —
  /// the ground truth for the "الجهاز غير متصل بالإنترنت" banner. When
  /// the connection returns, Firebase re-fires `onValue` with the current
  /// data automatically, so the list refreshes with no user action.
  Stream<bool> connectionStream() =>
      _db.ref('.info/connected').onValue.map(
            (DatabaseEvent event) => event.snapshot.value == true,
          );

  /// Subscribes to any change under `/accounts` — the live list for the UI.
  /// Errors (offline, permission) are surfaced through [onError] instead of
  /// killing the stream.
  Stream<List<AdminAccount>> watchAll() {
    final StreamController<List<AdminAccount>> controller =
        StreamController<List<AdminAccount>>.broadcast();
    final StreamSubscription<DatabaseEvent> sub = _db
        .ref('accounts')
        .onValue
        .listen((DatabaseEvent event) {
      final Object? value = event.snapshot.value;
      final List<AdminAccount> accounts = <AdminAccount>[];
      if (value is Map) {
        value.forEach((Object? key, Object? raw) {
          final AdminAccount? account =
              AdminAccount.fromRtdb(key.toString(), raw);
          if (account != null) accounts.add(account);
        });
        accounts.sort((AdminAccount a, AdminAccount b) =>
            b.createdAtMs.compareTo(a.createdAtMs));
      }
      controller.add(accounts);
    }, onError: (Object e) {
      debugPrint('watchAll error: $e');
      controller.addError(e);
    });
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }
}
