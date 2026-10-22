import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/category.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/data/models/tag_group.dart';
import 'package:homl/helpers/category_labels.dart';
import 'package:homl/helpers/colors.dart';
import 'package:homl/helpers/date_tags.dart';
import 'package:homl/helpers/e2ee.dart';
import 'package:homl/helpers/event_search.dart' show normalizeTagName;
import 'package:homl/helpers/tag_groups.dart';
import 'package:homl/pages/home/bloc/home_cubit.dart';

/// True when [category] holds the date tags — the months, years and Ongoing
/// the backend derives from the event periods. Older backends do not send the
/// kind: fall back to the seeded name, like [localizedCategoryName].
bool isDateCategory(Category category) =>
    category.kind == CategoryKind.date ||
    (category.kind == null && category.category == defaultDatesName);

/// Categories list: every category with its tags, synonyms and tag groups.
///
/// Two modes, chosen by [onTagSelected]:
/// - null (Categories tab): management view — tapping a tag (or long
///   pressing its chip) opens its sheet, with its synonyms and actions;
///   categories are editable;
/// - non-null (tag picker opened from the browse button): read-only browser —
///   tapping a tag hands it to the callback (e.g. insert it as a search
///   filter or as an event tag), tapping a group hands its tags to
///   [onGroupSelected].
class CategoryManagementBody extends StatelessWidget {
  final void Function(TagView tag)? onTagSelected;

  /// Picker mode: the tags of the tapped group. The groups are left out of
  /// the picker when null.
  final void Function(List<TagView> tags)? onGroupSelected;

  /// Lists the Dates category too. False where picking one makes no sense:
  /// an event's date tags come from its period, never from the picker (see
  /// [showTagPickerSheet]). Searching by month or year stays fair game.
  final bool showDates;

  const CategoryManagementBody(
      {this.onTagSelected,
      this.onGroupSelected,
      this.showDates = true,
      super.key});

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
            .where((category) => showDates || !isDateCategory(category))
            .map((category) => _CategoryTile(
                category: category,
                onTagSelected: onTagSelected,
                onGroupSelected: onGroupSelected))
            .toList(),
      );
    });
  }
}

/// Bottom sheet with the categories in picker mode: tapping a tag hands it
/// to [onTagSelected] and closes the sheet. [showDates] hides the Dates
/// category when picking one would be meaningless — see
/// [CategoryManagementBody.showDates].
void showTagPickerSheet(BuildContext context,
    {required void Function(TagView tag) onTagSelected,
    bool showDates = true}) {
  final homeCubit = context.read<HomeCubit>();

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => BlocProvider.value(
      value: homeCubit,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The sheet is reached from a button that no longer says what it
          // opens, so it says it itself.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              AppLocalizations.of(sheetContext)!.categories_pickTag,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: CategoryManagementBody(
              showDates: showDates,
              onTagSelected: (tag) {
                Navigator.pop(sheetContext);
                onTagSelected(tag);
              },
              // A group stands for its tags: each one is handed over, as if
              // picked one by one.
              onGroupSelected: (tags) {
                Navigator.pop(sheetContext);
                tags.forEach(onTagSelected);
              },
            ),
          ),
        ],
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
  final void Function(List<TagView> tags)? onGroupSelected;

  const _CategoryTile(
      {required this.category,
      required this.onTagSelected,
      required this.onGroupSelected});

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
    // The picker offers a group only when it can hand its tags over.
    final groups = isPicker && widget.onGroupSelected == null
        ? const <TagGroup>[]
        : category.groups;

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
    // On the dark cards the pastel itself is the light ink of the icon, over
    // a dimmer square: darkened, it would sink into it.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.homl.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.homl.hairline),
        boxShadow: [
          BoxShadow(
            color: context.homl.shadow,
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
                        color: base.withValues(alpha: isDark ? 0.22 : 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: FaIcon(FontAwesomeIcons.tag,
                            size: 15, color: isDark ? base : darken(base, .4)),
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
                                color:
                                    context.homl.ink.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    ),
                    if (!isPicker && !category.isLocked)
                      PopupMenuButton<String>(
                        icon: FaIcon(FontAwesomeIcons.ellipsisVertical,
                            size: 15,
                            color: context.homl.ink.withValues(alpha: 0.45)),
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
                                    color: context.homl.ink
                                        .withValues(alpha: 0.6)),
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
                          color: context.homl.ink.withValues(alpha: 0.35)),
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
                          color: context.homl.ink.withValues(alpha: 0.05),
                        ),
                        const SizedBox(height: 10),
                        // The main tags only, side by side: the synonyms
                        // are a count on their chip, listed in its sheet.
                        if (mainTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final mainTag in mainTags)
                                  _TagChip(
                                      category: category,
                                      mainTag: mainTag,
                                      canManage: canManageTags,
                                      onTagSelected: onTagSelected,
                                      synonyms: category.tags
                                          .where((tag) =>
                                              tag.idParentTag == mainTag.id)
                                          .toList()),
                              ],
                            ),
                          ),
                        if (groups.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                            child: Text(
                              localization.categories_groups,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      context.homl.ink.withValues(alpha: 0.45)),
                            ),
                          ),
                          ...groups.map((group) => _GroupRow(
                              category: category,
                              group: group,
                              canManage: canManageTags,
                              onGroupSelected:
                                  isPicker ? widget.onGroupSelected : null)),
                        ],
                        if (canManageTags && !isPicker)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _AddPill(
                                  label: localization.categories_newTag,
                                  onTap: () => _textDialog(
                                    context,
                                    title: localization.categories_newTag,
                                    label: localization.categories_categoryName,
                                    onSubmit: (name) =>
                                        homeCubit.createTag(name, category.id),
                                  ),
                                ),
                                // A group needs tags to hold.
                                if (mainTags.isNotEmpty)
                                  _AddPill(
                                    label: localization.categories_newGroup,
                                    onTap: () => tagGroupDialog(context,
                                        category: category),
                                  ),
                              ],
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

