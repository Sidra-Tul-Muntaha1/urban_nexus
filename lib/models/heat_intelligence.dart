/// Typed representation of a FortyGuard Heat Intelligence API response.
///
/// Deserialised from the JSON payload returned by
/// `POST /v1/heat-intelligence`.
class HeatIntelligence {
  const HeatIntelligence({
    required this.thermalRiskIndex,
    required this.riskLevel,
    required this.recommendedInterventions,
    required this.urbanHeatIslandFactor,
    required this.coolingDegreeDays,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  /// 0–100 composite score; higher = greater thermal stress.
  final double thermalRiskIndex;

  /// Human-readable severity band: "Low" | "Moderate" | "High" | "Critical".
  final String riskLevel;

  /// Ordered list of actionable recommendations from the FortyGuard engine.
  final List<String> recommendedInterventions;

  /// Degrees Celsius above rural baseline caused by the urban heat island.
  final double urbanHeatIslandFactor;

  /// Cumulative cooling degree-days for the current period.
  final double coolingDegreeDays;

  /// Request latitude echoed back by the API.
  final double latitude;

  /// Request longitude echoed back by the API.
  final double longitude;

  /// UTC timestamp of when the intelligence snapshot was generated.
  final DateTime timestamp;

  // ─── Deserialization ────────────────────────────────────────────────────────

  factory HeatIntelligence.fromJson(Map<String, dynamic> json) {
    // Interventions may arrive as a JSON array of strings.
    final rawInterventions = json['recommended_interventions'];
    final interventions = rawInterventions is List
        ? List<String>.from(rawInterventions.map((e) => e.toString()))
        : <String>[];

    final location = json['location'] as Map<String, dynamic>? ?? {};

    return HeatIntelligence(
      thermalRiskIndex: (json['thermal_risk_index'] as num).toDouble(),
      riskLevel: json['risk_level'] as String? ?? 'Unknown',
      recommendedInterventions: interventions,
      urbanHeatIslandFactor:
          (json['urban_heat_island_factor'] as num? ?? 0).toDouble(),
      coolingDegreeDays:
          (json['cooling_degree_days'] as num? ?? 0).toDouble(),
      latitude: (location['lat'] as num? ?? 0).toDouble(),
      longitude: (location['lng'] as num? ?? 0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now().toUtc(),
    );
  }

  // ─── Serialization (useful for local caching) ───────────────────────────────

  Map<String, dynamic> toJson() => {
        'thermal_risk_index': thermalRiskIndex,
        'risk_level': riskLevel,
        'recommended_interventions': recommendedInterventions,
        'urban_heat_island_factor': urbanHeatIslandFactor,
        'cooling_degree_days': coolingDegreeDays,
        'location': {'lat': latitude, 'lng': longitude},
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  String toString() =>
      'HeatIntelligence(index: $thermalRiskIndex, level: $riskLevel, '
      'interventions: ${recommendedInterventions.length})';
}
