import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../providers/thermal_provider.dart';

/// Layer / source IDs — kept as constants to avoid typo-driven runtime errors.
const _kSourceId = 'urban-nexus-thermal-source';
const _kHeatmapLayerId = 'urban-nexus-thermal-heatmap';

/// Full-screen Mapbox map with a live thermal heatmap overlay.
///
/// Lifecycle:
/// 1. [MapWidget] is created with the Mapbox Dark style.
/// 2. [_onMapCreated] stores the [MapboxMap] reference and enables the
///    user-location puck via [LocationComponentSettings].
/// 3. [_onStyleLoaded] adds an empty GeoJSON source + heatmap layer with the
///    red→blue colour ramp, then populates it if data is already available.
/// 4. The widget subscribes to [ThermalProvider] via [addListener]; every
///    `notifyListeners` call updates the source data and, on first load, flies
///    the camera to the user's position.
///
/// > **Token note**: Mapbox access token must be set before this widget is
/// > rendered — see `main.dart` → `MapboxOptions.setAccessToken(...)`.
class ThermalMap extends StatefulWidget {
  const ThermalMap({
    super.key,
    this.onMapTap,
  });

  /// Callback triggered when the user taps on the map, returning (lat, lng).
  final void Function(double lat, double lng)? onMapTap;

  @override
  State<ThermalMap> createState() => _ThermalMapState();
}

class _ThermalMapState extends State<ThermalMap> {
  MapboxMap? _mapboxMap;

  /// True once the GeoJSON source + heatmap layer have been added to the style.
  bool _heatmapReady = false;

  /// Prevents the initial camera fly from running more than once.
  bool _hasFlewToUser = false;

