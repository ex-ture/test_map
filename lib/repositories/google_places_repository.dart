import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../constants/place_urls.dart';
import '../models/place.dart';
import '../models/place_suggestion.dart';
import 'place_repository.dart';

class GooglePlacesRepository implements PlaceRepository {
  GooglePlacesRepository({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? const String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  final http.Client _client;
  final String _apiKey;

  static const String _nearbySearchEndpoint =
      'https://places.googleapis.com/v1/places:searchNearby';
  static const String _textSearchEndpoint =
      'https://places.googleapis.com/v1/places:searchText';
  static const String _autocompleteEndpoint =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const String _fieldMask =
      'places.id,places.displayName,places.formattedAddress,places.location,'
      'places.currentOpeningHours';
  static const String _autocompleteFieldMask =
      'suggestions.placePrediction.placeId,'
      'suggestions.placePrediction.text.text,'
      'suggestions.queryPrediction.text.text';

  @override
  Future<List<Place>> fetchPlaces({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int maxResultCount,
  }) async {
    developer.log(
      'GooglePlacesRepository.fetchPlaces start lat=$latitude lng=$longitude radius=$radiusMeters max=$maxResultCount',
      name: 'GooglePlacesRepository',
    );

    final Map<String, dynamic> response = await _postJsonObject(
      endpoint: _nearbySearchEndpoint,
      fieldMask: _fieldMask,
      body: <String, Object>{
        'includedTypes': <String>['cafe', 'coffee_shop'],
        'maxResultCount': maxResultCount,
        'languageCode': 'ja',
        'regionCode': 'JP',
        'rankPreference': 'DISTANCE',
        'locationRestriction': <String, Object>{
          'circle': <String, Object>{
            'center': <String, double>{
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radiusMeters,
          },
        },
      },
    );

    final List<Place> places = _parsePlacesResponse(response);

    developer.log(
      'Google Places API success count=${places.length}',
      name: 'GooglePlacesRepository',
    );
    return places;
  }

  @override
  Future<List<Place>> searchPlacesByText({
    required String query,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    int maxResultCount = 20,
  }) async {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      throw ArgumentError.value(query, 'query', 'must not be empty');
    }
    if (radiusMeters <= 0) {
      throw ArgumentError.value(
        radiusMeters,
        'radiusMeters',
        'must be greater than zero',
      );
    }

    final int pageSize = maxResultCount.clamp(1, 20);
    final _SearchBounds bounds = _buildSearchBounds(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );

    developer.log(
      'GooglePlacesRepository.searchPlacesByText start query=$trimmedQuery lat=$latitude lng=$longitude radius=$radiusMeters max=$pageSize',
      name: 'GooglePlacesRepository',
    );

    final Map<String, dynamic> response = await _postJsonObject(
      endpoint: _textSearchEndpoint,
      fieldMask: _fieldMask,
      body: <String, Object>{
        'textQuery': trimmedQuery,
        'pageSize': pageSize,
        'languageCode': 'ja',
        'regionCode': 'JP',
        'locationRestriction': <String, Object>{
          'rectangle': <String, Object>{
            'low': <String, double>{
              'latitude': bounds.south,
              'longitude': bounds.west,
            },
            'high': <String, double>{
              'latitude': bounds.north,
              'longitude': bounds.east,
            },
          },
        },
      },
    );

    final List<Place> places = _parsePlacesResponse(response)
        .where(
          (Place place) =>
              _distanceMeters(
                latitude,
                longitude,
                place.latitude,
                place.longitude,
              ) <=
              radiusMeters,
        )
        .toList();

    developer.log(
      'Google Places Text Search success count=${places.length}',
      name: 'GooglePlacesRepository',
    );
    return places;
  }

  @override
  Future<List<PlaceSuggestion>> fetchAutocompleteSuggestions({
    required String input,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final String trimmedInput = input.trim();
    if (trimmedInput.isEmpty) {
      return const <PlaceSuggestion>[];
    }

    final double biasRadius = radiusMeters.clamp(1, 50000).toDouble();
    final Map<String, dynamic> response = await _postJsonObject(
      endpoint: _autocompleteEndpoint,
      fieldMask: _autocompleteFieldMask,
      body: <String, Object>{
        'input': trimmedInput,
        'languageCode': 'ja',
        'regionCode': 'JP',
        'includeQueryPredictions': true,
        'locationBias': <String, Object>{
          'circle': <String, Object>{
            'center': <String, double>{
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': biasRadius,
          },
        },
      },
    );

    final List<dynamic> rawSuggestions =
        (response['suggestions'] as List<dynamic>?) ?? const <dynamic>[];
    return rawSuggestions
        .whereType<Map<String, dynamic>>()
        .map(_toSuggestion)
        .whereType<PlaceSuggestion>()
        .toList();
  }

  String get _validatedApiKey {
    final String apiKey = _apiKey.trim();
    if (apiKey.isEmpty || apiKey == 'あなたのキー') {
      throw Exception('GOOGLE_PLACES_API_KEY is not configured.');
    }
    return apiKey;
  }

  Future<Map<String, dynamic>> _postJsonObject({
    required String endpoint,
    required String fieldMask,
    required Map<String, Object> body,
  }) async {
    final String apiKey = _validatedApiKey;
    final http.Response response = await _client.post(
      Uri.parse(endpoint),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (endpoint == _autocompleteEndpoint) {
        throw Exception(
          'Google Places Autocomplete request failed: '
          'status=${response.statusCode}, body=${response.body}',
        );
      }

      developer.log(
        'Google Places API failed status=${response.statusCode} body=${response.body}',
        name: 'GooglePlacesRepository',
      );
      throw Exception(
        'Google Places API request failed: status=${response.statusCode}, body=${response.body}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      if (endpoint == _autocompleteEndpoint) {
        throw const FormatException(
          'Google Places Autocomplete returned invalid JSON.',
        );
      }
      throw const FormatException('Google Places API returned invalid JSON.');
    }

    return decoded;
  }

  List<Place> _parsePlacesResponse(Map<String, dynamic> response) {
    final List<dynamic> rawPlaces =
        (response['places'] as List<dynamic>?) ?? const <dynamic>[];
    return rawPlaces
        .whereType<Map<String, dynamic>>()
        .map(_toPlace)
        .whereType<Place>()
        .toList();
  }

  Place? _toPlace(Map<String, dynamic> json) {
    final Map<String, dynamic> displayName =
        (json['displayName'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final Map<String, dynamic> location =
        (json['location'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final Map<String, dynamic> currentOpeningHours =
        (json['currentOpeningHours'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    final String name = (displayName['text'] as String?)?.trim() ?? '';
    final num? latitudeNum = location['latitude'] as num?;
    final num? longitudeNum = location['longitude'] as num?;

    if (name.isEmpty || latitudeNum == null || longitudeNum == null) {
      return null;
    }

    return Place(
      id:
          (json['id'] as String?) ??
          'place_${location['latitude']}_${location['longitude']}',
      name: name,
      description: (json['formattedAddress'] as String?)?.trim() ?? '',
      latitude: latitudeNum.toDouble(),
      longitude: longitudeNum.toDouble(),
      webUrl: placeholderPlaceWebUrl,
      isOpenNow: currentOpeningHours['openNow'] as bool?,
    );
  }

  PlaceSuggestion? _toSuggestion(Map<String, dynamic> json) {
    final Map<String, dynamic>? placePrediction =
        json['placePrediction'] as Map<String, dynamic>?;
    if (placePrediction != null) {
      final String text = _predictionText(placePrediction);
      if (text.isEmpty) {
        return null;
      }
      return PlaceSuggestion(
        text: text,
        type: PlaceSuggestionType.place,
        placeId: (placePrediction['placeId'] as String?)?.trim(),
      );
    }

    final Map<String, dynamic>? queryPrediction =
        json['queryPrediction'] as Map<String, dynamic>?;
    if (queryPrediction == null) {
      return null;
    }
    final String text = _predictionText(queryPrediction);
    if (text.isEmpty) {
      return null;
    }
    return PlaceSuggestion(text: text, type: PlaceSuggestionType.query);
  }

  String _predictionText(Map<String, dynamic> prediction) {
    final Map<String, dynamic> text =
        (prediction['text'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return (text['text'] as String?)?.trim() ?? '';
  }

  _SearchBounds _buildSearchBounds({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    const double metersPerDegreeLatitude = 111320;
    final double latitudeDelta = radiusMeters / metersPerDegreeLatitude;
    final double longitudeScale = math.cos(latitude * math.pi / 180).abs();
    final double longitudeDelta =
        radiusMeters /
        (metersPerDegreeLatitude * math.max(longitudeScale, 0.000001));

    return _SearchBounds(
      south: math.max(-90, latitude - latitudeDelta),
      west: math.max(-180, longitude - longitudeDelta),
      north: math.min(90, latitude + latitudeDelta),
      east: math.min(180, longitude + longitudeDelta),
    );
  }

  double _distanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    const double earthRadiusMeters = 6371000;
    final double latitudeDelta = (endLatitude - startLatitude) * math.pi / 180;
    final double longitudeDelta =
        (endLongitude - startLongitude) * math.pi / 180;
    final double startLatitudeRadians = startLatitude * math.pi / 180;
    final double endLatitudeRadians = endLatitude * math.pi / 180;
    final double haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);

    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
  }
}

class _SearchBounds {
  const _SearchBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;
}
