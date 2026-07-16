import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/pages/splash/splash.dart';

void main() {
  testWidgets('splash page shows only the bare logo artwork', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    final logo = tester.widget<HomlLogo>(find.byType(HomlLogo));
    expect(logo.circled, isFalse);
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
    HomlLogo logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, 0.0);
    expect(find.byType(SvgPicture), findsNWidgets(2));

    // Mid-animation: partially revealed, the reveal starts right away.
    await tester.pump(const Duration(milliseconds: 500));
    logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, greaterThan(0.0));
    expect(logo.colorProgress, lessThan(1.0));

    // Done: back to the plain two-tone artwork (single picture).
    await tester.pump(const Duration(seconds: 1));
    logo = tester.widget(find.byType(HomlLogo));
    expect(logo.colorProgress, 1.0);
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('logo keeps its circle by default and drops it when uncircled',
      (tester) async {
    bool hasCircleDecoration() =>
        tester.widgetList<Container>(find.byType(Container)).any((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration &&
              decoration.shape == BoxShape.circle;
        });

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomlLogo())));
    expect(hasCircleDecoration(), isTrue);

    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomlLogo(circled: false))));
    expect(hasCircleDecoration(), isFalse);
  });
}
