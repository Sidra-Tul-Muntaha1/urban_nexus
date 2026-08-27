import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/heat_intelligence.dart';
import '../services/forty_guard_service.dart';
import '../services/location_service.dart';

/// Central state provider connecting FortyGuardService to the UI.
///
/// Holds:
/// - `isLoading`: boolean state indicator
/// - `thermalRiskIndex`: current calculated/returned Thermal Risk Index
/// - `activeHeatMapData`: map containing active raw heatmap payload
/// - `fetchMicroClimate(lat, lng)`: queries FortyGuard API, updates state, and calls `notifyListeners()`.
class ThermalProvider extends ChangeNotifier {
  ThermalProvider({
    required FortyGuardService fortyGuardService,
    LocationService? locationService,
  })  : _fortyGuard = fortyGuardService,
        _location = locationService ?? LocationService();

  final FortyGuardService _fortyGuard;
  final LocationService _location;

  // ── State Variables ────────────────────────────────────────────────────────

  bool _isLoading = false;
  double? _thermalRiskIndex;
  Map<String, dynamic>? _activeHeatMapData;
  HeatIntelligence? _heatData;
  Position? _currentPosition;
  String? _errorMessage;

  // ── Simulation State ───────────────────────────────────────────────────────

  static const double _maxCoolingEffect = 6.0;
  double _simulationFactor = 0.0;

  double? _inspectedLat;
  double? _inspectedLng;

  // ── Getters ────────────────────────────────────────────────────────────────

  /// Loading state indicator.
  bool get isLoading => _isLoading;

  /// Latitude of the currently inspected block on the map.
  double? get inspectedLat => _inspectedLat ?? _currentPosition?.latitude;

  /// Longitude of the currently inspected block on the map.
  double? get inspectedLng => _inspectedLng ?? _currentPosition?.longitude;

  /// Current Thermal Risk Index (0 - 100).
  double? get thermalRiskIndex => _thermalRiskIndex ?? _heatData?.thermalRiskIndex;

  /// Alias for thermal risk index.
  double? get currentThermalRiskIndex => thermalRiskIndex;

  /// Raw active heatmap data object returned by FortyGuard.
  Map<String, dynamic>? get activeHeatMapData => _activeHeatMapData;

  /// Parsed HeatIntelligence payload including recommendations.
  HeatIntelligence? get heatData => _heatData;
  HeatIntelligence? get heatIntelligence => _heatData;

  /// User device GPS position.
  Position? get currentPosition => _currentPosition;

  /// Last error message if any.
  String? get errorMessage => _errorMessage;

  /// Whether valid thermal data is available.
  bool get hasData => _heatData != null || _activeHeatMapData != null;

  /// Whether the last fetch resulted in an error.
  bool get hasError => _errorMessage != null;

  /// Whether GPS location was denied or disabled.
  bool get isGpsDenied => _location.isPermissionDenied || _location.isGpsDisabled;

  /// Whether an urban cooling simulation is currently active.
  bool get isSimulationActive => _simulationFactor > 0.05;

  /// Greening simulation factor (0.0 to 1.0).
  double get simulationFactor => _simulationFactor;

  /// Simulated temperature reduction in °C.
  double get simulatedTempDrop => _simulationFactor * _maxCoolingEffect;

  /// Toggles or sets the cooling mitigation scenario.
  /// When active, applies a targeted 3.8°C cooling drop.
  void toggleSimulation([bool? enable]) {
    final target = enable ?? !isSimulationActive;
    // Exactly 3.8°C reduction (3.8 / 6.0 = 0.6333)
    setSimulationFactor(target ? (3.8 / _maxCoolingEffect) : 0.0);
  }

  /// Calculated apparent temperature in °C for the inspected block.
  double get apparentTemperature {
    final tri = thermalRiskIndex ?? 65.0;
    final uhi = _heatData?.urbanHeatIslandFactor ?? 2.8;
    final temp = (27.0 + (tri * 0.22) + (uhi * 0.9)) - simulatedTempDrop;
    return temp.clamp(16.0, 58.0);
  }

  /// Heat stress risk classification: "Low", "Medium", "High", "Critical".
  String get heatStressRiskLevel {
    final tri = thermalRiskIndex ?? 60.0;
    if (tri >= 80) return 'Critical';
    if (tri >= 60) return 'High';
    if (tri >= 40) return 'Medium';
    return 'Low';
  }

  /// Infrastructure Analysis: Public asphalt softening and road temperature.
  ({String status, String description, double surfaceTempC, bool isAlert})
      get asphaltInfrastructureStatus {
    final apparent = apparentTemperature;
    final surfaceTemp = apparent + 14.5;
    if (surfaceTemp >= 52.0) {
      return (
        status: 'Softening Risk: High',
        description:
            'Road surface ~${surfaceTemp.toStringAsFixed(1)}°C. High risk of rutting & bitumen shear under heavy axles.',
        surfaceTempC: surfaceTemp,
        isAlert: true,
      );
    } else if (surfaceTemp >= 42.0) {
      return (
        status: 'Heat Retention: Elevated',
        description:
            'Road surface ~${surfaceTemp.toStringAsFixed(1)}°C. Strong night-time thermal radiation re-emission.',
        surfaceTempC: surfaceTemp,
        isAlert: false,
      );
    }
    return (
      status: 'Condition: Stable',
      description:
          'Road surface ~${surfaceTemp.toStringAsFixed(1)}°C. Pavement operating within thermal tolerance.',
      surfaceTempC: surfaceTemp,
      isAlert: false,
    );
  }

