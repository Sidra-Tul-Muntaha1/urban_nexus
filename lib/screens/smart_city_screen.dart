import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/thermal_provider.dart';
import '../services/location_service.dart';
import '../widgets/app_notice.dart';
import '../widgets/glass_card.dart';
import '../widgets/thermal_map.dart';

/// Smart City View — interactive thermal intelligence map with block inspection.
///
/// Features:
/// 1. Native Mapbox GL map on mobile (Android/iOS) + elegant thermal mesh grid view on Web/Desktop.
/// 2. Interactive map tap: tapping any sector triggers [ThermalProvider.fetchMicroClimate].
/// 3. Collapsible inspection card (closed by default on app boot to ensure maximum heatmap visibility):
///    - Compact bar showing ambient temperature and risk index.
///    - Expandable capital interventions & infrastructure analytics panel.
///    - Urban Greening Simulation Slider for live cooling projections.
class SmartCityScreen extends StatefulWidget {
  const SmartCityScreen({super.key});

  @override
  State<SmartCityScreen> createState() => _SmartCityScreenState();
}

class _SmartCityScreenState extends State<SmartCityScreen> {
  bool _showInterventions = false;

  @override
  void initState() {
    super.initState();
    // Ensure all intervention modal and expansion flags are false on boot
    _showInterventions = false;
  }

