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
    duration: const Duration(milliseconds: 1000),
  );

  /// Fills the gold strokes from their base to their tip over the full second,
  /// starting right away from the all-black hash the native splash hands off.
  late final Animation<double> _colorProgress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
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
            size: 132,
            circled: false,
            colorProgress: _colorProgress.value,
          ),
        ),
      ),
    );
  }
}
