import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_nexus/providers/thermal_provider.dart';
import 'package:urban_nexus/services/forty_guard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThermalProvider tests', () {
    test('initial state is not loading and has null metrics', () {
      final mockService = FortyGuardService(useMock: true);
      final provider = ThermalProvider(fortyGuardService: mockService);

      expect(provider.isLoading, isFalse);
      expect(provider.thermalRiskIndex, isNull);
      expect(provider.activeHeatMapData, isNull);
      expect(provider.hasData, isFalse);
    });

    test('fetchMicroClimate updates isLoading, thermalRiskIndex, and activeHeatMapData', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('heat-intelligence')) {
          return http.Response(
            jsonEncode({
              'thermal_risk_index': 68.5,
              'risk_level': 'High',
              'recommended_interventions': ['Cooling stations'],
              'urban_heat_island_factor': 3.1,
              'cooling_degree_days': 15.0,
              'location': {'lat': 24.86, 'lng': 67.0},
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.contains('heatmap')) {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'grid_cells': 250,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{"error":"not found"}', 404);
      });

      final fortyGuard = FortyGuardService(
        client: mockClient,
        apiKey: 'test_key',
        useMock: false,
      );

      final provider = ThermalProvider(fortyGuardService: fortyGuard);
      final notificationStates = <bool>[];
      provider.addListener(() {
        notificationStates.add(provider.isLoading);
      });

      final fetchFuture = provider.fetchMicroClimate(24.86, 67.0);

      // Verify that loading became true
      expect(provider.isLoading, isTrue);

      await fetchFuture;

      // Verify completed state
      expect(provider.isLoading, isFalse);
      expect(provider.thermalRiskIndex, equals(68.5));
      expect(provider.activeHeatMapData, isNotNull);
      expect(provider.activeHeatMapData?['status'], equals('success'));
      expect(provider.hasData, isTrue);
      expect(notificationStates, contains(true));
      expect(notificationStates.last, isFalse);
    });

    test('apparent temperature and infrastructure status calculations', () async {
      final mockService = FortyGuardService(useMock: true);
      final provider = ThermalProvider(fortyGuardService: mockService);

      await provider.fetchMicroClimate(24.8607, 67.0011);

      expect(provider.inspectedLat, equals(24.8607));
      expect(provider.inspectedLng, equals(67.0011));
      expect(provider.apparentTemperature, greaterThan(20.0));
      expect(provider.heatStressRiskLevel, isIn(['Low', 'Medium', 'High', 'Critical']));

      final asphalt = provider.asphaltInfrastructureStatus;
      expect(asphalt.status, isNotEmpty);
      expect(asphalt.description, isNotEmpty);
      expect(asphalt.surfaceTempC, greaterThan(provider.apparentTemperature));

      final grid = provider.utilityGridStatus;
      expect(grid.status, isNotEmpty);
      expect(grid.description, isNotEmpty);
    });
  });
}
