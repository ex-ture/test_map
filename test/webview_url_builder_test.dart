import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/constants/place_urls.dart';
import 'package:test_map/services/webview_url_builder.dart';

void main() {
  Future<Uri> build(String url, {String? uid, String id = 'xxxxx'}) {
    return buildWebViewUrl(
      url,
      getInstallationId: () async => id,
      getAuthUid: () => uid,
    );
  }

  test('signed out includes only installation_id', () async {
    expect(
      (await build(firebaseHostingWebUrl)).toString(),
      '$firebaseHostingWebUrl?installation_id=xxxxx',
    );
  });

  test('signed in includes both IDs', () async {
    expect(
      (await build(firebaseHostingWebUrl, uid: 'yyyyy')).toString(),
      '$firebaseHostingWebUrl?installation_id=xxxxx&auth_uid=yyyyy',
    );
  });

  test('encodes IDs and preserves path, repeated query and fragment', () async {
    const String id = 'a+b &/?=#日本語';
    const String uid = 'user+&=# あ';
    final Uri uri = await build(
      '${firebaseHostingWebUrl}map?tag=a&tag=b#spot',
      id: id,
      uid: uid,
    );
    final Uri parsed = Uri.parse(uri.toString());
    expect(parsed.path, '/map');
    expect(parsed.fragment, 'spot');
    expect(parsed.queryParametersAll['tag'], ['a', 'b']);
    expect(parsed.queryParameters['installation_id'], id);
    expect(parsed.queryParameters['auth_uid'], uid);
    expect(parsed.queryParameters.length, 3);
    expect(uri.toString(), contains('%26'));
  });

  test('replaces previous IDs and removes stale UID when signed out', () async {
    final Uri uri = await build(
      '$firebaseHostingWebUrl?installation_id=old&auth_uid=old&keep=yes',
    );
    expect(uri.queryParameters, {'installation_id': 'xxxxx', 'keep': 'yes'});
  });

  for (final String url in <String>[
    'https://example.com/shop?foo=bar#menu',
    'https://test-map-884b0.web.app.example.com/',
    'https://sub.test-map-884b0.web.app/',
    'https://test-map-884b0.web.app@external.example/',
    'http://test-map-884b0.web.app/',
    'https://test-map-884b0.web.app:8443/',
  ]) {
    test('does not attach or fetch IDs for $url', () async {
      final Uri result = await buildWebViewUrl(
        url,
        getInstallationId: () => throw StateError('must not fetch ID'),
        getAuthUid: () => throw StateError('must not fetch UID'),
      );
      expect(result.toString(), url);
      expect(result.queryParameters.containsKey('installation_id'), isFalse);
      expect(result.queryParameters.containsKey('auth_uid'), isFalse);
    });
  }
}
