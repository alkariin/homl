import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/helpers/language.dart';
import 'package:homl/pages/settings/bloc/settings_bloc.dart';

class LanguageDialog {
  static Route<String> route(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final lang = stringToLanguage(localizations.localeName);

    return DialogRoute<String>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: SimpleDialog(
          title: Text(localizations.settings_selectLanguage),
          children: [
            _DialogItem(
              selected: lang == Language.fr,
              text: Language.fr.longText,
            ),
            _DialogItem(
              selected: lang == Language.de,
              text: Language.de.longText,
            ),
            _DialogItem(
              selected: lang == Language.en,
              text: Language.en.longText,
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
  });

  final bool selected;
  final String text;

  @override
  Widget build(BuildContext context) {
    void onTap(String value) {
      Language language = longStringToLanguage(value);
      context.read<SettingsBloc>().add(UpdateLanguage(language));
      Navigator.of(context).pop();
    }

    return InkWell(
      onTap: () {
        onTap(text);
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
