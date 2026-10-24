import '../domain/account_model.dart';

/// Abstract store so the whole admin UI runs and is testable without the
/// Firebase project attached. The production implementation lives in
/// `firebase_accounts_repository.dart`.
abstract class AccountsRepository {
  /// All accounts, newest-created first.
  Future<List<AdminAccount>> loadAll();

  /// Writes (create or update) an account.
  Future<void> save(AdminAccount account);

  /// Deletes the account permanently.
  Future<void> delete(String username);
}

/// In-memory implementation used by unit tests.
class InMemoryAccountsRepository implements AccountsRepository {
  final Map<String, AdminAccount> _store = <String, AdminAccount>{};

  @override
  Future<List<AdminAccount>> loadAll() async =>
      _store.values.toList()
        ..sort((AdminAccount a, AdminAccount b) =>
            b.createdAtMs.compareTo(a.createdAtMs));

  @override
  Future<void> save(AdminAccount account) async {
    _store[account.username.toLowerCase()] = account;
  }

  @override
  Future<void> delete(String username) async {
    _store.remove(username.toLowerCase());
  }
}
