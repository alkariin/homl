import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/input.dart';
import 'package:homl/data/repositories/data_transfer.repository.dart';
import 'package:homl/data/transfer/export_file.dart';
import 'package:homl/l10n/app_localizations.dart';
import 'package:homl/pages/account/bloc/data_transfer_cubit.dart';

/// The shortest export password accepted: the file can be attacked offline,
/// so it is the one guard besides the key derivation cost.
const exportPasswordMinLength = 8;

/// What the user chose in [ExportDialog]: the password to seal the file
/// with, or none.
typedef ExportChoice = ({String? password});

/// Export options: protect the file with a password or not. On by default
/// for an E2EE account, whose data would otherwise leave the device in clear
/// — said in red when switched off.
class ExportDialog extends StatefulWidget {
  final bool isE2eeEnabled;

  const ExportDialog({required this.isE2eeEnabled, super.key});

  static Future<ExportChoice?> show(BuildContext context,
          {required bool isE2eeEnabled}) =>
      showDialog<ExportChoice>(
          context: context,
          builder: (_) => ExportDialog(isE2eeEnabled: isE2eeEnabled));

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  late bool _protect = widget.isE2eeEnabled;
  bool _toggleEye = true;
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localization.export_title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(localization.export_info),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localization.export_passwordSwitch),
                value: _protect,
                onChanged: (value) => setState(() => _protect = value),
              ),
              if (_protect) ...[
                Input(
                  inputType: InputType.password,
                  labelText: localization.export_password,
                  toggleEye: _toggleEye,
                  onToggleEye: () => setState(() => _toggleEye = !_toggleEye),
                  controller: _password,
                  validator: (value) => value.length >= exportPasswordMinLength
                      ? null
                      : localization.export_passwordTooShort,
                ),
                const SizedBox(height: 12),
                Input(
                  inputType: InputType.password,
                  labelText: localization.export_passwordRepeat,
                  toggleEye: _toggleEye,
                  onToggleEye: () => setState(() => _toggleEye = !_toggleEye),
                  controller: _repeat,
                  validator: (value) => value == _password.text
                      ? null
                      : localization.account_passwordsNotIdentical,
                ),
                const SizedBox(height: 12),
                Text(localization.export_passwordHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ] else if (widget.isE2eeEnabled)
                Text(localization.export_e2eeWarning,
                    style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localization.global_cancel),
        ),
        TextButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop<ExportChoice>(
                context, (password: _protect ? _password.text : null));
          },
          child: Text(localization.export_confirm),
        ),
      ],
    );
  }
}

/// Asks the password of a protected file; [wrong] after a failed attempt.
class ImportPasswordDialog extends StatefulWidget {
  final bool wrong;

  const ImportPasswordDialog({required this.wrong, super.key});

  static Future<String?> show(BuildContext context, {required bool wrong}) =>
      showDialog<String>(
          context: context, builder: (_) => ImportPasswordDialog(wrong: wrong));

  @override
  State<ImportPasswordDialog> createState() => _ImportPasswordDialogState();
}

class _ImportPasswordDialogState extends State<ImportPasswordDialog> {
  bool _toggleEye = true;
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localization.import_passwordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localization.import_passwordInfo),
          const SizedBox(height: 16),
          Input(
            inputType: InputType.password,
            labelText: localization.export_password,
            toggleEye: _toggleEye,
            onToggleEye: () => setState(() => _toggleEye = !_toggleEye),
            controller: _password,
            errorText: widget.wrong ? localization.import_passwordWrong : null,
            validator: (_) => null,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localization.global_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _password.text),
          child: Text(localization.import_open),
        ),
      ],
    );
  }
}

/// What the file holds, and how the import treats it, before anything is
/// written.
Future<bool> confirmImport(BuildContext context, ExportFile file) async {
  final localization = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).toString();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localization.import_confirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localization.import_confirmInfo(
                DateFormat.yMMMd(locale).format(file.exportedAt.toLocal()))),
            const SizedBox(height: 8),
            _Bullet(localization.import_countEvents(file.events.length)),
            _Bullet(localization.import_countTags(file.tagCount)),
            if (file.groupCount > 0)
              _Bullet(localization.import_countGroups(file.groupCount)),
            _Bullet(
                localization.import_countCategories(file.categories.length)),
            const SizedBox(height: 12),
            Text(localization.import_confirmMerge),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(localization.global_cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(localization.import_confirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// The import under way. It cannot be dismissed: the flow that opened it
/// closes it once the import is over.
class ImportProgressDialog extends StatelessWidget {
  const ImportProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: BlocBuilder<DataTransferCubit, DataTransferState>(
          builder: (context, state) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                  value: state.total == 0 ? null : state.done / state.total),
              const SizedBox(height: 16),
              Text(localization.import_progress(state.done, state.total)),
              const SizedBox(height: 8),
              Text(localization.import_keepOpen,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the import did.
Future<void> showImportReport(BuildContext context, ImportReport report) {
  final localization = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(localization.import_doneTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report.changedAnything) ...[
              Text(localization.import_doneAdded),
              const SizedBox(height: 8),
              if (report.eventsCreated > 0)
                _Bullet(localization.import_countEvents(report.eventsCreated)),
              if (report.tagsCreated > 0)
                _Bullet(localization.import_countTags(report.tagsCreated)),
              if (report.groupsCreated > 0)
                _Bullet(localization.import_countGroups(report.groupsCreated)),
              if (report.categoriesCreated > 0)
                _Bullet(localization
                    .import_countCategories(report.categoriesCreated)),
            ] else
              Text(localization.import_doneNothing),
            if (report.eventsExisting > 0) ...[
              const SizedBox(height: 12),
              Text(localization.import_doneExisting(report.eventsExisting)),
            ],
            if (report.skipped > 0) ...[
              const SizedBox(height: 12),
              Text(localization.import_doneSkipped(report.skipped),
                  style: TextStyle(color: Colors.red.shade400)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localization.global_close),
        ),
      ],
    ),
  );
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 2),
        child: Text('• $text'),
      );
}