/// Stadium button adding something to a category (a tag, a group).
class _AddPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.homl.ink.withValues(alpha: 0.06),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: context.homl.ink),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.homl.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tag group: its chip, then the tags it stands for.
class _GroupRow extends StatelessWidget {
  final Category category;
  final TagGroup group;
  final bool canManage;

  /// Picker mode when non-null: a tap hands the group's tags over.
  final void Function(List<TagView> tags)? onGroupSelected;

  const _GroupRow(
      {required this.category,
      required this.group,
      required this.canManage,
      required this.onGroupSelected});

  /// The group's tags as the picker hands them out, built from the category
  /// itself: a name shared with another category's tag must not resolve to
  /// that other tag.
  List<TagView> _memberViews() {
    final byId = {for (final tag in category.tags) tag.id: tag};
    return [
      for (final id in group.members)
        if (byId[id] case final tag?)
          TagView(tag.id, category.color, tag.tag, category.id, tag.idParentTag)
    ];
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final members = tagGroupMemberNames(category, group);
    final onGroupSelected = this.onGroupSelected;

    final VoidCallback? onTap;
    if (onGroupSelected != null) {
      onTap = members.isEmpty ? null : () => onGroupSelected(_memberViews());
    } else {
      onTap = canManage
          ? () => _groupActionsDialog(context, category, group)
          : null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Flexible(
            child: components.Tag(
              id: group.id,
              text: group.name,
              color: category.color,
              isGroup: true,
              onTap: onTap,
              onDeleteTag: onGroupSelected == null && canManage
                  ? (_) => _groupActionsDialog(context, category, group)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              members.isEmpty
                  ? localization.categories_groupEmpty
                  : members.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.homl.ink.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tap (or long press) on a group chip: edit it or delete it.
void _groupActionsDialog(
    BuildContext context, Category category, TagGroup group) {
  var localization = AppLocalizations.of(context)!;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(group.name),
      children: [
        SimpleDialogOption(
          child: Text(localization.categories_editGroup),
          onPressed: () {
            Navigator.pop(dialogContext);
            tagGroupDialog(context, category: category, group: group);
          },
        ),
        SimpleDialogOption(
          child: Text(localization.categories_deleteGroup),
          onPressed: () {
            Navigator.pop(dialogContext);
            _deleteGroupDialog(context, group);
          },
        ),
      ],
    ),
  );
}

/// Confirms a group deletion: only the shortcut goes.
void _deleteGroupDialog(BuildContext context, TagGroup group) {
  var localization = AppLocalizations.of(context)!;
  final homeCubit = context.read<HomeCubit>();

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(localization.categories_deleteGroupTitle(group.name)),
      content: Text(localization.categories_deleteGroupInfo),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(dialogContext),
        ),
        TextButton(
          child: Text(localization.global_delete),
          onPressed: () {
            homeCubit.deleteTagGroup(group.id);
            Navigator.pop(dialogContext);
          },
        ),
      ],
    ),
  );
}

