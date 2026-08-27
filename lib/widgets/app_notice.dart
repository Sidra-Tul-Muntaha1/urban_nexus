import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'glass_card.dart';

/// Notification and alert system for UrbanNexus.
///
/// Provides glassmorphic floating snackbars and informative modal dialogs
/// for API key warnings, network timeouts, and GPS permission notices.
class AppNotice {
  AppNotice._();

  /// Shows an elegant floating glassmorphism snackbar.
  static void showSnackBar(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color iconColor = const Color(0xFF00D4FF),
    Color borderColor = const Color(0xFF00D4FF),
    VoidCallback? onAction,
    String actionLabel = 'Retry',
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: duration,
        content: GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderColor: borderColor.withValues(alpha: 0.40),
          backgroundColor: const Color(0xFF0B1220).withValues(alpha: 0.92),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF00D4FF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Displays a formatted error notice for network timeouts or connection drops.
  static void showNetworkError(
    BuildContext context, {
    String? customMessage,
    VoidCallback? onRetry,
  }) {
    showSnackBar(
      context,
      title: 'Connection Timeout',
      message: customMessage ?? 'Could not reach FortyGuard servers. Please check your connection.',
      icon: Icons.wifi_off_rounded,
      iconColor: const Color(0xFFEF4444),
      borderColor: const Color(0xFFEF4444),
      onAction: onRetry,
      actionLabel: 'Retry',
    );
  }

  /// Displays a notice when FORTYGUARD_API_KEY is missing or invalid.
  static void showApiKeyNotice(BuildContext context) {
    showSnackBar(
      context,
      title: 'FortyGuard API Key Notice',
      message: 'No active key found in .env. Running on built-in mock intelligence.',
      icon: Icons.key_off_rounded,
      iconColor: const Color(0xFFFF6B35),
      borderColor: const Color(0xFFFF6B35),
      duration: const Duration(seconds: 5),
    );
  }

  /// Displays a notice when GPS location permissions are denied or disabled.
  static void showGpsNotice(BuildContext context, {VoidCallback? onRetry}) {
    showSnackBar(
      context,
      title: 'GPS Location Notice',
      message: 'Location access is restricted. Defaulting coordinates to Karachi City Center.',
      icon: Icons.location_off_rounded,
      iconColor: const Color(0xFFFFDC00),
      borderColor: const Color(0xFFFFDC00),
      onAction: onRetry,
      actionLabel: 'Check GPS',
      duration: const Duration(seconds: 5),
    );
  }

  /// Shows an informative modal alert dialog with dark glassmorphism styling.
  static Future<void> showNoticeDialog(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color accentColor = const Color(0xFF00D4FF),
    String buttonText = 'Understood',
    VoidCallback? onAction,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassCard(
          borderRadius: 24,
          padding: const EdgeInsets.all(22),
          borderColor: accentColor.withValues(alpha: 0.35),
          backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onAction?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
