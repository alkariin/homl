import 'package:flutter/material.dart';

import 'package:homl/helpers/colors.dart';

/// Decorative background of the Figma export: large rotated blobs (white and
/// translucent yellow) behind the page content.
class BubblesBackground extends StatelessWidget {
  final Widget child;

  const BubblesBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: -130,
          top: 254,
          child: _Blob(
            width: 745,
            height: 600,
            color: Colors.white,
            angle: 27.18,
          ),
        ),
        Positioned(
          left: -50,
          top: 254,
          child: _Blob(
            width: 760,
            height: 430,
            color: yellow.withValues(alpha: 0.12),
            angle: 27.18,
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double angle;

  const _Blob(
      {required this.width,
      required this.height,
      required this.color,
      required this.angle});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle * 3.14159 / 180,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(200),
          ),
        ),
      ),
    );
  }
}