/// A main tag in its category card. Its synonyms are only counted on the
/// chip: a tap (or a long press) opens the tag sheet, which lists them along
/// with the tag's actions. In the picker a tap hands the tag over.
class _TagChip extends StatelessWidget {
  final Category category;
  final Tag mainTag;
  final List<Tag> synonyms;
  final bool canManage;

  /// Picker mode when non-null: a tap selects instead of opening the sheet.
  final void Function(TagView tag)? onTagSelected;

  const _TagChip(
      {required this.category,
      required this.mainTag,
      required this.synonyms,
      required this.canManage,
      required this.onTagSelected});

  @override
  Widget build(BuildContext context) {
    final onTagSelected = this.onTagSelected;
    // Read-only translation of the month date tags, which are stored in
    // English for every user (helpers/date_tags.dart).
    final locale = Localizations.localeOf(context).toString();

    final VoidCallback? onTap;
    if (onTagSelected != null) {
      onTap = () {
        final tagView = context.read<HomeCubit>().state.allTagsMap[mainTag.tag];
        if (tagView != null) onTagSelected(tagView);
      };
    } else if (canManage || synonyms.isNotEmpty) {
      // A read-only tag only opens the sheet to show its synonyms.
      onTap = () => _showTagSheet(context, mainTag, canManage: canManage);
    } else {
      onTap = null;
    }

    return components.Tag(
      id: mainTag.id,
      text: localizedTagName(mainTag.tag, locale),
      color: category.color,
      // The picker hands the main tag over, which finds the events of its
      // synonyms too: their count would only promise a choice it lacks.
      count: onTagSelected == null ? synonyms.length : 0,
      onTap: onTap,
      onDeleteTag:
          onTagSelected == null && onTap != null ? (_) => onTap!() : null,
    );
  }
}

/// Opens the sheet of [mainTag]: its synonyms, then its own actions when
/// [canManage]. [context] is the chip's: moving or deleting the tag closes
/// the sheet first, and their dialogs must outlive it.
void _showTagSheet(BuildContext context, Tag mainTag,
    {required bool canManage}) {
  final homeCubit = context.read<HomeCubit>();

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => BlocProvider.value(
      value: homeCubit,
      child: _TagSheet(
          tagId: mainTag.id, canManage: canManage, chipContext: context),
    ),
  );
}

class _TagSheet extends StatelessWidget {
  final int tagId;
  final bool canManage;
  final BuildContext chipContext;

  const _TagSheet(
      {required this.tagId,
      required this.canManage,
      required this.chipContext});

