import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/models/place_suggestion.dart';
import 'package:test_map/pages/03_main_shell/main_shell.dart';
import 'package:test_map/repositories/place_history_repository.dart';
import 'package:test_map/repositories/place_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows home, map, and history tabs with home selected', (
    WidgetTester tester,
  ) async {
    int locationLoadCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          currentLocationLoader: () async {
            locationLoadCount++;
            return null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 0);
    expect(find.text('ホーム'), findsNWidgets(2));
    expect(find.text('マップ'), findsOneWidget);
    expect(find.text('履歴'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.text('まだ見たスポットはありません'), findsNothing);
    expect(find.text('マップを見る'), findsNothing);
    expect(locationLoadCount, 0);
  });

  testWidgets('switches to the map from the bottom navigation tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MainShell(currentLocationLoader: () async => null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('マップ'));
    await tester.pumpAndSettle();

    final NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);
    expect(find.text('現在地の取得に失敗しました'), findsOneWidget);
  });

  testWidgets('shows empty history on the history tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: MainShell(currentLocationLoader: () async => null)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();

    final NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 2);
    expect(find.text('履歴'), findsNWidgets(2));
    expect(find.text('まだ見たスポットはありません'), findsOneWidget);
    expect(find.text('マップを見る'), findsNothing);
  });

  testWidgets('shows the shared history cards on the history tab', (
    WidgetTester tester,
  ) async {
    final _MemoryPlaceHistoryRepository repository =
        _MemoryPlaceHistoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          historyRepository: repository,
          currentLocationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();

    expect(find.text(_MemoryPlaceHistoryRepository.place.name), findsOneWidget);
    expect(find.text('マップで開く'), findsOneWidget);
    expect(find.text('マップを見る'), findsNothing);
  });

  testWidgets('opens the map with the tapped history place', (
    WidgetTester tester,
  ) async {
    final _MemoryPlaceHistoryRepository historyRepository =
        _MemoryPlaceHistoryRepository();
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(
          historyRepository: historyRepository,
          mapRepository: placeRepository,
          currentLocationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('履歴'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'history-card-${_MemoryPlaceHistoryRepository.place.id}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final NavigationBar navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 1);
    final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.initialCameraPosition.target.latitude, 35.68);
    expect(map.initialCameraPosition.target.longitude, 139.76);
    expect(map.initialCameraPosition.zoom, 16);
    expect(map.markers.single.markerId, const MarkerId('shared-history-place'));
    expect(placeRepository.fetchCount, 0);
    expect(placeRepository.searchCount, 0);
  });
}

class _MemoryPlaceHistoryRepository extends PlaceHistoryRepository {
  static const Place place = Place(
    id: 'shared-history-place',
    name: '共通履歴のスポット',
    description: 'トップとホームで共有する履歴',
    latitude: 35.68,
    longitude: 139.76,
    webUrl: 'https://example.test/shared-history-place',
  );

  @override
  Future<List<Place>> fetchHistory() async => const <Place>[place];
}

class _RecordingPlaceRepository implements PlaceRepository {
  int fetchCount = 0;
  int searchCount = 0;

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int maxResultCount,
  }) async {
    fetchCount++;
    return const <Place>[];
  }

  @override
  Future<List<PlaceSuggestion>> fetchAutocompleteSuggestions({
    required String input,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    return const <PlaceSuggestion>[];
  }

  @override
  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  }) async {
    searchCount++;
    return const <Place>[];
  }
}
