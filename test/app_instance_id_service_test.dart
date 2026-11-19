import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/services/app_instance_id_service.dart';

void main() {
  test('SDK identity is read each time without caching', () async {
    var count = 0;
    Future<String?> read() async => 'sdk-${++count}';
    expect(await getAppInstanceId(readId: read), 'sdk-1');
    expect(await getAppInstanceId(readId: read), 'sdk-2');
  });
  test('null, empty and SDK failure are safe', () async {
    for (final value in [null, '', '   ']) {
      expect(await getAppInstanceId(readId: () async => value), isNull);
    }
    expect(
      await getAppInstanceId(
        readId: () async => throw StateError('SDK unavailable'),
      ),
      isNull,
    );
  });
}
