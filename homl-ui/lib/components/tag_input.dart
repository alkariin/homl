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

  const TagChipData({required this.id, required this.name, this.color});
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

  const TagInput(
      {required this.labelText,
      required this.tags,
      required this.suggestions,
      required this.onAddTag,
      this.onRemoveTag,
      this.leading,
      this.trailing,
      this.showLogo = false,
      super.key});

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
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

    return widget.suggestions.where((suggestion) =>
        suggestion.name.toLowerCase().contains(query) &&
        !widget.tags.any(
            (tag) => tag.name.toLowerCase() == suggestion.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading != null || widget.tags.isNotEmpty) ...[
          Wrap(
            spacing: 5,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.leading != null) widget.leading!,
              // A simple tap on a chip removes it (the date chip is the
              // [leading] widget and keeps its own onTap)
              ...widget.tags.map((tag) => Tag(
                  id: tag.id,
                  text: tag.name,
                  color: tag.color,
                  onTap: widget.onRemoveTag == null
                      ? null
                      : () => widget.onRemoveTag!(tag),
                  onDeleteTag: widget.onRemoveTag == null
                      ? null
                      : (_) => widget.onRemoveTag!(tag))),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (widget.showLogo) ...[
              const HomlLogo(),
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
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: widget.labelText,
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => value.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const FaIcon(
                                    FontAwesomeIcons.solidCircleXmark,
                                    size: 18,
                                    color: yellow),
                                onPressed: controller.clear,
                              ),
                      ),
                    ),
                    onFieldSubmitted: _submit,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(5),
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
