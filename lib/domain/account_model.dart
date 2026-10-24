import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../core/admin_security.dart';

/// One customer account, mirroring the aligner app's
/// `UserAccount.fromRtdb` schema EXACTLY — both apps read and write the
/// same `/accounts/{username}` nodes:
///
/// ```
/// salt:        <hex32>     // random per account
/// hash:        <hex64>     // sha256(salt + password)
/// permanent:   bool
/// expiry_at:   <epoch ms>  // omitted for permanent accounts
/// created_at:  <epoch ms>
/// ```
@immutable
class AdminAccount {
  const AdminAccount({
    required this.username,
    required this.salt,
    required this.passwordHash,
    required this.permanent,
    required this.expiryMs,
    required this.createdAtMs,
    this.plainPassword,
    this.suspended = false,
    this.suspendedUntilMs = 0,
  });

  /// Canonical key: lower-cased, trimmed username.
  final String username;

  final String salt;
  final String passwordHash;

  /// Permanent = never deleted. Temporary = deleted by the global sweep
  /// once [expiryMs] passes (even 1 second after creation).
  final bool permanent;

  /// Epoch ms of death for temporary accounts; 0 for permanent ones.
  final int expiryMs;
  final int createdAtMs;

  /// The panel-display password, stored ENCRYPTED AT REST with a key
  /// derived from the owner's master password (`enc1$nonce$ct$tag` blob).
  /// A stolen database can no longer reveal customer passwords: without
  /// the master password the blob is computationally unrecoverable.
  ///
  /// Legacy plaintext values (pre-upgrade accounts) are detected by
  /// [displayPassword] and still render (migration happens on next edit).
  final String? plainPassword;

  /// The password to DISPLAY/COPY in the panel: decrypts the at-rest blob
  /// with the session key. Legacy plaintext values pass through unchanged
  /// (they will be re-encrypted on the next save through the dialog).
  /// Returns null when no password is stored or the key is unavailable.
  String? displayPassword() {
    final String? stored = plainPassword;
    if (stored == null || stored.isEmpty) return null;
    if (!AdminSecurity.isEncryptedAtRest(stored)) return stored;
    final Uint8List? key = AdminSecurity.sessionKey;
    if (key == null) return null;
    return AdminSecurity.decryptAtRest(stored, key);
  }

  /// True while the suspension is active (permanent or timed).
  bool isSuspendedAt(int nowMs) {
    if (!suspended) return false;
    if (suspendedUntilMs <= 0) return true;
    return nowMs < suspendedUntilMs;
  }

  /// Remaining suspension time formatted hh:mm:ss ('' when not timed).
  String suspensionRemainingFormatted(int nowMs) {
    if (suspendedUntilMs <= 0) return '';
    final int remaining = suspendedUntilMs - nowMs;
    if (remaining <= 0) return '';
    final int h = remaining ~/ 3600000;
    final int m = (remaining % 3600000) ~/ 60000;
    final int s = (remaining % 60000) ~/ 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  /// Admin suspension. `true` with [suspendedUntilMs] == 0 means permanent
  /// suspension; a future timestamp means suspended until that instant.
  final bool suspended;
  final int suspendedUntilMs;

  bool get isTemporary => !permanent;

  bool isExpiredAt(int nowMs) =>
      !permanent && expiryMs > 0 && nowMs >= expiryMs;

  /// Remaining lifetime, formatted hh:mm:ss (values beyond 999 h still
  /// render fully; the field accepts any magnitude).
  String remainingFormatted(int nowMs) {
    if (permanent) return '∞';
    final int remaining = expiryMs - nowMs;
    if (remaining <= 0) return '00:00:00';
    final int h = remaining ~/ 3600000;
    final int m = (remaining % 3600000) ~/ 60000;
    final int s = (remaining % 60000) ~/ 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  Map<String, Object> toRtdb() => <String, Object>{
        'salt': salt,
        'hash': passwordHash,
        'permanent': permanent,
        if (expiryMs > 0) 'expiry_at': expiryMs,
        'created_at': createdAtMs,
        if (plainPassword != null && plainPassword!.isNotEmpty)
          'pass': plainPassword!,
        if (suspended) 'suspended': true,
        if (suspendedUntilMs > 0) 'suspended_until': suspendedUntilMs,
      };

  static AdminAccount? fromRtdb(String key, Object? raw) {
    if (raw is! Map) return null;
    final Object? salt = raw['salt'];
    final Object? hash = raw['hash'];
    if (salt is! String || hash is! String) return null;
    final bool permanent = raw['permanent'] == true;
    return AdminAccount(
      username: key.toLowerCase(),
      salt: salt,
      passwordHash: hash,
      permanent: permanent,
      expiryMs: raw['expiry_at'] is num ? (raw['expiry_at'] as num).toInt() : 0,
      createdAtMs:
          raw['created_at'] is num ? (raw['created_at'] as num).toInt() : 0,
      plainPassword: raw['pass'] is String ? raw['pass'] as String : null,
      suspended: raw['suspended'] == true,
      suspendedUntilMs: raw['suspended_until'] is num
          ? (raw['suspended_until'] as num).toInt()
          : 0,
    );
  }

  AdminAccount copyWith({
    String? username,
    String? salt,
    String? passwordHash,
    bool? permanent,
    int? expiryMs,
    int? createdAtMs,
    String? plainPassword,
    bool clearPlainPassword = false,
    bool? suspended,
    int? suspendedUntilMs,
    bool clearSuspension = false,
  }) =>
      AdminAccount(
        username: (username ?? this.username).toLowerCase(),
        salt: salt ?? this.salt,
        passwordHash: passwordHash ?? this.passwordHash,
        permanent: permanent ?? this.permanent,
        expiryMs: expiryMs ?? this.expiryMs,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        plainPassword: clearPlainPassword
            ? null
            : (plainPassword ?? this.plainPassword),
        suspended:
            clearSuspension ? false : (suspended ?? this.suspended),
        suspendedUntilMs: clearSuspension
            ? 0
            : (suspendedUntilMs ?? this.suspendedUntilMs),
      );
}