  /// The tag and its category, looked up again on every state: a synonym
  /// added or a rename made from the sheet shows at once. Null once the tag
  /// is gone.
  static (Category, Tag)? _find(HomeState state, int tagId) {
    for (final category in state.categories) {
      for (final tag in category.tags) {
        if (tag.id == tagId) return (category, tag);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();
    final locale = Localizations.localeOf(context).toString();
    final muted = context.homl.ink.withValues(alpha: 0.45);
    final iconColor = context.homl.ink.withValues(alpha: 0.6);
    const padding = EdgeInsets.symmetric(horizontal: 20);

    return BlocConsumer<HomeCubit, HomeState>(
      // Gone while the sheet is up (a sync, another device): close it, once,
      // unless a dialog sits on top of it.
      listenWhen: (previous, current) =>
          _find(previous, tagId) != null && _find(current, tagId) == null,
      listener: (context, _) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.pop(context);
        }
      },
      builder: (context, state) {
        final found = _find(state, tagId);
        if (found == null) return const SizedBox.shrink();
        final (category, mainTag) = found;
        final synonyms = category.tags
            .where((tag) => tag.idParentTag == mainTag.id)
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The tag as the card shows it, and where it is filed.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Flexible(
                      child: components.Tag(
                          id: mainTag.id,
                          text: localizedTagName(mainTag.tag, locale),
                          color: category.color,
                          large: true),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        localizedCategoryName(category, localization),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                child: Text(
                  localization.categories_synonyms,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: muted),
                ),
              ),
              for (final synonym in synonyms)
                _SynonymTile(
                    category: category,
                    mainTag: mainTag,
                    synonym: synonym,
                    canManage: canManage),
              if (canManage) ...[
                ListTile(
                  contentPadding: padding,
                  leading:
                      FaIcon(FontAwesomeIcons.plus, size: 14, color: iconColor),
                  title: Text(localization.categories_addSynonym),
                  onTap: () => _textDialog(
                    context,
                    title: localization.categories_addSynonym,
                    label: localization.categories_synonymName,
                    onSubmit: (name) => homeCubit.createTag(name, category.id,
                        idParentTag: mainTag.id),
                  ),
                ),
                Divider(
                    height: 17,
                    indent: 20,
                    endIndent: 20,
                    color: context.homl.ink.withValues(alpha: 0.08)),
                ListTile(
                  contentPadding: padding,
                  leading:
                      FaIcon(FontAwesomeIcons.pen, size: 14, color: iconColor),
                  title: Text(localization.categories_renameTag),
                  onTap: () => _textDialog(
                    context,
                    title: localization.categories_renameTag,
                    label: localization.categories_categoryName,
                    initialValue: mainTag.tag,
                    onSubmit: (name) =>
                        homeCubit.updateTag(mainTag.id, name, category.id),
                  ),
                ),
                ListTile(
                  contentPadding: padding,
                  leading: FaIcon(FontAwesomeIcons.arrowRightArrowLeft,
                      size: 14, color: iconColor),
                  title: Text(localization.categories_moveTag),
                  onTap: () {
                    Navigator.pop(context);
                    _moveTagDialog(chipContext, category, mainTag);
                  },
                ),
                ListTile(
                  contentPadding: padding,
                  leading: FaIcon(FontAwesomeIcons.trash,
                      size: 14, color: Colors.red.shade400),
                  title: Text(localization.categories_deleteTag,
                      style: TextStyle(color: Colors.red.shade400)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteTagDialog(chipContext, mainTag, synonyms);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A synonym in the tag sheet. A tap opens its menu: rename it, detach it
/// from its main tag, or delete it (after a confirmation: its events
/// migrate to the main tag).
class _SynonymTile extends StatelessWidget {
  final Category category;
  final Tag mainTag;
  final Tag synonym;
  final bool canManage;

  const _SynonymTile(
      {required this.category,
      required this.mainTag,
      required this.synonym,
      required this.canManage});

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final homeCubit = context.read<HomeCubit>();
    final locale = Localizations.localeOf(context).toString();
    final ink = context.homl.ink.withValues(alpha: 0.6);
    const padding = EdgeInsets.symmetric(horizontal: 20);
    final title = Text(localizedTagName(synonym.tag, locale));
    // An empty leading lines the name up with the labels of the rows below,
    // which follow an icon.
    const leading = SizedBox(width: 14);

    if (!canManage) {
      return ListTile(contentPadding: padding, leading: leading, title: title);
    }

    PopupMenuItem<String> item(String value, FaIconData icon, String label,
            {Color? color}) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              FaIcon(icon, size: 14, color: color ?? ink),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: color)),
            ],
          ),
        );

    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'rename':
            _textDialog(
              context,
              title: localization.categories_renameSynonym,
              label: localization.categories_synonymName,
              initialValue: synonym.tag,
              onSubmit: (name) => homeCubit.updateTag(
                  synonym.id, name, category.id,
                  idParentTag: synonym.idParentTag),
            );
          case 'detach':
            homeCubit.updateTag(synonym.id, synonym.tag, category.id);
          case 'delete':
            _deleteSynonymDialog(context, synonym, mainTag.tag);
        }
      },
      itemBuilder: (_) => [
        item('rename', FontAwesomeIcons.pen,
            localization.categories_renameSynonym),
        item('detach', FontAwesomeIcons.linkSlash,
            localization.categories_detachSynonym),
        item('delete', FontAwesomeIcons.trash, localization.global_delete,
            color: Colors.red.shade400),
      ],
      child: ListTile(
        contentPadding: padding,
        leading: leading,
        title: title,
        trailing: FaIcon(FontAwesomeIcons.ellipsisVertical,
            size: 15, color: context.homl.ink.withValues(alpha: 0.45)),
      ),
    );
  }
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

