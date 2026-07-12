import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/pages/splash/splash.dart';

void main() {
  testWidgets('splash page shows the logo artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(HomlLogo), findsOneWidget);
    expect(find.text('HOML'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
    expect(pictures, isNotEmpty);
    for (final picture in pictures) {
      expect((picture.bytesLoader as SvgAssetLoader).assetName,
          'assets/images/logo.svg');
    }
  });

  testWidgets('splash logo fills its gold strokes after a short delay',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    // Fully black at first: the reveal layers are stacked (2 pictures).
    HomlLogo logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, 0.0);
    expect(find.byType(SvgPicture), findsNWidgets(2));

    // Still black during the initial hold.
    await tester.pump(const Duration(milliseconds: 200));
    logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, 0.0);

    // Mid-animation: partially revealed.
    await tester.pump(const Duration(milliseconds: 400));
    logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, greaterThan(0.0));
    expect(logo.colorProgress, lessThan(1.0));

    // Done: back to the plain two-tone artwork (single picture).
    await tester.pump(const Duration(seconds: 1));
    logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, 1.0);
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
