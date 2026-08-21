import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/models/search_settings.dart';
import 'package:test_map/pages/04_map/widgets/map_filter_sheet.dart';

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    SearchSettings initialSettings = const SearchSettings(),
    required ValueChanged<SearchSettings> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapFilterSheet(
            initialSettings: initialSettings,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the existing labels, choices, and initial settings', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      initialSettings: const SearchSettings(
        radiusMeters: 3000,
        maxResultCount: 10,
        openNowOnly: true,
      ),
      onChanged: (_) {},
    );

    expect(find.text('検索条件'), findsOneWidget);
    expect(find.text('距離'), findsOneWidget);
    expect(find.text('件数'), findsOneWidget);
    expect(find.text('営業中のみ'), findsOneWidget);
    expect(find.text('500m'), findsOneWidget);
    expect(find.text('1km'), findsOneWidget);
    expect(find.text('3km'), findsOneWidget);
    expect(find.text('5km'), findsOneWidget);
    expect(find.text('10件'), findsOneWidget);
    expect(find.text('20件'), findsOneWidget);

    final List<SegmentedButton<int>> segmentedButtons = tester
        .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
        .toList();
    expect(segmentedButtons, hasLength(2));
    expect(segmentedButtons.first.selected, <int>{3000});
    expect(segmentedButtons.first.showSelectedIcon, isFalse);
    expect(segmentedButtons.last.selected, <int>{10});
    expect(segmentedButtons.last.showSelectedIcon, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('notifies radius changes while preserving the other settings', (
    WidgetTester tester,
  ) async {
    SearchSettings? notifiedSettings;
    await pumpSheet(
      tester,
      initialSettings: const SearchSettings(
        radiusMeters: 1000,
        maxResultCount: 10,
        openNowOnly: true,
      ),
      onChanged: (SearchSettings value) {
        notifiedSettings = value;
      },
    );

    await tester.tap(find.text('3km'));
    await tester.pump();

    expect(notifiedSettings?.radiusMeters, 3000);
    expect(notifiedSettings?.maxResultCount, 10);
    expect(notifiedSettings?.openNowOnly, isTrue);
  });

  testWidgets(
    'notifies maximum count changes while preserving the other settings',
    (WidgetTester tester) async {
      SearchSettings? notifiedSettings;
      await pumpSheet(
        tester,
        initialSettings: const SearchSettings(
          radiusMeters: 5000,
          maxResultCount: 20,
          openNowOnly: true,
        ),
        onChanged: (SearchSettings value) {
          notifiedSettings = value;
        },
      );

      await tester.tap(find.text('10件'));
      await tester.pump();

      expect(notifiedSettings?.radiusMeters, 5000);
      expect(notifiedSettings?.maxResultCount, 10);
      expect(notifiedSettings?.openNowOnly, isTrue);
    },
  );

  testWidgets('notifies open-now changes while preserving the other settings', (
    WidgetTester tester,
  ) async {
    SearchSettings? notifiedSettings;
    await pumpSheet(
      tester,
      initialSettings: const SearchSettings(
        radiusMeters: 3000,
        maxResultCount: 10,
      ),
      onChanged: (SearchSettings value) {
        notifiedSettings = value;
      },
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(notifiedSettings?.radiusMeters, 3000);
    expect(notifiedSettings?.maxResultCount, 10);
    expect(notifiedSettings?.openNowOnly, isTrue);
  });

  testWidgets('accumulates consecutive changes in notification order', (
    WidgetTester tester,
  ) async {
    final List<SearchSettings> notifications = <SearchSettings>[];
    await pumpSheet(tester, onChanged: notifications.add);

    await tester.tap(find.text('3km'));
    await tester.pump();
    await tester.tap(find.text('10件'));
    await tester.pump();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(notifications, hasLength(3));
    expect(notifications[0].radiusMeters, 3000);
    expect(notifications[0].maxResultCount, 20);
    expect(notifications[0].openNowOnly, isFalse);
    expect(notifications[1].radiusMeters, 3000);
    expect(notifications[1].maxResultCount, 10);
    expect(notifications[1].openNowOnly, isFalse);
    expect(notifications[2].radiusMeters, 3000);
    expect(notifications[2].maxResultCount, 10);
    expect(notifications[2].openNowOnly, isTrue);
  });

  testWidgets('does not notify when selected distance and count are tapped', (
    WidgetTester tester,
  ) async {
    final List<SearchSettings> notifications = <SearchSettings>[];
    await pumpSheet(tester, onChanged: notifications.add);

    await tester.tap(find.text('1km'));
    await tester.pump();
    await tester.tap(find.text('20件'));
    await tester.pump();

    expect(notifications, isEmpty);
  });
}
