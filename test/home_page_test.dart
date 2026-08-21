import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/pages/03_main_shell/home_page.dart';
import 'package:test_map/repositories/mock_auth_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpHomePage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pumpAndSettle();
  }

  Future<void> openRegisterSheet(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-register-button')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLoginSheet(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-login-button')),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterEmailAndPassword(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey<String>('mock-auth-email-field')),
      email,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('mock-auth-password-field')),
      password,
    );
  }

  Future<void> enterRegisterForm(
    WidgetTester tester, {
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    await enterEmailAndPassword(tester, email: email, password: password);
    await tester.enterText(
      find.byKey(
        const ValueKey<String>('mock-auth-password-confirmation-field'),
      ),
      passwordConfirmation,
    );
  }

  testWidgets('shows guest while logged out', (WidgetTester tester) async {
    await pumpHomePage(tester);

    expect(find.text('ゲスト'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mock-auth-status-badge')),
      findsOneWidget,
    );
    expect(find.text('場所を見つけよう'), findsOneWidget);
    expect(find.text('検索した場所や閲覧履歴を、この端末で確認できます。'), findsOneWidget);
    expect(find.text('ログイン'), findsOneWidget);
    expect(find.text('新規登録'), findsOneWidget);
    expect(find.text('ログアウト'), findsNothing);

    final Size scaffoldSize = tester.getSize(find.byType(Scaffold));
    final Size loginButtonSize = tester.getSize(
      find.byKey(const ValueKey<String>('mock-auth-login-button')),
    );
    final Size registerButtonSize = tester.getSize(
      find.byKey(const ValueKey<String>('mock-auth-register-button')),
    );
    expect(loginButtonSize.width, lessThan(scaffoldSize.width));
    expect(loginButtonSize.width, lessThanOrEqualTo(scaffoldSize.width * 0.8));
    expect(registerButtonSize.width, loginButtonSize.width);
  });

  testWidgets('uses email input settings', (WidgetTester tester) async {
    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    final TextField emailField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('mock-auth-email-field')),
    );
    expect(emailField.keyboardType, TextInputType.emailAddress);
    expect(emailField.textCapitalization, TextCapitalization.none);
    expect(
      find.byKey(const ValueKey<String>('mock-auth-close-button')),
      findsOneWidget,
    );
    expect(find.text('すでにアカウントをお持ちの方は'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mock-auth-switch-login-button')),
      findsOneWidget,
    );
  });

  testWidgets('shows multiple registration errors near each input', (
    WidgetTester tester,
  ) async {
    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    await enterRegisterForm(
      tester,
      email: 'sample.example.com',
      password: '123',
      passwordConfirmation: '456',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-register-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスの形式を確認してください'), findsOneWidget);
    expect(find.text('パスワードは4文字以上で入力してください'), findsOneWidget);
    expect(find.text('パスワードが一致しません'), findsOneWidget);
  });

  testWidgets('registers and logs in the local mock account', (
    WidgetTester tester,
  ) async {
    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    await enterRegisterForm(
      tester,
      email: 'sample@example.com',
      password: '1234',
      passwordConfirmation: '1234',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-register-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ログイン中'), findsOneWidget);
    expect(find.text('sample'), findsNWidgets(2));
    expect(find.text('このアカウントで引き続き周辺の場所を探せます。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mock-auth-login-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('mock-auth-register-button')),
      findsNothing,
    );
    expect(find.text('ログアウト'), findsOneWidget);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(MockAuthRepository.registeredEmailKey),
      'sample@example.com',
    );
    expect(
      preferences.getString(MockAuthRepository.registeredPasswordKey),
      '1234',
    );
    expect(preferences.getBool(MockAuthRepository.isLoggedInKey), isTrue);
    expect(
      preferences.getString(MockAuthRepository.loggedInEmailKey),
      'sample@example.com',
    );
  });

  testWidgets('prevents registering an existing email account', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
    });

    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    await enterRegisterForm(
      tester,
      email: 'sample@example.com',
      password: '5678',
      passwordConfirmation: '5678',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-register-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('すでにアカウントが登録されています'), findsOneWidget);
  });

  testWidgets('registers another email and keeps both accounts loginable', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
    });

    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    await enterRegisterForm(
      tester,
      email: 'other@example.com',
      password: '5678',
      passwordConfirmation: '5678',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-register-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ログイン中'), findsOneWidget);
    expect(find.text('other'), findsNWidgets(2));

    const MockAuthRepository repository = MockAuthRepository();
    await repository.logout();
    expect(
      await repository.login(email: 'sample@example.com', password: '1234'),
      isTrue,
    );
    await repository.logout();
    expect(
      await repository.login(email: 'other@example.com', password: '5678'),
      isTrue,
    );
  });

  testWidgets('rejects login with a wrong password', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
    });

    await pumpHomePage(tester);
    await openLoginSheet(tester);

    expect(find.text('アカウントをお持ちでない方は'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('mock-auth-switch-register-button')),
      findsOneWidget,
    );

    await enterEmailAndPassword(
      tester,
      email: 'sample@example.com',
      password: 'wrong',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-login-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスまたはパスワードが違います'), findsOneWidget);
    expect(find.text('ゲスト'), findsOneWidget);
  });

  testWidgets('toggles password visibility in login and registration sheets', (
    WidgetTester tester,
  ) async {
    await pumpHomePage(tester);
    await openLoginSheet(tester);

    TextField passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('mock-auth-password-field')),
    );
    expect(passwordField.obscureText, isTrue);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('mock-auth-password-visibility-button'),
      ),
    );
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('mock-auth-password-field')),
    );
    expect(passwordField.obscureText, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpHomePage(tester);
    await openRegisterSheet(tester);

    passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('mock-auth-password-field')),
    );
    TextField passwordConfirmationField = tester.widget<TextField>(
      find.byKey(
        const ValueKey<String>('mock-auth-password-confirmation-field'),
      ),
    );
    expect(passwordField.obscureText, isTrue);
    expect(passwordConfirmationField.obscureText, isTrue);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('mock-auth-password-visibility-button'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'mock-auth-password-confirmation-visibility-button',
        ),
      ),
    );
    await tester.pumpAndSettle();

    passwordField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('mock-auth-password-field')),
    );
    passwordConfirmationField = tester.widget<TextField>(
      find.byKey(
        const ValueKey<String>('mock-auth-password-confirmation-field'),
      ),
    );
    expect(passwordField.obscureText, isFalse);
    expect(passwordConfirmationField.obscureText, isFalse);
  });

  testWidgets('logs out without deleting the registered account', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
      MockAuthRepository.isLoggedInKey: true,
      MockAuthRepository.loggedInEmailKey: 'sample@example.com',
    });

    await pumpHomePage(tester);

    expect(find.text('sample'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('mock-auth-login-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('mock-auth-register-button')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('mock-auth-logout-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ゲスト'), findsOneWidget);
    expect(find.text('ログアウト'), findsNothing);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(MockAuthRepository.registeredEmailKey),
      'sample@example.com',
    );
    expect(
      preferences.getString(MockAuthRepository.registeredPasswordKey),
      '1234',
    );
    expect(preferences.getBool(MockAuthRepository.isLoggedInKey), isFalse);
    expect(preferences.getString(MockAuthRepository.loggedInEmailKey), isNull);
  });

  testWidgets('keeps the login state after rebuilding the app', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
      MockAuthRepository.isLoggedInKey: true,
      MockAuthRepository.loggedInEmailKey: 'sample@example.com',
    });

    await pumpHomePage(tester);
    expect(find.text('sample'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpHomePage(tester);

    expect(find.text('sample'), findsNWidgets(2));
    expect(find.text('ゲスト'), findsNothing);
  });
}
