// One-shot tool: prints the salted SHA-256 of the master password.
// Run with: dart run tool/hash_master.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() {
  const String salt = 'n5_admin_2026_static_salt_v1';
  const String password = 'jsatysa16%js';
  stdout.writeln(sha256.convert(utf8.encode(salt + password)).toString());
}
