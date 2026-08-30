import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

/// Categories list: every category with its tags and synonyms.
///
/// Two modes, chosen by [onTagSelected]:
/// - null (Categories tab): management view — tapping a tag (or long
///   pressing its chip) opens its actions menu, categories are editable;
/// - non-null (tag picker opened from the "#" logo): read-only browser —
///   tapping a tag hands it to the callback (e.g. insert it as a search
///   filter or as an event tag).
class CategoryManagementBody extends StatelessWidget {
  final void Function(TagView tag)? onTagSelected;

  const CategoryManagementBody({this.onTagSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(builder: (context, state) {
      return ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 100),
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

/// Bottom sheet with the categories in picker mode: tapping a tag hands it
/// to [onTagSelected] and closes the sheet.
void showTagPickerSheet(BuildContext context,
    {required void Function(TagView tag) onTagSelected}) {
  final homeCubit = context.read<HomeCubit>();

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => BlocProvider.value(
      value: homeCubit,
      child: CategoryManagementBody(
        onTagSelected: (tag) {
          Navigator.pop(sheetContext);
          onTagSelected(tag);
        },
      ),
    ),
  );
}

/// Category card: colored icon, name and tag count in the collapsed header,
/// tags and the add-tag pill in the expandable body. Category actions
/// (edit/delete) live in the trailing "more" menu.
class _CategoryTile extends StatefulWidget {
  final Category category;
  final void Function(TagView tag)? onTagSelected;

  const _CategoryTile({required this.category, required this.onTagSelected});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();
    final category = widget.category;
    final onTagSelected = widget.onTagSelected;
    final isPicker = onTagSelected != null;
    final mainTags =
        category.tags.where((tag) => tag.idParentTag == null).toList();

    // When the backend exposes the category kind, only the Dates tags are
    // off-limits (managed by the backend from the event dates). The Others
    // tags are manageable like any other so the free tags typed on the
    // insert page can be renamed, given synonyms or moved to a real
    // category. Older backends do not send the kind: fall back to the legacy
    // convention (first category is Dates, the next one is Persons) and its
    // legacy rules.
    final bool canManageTags;
    if (category.kind != null) {
      canManageTags = category.kind != CategoryKind.date;
    } else {
      final idDates = homeCubit.state.categories.isEmpty
          ? -1
          : homeCubit.state.categories.first.id;
      canManageTags = category.id != idDates && category.id != idDates + 1;
    }

    final base = colorFromHex(category.color);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
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
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: base.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: FaIcon(FontAwesomeIcons.tag,
                            size: 15, color: darken(base, .4)),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedCategoryName(category, localization),
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            localization.categories_tagCount(mainTags.length),
                            style: TextStyle(
                                fontSize: 12.5,
                                color: ink.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    ),
                    if (!isPicker && !category.isLocked)
                      PopupMenuButton<String>(
                        icon: FaIcon(FontAwesomeIcons.ellipsisVertical,
                            size: 15, color: ink.withValues(alpha: 0.45)),
                        onSelected: (action) {
                          if (action == 'edit') {
                            categoryDialog(
                              context,
                              title: localization.categories_editCategory,
                              initialName:
                                  localizedCategoryName(category, localization),
                              initialColor: category.color,
                              onSubmit: (name, color) => homeCubit
                                  .updateCategory(category.id, name, color),
                            );
                          } else {
                            _deleteCategoryDialog(context, category);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                FaIcon(FontAwesomeIcons.pen,
                                    size: 14,
                                    color: ink.withValues(alpha: 0.6)),
                                const SizedBox(width: 12),
                                Text(localization.categories_editCategory),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                FaIcon(FontAwesomeIcons.trash,
                                    size: 14, color: Colors.red.shade400),
                                const SizedBox(width: 12),
                                Text(localization.global_delete,
                                    style:
                                        TextStyle(color: Colors.red.shade400)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more,
                          color: ink.withValues(alpha: 0.35)),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                        const SizedBox(height: 10),
                        ...mainTags.map((mainTag) => _TagRow(
                            category: category,
                            mainTag: mainTag,
                            canManage: canManageTags,
                            onTagSelected: onTagSelected,
                            synonyms: category.tags
                                .where((tag) => tag.idParentTag == mainTag.id)
                                .toList())),
                        if (canManageTags && !isPicker)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: ink.withValues(alpha: 0.06),
                                shape: const StadiumBorder(),
                                child: InkWell(
                                  customBorder: const StadiumBorder(),
                                  onTap: () => _textDialog(
                                    context,
                                    title: localization.categories_newTag,
                                    label: localization.categories_categoryName,
                                    onSubmit: (name) =>
                                        homeCubit.createTag(name, category.id),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.add,
                                            size: 16, color: ink),
                                        const SizedBox(width: 4),
                                        Text(
                                          localization.categories_newTag,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  final Category category;
  final Tag mainTag;
  final List<Tag> synonyms;
  final bool canManage;

  /// Picker mode when non-null: taps select instead of opening the menus.
  final void Function(TagView tag)? onTagSelected;

  const _TagRow(
      {required this.category,
      required this.mainTag,
      required this.synonyms,
      required this.canManage,
      required this.onTagSelected});

  /// Hands the tapped tag to the picker callback (filter/tag insertion).
  void _selectTag(BuildContext context, Tag tag) {
    final tagView = context.read<HomeCubit>().state.allTagsMap[tag.tag];
    if (tagView != null) {
      onTagSelected!(tagView);
    }
  }

  void _onAction(BuildContext context, String action) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();

    switch (action) {
      case 'rename':
        _textDialog(
          context,
          title: localization.categories_renameTag,
          label: localization.categories_categoryName,
          initialValue: mainTag.tag,
          onSubmit: (name) =>
              homeCubit.updateTag(mainTag.id, name, category.id),
        );
        break;
      case 'synonym':
        _textDialog(
          context,
          title: localization.categories_addSynonym,
          label: localization.categories_synonymName,
          onSubmit: (name) =>
              homeCubit.createTag(name, category.id, idParentTag: mainTag.id),
        );
        break;
      case 'move':
        _moveTagDialog(context, category, mainTag);
        break;
      case 'delete':
        _deleteTagDialog(context, mainTag, synonyms);
        break;
    }
  }

  /// Long press on the main tag chip: the same actions as the trailing menu,
  /// as a dialog.
  void _mainTagDialog(BuildContext context) {
    var localization = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(mainTag.tag),
        children: [
          for (final (action, label) in [
            ('rename', localization.categories_renameTag),
            ('synonym', localization.categories_addSynonym),
            ('move', localization.categories_moveTag),
            ('delete', localization.categories_deleteTag),
          ])
            SimpleDialogOption(
              child: Text(label),
              onPressed: () {
                Navigator.pop(dialogContext);
                _onAction(context, action);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPicker = onTagSelected != null;
    // Read-only translation of the month date tags, which are stored in
    // English for every user (helpers/date_tags.dart).
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          components.Tag(
            id: mainTag.id,
            text: localizedTagName(mainTag.tag, locale),
            color: category.color,
            onTap: isPicker
                ? () => _selectTag(context, mainTag)
                : !canManage
                    ? null
                    : () => _mainTagDialog(context),
            onDeleteTag:
                isPicker || !canManage ? null : (_) => _mainTagDialog(context),
          ),
          ...synonyms.map((synonym) => components.Tag(
                id: synonym.id,
                text: localizedTagName(synonym.tag, locale),
                color: category.color,
                onTap: isPicker
                    ? () => _selectTag(context, synonym)
                    : !canManage
                        ? null
                        : () => _synonymDialog(context, category, synonym),
                onDeleteTag: isPicker || !canManage
                    ? null
                    : (_) => _synonymDialog(context, category, synonym),
              )),
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

/// Category picker dialog: every category except Dates (backend-managed)
/// and [excludeCategoryId] when given.
void pickCategoryDialog(BuildContext context,
    {required String title,
    int? excludeCategoryId,
    required void Function(Category category) onPicked}) {
  final categories = context
      .read<HomeCubit>()
      .state
      .categories
      .where((category) =>
          category.kind != CategoryKind.date &&
          category.id != excludeCategoryId)
      .toList();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: categories
          .map((category) => SimpleDialogOption(
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: colorFromHex(category.color),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(localizedCategoryName(
                        category, AppLocalizations.of(dialogContext)!)),
                  ],
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  onPicked(category);
                },
              ))
          .toList(),
    ),
  );
}

/// Picks the destination category for a main tag; its synonyms move with it
/// (backend rule: a synonym lives in its main tag's category).
void _moveTagDialog(BuildContext context, Category category, Tag mainTag) {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();

  pickCategoryDialog(
    context,
    title: localization.categories_moveTagTitle(mainTag.tag),
    excludeCategoryId: category.id,
    onPicked: (target) => homeCubit.moveTag(mainTag, target.id),
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

  // Keeping the events is preselected: a hasty confirm must never delete
  // them.
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
            // As soon as an event uses the tag, ask what to do with them
            // all: keep them (the tag is simply removed; the ones that had
            // no other tag are left with their date only) or delete them.
            if (usage.events > 0) ...[
              const SizedBox(height: 10),
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
                      title: Text(localization.categories_deleteTagKeepEvents),
                      subtitle: usage.exclusiveEvents > 0
                          ? Text(
                              localization.categories_deleteTagExclusiveEvents(
                                  usage.exclusiveEvents))
                          : null,
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
/// (default, so a hasty confirm never loses anything), delete them while
/// keeping the events, or delete them together with every event they tag.
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
                    if (usage.events > 0)
                      RadioListTile<_CategoryDeleteChoice>(
                        value: _CategoryDeleteChoice.deleteAll,
                        dense: true,
                        title: Text(
                            localization.categories_deleteCategoryDeleteAll),
                        subtitle: Text(localization
                            .categories_deleteCategoryDeleteAllDetail(
                                usage.events)),
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
      // Scrollable: the swatch grid rounds up to a fraction of a pixel more
      // than the dialog offers on some densities ("bottom overflowed").
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: localization.categories_categoryName),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categoryColors.map((color) {
                final swatch = colorFromHex(color);
                final selected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            selected ? darken(swatch, .35) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check,
                            size: 18, color: darken(swatch, .35))
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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
