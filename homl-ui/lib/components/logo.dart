import 'package:flutter/material.dart';

import 'package:homl/helpers/colors.dart';

/// The homl "#" logo: the two-tone hash from the design export
/// (assets/images/logo.png) inside a white circle.
class HomlLogo extends StatelessWidget {
  final double size;

  const HomlLogo({this.size = 51, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: yellow, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
