import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_map/services/installation_id_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String generatedId = 'd14a353d-9e8c-4630-b7e9-2512ad6f57f1';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('generates and saves an installation ID on first access', () async {
    int generationCount = 0;
    final InstallationIdService service = InstallationIdService(
      idGenerator: () {
        generationCount++;
        return generatedId;
      },
    );

    final List<String> ids = await Future.wait(<Future<String>>[
      service.getInstallationId(),
      service.getInstallationId(),
    ]);
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    expect(ids, <String>[generatedId, generatedId]);
    expect(generationCount, 1);
    expect(
      preferences.getString(InstallationIdService.storageKey),
      generatedId,
    );
  });

  test('reuses the saved installation ID from another service', () async {
    final InstallationIdService firstService = InstallationIdService(
      idGenerator: () => generatedId,
    );
    final String firstId = await firstService.getInstallationId();

    int generationCount = 0;
    final InstallationIdService secondService = InstallationIdService(
      idGenerator: () {
        generationCount++;
        return 'should-not-be-used';
      },
    );
    final String secondId = await secondService.getInstallationId();

    expect(secondId, firstId);
    expect(generationCount, 0);
  });
}
