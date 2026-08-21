import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key, this.url = 'https://example.com'});

  final String url;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
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
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
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
            setState(() {
              _isLoading = false;
              _errorMessage = 'ページの読み込みに失敗しました (${error.errorCode})';
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
