/// Validated page metadata. Raw URLs are used only for document matching;
/// Analytics receives query/fragment-free, bounded values.
class WebViewScreenView {
  WebViewScreenView._(this.location, this.title, this.referrer);

  static const allowedOrigins = <String>{
    'https://corp.ex-ture.com',
    'https://ex-ture.com',
  };

  final Uri location;
  final String title;
  final Uri? referrer;

  static Uri? _parseUrl(String value) {
    if (value.isEmpty ||
        RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(value) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value)) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    try {
      if (uri.port < 1 || uri.port > 65535) return null;
    } on FormatException {
      return null;
    }
    return uri;
  }

  static WebViewScreenView? tryParse({
    required String pageLocation,
    required String pageTitle,
    required String pageReferrer,
  }) {
    final location = _parseUrl(pageLocation);
    if (location == null || !allowedOrigins.contains(location.origin)) {
      return null;
    }
    final referrer = pageReferrer.isEmpty ? null : _parseUrl(pageReferrer);
    // Reject the message rather than silently forward a malformed referrer.
    if (pageReferrer.isNotEmpty && referrer == null) return null;
    return WebViewScreenView._(location, _bounded(pageTitle), referrer);
  }

  // Standard-property custom string parameters are bounded to 100 characters.
  // Runes avoid splitting a Unicode surrogate pair.
  static String _bounded(String value) => String.fromCharCodes(
    value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').runes.take(100),
  );

  static String _boundedUrl(String value) =>
      _bounded(value).replaceFirst(RegExp(r'%[0-9a-fA-F]?$'), '');

  static String _safeUrl(Uri uri) =>
      _boundedUrl('${uri.origin}${uri.path.isEmpty ? '/' : uri.path}');

  String get screenName =>
      _boundedUrl('web:${location.path.isEmpty ? '/' : location.path}');

  Map<String, Object> get parameters => <String, Object>{
    'wv_page_location': _safeUrl(location),
    'wv_page_title': title,
    'wv_page_referrer': referrer == null ? '' : _safeUrl(referrer!),
  };
}
