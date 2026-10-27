import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag.dart' as components;
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/event_feed.dart';
import 'package:homl/helpers/event_search.dart';
import 'package:homl/helpers/last_time.dart';
import 'package:homl/helpers/on_this_day.dart';
import 'package:homl/helpers/tag_groups.dart';
import 'package:homl/helpers/timeline.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/view/activity_calendar.dart';
import 'package:homl/pages/list/view/event_detail_sheet.dart';
import 'package:homl/pages/list/view/event_feed.dart';
import 'package:homl/pages/list/view/last_time_summary.dart';
import 'package:homl/pages/list/view/on_this_day_strip.dart';
import 'package:homl/pages/list/view/period_timeline.dart';

class ListPage extends StatelessWidget {
  /// Chip of a term looked up in the descriptions: a neutral grey, so it
  /// never reads as a category.
  static const String _textChipColor = '#e8eaed';

  /// Reports the tag being typed to the app bar mark (see [AppBarMark]);
  /// null when the page is shown without one.
  final ValueNotifier<String?>? typedTag;

  const ListPage({this.typedTag, super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ListPage());
  }

  /// The chip of a search term. Named after the term as typed ("-Bob"), so
  /// the field knows it is chipped and a tap hands it back for removal. A
  /// term naming a tag wears that tag; any other one is printed in quotes.
  static TagChipData _chipOf(SearchTerm term, HomeState home, String locale) {
    final tag = home.allTagsMap[term.tagName];
    if (tag != null) {
      return TagChipData(
          id: tag.id,
          name: term.typed,
          displayName: localizedTagName(tag.tagName, locale),
          color: tag.color,
          excluded: term.exclude);
    }
    return TagChipData(
        id: -1,
        name: term.typed,
        displayName: '\u201c${term.text}\u201d',
        color: _textChipColor,
        excluded: term.exclude);
  }

