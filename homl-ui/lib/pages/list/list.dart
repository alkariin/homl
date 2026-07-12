import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/bubbles_background.dart';
import 'package:homl/components/event_card.dart';
import 'package:homl/components/tag_input.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';
import 'package:homl/pages/list/bloc/list_cubit.dart';

class ListPage extends StatelessWidget {
  const ListPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const ListPage());
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    // The filtering is local (see ListCubit): network errors surface through
    // the HomeCubit listener, so this page has no error modal of its own.
    return BlocBuilder<HomeCubit, HomeState>(builder: (context, homeState) {
      return BlocBuilder<ListCubit, ListState>(builder: (context, listState) {
        return BubblesBackground(
          child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),
                child: TagInput(
                  labelText: localization.list_filterLabel,
                  showLogo: true,
                  tags: listState.filters
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
                      context.read<ListCubit>().addFilterTag(name),
                  onRemoveTag: (tag) =>
                      context.read<ListCubit>().removeFilterTag(tag.name),
                ),
              ),
              Expanded(
                child: listState.loading
                    ? const Center(child: CircularProgressIndicator())
                    : listState.events.isEmpty
                        ? Center(child: Text(localization.list_noEvents))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
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
                              );
                            },
                          ),
              ),
          ]),
        );
      });
    });
  }
}
