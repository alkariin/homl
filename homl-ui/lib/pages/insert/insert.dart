import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/app_bar_mark.dart';
import 'package:homl/components/bubbles_background.dart';
import 'package:homl/components/button.dart';
import 'package:homl/components/input.dart';
import 'package:homl/components/tag.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/app_message.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/toast.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/insert/bloc/insert_cubit.dart';

/// Edit form for an existing event, pushed from the event detail sheet. It
/// reuses [InsertView] with an [InsertCubit] seeded from the event, so the
/// tag resolution/creation logic stays in one place.
class EditEventPage extends StatefulWidget {
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

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  /// The tag being typed in the form. This route carries its own app bar,
  /// hence its own notifier: the home one is a screen away.
  final ValueNotifier<String?> _typedTag = ValueNotifier(null);

  @override
  void dispose() {
    _typedTag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.homeCubit),
        BlocProvider(
            create: (_) => InsertCubit(widget.homeCubit.eventsRepository,
                widget.homeCubit.tagsRepository,
                editing: widget.event,
                dateCategoryIds:
                    dateCategoryIds(widget.homeCubit.state.categories))),
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
          actions: [
            BlocBuilder<HomeCubit, HomeState>(
              builder: (context, home) => BlocBuilder<InsertCubit, InsertState>(
                builder: (context, state) => AppBarMark(
                    tagNames: state.tagNames,
                    typedTag: _typedTag,
                    accentColorOf: home.markAccentFor),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        // This route lives outside the home PageView: it carries its own
        // copy of the shared decorative background.
        body: BubblesBackground(child: InsertView(typedTag: _typedTag)),
      ),
    );
  }
}

class InsertView extends StatefulWidget {
  /// Called after a successful creation (not edits): the home page uses it
  /// to bring the user back to the Search tab. Null in edit mode (the edit
  /// route pops instead).
  final VoidCallback? onCreated;

  /// Reports the tag being typed to the app bar mark of the page holding the
  /// form (see [AppBarMark]).
  final ValueNotifier<String?>? typedTag;

  const InsertView({this.onCreated, this.typedTag, super.key});

  @override
  State<InsertView> createState() => _InsertViewState();
}

class _InsertViewState extends State<InsertView> {
  final TextEditingController _descriptionController = TextEditingController();

  /// Owned here (handed to [TagInput]) so the new-tag panel below can read
  /// and clear the pending tag text.
  final TextEditingController _tagController = TextEditingController();

