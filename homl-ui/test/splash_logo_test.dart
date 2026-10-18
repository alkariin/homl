import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/pages/splash/splash.dart';

void main() {
  testWidgets('splash page shows only the bare logo artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(HomlLogoSweep), findsOneWidget);
    expect(find.text('HOML'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    expect(pictures, isNotEmpty);
    for (final picture in pictures) {
      expect((picture.bytesLoader as SvgAssetLoader).assetName,
          'assets/images/logo.svg');
    }
  });

  testWidgets('splash logo fills its gold strokes over one second',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    // Fully black at first: the reveal layers are stacked (2 pictures).
    HomlLogoSweep logo = tester.widget(find.byType(HomlLogoSweep));
    expect(logo.progress, 0.0);
    expect(find.byType(SvgPicture), findsNWidgets(2));

    // Still black during the short hold that covers the native splash fade.
    await tester.pump(const Duration(milliseconds: 200));
    logo = tester.widget(find.byType(HomlLogoSweep));
    expect(logo.progress, 0.0);

    // Mid-animation: partially revealed.
    await tester.pump(const Duration(milliseconds: 500));
    logo = tester.widget(find.byType(HomlLogoSweep));
    expect(logo.progress, greaterThan(0.0));
    expect(logo.progress, lessThan(1.0));

    // Done: back to the plain two-tone artwork (single picture).
    await tester.pump(const Duration(seconds: 1));
    logo = tester.widget(find.byType(HomlLogoSweep));
    expect(logo.progress, 1.0);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  group('in the dark theme', () {
    Future<SvgAssetLoader> loaderOf(WidgetTester tester, Widget logo,
        {Brightness brightness = Brightness.dark}) async {
      await tester.pumpWidget(MaterialApp(
          theme: homlTheme(brightness: brightness), home: Center(child: logo)));
      return tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader
          as SvgAssetLoader;
    }

    testWidgets('the black strokes take the soft white ink, the gold stays',
        (tester) async {
      final mapper = (await loaderOf(tester, const HomlLogo())).colorMapper!;

      expect(mapper.substitute(null, 'path', 'fill', const Color(0xFF000000)),
          HomlColors.dark.ink);
      expect(mapper.substitute(null, 'path', 'fill', yellow), yellow);
    });

    testWidgets('a tint recolors the gold strokes only', (tester) async {
      const tint = Color(0xFF5B8DEF);
      final mapper =
          (await loaderOf(tester, const HomlLogo(tint: tint))).colorMapper!;

      expect(mapper.substitute(null, 'path', 'fill', yellow), tint);
      expect(mapper.substitute(null, 'path', 'fill', const Color(0xFF000000)),
          HomlColors.dark.ink);
    });

    testWidgets('the light theme draws the artwork as it is', (tester) async {
      final loader = await loaderOf(tester, const HomlLogo(),
          brightness: Brightness.light);

      expect(loader.colorMapper, isNull);
    });

    testWidgets('the same coloring is parsed once', (tester) async {
      const tint = Color(0xFF5B8DEF);
      final first = await loaderOf(tester, const HomlLogo(tint: tint));
      final second =
          await loaderOf(tester, const HomlLogo(tint: tint, size: 30));

      // The loader (its color mapper included) is the SVG cache key: equal
      // loaders share one parsed artwork, animation frames too.
      expect(second, first);
    });
  });
}
