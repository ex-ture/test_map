import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/pages/04_map/widgets/map_search_bar.dart';

void main() {
  testWidgets('submits from the keyboard search action', (
    WidgetTester tester,
  ) async {
    int searchCount = 0;
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchBar(
            controller: controller,
            onClear: () {},
            onSearch: () {
              searchCount++;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'コンビニ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(searchCount, 1);
  });

  testWidgets('submits from the search icon', (WidgetTester tester) async {
    int searchCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchBar(
            onClear: () {},
            onSearch: () {
              searchCount++;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    expect(searchCount, 1);
  });

  testWidgets('shows progress and blocks submission while searching', (
    WidgetTester tester,
  ) async {
    int searchCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchBar(
            isSearching: true,
            onClear: () {},
            onSearch: () {
              searchCount++;
            },
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(searchCount, 0);
  });

  testWidgets('clears text and notifies the parent', (
    WidgetTester tester,
  ) async {
    int clearCount = 0;
    final TextEditingController controller = TextEditingController(
      text: 'コンビニ',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchBar(
            controller: controller,
            onSearch: () {},
            onClear: () {
              clearCount++;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(clearCount, 1);
  });

  testWidgets('notifies the parent when text changes', (
    WidgetTester tester,
  ) async {
    String? changedText;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapSearchBar(
            onSearch: () {},
            onClear: () {},
            onChanged: (String value) {
              changedText = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'コンビニ');

    expect(changedText, 'コンビニ');
  });
}
