import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/services/analytics_service.dart';
import 'package:test_map/services/webview_screen_view.dart';
import 'package:test_map/services/installation_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String installationId = 'd14a353d-9e8c-4630-b7e9-2512ad6f57f1';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      InstallationIdService.storageKey: installationId,
    });
  });

  for (final uid in <String?>[null, 'firebase-auth-uid']) {
    test(
      'bridge test uses fixed event and native identity (uid: $uid)',
      () async {
        final gateway = _RecordingFirebaseAnalyticsGateway();
        final service = FirebaseAnalyticsService(
          gateway: gateway,
          installationIdService: InstallationIdService(),
          firebaseUidProvider: () => uid,
        );
        await service.logWebViewBridgeTest();
        expect(gateway.eventName, 'webview_bridge_test');
        expect(gateway.eventParameters, <String, Object>{
          'installation_id': installationId,
          if (uid != null) 'auth_uid': uid,
        });
      },
    );
  }

  test('page view forwards only page_path', () async {
    final gateway = _RecordingFirebaseAnalyticsGateway();
    final service = FirebaseAnalyticsService(
      gateway: gateway,
      firebaseUidProvider: () => throw StateError('Identity must not be read'),
    );
    await service.logWebViewPageView(pagePath: '/case');
    expect(gateway.eventName, 'wv_page_view');
    expect(gateway.eventParameters, {'page_path': '/case'});
    expect(gateway.defaultParameters, isNull);
  });

  test(
    'web screen uses native screen API and custom page parameters',
    () async {
      final gateway = _RecordingFirebaseAnalyticsGateway();
      final service = FirebaseAnalyticsService(
        gateway: gateway,
        installationIdService: InstallationIdService(),
        firebaseUidProvider: () => 'uid',
      );
      final page = WebViewScreenView.tryParse(
        pageLocation: 'https://ex-ture.com/case?installation_id=secret#private',
        pageTitle: 'Case',
        pageReferrer: 'https://corp.ex-ture.com/?auth_uid=secret',
      )!;
      await service.logWebViewScreenView(page);
      expect(gateway.screenName, 'web:/case');
      expect(gateway.screenClass, 'WebViewPage');
      expect(gateway.eventName, isNull);
      expect(gateway.screenParameters, {
        'installation_id': installationId,
        'auth_uid': 'uid',
        'wv_page_location': 'https://ex-ture.com/case',
        'wv_page_title': 'Case',
        'wv_page_referrer': 'https://corp.ex-ture.com/',
      });
    },
  );

  test('web metadata bounds Unicode and URLs without splitting escapes', () {
    final page = WebViewScreenView.tryParse(
      pageLocation: 'https://ex-ture.com/${'a' * 78}%E3%81%82?email=private',
      pageTitle: '${'😀' * 101}\n',
      pageReferrer: '',
    )!;
    expect(page.title.runes.length, 100);
    expect(page.screenName.runes.length, lessThanOrEqualTo(100));
    final url = page.parameters['wv_page_location']! as String;
    expect(url.length, lessThanOrEqualTo(100));
    expect(url, isNot(contains('?')));
    expect(RegExp(r'%[0-9a-fA-F]?$').hasMatch(url), isFalse);
    expect(page.parameters['wv_page_referrer'], '');
  });

  const Map<AnalyticsScreen, String> screenNames = <AnalyticsScreen, String>{
    AnalyticsScreen.map: 'map',
    AnalyticsScreen.webview: 'webview',
  };
  for (final MapEntry<AnalyticsScreen, String> entry in screenNames.entries) {
    test('adds installation_id to ${entry.value} screen_view', () async {
      final _RecordingFirebaseAnalyticsGateway gateway =
          _RecordingFirebaseAnalyticsGateway();
      final FirebaseAnalyticsService service = FirebaseAnalyticsService(
        gateway: gateway,
        installationIdService: InstallationIdService(),
        firebaseUidProvider: () => null,
      );

      await service.logScreenView(entry.key);

      expect(gateway.screenName, entry.value);
      expect(gateway.screenParameters, <String, Object>{
        'installation_id': installationId,
      });
      expect(gateway.defaultParameters, <String, Object>{
        'installation_id': installationId,
      });
    });
  }

  const Map<AnalyticsAction, String> actionNames = <AnalyticsAction, String>{
    AnalyticsAction.pinTap: 'pin_tap',
    AnalyticsAction.webviewOpen: 'webview_open',
  };
  for (final MapEntry<AnalyticsAction, String> entry in actionNames.entries) {
    test('adds installation_id to ${entry.value} action_event', () async {
      final _RecordingFirebaseAnalyticsGateway gateway =
          _RecordingFirebaseAnalyticsGateway();
      final FirebaseAnalyticsService service = FirebaseAnalyticsService(
        gateway: gateway,
        installationIdService: InstallationIdService(),
        firebaseUidProvider: () => null,
      );

      await service.logAction(entry.key);

      expect(gateway.eventName, 'action_event');
      expect(gateway.eventParameters, <String, Object>{
        'action_name': entry.value,
        'installation_id': installationId,
      });
      expect(gateway.defaultParameters, <String, Object>{
        'installation_id': installationId,
      });
    });
  }

  test('adds Auth UID to screen_view only while logged in', () async {
    final _RecordingFirebaseAnalyticsGateway gateway =
        _RecordingFirebaseAnalyticsGateway();
    String? currentUid = 'firebase-auth-uid';
    final FirebaseAnalyticsService service = FirebaseAnalyticsService(
      gateway: gateway,
      installationIdService: InstallationIdService(),
      firebaseUidProvider: () => currentUid,
    );

    await service.logScreenView(AnalyticsScreen.map);

    expect(gateway.screenParameters, <String, Object>{
      'installation_id': installationId,
      'auth_uid': 'firebase-auth-uid',
    });

    currentUid = null;
    await service.logScreenView(AnalyticsScreen.webview);

    expect(gateway.screenParameters, <String, Object>{
      'installation_id': installationId,
    });
  });

  test('adds Auth UID to action_event only while logged in', () async {
    final _RecordingFirebaseAnalyticsGateway gateway =
        _RecordingFirebaseAnalyticsGateway();
    String? currentUid = 'firebase-auth-uid';
    final FirebaseAnalyticsService service = FirebaseAnalyticsService(
      gateway: gateway,
      installationIdService: InstallationIdService(),
      firebaseUidProvider: () => currentUid,
    );

    await service.logAction(AnalyticsAction.pinTap);

    expect(gateway.eventParameters, <String, Object>{
      'action_name': 'pin_tap',
      'installation_id': installationId,
      'auth_uid': 'firebase-auth-uid',
    });

    currentUid = null;
    await service.logAction(AnalyticsAction.webviewOpen);

    expect(gateway.eventParameters, <String, Object>{
      'action_name': 'webview_open',
      'installation_id': installationId,
    });
  });
}

class _RecordingFirebaseAnalyticsGateway implements FirebaseAnalyticsGateway {
  Map<String, Object?>? defaultParameters;
  String? screenName;
  String? screenClass;
  Map<String, Object>? screenParameters;
  String? eventName;
  Map<String, Object>? eventParameters;

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?> defaultParameters,
  ) async {
    this.defaultParameters = defaultParameters;
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    required Map<String, Object> parameters,
  }) async {
    this.screenName = screenName;
    this.screenClass = screenClass;
    screenParameters = parameters;
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    eventName = name;
    eventParameters = parameters;
  }
}
