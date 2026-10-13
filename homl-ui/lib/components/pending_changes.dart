import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:homl/data/sync/outbox.dart';
import 'package:homl/data/sync/sync_engine.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/server_reachability.dart';
import 'package:homl/l10n/app_localizations.dart';

/// App bar button shown while changes made offline wait to be sent: the
/// count, in red when some are held back. Opens [PendingChangesSheet].
class PendingChangesButton extends StatelessWidget {
  final OutboxCounts counts;

  /// The outbox changed from the sheet (a change sent or discarded).
  final VoidCallback onChanged;

  const PendingChangesButton(
      {required this.counts, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    if (counts.total == 0) return const SizedBox.shrink();
    final localization = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: localization.pending_title,
      icon: Badge(
        label: Text('${counts.total}'),
        backgroundColor:
            counts.parked > 0 ? Theme.of(context).colorScheme.error : palette.ink,
        child: const Icon(Icons.cloud_upload_outlined),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => PendingChangesSheet(onChanged: onChanged),
      ),
    );
  }
}

/// The changes made offline that the server does not have yet, oldest first:
/// what each is, and why one is held back. Each can be discarded; the held
/// back ones can be tried again.
class PendingChangesSheet extends StatefulWidget {
  final VoidCallback onChanged;

  const PendingChangesSheet({required this.onChanged, super.key});

  @override
  State<PendingChangesSheet> createState() => _PendingChangesSheetState();
}

class _PendingChangesSheetState extends State<PendingChangesSheet> {
  List<(OutboxOp, String)>? _items;
  bool _busy = false;

  bool _started = false;

  /// Not in initState: the summaries need the locale, an inherited widget.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final locale = Localizations.localeOf(context).toString();
    final ops = await Outbox.instance.ops();
    final items = [for (final op in ops) (op, await _summary(op, locale))];
    if (mounted) setState(() => _items = items);
  }

  /// A line telling which event or tag the op is about, in clear.
  Future<String> _summary(OutboxOp op, String locale) async {
    final source = op.kind == OpKind.deleteEvent ? op.base : op.body;
    if (source == null) return '';
    if (op.kind == OpKind.createTag) return _plain(source['tag']);

    final description = await _plain(source['description']);
    final date = source['date'] is String
        ? DateFormat.yMMMd(locale)
            .format(DateTime.parse(source['date'] as String))
        : '';
    return [date, if (description.isNotEmpty) description].join(' · ');
  }

  static Future<String> _plain(Object? value) async {
    if (value is! String) return '';
    try {
      return await E2ee().decrypt(value);
    } catch (_) {
      return value;
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      widget.onChanged();
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  String _kindLabel(AppLocalizations l10n, OpKind kind) => switch (kind) {
        OpKind.createEvent => l10n.pending_createEvent,
        OpKind.updateEvent => l10n.pending_updateEvent,
        OpKind.deleteEvent => l10n.pending_deleteEvent,
        OpKind.createTag => l10n.pending_createTag,
      };

  String _statusLabel(AppLocalizations l10n, ParkReason? reason) =>
      switch (reason) {
        null => l10n.pending_waiting,
        ParkReason.refused => l10n.pending_refused,
        ParkReason.missingTag => l10n.pending_missingTag,
        ParkReason.encryptionChanged => l10n.pending_encryptionChanged,
        ParkReason.dataReplaced => l10n.pending_dataReplaced,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items;
    final anyParked = items?.any((item) => item.$1.parked != null) ?? false;
    final anyWaiting = items?.any((item) => item.$1.parked == null) ?? false;
    final online = !ServerReachability.instance.isOffline;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pending_title,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(l10n.pending_info),
            const SizedBox(height: 12),
            if (items == null)
              const Center(child: CircularProgressIndicator())
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (op, summary) in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(op.parked == null
                            ? Icons.schedule
                            : Icons.error_outline,
                            color: op.parked == null
                                ? null
                                : Theme.of(context).colorScheme.error),
                        title: Text(_kindLabel(l10n, op.kind)),
                        subtitle: Text([
                          if (summary.isNotEmpty) summary,
                          _statusLabel(l10n, op.parked),
                        ].join('\n')),
                        isThreeLine: summary.isNotEmpty,
                        trailing: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _act(() => Outbox.instance.discard(op.id)),
                          child: Text(l10n.pending_discard),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (anyParked)
                  TextButton(
                    onPressed: _busy || !online
                        ? null
                        : () => _act(() async {
                              await Outbox.instance.retryParked();
                              await SyncEngine.instance.sync();
                            }),
                    child: Text(l10n.pending_retry),
                  ),
                if (anyWaiting)
                  FilledButton(
                    onPressed: _busy || !online
                        ? null
                        : () => _act(SyncEngine.instance.sync),
                    child: Text(l10n.pending_sendNow),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
