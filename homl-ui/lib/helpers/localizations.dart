import 'package:material_ui/material_ui.dart';

import 'package:homl/l10n/app_localizations.dart';

/// The app's strings, plus the Material, Cupertino and widgets ones from
/// material_ui. The generated [AppLocalizations.localizationsDelegates] still
/// lists flutter_localizations' delegates, which localize the frozen in-SDK
/// Material copy: material_ui's widgets would find no French or German
/// MaterialLocalizations through them.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
