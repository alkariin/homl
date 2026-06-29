import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'helpers/bloc_observer.dart';
import 'pages/app/view/app.dart';

void main() {
  Bloc.observer = GlobalBlocObserver();
  runApp(const App());
}
