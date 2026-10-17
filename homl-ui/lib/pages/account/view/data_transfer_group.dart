import 'dart:async';
import 'dart:developer';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/components/settings_group.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/bloc/data_transfer_cubit.dart';
import 'package:homl/pages/account/view/data_transfer_dialogs.dart';

/// `homl-export-2026-10-17.json`, `-encrypted` before the extension for a
/// password-protected file so the two cannot be mixed up in a folder.
String exportFileName(DateTime now, {required bool sealed}) =>
    'homl-export-${formatDay(now)}${sealed ? '-encrypted' : ''}.json';

/// The "Export my data" and "Import data" rows of the account page, and the
/// flows behind them (homl-web/docs/data-export.md).
class DataTransferGroup extends StatelessWidget {
  final bool isE2eeEnabled;

  const DataTransferGroup({required this.isE2eeEnabled, super.key});

  Future<void> _export(BuildContext context) async {
    final cubit = context.read<DataTransferCubit>();
    final localization = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final choice =
        await ExportDialog.show(context, isE2eeEnabled: isE2eeEnabled);
    if (choice == null) return;

    final bytes = await cubit.export(password: choice.password);
    if (bytes == null) return;

    final String? path;
    try {
      path = await FilePicker.saveFile(
          fileName:
              exportFileName(DateTime.now(), sealed: choice.password != null),
          bytes: bytes);
    } catch (err) {
      log('Saving the export failed', name: 'DataTransferGroup', error: err);
      showToastWith(messenger, localization.export_failed, isError: true);
      return;
    }
    // Null is a cancel, except on the web: it downloads the file and never
    // answers anything else.
    if (path != null || kIsWeb) {
      showToastWith(messenger, localization.export_saved);
    }
  }

  Future<void> _import(BuildContext context) async {
    final cubit = context.read<DataTransferCubit>();

    final FilePickerResult? picked;
    try {
      // Any type: some Android file managers do not tag .json as JSON, and
      // the content is checked anyway.
      picked = await FilePicker.pickFiles(withData: true);
    } catch (err) {
      log('Picking the import failed', name: 'DataTransferGroup', error: err);
      return;
    }
    final bytes = picked?.files.singleOrNull?.bytes;
    if (bytes == null || !context.mounted) return;

    var (result, file) = await cubit.read(bytes);
    while (result == ReadResult.passwordRequired ||
        result == ReadResult.passwordWrong) {
      if (!context.mounted) return;
      final password = await ImportPasswordDialog.show(context,
          wrong: result == ReadResult.passwordWrong);
      if (password == null) return;
      (result, file) = await cubit.read(bytes, password: password);
    }
    if (file == null || !context.mounted) return;

    if (!await confirmImport(context, file) || !context.mounted) return;

    // Left open while the import runs, closed by this flow once it is over.
    final navigator = Navigator.of(context);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const ImportProgressDialog()),
    ));
    final report = await cubit.import(file);
    navigator.pop();

    if (report != null && context.mounted) {
      await showImportReport(context, report);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<DataTransferCubit, DataTransferState>(
      listenWhen: (previous, current) =>
          current.modal != null && previous.modal != current.modal,
      listener: (context, state) {
        final cubit = context.read<DataTransferCubit>();
        showToast(context, state.modal!.localize(localization),
                duration: const Duration(seconds: 5))
            .closed
            .then((_) => cubit.endModal());
      },
      builder: (context, state) => SettingsGroup(children: [
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(localization.account_exportData),
          subtitle: Text(localization.account_exportDataHint),
          trailing: Icon(Icons.chevron_right,
              size: 20, color: ink.withValues(alpha: 0.3)),
          enabled: !state.busy,
          onTap: () => _export(context),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: Text(localization.account_importData),
          subtitle: Text(localization.account_importDataHint),
          trailing: Icon(Icons.chevron_right,
              size: 20, color: ink.withValues(alpha: 0.3)),
          enabled: !state.busy,
          onTap: () => _import(context),
        ),
        // The import shows its own progress, in its dialog.
        if (state.status == DataTransferStatus.exporting ||
            state.status == DataTransferStatus.reading)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: LinearProgressIndicator(),
          ),
      ]),
    );
  }
}
