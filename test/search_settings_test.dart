import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/models/search_settings.dart';

void main() {
  test('defaults to a one kilometer search radius', () {
    const SearchSettings settings = SearchSettings();

    expect(settings.radiusMeters, 1000);
    expect(settings.maxResultCount, 20);
    expect(settings.openNowOnly, isFalse);
  });
}