  /// Infrastructure Analysis: Electrical utility grid & substation HVAC load.
  ({String status, String description, int loadSurgePercent, bool isAlert})
      get utilityGridStatus {
    final tri = thermalRiskIndex ?? 60.0;
    if (tri >= 75) {
      final surge = (15 + (tri - 75) * 0.8).round();
      return (
        status: 'Grid Stress: High Demand',
        description:
            'Substation cooling peak (+$surge% HVAC load surge). Transformer thermal derating advised.',
        loadSurgePercent: surge,
        isAlert: true,
      );
    } else if (tri >= 45) {
      final surge = (5 + (tri - 45) * 0.35).round();
      return (
        status: 'Grid Stress: Moderate',
        description:
            'AC cooling demand up +$surge%. Local distribution transformers operating normally.',
        loadSurgePercent: surge,
        isAlert: false,
      );
    }
    return (
      status: 'Grid Stress: Nominal',
      description:
          'Standard base-load operation. Feeder temperature within safe capacity limits.',
      loadSurgePercent: 0,
      isAlert: false,
    );
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Calls FortyGuardService for [lat], [lng], updates state variables,
  /// and notifies all listening UI widgets.
  Future<void> fetchMicroClimate(double lat, double lng) async {
    _inspectedLat = lat;
    _inspectedLng = lng;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Query heat intelligence & interventions
      final intel = await _fortyGuard.getHeatIntelligence(lat, lng);
      _heatData = intel;
      _thermalRiskIndex = intel.thermalRiskIndex;

      // 2. Query heatmap grid metrics
      final heatmapData = await _fortyGuard.getHeatmap(lat, lng);
      _activeHeatMapData = heatmapData;

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ThermalProvider] Error fetching micro-climate: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initial entry point that resolves device location and fetches micro-climate.
  Future<void> initialize() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Resolve position with strict timeout fallback to Dubai UHI test zone (25.2048, 55.2708)
      Position pos;
      try {
        pos = await _location.getCurrentPosition(
          timeout: const Duration(seconds: 4),
        );
      } catch (locErr) {
        debugPrint('[ThermalProvider] Location resolution notice ($locErr); defaulting to Dubai.');
        pos = Position(
          latitude: LocationService.fallbackLat,
          longitude: LocationService.fallbackLng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }

      _currentPosition = pos;
      _inspectedLat = pos.latitude;
      _inspectedLng = pos.longitude;

      // 2. Fetch micro-climate intelligence
      await fetchMicroClimate(pos.latitude, pos.longitude);
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[ThermalProvider] Initialization error: $e');
    } finally {
      // Strictly guarantee that isLoading is false and listeners are notified
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Re-fetches data for the current position.
  Future<void> refresh() async {
    try {
      _currentPosition ??= await _location.getCurrentPosition();
      if (_currentPosition != null) {
        await fetchMicroClimate(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Updates simulation slider factor and triggers heatmap visual refresh.
  void setSimulationFactor(double factor) {
    final clamped = factor.clamp(0.0, 1.0);
    if ((clamped - _simulationFactor).abs() < 0.001) return;
    _simulationFactor = clamped;
    notifyListeners();
  }

  // ── GeoJSON Generation for Mapbox ──────────────────────────────────────────

  /// Generates a GeoJSON FeatureCollection formatted for the Mapbox heatmap layer.
  String buildThermalGeoJson() {
    final pos = _currentPosition;
    final tri = thermalRiskIndex;

    if (pos == null || tri == null) {
      return '{"type":"FeatureCollection","features":[]}';
    }

    final rng = math.Random(42);
    final features = <Map<String, dynamic>>[];

    final coolingOffset = _simulationFactor * _maxCoolingEffect;
    final baseTemp = (18.0 + tri * 0.34) - coolingOffset;

    // Concentric thermal dispersion rings
    const rings = 4;
    for (int ring = 0; ring < rings; ring++) {
      final ringRadius = (ring + 1) * 0.0045;
      final pointCount = 8 + ring * 4;

      for (int i = 0; i < pointCount; i++) {
        final angle = (i / pointCount) * 2 * math.pi;
        final jitter = (rng.nextDouble() - 0.5) * 0.0012;

        final lat = pos.latitude + ringRadius * math.cos(angle) + jitter;
        final lng = pos.longitude + ringRadius * math.sin(angle) + jitter;

        final decay = 1.0 - ring * 0.18;
        final noise = (rng.nextDouble() - 0.38) * 5.5;
        final temperature = (baseTemp * decay + noise).clamp(18.0, 52.0);

        features.add(_feature(lng, lat, temperature));
      }
    }

    // High intensity epicenter
    features.add(_feature(
      pos.longitude,
      pos.latitude,
      (baseTemp + 2.5).clamp(18.0, 52.0),
    ));

    // Cool corridor simulation points
    final coolLat = pos.latitude - 0.012;
    final coolLng = pos.longitude - 0.009;
    for (int i = 0; i < 6; i++) {
      final spread = (rng.nextDouble() - 0.5) * 0.004;
      features.add(_feature(
        coolLng + spread,
        coolLat + spread,
        (18.0 + rng.nextDouble() * 8).clamp(18.0, 30.0),
      ));
    }

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  static Map<String, dynamic> _feature(
    double lng,
    double lat,
    double tempC,
  ) {
    final intensity = ((tempC - 18.0) / 34.0).clamp(0.0, 1.0);
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [lng, lat],
      },
      'properties': {
        'temperature': tempC,
        'intensity': intensity,
      },
    };
  }
}
