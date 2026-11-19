import 'package:firebase_auth/firebase_auth.dart';

import '../constants/place_urls.dart';
import 'installation_id_service.dart';

/// App IDs are only attached to the HTTPS Firebase Hosting destination.
Future<Uri> buildWebViewUrl(
  String url, {
  Future<String> Function()? getInstallationId,
  String? Function()? getAuthUid,
}) async {
  final Uri uri = Uri.parse(url);
  final Uri hostingUri = Uri.parse(firebaseHostingWebUrl);
  if (uri.scheme != hostingUri.scheme ||
      uri.host != hostingUri.host ||
      uri.port != hostingUri.port ||
      uri.userInfo.isNotEmpty) {
    return uri;
  }

  final String installationId =
      await (getInstallationId ??
          InstallationIdService.instance.getInstallationId)();
  final String? authUid =
      (getAuthUid ?? () => FirebaseAuth.instance.currentUser?.uid)();
  final Map<String, dynamic> parameters = <String, dynamic>{
    ...uri.queryParametersAll,
    'installation_id': installationId,
  }..remove('auth_uid');
  if (authUid != null) {
    parameters['auth_uid'] = authUid;
  }
  return uri.replace(queryParameters: parameters);
}
