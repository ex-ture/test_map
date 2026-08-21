import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../models/place.dart';

LatLngBounds? buildBoundsForPlaces(Iterable<Place> places) {
  final Iterator<Place> iterator = places.iterator;
  if (!iterator.moveNext()) {
    return null;
  }

  double south = iterator.current.latitude;
  double north = iterator.current.latitude;
  double west = iterator.current.longitude;
  double east = iterator.current.longitude;

  while (iterator.moveNext()) {
    final Place place = iterator.current;
    if (place.latitude < south) {
      south = place.latitude;
    }
    if (place.latitude > north) {
      north = place.latitude;
    }
    if (place.longitude < west) {
      west = place.longitude;
    }
    if (place.longitude > east) {
      east = place.longitude;
    }
  }

  return LatLngBounds(
    southwest: LatLng(south, west),
    northeast: LatLng(north, east),
  );
}
