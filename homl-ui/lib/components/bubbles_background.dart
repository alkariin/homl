import 'package:flutter/material.dart';

import 'package:homl/helpers/colors.dart';

/// Decorative page background: two large diagonal sweeps (white and
/// translucent yellow, from the Figma export) plus a soft yellow glow in the
/// top-right corner.
///
/// Everything is sized relative to the available space, like a background
/// image, so the shapes always overflow the screen and scale with it instead
/// of being pinned to phone-sized pixel offsets.
class BubblesBackground extends StatelessWidget {
  final Widget child;

  const BubblesBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -0.55 * w,
            top: -0.3 * h,
            child: _Glow(diameter: 1.1 * w),
          ),
          Positioned(
            left: -0.33 * w,
            top: 0.30 * h,
            child: _Sweep(
              width: 1.95 * w,
              height: 0.71 * h,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          Positioned(
            left: -0.13 * w,
            top: 0.30 * h,
            child: _Sweep(
              width: 1.95 * w,
              height: 0.51 * h,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  yellow.withValues(alpha: 0.12),
                  yellow.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),
          child,
        ],
      );
    });
  }
}

/// A rotated pill-shaped band, wider than the screen.
class _Sweep extends StatelessWidget {
  static const _angleDegrees = 27.18;

  final double width;
  final double height;
  final Gradient gradient;

  const _Sweep(
      {required this.width, required this.height, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: _angleDegrees * 3.14159 / 180,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// A soft radial halo that fades to transparent.
class _Glow extends StatelessWidget {
  final double diameter;

  const _Glow({required this.diameter});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              yellow.withValues(alpha: 0.08),
              yellow.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
