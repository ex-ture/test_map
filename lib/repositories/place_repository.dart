import '../models/place.dart';
import '../models/place_suggestion.dart';

abstract class PlaceRepository {
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int maxResultCount,
  });

  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  });

  Future<List<PlaceSuggestion>> fetchAutocompleteSuggestions({
    required String input,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  });
}
