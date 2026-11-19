import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  const AuthSession({required this.isLoggedIn, required this.loggedInEmail});

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

abstract interface class AuthRepository {
  Future<AuthSession> fetchSession();

  Future<void> registerAndLogin({
    required String email,
    required String password,
  });

  Future<void> login({required String email, required String password});

  Future<void> logout();
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException({required this.code, required this.message});

  factory AuthRepositoryException.fromFirebase(
    FirebaseAuthException exception,
  ) {
    return AuthRepositoryException(
      code: exception.code,
      message: messageForCode(exception.code),
    );
  }

  factory AuthRepositoryException.unknown() {
    return const AuthRepositoryException(
      code: 'unknown',
      message: '認証処理に失敗しました。しばらくしてからもう一度お試しください',
    );
  }

  final String code;
  final String message;

  static String messageForCode(String code) {
    return switch (code) {
      'email-already-in-use' => 'すでにアカウントが登録されています',
      'invalid-email' => 'メールアドレスの形式を確認してください',
      'weak-password' => 'パスワードが弱すぎます。より安全なパスワードを入力してください',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'メールアドレスまたはパスワードが違います',
      'too-many-requests' => '試行回数が多すぎます。しばらくしてからもう一度お試しください',
      'network-request-failed' => 'ネットワーク接続を確認して、もう一度お試しください',
      _ => '認証処理に失敗しました。しばらくしてからもう一度お試しください',
    };
  }

  @override
  String toString() => 'AuthRepositoryException($code): $message';
}

class FirebaseAuthRepository implements AuthRepository {
  const FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth;

  final FirebaseAuth? _firebaseAuth;

  FirebaseAuth get _auth => _firebaseAuth ?? FirebaseAuth.instance;

  static const List<String> _legacyPreferenceKeys = <String>[
    'mock_auth_registered_email',
    'mock_auth_registered_password',
    'mock_auth_accounts',
    'mock_auth_is_logged_in',
    'mock_auth_logged_in_email',
  ];

  Future<void> _removeLegacyAuthData() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    for (final String key in _legacyPreferenceKeys) {
      await preferences.remove(key);
    }
  }

  @override
  Future<AuthSession> fetchSession() async {
    await _removeLegacyAuthData();
    final User? user = _auth.currentUser;
    return AuthSession(isLoggedIn: user != null, loggedInEmail: user?.email);
  }

  @override
  Future<void> registerAndLogin({
    required String email,
    required String password,
  }) async {
    await _removeLegacyAuthData();
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (exception) {
      throw AuthRepositoryException.fromFirebase(exception);
    } catch (_) {
      throw AuthRepositoryException.unknown();
    }
  }

  @override
  Future<void> login({required String email, required String password}) async {
    await _removeLegacyAuthData();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (exception) {
      throw AuthRepositoryException.fromFirebase(exception);
    } catch (_) {
      throw AuthRepositoryException.unknown();
    }
  }

  @override
  Future<void> logout() async {
    await _removeLegacyAuthData();
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (exception) {
      throw AuthRepositoryException.fromFirebase(exception);
    } catch (_) {
      throw AuthRepositoryException.unknown();
    }
  }
}
