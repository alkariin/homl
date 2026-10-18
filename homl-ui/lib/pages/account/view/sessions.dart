import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/settings_group.dart';
import 'package:homl/data/models/device_session.dart';
import 'package:homl/data/repositories/users.repository.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/pages/account/bloc/sessions_cubit.dart';

/// The account's signed-in devices (homl-web/docs/auth-flows.md, "Signed-in
/// devices"): this one first, then the others, each with a way to sign it
/// out. Reached from the Security page; online only.
class SessionsPage extends StatelessWidget {
  const SessionsPage({super.key});

  static Route<void> route(BuildContext context) {
    final users = context.read<UsersRepository>();
    return MaterialPageRoute<void>(
        builder: (_) => RepositoryProvider.value(
            value: users, child: const SessionsPage()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SessionsCubit(context.read<UsersRepository>());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _SessionsView(),
    );
  }
}

class _SessionsView extends StatelessWidget {
  const _SessionsView();

  Future<bool> _confirm(BuildContext context, String title) async {
    final localization = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(localization.sessions_signOutInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localization.global_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(localization.sessions_signOut),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return BlocConsumer<SessionsCubit, SessionsState>(
      listenWhen: (previous, current) =>
          current.actionFailed && !previous.actionFailed,
      listener: (context, state) =>
          showToast(context, localization.sessions_actionFailed),
      builder: (context, state) {
        final cubit = context.read<SessionsCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(localization.account_sessions)),
          body: switch (state.status) {
            SessionsStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            SessionsStatus.failed => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(localization.sessions_failed,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: cubit.load,
                        child: Text(localization.sessions_retry),
                      ),
                    ],
                  ),
                ),
              ),
            SessionsStatus.loaded => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SettingsGroup(children: [
                    for (final session in state.sessions)
                      _SessionTile(
                        session: session,
                        onSignOut: session.current || state.busy
                            ? null
                            : () async {
                                if (await _confirm(context,
                                    localization.sessions_signOutTitle)) {
                                  await cubit.signOut(session.id);
                                }
                              },
                      ),
                  ]),
                  if (state.hasOthers)
                    SettingsGroup(children: [
                      ListTile(
                        enabled: !state.busy,
                        leading: Icon(Icons.logout, color: Colors.red.shade400),
                        title: Text(
                          localization.sessions_signOutOthers,
                          style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          if (await _confirm(context,
                              localization.sessions_signOutOthersTitle)) {
                            await cubit.signOutOthers();
                          }
                        },
                      ),
                    ]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      localization.sessions_activityNote,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: context.homl.ink.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
          },
        );
      },
    );
  }
}

/// One device: what it is, when it was last active (or that it is this
/// one), when it signed in and from where, and the sign-out button.
class _SessionTile extends StatelessWidget {
  final DeviceSession session;

  /// Null for this device (the Security page's logout is for it), or while
  /// a sign-out is on its way.
  final VoidCallback? onSignOut;

  const _SessionTile({required this.session, required this.onSignOut});

  static IconData _icon(String platform) => switch (platform) {
        'android' => Icons.phone_android,
        'ios' => Icons.phone_iphone,
        'web' => Icons.language,
        'linux' || 'macos' || 'windows' => Icons.computer,
        _ => Icons.devices_other,
      };

  static String? _platformName(String platform) => switch (platform) {
        'android' => 'Android',
        'ios' => 'iOS',
        'web' => 'Web',
        'linux' => 'Linux',
        'macos' => 'macOS',
        'windows' => 'Windows',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dates = DateFormat.yMMMd(locale).add_Hm();

    final name =
        _platformName(session.platform) ?? localization.sessions_unknownDevice;
    final version = session.version;
    final title = version == null
        ? name
        : '$name \u00b7 ${localization.sessions_app(version)}';
    final signedIn = session.createdAt == null
        ? localization.sessions_signedInUnknown
        : localization.sessions_signedIn(dates.format(session.createdAt!));

    return ListTile(
      leading: Icon(_icon(session.platform)),
      title: Text(title),
      subtitle: Text([
        session.current
            ? localization.sessions_thisDevice
            : localization
                .sessions_lastActive(dates.format(session.lastSeenAt)),
        signedIn,
        if (session.ip.isNotEmpty) session.ip,
      ].join('\n')),
      isThreeLine: true,
      // An icon, not a text button: the dates need the width.
      trailing: session.current
          ? null
          : IconButton(
              onPressed: onSignOut,
              tooltip: localization.sessions_signOut,
              icon: Icon(Icons.logout, color: Colors.red.shade400),
            ),
    );
  }
}
