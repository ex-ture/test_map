import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/repositories/place_history_repository.dart';

void main() {
  const PlaceHistoryRepository repository = PlaceHistoryRepository();
  const Place firstPlace = Place(
    id: 'first',
    name: 'First Place',
    description: 'First description',
    latitude: 35.68,
    longitude: 139.76,
    webUrl: 'https://example.test/first',
    isOpenNow: true,
  );
  const Place secondPlace = Place(
    id: 'second',
    name: 'Second Place',
    description: 'Second description',
    latitude: 35.69,
    longitude: 139.77,
    webUrl: 'https://example.test/second',
    isOpenNow: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists places with every existing Place field', () async {
    await repository.add(firstPlace);

    final List<Place> history = await const PlaceHistoryRepository()
        .fetchHistory();

    expect(history, hasLength(1));
    expect(history.single.id, firstPlace.id);
    expect(history.single.name, firstPlace.name);
    expect(history.single.description, firstPlace.description);
    expect(history.single.latitude, firstPlace.latitude);
    expect(history.single.longitude, firstPlace.longitude);
    expect(history.single.webUrl, 'https://example.com');
    expect(history.single.isOpenNow, firstPlace.isOpenNow);
  });

  test('keeps the newest viewed place first', () async {
    await repository.add(firstPlace);
    await repository.add(secondPlace);

    final List<Place> history = await repository.fetchHistory();

    expect(history.map((Place place) => place.id), <String>['second', 'first']);
  });

  test(
    'replaces a previously saved real URL with the placeholder URL',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'place_view_history': <String>[
          '{"id":"legacy","name":"Legacy","description":"Old",'
              '"latitude":35.68,"longitude":139.76,'
              '"webUrl":"https://real-store.example/path","isOpenNow":true}',
        ],
      });

      final List<Place> history = await repository.fetchHistory();

      expect(history.single.webUrl, 'https://example.com');
    },
  );

  test('moves an existing place to the top without duplicating it', () async {
    await repository.add(firstPlace);
    await repository.add(secondPlace);
    await repository.add(
      const Place(
        id: 'first',
        name: 'First Place Updated',
        description: 'Updated description',
        latitude: 35.70,
        longitude: 139.78,
        webUrl: 'https://example.test/first-updated',
      ),
    );

    final List<Place> history = await repository.fetchHistory();

    expect(history, hasLength(2));
    expect(history.map((Place place) => place.id), <String>['first', 'second']);
    expect(history.first.name, 'First Place Updated');
  });

  test('keeps at most 20 places and removes the oldest place', () async {
    for (int index = 0; index < 21; index++) {
      await repository.add(_placeForIndex(index));
    }

    final List<Place> history = await const PlaceHistoryRepository()
        .fetchHistory();

    expect(history, hasLength(20));
    expect(history.first.id, 'place-20');
    expect(history.last.id, 'place-1');
    expect(history.any((Place place) => place.id == 'place-0'), isFalse);
  });

  test(
    'keeps 20 unique places when an existing place is viewed again',
    () async {
      for (int index = 0; index < 20; index++) {
        await repository.add(_placeForIndex(index));
      }

      await repository.add(_placeForIndex(5, name: 'Updated Place 5'));

      final List<Place> history = await repository.fetchHistory();

      expect(history, hasLength(20));
      expect(history.first.id, 'place-5');
      expect(history.first.name, 'Updated Place 5');
      expect(
        history.where((Place place) => place.id == 'place-5'),
        hasLength(1),
      );
    },
  );
}

Place _placeForIndex(int index, {String? name}) {
  return Place(
    id: 'place-$index',
    name: name ?? 'Place $index',
    description: 'Description $index',
    latitude: 35 + index / 100,
    longitude: 139 + index / 100,
    webUrl: 'https://example.test/place-$index',
    isOpenNow: index.isEven,
  );
}
