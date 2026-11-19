import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'installation_id_service.dart';
import 'webview_screen_view.dart';

enum AnalyticsScreen {
  map('map'),
  webview('webview');

  const AnalyticsScreen(this.name);

  final String name;
}

enum AnalyticsAction {
  pinTap('pin_tap'),
  webviewOpen('webview_open');

  const AnalyticsAction(this.name);

  final String name;
}

abstract interface class AnalyticsService {
  Future<void> logScreenView(AnalyticsScreen screen);

  Future<void> logAction(AnalyticsAction action);

  Future<void> logWebViewBridgeTest();

  Future<void> logWebViewPageView({required String pagePath});

  Future<void> logWebViewScreenView(WebViewScreenView page);
}

abstract interface class FirebaseAnalyticsGateway {
  Future<void> setDefaultEventParameters(
    Map<String, Object?> defaultParameters,
  );

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    required Map<String, Object> parameters,
  });

  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  });
}

class DefaultFirebaseAnalyticsGateway implements FirebaseAnalyticsGateway {
  const DefaultFirebaseAnalyticsGateway();

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?> defaultParameters,
  ) {
    return FirebaseAnalytics.instance.setDefaultEventParameters(
      defaultParameters,
    );
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    required Map<String, Object> parameters,
  }) {
    return FirebaseAnalytics.instance.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    if (name == 'wv_page_view') {
      debugPrint(
        'Analytics wv_page_view: calling FirebaseAnalytics.instance.logEvent',
      );
    }
    return FirebaseAnalytics.instance.logEvent(
      name: name,
      parameters: parameters,
    );
  }
}

class FirebaseAnalyticsService implements AnalyticsService {
  const FirebaseAnalyticsService({
    FirebaseAnalyticsGateway? gateway,
    InstallationIdService? installationIdService,
    String? Function()? firebaseUidProvider,
  }) : _gateway = gateway,
       _installationIdService = installationIdService,
       _firebaseUidProvider = firebaseUidProvider;

  static const FirebaseAnalyticsGateway _defaultGateway =
      DefaultFirebaseAnalyticsGateway();

  final FirebaseAnalyticsGateway? _gateway;
  final InstallationIdService? _installationIdService;
  final String? Function()? _firebaseUidProvider;

  FirebaseAnalyticsGateway get _instance => _gateway ?? _defaultGateway;

  Future<Map<String, Object>> _commonParameters() async {
    final InstallationIdService installationIdService =
        _installationIdService ?? InstallationIdService.instance;
    final String installationId = await installationIdService
        .getInstallationId();
    final String? firebaseUid = (_firebaseUidProvider ?? _currentFirebaseUid)
        .call();

    await _instance.setDefaultEventParameters(<String, Object>{
      'installation_id': installationId,
    });

    return <String, Object>{
      'installation_id': installationId,
      if (firebaseUid != null && firebaseUid.isNotEmpty)
        'auth_uid': firebaseUid,
    };
  }

  static String? _currentFirebaseUid() =>
      FirebaseAuth.instance.currentUser?.uid;

  @override
  Future<void> logWebViewPageView({required String pagePath}) async {
    debugPrint('Analytics wv_page_view: service entered');
    if (_gateway == null && Firebase.apps.isEmpty) {
      debugPrint(
        'Analytics wv_page_view: skipped; Firebase is not initialized',
      );
      return;
    }
    try {
      debugPrint(
        'Analytics wv_page_view: calling gateway ${_instance.runtimeType}',
      );
      await _instance.logEvent(
        name: 'wv_page_view',
        parameters: <String, Object>{'page_path': pagePath},
      );
      debugPrint(
        'Analytics wv_page_view: gateway logEvent completed '
        '(SDK call completed when using default gateway; not GA4 delivery confirmation)',
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics wv_page_view failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> logWebViewBridgeTest() async {
    if (_gateway == null && Firebase.apps.isEmpty) {
      return;
    }
    try {
      await _instance.logEvent(
        name: 'webview_bridge_test',
        parameters: await _commonParameters(),
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics webview_bridge_test failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> logWebViewScreenView(WebViewScreenView page) async {
    if (_gateway == null && Firebase.apps.isEmpty) return;
    try {
      await _instance.logScreenView(
        screenName: page.screenName,
        screenClass: 'WebViewPage',
        parameters: <String, Object>{
          ...await _commonParameters(),
          ...page.parameters,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics WebView screen_view failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    if (_gateway == null && Firebase.apps.isEmpty) {
      return;
    }
    try {
      await _instance.logScreenView(
        screenName: screen.name,
        parameters: await _commonParameters(),
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics screen_view failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Future<void> logAction(AnalyticsAction action) async {
    if (_gateway == null && Firebase.apps.isEmpty) {
      return;
    }
    try {
      final Map<String, Object> parameters = await _commonParameters();
      await _instance.logEvent(
        name: 'action_event',
        parameters: <String, Object>{'action_name': action.name, ...parameters},
      );
    } catch (error, stackTrace) {
      debugPrint('Analytics action_event failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
