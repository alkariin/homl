import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/pages/home/bloc/home_bloc.dart';

/// Categories list shown in the Categories tab: every category with its tags
/// and synonyms, with full CRUD management. [onTagSelected] receives the
/// tapped tag so the caller can insert it as a search filter.
class CategoryManagementBody extends StatelessWidget {
  final void Function(TagView tag) onTagSelected;

  const CategoryManagementBody({required this.onTagSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      return ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        children: state.categories
            .map((category) =>
                _CategoryTile(category: category, onTagSelected: onTagSelected))
            .toList(),
      );
    });
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final void Function(TagView tag) onTagSelected;

  const _CategoryTile({required this.category, required this.onTagSelected});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeBloc = context.read<HomeBloc>();
    final mainTags =
        category.tags.where((tag) => tag.idParentTag == null).toList();

    // Backend convention: the first category is Dates and the next one is
    // Persons; their tags are managed by the backend. Others (Dates + 2) is
    // locked as a category but its tags are editable.
    final idDates = homeBloc.state.categories.isEmpty
        ? -1
        : homeBloc.state.categories.first.id;
    final canManageTags = category.id != idDates && category.id != idDates + 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ExpansionTile(
        shape: const Border(),
        leading: CircleAvatar(
          radius: 12,
          backgroundColor:
              Color(int.parse(category.color.replaceAll("#", "0xff"))),
        ),
        title: Text(category.category),
        trailing: category.isLocked
            ? const SizedBox.shrink()
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.pen, size: 16),
                    tooltip: localization.categories_editCategory,
                    onPressed: () => categoryDialog(
                      context,
                      title: localization.categories_editCategory,
                      initialName: category.category,
                      initialColor: category.color,
                      onSubmit: (name, color) => homeBloc
                          .add(UpdateCategory(category.id, name, color)),
                    ),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
                    tooltip: localization.global_delete,
                    onPressed: () => _deleteCategoryDialog(context, category),
                  ),
                ],
              ),
        children: [
          ...mainTags.map((mainTag) => _TagRow(
              category: category,
              mainTag: mainTag,
              canManage: canManageTags,
              onTagSelected: onTagSelected,
              synonyms: category.tags
                  .where((tag) => tag.idParentTag == mainTag.id)
                  .toList())),
          if (canManageTags)
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 18),
              title: Text(localization.categories_newTag),
              onTap: () => _textDialog(
                context,
                title: localization.categories_newTag,
                label: localization.categories_categoryName,
                onSubmit: (name) => homeBloc.add(CreateTag(name, category.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final Category category;
  final Tag mainTag;
  final List<Tag> synonyms;
  final bool canManage;
  final void Function(TagView tag) onTagSelected;

  const _TagRow(
      {required this.category,
      required this.mainTag,
      required this.synonyms,
      required this.canManage,
      required this.onTagSelected});

  /// Hands the tapped tag to the page callback (search filter insertion).
  void _selectTag(BuildContext context, Tag tag) {
    final tagView = context.read<HomeBloc>().state.allTagsMap[tag.tag];
    if (tagView != null) {
      onTagSelected(tagView);
    }
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeBloc = context.read<HomeBloc>();

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 25, right: 10),
      title: Wrap(
        spacing: 5,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          components.Tag(
            id: mainTag.id,
            text: mainTag.tag,
            color: category.color,
            onTap: () => _selectTag(context, mainTag),
          ),
          ...synonyms.map((synonym) => components.Tag(
                id: synonym.id,
                text: synonym.tag,
                onTap: () => _selectTag(context, synonym),
                onDeleteTag: !canManage
                    ? null
                    : (_) => _synonymDialog(context, category, synonym),
              )),
        ],
      ),
      trailing: !canManage
          ? null
          : PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    _textDialog(
                      context,
                      title: localization.categories_renameTag,
                      label: localization.categories_categoryName,
                      initialValue: mainTag.tag,
                      onSubmit: (name) => homeBloc
                          .add(UpdateTag(mainTag.id, name, category.id)),
                    );
                    break;
                  case 'delete':
                    homeBloc.add(DeleteTag(mainTag.id));
                    break;
                  case 'synonym':
                    _textDialog(
                      context,
                      title: localization.categories_addSynonym,
                      label: localization.categories_synonymName,
                      onSubmit: (name) => homeBloc.add(CreateTag(
                          name, category.id,
                          idParentTag: mainTag.id)),
                    );
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'rename',
                    child: Text(localization.categories_renameTag)),
                PopupMenuItem(
                    value: 'synonym',
                    child: Text(localization.categories_addSynonym)),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(localization.categories_deleteTag)),
              ],
            ),
    );
  }
}

/// Long press on a synonym chip: detach it from its main tag or delete it.
void _synonymDialog(BuildContext context, Category category, Tag synonym) {
  var localization = AppLocalizations.of(context)!;
  final homeBloc = context.read<HomeBloc>();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(synonym.tag),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        TextButton(
          child: Text(localization.categories_detachSynonym),
          onPressed: () {
            homeBloc.add(UpdateTag(synonym.id, synonym.tag, category.id));
            Navigator.pop(dialogContext);
          },
        ),
        TextButton(
          child: Text(localization.global_delete),
          onPressed: () {
            homeBloc.add(DeleteTag(synonym.id));
            Navigator.pop(dialogContext);
          },
        ),
      ],
    ),
  );
}

void _deleteCategoryDialog(BuildContext context, Category category) {
  var localization = AppLocalizations.of(context)!;
  final homeBloc = context.read<HomeBloc>();
  bool moveTags = false;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(localization.categories_deleteCategory),
        content: CheckboxListTile(
          title: Text(localization.categories_deleteMoveTags),
          value: moveTags,
          onChanged: (value) => setState(() => moveTags = value ?? false),
        ),
        actions: [
          TextButton(
            child: Text(localization.global_cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(localization.global_delete),
            onPressed: () {
              homeBloc.add(DeleteCategory(category.id, moveTags: moveTags));
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    ),
  );
}

/// Simple one-field dialog (new tag, rename tag, add synonym).
void _textDialog(BuildContext context,
    {required String title,
    required String label,
    String? initialValue,
    required void Function(String value) onSubmit}) {
  var localization = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialValue);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        TextButton(
          child: Text(localization.global_save),
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) {
              onSubmit(value);
            }
            Navigator.pop(dialogContext);
          },
        ),
      ],
    ),
  );
}

/// Category create/edit dialog: name + preset color picker.
void categoryDialog(BuildContext context,
    {required String title,
    String? initialName,
    String? initialColor,
    required void Function(String name, String color) onSubmit}) {
  var localization = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialName);
  String selectedColor = initialColor ?? categoryColors.first;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: localization.categories_categoryName),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categoryColors
                  .map((color) => GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              Color(int.parse(color.replaceAll("#", "0xff"))),
                          child: selectedColor == color
                              ? const Icon(Icons.check, size: 16)
                              : null,
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(localization.global_cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(localization.global_save),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                onSubmit(name, selectedColor);
              }
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    ),
  );
}
