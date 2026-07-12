import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

/// Categories list shown in the Categories tab: every category with its tags
/// and synonyms, with full CRUD management. [onTagSelected] receives the
/// tapped tag so the caller can insert it as a search filter.
class CategoryManagementBody extends StatelessWidget {
  final void Function(TagView tag) onTagSelected;

  const CategoryManagementBody({required this.onTagSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
      return ListView(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        children: state.categories
            // The Others category is a grey bucket the backend guarantees:
            // only show it once tags have landed in it (free tags from the
            // insert page, or tags moved on a category deletion).
            .where((category) =>
                category.kind != CategoryKind.other || category.tags.isNotEmpty)
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
    final homeCubit = context.read<HomeCubit>();
    final mainTags =
        category.tags.where((tag) => tag.idParentTag == null).toList();

    // When the backend exposes the category kind, the Dates tags are managed
    // by the backend and the Others tags are read-only here (they land in the
    // grey bucket through the insert page or a category deletion); Persons is
    // an ordinary suggestion category, fully editable. Older backends do not
    // send the kind: fall back to the legacy convention (first category is
    // Dates, the next one is Persons) and its legacy rules.
    final bool canManageTags;
    if (category.kind != null) {
      canManageTags = category.kind != CategoryKind.date &&
          category.kind != CategoryKind.other;
    } else {
      final idDates = homeCubit.state.categories.isEmpty
          ? -1
          : homeCubit.state.categories.first.id;
      canManageTags = category.id != idDates && category.id != idDates + 1;
    }

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
          backgroundColor: colorFromHex(category.color),
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
                      onSubmit: (name, color) => homeCubit
                          .updateCategory(category.id, name, color),
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
                onSubmit: (name) => homeCubit.createTag(name, category.id),
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
    final tagView = context.read<HomeCubit>().state.allTagsMap[tag.tag];
    if (tagView != null) {
      onTagSelected(tagView);
    }
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();

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
                      onSubmit: (name) => homeCubit
                          .updateTag(mainTag.id, name, category.id),
                    );
                    break;
                  case 'synonym':
                    _textDialog(
                      context,
                      title: localization.categories_addSynonym,
                      label: localization.categories_synonymName,
                      onSubmit: (name) => homeCubit.createTag(
                          name, category.id,
                          idParentTag: mainTag.id),
                    );
                    break;
                  case 'move':
                    _moveTagDialog(context, category, mainTag);
                    break;
                  case 'delete':
                    _deleteTagDialog(context, mainTag, synonyms);
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
                    value: 'move',
                    child: Text(localization.categories_moveTag)),
                PopupMenuItem(
                    value: 'delete',
                    child: Text(localization.categories_deleteTag)),
              ],
            ),
    );
  }
}

/// Long press on a synonym chip: rename it, detach it from its main tag, or
/// delete it (after a confirmation: its events migrate to the main tag).
void _synonymDialog(BuildContext context, Category category, Tag synonym) {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();
  final mainTags =
      category.tags.where((tag) => tag.id == synonym.idParentTag).toList();
  final mainTagName = mainTags.isEmpty ? '' : mainTags.first.tag;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(synonym.tag),
      children: [
        SimpleDialogOption(
          child: Text(localization.categories_renameSynonym),
          onPressed: () {
            Navigator.pop(dialogContext);
            _textDialog(
              context,
              title: localization.categories_renameSynonym,
              label: localization.categories_synonymName,
              initialValue: synonym.tag,
              onSubmit: (name) => homeCubit.updateTag(
                  synonym.id, name, category.id,
                  idParentTag: synonym.idParentTag),
            );
          },
        ),
        SimpleDialogOption(
          child: Text(localization.categories_detachSynonym),
          onPressed: () {
            homeCubit.updateTag(synonym.id, synonym.tag, category.id);
            Navigator.pop(dialogContext);
          },
        ),
        SimpleDialogOption(
          child: Text(localization.global_delete),
          onPressed: () {
            Navigator.pop(dialogContext);
            _deleteSynonymDialog(context, synonym, mainTagName);
          },
        ),
      ],
    ),
  );
}

/// Confirms a synonym deletion: its events are repointed to the main tag.
void _deleteSynonymDialog(
    BuildContext context, Tag synonym, String mainTagName) {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(localization.categories_deleteSynonymTitle),
      content: Text(
          localization.categories_deleteSynonymInfo(synonym.tag, mainTagName)),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        TextButton(
          child: Text(localization.global_delete),
          onPressed: () {
            homeCubit.deleteTag(synonym.id);
            Navigator.pop(dialogContext);
          },
        ),
      ],
    ),
  );
}

/// Picks the destination category for a main tag; its synonyms move with it
/// (backend rule: a synonym lives in its main tag's category).
void _moveTagDialog(BuildContext context, Category category, Tag mainTag) {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();
  // Any category except Dates (backend-managed), Others (read-only grey
  // bucket) and the current one.
  final targets = homeCubit.state.categories
      .where((target) =>
          target.id != category.id &&
          target.kind != CategoryKind.date &&
          target.kind != CategoryKind.other)
      .toList();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(localization.categories_moveTagTitle(mainTag.tag)),
      children: targets
          .map((target) => SimpleDialogOption(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: colorFromHex(target.color),
                    ),
                    const SizedBox(width: 10),
                    Text(target.category),
                  ],
                ),
                onPressed: () {
                  homeCubit.moveTag(mainTag, target.id);
                  Navigator.pop(dialogContext);
                },
              ))
          .toList(),
    ),
  );
}

