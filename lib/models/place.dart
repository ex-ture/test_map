class Place {
  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String webUrl;
  final bool? isOpenNow;

  const Place({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.webUrl,
    this.isOpenNow,
  });
}
