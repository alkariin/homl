import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/last_time.dart';
import 'package:homl/helpers/on_this_day.dart';
import 'package:homl/helpers/tag_groups.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/view/event_detail_sheet.dart';
import 'package:homl/pages/list/view/last_time_summary.dart';
import 'package:homl/pages/list/view/on_this_day_strip.dart';

class ListPage extends StatelessWidget {
  /// Reports the tag being typed to the app bar mark (see [AppBarMark]);
  /// null when the page is shown without one.
  final ValueNotifier<String?>? typedTag;

  const ListPage({this.typedTag, super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ListPage());
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    // The filtering is local (see ListCubit): network errors surface through
    // the HomeCubit listener, so this page has no error modal of its own.
    return BlocBuilder<HomeCubit, HomeState>(builder: (context, homeState) {
      // Tags of the Others category keep the default input styling while
      // suggested: only "real" categories tint the field and the logo.
      final otherCategoryIds = homeState.categories
          .where((category) => category.kind == CategoryKind.other)
          .map((category) => category.id)
          .toSet();

      final dateIds = dateCategoryIds(homeState.categories);

      // Printed next to each suggestion, translated like the Categories tab.
      final categoryLabels = {
        for (final category in homeState.categories)
          category.id: localizedCategoryName(category, localization),
      };

      return BlocBuilder<ListCubit, ListState>(builder: (context, listState) {
        // The same card in the grid and in the "On this day" strip.
        Widget cardFor(Event event) => EventCard(
              event: event,
              tagColorResolver: (tagName) =>
                  homeState.allTagsMap[tagName]?.color,
              // The tags map comes from the categories fetch: prefer it over
              // the category carried by the event payload, which a cached
              // event may have taken before a tag was moved.
              isDateTag: (tag) {
                final idCategory =
                    homeState.allTagsMap[tag.tag]?.idCategory ?? tag.idCategory;
                return idCategory != null && dateIds.contains(idCategory);
              },
              onTap: () => showEventDetailSheet(context, event: event),
            );

        // Both worked out at render time, like the period lengths: never
        // stored, so never a day behind. "On this day" over the whole list,
        // "Last time" over the results of a search.
        final today = DateTime.now();
        final memories = listState.filters.isEmpty
            ? eventsOnThisDay(homeState.events, today)
            : const <Memory>[];
        final lastTime = listState.filters.isEmpty
            ? null
            : lastTimeOf(listState.events, today);

        // The decorative background is shared by the tabs (parallax in the
        // home page).
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: TagInput(
              labelText: localization.list_filterLabel,
              showSearchIcon: true,
              tags: listState.filters
                  .map((name) => TagChipData(
                      id: homeState.allTagsMap[name]?.id ?? -1,
                      name: name,
                      displayName: localizedTagName(name, locale),
                      color: homeState.allTagsMap[name]?.color))
                  .toList(),
              suggestions: [
                ...homeState.allTagsMap.values.map((tagView) => TagChipData(
                    id: tagView.id,
                    name: tagView.tagName,
                    displayName: localizedTagName(tagView.tagName, locale),
                    color: tagView.color,
                    category: categoryLabels[tagView.idCategory],
                    highlightColor:
                        otherCategoryIds.contains(tagView.idCategory)
                            ? null
                            : tagView.color)),
                // A group adds each of its tags as a filter: the events
                // carrying them all.
                ...tagGroupSuggestions(homeState.categories),
              ],
              onAddTag: (name) => context.read<ListCubit>().addFilterTag(name),
              onRemoveTag: (tag) =>
                  context.read<ListCubit>().removeFilterTag(tag.name),
              // The button next to the field browses the categories; a
              // tap on a tag inserts it as a search filter.
              browseLabel: localization.categories_browseTags,
              onBrowse: () => showTagPickerSheet(
                context,
                onTagSelected: (tag) =>
                    context.read<ListCubit>().addFilterTag(tag.tagName),
              ),
              // The app bar mark follows the tag being typed, then the
              // filters already chosen.
              onSuggestionChanged: (name) => typedTag?.value = name,
            ),
          ),
          Expanded(
            child: listState.loading
                ? const Center(child: CircularProgressIndicator())
                // Pull down to fetch the events again (the list is local:
                // without this, only a restart or a write refreshed it).
                : RefreshIndicator(
                    onRefresh: () => context.read<HomeCubit>().refresh(),
                    child: listState.events.isEmpty
                        ? LayoutBuilder(
                            // Scrollable, so the pull works on an empty list too.
                            builder: (context, constraints) => ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                        height: constraints.maxHeight,
                                        child: Center(
                                            child: Text(
                                                localization.list_noEvents))),
                                  ],
                                ))
                        : CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (memories.isNotEmpty)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 22),
                                    child: Column(children: [
                                      OnThisDayStrip(
                                          memories: memories,
                                          cardBuilder: cardFor),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            20, 18, 20, 0),
                                        child: Divider(
                                            height: 1,
                                            color: palette.borderGrey
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ]),
                                  ),
                                ),
                              if (lastTime != null)
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 18, 20, 0),
                                  sliver: SliverToBoxAdapter(
                                    child: LastTimeSummary(
                                        lastTime: lastTime, today: today),
                                  ),
                                ),
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 22, 20, 25),
                                sliver: SliverGrid.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 250,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                    childAspectRatio: 155 / 160,
                                  ),
                                  itemCount: listState.events.length,
                                  itemBuilder: (context, index) =>
                                      cardFor(listState.events[index]),
                                ),
                              ),
                            ],
                          ),
                  ),
          ),
        ]);
      });
    });
  }
}
