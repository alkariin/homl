import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_period.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Heading of a month in the event list: "October 2026", and how many events
/// start in it.
class MonthHeader extends StatelessWidget {
  final DateTime month;
  final int count;

  const MonthHeader({required this.month, required this.count, super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 0, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              // intl writes French month names in lowercase ("octobre
              // 2026"): a heading starts with a capital in every language.
              child: Text(
                toBeginningOfSentenceCase(
                    DateFormat.yMMMM(locale).format(month), locale),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              AppLocalizations.of(context)!.list_monthCount(count),
              style: TextStyle(
                  fontSize: 12, color: context.homl.ink.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

/// An event in the list: its day and weekday on the left, a dot on the rail
/// that joins the events of a month, and a card with the period, every tag
/// (wrapped, never cut) and two lines of description. A tap opens the detail
/// sheet. The month and year are in the heading above, so the date tags are
/// not chipped.
class EventRow extends StatelessWidget {
  static const double _dayWidth = 44;
  static const double _gap = 6;
  static const double _railWidth = 18;

  /// The dot sits level with the day number; the rail of a month starts at
  /// its first dot and ends at its last.
  static const double _dotTop = 16;
  static const double _dotSize = 10;
  static const double _railX = _dayWidth + _gap + _railWidth / 2;

  static const double _tagSpacing = 5;

  final Event event;

  /// First and last event of its month: where the rail starts and stops.
  final bool first;
  final bool last;

  /// Resolves a tag name to its category color (from HomeState.allTagsMap).
  final String? Function(String tagName) tagColorResolver;

  /// Tells whether a tag is one of the month/year date tags.
  final bool Function(Tag tag) isDateTag;

  /// Color of the dot: the event's first tag in a real category, like its
  /// bar on the timeline; null for the neutral grey.
  final String? dotColor;

  final VoidCallback? onTap;

  const EventRow(
      {required this.event,
      required this.first,
      required this.last,
      required this.tagColorResolver,
      required this.isDateTag,
      this.dotColor,
      this.onTap,
      super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final muted = context.homl.ink.withValues(alpha: 0.6);
    // A pastel dot would vanish on the light background: a quarter of the
    // way to black, which keeps its hue (a lightness darken saturates the
    // pastels into candy colors).
    final dot = dotColor == null
        ? context.homl.rule
        : Color.lerp(palette.colorFromHex(dotColor!), Colors.black, .25)!;
    const dotCenter = _dotTop + _dotSize / 2;

    return Stack(
      children: [
        if (!(first && last))
          Positioned(
            left: _railX - 1,
            width: 2,
            top: first ? dotCenter : 0,
            bottom: last ? null : 0,
            height: last ? dotCenter : null,
            child: ColoredBox(color: context.homl.quiet),
          ),
        Positioned(
          left: _railX - _dotSize / 2,
          top: _dotTop,
          child: Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _dayWidth,
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.d(locale).format(event.date),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat.E(locale).format(event.date).toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: _gap * 2 + _railWidth),
              Expanded(child: _card(context, locale, muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, String locale, Color muted) {
    final tags = event.tags.where((tag) => !isDateTag(tag)).toList();
    // The end on the same scale as the day column: its year only when it
    // is not the start's.
    final end = event.endDate;
    final endFormat = end != null && end.year == event.date.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    final period = periodLine(
        AppLocalizations.of(context)!, event, endFormat, DateTime.now());

    final sections = <Widget>[
      if (period != null)
        Text(
          period,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: muted),
        ),
      if (tags.isNotEmpty)
        Wrap(
          spacing: _tagSpacing,
          runSpacing: _tagSpacing,
          children: [
            for (final tag in tags)
              components.Tag(
                  id: tag.id, text: tag.tag, color: tagColorResolver(tag.tag)),
          ],
        ),
      if (event.description.isNotEmpty)
        Text(
          event.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, height: 1.38),
        ),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          sections[i],
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: context.homl.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.homl.hairline),
        boxShadow: [
          BoxShadow(
            color: context.homl.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // The Material/InkWell pair gives the tap a ripple over the card
      // decoration without hiding it.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
            child: event.isPending
                // Made offline, not on the server yet: a small clock in the
                // corner, the content kept clear of it.
                ? Stack(clipBehavior: Clip.none, children: [
                    Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: content),
                    Positioned(
                      top: -3,
                      right: -6,
                      child: Tooltip(
                        message: AppLocalizations.of(context)!.pending_waiting,
                        child: Icon(Icons.schedule, size: 14, color: muted),
                      ),
                    ),
                  ])
                : content,
          ),
        ),
      ),
    );
  }
}
