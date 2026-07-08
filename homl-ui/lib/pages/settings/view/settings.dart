import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/settings/view/home_tab_dialog.dart';
import 'package:homl/pages/settings/view/language_dialog.dart';

import 'package:homl/pages/settings/bloc/settings_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (BuildContext context) =>
                SettingsBloc(context.read<SettingsRepository>())),
      ],
      child: const SettingsView(),
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return MultiBlocListener(
        listeners: [
          BlocListener<SettingsBloc, SettingsState>(listener: (context, state) {
            if (state.errorModal != null) {
              final settingsBloc = context.read<SettingsBloc>();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.errorModal!.localize(localization)),
                  action: SnackBarAction(
                      label: localization.global_close, onPressed: () {}),
                  duration: const Duration(seconds: 5),
                )).closed.then(
                  (_) {
                    settingsBloc.add(EndModal());
                  },
                );
            }
          }),
        ],
        child: Scaffold(
            appBar: AppBar(
              title: const Text("Homl"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
              return Column(
                children: [
                  ListTile(
                    title: Text(localization.settings_language),
                    onTap: () {
                      Navigator.push(context, LanguageDialog.route(context));
                    },
                  ),
                  ListTile(
                    title: Text(localization.settings_homeTab),
                    subtitle: Text(state.settings?.defaultScreen ?? false
                        ? localization.nav_add
                        : localization.nav_search),
                    onTap: () {
                      Navigator.push(context, HomeTabDialog.route(context));
                    },
                  ),
                ],
              );
            })));
  }
}
