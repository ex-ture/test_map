import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../constants/place_urls.dart';
import '../../services/analytics_service.dart';
import '../../services/app_instance_id_service.dart';
import '../../services/webview_url_builder.dart';
import '../../services/webview_screen_view.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    this.url = firebaseHostingWebUrl,
    this.analyticsService = const FirebaseAnalyticsService(),
    this.appInstanceIdProvider = getAppInstanceId,
  });

  final String url;
  final AnalyticsService analyticsService;
  final Future<String?> Function() appInstanceIdProvider;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  static final List<Uri> _analyticsAllowedOrigins = <Uri>[
    ...WebViewScreenView.allowedOrigins.map(Uri.parse),
  ];

  late final WebViewController _controller;
  late final Future<void> _analyticsChannelReady;
  int _documentVersion = 0;
  int? _screenViewDocumentVersion;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRouteVisible = false;
  // Bridge acceptance state; DOM availability does not require all resources.
  bool _pageReady = false;
  bool _identitySent = false;
  bool _identityInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool visible = ModalRoute.isCurrentOf(context) ?? false;
    _isRouteVisible = visible;
    unawaited(_notifyAppIdentity());
  }

  Future<void> _notifyAppIdentity({bool requestedByPage = false}) async {
    if (!mounted ||
        !_isRouteVisible ||
        (!requestedByPage && (!_pageReady || _isLoading)) ||
        _identitySent ||
        _identityInFlight ||
        _errorMessage != null) {
      return;
    }
    _identityInFlight = true;
    final int version = _documentVersion;
    try {
      final String? id = await widget.appInstanceIdProvider();
      if (id == null || id.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'WebView identity: app_instance_id unavailable (null/empty)',
          );
        }
        return;
      }
      if (!mounted ||
          !_isRouteVisible ||
          version != _documentVersion ||
          _errorMessage != null) {
        return;
      }
      final String origins = jsonEncode([
        Uri.parse(firebaseHostingWebUrl).origin,
        ..._analyticsAllowedOrigins.map((uri) => uri.origin),
      ]);
      final String encodedId = jsonEncode(id);
      final Object pushed = await _controller.runJavaScriptReturningResult('''
        (function () {
          if ($origins.includes(window.location.origin) &&
              typeof window.pushAppIdentity === 'function') {
            return window.pushAppIdentity({appInstanceId: $encodedId, skipIfAlreadySent: true}) === true;
          }
          return false;
        })()
      ''');
      // A late result from an old document must not mark the new one sent.
      if (version == _documentVersion && (pushed == true || pushed == 'true')) {
        _identitySent = true;
        if (kDebugMode) {
          debugPrint('WebView identity: dataLayer push succeeded');
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('WebView identity notification failed: $error');
      }
    } finally {
      if (version == _documentVersion) _identityInFlight = false;
    }
  }

  Future<void> _onIdentityRequest() async {
    final int version = _documentVersion;
    try {
      final String? url = await _controller.currentUrl();
      final Uri? uri = url == null ? null : Uri.tryParse(url);
      if (uri == null ||
          uri.userInfo.isNotEmpty ||
          ![
            Uri.parse(firebaseHostingWebUrl),
            ..._analyticsAllowedOrigins,
          ].any((allowed) => uri.origin == allowed.origin) ||
          version != _documentVersion) {
        return;
      }
      await _notifyAppIdentity(requestedByPage: true);
    } catch (error) {
      if (kDebugMode) debugPrint('WebView identity request failed: $error');
    }
  }

  // Keep paths bounded and path-only; never forward arbitrary JSON parameters.
  static bool _validPagePath(String path) =>
      path.isNotEmpty &&
      path.length <= 100 &&
      path.startsWith('/') &&
      !path.startsWith('//') &&
      !RegExp(r'[\s\x00-\x1f\x7f?#\\]').hasMatch(path);

  static ({String event, String? pagePath, WebViewScreenView? page})?
  _parseAnalyticsMessage(String raw) {
    if (raw == 'bridge_test' || raw == 'wv_page_view') {
      return (event: raw, pagePath: null, page: null);
    }
    if (raw.length > 2048) return null;
    try {
      final Object? value = jsonDecode(raw);
      if (value is Map<String, dynamic> && value['event'] == 'wv_screen_view') {
        if (value.length != 4 ||
            value['page_location'] is! String ||
            value['page_title'] is! String ||
            value['page_referrer'] is! String) {
          return null;
        }
        final page = WebViewScreenView.tryParse(
          pageLocation: value['page_location'] as String,
          pageTitle: value['page_title'] as String,
          pageReferrer: value['page_referrer'] as String,
        );
        return page == null
            ? null
            : (event: 'wv_screen_view', pagePath: null, page: page);
      }
      if (value is! Map<String, dynamic> ||
          value.length != 2 ||
          value['event'] != 'wv_page_view') {
        return null;
      }
      final Object? path = value['page_path'];
      if (path is! String || !_validPagePath(path)) return null;
      return (event: 'wv_page_view', pagePath: path, page: null);
    } on FormatException {
      return null;
    }
  }

  Future<void> _onAnalyticsMessage(JavaScriptMessage message) async {
    final payload = _parseAnalyticsMessage(message.message);
    if (payload == null ||
        !mounted ||
        !_isRouteVisible ||
        _errorMessage != null) {
      debugPrint(
        'AppAnalytics bridge: rejected before URL lookup; '
        'time=${DateTime.now().toIso8601String()}, documentVersion=$_documentVersion; '
        'reasons=${<String>[if (payload == null) 'invalid message', if (!mounted) 'not mounted', if (!_isRouteVisible) 'route not visible', if (_errorMessage != null) 'error exists'].join(', ')}; '
        'allowedMessage=${payload != null}, '
        'mounted=$mounted, visible=$_isRouteVisible, '
        'pageReady=$_pageReady, hasError=${_errorMessage != null}',
      );
      return;
    }
    final int documentVersion = _documentVersion;
    try {
      debugPrint('AppAnalytics bridge: currentUrl lookup started');
      final String? url = await _controller.currentUrl();
      final Uri? uri = url == null ? null : Uri.tryParse(url);
      final bool originMatches =
          uri != null &&
          _analyticsAllowedOrigins.any(
            (allowed) =>
                uri.scheme == allowed.scheme &&
                uri.host == allowed.host &&
                uri.port == allowed.port,
          );
      debugPrint(
        'AppAnalytics bridge: currentUrl lookup completed; '
        'scheme=${uri?.scheme}, host=${uri?.host}, port=${uri?.port}; '
        'expectedOrigin=${_analyticsAllowedOrigins.map((allowed) => allowed.origin).join(', ')}',
      );
      // Check lazily on receipt, so a DOM Ready event does not race a
      // separately injected readiness notification. No polling or replay.
      if (!_pageReady &&
          mounted &&
          _isRouteVisible &&
          _errorMessage == null &&
          documentVersion == _documentVersion &&
          originMatches &&
          uri.userInfo.isEmpty) {
        final Object readyState = await _controller
            .runJavaScriptReturningResult('document.readyState');
        // An async JavaScript result must never ready a newer document.
        if (mounted &&
            _isRouteVisible &&
            _errorMessage == null &&
            documentVersion == _documentVersion &&
            (readyState == 'interactive' || readyState == 'complete')) {
          _pageReady = true;
        }
        debugPrint(
          'AppAnalytics bridge: DOM readiness checked; '
          'time=${DateTime.now().toIso8601String()}, readyState=$readyState, '
          'documentVersion=$documentVersion->$_documentVersion, pageReady=$_pageReady',
        );
      }
      if (!mounted ||
          !_isRouteVisible ||
          !_pageReady ||
          _errorMessage != null ||
          documentVersion != _documentVersion ||
          uri == null ||
          !originMatches ||
          uri.userInfo.isNotEmpty) {
        debugPrint(
          'AppAnalytics bridge: rejected after URL lookup; '
          'time=${DateTime.now().toIso8601String()}, '
          'documentVersion=$documentVersion->$_documentVersion; '
          'reasons=${<String>[if (!mounted) 'not mounted', if (!_isRouteVisible) 'route not visible', if (!_pageReady) 'pageReady false', if (_errorMessage != null) 'error exists', if (documentVersion != _documentVersion) 'documentVersion changed', if (url == null) 'currentUrl null', if (url != null && (uri == null || !uri.hasScheme || uri.host.isEmpty)) 'currentUrl invalid', if (uri != null && !originMatches) 'origin mismatch', if (uri != null && uri.userInfo.isNotEmpty) 'URL userInfo exists'].join(', ')}; '
          'mounted=$mounted, visible=$_isRouteVisible, '
          'pageReady=$_pageReady, hasError=${_errorMessage != null}, '
          'documentChanged=${documentVersion != _documentVersion}, '
          'urlParsed=${uri != null}, '
          'schemeMatches=${_analyticsAllowedOrigins.any((allowed) => uri?.scheme == allowed.scheme)}, '
          'hostMatches=${_analyticsAllowedOrigins.any((allowed) => uri?.host == allowed.host)}, '
          'portMatches=${_analyticsAllowedOrigins.any((allowed) => uri?.port == allowed.port)}, '
          'hasUserInfo=${uri?.userInfo.isNotEmpty}',
        );
        return;
      }
      final String currentPath = uri.path.isEmpty ? '/' : uri.path;
      final String pagePath = payload.pagePath ?? currentPath;
      if (payload.event == 'wv_page_view' &&
          (!_validPagePath(pagePath) || pagePath != currentPath)) {
        debugPrint(
          'AppAnalytics bridge: rejected page_path; invalid or current URL path mismatch',
        );
        return;
      }
      debugPrint('AppAnalytics bridge: checks passed');
      if (payload.page case final page?) {
        // Compare the original URL (including query/fragment), before sanitizing.
        if (page.location != uri ||
            _screenViewDocumentVersion == documentVersion) {
          return;
        }
        // Reserve before awaiting the service: concurrent callbacks share this guard.
        // Do not retry automatically: SDK completion is not a delivery receipt.
        _screenViewDocumentVersion = documentVersion;
        await widget.analyticsService.logWebViewScreenView(page);
      } else if (payload.event == 'bridge_test') {
        await widget.analyticsService.logWebViewBridgeTest();
      } else if (payload.event == 'wv_page_view') {
        debugPrint(
          'AppAnalytics bridge: calling logWebViewPageView; sending wv_page_view; '
          'time=${DateTime.now().toIso8601String()}, '
          'documentVersion=$_documentVersion, currentUrl=$url, page_path=$pagePath',
        );
        await widget.analyticsService.logWebViewPageView(pagePath: pagePath);
        debugPrint('AppAnalytics bridge: logWebViewPageView returned');
      }
    } catch (error) {
      debugPrint('WebView analytics bridge failed: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _analyticsChannelReady = _controller.addJavaScriptChannel(
      'AppAnalytics',
      onMessageReceived: (message) {
        debugPrint(
          'AppAnalytics received (${message.message.length} characters); '
          'time=${DateTime.now().toIso8601String()}, '
          'documentVersion=$_documentVersion, pageReady=$_pageReady, '
          'visible=$_isRouteVisible, hasError=${_errorMessage != null}',
        );
        if (message.message == 'app_identity_request') {
          unawaited(_onIdentityRequest());
        } else {
          unawaited(_onAnalyticsMessage(message));
        }
      },
    );
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (NavigationRequest request) {
          final Uri? uri = Uri.tryParse(request.url);
          final String scheme = uri?.scheme.toLowerCase() ?? '';
          if (scheme == 'http' || scheme == 'https') {
            return NavigationDecision.navigate;
          }
          // Prevent deep-link schemes (for external apps) from breaking in-app WebView.
          return NavigationDecision.prevent;
        },
        onPageStarted: (url) {
          if (!mounted) {
            return;
          }
          _documentVersion++;
          _pageReady = false;
          debugPrint(
            'AppAnalytics onPageStarted: time=${DateTime.now().toIso8601String()}, '
            'url=$url, documentVersion=$_documentVersion, pageReady=$_pageReady',
          );
          _identitySent = false;
          _identityInFlight = false;
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        },
        onPageFinished: (url) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoading = false;
          });
          // Full load is a fallback; a prior DOM check can already accept events.
          _pageReady = _errorMessage == null;
          debugPrint(
            'AppAnalytics onPageFinished: time=${DateTime.now().toIso8601String()}, '
            'url=$url, documentVersion=$_documentVersion, pageReady=$_pageReady',
          );
          unawaited(_notifyAppIdentity());
        },
        onWebResourceError: (WebResourceError error) {
          if (error.errorCode == 0) {
            return;
          }
          if (error.isForMainFrame != true) {
            return;
          }
          if (!mounted) {
            return;
          }
          _pageReady = false;
          setState(() {
            _isLoading = false;
            _errorMessage = 'ページの読み込みに失敗しました (${error.errorCode})';
          });
        },
      ),
    );
    unawaited(_loadPage());
  }

  Future<void> _loadPage() async {
    try {
      await _analyticsChannelReady;
      final platform = _controller.platform;
      if (kDebugMode && platform is WebKitWebViewController) {
        await platform.setInspectable(true);
      }
      final Uri uri = await buildWebViewUrl(widget.url);
      if (!mounted) {
        return;
      }
      await _controller.loadRequest(uri);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'ページの読み込みに失敗しました';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WEB表示')),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
