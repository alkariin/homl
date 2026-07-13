import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:homl/helpers/colors.dart';

/// Repaints the gold strokes of the logo artwork (drawn in [yellow], which is
/// the palette's #D3A934) in another color, leaving the black strokes alone.
class _GoldTintMapper extends ColorMapper {
  final Color tint;

  const _GoldTintMapper(this.tint);

  @override
  Color substitute(
          String? id, String elementName, String attributeName, Color color) =>
      color == yellow ? tint : color;
}

/// The homl "#" logo: the two-tone hash from the design export
/// (assets/images/logo.svg) inside a white circle.
///
/// [colorProgress] drives the gold reveal: at 0 the whole hash is black, at 1
/// it shows the normal two-tone artwork. The reveal sweeps from the base of
/// the gold strokes (bottom-left) to their tip (top-right).
///
/// [tint] recolors the gold strokes only — the black ones stay black — and
/// the circle border (search bar: the category color of the top suggestion).
/// Null keeps the normal artwork.
///
/// [circled] false drops the white circle, border and shadow and shows the
/// bare hash (splash screen: the circle reads as a tappable button there).
class HomlLogo extends StatelessWidget {
  final double size;
  final double colorProgress;
  final Color? tint;
  final bool circled;

  const HomlLogo(
      {this.size = 51,
      this.colorProgress = 1.0,
      this.tint,
      this.circled = true,
      super.key});

  @override
  Widget build(BuildContext context) {
    if (!circled) {
      return SizedBox(
        width: size,
        height: size,
        child: colorProgress >= 1.0 ? _hash() : _revealingHash(),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
            color: tint ?? yellow, width: tint == null ? 0.5 : 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: colorProgress >= 1.0 ? _hash() : _revealingHash(),
    );
  }

  /// The plain two-tone artwork stacked over an all-black copy of itself,
  /// with the top layer masked by a gradient front at [colorProgress].
  /// Black-over-black is invisible, so only the gold strokes appear to fill.
  Widget _revealingHash() {
    const fade = 0.25;
    final front = colorProgress * (1 + fade);
    return Stack(
      alignment: Alignment.center,
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(ink, BlendMode.srcIn),
          child: _hash(),
        ),
        ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Colors.white, Colors.white.withValues(alpha: 0)],
            stops: [
              (front - fade).clamp(0.0, 1.0),
              front.clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: _hash(),
        ),
      ],
    );
  }

  Widget _hash() {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      fit: BoxFit.contain,
      colorMapper: tint == null ? null : _GoldTintMapper(tint!),
    );
  }
}
