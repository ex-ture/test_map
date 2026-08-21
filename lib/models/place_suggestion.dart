enum PlaceSuggestionType { place, query }

class PlaceSuggestion {
  const PlaceSuggestion({required this.text, required this.type, this.placeId});

  final String text;
  final PlaceSuggestionType type;
  final String? placeId;
}
