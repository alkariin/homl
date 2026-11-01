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

/// What [UpdateNoticeButton] has to say: which side is behind the other.
sealed class _Notice {}

/// The server runs [release], newer than the app's [installed]: a newer APK
/// is out.
final class _AppBehind extends _Notice {
  final String release;
  final String installed;

  _AppBehind(this.release, this.installed);
}

/// The server runs [release], older than the [minimum] this app needs.
final class _ServerBehind extends _Notice {
  final String release;
  final String minimum;

  _ServerBehind(this.release, this.minimum);
}

/// App bar button shown when the app and its server are releases apart
/// (homl-web/docs/deployment.md, "The app and its server"):
///
/// - the server runs a newer release than this app: whoever upgraded the
///   server can upgrade the app too, since every release publishes a signed
///   APK. Android only, the one platform with a published build. Opens
///   [AppUpdateDialog].
/// - the server runs a release older than [minimum] ([minServerRelease]):
///   the app was upgraded first (Obtainium installs in the background) and
///   relies on something that server does not do yet. Every platform. Opens
///   [ServerUpdateDialog].
///
/// Asked each time the server is found reachable again, so a phone started
/// away from a LAN-only server still learns about it back home, and the
/// server notice goes once that server is upgraded.
class UpdateNoticeButton extends StatefulWidget {
  /// The oldest server release this app works with: [minServerRelease],
  /// another one in the tests only.
  final String minimum;

  const UpdateNoticeButton({this.minimum = minServerRelease, super.key});

  @override
  State<UpdateNoticeButton> createState() => _UpdateNoticeButtonState();
}

class _UpdateNoticeButtonState extends State<UpdateNoticeButton> {
  StreamSubscription<Reachability>? _reachabilitySubscription;
  _Notice? _notice;

  static bool get _hasPublishedBuild =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final repository = context.read<SettingsRepository>();
    _reachabilitySubscription = ServerReachability.instance.stream
        .where((reachability) => reachability == Reachability.online)
        .listen((_) => _check(repository));
  }

  Future<void> _check(SettingsRepository repository) async {
    final server = await repository.getServerVersion();
    if (server == null || !mounted) return;
    final minimum = widget.minimum;
    final outdated = outdatedServerRelease(server: server, minimum: minimum);
    if (outdated != null) {
      setState(() => _notice = _ServerBehind(outdated, minimum));
      return;
    }
    _Notice? notice;
    if (_hasPublishedBuild) {
      try {
        final installed = (await PackageInfo.fromPlatform()).version;
        final release = newerServerRelease(server: server, app: installed);
        if (release != null) notice = _AppBehind(release, installed);
      } catch (_) {
        // Without the installed version there is nothing to compare.
      }
    }
    if (mounted) setState(() => _notice = notice);
  }

  @override
  void dispose() {
    _reachabilitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    return switch (_notice) {
      null => const SizedBox.shrink(),
      _AppBehind(:final release, :final installed) => IconButton(
          tooltip: localization.update_available,
          icon: const Icon(Icons.system_update_outlined),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                AppUpdateDialog(release: release, installed: installed),
          ),
        ),
      _ServerBehind(:final release, :final minimum) => IconButton(
          tooltip: localization.update_serverNeeded,
          icon: const Icon(Icons.dns_outlined),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) =>
                ServerUpdateDialog(server: release, minimum: minimum),
          ),
        ),
    };
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

/// Names the release the server runs and the [minimum] this app needs.
/// Nothing to open: whoever runs the server upgrades it
/// (homl-web/docs/deployment.md, "Upgrades"), and the app meanwhile does what
/// that server allows.
class ServerUpdateDialog extends StatelessWidget {
  final String server;
  final String minimum;

  const ServerUpdateDialog(
      {required this.server, required this.minimum, super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(localization.update_serverNeeded),
      content: Text(localization.update_serverBody(server, minimum)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localization.update_serverClose),
        ),
      ],
    );
  }
}
