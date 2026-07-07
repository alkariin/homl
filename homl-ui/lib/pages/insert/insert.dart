import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/components/tag.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';
import 'package:homl/pages/insert/bloc/insert_bloc.dart';
import 'package:homl/pages/list/bloc/list_bloc.dart';

class InsertPage extends StatelessWidget {
  const InsertPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const InsertPage());
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (context) => InsertBloc(
          localization,
          context.read<EventsRepository>(),
          context.read<TagsRepository>(),
          context.read<HomeBloc>()),
      child: const InsertView(),
    );
  }
}

class InsertView extends StatefulWidget {
  const InsertView({super.key});

  @override
  State<InsertView> createState() => _InsertViewState();
}

class _InsertViewState extends State<InsertView> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return BlocListener<InsertBloc, InsertState>(
      listener: (context, state) {
        final insertBloc = context.read<InsertBloc>();
        if (state.status == InsertStatus.success) {
          _descriptionController.clear();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text(localization.insert_eventCreated)));
          // Keep the search tab in sync with the new event
          context.read<ListBloc>().add(FetchEvents());
          insertBloc.add(EndInsertModal());
        } else if (state.modal != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.modal!),
              action: SnackBarAction(label: 'close', onPressed: () {}),
              duration: const Duration(seconds: 5),
            )).closed.then((_) {
              insertBloc.add(EndInsertModal());
            });
        }
      },
      child: BlocBuilder<HomeBloc, HomeState>(builder: (context, homeState) {
        return BlocBuilder<InsertBloc, InsertState>(
            builder: (context, state) {
          final insertBloc = context.read<InsertBloc>();

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.date,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              insertBloc.add(UpdateDate(picked));
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TagInput(
                  labelText: localization.insert_tagInputLabel,
                  tags: state.tagNames
                      .map((name) => TagChipData(
                          id: homeState.allTagsMap[name]?.id ?? -1,
                          name: name,
                          color: homeState.allTagsMap[name]?.color))
                      .toList(),
                  suggestions: homeState.allTagsMap.values
                      .map((tagView) => TagChipData(
                          id: tagView.id,
                          name: tagView.tagName,
                          color: tagView.color))
                      .toList(),
                  onAddTag: (name) =>
                      context.read<InsertBloc>().add(AddTag(name)),
                  onRemoveTag: (tag) =>
                      context.read<InsertBloc>().add(RemoveTag(tag.name)),
                  // The date tag is always there and cannot be removed
                  leading: Tag(
                    id: -1,
                    text: DateFormat.yMd(locale).format(state.date),
                    isDate: true,
                    onTap: pickDate,
                  ),
                ),
                const SizedBox(height: 20),
                Input(
                  labelText: localization.insert_descriptionLabel,
                  controller: _descriptionController,
                  maxLines: 4,
                  minLines: 3,
                  validator: (_) => null,
                  onChange: (text) =>
                      context.read<InsertBloc>().add(UpdateDescription(text)),
                ),
                const SizedBox(height: 20),
                state.status == InsertStatus.submitting
                    ? const Center(child: CircularProgressIndicator())
                    : Button(
                        text: localization.insert_submit,
                        onPressed: () =>
                            context.read<InsertBloc>().add(SubmitEvent()),
                      ),
              ],
            ),
          );
        });
      }),
    );
  }
}
