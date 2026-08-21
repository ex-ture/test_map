import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/models/place_suggestion.dart';
import 'package:test_map/models/search_settings.dart';
import 'package:test_map/pages/04_map/map_page.dart';
import 'package:test_map/pages/04_map/widgets/map_filter_sheet.dart';
import 'package:test_map/pages/04_map/widgets/map_search_bar.dart';
import 'package:test_map/pages/04_map/widgets/place_bottom_sheet.dart';
import 'package:test_map/repositories/place_history_repository.dart';
import 'package:test_map/repositories/place_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const Place initialPlace = Place(
    id: 'history-place',
    name: '履歴のスポット',
    description: '保存済みの説明',
    latitude: 35.6815,
    longitude: 139.7674,
    webUrl: 'https://example.test/history-place',
    isOpenNow: true,
  );

  late GoogleMapsFlutterPlatform originalPlatform;
  late _FakeGoogleMapsFlutterPlatform fakePlatform;

  setUp(() {
    originalPlatform = GoogleMapsFlutterPlatform.instance;
    fakePlatform = _FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakePlatform;
  });

  tearDown(() {
    GoogleMapsFlutterPlatform.instance = originalPlatform;
  });

  testWidgets(
    'restores an initial history place without calling a places API',
    (WidgetTester tester) async {
      final _RecordingPlaceRepository placeRepository =
          _RecordingPlaceRepository();
      final _RecordingHistoryRepository historyRepository =
          _RecordingHistoryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            initialPlace: initialPlace,
            repository: placeRepository,
            historyRepository: historyRepository,
            currentLocationLoader: () async => const LatLng(35.68, 139.76),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.initialCameraPosition.target.latitude, initialPlace.latitude);
      expect(
        map.initialCameraPosition.target.longitude,
        initialPlace.longitude,
      );
      expect(map.initialCameraPosition.zoom, 16);
      expect(map.markers, hasLength(1));
      expect(map.markers.single.markerId, const MarkerId('history-place'));
      expect(find.byType(PlaceBottomSheet), findsOneWidget);
      expect(find.text(initialPlace.name), findsOneWidget);
      final TextField searchField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(searchField.controller?.text, isEmpty);
      expect(placeRepository.fetchCount, 0);
      expect(placeRepository.searchCount, 0);
      expect(historyRepository.addedPlaces, <Place>[initialPlace]);
      expect(fakePlatform.animateCameraCount, 1);
    },
  );

  testWidgets('keeps the history place on settings changes and clears it', (
    WidgetTester tester,
  ) async {
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository();

    Widget buildPage(SearchSettings settings) {
      return MaterialApp(
        home: MapPage(
          initialPlace: initialPlace,
          searchSettings: settings,
          repository: placeRepository,
          historyRepository: _RecordingHistoryRepository(),
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      );
    }

    await tester.pumpWidget(buildPage(const SearchSettings()));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(PlaceBottomSheet))).pop();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      buildPage(const SearchSettings(radiusMeters: 3000, maxResultCount: 10)),
    );
    await tester.pumpAndSettle();

    GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(1));
    expect(placeRepository.searchCount, 0);

    await tester.tap(find.byTooltip('クリア'));
    await tester.pumpAndSettle();

    map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, isEmpty);
    expect(placeRepository.fetchCount, 0);
    expect(placeRepository.searchCount, 0);
  });

  testWidgets(
    'debounces autocomplete and searches after selecting a suggestion',
    (WidgetTester tester) async {
      final _RecordingPlaceRepository placeRepository =
          _RecordingPlaceRepository()
            ..autocompleteSuggestions = const <PlaceSuggestion>[
              PlaceSuggestion(
                text: 'コンビニ 神田店',
                type: PlaceSuggestionType.place,
                placeId: 'place-id-1',
              ),
            ];

      await tester.pumpWidget(
        MaterialApp(
          home: MapPage(
            repository: placeRepository,
            currentLocationLoader: () async => const LatLng(35.68, 139.76),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'コン');
      await tester.pump(const Duration(milliseconds: 399));

      expect(placeRepository.autocompleteCount, 0);
      expect(placeRepository.searchCount, 0);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(placeRepository.autocompleteCount, 1);
      expect(placeRepository.searchCount, 0);
      expect(find.text('コンビニ 神田店'), findsOneWidget);

      await tester.tap(find.text('コンビニ 神田店'));
      await tester.pumpAndSettle();

      expect(placeRepository.searchCount, 1);
      expect(placeRepository.lastSearchQuery, 'コンビニ 神田店');
      expect(
        find.byKey(const ValueKey<String>('place-suggestion-0')),
        findsNothing,
      );
    },
  );

  testWidgets('clears autocomplete suggestions without running text search', (
    WidgetTester tester,
  ) async {
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository()
          ..autocompleteSuggestions = const <PlaceSuggestion>[
            PlaceSuggestion(text: '病院 東京駅前', type: PlaceSuggestionType.place),
          ];

    await tester.pumpWidget(
      MaterialApp(
        home: MapPage(
          repository: placeRepository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '病院');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('病院 東京駅前'), findsOneWidget);

    await tester.tap(find.byTooltip('クリア'));
    await tester.pump();

    expect(find.text('病院 東京駅前'), findsNothing);
    expect(placeRepository.searchCount, 0);
  });

  testWidgets('closes autocomplete suggestions when the map becomes inactive', (
    WidgetTester tester,
  ) async {
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository()
          ..autocompleteSuggestions = const <PlaceSuggestion>[
            PlaceSuggestion(text: 'ジム 東京駅前', type: PlaceSuggestionType.place),
          ];
    final ValueNotifier<bool> isActive = ValueNotifier<bool>(true);
    addTearDown(isActive.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: isActive,
          builder: (BuildContext context, bool value, Widget? child) {
            return MapPage(
              isActive: value,
              repository: placeRepository,
              currentLocationLoader: () async => const LatLng(35.68, 139.76),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ジム');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('ジム 東京駅前'), findsOneWidget);

    isActive.value = false;
    await tester.pumpAndSettle();

    expect(find.text('ジム 東京駅前'), findsNothing);
    expect(placeRepository.searchCount, 0);
  });

  testWidgets('closes autocomplete suggestions when the map is tapped', (
    WidgetTester tester,
  ) async {
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository()
          ..autocompleteSuggestions = const <PlaceSuggestion>[
            PlaceSuggestion(text: '病院 大手町', type: PlaceSuggestionType.place),
          ];

    await tester.pumpWidget(
      MaterialApp(
        home: MapPage(
          repository: placeRepository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '病院');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('病院 大手町'), findsOneWidget);

    final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    map.onTap?.call(const LatLng(35.68, 139.76));
    await tester.pump();

    expect(find.text('病院 大手町'), findsNothing);
    expect(placeRepository.searchCount, 0);
  });

  testWidgets('restores a history place when a new open request is received', (
    WidgetTester tester,
  ) async {
    final _RecordingPlaceRepository placeRepository =
        _RecordingPlaceRepository();
    final _RecordingHistoryRepository historyRepository =
        _RecordingHistoryRepository();
    final ValueNotifier<int> requestId = ValueNotifier<int>(0);
    addTearDown(requestId.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: requestId,
          builder: (BuildContext context, int value, Widget? child) {
            return MapPage(
              initialPlace: value == 0 ? null : initialPlace,
              initialPlaceRequestId: value,
              repository: placeRepository,
              historyRepository: historyRepository,
              currentLocationLoader: () async => const LatLng(35.68, 139.76),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    requestId.value = 1;
    await tester.pumpAndSettle();

    GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers.single.markerId, const MarkerId('history-place'));
    expect(find.byType(PlaceBottomSheet), findsOneWidget);
    expect(placeRepository.fetchCount, 0);
    expect(placeRepository.searchCount, 0);

    Navigator.of(tester.element(find.byType(PlaceBottomSheet))).pop();
    await tester.pumpAndSettle();
    requestId.value = 2;
    await tester.pumpAndSettle();

    map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, hasLength(1));
    expect(find.byType(PlaceBottomSheet), findsOneWidget);
    expect(historyRepository.addedPlaces, <Place>[initialPlace, initialPlace]);
    expect(placeRepository.fetchCount, 0);
    expect(placeRepository.searchCount, 0);
  });

  testWidgets(
    'replaces an in-flight search when the radius changes and ignores the old result',
    (WidgetTester tester) async {
      final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
      SearchSettings settings = const SearchSettings();

      Widget buildPage() => MaterialApp(
        home: MapPage(
          searchSettings: settings,
          repository: repository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'カフェ');
      await tester.tap(find.byTooltip('検索'));
      await tester.pump();

      expect(repository.searches, hasLength(1));
      expect(repository.searches.first.radiusMeters, 1000);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      settings = settings.copyWith(radiusMeters: 3000);
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(repository.searches, hasLength(2));
      expect(repository.searches.last.query, 'カフェ');
      expect(repository.searches.last.radiusMeters, 3000);
      final int cameraCountBeforeResponses = fakePlatform.animateCameraCount;

      repository.searches.first.completer.complete(const <Place>[
        Place(
          id: 'old-radius-result',
          name: '古い範囲の結果',
          description: '',
          latitude: 35.69,
          longitude: 139.77,
          webUrl: 'https://example.test/old',
        ),
      ]);
      await tester.pump();

      GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(fakePlatform.animateCameraCount, cameraCountBeforeResponses);

      repository.searches.last.completer.complete(const <Place>[
        Place(
          id: 'new-radius-result',
          name: '新しい範囲の結果',
          description: '',
          latitude: 35.70,
          longitude: 139.78,
          webUrl: 'https://example.test/new',
        ),
      ]);
      await tester.pumpAndSettle();

      map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.markerId, const MarkerId('new-radius-result'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fakePlatform.animateCameraCount, cameraCountBeforeResponses + 1);
    },
  );

  testWidgets(
    'restarts an in-flight search with the new maximum result count',
    (WidgetTester tester) async {
      final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
      SearchSettings settings = const SearchSettings(maxResultCount: 20);

      Widget buildPage() => MaterialApp(
        home: MapPage(
          searchSettings: settings,
          repository: repository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '病院');
      await tester.tap(find.byTooltip('検索'));
      await tester.pump();

      settings = settings.copyWith(maxResultCount: 10);
      await tester.pumpWidget(buildPage());
      await tester.pump();

      expect(repository.searches, hasLength(2));
      expect(repository.searches.first.maxResultCount, 20);
      expect(repository.searches.last.maxResultCount, 10);

      repository.searches.last.completer.complete(const <Place>[]);
      await tester.pump();
      repository.searches.first.completer.complete(const <Place>[]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('ignores empty results and errors from stale searches', (
    WidgetTester tester,
  ) async {
    final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
    SearchSettings settings = const SearchSettings();

    Widget buildPage() => MaterialApp(
      home: MapPage(
        searchSettings: settings,
        repository: repository,
        currentLocationLoader: () async => const LatLng(35.68, 139.76),
      ),
    );

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '公園');
    await tester.tap(find.byTooltip('検索'));
    await tester.pump();

    settings = settings.copyWith(radiusMeters: 3000);
    await tester.pumpWidget(buildPage());
    await tester.pump();
    repository.searches.first.completer.complete(const <Place>[]);
    await tester.pump();

    expect(find.text('検索結果が見つかりませんでした'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    settings = settings.copyWith(maxResultCount: 10);
    await tester.pumpWidget(buildPage());
    await tester.pump();
    repository.searches[1].completer.completeError(
      StateError('stale search failed'),
    );
    await tester.pump();

    expect(find.text('検索に失敗しました'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.searches.last.completer.complete(const <Place>[
      Place(
        id: 'latest-result',
        name: '最新の結果',
        description: '',
        latitude: 35.70,
        longitude: 139.78,
        webUrl: 'https://example.test/latest',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers.single.markerId, const MarkerId('latest-result'));
  });

  testWidgets(
    'history restoration invalidates an in-flight search and remains authoritative',
    (WidgetTester tester) async {
      final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
      SearchSettings settings = const SearchSettings();
      Place? restoredPlace;
      int requestId = 0;
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return MapPage(
                searchSettings: settings,
                initialPlace: restoredPlace,
                initialPlaceRequestId: requestId,
                repository: repository,
                historyRepository: _RecordingHistoryRepository(),
                currentLocationLoader: () async => const LatLng(35.68, 139.76),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'レストラン');
      await tester.tap(find.byTooltip('検索'));
      await tester.pump();

      setHostState(() {
        restoredPlace = initialPlace;
        requestId = 1;
      });
      await tester.pumpAndSettle();

      GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.markerId, const MarkerId('history-place'));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(PlaceBottomSheet), findsOneWidget);
      final int cameraCountAfterRestoration = fakePlatform.animateCameraCount;

      setHostState(() {
        settings = settings.copyWith(radiusMeters: 3000);
      });
      await tester.pump();
      expect(repository.searches, hasLength(1));

      repository.searches.single.completer.complete(const <Place>[
        Place(
          id: 'stale-after-history',
          name: '古い検索結果',
          description: '',
          latitude: 35.71,
          longitude: 139.79,
          webUrl: 'https://example.test/stale',
        ),
      ]);
      await tester.pumpAndSettle();

      map = tester.widget<GoogleMap>(find.byType(GoogleMap));
      expect(map.markers.single.markerId, const MarkerId('history-place'));
      expect(fakePlatform.animateCameraCount, cameraCountAfterRestoration);
      expect(find.text('検索結果が見つかりませんでした'), findsNothing);
      expect(find.text('検索に失敗しました'), findsNothing);
    },
  );

  testWidgets('clear invalidates an in-flight text search', (
    WidgetTester tester,
  ) async {
    final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MapPage(
          repository: repository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '図書館');
    await tester.tap(find.byTooltip('検索'));
    await tester.pump();

    final TextEditingController searchController = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    searchController.clear();
    tester.widget<MapSearchBar>(find.byType(MapSearchBar)).onClear();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );

    repository.searches.single.completer.complete(const <Place>[
      Place(
        id: 'stale-after-clear',
        name: '古い検索結果',
        description: '',
        latitude: 35.71,
        longitude: 139.79,
        webUrl: 'https://example.test/stale',
      ),
    ]);
    await tester.pumpAndSettle();

    final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(map.markers, isEmpty);
  });

  testWidgets('keeps an in-flight search when the map becomes inactive', (
    WidgetTester tester,
  ) async {
    final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
    final ValueNotifier<bool> isActive = ValueNotifier<bool>(true);
    addTearDown(isActive.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: isActive,
          builder: (BuildContext context, bool value, Widget? child) {
            return MapPage(
              isActive: value,
              repository: repository,
              currentLocationLoader: () async => const LatLng(35.68, 139.76),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'スーパー');
    await tester.tap(find.byTooltip('検索'));
    await tester.pump();

    isActive.value = false;
    await tester.pump();
    expect(repository.searches, hasLength(1));

    repository.searches.single.completer.complete(const <Place>[
      Place(
        id: 'completed-on-another-tab',
        name: '別タブ中に完了した結果',
        description: '',
        latitude: 35.71,
        longitude: 139.79,
        webUrl: 'https://example.test/completed',
      ),
    ]);
    await tester.pumpAndSettle();

    isActive.value = true;
    await tester.pump();
    final GoogleMap map = tester.widget<GoogleMap>(find.byType(GoogleMap));
    expect(
      map.markers.single.markerId,
      const MarkerId('completed-on-another-tab'),
    );
  });

  testWidgets(
    'keeps normal double submission blocked and does not search for open-now changes',
    (WidgetTester tester) async {
      final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
      SearchSettings settings = const SearchSettings();

      Widget buildPage() => MaterialApp(
        home: MapPage(
          searchSettings: settings,
          repository: repository,
          currentLocationLoader: () async => const LatLng(35.68, 139.76),
        ),
      );

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '薬局');
      await tester.tap(find.byTooltip('検索'));
      await tester.pump();

      final TextField searchField = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(searchField.readOnly, isTrue);
      searchField.onSubmitted?.call('別の検索語');
      await tester.pump();
      expect(repository.searches, hasLength(1));

      settings = settings.copyWith(openNowOnly: true);
      await tester.pumpWidget(buildPage());
      await tester.pump();
      expect(repository.searches, hasLength(1));

      repository.searches.single.completer.complete(const <Place>[
        Place(
          id: 'open-pharmacy',
          name: '営業中の薬局',
          description: '',
          latitude: 35.71,
          longitude: 139.79,
          webUrl: 'https://example.test/pharmacy',
          isOpenNow: true,
        ),
      ]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'opens the filter sheet, forwards changes, and reopens with parent settings',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final _DelayedPlaceRepository repository = _DelayedPlaceRepository();
      final List<SearchSettings> notifications = <SearchSettings>[];
      SearchSettings settings = const SearchSettings();
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return MapPage(
                searchSettings: settings,
                repository: repository,
                currentLocationLoader: () async => const LatLng(35.68, 139.76),
                onSettingsChanged: (SearchSettings value) {
                  notifications.add(value);
                  setHostState(() {
                    settings = value;
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'カフェ');
      await tester.tap(find.byTooltip('検索'));
      await tester.pump();
      expect(repository.searches, hasLength(1));

      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MapFilterSheet), findsOneWidget);

      await tester.tap(find.text('3km'));
      await tester.pump();
      expect(notifications.last.radiusMeters, 3000);
      expect(repository.searches, hasLength(2));
      expect(repository.searches.last.radiusMeters, 3000);

      await tester.tap(find.text('10件'));
      await tester.pump();
      expect(notifications.last.maxResultCount, 10);
      expect(repository.searches, hasLength(3));
      expect(repository.searches.last.maxResultCount, 10);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(notifications.last.openNowOnly, isTrue);
      expect(repository.searches, hasLength(3));

      Navigator.of(tester.element(find.byType(MapFilterSheet))).pop();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final List<SegmentedButton<int>> segmentedButtons = tester
          .widgetList<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
          .toList();
      expect(segmentedButtons.first.selected, <int>{3000});
      expect(segmentedButtons.last.selected, <int>{10});
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      Navigator.of(tester.element(find.byType(MapFilterSheet))).pop();
      await tester.pump();
      repository.searches.last.completer.complete(const <Place>[]);
      repository.searches[0].completer.complete(const <Place>[]);
      repository.searches[1].completer.complete(const <Place>[]);
      await tester.pumpAndSettle();
    },
  );
}

class _RecordingPlaceRepository implements PlaceRepository {
  int fetchCount = 0;
  int searchCount = 0;
  int autocompleteCount = 0;
  String? lastSearchQuery;
  List<PlaceSuggestion> autocompleteSuggestions = const <PlaceSuggestion>[];

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
  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  }) async {
    searchCount++;
    lastSearchQuery = query;
    return const <Place>[];
  }

  @override
  Future<List<PlaceSuggestion>> fetchAutocompleteSuggestions({
    required String input,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    autocompleteCount++;
    return autocompleteSuggestions;
  }
}

class _RecordingHistoryRepository extends PlaceHistoryRepository {
  final List<Place> addedPlaces = <Place>[];

  @override
  Future<void> add(Place place) async {
    addedPlaces.add(place);
  }
}

class _DelayedPlaceRepository implements PlaceRepository {
  final List<_PendingSearch> searches = <_PendingSearch>[];

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int maxResultCount,
  }) async {
    return const <Place>[];
  }

  @override
  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  }) {
    final _PendingSearch search = _PendingSearch(
      query: query,
      radiusMeters: radiusMeters,
      maxResultCount: maxResultCount,
    );
    searches.add(search);
    return search.completer.future;
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
}

class _PendingSearch {
  _PendingSearch({
    required this.query,
    required this.radiusMeters,
    required this.maxResultCount,
  });

  final String query;
  final double radiusMeters;
  final int maxResultCount;
  final Completer<List<Place>> completer = Completer<List<Place>>();
}

class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  int animateCameraCount = 0;
  final Set<int> _createdIds = <int>{};

  @override
  Future<void> init(int mapId) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    if (_createdIds.add(creationId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onPlatformViewCreated(creationId);
      });
    }
    return const ColoredBox(color: Colors.white);
  }

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    animateCameraCount++;
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) {
    return const Stream<MarkerTapEvent>.empty();
  }

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) {
    return const Stream<MarkerDragStartEvent>.empty();
  }

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) {
    return const Stream<MarkerDragEvent>.empty();
  }

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) {
    return const Stream<MarkerDragEndEvent>.empty();
  }

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) {
    return const Stream<InfoWindowTapEvent>.empty();
  }

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) {
    return const Stream<PolylineTapEvent>.empty();
  }

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) {
    return const Stream<PolygonTapEvent>.empty();
  }

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) {
    return const Stream<CircleTapEvent>.empty();
  }

  @override
  Stream<MapTapEvent> onTap({required int mapId}) {
    return const Stream<MapTapEvent>.empty();
  }

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) {
    return const Stream<MapLongPressEvent>.empty();
  }

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) {
    return const Stream<ClusterTapEvent>.empty();
  }

  @override
  void dispose({required int mapId}) {}
}
