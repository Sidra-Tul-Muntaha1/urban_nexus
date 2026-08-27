import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_card.dart';

/// A single metric card for the Commercial ROI dashboard.
///
/// Displays an [icon], [title], large [value] + [unit], a trend pill,
/// a [subtitle] descriptor, and a mini spark-line chart.
class RoiMetricCard extends StatelessWidget {
  const RoiMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendUp,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
    required this.sparkData,
  });

  final String title;
  final String value;
  final String unit;

  /// Trend label shown in the pill, e.g. "+18%".
  final String trend;

  /// Whether the trend is positive (green) or negative (red).
  final bool trendUp;

  final IconData icon;
  final Color accentColor;

  /// Short descriptor shown below the value, e.g. "vs last quarter".
  final String subtitle;

  /// Normalised (0–1) data points for the mini spark-line.
  final List<double> sparkData;

  @override
  Widget build(BuildContext context) {
    final trendColor = trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon + trend pill ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.35),
                      accentColor.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              _TrendPill(label: trend, isUp: trendUp, color: trendColor),
            ],
          ),

          const SizedBox(height: 14),

          // ── Title ──────────────────────────────────────────────────
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white54,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(height: 6),

          // ── Value + unit ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white38,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),

          const SizedBox(height: 14),

          // ── Spark-line ─────────────────────────────────────────────
          SizedBox(
            height: 34,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparkLinePainter(data: sparkData, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trend pill ──────────────────────────────────────────────────────────────

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.label,
    required this.isUp,
    required this.color,
  });

  final String label;
  final bool isUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spark-line painter ───────────────────────────────────────────────────────

class _SparkLinePainter extends CustomPainter {
  const _SparkLinePainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b);
    final minVal = data.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : maxVal - minVal;

    Offset toOffset(int i) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height * 0.85;
      return Offset(x, y);
    }

    final points = List.generate(data.length, toOffset);

    // ── Gradient fill ──
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // ── Stroke line ──
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── Terminal dot ──
    canvas
      ..drawCircle(points.last, 3.5, Paint()..color = color)
      ..drawCircle(
        points.last,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
  }

  @override
  bool shouldRepaint(covariant _SparkLinePainter old) =>
      old.data != data || old.color != color;
}
