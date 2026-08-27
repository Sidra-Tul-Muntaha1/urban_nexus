import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/thermal_provider.dart';
import '../services/file_download_service.dart';
import '../services/location_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/roi_metric_card.dart';

// ─── Metric Card Model ────────────────────────────────────────────────────────

class _RoiCardModel {
  const _RoiCardModel({
    required this.title,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendUp,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.spark,
  });

  final String title;
  final String value;
  final String unit;
  final String trend;
  final bool trendUp;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<double> spark;
}

// ─── Commercial ROI Screen ────────────────────────────────────────────────────

/// Commercial ROI Dashboard evaluating thermal impact on operational expenditure,
/// retail foot traffic, building asset longevity, and capital mitigation strategies.
class CommercialRoiScreen extends StatelessWidget {
  const CommercialRoiScreen({super.key});

  List<_RoiCardModel> _getCards(ThermalProvider thermal) {
    final tri = thermal.thermalRiskIndex ?? 70.0;
    final apparent = thermal.apparentTemperature;
    final simDrop = thermal.simulatedTempDrop;

    // Card 1: HVAC Cooling Load
    final hvacCost = ((320 + (tri * 1.8) - (simDrop * 25))).round();
    final hvacWastePercent = (12.0 + (tri * 0.14) - (simDrop * 2)).clamp(4.0, 35.0);

    // Card 2: Foot Traffic Predictive Score
    final footTrafficScore = ((95 - (tri * 0.42) + (simDrop * 5))).clamp(35.0, 98.0).round();
    final footTrafficLoss = (22 - (simDrop * 3.5)).clamp(4.0, 30.0).round();

    // Card 3: Asset Value Degradation Risk
    final assetRiskMillions = (0.8 + (tri * 0.012) - (simDrop * 0.1)).clamp(0.5, 2.5);

    // Card 4: Mitigation Net Benefit & Projected ROI
    final netSavingsMillions = (1.4 + (simDrop * 0.28)).clamp(1.2, 3.8);

    return [
      // 1. HVAC Cooling Load
      _RoiCardModel(
        title: 'HVAC Cooling Load',
        value: '\$${hvacCost}K',
        unit: '/ month',
        trend: '+${hvacWastePercent.toStringAsFixed(0)}% waste',
        trendUp: false,
        icon: Icons.ac_unit_rounded,
        color: const Color(0xFFFF6B35),
        subtitle: 'Peak ${apparent.toStringAsFixed(1)}°C outdoor load',
        spark: const [0.35, 0.45, 0.50, 0.62, 0.70, 0.75, 0.82, 0.88, 0.92, 0.96],
      ),

      // 2. Foot Traffic Predictive Score
      _RoiCardModel(
        title: 'Foot Traffic Score',
        value: '$footTrafficScore',
        unit: '/ 100 comfort',
        trend: '−$footTrafficLoss% visits',
        trendUp: false,
        icon: Icons.storefront_rounded,
        color: const Color(0xFFFFDC00),
        subtitle: 'Midday heat slows retail entries',
        spark: const [0.88, 0.82, 0.76, 0.70, 0.65, 0.58, 0.62, 0.60, 0.64, 0.64],
      ),

      // 3. Asset Value Degradation Risk
      _RoiCardModel(
        title: 'Asset Value Risk',
        value: '\$${assetRiskMillions.toStringAsFixed(1)}M',
        unit: '10-yr exposure',
        trend: tri > 65 ? 'High risk' : 'Moderate',
        trendUp: false,
        icon: Icons.domain_verification_rounded,
        color: const Color(0xFFFF1E1E),
        subtitle: 'Roof membrane & chiller fatigue',
        spark: const [0.40, 0.46, 0.52, 0.58, 0.65, 0.71, 0.78, 0.84, 0.89, 0.92],
      ),

      // 4. Net Thermal Mitigation ROI
      _RoiCardModel(
        title: 'Mitigation ROI',
        value: '+\$${netSavingsMillions.toStringAsFixed(2)}M',
        unit: 'net yield (NPV)',
        trend: '+31% ROI',
        trendUp: true,
        icon: Icons.energy_savings_leaf_rounded,
        color: const Color(0xFF10B981),
        subtitle: 'Cool roofs + solar canopy yield',
        spark: const [0.30, 0.40, 0.48, 0.58, 0.66, 0.75, 0.82, 0.89, 0.94, 1.0],
      ),
    ];
  }

