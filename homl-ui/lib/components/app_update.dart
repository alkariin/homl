import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:homl/data/repositories/settings.repository.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/helpers/version.dart';
import 'package:homl/l10n/app_localizations.dart';

/// App bar button shown when the server runs a newer release than this app:
/// whoever upgraded the server can upgrade the app too, since every release
/// publishes a signed APK (homl-web/docs/deployment.md, "Building the
/// clients"). Android only, the one platform with a published build. Opens
/// [AppUpdateDialog].
///
/// Asked each time the server is found reachable again, so a phone started
/// away from a LAN-only server still learns about it back home.
class AppUpdateButton extends StatefulWidget {
  const AppUpdateButton({super.key});

  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton> {
  StreamSubscription<Reachability>? _reachabilitySubscription;
  ({String release, String installed})? _update;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final repository = context.read<SettingsRepository>();
    _reachabilitySubscription = ServerReachability.instance.stream
        .where((reachability) => reachability == Reachability.online)
        .listen((_) => _check(repository));
  }

  Future<void> _check(SettingsRepository repository) async {
    if (_update != null) return;
    final String installed;
    try {
      installed = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return;
    }
    final server = await repository.getServerVersion();
    if (server == null || !mounted) return;
    final release = newerServerRelease(server: server, app: installed);
    if (release != null) {
      setState(() => _update = (release: release, installed: installed));
    }
  }

  @override
  void dispose() {
    _reachabilitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    if (update == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppLocalizations.of(context)!.update_available,
      icon: const Icon(Icons.system_update_outlined),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => AppUpdateDialog(
            release: update.release, installed: update.installed),
      ),
    );
  }
}

Future<bool> _openExternally(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Names the release the server runs and the one installed, and opens the
/// release page in the browser, where the APK is. Obtainium users get the
/// update from Obtainium instead, so the dialog says that too.
class AppUpdateDialog extends StatelessWidget {
  final String release;
  final String installed;

  /// Opens the release page; false when nothing could.
  final Future<bool> Function(Uri url) open;

  const AppUpdateDialog(
      {required this.release,
      required this.installed,
      this.open = _openExternally,
      super.key});

  Future<void> _openReleasePage(
      BuildContext context, AppLocalizations localization) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool opened;
    try {
      opened = await open(Uri.parse(releasePageUrl(release)));
    } catch (_) {
      opened = false;
    }
    navigator.pop();
    if (!opened) {
      showToastWith(messenger, localization.update_openFailed, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(localization.update_title(release)),
      content: Text(localization.update_body(release, installed)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localization.update_later),
        ),
        FilledButton(
          onPressed: () => _openReleasePage(context, localization),
          child: Text(localization.update_open),
        ),
      ],
    );
  }
}
