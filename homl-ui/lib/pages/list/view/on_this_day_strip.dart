import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_period.dart';
import 'package:homl/helpers/on_this_day.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Inset of the panel's content from its edges.
const double _inset = 16;

/// "On this day": the events that started on today's date in earlier years,
/// in a gold-tinted panel above the event list. It shows one at a time — its
/// year and how long ago, then its period, tags and the start of its
/// description — and a swipe brings the next; the dots under the panel say
/// which one is shown. A tap opens the detail sheet.
class OnThisDayStrip extends StatefulWidget {
  /// Inset of the panel, aligned on the list.
  static const double sidePadding = 20;

  final List<Memory> memories;

  /// Resolves a tag name to its category color (from HomeState.allTagsMap).
  final String? Function(String tagName) tagColorResolver;

  /// Tells whether a tag is one of the month/year date tags: the year is
  /// printed beside the tags already, so they are left out.
  final bool Function(Tag tag) isDateTag;

  final void Function(Event event) onTap;

  /// The date in the header, and what an ongoing period is counted to.
  final DateTime today;

  const OnThisDayStrip(
      {required this.memories,
      required this.tagColorResolver,
      required this.isDateTag,
      required this.onTap,
      required this.today,
      super.key});

  @override
  State<OnThisDayStrip> createState() => _OnThisDayStripState();
}

class _OnThisDayStripState extends State<OnThisDayStrip> {
  final _pages = PageController();
  int _shown = 0;

  @override
  void didUpdateWidget(OnThisDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A memory deleted meanwhile: the pager settles on the last one left.
    if (_shown >= widget.memories.length) {
      _shown = widget.memories.length - 1;
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final memories = widget.memories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(
              horizontal: OnThisDayStrip.sidePadding),
          // The pages slide out at the panel's edges, not at its inset.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: palette.yellow.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(_inset, 14, _inset, 10),
                child: Row(children: [
                  const FaIcon(FontAwesomeIcons.clockRotateLeft,
                      size: 14, color: palette.yellow),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localization.list_onThisDay,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    DateFormat.MMMMd(locale).format(widget.today),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.homl.ink.withValues(alpha: 0.6)),
                  ),
                ]),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: _inset),
                color: palette.yellow.withValues(alpha: 0.28),
              ),
              SizedBox(
                height: _MemoryPage.heightOf(context),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: memories.length,
                  onPageChanged: (index) => setState(() => _shown = index),
                  itemBuilder: (context, index) => _MemoryPage(
                    memory: memories[index],
                    tagColorResolver: widget.tagColorResolver,
                    isDateTag: widget.isDateTag,
                    onTap: widget.onTap,
                    today: widget.today,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (memories.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Dots(count: memories.length, shown: _shown),
          ),
      ],
    );
  }
}

/// One memory of the panel, in the fixed height the pager needs: a period
/// line, one tag row and two lines of description — three lines without a
/// period. A second tag row is taken from the description; tags that still
/// do not fit are left out whole, never cut in half.
class _MemoryPage extends StatelessWidget {
  static const double _yearWidth = 60;
  static const double _padding = 11;
  static const double _gap = 6;
  static const double _tagSpacing = 5;
  static const double _descriptionFontSize = 13.5;
  static const double _descriptionLineHeight = 1.38;
  static const TextStyle _periodStyle =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

  final Memory memory;
  final String? Function(String tagName) tagColorResolver;
  final bool Function(Tag tag) isDateTag;
  final void Function(Event event) onTap;
  final DateTime today;

  const _MemoryPage(
      {required this.memory,
      required this.tagColorResolver,
      required this.isDateTag,
      required this.onTap,
      required this.today});

  static double _lineOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_descriptionFontSize) *
      _descriptionLineHeight;

  /// Laid-out height of the period line, under the ambient font and scale.
  static double _periodLineOf(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
          text: 'Hg',
          style: DefaultTextStyle.of(context).style.merge(_periodStyle)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }

  static double heightOf(BuildContext context) =>
      2 * _padding +
      _periodLineOf(context) +
      _gap +
      components.Tag.heightOf(context) +
      _gap +
      2 * _lineOf(context);

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final muted = context.homl.ink.withValues(alpha: 0.6);
    final event = memory.event;
    final tags = event.tags.where((tag) => !isDateTag(tag)).toList();
    // The end with its year only when it is not the start's, as in the list.
    final end = event.endDate;
    final endFormat = end != null && end.year == event.date.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    final period = periodLine(localization, event, endFormat, today);

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _yearWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.y(locale).format(event.date),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, height: 1.1),
              ),
              const SizedBox(height: 3),
              Text(
                localization.event_yearsAgo(memory.yearsAgo),
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (period != null) ...[
                Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _periodStyle.copyWith(color: muted),
                ),
                const SizedBox(height: _gap),
              ],
              // The tag rows and the description lines are sized against the
              // height actually left, hence the LayoutBuilder.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _tagsAndDescription(
                      context, constraints.maxHeight, tags),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // The Material/InkWell pair gives the tap a ripple over the panel's tint.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(event),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: _inset, vertical: _padding),
          child: event.isPending
              // Made offline, not on the server yet: a small clock in the
              // corner, the content kept clear of it.
              ? Stack(clipBehavior: Clip.none, children: [
                  Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: content),
                  Positioned(
                    top: 0,
                    right: -4,
                    child: Tooltip(
                      message: localization.pending_waiting,
                      child: Icon(Icons.schedule, size: 14, color: muted),
                    ),
                  ),
                ])
              : content,
        ),
      ),
    );
  }

  Widget _tagsAndDescription(
      BuildContext context, double available, List<Tag> tags) {
    final line = _lineOf(context);
    final description = memory.event.description;
    final rowHeight = components.Tag.heightOf(context);

    // Every whole tag row that fits once a line of description is set aside;
    // one row at least.
    final free = available - (description.isEmpty ? 0 : _gap + line);
    final rows = math.max(
        1, ((free + _tagSpacing) / (rowHeight + _tagSpacing)).floor());
    final tagsHeight = rows * rowHeight + (rows - 1) * _tagSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tags.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: tagsHeight),
            // The box is a whole number of rows, so a row that does not fit
            // is clipped away entirely. [heightFactor] keeps the box down to
            // the rows actually used, so a single row leaves the description
            // the rest.
            child: ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: 1,
                child: Wrap(
                  spacing: _tagSpacing,
                  runSpacing: _tagSpacing,
                  children: [
                    for (final tag in tags)
                      components.Tag(
                          id: tag.id,
                          text: tag.tag,
                          color: tagColorResolver(tag.tag)),
                  ],
                ),
              ),
            ),
          ),
        if (description.isNotEmpty) ...[
          if (tags.isNotEmpty) const SizedBox(height: _gap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Text(
                description,
                // The room is a whole number of lines by construction: the
                // margin keeps a rounding error from dropping one.
                maxLines: math.max(
                    1, (constraints.maxHeight / line + 0.01).floor()),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: _descriptionFontSize,
                    height: _descriptionLineHeight),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Which memory the panel shows: a gold dash for it, a dot for each other.
/// The pager itself tells a screen reader where it is.
class _Dots extends StatelessWidget {
  final int count;
  final int shown;

  const _Dots({required this.count, required this.shown});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == shown ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == shown
                    ? palette.yellow
                    : context.homl.ink.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
