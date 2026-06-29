import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:homl/components/tag.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';
import 'package:homl/pages/list/bloc/list_bloc.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => ListPage());
  }

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 50,
        child:
            BlocBuilder<HomeBloc, HomeState>(builder: (homeContext, homeState) {
          return BlocBuilder<ListBloc, ListState>(
              builder: (listContext, listState) {
            String? findTagColor(String tagName) {
              return homeState.allTagsMap[tagName]?.color;
            }

            void onDeleteTag(int tagId) {
              listContext.read<ListBloc>().add(RemoveTagFromHeader(tagId));
            }

            return Row(
                children: listState.tags
                    .map((tag) => Tag(
                        id: tag.id,
                        text: tag.tag,
                        color: findTagColor(tag.tag),
                        onDeleteTag: onDeleteTag,
                        isDate: false))
                    .toList());
          });
        }),
      ),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[],
        ),
      ),
    ]);
  }
}