  /// Determines if the current platform requires the mesh grid preview
  /// (e.g. Web and Desktop where native Mapbox platform views are not supported).
  bool _shouldUseMockGrid() {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. Map Layer (Native Mapbox on Mobile / Mesh Grid on Web & Desktop) ──
          Consumer<ThermalProvider>(
            builder: (context, thermal, _) {
              if (_shouldUseMockGrid()) {
                return _MockThermalGridMap(
                  thermal: thermal,
                  onMapTap: (lat, lng) {
                    thermal.fetchMicroClimate(lat, lng);
                  },
                );
              }
              return ThermalMap(
                onMapTap: (lat, lng) {
                  thermal.fetchMicroClimate(lat, lng);
                },
              );
            },
          ),

          // ── 2. Top Header Bar ──────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Consumer<ThermalProvider>(
                builder: (context, thermal, child) =>
                    _TopHeader(isLive: thermal.hasData),
              ),
            ),
          ),

          // ── 3. Heat Index Legend (Top-Right) ───────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 88,
            right: 16,
            child: const _HeatLegend(),
          ),

          // ── 4. Bottom Inspection HUD (Compact by default on initialization) ────
          Positioned(
            left: 14,
            right: 14,
            bottom: bottomPad + 92,
            child: Consumer<ThermalProvider>(
              builder: (context, thermal, child) {
                if (_showInterventions) {
                  return _FloatingInspectionCard(
                    thermal: thermal,
                    onCollapse: () => setState(() => _showInterventions = false),
                  );
                }
                return _CompactInspectionBar(
                  thermal: thermal,
                  onExpand: () => setState(() => _showInterventions = true),
                );
              },
            ),
          ),

          // ── 5. Full-Screen Initial Loading Overlay ─────────────────
          Consumer<ThermalProvider>(
            builder: (context, thermal, child) {
              if (thermal.isLoading && !thermal.hasData) {
                return const _LoadingOverlay();
              }
              return const SizedBox.shrink();
            },
          ),

          // ── 6. Error Banner ────────────────────────────────────────
          Consumer<ThermalProvider>(
            builder: (context, thermal, child) {
              if (thermal.hasError &&
                  !thermal.isLoading &&
                  thermal.errorMessage != null) {
                return Positioned(
                  top: MediaQuery.of(context).padding.top + 80,
                  left: 16,
                  right: 16,
                  child: _ErrorBanner(message: thermal.errorMessage!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

// ─── Compact Bottom Inspection Bar ───────────────────────────────────────────

class _CompactInspectionBar extends StatelessWidget {
  const _CompactInspectionBar({
    required this.thermal,
    required this.onExpand,
  });

  final ThermalProvider thermal;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final lat = thermal.inspectedLat ?? LocationService.fallbackLat;
    final lng = thermal.inspectedLng ?? LocationService.fallbackLng;
    final apparent = thermal.apparentTemperature;
    final riskLevel = thermal.heatStressRiskLevel;
    final drop = thermal.simulatedTempDrop;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderColor: Colors.white.withValues(alpha: 0.15),
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.88),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_searching_rounded,
              color: Color(0xFF00D4FF),
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${lat.toStringAsFixed(3)}° N, ${lng.toStringAsFixed(3)}° E',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${apparent.toStringAsFixed(1)}°C · $riskLevel Risk${drop > 0.05 ? " (Cooling: −${drop.toStringAsFixed(1)}°C)" : ""}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onExpand,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Simulate & Interventions',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF00D4FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_less_rounded,
                    color: Color(0xFF00D4FF),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mock Thermal Grid Map (Web & Desktop Platforms) ──────────────────────────

/// High-tech dark thermal heat map dashboard layout rendered on Web & Desktop.
/// Visualizes FortyGuard's 2-meter resolution heat intelligence with glowing
/// critical heat zones, cool corridors, and live greening relaxation.
class _MockThermalGridMap extends StatelessWidget {
  const _MockThermalGridMap({
    required this.thermal,
    required this.onMapTap,
  });

  final ThermalProvider thermal;
  final void Function(double lat, double lng) onMapTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final apparent = thermal.apparentTemperature;
    final simDrop = thermal.simulatedTempDrop;
    final factor = thermal.simulationFactor;
    final isGreeningActive = factor > 0.05;

    // Cooling factor dynamically relaxes red heat zones into green/cyan
    final heatZoneColor = Color.lerp(
      const Color(0xFFFF1E1E),
      const Color(0xFF10B981),
      factor,
    )!;

    final secondaryHeatColor = Color.lerp(
      const Color(0xFFFF6B35),
      const Color(0xFF00D4FF),
      factor,
    )!;

    return GestureDetector(
      onTapDown: (details) {
        // Map tap pixel coordinates to simulated geographic coordinates near Karachi
        final dx = (details.localPosition.dx / size.width).clamp(0.0, 1.0);
        final dy = (details.localPosition.dy / size.height).clamp(0.0, 1.0);
        final lat = LocationService.fallbackLat + (0.5 - dy) * 0.08;
        final lng = LocationService.fallbackLng + (dx - 0.5) * 0.08;
        onMapTap(lat, lng);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF060B18),
          gradient: RadialGradient(
            center: Alignment(0.0, -0.1),
            radius: 1.1,
            colors: [
              Color(0xFF0C172E),
              Color(0xFF060B18),
              Color(0xFF030710),
            ],
            stops: [0.0, 0.65, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background Coordinate & Street Mesh Lines ───────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _ThermalMeshGridPainter(
                  apparentTemp: apparent,
                  simulationFactor: factor,
                ),
              ),
            ),

            // ── Glowing Circle 1: Critical Heat Zone (CBD Core) ───────────
            Positioned(
              top: size.height * 0.19,
              left: size.width * 0.18,
              child: _GlowingThermalCircle(
                diameter: 190,
                baseColor: heatZoneColor,
                glowColor: heatZoneColor,
                shadowBlur: 75,
                shadowSpread: 24,
                opacity: 0.48,
                label: isGreeningActive
                    ? '🌿 SIMULATED COOLING • ${(apparent - simDrop).toStringAsFixed(1)}°C'
                    : '🔥 CRITICAL HEAT ZONE • ${apparent.toStringAsFixed(1)}°C',
                sublabel: 'Sector 4A · High Albedo Deficit',
              ),
            ),

            // ── Glowing Circle 2: Secondary Thermal Hotspot (Asphalt Hub) ─
            Positioned(
              top: size.height * 0.35,
              right: size.width * 0.10,
              child: _GlowingThermalCircle(
                diameter: 155,
                baseColor: secondaryHeatColor,
                glowColor: secondaryHeatColor,
                shadowBlur: 65,
                shadowSpread: 18,
                opacity: 0.42,
                label: isGreeningActive
                    ? '💧 BUFFERED ZONE • ${(apparent - (simDrop * 0.7)).toStringAsFixed(1)}°C'
                    : '⚠️ ASPHALT HEAT ISLAND • 39.4°C',
                sublabel: 'Sector 7B · Traffic Grid',
              ),
            ),

            // ── Glowing Circle 3: Cool Corridor (Coastal / Wind Channel) ──
            Positioned(
              top: size.height * 0.40,
              left: size.width * 0.08,
              child: const _GlowingThermalCircle(
                diameter: 170,
                baseColor: Color(0xFF00D4FF),
                glowColor: Color(0xFF00D4FF),
                shadowBlur: 70,
                shadowSpread: 20,
                opacity: 0.45,
                label: '❄️ COOL CORRIDOR • 27.8°C',
                sublabel: 'Coastal Sea Breeze Channel',
              ),
            ),

            // ── Glowing Circle 4: Urban Green Buffer / Pocket Park ────────
            Positioned(
              top: size.height * 0.54,
              right: size.width * 0.24,
              child: _GlowingThermalCircle(
                diameter: 140,
                baseColor: const Color(0xFF10B981),
                glowColor: const Color(0xFF10B981),
                shadowBlur: 55,
                shadowSpread: 16,
                opacity: 0.40 + (factor * 0.25),
                label: '🌳 URBAN GREEN BUFFER • 25.4°C',
                sublabel: 'Evapotranspirative Corridor',
              ),
            ),

            // ── Top Header Badge: FortyGuard 2m Microclimate Grid ─────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1426).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isGreeningActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFFF6B35),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (isGreeningActive
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFFF6B35))
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'FORTYGUARD 2M THERMAL GRID',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glowing Thermal Circle Widget ────────────────────────────────────────────

class _GlowingThermalCircle extends StatelessWidget {
  const _GlowingThermalCircle({
    required this.diameter,
    required this.baseColor,
    required this.glowColor,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.opacity,
    required this.label,
    required this.sublabel,
  });

  final double diameter;
  final Color baseColor;
  final Color glowColor;
  final double shadowBlur;
  final double shadowSpread;
  final double opacity;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            baseColor.withValues(alpha: opacity),
            baseColor.withValues(alpha: opacity * 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: opacity * 0.75),
            blurRadius: shadowBlur,
            spreadRadius: shadowSpread,
          ),
        ],
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1020).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: baseColor.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Thermal Mesh Grid Painter ────────────────────────────────────────────────

class _ThermalMeshGridPainter extends CustomPainter {
  const _ThermalMeshGridPainter({
    required this.apparentTemp,
    required this.simulationFactor,
  });

  final double apparentTemp;
  final double simulationFactor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.46);

    // 1. City Grid Mesh Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 42.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Concentric Thermal Radar Rings
    final green = const Color(0xFF10B981);
    final cyan = const Color(0xFF00D4FF);
    final warmOrange = const Color(0xFFFF6B35);
    final hotRed = const Color(0xFFFF1E1E);

    final glowColor = Color.lerp(
      apparentTemp >= 40 ? hotRed : (apparentTemp >= 34 ? warmOrange : cyan),
      green,
      simulationFactor,
    )!;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = glowColor.withValues(alpha: 0.22);

    for (int i = 1; i <= 4; i++) {
      final radius = i * 65.0;
      canvas.drawCircle(center, radius, ringPaint);
    }

    // 3. Sector Crosshairs
    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx - 18, center.dy),
      Offset(center.dx + 18, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 18),
      Offset(center.dx, center.dy + 18),
      crosshairPaint,
    );

    // 4. Center Location Marker
    final dotPaint = Paint()..color = glowColor;
    canvas.drawCircle(center, 4.5, dotPaint);

    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 4.5, dotBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _ThermalMeshGridPainter old) =>
      old.apparentTemp != apparentTemp ||
      old.simulationFactor != simulationFactor;
}

