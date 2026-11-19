import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/repositories/firebase_auth_repository.dart';

void main() {
  test('maps Firebase Authentication errors to Japanese messages', () {
    const Map<String, String> expectedMessages = <String, String>{
      'email-already-in-use': 'すでにアカウントが登録されています',
      'invalid-email': 'メールアドレスの形式を確認してください',
      'weak-password': 'パスワードが弱すぎます。より安全なパスワードを入力してください',
      'user-not-found': 'メールアドレスまたはパスワードが違います',
      'wrong-password': 'メールアドレスまたはパスワードが違います',
      'invalid-credential': 'メールアドレスまたはパスワードが違います',
      'too-many-requests': '試行回数が多すぎます。しばらくしてからもう一度お試しください',
      'network-request-failed': 'ネットワーク接続を確認して、もう一度お試しください',
      'unknown-code': '認証処理に失敗しました。しばらくしてからもう一度お試しください',
    };

    for (final MapEntry<String, String> entry in expectedMessages.entries) {
      expect(AuthRepositoryException.messageForCode(entry.key), entry.value);
    }
  });
}
