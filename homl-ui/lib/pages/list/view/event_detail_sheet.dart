import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/event_period.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/insert.dart';

/// Bottom sheet with the full event: complete date, every tag and the whole
/// description (scrollable), plus the edit and delete actions.
void showEventDetailSheet(BuildContext context, {required Event event}) {
  final homeCubit = context.read<HomeCubit>();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: homeCubit,
      child: _EventDetailSheetBody(event: event),
    ),
  );
}

class _EventDetailSheetBody extends StatelessWidget {
  final Event event;

  const _EventDetailSheetBody({required this.event});

  /// Closes the sheet and pushes the edit form. The HomeCubit is handed over
  /// through the route because the pushed page lives outside the home
  /// provider scope (see EditEventPage).
  void _onEdit(BuildContext context) {
    final homeCubit = context.read<HomeCubit>();
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(EditEventPage.route(homeCubit, event));
  }

  void _deleteEventDialog(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();
    final sheetNavigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.list_deleteEventTitle),
        content: Text(localization.list_deleteEventInfo),
        actions: [
          TextButton(
            child: Text(localization.global_cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(localization.global_delete),
            onPressed: () {
              homeCubit.deleteEvent(event.id);
              Navigator.pop(dialogContext);
              // The event is gone: the snapshot on screen must not go stale.
              sheetNavigator.pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scrollController) =>
          BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
        // The date tags are left out, as on the card: the header already
        // prints the whole period, and a long one would put a dozen month
        // chips under it. They are search keys, not facts about this event.
        // Same category resolution as ListPage: the categories fetch over the
        // category a cached event may carry.
        final dateIds = dateCategoryIds(state.categories);
        final tags = event.tags.where((tag) {
          final idCategory =
              state.allTagsMap[tag.tag]?.idCategory ?? tag.idCategory;
          return idCategory == null || !dateIds.contains(idCategory);
        }).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PeriodHeader(event: event, locale: locale),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.pen, size: 16),
                    tooltip: localization.list_editEvent,
                    onPressed: () => _onEdit(context),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
                    tooltip: localization.global_delete,
                    onPressed: () => _deleteEventDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: tags
                      .map((tag) => components.Tag(
                          id: tag.id,
                          text: localizedTagName(tag.tag, locale),
                          color: state.allTagsMap[tag.tag]?.color))
                      .toList(),
                ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      event.description,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

/// The sheet header: the start date and, for a period, a second line — the
/// end and the length ("→ Thursday 18 June 2026 · 16 days") or, for an open
/// one, "→ ongoing · for 2 years". The elapsed part counts to today at render
/// time (never stored, so never stale) and is left out until a full day has
/// passed: a start still in the future must not read as a negative duration.
class _PeriodHeader extends StatelessWidget {
  final Event event;
  final String locale;

  const _PeriodHeader({required this.event, required this.locale});

  String? _secondLine(AppLocalizations l10n) {
    final end = event.endDate;
    if (end != null) {
      final length = periodLengthLabel(l10n, periodLength(event.date, end));
      return '→ ${DateFormat.yMMMMEEEEd(locale).format(end)} · $length';
    }
    if (event.isOngoing) {
      final elapsed = ongoingLength(event.date, DateTime.now());
      if (elapsed == null) return '→ ${l10n.event_ongoing}';
      return '→ ${l10n.event_ongoing} · ${sinceLabel(l10n, elapsed)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final second = _secondLine(AppLocalizations.of(context)!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.yMMMMEEEEd(locale).format(event.date),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        if (second != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              second,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.ink.withValues(alpha: 0.65),
              ),
            ),
          ),
      ],
    );
  }
}
