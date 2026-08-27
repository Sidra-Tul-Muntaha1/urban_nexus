import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_nexus/services/forty_guard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FortyGuardService tests', () {
    test('FortyGuardHttpClient injects api-key and content-type headers', () async {
      dotenv.testLoad(fileInput: 'FORTYGUARD_API_KEY=test_secret_key_123\n');

      late Map<String, String> capturedHeaders;
      late String capturedBody;
      late Uri capturedUrl;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedBody = request.body;
        capturedUrl = request.url;

        return http.Response(
          jsonEncode({
            'thermal_risk_index': 75.0,
            'risk_level': 'High',
            'recommended_interventions': ['Deploy misting systems'],
            'urban_heat_island_factor': 3.5,
            'cooling_degree_days': 20.0,
            'location': {'lat': 24.86, 'lng': 67.0},
            'timestamp': DateTime.now().toUtc().toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FortyGuardService(
        client: mockClient,
        useMock: false,
      );

      expect(service.apiKey, equals('test_secret_key_123'));

      final heatIntel = await service.getHeatIntelligence(24.86, 67.0);

      expect(capturedUrl.toString(), equals('https://api.fortyguard.com/v1/heat-intelligence'));
      expect(capturedHeaders['api-key'], equals('test_secret_key_123'));
      expect(capturedHeaders['Content-Type'], contains('application/json'));
      expect(jsonDecode(capturedBody), equals({'lat': 24.86, 'lng': 67.0}));
      expect(heatIntel.thermalRiskIndex, equals(75.0));
      expect(heatIntel.riskLevel, equals('High'));
    });

    test('FortyGuardService POST to /heatmap sends correct payload and headers', () async {
      dotenv.testLoad(fileInput: 'FORTYGUARD_API_KEY=another_test_key\n');

      late Map<String, String> capturedHeaders;
      late Uri capturedUrl;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedUrl = request.url;

        return http.Response(
          jsonEncode({'status': 'ok', 'grid_count': 100}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FortyGuardService(
        client: mockClient,
        useMock: false,
      );

      final response = await service.getHeatmap(24.86, 67.0, radiusKm: 10.0);

      expect(capturedUrl.toString(), equals('https://api.fortyguard.com/v1/heatmap'));
      expect(capturedHeaders['api-key'], equals('another_test_key'));
      expect(response['status'], equals('ok'));
    });

    test('FortyGuardService mock mode returns mock data without network calls', () async {
      final service = FortyGuardService(useMock: true);
      final result = await service.getHeatIntelligence(24.8607, 67.0011);

      expect(result.thermalRiskIndex, greaterThan(0));
      expect(result.recommendedInterventions, isNotEmpty);
    });

    test('testConnection sends POST request with api-key and content-type', () async {
      dotenv.testLoad(fileInput: 'FORTYGUARD_API_KEY=debug_api_key_xyz\n');

      late Map<String, String> capturedHeaders;
      late Uri capturedUrl;
      late String capturedBody;

      final mockClient = MockClient((request) async {
        capturedHeaders = request.headers;
        capturedUrl = request.url;
        capturedBody = request.body;

        return http.Response(
          '{"status":"connected","message":"API reachable"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = FortyGuardService(client: mockClient);
      await service.testConnection();

      expect(capturedUrl.toString(), equals('https://api.fortyguard.com/v1/heatmap'));
      expect(capturedHeaders['api-key'], equals('debug_api_key_xyz'));
      expect(capturedHeaders['Content-Type'], contains('application/json'));
      expect(jsonDecode(capturedBody), contains('lat'));
    });

    test('FortyGuardService throws FortyGuardApiException on 401 Unauthorized', () async {
      dotenv.testLoad(fileInput: 'FORTYGUARD_API_KEY=invalid_key\n');

      final mockClient = MockClient((request) async {
        return http.Response('{"error":"Invalid API Key"}', 401);
      });

      final service = FortyGuardService(client: mockClient, useMock: false);

      expect(
        () => service.getHeatIntelligence(24.8607, 67.0011),
        throwsA(isA<FortyGuardApiException>()),
      );
    });

    test('FortyGuardService throws FortyGuardAuthException when key is missing and useMock is false', () async {
      dotenv.testLoad(fileInput: 'FORTYGUARD_API_KEY=\n');

      final service = FortyGuardService(apiKey: '', useMock: false);

      expect(
        () => service.getHeatIntelligence(24.8607, 67.0011),
        throwsA(isA<FortyGuardAuthException>()),
      );
    });
  });
}
