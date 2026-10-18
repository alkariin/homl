import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/on_this_day.dart';

/// "On this day": the events that started on today's date in earlier years,
/// in a horizontal strip above the search grid. Each card is the grid's own
/// card (built by [cardBuilder], so a tap opens the same detail sheet) under
/// how many years ago it was.
class OnThisDayStrip extends StatelessWidget {
  /// Size of a strip card: a phone-width grid cell, a little shorter so the
  /// strip leaves room for the grid below it.
  static const double cardWidth = 150;
  static const double cardHeight = 150;

  /// Inset of the title and the first card, aligned on the grid.
  static const double sidePadding = 20;

  final List<Memory> memories;
  final Widget Function(Event event) cardBuilder;

  const OnThisDayStrip(
      {required this.memories, required this.cardBuilder, super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final mutedInk = context.homl.ink.withValues(alpha: 0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Row(children: [
            const FaIcon(FontAwesomeIcons.clockRotateLeft,
                size: 14, color: palette.yellow),
            const SizedBox(width: 8),
            Text(
              localization.list_onThisDay,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          // The label line above each card, then the card.
          height: 20 + cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: sidePadding),
            // The cards cast their soft shadow outside their bounds.
            clipBehavior: Clip.none,
            itemCount: memories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final memory = memories[index];
              return SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 20,
                      child: Text(
                        localization.event_yearsAgo(memory.yearsAgo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mutedInk),
                      ),
                    ),
                    SizedBox(
                      height: cardHeight,
                      child: cardBuilder(memory.event),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
