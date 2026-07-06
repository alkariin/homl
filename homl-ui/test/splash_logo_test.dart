import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homl/components/logo.dart';
import 'package:homl/pages/splash/splash.dart';

void main() {
  testWidgets('splash page shows the logo image', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(find.byType(HomlLogo), findsOneWidget);
    expect(find.text('HOML'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/logo.png');
  });
}
