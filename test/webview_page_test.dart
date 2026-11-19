import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:test_map/constants/place_urls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_map/pages/05_webview/webview_page.dart';
import 'package:test_map/services/analytics_service.dart';
import 'package:test_map/services/webview_screen_view.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late _FakeWebViewPlatform platform;
  late _NoopAnalytics analytics;
  final navigatorKey = GlobalKey<NavigatorState>();

  setUp(() {
    analytics = _NoopAnalytics();
    platform = _FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => WebViewPage(
          url: 'https://example.test/',
          analyticsService: analytics,
          appInstanceIdProvider: () async => 'sdk-test-id',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> cover(WidgetTester tester) async {
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Cover')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> uncover(WidgetTester tester) async {
    navigatorKey.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  String screenMessage(
    String location, {
    String referrer = '',
    Object title = '事例紹介',
  }) => jsonEncode({
    'event': 'wv_screen_view',
    'page_location': location,
    'page_title': title,
    'page_referrer': referrer,
  });

  testWidgets('no box SV; document SV forwards metadata once even concurrently', (
    tester,
  ) async {
    await open(tester);
    expect(analytics.screens, isEmpty);
    final controller = platform.controllers.single;
    controller.url = 'https://ex-ture.com/case?auth_uid=secret#section';
    platform.delegate.started(controller.url!);
    controller.readyState = 'interactive';
    final message = screenMessage(
      controller.url!,
      referrer: 'https://other.test/?installation_id=secret',
    );
    final pending = Completer<void>();
    analytics.pendingScreen = pending.future;
    controller.send(message);
    controller.send(message);
    await tester.pump();
    controller.send(message);
    await tester.pump();
    expect(analytics.webScreens, hasLength(1));
    final page = analytics.webScreens.single;
    expect(page.screenName, 'web:/case');
    expect(page.parameters, {
      'wv_page_location': 'https://ex-ture.com/case',
      'wv_page_title': '事例紹介',
      'wv_page_referrer': 'https://other.test/',
    });
    pending.complete();
    await tester.pump();
    // Existing PV remains independent, including its original duplicate behavior.
    controller.send('wv_page_view');
    controller.send('wv_page_view');
    await tester.pump();
    expect(analytics.pagePaths, ['/case', '/case']);
  });

  testWidgets('reload and a-b-a each allow a new document SV', (tester) async {
    await open(tester);
    final controller = platform.controllers.single;
    for (final path in ['/', '/', '/case', '/']) {
      controller.url = 'https://ex-ture.com$path';
      platform.delegate.started(controller.url!);
      controller.readyState = 'interactive';
      controller.send(screenMessage(controller.url!));
      await tester.pump();
      controller.send(screenMessage(controller.url!));
      await tester.pump();
    }
    expect(analytics.webScreens.map((page) => page.screenName), [
      'web:/',
      'web:/',
      'web:/case',
      'web:/',
    ]);
  });

  testWidgets('invalid metadata never consumes the document SV slot', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    controller.url = 'https://ex-ture.com/case?x=1';
    platform.delegate.started(controller.url!);
    controller.readyState = 'interactive';
    for (final message in [
      screenMessage('https://evil.test/case?x=1'),
      screenMessage('http://ex-ture.com/case?x=1'),
      screenMessage('https://user@ex-ture.com/case?x=1'),
      screenMessage('https://ex-ture.com/case'),
      screenMessage('https://ex-ture.com/other?x=1'),
      screenMessage('not a URL'),
      screenMessage('https://ex-ture.com/%XX'),
      screenMessage('https://ex-ture.com:bad/case'),
      screenMessage(controller.url!, title: 42),
      screenMessage(controller.url!, referrer: 'javascript:alert(1)'),
      screenMessage(controller.url!, referrer: '/relative'),
      jsonEncode({'event': 'wv_screen_view', 'page_location': controller.url}),
      jsonEncode({
        'event': 'wv_screen_view',
        'page_location': controller.url,
        'page_title': '',
        'page_referrer': '',
        'extra': true,
      }),
      screenMessage(controller.url!, title: 'x' * 2100),
    ]) {
      controller.send(message);
      await tester.pump();
    }
    expect(analytics.webScreens, isEmpty);
    controller.send(screenMessage(controller.url!));
    await tester.pump();
    expect(analytics.webScreens, hasLength(1));
  });

  testWidgets('untrusted current origin rejects trusted payload', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    controller.url = 'https://evil.test/case';
    controller.readyState = 'interactive';
    platform.delegate.started(controller.url!);
    controller.send(screenMessage('https://ex-ture.com/case'));
    await tester.pump();
    expect(analytics.webScreens, isEmpty);
  });

  testWidgets('old async document result and hidden route cannot send SV', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    controller.url = 'https://ex-ture.com/case';
    platform.delegate.started(controller.url!);
    final pending = Completer<String?>();
    controller.pendingUrl = pending.future;
    controller.send(screenMessage(controller.url!));
    await tester.pump();
    // Even reloading the same URL invalidates the pending request.
    platform.delegate.started(controller.url!);
    controller.readyState = 'interactive';
    pending.complete(controller.url);
    await tester.pump();
    expect(analytics.webScreens, isEmpty);
    controller.pendingUrl = null;
    await cover(tester);
    controller.send(screenMessage(controller.url!));
    await tester.pump();
    expect(analytics.webScreens, isEmpty);
    await uncover(tester);
    controller.send(screenMessage(controller.url!));
    await tester.pump();
    expect(analytics.webScreens, hasLength(1));
  });

  for (final result in [true, 'true']) {
    testWidgets('successful $result blocks all triggers until navigation', (
      tester,
    ) async {
      await open(tester);
      final controller = platform.controllers.single;
      controller.identityResult = result;
      controller.send('app_identity_request');
      await tester.pump();
      controller.send('app_identity_request');
      platform.delegate.finished(controller.url!);
      await tester.pump();
      await cover(tester);
      await uncover(tester);
      expect(controller.scripts, hasLength(1));
      platform.delegate.started(controller.url!);
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(2));
    });
  }

  for (final failure in ['missing function/false', 'exception']) {
    testWidgets('$failure allows a later request to retry', (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      controller.identityResult = false;
      controller.failScript = failure == 'exception';
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(1));
      controller.identityResult = true;
      controller.failScript = false;
      controller.send('app_identity_request');
      await tester.pump();
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(2));
    });
  }

  testWidgets(
    'in-flight delivery blocks concurrent triggers and ignores stale results',
    (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      final oldResult = Completer<Object>();
      controller.pendingIdentityResult = oldResult.future;
      controller.send('app_identity_request');
      await tester.pump();
      await cover(tester);
      await uncover(tester);
      platform.delegate.finished(controller.url!);
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(1));

      platform.delegate.started(controller.url!);
      final newResult = Completer<Object>();
      controller.pendingIdentityResult = newResult.future;
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(2));
      oldResult.complete(true);
      await tester.pump();
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(2));
      newResult.complete(false);
      await tester.pump();
      controller.pendingIdentityResult = null;
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(3));
    },
  );

  for (final invalid in [null, '', '   ']) {
    testWidgets('invalid ID $invalid remains retryable', (tester) async {
      String? id = invalid;
      await tester.pumpWidget(
        MaterialApp(
          home: WebViewPage(
            url: 'https://example.test/',
            analyticsService: analytics,
            appInstanceIdProvider: () async => id,
          ),
        ),
      );
      await tester.pump();
      final controller = platform.controllers.single;
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, isEmpty);
      id = 'valid-sdk-id';
      controller.send('app_identity_request');
      await tester.pump();
      expect(controller.scripts, hasLength(1));
    });
  }

  testWidgets('identity request delivers SDK ID before DOM ready', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    platform.delegate.started(controller.url!);
    controller.send('app_identity_request');
    await tester.pump();
    expect(controller.scripts.single, contains('appInstanceId: "sdk-test-id"'));
    expect(controller.readinessChecks, 0);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    platform.delegate.finished(controller.url!);
    await tester.pump();
    expect(controller.scripts, hasLength(1));
    expect(analytics.bridgeTests + analytics.pageViews, 0);
  });

  testWidgets(
    'null identity does not inject invalid values or prevent loading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WebViewPage(
            url: 'https://example.test/',
            analyticsService: analytics,
            appInstanceIdProvider: () async => null,
          ),
        ),
      );
      await tester.pump();
      final controller = platform.controllers.single;
      controller.send('app_identity_request');
      await tester.pump();
      platform.delegate.finished(controller.url!);
      await tester.pump();
      expect(controller.scripts, isEmpty);
      expect(controller.loads, 1);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets('JSON page views forward matching paths before full load', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    for (final path in ['/', '/case']) {
      controller.url = 'https://ex-ture.com$path?source=test';
      platform.delegate.started(controller.url!);
      controller.readyState = 'interactive';
      for (var i = 0; i < 2; i++) {
        controller.send(
          jsonEncode({'event': 'wv_page_view', 'page_path': path}),
        );
        await tester.pump();
      }
    }
    expect(analytics.pagePaths, ['/', '/', '/case', '/case']);
  });

  testWidgets('rejects invalid JSON payloads and mismatched paths', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    controller.url = 'https://ex-ture.com/case';
    controller.readyState = 'interactive';
    platform.delegate.started(controller.url!);
    final invalid = <String>[
      '{broken',
      'null',
      '[]',
      '42',
      jsonEncode({'event': 'other', 'page_path': '/case'}),
      jsonEncode({'event': 'bridge_test', 'page_path': '/case'}),
      jsonEncode({'event': 'wv_page_view'}),
      jsonEncode({
        'event': 'wv_page_view',
        'page_path': '/case',
        'page_title': 'ignored',
      }),
      for (final path in <Object?>[
        null,
        42,
        true,
        [],
        {},
        '',
        ' ',
        '/other',
        'https://ex-ture.com/case',
        '//case',
        '/case?q=1',
        '/case#x',
        '/ca\nse',
        '/${List.filled(100, 'a').join()}',
      ])
        jsonEncode({'event': 'wv_page_view', 'page_path': path}),
    ];
    for (final message in invalid) {
      controller.send(message);
      await tester.pump();
      expect(analytics.pageViews, 0, reason: message);
    }
  });

  for (final scenario in ['external', 'navigation', 'loading', 'error']) {
    testWidgets('JSON page view rejects $scenario', (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      controller.url = scenario == 'external'
          ? 'https://example.com/case'
          : 'https://ex-ture.com/case';
      platform.delegate.started(controller.url!);
      controller.readyState = scenario == 'loading' ? 'loading' : 'interactive';
      final pending = Completer<String?>();
      if (scenario == 'navigation') controller.pendingUrl = pending.future;
      if (scenario == 'error') {
        platform.delegate.error(
          const WebResourceError(
            errorCode: -1,
            description: 'failed',
            isForMainFrame: true,
          ),
        );
      }
      controller.send('{"event":"wv_page_view","page_path":"/case"}');
      if (scenario == 'navigation') {
        platform.delegate.started(controller.url!);
        pending.complete(controller.url);
      }
      await tester.pump();
      expect(analytics.pageViews, 0);
    });
  }

  testWidgets('legacy page view derives path without query or fragment', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    controller.readyState = 'interactive';
    for (final url in [
      'https://ex-ture.com',
      'https://ex-ture.com/case?q=1#section',
    ]) {
      controller.url = url;
      platform.delegate.started(url);
      controller.send('wv_page_view');
      await tester.pump();
    }
    expect(analytics.pagePaths, ['/', '/case']);
  });

  for (final allowedMessage in ['bridge_test', 'wv_page_view']) {
    testWidgets('only exact $allowedMessage records an event', (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      expect(controller.channels.keys, ['AppAnalytics']);
      platform.delegate.finished(firebaseHostingWebUrl);
      for (final message in [
        '',
        'WV_PAGE_VIEW',
        'wv_page_view ',
        '{"event":"wv_page_view"}',
        'arbitrary_event',
        'BRIDGE_TEST',
        'bridge_test ',
        '{"event":"bridge_test"}',
        'webview_bridge_test',
      ]) {
        controller.send(message);
      }
      await tester.pump();
      expect(analytics.bridgeTests + analytics.pageViews, 0);
      controller.send(allowedMessage);
      await tester.pump();
      expect(analytics.bridgeTests, allowedMessage == 'bridge_test' ? 1 : 0);
      expect(analytics.pageViews, allowedMessage == 'wv_page_view' ? 1 : 0);
    });

    testWidgets(
      '$allowedMessage ignores loading, hidden, failed and disposed WebViews',
      (tester) async {
        await open(tester);
        final controller = platform.controllers.single;
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
        platform.delegate.finished(firebaseHostingWebUrl);
        await cover(tester);
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
        await uncover(tester);
        platform.delegate.error(
          const WebResourceError(
            errorCode: -1,
            description: 'failed',
            isForMainFrame: true,
          ),
        );
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
        await uncover(tester);
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
      },
    );

    for (final domState in ['interactive', 'complete']) {
      testWidgets('$allowedMessage accepts $domState before page finished', (
        tester,
      ) async {
        await open(tester);
        final controller = platform.controllers.single;
        platform.delegate.started(firebaseHostingWebUrl);
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
        expect(controller.readinessChecks, 1);

        controller.readyState = domState;
        for (var count = 1; count <= 3; count++) {
          controller.send(allowedMessage);
          await tester.pump();
          expect(analytics.bridgeTests + analytics.pageViews, count);
        }
        expect(controller.readinessChecks, 2);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
          controller.scripts,
          isEmpty,
        ); // Identity still waits for full load.

        platform.delegate.started(firebaseHostingWebUrl);
        controller.readyState = 'loading';
        controller.send(allowedMessage);
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 3);
      });
    }

    for (final interruption in ['navigation', 'error', 'hidden', 'disposed']) {
      testWidgets('$allowedMessage rejects $interruption during DOM lookup', (
        tester,
      ) async {
        await open(tester);
        final controller = platform.controllers.single;
        platform.delegate.started(firebaseHostingWebUrl);
        final pending = Completer<Object>();
        controller.pendingReadyState = pending.future;
        controller.send(allowedMessage);
        await tester.pump();
        expect(controller.readinessChecks, 1);
        switch (interruption) {
          case 'navigation':
            platform.delegate.started(firebaseHostingWebUrl);
          case 'error':
            platform.delegate.error(
              const WebResourceError(
                errorCode: -1,
                description: 'failed',
                isForMainFrame: true,
              ),
            );
          case 'hidden':
            await cover(tester);
          case 'disposed':
            await uncover(tester);
        }
        pending.complete('interactive');
        await tester.pump();
        expect(analytics.bridgeTests + analytics.pageViews, 0);
        if (interruption == 'navigation') {
          controller.pendingReadyState = null;
          controller.readyState = 'loading';
          controller.send(allowedMessage);
          await tester.pump();
          expect(analytics.bridgeTests + analytics.pageViews, 0);
        }
      });
    }

    testWidgets('$allowedMessage contains DOM lookup failure', (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      platform.delegate.started(firebaseHostingWebUrl);
      controller.failReadiness = true;
      controller.send(allowedMessage);
      await tester.pump();
      expect(analytics.bridgeTests + analytics.pageViews, 0);
      controller.failReadiness = false;
      controller.readyState = 'interactive';
      controller.send(allowedMessage);
      await tester.pump();
      expect(analytics.bridgeTests + analytics.pageViews, 1);
    });

    testWidgets('$allowedMessage accepts both allowed origins repeatedly', (
      tester,
    ) async {
      await open(tester);
      final controller = platform.controllers.single;
      var expectedEvents = 0;
      for (final origin in [
        'https://corp.ex-ture.com',
        'https://ex-ture.com',
      ]) {
        for (final suffix in [
          '',
          '/',
          '/case',
          '/xxx?source=app',
          '/?q=test',
          ':443/case',
        ]) {
          final url = '$origin$suffix';
          controller.url = url;
          platform.delegate.started(url);
          platform.delegate.finished(url);
          for (var repeat = 0; repeat < 2; repeat++) {
            controller.send(allowedMessage);
            await tester.pump();
            expectedEvents++;
            expect(
              analytics.bridgeTests + analytics.pageViews,
              expectedEvents,
              reason: url,
            );
          }
        }
      }
    });

    testWidgets(
      '$allowedMessage rejects other origins and unavailable current URLs',
      (tester) async {
        await open(tester);
        final controller = platform.controllers.single;
        platform.delegate.started(firebaseHostingWebUrl);
        controller.readyState = 'interactive';
        for (final url in <String?>[
          null,
          '',
          'https://example.test/',
          'https://example.com/',
          'http://ex-ture.com/',
          'https://sub.ex-ture.com/',
          'https://ex-ture.com.evil.test/',
          'https://ex-ture.com:444/',
          'https://user@ex-ture.com/',
          'https://user:password@ex-ture.com/',
          'http://corp.ex-ture.com/',
          'https://corp.ex-ture.com.evil.test/',
          'https://corp.ex-ture.com:444/',
          'https://user@corp.ex-ture.com/',
        ]) {
          controller.url = url;
          controller.send(allowedMessage);
          await tester.pump();
        }
        expect(analytics.bridgeTests + analytics.pageViews, 0);
      },
    );

    testWidgets('$allowedMessage ignores navigation during URL lookup', (
      tester,
    ) async {
      await open(tester);
      final controller = platform.controllers.single;
      platform.delegate.finished(firebaseHostingWebUrl);
      final pending = Completer<String?>();
      controller.pendingUrl = pending.future;
      controller.send(allowedMessage);
      platform.delegate.started(firebaseHostingWebUrl);
      platform.delegate.finished(firebaseHostingWebUrl);
      pending.complete(firebaseHostingWebUrl);
      await tester.pump();
      expect(analytics.bridgeTests + analytics.pageViews, 0);
    });
  }

  testWidgets('successful identity is not resent on retained route returns', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    expect(controller.scripts, isEmpty);
    platform.delegate.started('https://example.test/');
    platform.delegate.finished('https://example.test/');
    await tester.pump();
    expect(controller.scripts, hasLength(1));
    expect(controller.scripts.single, contains('skipIfAlreadySent: true'));

    // Duplicate finish callbacks and ordinary rebuilds are not new displays.
    platform.delegate.finished('https://example.test/');
    await tester.pump();
    expect(controller.scripts, hasLength(1));
    for (var i = 0; i < 2; i++) {
      await cover(tester);
      expect(controller.scripts, hasLength(1));
      await uncover(tester);
      expect(controller.scripts, hasLength(1));
      expect(controller.scripts.last, contains('skipIfAlreadySent: true'));
    }
    expect(controller.loads, 1);
    expect(platform.controllers, hasLength(1));
  });

  testWidgets('return while loading waits and shares the initial page event', (
    tester,
  ) async {
    await open(tester);
    final controller = platform.controllers.single;
    platform.delegate.started('https://example.test/');
    await cover(tester);
    await uncover(tester);
    expect(controller.scripts, isEmpty);
    platform.delegate.finished('https://example.test/');
    await tester.pump();
    expect(controller.scripts.single, contains('skipIfAlreadySent: true'));
    expect(controller.loads, 1);
  });

  testWidgets('load completed behind another route waits for visibility', (
    tester,
  ) async {
    await open(tester);
    await cover(tester);
    platform.delegate.finished('https://example.test/');
    await tester.pump();
    expect(platform.controllers.single.scripts, isEmpty);
    await uncover(tester);
    expect(platform.controllers.single.scripts, hasLength(1));
  });

  testWidgets(
    'closing and reopening creates a document with first-display deduplication',
    (tester) async {
      await open(tester);
      platform.delegate.finished('https://example.test/');
      await tester.pump();
      await uncover(tester);
      await open(tester);
      platform.delegate.finished('https://example.test/');
      await tester.pump();
      expect(platform.controllers, hasLength(2));
      for (final controller in platform.controllers) {
        expect(controller.loads, 1);
        expect(controller.scripts.single, contains('skipIfAlreadySent: true'));
      }
    },
  );

  testWidgets(
    'JavaScript failure is contained and a later display can notify',
    (tester) async {
      await open(tester);
      final controller = platform.controllers.single;
      controller.failScript = true;
      platform.delegate.finished('https://example.test/');
      await tester.pump();
      expect(tester.takeException(), isNull);
      controller.failScript = false;
      await cover(tester);
      await uncover(tester);
      expect(controller.scripts, hasLength(2));
    },
  );
}

