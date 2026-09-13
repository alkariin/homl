import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/components/tag.dart';
import 'package:homl/helpers/colors.dart';

/// Data of a chip displayed by [TagInput]. [id] is -1 when the tag does not
/// exist on the backend yet.
class TagChipData {
  final int id;

  /// Stored name of the tag: what the callbacks report and what the requests
  /// carry, whatever the chip displays.
  final String name;
  final String? color;

  /// Category color tinting the input border and logo while this tag is the
  /// top suggestion; null keeps the default styling (e.g. Others tags).
  final String? highlightColor;

  /// Label shown instead of [name] when they differ — the month date tags are
  /// stored in English and displayed in the app locale (see
  /// helpers/date_tags.dart). The input matches the typed text against both,
  /// so a translated month is searchable under its label too.
  final String? displayName;

  /// Display name of the tag's category, printed next to its suggestion so
  /// the color of the chip is explained; nothing is printed when null.
  final String? category;

  const TagChipData(
      {required this.id,
      required this.name,
      this.color,
      this.highlightColor,
      this.displayName,
      this.category});

  String get label => displayName ?? name;
}

/// Shared tag input: a text field with autocomplete on the existing tags.
/// Pressing enter (or tapping a suggestion) adds the tag as a chip and clears
/// the field; a long press on a chip removes it.
class TagInput extends StatefulWidget {
  final String labelText;

  /// Chips currently displayed (controlled by the parent).
  final List<TagChipData> tags;

  /// All the known tags, used for the autocomplete.
  final List<TagChipData> suggestions;

  final void Function(String name) onAddTag;
  final void Function(TagChipData tag)? onRemoveTag;

  /// Rendered before the chips, in the same wrap (e.g. the fixed month/year
  /// date chips of the insert form).
  final List<Widget> leading;

  /// Shows a magnifier in front of the field (the search page).
  final bool showSearchIcon;

  /// Opens the tag picker. Renders the browse button next to the field when
  /// set, nothing when null.
  final VoidCallback? onBrowse;

  /// Tooltip and accessible name of that button.
  final String? browseLabel;

  /// Reports the stored name of the tag being typed — the top suggestion of
  /// the autocomplete — on every change of the field, and null when it is
  /// empty or nothing matches it. The app bar mark follows it.
  final void Function(String? tagName)? onSuggestionChanged;

  /// Text controller of the field. Owned by the parent when provided (so it
  /// can read or clear the pending text), otherwise the input creates and
  /// disposes its own.
  final TextEditingController? controller;