// ─── Top Header ───────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.isLive});
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Color(0xFF00D4FF),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'URBAN NEXUS',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'FortyGuard Heat Intelligence Platform',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: isLive
                ? const _LiveBadge(key: ValueKey('live'))
                : const _SyncingBadge(key: ValueKey('sync')),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'ONLINE',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncingBadge extends StatelessWidget {
  const _SyncingBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'SYNCING',
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Heat Legend ──────────────────────────────────────────────────────────────

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  static const _entries = [
    ('Critical', Color(0xFFFF1E1E)),
    ('High', Color(0xFFFF6B35)),
    ('Medium', Color(0xFFFFDC00)),
    ('Low', Color(0xFF00D4FF)),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 12,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HEAT INDEX',
            style: GoogleFonts.inter(
              fontSize: 8,
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          ..._entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: e.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    e.$1,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating Inspection Overlay Card ─────────────────────────────────────────

/// Floating card displaying local apparent temperature, heat stress risk,
/// infrastructure vulnerability indicators, and the greening simulation slider.
class _FloatingInspectionCard extends StatelessWidget {
  const _FloatingInspectionCard({
    required this.thermal,
    required this.onCollapse,
  });

  final ThermalProvider thermal;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final lat = thermal.inspectedLat ?? LocationService.fallbackLat;
    final lng = thermal.inspectedLng ?? LocationService.fallbackLng;
    final apparentTemp = thermal.apparentTemperature;
    final riskLevel = thermal.heatStressRiskLevel;
    final asphalt = thermal.asphaltInfrastructureStatus;
    final grid = thermal.utilityGridStatus;
    final isSyncing = thermal.isLoading;

    return GlassCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderColor: Colors.white.withValues(alpha: 0.14),
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Block Coordinates & Tap Hint ───────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: Color(0xFF00D4FF),
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'INSPECTED BLOCK',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: const Color(0xFF00D4FF),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isSyncing)
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF00D4FF),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${lat.toStringAsFixed(4)}° N, ${lng.toStringAsFixed(4)}° E',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onCollapse,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Key Metrics Row: Apparent Temp & Heat Stress Risk ───────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Apparent Temperature
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apparent Temperature',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${apparentTemp.toStringAsFixed(1)}°',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            color: _tempColor(apparentTemp),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'C',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Surface: ~${asphalt.surfaceTempC.toStringAsFixed(0)}°C',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Container(
                width: 1,
                height: 48,
                color: Colors.white.withValues(alpha: 0.08),
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),

              // 2. Heat Stress Risk Level
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Heat Stress Risk Level',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _RiskLevelBadge(riskLevel: riskLevel),
                    const SizedBox(height: 3),
                    Text(
                      'TRI: ${(thermal.thermalRiskIndex ?? 60).toStringAsFixed(0)} / 100',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Infrastructure Status Widget ───────────────────────────────
          _InfrastructureStatusWidget(
            asphalt: asphalt,
            grid: grid,
          ),

          const SizedBox(height: 10),

          // ── Compact Greening Simulation Slider ─────────────────────────
          _SimulationSliderRow(thermal: thermal),
        ],
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp >= 42) return const Color(0xFFFF1E1E);
    if (temp >= 36) return const Color(0xFFFF6B35);
    if (temp >= 30) return const Color(0xFFFFDC00);
    return const Color(0xFF00D4FF);
  }
}

