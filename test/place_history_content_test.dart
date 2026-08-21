import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/pages/02_top/widgets/place_history_content.dart';
import 'package:test_map/repositories/place_history_repository.dart';

void main() {
  testWidgets('shows the existing label and color for every opening state', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaceHistoryContent(
            historyRepository: _OpeningStateHistoryRepository(),
            onOpenPlace: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectStatus(tester, '営業中', const Color(0xFF167A3D));
    _expectStatus(tester, '営業時間外', const Color(0xFFB3261E));
    _expectStatus(tester, '営業時間不明', const Color(0xFF6B6B70));
  });
}

void _expectStatus(WidgetTester tester, String label, Color color) {
  final Text statusText = tester.widget<Text>(find.text(label));
  expect(statusText.style?.color, color);
}

class _OpeningStateHistoryRepository extends PlaceHistoryRepository {
  @override
  Future<List<Place>> fetchHistory() async {
    return const <Place>[
      Place(
        id: 'open',
        name: '営業中のスポット',
        description: '',
        latitude: 35.68,
        longitude: 139.76,
        webUrl: 'https://example.test/open',
        isOpenNow: true,
      ),
      Place(
        id: 'closed',
        name: '営業時間外のスポット',
        description: '',
        latitude: 35.69,
        longitude: 139.77,
        webUrl: 'https://example.test/closed',
        isOpenNow: false,
      ),
      Place(
        id: 'unknown',
        name: '営業時間不明のスポット',
        description: '',
        latitude: 35.70,
        longitude: 139.78,
        webUrl: 'https://example.test/unknown',
      ),
    ];
  }
}
