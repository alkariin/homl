import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/pin_dialog.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/language.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/pages/app/bloc/app_cubit.dart';
import 'package:homl/pages/home/view/home.dart';
import 'package:homl/pages/login/bloc/login_cubit.dart';
import 'package:homl/pages/login/view/login.dart';
import 'package:homl/pages/splash/view/splash_page.dart';
import 'package:homl/services/authentication/bloc/authentication_cubit.dart';
import 'package:homl/data/repositories/api.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/data/repositories/users.repository.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final UsersRepository _usersRepository;
  late final SettingsRepository _settingsRepository;
  late final Api _apiInstance;

  @override
  void initState() {
    super.initState();
    _apiInstance = Api();
    _usersRepository = UsersRepository();
    _settingsRepository = SettingsRepository();
  }

  @override
  void dispose() {
    _apiInstance.dispose();
    _settingsRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultLanguage =
        stringToLanguage(PlatformDispatcher.instance.locale.languageCode);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UsersRepository>.value(value: _usersRepository),
        RepositoryProvider<SettingsRepository>.value(
            value: _settingsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthenticationCubit(_settingsRepository)),
          BlocProvider(create: (_) => LoginCubit(_usersRepository)),
          BlocProvider(
              create: (_) => AppCubit(defaultLanguage, _settingsRepository)),
        ],
        child: AppView(_apiInstance),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  final Api _apiInstance;

  const AppView(this._apiInstance, {super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  NavigatorState get _navigator => _navigatorKey.currentState!;

  Future<bool> onPinChanged(String pin) async {
    return widget._apiInstance.sendPinAuth(pin);
  }

  void onReturnToLogin() {
    widget._apiInstance.cancelPinAuth();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppCubit, AppState>(builder: (context, state) {
      return MaterialApp(
        navigatorKey: _navigatorKey,
        theme: homlTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(state.locale.text),
        builder: (context, child) {
          return MultiBlocListener(listeners: [
            BlocListener<AppCubit, AppState>(
              listener: (context, state) {
                if (state.errorModal != null) {
                  final localization = AppLocalizations.of(context)!;
                  final appCubit = context.read<AppCubit>();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(state.errorModal!.localize(localization)),
                      duration: const Duration(seconds: 5),
                    )).closed.then((_) {
                      appCubit.endErrorModal();
                    });
                }
              },
            ),
            BlocListener<AuthenticationCubit, AuthenticationState>(
              listener: (context, state) {
                switch (state.status) {
                  case AuthenticationStatus.authenticated:
                    // get settings here if you want to remove it from authentication_bloc
                    _navigator.pushAndRemoveUntil<void>(
                        HomePage.route(
                            context.read<LoginCubit>().state.username),
                        (route) => false);
                    break;
                  case AuthenticationStatus.unauthenticated:
                    _navigator.pushAndRemoveUntil<void>(
                        LoginPage.route(), (route) => false);
                    break;
                  case AuthenticationStatus.pinCheck:
                    _navigator.push(PinDialog.route(context, onPinChanged,
                        returnToLogin: onReturnToLogin));
                    break;
                  case AuthenticationStatus.unknown:
                    break;
                }
              },
            ),
          ], child: child ?? const SizedBox.shrink());
        },
        onGenerateRoute: (_) => SplashPage.route(),
      );
    });
  }
}
