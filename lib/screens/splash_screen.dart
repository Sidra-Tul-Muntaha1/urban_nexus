import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/thermal_provider.dart';

/// Unified Splash Screen for Android, iOS, and Web.
///
/// Features:
/// 1. Deep midnight-blue background (#0F172A) matching the dark glassmorphic design system.
/// 2. Environmental radar scan animation with glowing neon-blue and crimson accents.
/// 3. Initiates ThermalProvider heat intelligence pre-fetching in the background during boot.
/// 4. 3-second minimum duration timer followed by a smooth transition to [AppShell].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();

    // 1. Environmental radar rotation animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // 2. Pre-fetch FortyGuard / Dubai heat intelligence data on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ThermalProvider>().initialize();
      }
    });

    // 3. 3-Second boot timer for clean unified splash presentation
    _transitionTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AppShell(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 650),
        ),
      );
    });
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // ── 1. Midnight Deep Gradient Background ─────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.1),
                radius: 1.2,
                colors: [
                  Color(0xFF1E293B),
                  Color(0xFF0F172A),
                  Color(0xFF070C18),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── 2. Ambient Background Glowing Flares ─────────────────────
          Positioned(
            top: size.height * 0.28,
            left: size.width * 0.5 - 130,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.18),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF1E1E).withValues(alpha: 0.12),
                    blurRadius: 120,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Centered Content: Radar Scanner + Branding ─────────────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Animated Environmental Radar Scan ───────────────────
                SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Concentric pulse ring 1
                      _PulsingRing(
                        diameter: 160,
                        borderColor: const Color(0xFF00D4FF).withValues(alpha: 0.25),
                      ),
                      // Concentric pulse ring 2
                      _PulsingRing(
                        diameter: 110,
                        borderColor: const Color(0xFFFF1E1E).withValues(alpha: 0.35),
                      ),
                      // Concentric pulse ring 3
                      _PulsingRing(
                        diameter: 65,
                        borderColor: const Color(0xFF00D4FF).withValues(alpha: 0.50),
                      ),

                      // Rotating radar sweep beam
                      RotationTransition(
                        turns: _controller,
                        child: CustomPaint(
                          size: const Size(160, 160),
                          painter: _RadarBeamPainter(),
                        ),
                      ),

                      // Center core thermal beacon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F172A),
                          border: Border.all(
                            color: const Color(0xFF00D4FF),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF).withValues(alpha: 0.6),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.public_rounded,
                            color: Color(0xFF00D4FF),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 38),

                // ── Primary App Title ──────────────────────────────────
                Text(
                  'URBANNEXUS',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4.5,
                  ),
                ),

                const SizedBox(height: 6),

                // ── Subtitle ──────────────────────────────────────────
                Text(
                  'Ambient Intelligence Engine',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF00D4FF),
                    letterSpacing: 2.2,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Loading Pill & Pulse ───────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFF00D4FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'INITIALIZING 2M THERMAL GRID…',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 4. Bottom Powered By Ribbon ──────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'POWERED BY FORTYGUARD HEAT INTELLIGENCE',
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.white30,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing Radar Ring Widget ────────────────────────────────────────────────

class _PulsingRing extends StatelessWidget {
  const _PulsingRing({
    required this.diameter,
    required this.borderColor,
  });

  final double diameter;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
    );
  }
}

// ─── Radar Beam Painter ───────────────────────────────────────────────────────

class _RadarBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Sweep gradient slice simulating radar wave
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          const Color(0xFF00D4FF).withValues(alpha: 0.45),
          const Color(0xFFFF1E1E).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi / 2,
      true,
      sweepPaint,
    );

    // Leading scan line
    final linePaint = Paint()
      ..color = const Color(0xFF00D4FF).withValues(alpha: 0.9)
      ..strokeWidth = 2.0;

    canvas.drawLine(
      center,
      Offset(center.dx + radius, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
