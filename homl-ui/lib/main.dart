import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'helpers/bloc_observer.dart';
import 'pages/app/view/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The observer logs every event and state: debug builds only.
  if (kDebugMode) {
    Bloc.observer = GlobalBlocObserver();
  }
  // Parse the logo before the first frame — the native splash stays up in the
  // meantime — so the in-app splash starts with the hash already drawn instead
  // of popping it in once the SVG loads.
  const loader = SvgAssetLoader('assets/images/logo.svg');
  await svg.cache
      .putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
  runApp(const App());
}
