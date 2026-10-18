import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/theme.dart';

/// The ink the logo artwork is drawn with (assets/images/logo.svg).
const Color _artworkInk = Color(0xFF000000);

/// Repaints the logo artwork: its gold strokes (drawn in [yellow], which is
/// the palette's #D3A934) in [gold], its black ones in [ink].
class _LogoColorMapper extends ColorMapper {
  final Color gold;
  final Color ink;

  const _LogoColorMapper({required this.gold, required this.ink});

  @override
  Color substitute(
          String? id, String elementName, String attributeName, Color color) =>
      color == yellow
          ? gold
          : color == _artworkInk
              ? ink
              : color;

  // Part of the SVG cache key: equal mappers share one parsed artwork
  // instead of parsing it again on every frame of an animation.
  @override
  bool operator ==(Object other) =>
      other is _LogoColorMapper && other.gold == gold && other.ink == ink;

  @override
  int get hashCode => Object.hash(gold, ink);
}

/// The artwork with its gold strokes in [tint] (null keeps the gold) and its
/// black ones in [ink].
SvgAssetLoader _loader(Color? tint, Color ink) => SvgAssetLoader(
      'assets/images/logo.svg',
      colorMapper: tint == null && ink == _artworkInk
          ? null
          : _LogoColorMapper(gold: tint ?? yellow, ink: ink),
    );

Widget _hash(Color? tint, Color ink) =>
    SvgPicture(_loader(tint, ink), fit: BoxFit.contain);

/// Parses the artwork the splash starts with, in both brightnesses (all ink,
/// then the gold revealed over it), so its first frame already shows the
/// hash instead of popping it in once the SVG loads.
Future<void> precacheLogo() => Future.wait([
      for (final ink in [HomlColors.light.ink, HomlColors.dark.ink])
        for (final tint in [null, ink])
          svg.cache.putIfAbsent(_loader(tint, ink).cacheKey(null),
              () => _loader(tint, ink).loadBytes(null)),
    ]);

/// The homl "#" logo: the two-tone hash from the design export
/// (assets/images/logo.svg).
///
/// [tint] recolors the gold strokes only — the others stay in the theme's
/// ink (black, or the soft white of the dark theme). Null keeps the normal
/// two-tone artwork, which is the resting state of the mark.
class HomlLogo extends StatelessWidget {
  final double size;
  final Color? tint;

  const HomlLogo({this.size = 51, this.tint, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: size, height: size, child: _hash(tint, context.homl.ink));
  }
}

/// The hash caught between two colorings: [from] underneath and [to] painted
/// over it, revealed from the base of the gold strokes (bottom-left) to their
/// tip (top-right) as [progress] goes from 0 to 1.
///
/// Both layers are stacked in the same tight box, so the artwork keeps the
/// exact same size throughout the sweep (a loose Stack would render it
/// smaller until the animation ends). At 1 only the [to] artwork is left.
class HomlLogoSweep extends StatelessWidget {
  final double size;
  final Color? from;
  final Color? to;
  final double progress;

  /// Softness of the reveal front, as a fraction of the sweep.
  static const double _fade = 0.25;

  const HomlLogoSweep(
      {required this.progress, this.from, this.to, this.size = 51, super.key});

  @override
  Widget build(BuildContext context) {
    if (progress >= 1.0) return HomlLogo(size: size, tint: to);

    final front = progress * (1 + _fade);
    final ink = context.homl.ink;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _hash(from, ink)),
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                stops: [
                  (front - _fade).clamp(0.0, 1.0),
                  front.clamp(0.0, 1.0),
                ],
              ).createShader(rect),
              child: _hash(to, ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The logo as it lives in the app bar: the artwork alone — no circle, no
/// button — animating from one coloring to the next.
///
/// Taking a color on is the splash reveal (the gold strokes fill base to
/// tip); every other change is a plain fade, since a second reveal on every
/// keystroke would pull the eye away from the field. Null is the resting
/// two-tone gold.
class HomlMark extends StatefulWidget {
  final double size;
  final Color? tint;

  const HomlMark({this.size = 30, this.tint, super.key});

  @override
  State<HomlMark> createState() => _HomlMarkState();
}

class _HomlMarkState extends State<HomlMark>
    with SingleTickerProviderStateMixin {
  static const _sweepDuration = Duration(milliseconds: 350);
  static const _fadeDuration = Duration(milliseconds: 200);

  /// Rests at 1: the mark is static until a new tint arrives.
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _sweepDuration, value: 1);

  Color? _from;
  late Color? _to = widget.tint;
  bool _sweeping = false;

  @override
  void didUpdateWidget(covariant HomlMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tint == _to) return;

    // An interrupted animation restarts from the color it was heading to,
    // which is what is (nearly) on screen.
    _from = _to;
    _to = widget.tint;
    _sweeping = _from == null && _to != null;
    _controller.duration = _sweeping ? _sweepDuration : _fadeDuration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decorative and inert: it must not read as a control to a screen reader
    // any more than to a finger.
    return ExcludeSemantics(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;
            final ink = context.homl.ink;
            if (progress >= 1.0) {
              return HomlLogo(size: widget.size, tint: _to);
            }
            if (_sweeping) {
              return HomlLogoSweep(
                  size: widget.size, from: _from, to: _to, progress: progress);
            }
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: _hash(_from, ink)),
                  Positioned.fill(
                      child:
                          Opacity(opacity: progress, child: _hash(_to, ink))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
