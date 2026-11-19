import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Read SDK-owned identity each time; never persist an independent copy.
Future<String?> getAppInstanceId({Future<String?> Function()? readId}) async {
  try {
    final String? id =
        await (readId ?? () => FirebaseAnalytics.instance.appInstanceId)();
    if (id == null || id.trim().isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'app_instance_id unavailable: SDK returned null/empty (check Analytics consent/collection)',
        );
      }
      return null;
    }
    if (kDebugMode) {
      debugPrint('app_instance_id acquisition succeeded: $id');
    }
    return id;
  } catch (error) {
    if (kDebugMode) debugPrint('app_instance_id acquisition failed: $error');
    return null;
  }
}