/// Tag group create/edit dialog: a name and the main tags of [category] it
/// stands for. Editing passes the [group].
void tagGroupDialog(BuildContext context,
    {required Category category, TagGroup? group}) {
  final homeCubit = context.read<HomeCubit>();

  showDialog<void>(
    context: context,
    builder: (_) => _TagGroupDialog(
      category: category,
      group: group,
      // Every tag and group name of the account: typed in the same field as
      // the tags, a group named like one of them would be ambiguous there.
      takenNames: {
        for (final other in homeCubit.state.categories) ...[
          for (final tag in other.tags) normalizeTagName(tag.tag),
          for (final otherGroup in other.groups)
            if (otherGroup.id != group?.id) normalizeTagName(otherGroup.name),
        ],
      },
      onSubmit: (name, members) => group == null
          ? homeCubit.createTagGroup(name, category.id, members)
          : homeCubit.updateTagGroup(group.id, name, members),
    ),
  );
}

class _TagGroupDialog extends StatefulWidget {
  final Category category;
  final TagGroup? group;

  /// Normalized names the group cannot take.
  final Set<String> takenNames;
  final void Function(String name, List<int> members) onSubmit;

  const _TagGroupDialog(
      {required this.category,
      required this.group,
      required this.takenNames,
      required this.onSubmit});

  @override
  State<_TagGroupDialog> createState() => _TagGroupDialogState();
}

class _TagGroupDialogState extends State<_TagGroupDialog> {
  // Owned by the dialog state, like the other dialogs of this page.
  late final TextEditingController _controller =
      TextEditingController(text: widget.group?.name);
  late final Set<int> _selected = {...?widget.group?.members};

  late final List<Tag> _mainTags =
      widget.category.tags.where((tag) => tag.idParentTag == null).toList();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Why the typed name cannot be saved, or null when it can.
  String? _nameError(AppLocalizations localization) {
    final name = _controller.text.trim();
    if (name.isEmpty) return null;
    if (E2ee().isBlacklistedTag(name)) {
      return localization.categories_groupNameReserved;
    }
    if (widget.takenNames.contains(normalizeTagName(name))) {
      return localization.categories_groupNameTaken;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final nameError = _nameError(localization);
    // Members in the category's order, whatever the order of the taps; a
    // member deleted meanwhile is simply not listed anymore.
    final members = [
      for (final tag in _mainTags)
        if (_selected.contains(tag.id)) tag.id
    ];
    final canSave = _controller.text.trim().isNotEmpty &&
        nameError == null &&
        members.isNotEmpty;

    return AlertDialog(
      title: Text(widget.group == null
          ? localization.categories_newGroup
          : localization.categories_editGroup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: widget.group == null,
              decoration: InputDecoration(
                labelText: localization.categories_categoryName,
                errorText: nameError,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              localization.categories_groupHint,
              style: TextStyle(
                  fontSize: 12.5,
                  color: context.homl.ink.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 16),
            Text(
              localization.categories_groupMembers,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _mainTags)
                  FilterChip(
                    label: Text(localizedTagName(tag.tag, locale)),
                    selected: _selected.contains(tag.id),
                    selectedColor: colorFromHex(widget.category.color)
                        .withValues(alpha: 0.45),
                    onSelected: (selected) => setState(() => selected
                        ? _selected.add(tag.id)
                        : _selected.remove(tag.id)),
                  ),
              ],
            ),
            if (members.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                localization.categories_groupNeedsMembers,
                style: TextStyle(
                    fontSize: 12.5,
                    color: context.homl.ink.withValues(alpha: 0.55)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(localization.global_cancel),
          onPressed: () => Navigator.pop(context),
        ),
        TextButton(
          onPressed: canSave
              ? () {
                  widget.onSubmit(_controller.text.trim(), members);
                  Navigator.pop(context);
                }
              : null,
          child: Text(localization.global_save),
        ),
      ],
    );
  }
}
