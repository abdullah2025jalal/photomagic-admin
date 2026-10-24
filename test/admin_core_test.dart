import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:photomagic_admin/core/admin_security.dart';
import 'package:photomagic_admin/data/accounts_repository.dart';
import 'package:photomagic_admin/domain/account_model.dart';

void main() {
  group('AdminSecurity', () {
    test('master password gate accepts the owner password', () {
      expect(AdminSecurity.verifyMaster('jsatysa16%js'), isTrue);
    });

    test('master gate rejects wrong passwords', () {
      expect(AdminSecurity.verifyMaster(''), isFalse);
      expect(AdminSecurity.verifyMaster('jsatysa16'), isFalse);
      expect(AdminSecurity.verifyMaster('Jsatysa16%js'), isFalse);
      expect(AdminSecurity.verifyMaster('jsatysa16%js '), isFalse);
    });

    test('account hashing produces the v2 PBKDF2 contract format', () {
      final String salt = AdminSecurity.newSalt();
      final String hash = AdminSecurity.hash(salt, 'Passw0rd');
      // v2 self-describing: v2$iter$salt$digest (aligner app contract).
      expect(hash, startsWith('v2\$100000\$$salt\$'));
      expect(AdminSecurity.hash(salt, 'Passw0rd'), hash);
      expect(AdminSecurity.hash(salt, 'passw0rd'), isNot(hash));
    });

    test('verifyAccount accepts legacy sha256 and upgrades to v2', () {
      final String salt = AdminSecurity.newSalt();
      final String legacy = AdminSecurity.legacyHash(salt, 'OldPass1');
      final ({bool ok, String? upgraded}) verdict =
          AdminSecurity.verifyAccount(salt, 'OldPass1', legacy);
      expect(verdict.ok, isTrue);
      expect(verdict.upgraded, isNotNull);
      expect(verdict.upgraded, startsWith('v2\$'));
      // The upgraded hash verifies directly under v2.
      expect(
        AdminSecurity.verifyAccount(salt, 'OldPass1', verdict.upgraded!).ok,
        isTrue,
      );
      // Wrong password never upgrades.
      expect(
        AdminSecurity.verifyAccount(salt, 'nope', legacy).upgraded,
        isNull,
      );
    });

    test('at-rest encryption round-trips and is tamper-evident', () {
      final Uint8List key = AdminSecurity.deriveAtRestKey('master-pw');
      final String blob = AdminSecurity.encryptAtRest('S3cret-42', key);

      // Format + no plaintext leakage.
      expect(blob, startsWith('enc1\$'));
      expect(blob.contains('S3cret'), isFalse);

      // Round-trip.
      expect(AdminSecurity.decryptAtRest(blob, key), 'S3cret-42');

      // Unique nonce per call.
      expect(AdminSecurity.encryptAtRest('S3cret-42', key), isNot(blob));

      // Tampered ciphertext or wrong key -> null, never garbage.
      final List<String> parts = blob.split('\$');
      final String flipped =
          '${parts[0]}\$${parts[1]}\$ff${parts[2].substring(2)}\$${parts[3]}';
      expect(AdminSecurity.decryptAtRest(flipped, key), isNull);
      expect(
        AdminSecurity.decryptAtRest(blob, AdminSecurity.deriveAtRestKey('x')),
        isNull,
      );
    });
  });

  group('AdminAccount schema', () {
    test('matches the aligner UserAccount node exactly', () {
      final AdminAccount a = AdminAccount(
        username: 'mustafa',
        salt: 'aa11',
        passwordHash: 'bb22',
        permanent: false,
        expiryMs: 5000,
        createdAtMs: 1000,
      );
      final Map<String, Object> node = a.toRtdb();
      // Keys shared with the login app's UserAccount.toRtdb:
      expect(node.keys, containsAll(<String>['salt', 'hash', 'permanent']));
      expect(node['expiry_at'], 5000);
      expect(node['created_at'], 1000);

      // And its parser accepts the login app's nodes (subset is fine).
      final Map<String, Object> loginNode = <String, Object>{
        'salt': 's',
        'hash': 'h',
        'permanent': true,
        'created_at': 42,
      };
      final AdminAccount? parsed = AdminAccount.fromRtdb('ALI', loginNode);
      expect(parsed, isNotNull);
      expect(parsed!.username, 'ali');
      expect(parsed.permanent, isTrue);
      expect(parsed.expiryMs, 0);
    });

    test('expiry edge: even one second means deletion', () {
      final AdminAccount a = AdminAccount(
        username: 'trial',
        salt: 's',
        passwordHash: 'h',
        permanent: false,
        expiryMs: 1000,
        createdAtMs: 0,
      );
      expect(a.isExpiredAt(999), isFalse);
      expect(a.isExpiredAt(1000), isTrue);
      // 400 ms remaining -> shows 00:00:00 but is NOT yet deleted:
      expect(a.remainingFormatted(400), '00:00:00');
      expect(a.isExpiredAt(400), isFalse);
      // Exactly one second left:
      expect(a.remainingFormatted(0), '00:00:01');
    });

    test('huge durations render correctly (million hours)', () {
      final AdminAccount a = AdminAccount(
        username: 'long',
        salt: 's',
        passwordHash: 'h',
        permanent: false,
        expiryMs: 1000000 * 3600000,
        createdAtMs: 0,
      );
      expect(a.remainingFormatted(0), startsWith('1000000:00:00'));
    });
  });

  group('InMemoryAccountsRepository', () {
    test('save / loadAll / delete round-trip, newest first', () async {
      final InMemoryAccountsRepository repo = InMemoryAccountsRepository();
      final AdminAccount old = AdminAccount(
          username: 'old', salt: 's', passwordHash: 'h',
          permanent: true, expiryMs: 0, createdAtMs: 1);
      final AdminAccount recent = AdminAccount(
          username: 'new', salt: 's', passwordHash: 'h',
          permanent: true, expiryMs: 0, createdAtMs: 2);
      await repo.save(old);
      await repo.save(recent);

      final List<AdminAccount> all = await repo.loadAll();
      expect(all.length, 2);
      expect(all.first.username, 'new');

      await repo.delete('OLD'); // case-insensitive canonical key
      expect((await repo.loadAll()).length, 1);
    });
  });
}
