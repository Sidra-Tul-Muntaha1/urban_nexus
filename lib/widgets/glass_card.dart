import 'dart:ui';
import 'package:flutter/material.dart';

/// A reusable frosted-glass container using [BackdropFilter].
///
/// Wrap any widget in [GlassCard] to give it the glassmorphism look
/// that is consistent across the UrbanNexus design system.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blurSigma = 12.0,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.gradient,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null
                  ? (backgroundColor ?? Colors.white.withValues(alpha: 0.06))
                  : null,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