  /// "Mar 3, 2019 – Aug 12, 2021", or the one day.
  static String _rangeLabel(DayRange range, String locale) {
    final format = DateFormat.yMMMd(locale);
    final first = format.format(range.first);
    return range.first == range.last
        ? first
        : '$first \u2013 ${format.format(range.last)}';
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
        // The tags map comes from the categories fetch: prefer it over the
        // category carried by the event payload, which a cached event may
        // have taken before a tag was moved.
        bool isDateTag(Tag tag) {
          final idCategory =
              homeState.allTagsMap[tag.tag]?.idCategory ?? tag.idCategory;
          return idCategory != null && dateIds.contains(idCategory);
        }

        // The card of the "On this day" strip.
        Widget cardFor(Event event) => EventCard(
              event: event,
              tagColorResolver: (tagName) =>
                  homeState.allTagsMap[tagName]?.color,
              isDateTag: isDateTag,
              onTap: () => showEventDetailSheet(context, event: event),
            );

        // A timeline row is called by its tags, like a card without the
        // room for chips; the first line of the description otherwise.
        String timelineLabel(Event event) {
          final names = [
            for (final tag in event.tags)
              if (!isDateTag(tag)) localizedTagName(tag.tag, locale),
          ];
          if (names.isNotEmpty) return names.join(' \u00b7 ');
          return event.description.trim().split('\n').first.trim();
        }

        // Its bar wears the color of its first tag in a real category. The
        // pale Others grey would vanish on the light background: such a
        // bar, like an untagged one, is drawn in the darker neutral grey.
        String? timelineColor(Event event) {
          for (final tag in event.tags) {
            if (isDateTag(tag)) continue;
            final view = homeState.allTagsMap[tag.tag];
            if (view != null && !otherCategoryIds.contains(view.idCategory)) {
              return view.color;
            }
          }
          return null;
        }

        // Both worked out at render time, like the period lengths: never
        // stored, so never a day behind. "On this day" over the whole list,
        // "Last time" over the results of a search.
        final today = DateTime.now();
        // The strip opens the list only: the timeline is a view of its own.
        final memories = listState.isSearching || listState.timeline
            ? const <Memory>[]
            : eventsOnThisDay(homeState.events, today);
        final lastTime =
            listState.isSearching ? lastTimeOf(listState.events, today) : null;
        final feed = eventFeed(listState.events);

        // The activity calendar shows what the terms find, whatever day
        // range narrows the results: picking a day must not empty it.
        final activity = listState.terms.isEmpty
            ? null
            : searchEvents(homeState.events, homeState.categories,
                terms: listState.terms, today: today);
        // In the color of the first tag asked for in a real category.
        String? activityColor;
        for (final term in listState.terms) {
          final view = term.exclude ? null : homeState.allTagsMap[term.tagName];
          if (view != null && !otherCategoryIds.contains(view.idCategory)) {
            activityColor = view.color;
            break;
          }
        }
        final range = listState.range;

        // The decorative background is shared by the tabs (parallax in the
        // home page).
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: TagInput(
              labelText: localization.list_filterLabel,
              hintText: localization.list_filterHint,
              showSearchIcon: true,
              // "-Bob" leaves Bob's events out (see SearchTerm.parse).
              allowExclusion: true,
              // The range comes first, a tap lifts it like any chip.
              leading: [
                if (range != null)
                  components.Tag(
                    id: -1,
                    text: _rangeLabel(range, locale),
                    color: palette.yellowHex,
                    isDate: true,
                    large: true,
                    onTap: () => context.read<ListCubit>().setRange(null),
                    onDeleteTag: (_) =>
                        context.read<ListCubit>().setRange(null),
                  ),
              ],
              tags: listState.terms
                  .map((term) => _chipOf(term, homeState, locale))
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
              onAddTag: (typed) =>
                  context.read<ListCubit>().addTypedTerm(typed),
              onRemoveTag: (chip) {
                final cubit = context.read<ListCubit>();
                final term = cubit.state.terms
                    .where((term) => term.typed == chip.name)
                    .firstOrNull;
                if (term != null) cubit.removeTerm(term);
              },
              // The button next to the field browses the categories; a
              // tap on a tag inserts it as a search filter.
              browseLabel: localization.categories_browseTags,
              onBrowse: () => showTagPickerSheet(
                context,
                onTagSelected: (tag) =>
                    context.read<ListCubit>().addTag(tag.tagName),
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
                                            color: context.homl.rule
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
                              if (activity != null)
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                  sliver: SliverToBoxAdapter(
                                    child: ActivityCalendar(
                                      events: activity,
                                      today: today,
                                      color: activityColor,
                                      selected: range,
                                      // A tap narrows to that day; on the
                                      // day already picked, lifts it.
                                      onDayTap: (day) {
                                        final picked = DayRange(day, day);
                                        context.read<ListCubit>().setRange(
                                            picked == range ? null : picked);
                                      },
                                    ),
                                  ),
                                ),
                              if (listState.timeline)
                                PeriodTimeline(
                                  timeline: timelineOf(listState.events, today),
                                  today: today,
                                  labelOf: timelineLabel,
                                  colorOf: timelineColor,
                                  onTap: (event) => showEventDetailSheet(
                                      context,
                                      event: event),
                                )
                              else
                                // One column, newest first, under a
                                // heading per month (see EventRow).
                                SliverPadding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 4, 20, 25),
                                  sliver: SliverList.builder(
                                    itemCount: feed.length,
                                    itemBuilder: (context, index) =>
                                        switch (feed[index]) {
                                      FeedMonth(:final month, :final count) =>
                                        MonthHeader(month: month, count: count),
                                      FeedEvent(
                                        :final event,
                                        :final first,
                                        :final last
                                      ) =>
                                        EventRow(
                                          event: event,
                                          first: first,
                                          last: last,
                                          tagColorResolver: (tagName) =>
                                              homeState
                                                  .allTagsMap[tagName]?.color,
                                          isDateTag: isDateTag,
                                          dotColor: timelineColor(event),
                                          onTap: () => showEventDetailSheet(
                                              context,
                                              event: event),
                                        ),
                                    },
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
