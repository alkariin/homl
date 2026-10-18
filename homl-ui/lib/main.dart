import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'components/logo.dart';
import 'helpers/bloc_observer.dart';
import 'pages/app/bloc/app_cubit.dart';
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
  await precacheLogo();
  // The saved appearance too: a dark choice on a light system must not show
  // a light frame first.
  runApp(App(themeMode: await AppCubit.loadThemeMode()));
}
