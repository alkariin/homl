import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat.yMMMMEEEEd(locale).format(event.date),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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
              if (event.tags.isNotEmpty)
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: event.tags
                      .map((tag) => components.Tag(
                          id: tag.id,
                          text: tag.tag,
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
