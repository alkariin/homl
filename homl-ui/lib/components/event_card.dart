import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/tag.dart';
import 'package:homl/data/models/event.dart';

class EventCard extends StatelessWidget {
  final Event event;

  /// Resolves a tag name to its category color (from HomeState.allTagsMap).
  final String? Function(String tagName) tagColorResolver;

  const EventCard(
      {required this.event, required this.tagColorResolver, super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMd(locale).format(event.date),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(event.description),
            ],
            if (event.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: event.tags
                    .map((tag) => Tag(
                        id: tag.id,
                        text: tag.tag,
                        color: tagColorResolver(tag.tag)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