// ─── Infrastructure Status Widget ─────────────────────────────────────────────

class _InfrastructureStatusWidget extends StatelessWidget {
  const _InfrastructureStatusWidget({
    required this.asphalt,
    required this.grid,
  });

  final ({String status, String description, double surfaceTempC, bool isAlert})
      asphalt;
  final ({String status, String description, int loadSurgePercent, bool isAlert})
      grid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.apartment_rounded,
                color: Colors.white38,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                'INFRASTRUCTURE STATUS',
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Asphalt & Roadways Status
          _InfrastructureRow(
            icon: Icons.add_road_rounded,
            title: 'Public Asphalt',
            status: asphalt.status,
            description: asphalt.description,
            isAlert: asphalt.isAlert,
            accentColor: asphalt.isAlert
                ? const Color(0xFFFF6B35)
                : const Color(0xFF10B981),
          ),

          const SizedBox(height: 6),

          // 2. Utility & Electrical Grid Status
          _InfrastructureRow(
            icon: Icons.bolt_rounded,
            title: 'Utility Grid',
            status: grid.status,
            description: grid.description,
            isAlert: grid.isAlert,
            accentColor: grid.isAlert
                ? const Color(0xFFFF1E1E)
                : const Color(0xFF00D4FF),
          ),
        ],
      ),
    );
  }
}

class _InfrastructureRow extends StatelessWidget {
  const _InfrastructureRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.description,
    required this.isAlert,
    required this.accentColor,
  });

  final IconData icon;
  final String title;
  final String status;
  final String description;
  final bool isAlert;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: accentColor,
            size: 13,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: Colors.white38,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Risk Level Badge ─────────────────────────────────────────────────────────

class _RiskLevelBadge extends StatelessWidget {
  const _RiskLevelBadge({required this.riskLevel});
  final String riskLevel;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (riskLevel.toLowerCase()) {
      'critical' || 'extreme' => (const Color(0xFFFF1E1E), 'Critical Risk'),
      'high' => (const Color(0xFFFF6B35), 'High Risk'),
      'medium' || 'moderate' => (const Color(0xFFFFDC00), 'Moderate Risk'),
      _ => (const Color(0xFF10B981), 'Low Risk'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greening Simulation Slider Row ───────────────────────────────────────────

class _SimulationSliderRow extends StatelessWidget {
  const _SimulationSliderRow({required this.thermal});
  final ThermalProvider thermal;

  @override
  Widget build(BuildContext context) {
    final drop = thermal.simulatedTempDrop;
    final factor = thermal.simulationFactor;
    final green = const Color(0xFF10B981);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.park_rounded,
                  color: green,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  'URBAN GREENING SIMULATION',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    color: Colors.white38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
              ],
            ),
            Text(
              drop > 0.05
                  ? 'Simulated Cooling: −${drop.toStringAsFixed(1)}°C'
                  : 'Baseline (0.0°C)',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: drop > 0.05 ? green : Colors.white38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            activeTrackColor: green,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: green,
            overlayColor: green.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: factor,
            min: 0.0,
            max: 1.0,
            onChanged: (v) => thermal.setSimulationFactor(v),
          ),
        ),
      ],
    );
  }
}

// ─── Loading Overlay ──────────────────────────────────────────────────────────

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: GlassCard(
            borderRadius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF00D4FF),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Fetching heat intelligence…',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppNotice.showNoticeDialog(
          context,
          title: 'Connection & Intelligence Notice',
          message: message,
          icon: Icons.cloud_off_rounded,
          accentColor: const Color(0xFFEF4444),
          buttonText: 'Retry Connection',
          onAction: () => context.read<ThermalProvider>().refresh(),
        );
      },
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderColor: const Color(0xFFEF4444).withValues(alpha: 0.50),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.read<ThermalProvider>().refresh(),
              child: Text(
                'Retry',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF00D4FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
