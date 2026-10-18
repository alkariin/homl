import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/pages/app/bloc/app_cubit.dart';

/// What the settings call an appearance.
String themeModeLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.settings_themeSystem,
      ThemeMode.light => l10n.settings_themeLight,
      ThemeMode.dark => l10n.settings_themeDark,
    };

/// Lets the user pick the appearance: as the system, light or dark. Applied
/// at once and kept on this device (see [AppCubit.updateThemeMode]).
class AppearanceDialog {
  static Route<void> route(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appCubit = context.read<AppCubit>();
    final current = appCubit.state.themeMode;

    return DialogRoute<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(localizations.settings_selectAppearance),
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              leading: Icon(mode == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(themeModeLabel(localizations, mode)),
              onTap: () {
                unawaited(appCubit.updateThemeMode(mode));
                Navigator.of(dialogContext).pop();
              },
            ),
        ],
      ),
    );
  }
}