  // ── Widget lifecycle ───────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe whenever the dependency tree changes.
    final provider = Provider.of<ThermalProvider>(context, listen: false);
    provider
      ..removeListener(_onProviderChanged)
      ..addListener(_onProviderChanged);
  }

  @override
  void dispose() {
    // Safe: will no-op if the provider has already been disposed.
    try {
      final provider = Provider.of<ThermalProvider>(context, listen: false);
      provider.removeListener(_onProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  // ── Provider listener ──────────────────────────────────────────────────────

  Future<void> _onProviderChanged() async {
    if (!mounted || _mapboxMap == null || !_heatmapReady) return;

    final provider = Provider.of<ThermalProvider>(context, listen: false);

    if (provider.hasData) {
      await _updateHeatmapSource(provider.buildThermalGeoJson());
    }

    if (!_hasFlewToUser && provider.currentPosition != null) {
      _hasFlewToUser = true;
      await _flyTo(
        lat: provider.currentPosition!.latitude,
        lng: provider.currentPosition!.longitude,
      );
    }
  }

  // ── Map callbacks ──────────────────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    // Register map tap listener for micro-climate coordinate inspection
    // ignore: deprecated_member_use
    map.setOnMapTapListener((gestureContext) {
      final lat = gestureContext.point.coordinates.lat.toDouble();
      final lng = gestureContext.point.coordinates.lng.toDouble();
      widget.onMapTap?.call(lat, lng);
    });

    // Enable user-location puck with a pulsing ring in the app's cyan accent.
    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: 0xFF00D4FF, // ARGB — cyan accent
          pulsingMaxRadius: 60.0,
        ),
      );
    } catch (e) {
      debugPrint('[ThermalMap] location puck error: $e');
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    if (_mapboxMap == null) return;

    // Cache provider reference synchronously before any awaits.
    final provider = Provider.of<ThermalProvider>(context, listen: false);

    await _setupHeatmapLayer();

    // If ThermalDataProvider already has data (loaded before style), render it.
    if (provider.hasData) {
      await _updateHeatmapSource(provider.buildThermalGeoJson());
    }
    if (!_hasFlewToUser && provider.currentPosition != null) {
      _hasFlewToUser = true;
      await _flyTo(
        lat: provider.currentPosition!.latitude,
        lng: provider.currentPosition!.longitude,
      );
    }
  }

  // ── Heatmap setup ──────────────────────────────────────────────────────────

  /// Adds an empty [GeoJsonSource] and a [HeatmapLayer] to the current style,
  /// then applies the thermal colour ramp and weight expression via
  /// [MapboxMap.style.setStyleLayerProperty].
  Future<void> _setupHeatmapLayer() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      // ── GeoJSON source (empty until data arrives) ──
      await map.style.addSource(GeoJsonSource(
        id: _kSourceId,
        data: '{"type":"FeatureCollection","features":[]}',
      ));

      // ── Heatmap layer ──
      await map.style.addLayer(HeatmapLayer(
        id: _kHeatmapLayerId,
        sourceId: _kSourceId,
        heatmapOpacity: 0.88,
        heatmapRadius: 72.0,    // pixel spread per point
        heatmapIntensity: 1.6,  // global multiplier
      ));

      // ── Colour ramp: cool (blue) → warm (yellow) → hot (red) ──
      // Interpolates by `heatmap-density` (0 = empty → 1 = dense).
      await map.style.setStyleLayerProperty(
        _kHeatmapLayerId,
        'heatmap-color',
        [
          'interpolate', ['linear'], ['heatmap-density'],
          0,    'rgba(0,   212, 255, 0)',    // transparent at zero density
          0.10, 'rgba(0,   100, 255, 0.4)', // cool blue
          0.30, 'rgba(0,   200, 150, 0.6)', // teal transition
          0.55, 'rgba(255, 220,   0, 0.80)', // warm yellow
          0.75, 'rgba(255, 107,  53, 0.90)', // orange
          1.0,  'rgba(255,  30,  30, 1.0)', // critical red
        ],
      );

      // ── Weight expression: driven by the `intensity` property (0–1) ──
      await map.style.setStyleLayerProperty(
        _kHeatmapLayerId,
        'heatmap-weight',
        ['interpolate', ['linear'], ['get', 'intensity'], 0, 0, 1, 1],
      );

      // ── Radius expression: zoom-adaptive spread ──
      await map.style.setStyleLayerProperty(
        _kHeatmapLayerId,
        'heatmap-radius',
        ['interpolate', ['linear'], ['zoom'], 8, 20, 13, 60, 16, 120],
      );

      _heatmapReady = true;
    } catch (e) {
      debugPrint('[ThermalMap] layer setup error: $e');
    }
  }

  // ── Source update ──────────────────────────────────────────────────────────

  /// Replaces the GeoJSON source data with a fresh [geoJson] string.
  Future<void> _updateHeatmapSource(String geoJson) async {
    final map = _mapboxMap;
    if (map == null) return;
    try {
      await map.style.setStyleSourceProperty(_kSourceId, 'data', geoJson);
    } catch (e) {
      debugPrint('[ThermalMap] source update error: $e');
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────────

  Future<void> _flyTo({required double lat, required double lng}) async {
    final map = _mapboxMap;
    if (map == null) return;
    try {
      await map.flyTo(
        CameraOptions(
          // Mapbox uses [longitude, latitude] order for Position.
          center: Point(coordinates: Position(lng, lat)),
          zoom: 13.5,
          pitch: 38.0,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 2800, startDelay: 200),
      );
    } catch (e) {
      debugPrint('[ThermalMap] flyTo error: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('thermal-mapbox-widget'),
      styleUri: MapboxStyles.DARK,
      // Default viewport centres on Karachi; will fly to user location on load.
      viewport: CameraViewportState(
        center: Point(coordinates: Position(67.0011, 24.8607)),
        zoom: 11.0,
        pitch: 30.0,
      ),
      // ignore: deprecated_member_use
      onTapListener: (gestureContext) {
        final lat = gestureContext.point.coordinates.lat.toDouble();
        final lng = gestureContext.point.coordinates.lng.toDouble();
        widget.onMapTap?.call(lat, lng);
      },
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
    );
  }
}
