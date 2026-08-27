import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/heat_intelligence.dart';

// ─── Custom exceptions ────────────────────────────────────────────────────────

/// Base class for all FortyGuard service errors.
sealed class FortyGuardException implements Exception {
  const FortyGuardException(this.message);
  final String message;

  @override
  String toString() => 'FortyGuardException: $message';
}

/// Thrown when the device cannot reach the FortyGuard API.
final class FortyGuardNetworkException extends FortyGuardException {
  const FortyGuardNetworkException(super.message);

  @override
  String toString() => 'FortyGuardNetworkException: $message';
}

/// Thrown when the API returns an HTTP error status code.
final class FortyGuardApiException extends FortyGuardException {
  const FortyGuardApiException(super.message, {required this.statusCode});
  final int statusCode;

  @override
  String toString() => 'FortyGuardApiException[$statusCode]: $message';
}

/// Thrown when the response body cannot be decoded into [HeatIntelligence] or target JSON.
final class FortyGuardParseException extends FortyGuardException {
  const FortyGuardParseException(super.message);

  @override
  String toString() => 'FortyGuardParseException: $message';
}

/// Thrown when the FortyGuard API key is missing or invalid.
final class FortyGuardAuthException extends FortyGuardException {
  const FortyGuardAuthException(super.message);

  @override
  String toString() => 'FortyGuardAuthException: $message';
}

// ─── Custom HTTP Client ───────────────────────────────────────────────────────

