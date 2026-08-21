import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/models/place.dart';
import 'package:test_map/pages/04_map/map_camera_bounds.dart';

void main() {
  test('returns null for no places', () {
    expect(buildBoundsForPlaces(const <Place>[]), isNull);
  });

  test('uses the same coordinate for a single place', () {
    final bounds = buildBoundsForPlaces(const <Place>[
      Place(
        id: 'single',
        name: 'Single',
        description: '',
        latitude: 35.681236,
        longitude: 139.767125,
        webUrl: 'https://example.test',
      ),
    ]);

    expect(bounds, isNotNull);
    expect(bounds!.southwest.latitude, 35.681236);
    expect(bounds.southwest.longitude, 139.767125);
    expect(bounds.northeast.latitude, 35.681236);
    expect(bounds.northeast.longitude, 139.767125);
  });

  test('contains every search result coordinate', () {
    final bounds = buildBoundsForPlaces(const <Place>[
      Place(
        id: 'north-west',
        name: 'North West',
        description: '',
        latitude: 35.70,
        longitude: 139.70,
        webUrl: 'https://example.test/north-west',
      ),
      Place(
        id: 'south-east',
        name: 'South East',
        description: '',
        latitude: 35.60,
        longitude: 139.80,
        webUrl: 'https://example.test/south-east',
      ),
      Place(
        id: 'center',
        name: 'Center',
        description: '',
        latitude: 35.65,
        longitude: 139.75,
        webUrl: 'https://example.test/center',
      ),
    ]);

    expect(bounds, isNotNull);
    expect(bounds!.southwest.latitude, 35.60);
    expect(bounds.southwest.longitude, 139.70);
    expect(bounds.northeast.latitude, 35.70);
    expect(bounds.northeast.longitude, 139.80);
  });
}
