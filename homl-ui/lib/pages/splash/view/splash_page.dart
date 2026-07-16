import 'package:flutter/material.dart';

import 'package:homl/components/logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SplashPage());
  }

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );

  /// Holds the hash black for 250ms — the OS splash dismisses over the
  /// identical black hash — then fills the gold strokes base to tip in 1s.
  late final Animation<double> _colorProgress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    // The controller runs on wall-clock time, so starting it here would let
    // engine startup (slow on a device in debug) eat the reveal before any
    // frame is shown. Start it once the splash is actually on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _colorProgress,
          builder: (context, _) => HomlLogo(
            size: 174,
            circled: false,
            colorProgress: _colorProgress.value,
          ),
        ),
      ),
    );
  }
}
