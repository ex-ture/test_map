import '../models/place.dart';
import '../models/place_suggestion.dart';
import 'place_repository.dart';

class DummyPlaceRepository implements PlaceRepository {
  static const List<Place> _dummyPlaces = [
    Place(
      id: 'spot-a',
      name: 'Spot A',
      description: '東京駅周辺スポット',
      latitude: 35.681236,
      longitude: 139.767125,
      webUrl: 'https://example.com/spot-a',
    ),
    Place(
      id: 'spot-b',
      name: 'Spot B',
      description: '有楽町周辺スポット',
      latitude: 35.675069,
      longitude: 139.763328,
      webUrl: 'https://example.com/spot-b',
    ),
    Place(
      id: 'spot-c',
      name: 'Spot C',
      description: '銀座周辺スポット',
      latitude: 35.6717,
      longitude: 139.7650,
      webUrl: 'https://example.com/spot-c',
    ),
    Place(
      id: 'spot-d',
      name: 'Spot D',
      description: '日本橋周辺スポット',
      latitude: 35.6830,
      longitude: 139.7742,
      webUrl: 'https://example.com/spot-d',
    ),
    Place(
      id: 'spot-e',
      name: 'Spot E',
      description: '丸の内周辺スポット',
      latitude: 35.6804,
      longitude: 139.7690,
      webUrl: 'https://example.com/spot-e',
    ),
  ];

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int maxResultCount,
  }) async {
    return _dummyPlaces.take(maxResultCount).toList();
  }

  @override
  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  }) async {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const <Place>[];
    }

    return _dummyPlaces
        .where(
          (Place place) =>
              place.name.toLowerCase().contains(normalizedQuery) ||
              place.description.toLowerCase().contains(normalizedQuery),
        )
        .take(maxResultCount)
        .toList();
  }

  @override
  Future<List<PlaceSuggestion>> fetchAutocompleteSuggestions({
    required String input,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final String normalizedInput = input.trim().toLowerCase();
    if (normalizedInput.isEmpty) {
      return const <PlaceSuggestion>[];
    }

    return _dummyPlaces
        .where(
          (Place place) =>
              place.name.toLowerCase().contains(normalizedInput) ||
              place.description.toLowerCase().contains(normalizedInput),
        )
        .map(
          (Place place) => PlaceSuggestion(
            text: place.name,
            type: PlaceSuggestionType.place,
            placeId: place.id,
          ),
        )
        .toList();
  }
}
