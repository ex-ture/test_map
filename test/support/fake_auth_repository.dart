import 'package:test_map/repositories/firebase_auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Map<String, String>? accounts, String? loggedInEmail})
    : accounts = <String, String>{...?accounts},
      _loggedInEmail = loggedInEmail;

  final Map<String, String> accounts;
  String? _loggedInEmail;

  String? get loggedInEmail => _loggedInEmail;

  @override
  Future<AuthSession> fetchSession() async {
    return AuthSession(
      isLoggedIn: _loggedInEmail != null,
      loggedInEmail: _loggedInEmail,
    );
  }

  @override
  Future<void> registerAndLogin({
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = email.trim().toLowerCase();
    if (accounts.containsKey(normalizedEmail)) {
      throw const AuthRepositoryException(
        code: 'email-already-in-use',
        message: 'すでにアカウントが登録されています',
      );
    }

    accounts[normalizedEmail] = password;
    _loggedInEmail = normalizedEmail;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    final String normalizedEmail = email.trim().toLowerCase();
    if (accounts[normalizedEmail] != password) {
      throw const AuthRepositoryException(
        code: 'invalid-credential',
        message: 'メールアドレスまたはパスワードが違います',
      );
    }

    _loggedInEmail = normalizedEmail;
  }

  @override
  Future<void> logout() async {
    _loggedInEmail = null;
  }
}
