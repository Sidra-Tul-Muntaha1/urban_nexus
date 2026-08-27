import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// ─── Custom exceptions ────────────────────────────────────────────────────────

/// Thrown when the device location cannot be determined and no fallback is available.
class LocationServiceException implements Exception {
  const LocationServiceException(this.message);
  final String message;

  @override
  String toString() => 'LocationServiceException: $message';
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Thin, crash-resilient wrapper around the [Geolocator] plugin.
///
/// Handles permission negotiation, strict timeout fallbacks, and always ensures
/// a valid geographic coordinate is returned for the map.
class LocationService {
  /// Default position for an Urban Heat Island zone (Dubai Central Zone: Lat 25.2048, Lng 55.2708)
  /// used when the device cannot supply a real location within the timeout window
  /// (browser permission delay, emulator, offline GPS, etc.).
  static const double fallbackLat = 25.2048;
  static const double fallbackLng = 55.2708;

  bool _isPermissionDenied = false;
  bool _isGpsDisabled = false;

  /// Whether the user has denied GPS location permissions.
  bool get isPermissionDenied => _isPermissionDenied;

  /// Whether device GPS location services are turned off.
  bool get isGpsDisabled => _isGpsDisabled;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns the device's current position with strict timeout protection.
  ///
  /// Falls back safely to last-known location or Dubai default coordinates (25.2048, 55.2708)
  /// rather than hanging or throwing, guaranteeing instant boot and map stability.
  Future<Position> getCurrentPosition({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);

      if (!serviceEnabled) {
        _isGpsDisabled = true;
        debugPrint('[LocationService] Location services disabled or timed out; using Dubai fallback.');
        return _fallbackPosition();
      }
      _isGpsDisabled = false;

      LocationPermission perm = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 2), onTimeout: () => LocationPermission.denied);

      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission()
            .timeout(timeout, onTimeout: () => LocationPermission.denied);
      }

      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _isPermissionDenied = true;
        debugPrint('[LocationService] Location permission denied; using Dubai fallback.');
        return _fallbackPosition();
      }
      _isPermissionDenied = false;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(
        timeout,
        onTimeout: () async {
          debugPrint('[LocationService] GPS timeout (${timeout.inSeconds}s); reading last-known position or fallback.');
          final last = await Geolocator.getLastKnownPosition();
          return last ?? _fallbackPosition();
        },
      );

      // Validate that returned coordinates are valid non-zero numbers
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        return _fallbackPosition();
      }

      return position;
    } catch (e) {
      debugPrint('[LocationService] Exception acquiring location ($e); using Dubai fallback.');
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return _fallbackPosition();
    }
  }

  /// A [Stream] of position updates filtered to fire only when the device
  /// has moved at least [distanceFilterMeters] metres.
  Stream<Position> streamPosition({int distanceFilterMeters = 50}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  /// Creates a [Position] at the fallback Dubai coordinates with zeroed metadata.
  Position _fallbackPosition() => Position(
        latitude: fallbackLat,
        longitude: fallbackLng,
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