  void _openMitigationReport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => const _MitigationReportModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final thermal = context.watch<ThermalProvider>();
    final cards = _getCards(thermal);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Dashboard Header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DashboardHeader(thermal: thermal),
          ),

          // ── Section Title Ribbon ───────────────────────────────────
          SliverToBoxAdapter(child: _SummaryRibbon()),

          // ── 4-Card Responsive Grid ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) => RoiMetricCard(
                  title: cards[i].title,
                  value: cards[i].value,
                  unit: cards[i].unit,
                  trend: cards[i].trend,
                  trendUp: cards[i].trendUp,
                  icon: cards[i].icon,
                  accentColor: cards[i].color,
                  subtitle: cards[i].subtitle,
                  sparkData: cards[i].spark,
                ),
                childCount: cards.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
            ),
          ),

          // ── Action Button: Generate Mitigation Report ───────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: _GenerateReportButton(
                onTap: () => _openMitigationReport(context),
              ),
            ),
          ),

          // ── Bottom Padding for Floating Navigation Bar ─────────────
          SliverToBoxAdapter(
            child: SizedBox(height: bottomPad + 96),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Header ─────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.thermal});
  final ThermalProvider thermal;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final apparent = thermal.apparentTemperature;
    final simDrop = thermal.simulatedTempDrop;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 18, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1035), Color(0xFF0A1124)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commercial ROI Engine',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Financial & Thermal Asset Analytics',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => thermal.refresh(),
                child: GlassCard(
                  borderRadius: 12,
                  padding: const EdgeInsets.all(9),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF00D4FF),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Total Financial Impact KPI Banner
          GlassCard(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7C3AED).withValues(alpha: 0.22),
                const Color(0xFF00D4FF).withValues(alpha: 0.08),
              ],
            ),
            borderColor: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected Net Annual Yield',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$2.15M  ·  +28.4% ROI',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (simDrop > 0.05)
                        Text(
                          'Greening simulation active: −${simDrop.toStringAsFixed(1)}°C drop',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${apparent.toStringAsFixed(0)}°C AMBIENT',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: const Color(0xFF00D4FF),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Ribbon ───────────────────────────────────────────────────────────

class _SummaryRibbon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Text(
            'Thermal Vulnerability Metrics',
            style: GoogleFonts.outfit(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sensors_rounded,
                  color: Color(0xFF10B981),
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Real-Time Live',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Generate Mitigation Report Button ─────────────────────────────────────────

class _GenerateReportButton extends StatelessWidget {
  const _GenerateReportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assessment_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              'Generate Mitigation Report',
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mitigation Report Modal ──────────────────────────────────────────────────

class _MitigationReportModal extends StatelessWidget {
  const _MitigationReportModal();

  @override
  Widget build(BuildContext context) {
    final thermal = context.watch<ThermalProvider>();
    final apparent = thermal.apparentTemperature;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.84,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Modal Handle ───────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              children: [
                // ── Header Title Row ─────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Color(0xFF9333EA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thermal Mitigation & ROI Plan',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Site Coordinates: ${thermal.inspectedLat?.toStringAsFixed(4) ?? LocationService.fallbackLat.toStringAsFixed(4)}° N, ${thermal.inspectedLng?.toStringAsFixed(4) ?? LocationService.fallbackLng.toStringAsFixed(4)}° E',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Executive Summary KPI Banner ───────────────────────
                GlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(16),
                  borderColor: const Color(0xFF00D4FF).withValues(alpha: 0.25),
                  backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.70),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXECUTIVE MITIGATION SUMMARY',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: const Color(0xFF00D4FF),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ModalMetric(
                            label: 'Ambient Heat',
                            value: '${apparent.toStringAsFixed(1)}°C',
                            color: const Color(0xFFFF6B35),
                          ),
                          _ModalDivider(),
                          _ModalMetric(
                            label: 'Cooling Target',
                            value: '−3.8°C',
                            color: const Color(0xFF10B981),
                          ),
                          _ModalDivider(),
                          _ModalMetric(
                            label: 'Annual OPEX Cut',
                            value: '\$188K',
                            color: const Color(0xFF00D4FF),
                          ),
                          _ModalDivider(),
                          _ModalMetric(
                            label: 'Avg Payback',
                            value: '2.4 Yrs',
                            color: const Color(0xFF7C3AED),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Recommended Capital Interventions',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Intervention 1: Cool Roof ─────────────────────────
                _InterventionCard(
                  title: 'Cool Roof High-Albedo Coating',
                  tag: 'HIGHEST EFFICIENCY',
                  tagColor: const Color(0xFF10B981),
                  icon: Icons.roofing_rounded,
                  description:
                      'Reflective elastomeric membrane reflecting 85% solar radiation. Eliminates top-floor thermal absorption and reduces HVAC chiller load by up to 32%.',
                  capex: '\$125,000',
                  annualSavings: '\$62,000 / yr',
                  payback: '2.0 Years',
                  roiNpv: '+36% IRR',
                  accentColor: const Color(0xFF00D4FF),
                ),

                const SizedBox(height: 12),

                // ── Intervention 2: Solar Canopies ────────────────────
                _InterventionCard(
                  title: 'BIPV Solar Shading Canopies',
                  tag: 'DUAL VALUE (POWER + SHADE)',
                  tagColor: const Color(0xFF7C3AED),
                  icon: Icons.solar_power_rounded,
                  description:
                      'Photovoltaic canopies across parking plazas and rooftop decks. Produces 160 kW clean electricity while lowering ground asphalt heat retention by 14°C.',
                  capex: '\$290,000',
                  annualSavings: '\$98,000 / yr',
                  payback: '2.9 Years',
                  roiNpv: '+28% IRR',
                  accentColor: const Color(0xFF7C3AED),
                ),

                const SizedBox(height: 12),

                // ── Intervention 3: Green Wall & Corridors ────────────
                _InterventionCard(
                  title: 'Vertical Green Façade & Pocket Park',
                  tag: 'FOOT TRAFFIC BOOST',
                  tagColor: const Color(0xFFFFDC00),
                  icon: Icons.park_rounded,
                  description:
                      'Living wall micro-cooling system on exterior retail façades. Lowers ambient corridor temperature by 2.6°C and drives a predicted +18% increase in retail dwell time.',
                  capex: '\$88,000',
                  annualSavings: '\$38,000 / yr',
                  payback: '2.3 Years',
                  roiNpv: '+22% IRR',
                  accentColor: const Color(0xFF10B981),
                ),

                const SizedBox(height: 20),

                // ── Action Footer ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Apply 3.8°C greening mitigation simulation
                          thermal.toggleSimulation(true);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Cooling scenario successfully simulated! Ambient drop: −3.8°C',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF10B981)),
                        label: Text(
                          'Simulate Scenario',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final reportContent = _buildReportText(thermal);
                          FileDownloadService.downloadTextFile(
                            reportContent,
                            'UrbanNexus_Thermal_Report.txt',
                          );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF7C3AED),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.download_done_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'UrbanNexus_Thermal_Report.txt downloaded successfully!',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, color: Colors.white),
                        label: Text(
                          'Export PDF',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildReportText(ThermalProvider thermal) {
    final lat = thermal.inspectedLat ?? LocationService.fallbackLat;
    final lng = thermal.inspectedLng ?? LocationService.fallbackLng;
    final apparent = thermal.apparentTemperature;
    final tri = thermal.thermalRiskIndex ?? 68.0;
    final level = thermal.heatStressRiskLevel;
    final date = DateTime.now().toUtc().toIso8601String();

    return '''
================================================================================
           URBAN NEXUS — THERMAL MITIGATION & CAPITAL ROI REPORT
================================================================================
Generated: $date
Target Sector: $lat° N, $lng° E
FortyGuard Thermal Risk Index (TRI): ${tri.toStringAsFixed(1)} / 100 ($level Risk)
Baseline Apparent Heat: ${apparent.toStringAsFixed(1)} °C
Target Simulated Cooling: −3.8 °C
Projected Annual OPEX Savings: \$188,000 / year
Average Capital Payback: 2.4 Years

--------------------------------------------------------------------------------
RECOMMENDED CAPITAL INTERVENTIONS & ROI ANALYSIS
--------------------------------------------------------------------------------

1. Cool Roof High-Albedo Membrane Coating
   • Description: Reflects 85% solar radiation, eliminates top-floor heat transfer.
   • Estimated Capex: \$125,000
   • Annual HVAC Energy Savings: \$62,000 / yr
   • Payback Period: 2.0 Years
   • Financial Return: +36% IRR / +34% NPV

2. BIPV Solar Shading Canopies & Walkway Arrays
   • Description: 160 kW clean solar generation over parking plazas + 14°C pavement cooling.
   • Estimated Capex: \$290,000
   • Annual Energy & Shading Value: \$98,000 / yr
   • Payback Period: 2.9 Years
   • Financial Return: +28% IRR / +26% NPV

3. Vertical Green Façade & Pocket Park Micro-Corridor
   • Description: Living wall bio-cooling buffer restoring +18% retail storefront foot traffic.
   • Estimated Capex: \$88,000
   • Annual Revenue & Cooling Value: \$38,000 / yr
   • Payback Period: 2.3 Years
   • Financial Return: +22% IRR / +20% NPV

================================================================================
Report validated by FortyGuard Heat Intelligence Platform for UrbanNexus.
================================================================================
''';
  }
}

// ─── Modal Metric Chip ────────────────────────────────────────────────────────

class _ModalMetric extends StatelessWidget {
  const _ModalMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

// ─── Intervention Card ────────────────────────────────────────────────────────

class _InterventionCard extends StatelessWidget {
  const _InterventionCard({
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.icon,
    required this.description,
    required this.capex,
    required this.annualSavings,
    required this.payback,
    required this.roiNpv,
    required this.accentColor,
  });

  final String title;
  final String tag;
  final Color tagColor;
  final IconData icon;
  final String description;
  final String capex;
  final String annualSavings;
  final String payback;
  final String roiNpv;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      borderColor: accentColor.withValues(alpha: 0.25),
      backgroundColor: Colors.white.withValues(alpha: 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tag,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: tagColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white60,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InterventionStat(label: 'Est. Capex', value: capex),
                _InterventionStat(label: 'Annual Save', value: annualSavings, highlight: true),
                _InterventionStat(label: 'Payback', value: payback),
                _InterventionStat(label: 'ROI (IRR)', value: roiNpv, highlight: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InterventionStat extends StatelessWidget {
  const _InterventionStat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: Colors.white38,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: highlight ? const Color(0xFF10B981) : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
