import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:homl/components/logo.dart';
import 'package:homl/components/tag.dart';
import 'package:homl/helpers/colors.dart';

/// Data of a chip displayed by [TagInput]. [id] is -1 when the tag does not
/// exist on the backend yet.
class TagChipData {
  final int id;
  final String name;
  final String? color;

  /// Category color tinting the input border and logo while this tag is the
  /// top suggestion; null keeps the default styling (e.g. Others tags).
  final String? highlightColor;

  const TagChipData(
      {required this.id, required this.name, this.color, this.highlightColor});
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

  /// Rendered before the chips (e.g. the fixed date chip of the insert form).
  final Widget? leading;

  /// Rendered after the text field (e.g. the categories management button).
  final Widget? trailing;

  /// Shows the homl "#" logo on the left of the field (search page).
  final bool showLogo;

  /// Called when the logo is tapped, with the trimmed text currently typed
  /// in the field (empty when the field is empty). Leaves the logo inert
  /// when null.
  final void Function(String pendingText)? onLogoTap;

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
      this.leading,
      this.trailing,
      this.showLogo = false,
      this.onLogoTap,
      this.controller,
      super.key});

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (widget.tags
        .any((tag) => tag.name.toLowerCase() == trimmed.toLowerCase())) {
      _controller.clear();
      return;
    }

    widget.onAddTag(trimmed);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Iterable<TagChipData> _filterSuggestions(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return const Iterable<TagChipData>.empty();

    final candidates = widget.suggestions.where((suggestion) =>
        suggestion.name.toLowerCase().contains(query) &&
        !widget.tags.any(
            (tag) => tag.name.toLowerCase() == suggestion.name.toLowerCase()));

    // Tags starting with the query come first, so the top suggestion (which
    // also drives the highlight color below) is the most natural completion.
    return [
      ...candidates.where((s) => s.name.toLowerCase().startsWith(query)),
      ...candidates.where((s) => !s.name.toLowerCase().startsWith(query)),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading != null || widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.leading != null) widget.leading!,
              // A simple tap on a chip removes it (the date chip is the
              // [leading] widget and keeps its own onTap)
              ...widget.tags.map((tag) => Tag(
                  id: tag.id,
                  text: tag.name,
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
            if (widget.showLogo) ...[
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final highlight = _highlightFor(value);
                  // Ink by default (the gold strokes only light up in a
                  // category color while a suggestion highlights them), and
                  // a small inset so the hash fills the circle.
                  final logo =
                      HomlLogo(tint: highlight ?? ink, insetFactor: 0.08);
                  if (widget.onLogoTap == null) return logo;

                  // Button affordance: circular ripple on the logo plus a
                  // small chevron badge (tinted like the input border when a
                  // suggestion highlights it) telling it opens the picker.
                  return Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          widget.onLogoTap!(_controller.text.trim()),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          logo,
                          Positioned(
                            right: -3,
                            bottom: -3,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: highlight ?? ink,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.expand_more,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: RawAutocomplete<TagChipData>(
                textEditingController: _controller,
                focusNode: _focusNode,
                displayStringForOption: (option) => option.name,
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
                            return ListTile(
                              dense: true,
                              title: Text(option.name),
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
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ],
    );
  }
}
