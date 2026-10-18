import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/server_address.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Where the app finds its server (homl-ui/README.md, "Server address"): the
/// address is typed, checked against its `/healthz`, and kept once a homl
/// server answered there.
class ServerDialog extends StatefulWidget {
  const ServerDialog({super.key});

  /// The check of the server now in use, or null when the user cancelled.
  static Future<ServerCheck?> show(BuildContext context) {
    return showDialog<ServerCheck>(
        context: context, builder: (_) => const ServerDialog());
  }

  @override
  State<ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<ServerDialog> {
  late final TextEditingController _controller = TextEditingController(
      text: ServerAddress.isSet
          ? displayServerAddress(ServerAddress.current)
          : '');
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations localization) async {
    if (_checking) return;
    final apiBaseUrl = apiBaseUrlFor(_controller.text);
    if (apiBaseUrl == null) {
      setState(() => _error = localization.login_serverInvalid);
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });
    final check =
        await context.read<UsersRepository>().changeServer(apiBaseUrl);
    if (!mounted) return;
    if (check.outcome == ServerCheckOutcome.ok) {
      Navigator.pop(context, check);
      return;
    }
    setState(() {
      _checking = false;
      _error = switch (check.outcome) {
        ServerCheckOutcome.unreachable => localization.login_serverNoAnswer,
        ServerCheckOutcome.untrustedCertificate =>
          localization.login_serverUntrusted,
        ServerCheckOutcome.notHoml => localization.login_serverNotHoml,
        ServerCheckOutcome.ok => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final typed = apiBaseUrlFor(_controller.text);

    return AlertDialog(
      title: Text(localization.login_server),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !_checking,
              autofocus: !ServerAddress.isSet,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(localization),
              decoration: InputDecoration(
                labelText: localization.login_serverLabel,
                hintText: localization.login_serverHint,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            // Said as the address is typed: the password and the session
            // token would cross the network in clear.
            if (typed != null && isCleartext(typed)) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_open_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(localization.login_serverCleartext,
                        style: Theme.of(context).textTheme.labelMedium),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context),
          child: Text(localization.global_cancel),
        ),
        _checking
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : FilledButton(
                onPressed: () => _submit(localization),
                child: Text(localization.global_save),
              ),
      ],
    );
  }
}
