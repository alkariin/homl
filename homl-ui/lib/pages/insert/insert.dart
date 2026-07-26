import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/bubbles_background.dart';
import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/components/tag.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/repositories/events.repository.dart';
import 'package:homl/data/repositories/tags.repository.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/bloc/insert_cubit.dart';

class InsertPage extends StatelessWidget {
  const InsertPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const InsertPage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InsertCubit(
          context.read<EventsRepository>(), context.read<TagsRepository>()),
      child: const InsertView(),
    );
  }
}

/// Edit form for an existing event, pushed from the event detail sheet. It
/// reuses [InsertView] with an [InsertCubit] seeded from the event, so the
/// tag resolution/creation logic stays in one place.
class EditEventPage extends StatelessWidget {
  /// The HomeCubit is passed through the route on purpose: this page lives in
  /// its own navigator route, outside the provider scope of the home page
  /// (see AccountPage for the same convention).
  final HomeCubit homeCubit;
  final Event event;

  const EditEventPage(
      {required this.homeCubit, required this.event, super.key});

  static Route<void> route(HomeCubit homeCubit, Event event) {
    return MaterialPageRoute<void>(
        builder: (_) => EditEventPage(homeCubit: homeCubit, event: event));
  }

  /// Categories whose tags are backend-managed date tags (month/year).
  /// Legacy backends do not send the kind: fall back to the convention that
  /// the first category is Dates (same rule as the categories page).
  Set<int> _dateCategoryIds(List<Category> categories) {
    final ids = categories
        .where((category) => category.kind == CategoryKind.date)
        .map((category) => category.id)
        .toSet();
    if (ids.isNotEmpty || categories.isEmpty) return ids;
    return {categories.first.id};
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: homeCubit),
        BlocProvider(
            create: (_) => InsertCubit(
                homeCubit.eventsRepository, homeCubit.tagsRepository,
                editing: event,
                dateCategoryIds:
                    _dateCategoryIds(homeCubit.state.categories))),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.list_editEvent),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: const InsertView(),
      ),
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

  /// Owned here (handed to [TagInput]) so the logo flow below can read and
  /// clear the pending tag text.
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prefilled in edit mode, empty on the insert tab.
    _descriptionController.text = context.read<InsertCubit>().state.description;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  /// "#" logo of the tag input:
  /// - empty field: browse the categories and tap a tag to add it;
  /// - a new tag typed: pick the category it belongs to, create it there and
  ///   add it to the event;
  /// - an existing tag typed: nothing to do, it already has a category (the
  ///   autocomplete adds it to the event).
  void _onLogoTap(BuildContext context, String pending, HomeState homeState) {
    var localization = AppLocalizations.of(context)!;
    final insertCubit = context.read<InsertCubit>();
    final homeCubit = context.read<HomeCubit>();

    if (pending.isEmpty) {
      showTagPickerSheet(
        context,
        onTagSelected: (tag) => insertCubit.addTag(tag.tagName),
      );
      return;
    }

    final exists = homeState.allTagsMap.keys
        .any((name) => name.toLowerCase() == pending.toLowerCase());
    if (exists) {
      return;
    }

    pickCategoryDialog(
      context,
      title: localization.insert_newTagCategoryTitle(pending),
      onPicked: (category) async {
        final created = await homeCubit.createTag(pending, category.id);
        if (created) {
          insertCubit.addTag(pending);
          _tagController.clear();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return BlocListener<InsertCubit, InsertState>(
      listener: (context, state) {
        final insertCubit = context.read<InsertCubit>();
        if (state.status == InsertStatus.success) {
          if (state.editingEventId != null) {
            // Edit mode: pop back to the list. The messenger is app-level,
            // so the confirmation snackbar survives the pop.
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                  SnackBar(content: Text(localization.list_eventUpdated)));
            return;
          }
          _descriptionController.clear();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text(localization.insert_eventCreated)));
          // The search tab follows the shared events through the repository
          // changes stream, so no explicit refresh is needed here.
          insertCubit.endModal();
        } else if (state.modal != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(state.modal!.localize(localization)),
              action: SnackBarAction(
                  label: localization.global_close, onPressed: () {}),
              duration: const Duration(seconds: 5),
            )).closed.then((_) {
              insertCubit.endModal();
            });
        }
      },
      child: BlocBuilder<HomeCubit, HomeState>(builder: (context, homeState) {
        // A free tag not created yet lands in the Others category on submit:
        // its chip already wears that category's grey.
        String? otherCategoryColor;
        for (final category in homeState.categories) {
          if (category.kind == CategoryKind.other) {
            otherCategoryColor = category.color;
            break;
          }
        }

        return BlocBuilder<InsertCubit, InsertState>(builder: (context, state) {
          final insertCubit = context.read<InsertCubit>();

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.date,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              insertCubit.updateDate(picked);
            }
          }

          return BubblesBackground(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TagInput(
                      labelText: localization.insert_tagInputLabel,
                      showLogo: true,
                      controller: _tagController,
                      onLogoTap: (pending) =>
                          _onLogoTap(context, pending, homeState),
                      tags: state.tagNames
                          .map((name) => TagChipData(
                              id: homeState.allTagsMap[name]?.id ?? -1,
                              name: name,
                              color: homeState.allTagsMap[name]?.color ??
                                  otherCategoryColor))
                          .toList(),
                      suggestions: homeState.allTagsMap.values
                          .map((tagView) => TagChipData(
                              id: tagView.id,
                              name: tagView.tagName,
                              color: tagView.color))
                          .toList(),
                      onAddTag: (name) =>
                          context.read<InsertCubit>().addTag(name),
                      onRemoveTag: (tag) =>
                          context.read<InsertCubit>().removeTag(tag.name),
                      // The date tag is always there and cannot be removed
                      leading: Tag(
                        id: -1,
                        text: DateFormat.yMd(locale).format(state.date),
                        isDate: true,
                        large: true,
                        onTap: pickDate,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Input(
                      labelText: localization.insert_descriptionLabel,
                      controller: _descriptionController,
                      maxLines: 4,
                      minLines: 3,
                      validator: (_) => null,
                      onChange: (text) => context
                          .read<InsertCubit>()
                          .updateDescription(text),
                    ),
                    const SizedBox(height: 20),
                    state.status == InsertStatus.submitting
                        ? const Center(child: CircularProgressIndicator())
                        : Button(
                            text: state.editingEventId != null
                                ? localization.global_save
                                : localization.insert_submit,
                            onPressed: () => context.read<InsertCubit>().submitEvent(homeState.categories,
                                    homeState.allTagsMap),
                          ),
                  ],
                ),
              ),
            ),
          );
        });
      }),
    );
  }
}
