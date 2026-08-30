import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/components/settings_group.dart';
import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/pages/settings/view/home_tab_dialog.dart';
import 'package:homl/pages/settings/view/language_dialog.dart';

import 'package:homl/pages/settings/bloc/settings_cubit.dart';

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
                SettingsCubit(context.read<SettingsRepository>())),
      ],
      child: const SettingsView(),
    );
  }
}

/// "App 0.1.0+1 · Server v0.1.0", each half only once known; the server half
/// turns into "unreachable" when /healthz did not answer.
String _versionSummary(AppLocalizations l10n, SettingsState state) {
  final parts = <String>[];
  if (state.appVersion != null) {
    parts.add(l10n.settings_versionApp(state.appVersion!));
  }
  if (state.serverVersion != null) {
    parts.add(l10n.settings_versionServer(state.serverVersion!));
  } else if (state.versionsLoaded) {
    parts.add(l10n.settings_versionServerUnavailable);
  }
  return parts.isEmpty ? '…' : parts.join(' · ');
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return MultiBlocListener(
        listeners: [
          BlocListener<SettingsCubit, SettingsState>(
              listener: (context, state) {
            if (state.errorModal != null) {
              final settingsCubit = context.read<SettingsCubit>();
              showToast(context, state.errorModal!.localize(localization),
                      duration: const Duration(seconds: 5))
                  .closed
                  .then(
                (_) {
                  settingsCubit.endModal();
                },
              );
            }
          }),
        ],
        child: Scaffold(
            appBar: AppBar(
              title: Text(localization.settings),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            body: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SettingsGroup(children: [
                    ListTile(
                      leading: const Icon(Icons.translate),
                      title: Text(localization.settings_language),
                      trailing: Icon(Icons.chevron_right,
                          size: 20, color: ink.withValues(alpha: 0.3)),
                      onTap: () {
                        Navigator.push(context, LanguageDialog.route(context));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: Text(localization.settings_homeTab),
                      subtitle: Text(state.settings?.defaultScreen ?? false
                          ? localization.nav_add
                          : localization.nav_search),
                      trailing: Icon(Icons.chevron_right,
                          size: 20, color: ink.withValues(alpha: 0.3)),
                      onTap: () {
                        Navigator.push(context, HomeTabDialog.route(context));
                      },
                    ),
                  ]),
                  SettingsGroup(children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(localization.settings_about),
                      subtitle: Text(_versionSummary(localization, state)),
                    ),
                  ]),
                ],
              );
            })));
  }
}