  const TagInput(
      {required this.labelText,
      required this.tags,
      required this.suggestions,
      required this.onAddTag,
      this.onRemoveTag,
      this.leading = const [],
      this.showSearchIcon = false,
      this.onBrowse,
      this.browseLabel,
      this.onSuggestionChanged,
      this.controller,
      super.key});

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  /// Side of the browse button: the height a filled field takes under the
  /// theme's content padding, so the two sit flush.
  static const double _browseButtonSize = 52;

  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Registered once, and never during a build: the field notifies from the
    // user's keystrokes and from the deferred clear below.
    _controller.addListener(_reportSuggestion);
  }

  /// Hands the top suggestion to the parent (see [TagInput.onSuggestionChanged]).
  void _reportSuggestion() {
    final report = widget.onSuggestionChanged;
    if (report == null) return;

    final suggestions = _filterSuggestions(_controller.value);
    report(suggestions.isEmpty ? null : suggestions.first.name);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportSuggestion);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // A typed label that names a known tag is resolved to its stored name, so
    // a French user typing "juillet" adds the "July" date tag instead of
    // creating a second, untranslated tag.
    final name = _suggestionFor(trimmed)?.name ?? trimmed;
    if (widget.tags
        .any((tag) => tag.name.toLowerCase() == name.toLowerCase())) {
      _clearField();
      return;
    }

    widget.onAddTag(name);
    _clearField();
    _focusNode.requestFocus();
  }

  /// Clears the field on the next microtask, not synchronously. When [_submit]
  /// runs from RawAutocomplete's onSelected (a tap on a suggestion), the
  /// autocomplete is still inside its `_selecting` guard: a synchronous clear
  /// is swallowed by its controller listener, which leaves its cached options
  /// list non-empty — and the dropdown pops back over the emptied field on the
  /// next focus gain (e.g. coming back from an event's detail sheet), with no
  /// way to dismiss it. Deferring the clear lets the autocomplete finish
  /// selecting first, so it recomputes its options for the empty text and
  /// stays closed.
  void _clearField() {
    scheduleMicrotask(() {
      if (mounted) _controller.clear();
    });
  }

  /// Suggestion whose stored name or displayed label is exactly [text].
  TagChipData? _suggestionFor(String text) {
    final lowered = text.toLowerCase();
    for (final suggestion in widget.suggestions) {
      if (suggestion.name.toLowerCase() == lowered ||
          suggestion.label.toLowerCase() == lowered) {
        return suggestion;
      }
    }
    return null;
  }

  Iterable<TagChipData> _filterSuggestions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return const Iterable<TagChipData>.empty();

    // Matched on the label as well as the stored name: a translated month tag
    // is reachable by typing it in the app language.
    final candidates = widget.suggestions.where((suggestion) =>
        (suggestion.name.toLowerCase().contains(query) ||
            suggestion.label.toLowerCase().contains(query)) &&
        !widget.tags.any(
            (tag) => tag.name.toLowerCase() == suggestion.name.toLowerCase()));

    // Tags starting with the query come first, so the top suggestion (which
    // also drives the highlight color below) is the most natural completion.
    bool startsWithQuery(TagChipData s) =>
        s.name.toLowerCase().startsWith(query) ||
        s.label.toLowerCase().startsWith(query);

    return [
      ...candidates.where(startsWithQuery),
      ...candidates.where((s) => !startsWithQuery(s)),
    ];
  }

  /// Color highlighting the field and the logo while the user types: the
  /// category color of the top suggestion, darkened so the pastel presets
  /// stay visible, or null when there is no suggestion or the suggestion
  /// carries no highlight color (Others tags).
  Color? _highlightFor(TextEditingValue value) {
    final suggestions = _filterSuggestions(value);
    final highlightColor =
        suggestions.isEmpty ? null : suggestions.first.highlightColor;
    return highlightColor == null ? null : darken(colorFromHex(highlightColor));
  }

  /// Opens the tag picker: a tonal square matching the height of the field,
  /// wearing the same icon as the Categories tab.
  Widget _browseButton() {
    return IconButton(
      onPressed: widget.onBrowse,
      tooltip: widget.browseLabel,
      icon: const FaIcon(FontAwesomeIcons.tags, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: ink.withValues(alpha: 0.06),
        foregroundColor: ink,
        padding: EdgeInsets.zero,
        fixedSize: const Size.square(_browseButtonSize),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading.isNotEmpty || widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.leading,
              // A simple tap on a chip removes it (the date chips are the
              // [leading] widgets and keep their own onTap)
              ...widget.tags.map((tag) => Tag(
                  id: tag.id,
                  text: tag.label,
                  color: tag.color,
                  large: true,
                  onTap: widget.onRemoveTag == null
                      ? null
                      : () => widget.onRemoveTag!(tag),
                  onDeleteTag: widget.onRemoveTag == null
                      ? null
                      : (_) => widget.onRemoveTag!(tag))),
            ],
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            Expanded(
              child: RawAutocomplete<TagChipData>(
                textEditingController: _controller,
                focusNode: _focusNode,
                displayStringForOption: (option) => option.label,
                optionsBuilder: _filterSuggestions,
                onSelected: (option) => _submit(option.name),
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final highlight = _highlightFor(value);
                      // A null border falls back to the theme (borderless
                      // filled field, ink border on focus).
                      final border = highlight == null
                          ? null
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: highlight, width: 1),
                            );
                      final focusedBorder = highlight == null
                          ? null
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: highlight, width: 1.5),
                            );

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: widget.labelText,
                          enabledBorder: border,
                          focusedBorder: focusedBorder,
                          // FaIcon is a bare glyph (the Icon widget minus
                          // its SizedBox and Center): handed the 48 px slot
                          // of the prefix it would paint in its top-left
                          // corner, so it is centered by hand.
                          prefixIcon: widget.showSearchIcon
                              ? Center(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: FaIcon(
                                      FontAwesomeIcons.magnifyingGlass,
                                      size: 18,
                                      color: ink.withValues(alpha: 0.45)),
                                )
                              : null,
                          suffixIcon: value.text.isEmpty
                              ? const SizedBox.shrink()
                              : IconButton(
                                  icon: FaIcon(
                                      FontAwesomeIcons.solidCircleXmark,
                                      size: 18,
                                      color: ink.withValues(alpha: 0.35)),
                                  onPressed: controller.clear,
                                ),
                        ),
                        onFieldSubmitted: _submit,
                      );
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      color: Colors.white,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            // The suggestion is the chip it would become,
                            // with its category named on the right: the
                            // color of the chip, the border and the app bar
                            // mark then explain themselves.
                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 14, 0),
                              title: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Tag(
                                    id: option.id,
                                    text: option.label,
                                    color: option.color),
                              ),
                              trailing: option.category == null
                                  ? null
                                  : Text(
                                      option.category!,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: ink.withValues(alpha: 0.45)),
                                    ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.onBrowse != null) ...[
              const SizedBox(width: 10),
              _browseButton(),
            ],
          ],
        ),
      ],
    );
  }
}
