import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/main.dart';
import 'package:test_map/pages/00_root/root_page.dart';
import 'package:test_map/repositories/mock_auth_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('starts on the tutorial on first launch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.title, 'スポットマップ');
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('場所を検索'), findsOneWidget);
    expect(find.text('スキップ'), findsOneWidget);
    expect(find.text('閲覧履歴'), findsNothing);
    expect(find.text('マップを見る'), findsNothing);
  });

  testWidgets('completing the tutorial opens the main shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ホーム'), findsNWidgets(2));
    expect(find.text('履歴'), findsOneWidget);
    expect(find.text('場所を検索'), findsNothing);

    final SharedPreferences preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(tutorialCompletedPreferenceKey), isTrue);
  });

  testWidgets('starts on the main shell after tutorial completion', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      tutorialCompletedPreferenceKey: true,
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ホーム'), findsNWidgets(2));
    expect(find.text('場所を見つけよう'), findsOneWidget);
    expect(find.text('場所を検索'), findsNothing);
    expect(find.text('スキップ'), findsNothing);
  });

  testWidgets('restores login state after tutorial completion', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      tutorialCompletedPreferenceKey: true,
      MockAuthRepository.registeredEmailKey: 'sample@example.com',
      MockAuthRepository.registeredPasswordKey: '1234',
      MockAuthRepository.isLoggedInKey: true,
      MockAuthRepository.loggedInEmailKey: 'sample@example.com',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('ログイン中'), findsOneWidget);
    expect(find.text('sample'), findsNWidgets(2));
    expect(find.text('ログイン'), findsNothing);
    expect(find.text('新規登録'), findsNothing);
  });
}
