import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/sky.dart';
import 'package:homl/helpers/theme.dart';

/// The background of the home tabs: the user's last months as a night sky,
/// one constellation per month and one star per event (see
/// lib/helpers/sky.dart for what it shows). Grey stars on the light theme,
/// white ones and a dust of tiny stars on the dark one; one gold star per
/// month. Decorative only: it takes no touch and says nothing to a screen
/// reader.
class SkyBackground extends StatelessWidget {
  final Sky sky;

  const SkyBackground({required this.sky, super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SkyPainter(
            sky,
            ink: context.homl.ink,
            night: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  final Sky sky;
  final Color ink;
  final bool night;

  _SkyPainter(this.sky, {required this.ink, required this.night});

  // Half as strong on the light theme: grey on white reads louder than
  // white on black.
  double get _lineAlpha => night ? 0.18 : 0.06;
  double get _starAlpha => night ? 0.6 : 0.19;
  double get _glowAlpha => night ? 0.38 : 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    if (night) _paintDust(canvas, size);

    final geometry = SkyGeometry(sky.months.length, size);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = ink.withValues(alpha: _lineAlpha);
    final star = Paint()..color = ink.withValues(alpha: _starAlpha);
    final gold = Paint()..color = yellow;

    for (var index = 0; index < sky.months.length; index++) {
      final month = sky.months[index];
      if (month.stars.isEmpty) continue;
      final (center, radius) = geometry.discOf(index, month.drift);
      if (radius <= 0) continue;
      Offset at(SkyStar s) => center + s.at * radius;

      for (final (from, to) in month.links) {
        canvas.drawLine(at(month.stars[from]), at(month.stars[to]), line);
      }
      for (var i = 0; i < month.stars.length; i++) {
        final s = month.stars[i];
        final p = at(s);
        final size = 1.3 + 0.45 * math.min(s.tags, 4);
        if (i == month.bright) {
          const halo = 12.0;
          canvas.drawCircle(
              p,
              halo,
              Paint()
                ..shader = RadialGradient(colors: [
                  yellow.withValues(alpha: _glowAlpha),
                  yellow.withValues(alpha: 0),
                ]).createShader(Rect.fromCircle(center: p, radius: halo)));
          canvas.drawCircle(p, size + 1.2, gold);
        } else {
          canvas.drawCircle(p, size, star);
        }
      }
    }
  }

  /// The tiny stars of the dark theme, scattered once and for all (a fixed
  /// seed): they belong to no event.
  void _paintDust(Canvas canvas, Size size) {
    final random = math.Random(3);
    final dust = Paint();
    final count = (size.width * size.height / 9000).round();
    for (var i = 0; i < count; i++) {
      dust.color = ink.withValues(alpha: 0.08 + random.nextDouble() * 0.14);
      canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          0.5 + random.nextDouble() * 0.6,
          dust);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.sky != sky || old.ink != ink || old.night != night;
}