class _NoopAnalytics implements AnalyticsService {
  @override
  Future<void> logWebViewScreenView(WebViewScreenView page) async {
    webScreens.add(page);
    await pendingScreen;
  }

  final webScreens = <WebViewScreenView>[];
  final screens = <AnalyticsScreen>[];
  Future<void>? pendingScreen;
  int bridgeTests = 0;
  int pageViews = 0;
  final pagePaths = <String>[];
  @override
  Future<void> logWebViewPageView({required String pagePath}) async {
    pageViews++;
    pagePaths.add(pagePath);
  }

  @override
  Future<void> logWebViewBridgeTest() async {
    bridgeTests++;
  }

  @override
  Future<void> logAction(AnalyticsAction action) async {}
  @override
  Future<void> logScreenView(AnalyticsScreen screen) async {
    screens.add(screen);
  }
}

class _FakeWebViewPlatform extends WebViewPlatform {
  final controllers = <_FakeController>[];
  late _FakeDelegate delegate;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = _FakeController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = _FakeDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => _FakeWidget(params);
}

class _FakeController extends PlatformWebViewController {
  _FakeController(super.params) : super.implementation();
  final scripts = <String>[];
  final channels = <String, JavaScriptChannelParams>{};
  String? url = firebaseHostingWebUrl;
  Future<String?>? pendingUrl;
  Object readyState = 'loading';
  Future<Object>? pendingReadyState;
  int readinessChecks = 0;
  bool failReadiness = false;
  Object identityResult = true;
  Future<Object>? pendingIdentityResult;
  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    if (javaScript != 'document.readyState') {
      scripts.add(javaScript);
      if (failScript) throw StateError('WebView navigated away');
      return pendingIdentityResult ?? identityResult;
    }
    readinessChecks++;
    if (failReadiness) throw StateError('Document unavailable');
    return pendingReadyState ?? readyState;
  }

  @override
  Future<String?> currentUrl() async => pendingUrl ?? url;
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channels[params.name] = params;
  }

  void send(String message) {
    channels['AppAnalytics']!.onMessageReceived(
      JavaScriptMessage(message: message),
    );
  }

  int loads = 0;
  bool failScript = false;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    expect(channels.keys, ['AppAnalytics']);
    loads++;
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    scripts.add(javaScript);
    if (failScript) throw StateError('WebView navigated away');
  }
}

class _FakeDelegate extends PlatformNavigationDelegate {
  _FakeDelegate(super.params) : super.implementation();
  late WebResourceErrorCallback error;
  late PageEventCallback started;
  late PageEventCallback finished;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    error = callback;
  }
}

class _FakeWidget extends PlatformWebViewWidget {
  _FakeWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