  /// Name typed in the tag field while no known tag matches it: the panel
  /// under the field offers to create it in a category. Null hides it.
  final ValueNotifier<String?> _newTagName = ValueNotifier(null);

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
    _newTagName.dispose();
    super.dispose();
  }

  /// Fed by the tag input on every change of the field: the top suggestion
  /// goes to the app bar mark, and "no suggestion at all" is what opens the
  /// new-tag panel — so it never fights the autocomplete dropdown for the
  /// room under the field. A name that is already a tag (its suggestion is
  /// hidden once it is chipped on the event) opens nothing, and neither does
  /// a name reserved for the date tags — the backend would refuse to create
  /// it, so it must not be offered.
  void _onSuggestion(String? tagName) {
    widget.typedTag?.value = tagName;

    final pending = _tagController.text.trim();
    final known = context
        .read<HomeCubit>()
        .state
        .allTagsMap
        .keys
        .any((name) => name.toLowerCase() == pending.toLowerCase());

    _newTagName.value = pending.isEmpty ||
            tagName != null ||
            known ||
            E2ee().isBlacklistedTag(pending)
        ? null
        : pending;
  }

  /// Creates the typed tag in the picked category and chips it on the event,
  /// instead of letting it fall into Others on submit.
  Future<void> _createTagIn(
      BuildContext context, String name, Category category) async {
    final insertCubit = context.read<InsertCubit>();
    final homeCubit = context.read<HomeCubit>();

    final created = await homeCubit.createTag(name, category.id);
    if (created) {
      insertCubit.addTag(name);
      _tagController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return BlocListener<InsertCubit, InsertState>(
      // The navigation and the toasts react to the *transition* into a status
      // or a message, never to any state that happens to carry one: the form
      // keeps emitting while the success is on screen (the description field
      // notifies its text when it loses focus on the way out), and a second
      // run of the edit branch would pop the list route too.
      listenWhen: (previous, current) =>
          previous.status != current.status || previous.modal != current.modal,
      listener: (context, state) {
        final insertCubit = context.read<InsertCubit>();
        if (state.status == InsertStatus.success) {
          if (state.editingEventId != null) {
            // Edit mode: pop back to the list. The messenger is resolved
            // before the pop (the context is gone after it) and the toast
            // shown after it, since the route observer clears the toasts on
            // the way out.
            final messenger = ScaffoldMessenger.of(context);
            Navigator.of(context).pop();
            showToastWith(messenger, localization.list_eventUpdated);
            return;
          }
          _descriptionController.clear();
          showToast(context, localization.insert_eventCreated);
          // The search tab follows the shared events through the repository
          // changes stream, so no explicit refresh is needed here.
          insertCubit.endModal();
          // Back to the list: the created event is the natural next focus.
          widget.onCreated?.call();
        } else if (state.modal != null) {
          showToast(context, state.modal!.localize(localization),
                  duration: const Duration(seconds: 5))
              .closed
              .then((_) {
            insertCubit.endModal();
          });
        }
      },
      child: BlocBuilder<HomeCubit, HomeState>(builder: (context, homeState) {
        // Printed next to each suggestion, translated like the Categories tab.
        final categoryLabels = {
          for (final category in homeState.categories)
            category.id: localizedCategoryName(category, localization),
        };

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

          // The end picker starts from the end already picked or, on a first
          // pick, from the start day; earlier days are simply not offered.
          // initialDate has to sit inside [firstDate, lastDate] or the dialog
          // asserts — hence the fallback on the start, never "today".
          Future<void> pickEndDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.endDate ?? state.date,
              firstDate: state.date,
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              insertCubit.updateEndDate(picked);
            }
          }

          // The decorative background is shared by the tabs (parallax in
          // the home page); the edit route wraps this view with its own.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
                    controller: _tagController,
                    // Browsing the categories adds an existing tag to the
                    // event; a name none of them holds opens the panel below.
                    // The Dates category stays out of the sheet: the backend
                    // files the event under its own date tags, derived from
                    // the period picked below, so picking one here would
                    // either be a no-op or fight that derivation.
                    browseLabel: localization.categories_browseTags,
                    onBrowse: () => showTagPickerSheet(
                      context,
                      showDates: false,
                      onTagSelected: (tag) =>
                          context.read<InsertCubit>().addTag(tag.tagName),
                    ),
                    onSuggestionChanged: _onSuggestion,
                    tags: state.tagNames
                        .map((name) => TagChipData(
                            id: homeState.allTagsMap[name]?.id ?? -1,
                            name: name,
                            displayName: localizedTagName(name, locale),
                            color: homeState.allTagsMap[name]?.color ??
                                otherCategoryColor))
                        .toList(),
                    suggestions: homeState.allTagsMap.values
                        .map((tagView) => TagChipData(
                            id: tagView.id,
                            name: tagView.tagName,
                            displayName:
                                localizedTagName(tagView.tagName, locale),
                            color: tagView.color,
                            category: categoryLabels[tagView.idCategory],
                            highlightColor:
                                homeState.markAccentFor(tagView.tagName)))
                        .toList(),
                    onAddTag: (name) =>
                        context.read<InsertCubit>().addTag(name),
                    onRemoveTag: (tag) =>
                        context.read<InsertCubit>().removeTag(tag.name),
                    // The date chips are always there and cannot be removed.
                    // They mirror the date tags the event is filed under
                    // (translated for display, stored in English): the start
                    // month and year, both opening the date picker, then the
                    // end of a closed period (tap to change it) or the
                    // Ongoing tag of an open one. A closed period is filed
                    // under every month it covers, but only its start is
                    // chipped — a long one would flood the field.
                    leading: [
                      Tag(
                        id: -1,
                        text: monthLabel(state.date.month, locale),
                        isDate: true,
                        large: true,
                        onTap: pickDate,
                      ),
                      Tag(
                        id: -1,
                        text: state.date.year.toString(),
                        isDate: true,
                        large: true,
                        onTap: pickDate,
                      ),
                      if (state.endDate != null)
                        Tag(
                          id: -1,
                          text:
                              '→ ${DateFormat.yMMMd(locale).format(state.endDate!)}',
                          isDate: true,
                          large: true,
                          onTap: pickEndDate,
                        ),
                      if (state.isOngoing)
                        Tag(
                          id: -1,
                          text: localizedTagName(dateTagOngoing, locale),
                          isDate: true,
                          large: true,
                        ),
                    ],
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: _newTagName,
                    builder: (context, name, _) {
                      if (name == null) return const SizedBox.shrink();
                      return _NewTagCategories(
                        name: name,
                        // The Dates tags are the backend's: it derives them
                        // from the event period, nobody types them.
                        categories: homeState.categories
                            .where((category) => !isDateCategory(category))
                            .toList(),
                        onPicked: (category) =>
                            _createTagIn(context, name, category),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  // One day, a closed period or an open one. "Period" opens
                  // the end picker straight away and only becomes the selected
                  // shape once a day is picked — the selection is derived from
                  // the state — so cancelling leaves the previous shape in
                  // place and the form never rests on "a period without an
                  // end".
                  SegmentedButton<PeriodShape>(
                    showSelectedIcon: false,
                    style:
                        const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(
                          value: PeriodShape.singleDay,
                          label: Text(localization.insert_periodSingleDay)),
                      ButtonSegment(
                          value: PeriodShape.closed,
                          label: Text(localization.insert_periodClosed)),
                      ButtonSegment(
                          value: PeriodShape.ongoing,
                          label: Text(localization.insert_periodOngoing)),
                    ],
                    selected: {state.shape},
                    onSelectionChanged: (selection) {
                      switch (selection.single) {
                        case PeriodShape.singleDay:
                          insertCubit.setSingleDay();
                        case PeriodShape.closed:
                          pickEndDate();
                        case PeriodShape.ongoing:
                          insertCubit.setOngoing();
                      }
                    },
                  ),
                  const SizedBox(height: 22),
                  Input(
                    labelText: localization.insert_descriptionLabel,
                    controller: _descriptionController,
                    maxLines: 4,
                    minLines: 3,
                    validator: (_) => null,
                    onChange: (text) =>
                        context.read<InsertCubit>().updateDescription(text),
                  ),
                  const SizedBox(height: 20),
                  state.status == InsertStatus.submitting
                      ? const Center(child: CircularProgressIndicator())
                      : Button(
                          text: state.editingEventId != null
                              ? localization.global_save
                              : localization.insert_submit,
                          onPressed: () => context
                              .read<InsertCubit>()
                              .submitEvent(
                                  homeState.categories, homeState.allTagsMap),
                        ),
                ],
              ),
            ),
          );
        });
      }),
    );
  }
}

/// Panel under the tag input: the categories the typed name can be created
/// in, one tap each. It replaces the dialog the old "#" logo button opened —
/// the choice is offered where the name was typed, and only when no known tag
/// matches it. Ignoring it still works: submitting files the tag under
/// Others, as it always did.
class _NewTagCategories extends StatelessWidget {
  final String name;
  final List<Category> categories;
  final void Function(Category category) onPicked;

  const _NewTagCategories(
      {required this.name, required this.categories, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.03),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localization.insert_newTagCategoryTitle(name),
            style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map((category) => _CategoryPill(
                    category: category, onTap: () => onPicked(category)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// One category of the panel: its color as a dot, its name, and the whole
/// pill as the target.
class _CategoryPill extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryPill({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final base = colorFromHex(category.color);

    return Material(
      color: Colors.white,
      shape: StadiumBorder(
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: base,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: darken(base, .3).withValues(alpha: 0.5), width: 1),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                localizedCategoryName(category, localization),
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: ink.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
