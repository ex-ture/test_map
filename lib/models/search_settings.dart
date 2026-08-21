class SearchSettings {
  final int radiusMeters;
  final int maxResultCount;
  final bool openNowOnly;

  const SearchSettings({
    this.radiusMeters = 1000,
    this.maxResultCount = 20,
    this.openNowOnly = false,
  });

  SearchSettings copyWith({
    int? radiusMeters,
    int? maxResultCount,
    bool? openNowOnly,
  }) {
    return SearchSettings(
      radiusMeters: radiusMeters ?? this.radiusMeters,
      maxResultCount: maxResultCount ?? this.maxResultCount,
      openNowOnly: openNowOnly ?? this.openNowOnly,
    );
  }
}
