import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/pages/settings/bloc/settings_bloc.dart';

/// Lets the user pick which tab the app opens on: Search
/// (defaultScreen = false) or Add (defaultScreen = true).
class HomeTabDialog {
  static Route<String> route(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final settingsBloc = context.read<SettingsBloc>();
    final isAddHome = settingsBloc.state.settings?.defaultScreen ?? false;

    return DialogRoute<String>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: settingsBloc,
        child: SimpleDialog(
          title: Text(localizations.settings_selectHomeTab),
          children: [
            _DialogItem(
              selected: !isAddHome,
              text: localizations.nav_search,
              defaultScreen: false,
            ),
            _DialogItem(
              selected: isAddHome,
              text: localizations.nav_add,
              defaultScreen: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogItem extends StatelessWidget {
  const _DialogItem({
    required this.selected,
    required this.text,
    required this.defaultScreen,
  });

  final bool selected;
  final String text;
  final bool defaultScreen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.read<SettingsBloc>().add(UpdateDefaultScreen(defaultScreen));
        Navigator.of(context).pop();
      },
      child: ListTile(
        title: Text(text),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        ),
      ),
    );
  }
}
