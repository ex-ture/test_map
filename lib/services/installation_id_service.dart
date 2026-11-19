import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

typedef InstallationIdGenerator = String Function();

class InstallationIdService {
  InstallationIdService({InstallationIdGenerator? idGenerator})
    : _idGenerator = idGenerator ?? _generateUuid;

  static final InstallationIdService instance = InstallationIdService();
  static const String storageKey = 'installation_id';

  final InstallationIdGenerator _idGenerator;
  String? _cachedInstallationId;
  Future<String>? _pendingInstallationId;

  Future<String> getInstallationId() {
    final String? cachedInstallationId = _cachedInstallationId;
    if (cachedInstallationId != null) {
      return Future<String>.value(cachedInstallationId);
    }

    return _pendingInstallationId ??= _loadOrCreateInstallationId()
        .whenComplete(() => _pendingInstallationId = null);
  }

  Future<String> _loadOrCreateInstallationId() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? storedInstallationId = preferences.getString(storageKey);
    if (storedInstallationId != null && storedInstallationId.isNotEmpty) {
      _cachedInstallationId = storedInstallationId;
      return storedInstallationId;
    }

    final String installationId = _idGenerator();
    final bool didSave = await preferences.setString(
      storageKey,
      installationId,
    );
    if (!didSave) {
      throw StateError('Failed to save installation_id');
    }

    _cachedInstallationId = installationId;
    return installationId;
  }

  static String _generateUuid() => Uuid().v4();
}
