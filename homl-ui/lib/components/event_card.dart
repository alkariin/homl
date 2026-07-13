import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/tag.dart';
import 'package:homl/data/models/event.dart';

/// Event card: white, radius 15, soft shadow. Sized by its parent (grid
/// cell); overflowing tags/description are clipped or faded.
class EventCard extends StatelessWidget {
  final Event event;

  /// Resolves a tag name to its category color (from HomeState.allTagsMap).
  final String? Function(String tagName) tagColorResolver;

  final VoidCallback? onTap;

  const EventCard(
      {required this.event,
      required this.tagColorResolver,
      this.onTap,
      super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      // The Material/InkWell pair gives the tap a ripple over the white
      // decoration without hiding it.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _content(locale),
          ),
        ),
      ),
    );
  }

  Widget _content(String locale) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              DateFormat.yMMMd(locale).format(event.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          if (event.tags.isNotEmpty)
            // With a description the tags keep a single clipped row;
            // alone they fill the card.
            _tagsArea(
              singleRow: event.description.isNotEmpty,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: event.tags
                    .map((tag) => Tag(
                        id: tag.id,
                        text: tag.tag,
                        color: tagColorResolver(tag.tag)))
                    .toList(),
              ),
            ),
          if (event.description.isNotEmpty) ...[
            if (event.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                event.description,
                overflow: TextOverflow.fade,
                style: const TextStyle(fontSize: 12, height: 1.25),
              ),
            ),
          ],
        ],
    );
  }

  Widget _tagsArea({required bool singleRow, required Widget child}) {
    final clipped = ClipRect(
      child: Align(alignment: Alignment.topLeft, child: child),
    );
    if (singleRow) return SizedBox(height: 28, child: clipped);
    return Flexible(child: clipped);
  }
}
