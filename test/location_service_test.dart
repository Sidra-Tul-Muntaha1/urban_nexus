import 'package:flutter_test/flutter_test.dart';
import 'package:urban_nexus/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocationService tests', () {
    test('fallback coordinates are set to Dubai UHI Zone', () {
      expect(LocationService.fallbackLat, equals(25.2048));
      expect(LocationService.fallbackLng, equals(55.2708));
    });

    test('LocationService handles GPS requests safely', () async {
      final service = LocationService();
      final pos = await service.getCurrentPosition();

      expect(pos.latitude, isNotNull);
      expect(pos.longitude, isNotNull);
    });
  });
}
