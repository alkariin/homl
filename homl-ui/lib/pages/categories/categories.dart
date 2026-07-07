import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/bubbles_background.dart';
import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';

/// Categories tab: the management list inline. Tapping a tag inserts it as a
/// search filter (the parent switches to the Search tab).
class CategoriesPage extends StatelessWidget {
  final void Function(TagView tag) onTagSelected;

  const CategoriesPage({required this.onTagSelected, super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeBloc = context.read<HomeBloc>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: localization.categories_newCategory,
        child: const Icon(Icons.add),
        onPressed: () => categoryDialog(
          context,
          title: localization.categories_newCategory,
          onSubmit: (name, color) => homeBloc.add(CreateCategory(name, color)),
        ),
      ),
      body: BubblesBackground(
        child: CategoryManagementBody(onTagSelected: onTagSelected),
      ),
    );
  }
}