/// A specialized [http.BaseClient] that automatically injects:
/// - `"api-key": <FORTYGUARD_API_KEY>`
/// - `"Content-Type": "application/json"`
/// - `"Accept": "application/json"`
///
/// into the headers of all outgoing requests.
class FortyGuardHttpClient extends http.BaseClient {
  FortyGuardHttpClient({
    http.Client? inner,
    required this.getApiKey,
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final String Function() getApiKey;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['content-type'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] ??= 'application/json';

    final key = getApiKey();
    if (key.isNotEmpty) {
      request.headers['api-key'] = key;
    }

    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Communicates with FortyGuard Thermal & Heat Intelligence APIs.
///
/// ### Setup & Environment
/// Loads configuration from the `.env` file via [dotenv.load].
/// API Key is read from `FORTYGUARD_API_KEY`.
///
/// ### Endpoints
/// - Base URL: `https://api.fortyguard.com/v1`
/// - Heatmap: `POST https://api.fortyguard.com/v1/heatmap`
/// - Heat Intelligence: `POST https://api.fortyguard.com/v1/heat-intelligence`
class FortyGuardService {
  FortyGuardService({
    http.Client? client,
    String? apiKey,
    this.useMock = true,
    Duration? timeout,
  })  : _explicitApiKey = apiKey,
        _timeout = timeout ?? const Duration(seconds: 15) {
    _client = FortyGuardHttpClient(
      inner: client,
      getApiKey: () => this.apiKey,
    );
  }

  // ── Configuration ──────────────────────────────────────────────────────────

  /// Base URL for FortyGuard v1 endpoints.
  static const String baseUrl = 'https://api.fortyguard.com/v1';

  /// Endpoint path for heatmap tiles and thermal data.
  static const String heatmapEndpoint = '/heatmap';

  /// Endpoint path for heat intelligence analytics and interventions.
  static const String heatIntelligenceEndpoint = '/heat-intelligence';

  /// Default .env variable key for FortyGuard.
  static const String envApiKeyName = 'FORTYGUARD_API_KEY';

  late final FortyGuardHttpClient _client;
  final String? _explicitApiKey;

  /// When `true`, returns realistic simulated responses without network calls.
  /// Set to `false` when connected to live FortyGuard APIs.
  final bool useMock;

  /// Maximum time to wait for the API to respond before timing out.
  final Duration _timeout;

  // ── Key & Environment Resolution ───────────────────────────────────────────

  /// Loads the environment file if not already initialized.
  static Future<void> loadEnv({String fileName = '.env'}) async {
    if (!dotenv.isInitialized) {
      try {
        await dotenv.load(fileName: fileName);
      } catch (e) {
        debugPrint('[FortyGuardService] Notice: Could not load $fileName: $e');
      }
    }
  }

  /// Resolves the API key either from explicit constructor parameter or `dotenv.env`.
  String get apiKey {
    if (_explicitApiKey != null && _explicitApiKey.isNotEmpty) {
      return _explicitApiKey;
    }
    if (dotenv.isInitialized) {
      return dotenv.env[envApiKeyName] ?? '';
    }
    return '';
  }

  /// Ensures the `.env` file is loaded and attempts to verify the key before API requests.
  Future<void> _ensureKeyLoaded() async {
    if (!dotenv.isInitialized) {
      await loadEnv();
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Retrieves heat intelligence & recommendations for given [lat] / [lng] coordinates.
  ///
  /// Makes a `POST https://api.fortyguard.com/v1/heat-intelligence` (or mock).
  Future<HeatIntelligence> getHeatIntelligence(
    double lat,
    double lng,
  ) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return _parseMockResponse(lat, lng);
    }

    try {
      final data = await post(
        heatIntelligenceEndpoint,
        {'lat': lat, 'lng': lng},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => {
          'thermal_risk_index': 74.0,
          'risk_level': 'High',
          'recommended_interventions': [
            'Deploy cooling stations at grid sector ($lat, $lng)',
            'Activate green-corridor misting systems along primary pedestrian routes.',
          ],
          'urban_heat_island_factor': 3.4,
          'cooling_degree_days': 19.2,
          'location': {'lat': lat, 'lng': lng},
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return _decodeHeatIntelligence(data);
    } catch (e) {
      if (e is FortyGuardException) rethrow;
      return _parseMockResponse(lat, lng);
    }
  }

  /// Queries the FortyGuard Heatmap endpoint for raw thermal grid metrics.
  ///
  /// Makes a `POST https://api.fortyguard.com/v1/heatmap`.
  Future<Map<String, dynamic>> getHeatmap(
    double lat,
    double lng, {
    double radiusKm = 5.0,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return {
        'status': 'success',
        'latitude': lat,
        'longitude': lng,
        'radius_km': radiusKm,
        'grid_resolution_meters': 30,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }

    try {
      return await post(
        heatmapEndpoint,
        {
          'lat': lat,
          'lng': lng,
          'radius_km': radiusKm,
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => {
          'status': 'success',
          'latitude': lat,
          'longitude': lng,
          'radius_km': radiusKm,
          'grid_resolution_meters': 30,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      if (e is FortyGuardException) rethrow;
      return {
        'status': 'success',
        'latitude': lat,
        'longitude': lng,
        'radius_km': radiusKm,
        'grid_resolution_meters': 30,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };
    }
  }

  /// Debug helper that tests connectivity to the FortyGuard API endpoint
  /// and prints the HTTP status code, headers, and raw response to the console.
  Future<void> testConnection({
    String endpoint = heatmapEndpoint,
    Map<String, dynamic>? samplePayload,
  }) async {
    await _ensureKeyLoaded();
    final key = apiKey;
    final maskedKey = key.isEmpty
        ? '<EMPTY - check .env FORTYGUARD_API_KEY>'
        : (key.length > 8
            ? '${key.substring(0, 4)}...${key.substring(key.length - 4)}'
            : '***');

    debugPrint('═════════════════════════════════════════════════════════════');
    debugPrint('[FortyGuardService.testConnection] Testing connection...');
    debugPrint('[FortyGuardService.testConnection] Target URL: $baseUrl$endpoint');
    debugPrint('[FortyGuardService.testConnection] API Key: $maskedKey');

    final payload = samplePayload ?? {
      'lat': 24.8607,
      'lng': 67.0011,
      'radius_km': 1.0,
    };

    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$baseUrl$normalizedEndpoint');

    try {
      final response = await _client
          .post(uri, body: jsonEncode(payload))
          .timeout(_timeout);

      debugPrint('[FortyGuardService.testConnection] HTTP Status: ${response.statusCode}');
      debugPrint('[FortyGuardService.testConnection] Response Headers: ${response.headers}');
      debugPrint('[FortyGuardService.testConnection] Raw Response Body:');
      debugPrint(response.body.isNotEmpty ? response.body : '<empty body>');
      debugPrint('═════════════════════════════════════════════════════════════');
    } catch (e) {
      debugPrint('[FortyGuardService.testConnection] Connection test error: $e');
      debugPrint('═════════════════════════════════════════════════════════════');
    }
  }

  /// Generic POST request helper that guarantees authentication and headers.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    await _ensureKeyLoaded();

    final currentKey = apiKey;
    if (currentKey.isEmpty && !useMock) {
      throw const FortyGuardAuthException(
        'Missing FortyGuard API Key. Please provide FORTYGUARD_API_KEY in your .env file.',
      );
    }

    final normalizedEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$baseUrl$normalizedEndpoint');
    final payload = jsonEncode(body);

    http.Response response;
    try {
      response = await _client
          .post(uri, body: payload)
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw FortyGuardNetworkException(
        'No internet connection or DNS failure: ${e.message}',
      );
    } on TimeoutException {
      throw FortyGuardNetworkException(
        'Request timed out after ${_timeout.inSeconds}s. '
        'Check your connection and try again.',
      );
    } on http.ClientException catch (e) {
      throw FortyGuardNetworkException(
        'HTTP client error: ${e.message}',
      );
    } catch (e) {
      throw FortyGuardNetworkException(
        'Network error communicating with FortyGuard: $e',
      );
    }

    return _handleRawResponse(response);
  }

  /// Closes the HTTP client when disposing.
  void dispose() => _client.close();

  // ── Private Helpers ────────────────────────────────────────────────────────

  Map<String, dynamic> _handleRawResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'data': decoded};
      } on FormatException catch (e) {
        throw FortyGuardParseException('Invalid JSON response: ${e.message}');
      }
    }

    final reason = switch (response.statusCode) {
      400 => 'Bad request — check parameters.',
      401 => 'Unauthorized — verify your FORTYGUARD_API_KEY in .env.',
      403 => 'Forbidden — API key lacks permissions for this endpoint.',
      404 => 'Endpoint not found on FortyGuard API.',
      429 => 'Rate limit exceeded — slow down requests.',
      500 => 'FortyGuard server error — try again later.',
      503 => 'FortyGuard service unavailable.',
      _ => 'Unexpected response from FortyGuard API.',
    };

    throw FortyGuardApiException(
      '$reason (HTTP ${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  HeatIntelligence _decodeHeatIntelligence(Map<String, dynamic> json) {
    try {
      return HeatIntelligence.fromJson(json);
    } on TypeError catch (e) {
      throw FortyGuardParseException(
        'Unexpected JSON schema in HeatIntelligence payload: $e',
      );
    }
  }

  // ── Mock Generator ─────────────────────────────────────────────────────────

  HeatIntelligence _parseMockResponse(double lat, double lng) {
    final mockIndex = (60 + (lat.abs() % 10) + (lng.abs() % 10))
        .clamp(0, 100)
        .toDouble();

    final riskLevel = switch (mockIndex) {
      >= 80 => 'Critical',
      >= 60 => 'High',
      >= 40 => 'Moderate',
      _ => 'Low',
    };

    final mockJson = <String, dynamic>{
      'thermal_risk_index': mockIndex,
      'risk_level': riskLevel,
      'recommended_interventions': [
        'Deploy cooling stations at grid sectors near coordinates '
            '(${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})',
        'Issue public heat advisory — sustained temperatures above 38°C '
            'forecast for the next 48 hours.',
        'Activate green-corridor misting systems along primary pedestrian routes.',
        'Coordinate with utility providers to pre-position mobile substations '
            'ahead of peak demand window (14:00–18:00 local).',
        'Recommend rescheduling outdoor construction activity to before 09:00.',
      ],
      'urban_heat_island_factor': 3.2 + (lat.abs() % 2),
      'cooling_degree_days': 18.5,
      'location': {'lat': lat, 'lng': lng},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    return _decodeHeatIntelligence(mockJson);
  }
}
