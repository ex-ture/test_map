import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/place_urls.dart';
import '../models/place.dart';

class PlaceHistoryRepository {
  const PlaceHistoryRepository();

  static const String _storageKey = 'place_view_history';
  static const int _maxHistoryCount = 20;

  Future<List<Place>> fetchHistory() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> storedPlaces =
        preferences.getStringList(_storageKey) ?? const <String>[];

    return storedPlaces
        .map(_decodePlace)
        .whereType<Place>()
        .take(_maxHistoryCount)
        .toList();
  }

  Future<void> add(Place place) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final List<String> storedPlaces =
        preferences.getStringList(_storageKey) ?? const <String>[];
    final List<Place> history = storedPlaces
        .map(_decodePlace)
        .whereType<Place>()
        .where((Place storedPlace) => storedPlace.id != place.id)
        .toList();

    history.insert(0, place);
    await preferences.setStringList(
      _storageKey,
      history.take(_maxHistoryCount).map(_encodePlace).toList(),
    );
  }

  String _encodePlace(Place place) {
    return jsonEncode(<String, Object?>{
      'id': place.id,
      'name': place.name,
      'description': place.description,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'webUrl': placeholderPlaceWebUrl,
      'isOpenNow': place.isOpenNow,
    });
  }

  Place? _decodePlace(String encodedPlace) {
    try {
      final Object? decoded = jsonDecode(encodedPlace);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final Object? id = decoded['id'];
      final Object? name = decoded['name'];
      final Object? description = decoded['description'];
      final Object? latitude = decoded['latitude'];
      final Object? longitude = decoded['longitude'];
      final Object? webUrl = decoded['webUrl'];
      final Object? isOpenNow = decoded['isOpenNow'];

      if (id is! String ||
          name is! String ||
          description is! String ||
          latitude is! num ||
          longitude is! num ||
          webUrl is! String) {
        return null;
      }

      return Place(
        id: id,
        name: name,
        description: description,
        latitude: latitude.toDouble(),
        longitude: longitude.toDouble(),
        webUrl: placeholderPlaceWebUrl,
        isOpenNow: isOpenNow is bool ? isOpenNow : null,
      );
    } on FormatException {
      return null;
    }
  }
}
