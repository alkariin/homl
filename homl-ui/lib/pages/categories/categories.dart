import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/pages/categories/view/category_management.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

/// Categories tab: the management list inline. Tapping a tag opens its
/// actions menu (inserting a tag as a search filter happens through the "#"
/// logo of the Search tab instead).
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(localization.categories_newCategory),
        onPressed: () => categoryDialog(
          context,
          title: localization.categories_newCategory,
          onSubmit: (name, color) => homeCubit.createCategory(name, color),
        ),
      ),
      // The decorative background is shared by the tabs (parallax in the
      // home page), so the body is transparent.
      body: const CategoryManagementBody(),
    );
  }
}
