import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MockAuthSession {
  const MockAuthSession({
    required this.isLoggedIn,
    required this.loggedInEmail,
  });

  final bool isLoggedIn;
  final String? loggedInEmail;

  String get displayName {
    final String? email = loggedInEmail;
    if (!isLoggedIn || email == null || email.isEmpty) {
      return 'ゲスト';
    }

    return email.split('@').first;
  }
}

class MockAuthRepository {
  const MockAuthRepository();

  static const String registeredEmailKey = 'mock_auth_registered_email';
  static const String registeredPasswordKey = 'mock_auth_registered_password';
  static const String accountsKey = 'mock_auth_accounts';
  static const String isLoggedInKey = 'mock_auth_is_logged_in';
  static const String loggedInEmailKey = 'mock_auth_logged_in_email';

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Map<String, String> _readAccounts(SharedPreferences preferences) {
    final Map<String, String> accounts = <String, String>{};
    final String? accountsJson = preferences.getString(accountsKey);

    if (accountsJson != null && accountsJson.isNotEmpty) {
      try {
        final Object? decodedAccounts = jsonDecode(accountsJson);
        if (decodedAccounts is Map<String, dynamic>) {
          for (final MapEntry<String, dynamic> entry
              in decodedAccounts.entries) {
            final String email = _normalizeEmail(entry.key);
            final dynamic password = entry.value;
            if (email.isNotEmpty && password is String && password.isNotEmpty) {
              accounts[email] = password;
            }
          }
        }
      } on FormatException {
        // Ignore malformed local mock auth data and fall back to legacy keys.
      }
    }

    final String? legacyEmail = preferences.getString(registeredEmailKey);
    final String? legacyPassword = preferences.getString(registeredPasswordKey);
    if (legacyEmail != null &&
        legacyEmail.isNotEmpty &&
        legacyPassword != null &&
        legacyPassword.isNotEmpty) {
      accounts.putIfAbsent(_normalizeEmail(legacyEmail), () => legacyPassword);
    }

    return accounts;
  }

  Future<void> _writeAccounts(
    SharedPreferences preferences,
    Map<String, String> accounts,
  ) async {
    await preferences.setString(accountsKey, jsonEncode(accounts));
  }

  Future<MockAuthSession> fetchSession() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? loggedInEmail = preferences.getString(loggedInEmailKey);
    final bool isLoggedIn = preferences.getBool(isLoggedInKey) ?? false;

    return MockAuthSession(
      isLoggedIn:
          isLoggedIn && loggedInEmail != null && loggedInEmail.isNotEmpty,
      loggedInEmail: loggedInEmail,
    );
  }

  Future<bool> hasRegisteredAccount() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return _readAccounts(preferences).isNotEmpty;
  }

  Future<bool> isEmailRegistered({required String email}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return _readAccounts(preferences).containsKey(_normalizeEmail(email));
  }

  Future<void> registerAndLogin({
    required String email,
    required String password,
  }) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String normalizedEmail = _normalizeEmail(email);
    final Map<String, String> accounts = _readAccounts(preferences);
    accounts[normalizedEmail] = password;

    await _writeAccounts(preferences, accounts);
    await preferences.setString(registeredEmailKey, normalizedEmail);
    await preferences.setString(registeredPasswordKey, password);
    await preferences.setBool(isLoggedInKey, true);
    await preferences.setString(loggedInEmailKey, normalizedEmail);
  }

  Future<bool> login({required String email, required String password}) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String normalizedEmail = _normalizeEmail(email);
    final Map<String, String> accounts = _readAccounts(preferences);
    final String? registeredPassword = accounts[normalizedEmail];

    if (registeredPassword != password) {
      return false;
    }

    await preferences.setBool(isLoggedInKey, true);
    await preferences.setString(loggedInEmailKey, normalizedEmail);
    return true;
  }

  Future<void> logout() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(isLoggedInKey, false);
    await preferences.remove(loggedInEmailKey);
  }
}
