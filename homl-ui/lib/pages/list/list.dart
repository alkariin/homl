import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/data/models/category.dart';
import 'package:homl/helpers/categories.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';
import 'package:homl/pages/list/view/event_detail_sheet.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

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

      return BlocBuilder<ListCubit, ListState>(builder: (context, listState) {
        // The decorative background is shared by the tabs (parallax in the
        // home page).
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: TagInput(
              labelText: localization.list_filterLabel,
              showLogo: true,
              tags: listState.filters
                  .map((name) => TagChipData(
                      id: homeState.allTagsMap[name]?.id ?? -1,
                      name: name,
                      displayName: localizedTagName(name, locale),
                      color: homeState.allTagsMap[name]?.color))
                  .toList(),
              suggestions: homeState.allTagsMap.values
                  .map((tagView) => TagChipData(
                      id: tagView.id,
                      name: tagView.tagName,
                      displayName: localizedTagName(tagView.tagName, locale),
                      color: tagView.color,
                      highlightColor:
                          otherCategoryIds.contains(tagView.idCategory)
                              ? null
                              : tagView.color))
                  .toList(),
              onAddTag: (name) => context.read<ListCubit>().addFilterTag(name),
              onRemoveTag: (tag) =>
                  context.read<ListCubit>().removeFilterTag(tag.name),
              // The "#" logo browses the categories; a tap on a tag
              // inserts it as a search filter.
              onLogoTap: (_) => showTagPickerSheet(
                context,
                onTagSelected: (tag) =>
                    context.read<ListCubit>().addFilterTag(tag.tagName),
              ),
            ),
          ),
          Expanded(
            child: listState.loading
                ? const Center(child: CircularProgressIndicator())
                : listState.events.isEmpty
                    ? Center(child: Text(localization.list_noEvents))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 25),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 250,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 155 / 160,
                        ),
                        itemCount: listState.events.length,
                        itemBuilder: (context, index) {
                          final event = listState.events[index];
                          return EventCard(
                            event: event,
                            tagColorResolver: (tagName) =>
                                homeState.allTagsMap[tagName]?.color,
                            // The tags map comes from the categories fetch:
                            // prefer it over the category carried by the
                            // event payload, which a cached event may have
                            // taken before a tag was moved.
                            isDateTag: (tag) {
                              final idCategory =
                                  homeState.allTagsMap[tag.tag]?.idCategory ??
                                      tag.idCategory;
                              return idCategory != null &&
                                  dateIds.contains(idCategory);
                            },
                            onTap: () =>
                                showEventDetailSheet(context, event: event),
                          );
                        },
                      ),
          ),
        ]);
      });
    });
  }
}