/// Confirms a main tag deletion: shows how many events use the synonym group
/// and, for the ones that would be left without any other tag, lets the user
/// delete them or keep them with their date only.
Future<void> _deleteTagDialog(
    BuildContext context, Tag mainTag, List<Tag> synonyms) async {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();

  final usage = await homeCubit.fetchTagUsage(mainTag.id);
  if (usage == null || !context.mounted) {
    return;
  }

  bool deleteEvents = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(localization.categories_deleteTagTitle(mainTag.tag)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localization.categories_deleteTagEvents(usage.events)),
            if (synonyms.isNotEmpty)
              Text(localization.categories_deleteTagSynonyms(synonyms.length)),
            if (usage.exclusiveEvents > 0) ...[
              const SizedBox(height: 10),
              Text(localization
                  .categories_deleteTagExclusiveEvents(usage.exclusiveEvents)),
              RadioGroup<bool>(
                groupValue: deleteEvents,
                onChanged: (value) =>
                    setState(() => deleteEvents = value ?? false),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      dense: true,
                      title:
                          Text(localization.categories_deleteTagKeepEvents),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      dense: true,
                      title:
                          Text(localization.categories_deleteTagDeleteEvents),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: Text(localization.global_cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(localization.global_delete),
            onPressed: () {
              homeCubit.deleteTag(mainTag.id, deleteEvents: deleteEvents);
              Navigator.pop(dialogContext);
            },
          ),
        ],
      ),
    ),
  );
}

enum _CategoryDeleteChoice { moveTags, deleteTags, deleteAll }

/// Confirms a category deletion: move its tags to the Others category
/// (default), delete them while keeping the events, or delete them together
/// with the events that only use tags from this category.
Future<void> _deleteCategoryDialog(
    BuildContext context, Category category) async {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();

  final usage = await homeCubit.fetchCategoryUsage(category.id);
  if (usage == null || !context.mounted) {
    return;
  }

  var choice = _CategoryDeleteChoice.moveTags;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(localization.categories_deleteCategory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localization.categories_deleteCategoryTags(usage.tags)),
            if (usage.tags > 0) ...[
              Text(localization.categories_deleteCategoryEvents(usage.events)),
              RadioGroup<_CategoryDeleteChoice>(
                groupValue: choice,
                onChanged: (value) => setState(
                    () => choice = value ?? _CategoryDeleteChoice.moveTags),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<_CategoryDeleteChoice>(
                      value: _CategoryDeleteChoice.moveTags,
                      dense: true,
                      title: Text(localization.categories_deleteMoveTags),
                    ),
                    RadioListTile<_CategoryDeleteChoice>(
                      value: _CategoryDeleteChoice.deleteTags,
                      dense: true,
                      title: Text(
                          localization.categories_deleteCategoryDeleteTags),
                    ),
                    if (usage.exclusiveEvents > 0)
                      RadioListTile<_CategoryDeleteChoice>(
                        value: _CategoryDeleteChoice.deleteAll,
                        dense: true,
                        title: Text(
                            localization.categories_deleteCategoryDeleteAll),
                        subtitle: Text(localization
                            .categories_deleteCategoryDeleteAllDetail(
                                usage.exclusiveEvents)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: Text(localization.global_cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(localization.global_delete),
            onPressed: () {
              homeCubit.deleteCategory(
                category.id,
                moveTags: choice == _CategoryDeleteChoice.moveTags,
                deleteEvents: choice == _CategoryDeleteChoice.deleteAll,
              );
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
  showDialog<void>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      onSubmit: onSubmit,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String label;
  final String? initialValue;
  final void Function(String value) onSubmit;

  const _TextDialog(
      {required this.title,
      required this.label,
      this.initialValue,
      required this.onSubmit});

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  // Owned by the dialog state: State.dispose only runs once the route is
  // fully gone. Disposing from showDialog's future is too early — it
  // completes on pop, while the TextField is still animating out.
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(localization.global_save),
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isNotEmpty) {
              widget.onSubmit(value);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

/// Category create/edit dialog: name + preset color picker.
void categoryDialog(BuildContext context,
    {required String title,
    String? initialName,
    String? initialColor,
    required void Function(String name, String color) onSubmit}) {
  showDialog<void>(
    context: context,
    builder: (_) => _CategoryDialog(
      title: title,
      initialName: initialName,
      initialColor: initialColor,
      onSubmit: onSubmit,
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialColor;
  final void Function(String name, String color) onSubmit;

  const _CategoryDialog(
      {required this.title,
      this.initialName,
      this.initialColor,
      required this.onSubmit});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  // Owned by the dialog state: State.dispose only runs once the route is
  // fully gone. Disposing from showDialog's future is too early — it
  // completes on pop, while the TextField is still animating out.
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);
  late String _selectedColor = widget.initialColor ?? categoryColors.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration:
                InputDecoration(labelText: localization.categories_categoryName),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categoryColors
                .map((color) => GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: colorFromHex(color),
                        child: _selectedColor == color
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
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          child: Text(localization.global_save),
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.onSubmit(name, _selectedColor);
            }
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
