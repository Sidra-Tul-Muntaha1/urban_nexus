import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'models/app_state.dart';
import 'providers/thermal_provider.dart';
import 'screens/commercial_roi_screen.dart';
import 'screens/smart_city_screen.dart';
import 'screens/splash_screen.dart';
import 'services/forty_guard_service.dart';
import 'services/location_service.dart';

// ─── Entry point ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Load .env configuration ────────────────────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[UrbanNexus] Notice: .env file not loaded ($e). Using fallbacks.');
  }

  // ── Mapbox public access token (Mobile Only) ──────────────────────────────
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      final mapboxToken = dotenv.isInitialized
          ? (dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? dotenv.env['MAPBOX_TOKEN'] ?? '')
          : '';
      const fallbackToken = 'pk.YOUR_MAPBOX_PUBLIC_TOKEN_HERE';
      MapboxOptions.setAccessToken(
        mapboxToken.isNotEmpty ? mapboxToken : fallbackToken,
      );
    } catch (e) {
      debugPrint('[UrbanNexus] Notice: Error setting Mapbox access token: $e');
    }
  }

  // ── Edge-to-edge system UI ─────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // ── Initialize singleton services ──────────────────────────────────────────
  final fortyGuardService = FortyGuardService(useMock: true);
  final locationService = LocationService();

  // Test FortyGuard API connectivity & print raw response to console
  fortyGuardService.testConnection();

  runApp(
    MultiProvider(
      providers: [
        // ── Navigation state ────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => AppState()),

        // ── Singleton services ──────────────────────────────────────
        Provider<FortyGuardService>.value(value: fortyGuardService),
        Provider<LocationService>.value(value: locationService),

        // ── Thermal provider (auto-initialises on creation) ─────────
        ChangeNotifierProvider(
          create: (ctx) => ThermalProvider(
            fortyGuardService: ctx.read<FortyGuardService>(),
            locationService: ctx.read<LocationService>(),
          )..initialize(),
        ),
      ],
      child: const UrbanNexusApp(),
    ),
  );
}

// ─── App root ─────────────────────────────────────────────────────────────────

class UrbanNexusApp extends StatelessWidget {
  const UrbanNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbanNexus',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF080D1A),
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF00D4FF),
        secondary: const Color(0xFF7C3AED),
        tertiary: const Color(0xFFFF6B35),
        surface: const Color(0xFF111827),
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
    );
  }
}

// ─── App shell ────────────────────────────────────────────────────────────────

/// Top-level scaffold. Owns the [_CustomBottomNav] and delegates the active
/// screen to an [AnimatedSwitcher] driven by [AppState].
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const _screens = [
    SmartCityScreen(),
    CommercialRoiScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      extendBody: true,
      body: Stack(
        children: [
          // Global dark background gradient (visible behind map letterboxing).
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF080D1A),
                  Color(0xFF0C1528),
                  Color(0xFF07101D),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Active screen with fade transition.
          Consumer<AppState>(
            builder: (context, state, child) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey(state.currentIndex),
                child: _screens[state.currentIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const _CustomBottomNav(),
    );
  }
}

// ─── Custom glassmorphism bottom nav ─────────────────────────────────────────

class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    id: 'nav_smart_city',
                    label: 'Smart City',
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map_rounded,
                    isActive: state.currentIndex == 0,
                    activeColor: const Color(0xFF00D4FF),
                    onTap: () => state.setIndex(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    id: 'nav_commercial_roi',
                    label: 'Commercial ROI',
                    icon: Icons.analytics_outlined,
                    activeIcon: Icons.analytics_rounded,
                    isActive: state.currentIndex == 1,
                    activeColor: const Color(0xFF7C3AED),
                    onTap: () => state.setIndex(1),
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

// ─── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey(id),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: isActive
              ? Border.all(color: activeColor.withValues(alpha: 0.30), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? activeColor : Colors.white38,
                size: 20,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: isActive
                  ? Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: activeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
