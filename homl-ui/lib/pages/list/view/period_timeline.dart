import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_period.dart';
import 'package:homl/helpers/timeline.dart';

/// The Search tab's other view: the periods among the results, one row each
/// (newest first), on a shared axis of years that fits the screen width.
/// Slivers, so it scrolls in the page's CustomScrollView with the pull to
/// refresh; the axis stays pinned on top.
class PeriodTimeline extends StatelessWidget {
  /// Inset of the axis and the rows, aligned on the grid.
  static const double sidePadding = 20;

  /// Room a year label needs on the axis.
  static const double _tickSpacing = 52;

  final Timeline timeline;

  /// The render time: where the today line falls, how long an open period
  /// has lasted.
  final DateTime today;

  /// What a row is called (its tags, say); empty falls back to its dates.
  final String Function(Event event) labelOf;

  /// Category color ("#RRGGBB") of a row's bar; null draws it grey.
  final String? Function(Event event) colorOf;

  final void Function(Event event) onTap;

  const PeriodTimeline(
      {required this.timeline,
      required this.today,
      required this.labelOf,
      required this.colorOf,
      required this.onTap,
      super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final mutedInk = context.homl.ink.withValues(alpha: 0.55);

    if (timeline.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              localization.timeline_empty,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4, color: mutedInk),
            ),
          ),
        ),
      );
    }

    // The page spans the screen: its width, less the insets, is the axis.
    final axisWidth = MediaQuery.sizeOf(context).width - 2 * sidePadding;
    final maxTicks = math.max(1, (axisWidth / _tickSpacing).floor());
    final ticks = [
      for (final year in timeline.tickYears(maxTicks))
        (year, timeline.positionOf(DateTime.utc(year))),
    ];
    final todayPosition = timeline.positionOf(today);
    final todayLine =
        todayPosition >= 0 && todayPosition <= 1 ? todayPosition : null;
    final gridLines = [for (final (_, position) in ticks) position];

    return SliverMainAxisGroup(slivers: [
      SliverPersistentHeader(
        pinned: true,
        delegate: _AxisHeader(ticks: ticks, todayPosition: todayLine),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(sidePadding, 4, sidePadding, 12),
        sliver: SliverList.builder(
          itemCount: timeline.spans.length,
          itemBuilder: (context, index) {
            final span = timeline.spans[index];
            return _SpanRow(
              span: span,
              extent: timeline.extentOf(span),
              label: labelOf(span.event),
              color: colorOf(span.event),
              today: today,
              gridLines: gridLines,
              todayPosition: todayLine,
              onTap: () => onTap(span.event),
            );
          },
        ),
      ),
      if (timeline.singleDays > 0)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(sidePadding, 0, sidePadding, 25),
          sliver: SliverToBoxAdapter(
            child: Text(
              localization.timeline_singleDays(timeline.singleDays),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: mutedInk),
            ),
          ),
        ),
    ]);
  }
}

/// The pinned axis: a tick and its year at the start of each labelled year,
/// and a gold dot where today falls.
class _AxisHeader extends SliverPersistentHeaderDelegate {
  static const double _height = 30;

  final List<(int, double)> ticks;
  final double? todayPosition;

  const _AxisHeader({required this.ticks, required this.todayPosition});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final mutedInk = context.homl.ink.withValues(alpha: 0.55);

    return Container(
      // Opaque enough to read over the rows scrolling under it.
      color: context.homl.background.withValues(alpha: 0.94),
      padding:
          const EdgeInsets.symmetric(horizontal: PeriodTimeline.sidePadding),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
                height: 1, color: context.homl.ink.withValues(alpha: 0.12)),
          ),
          for (final (year, position) in ticks) ...[
            Positioned(
              left: position * width,
              bottom: 0,
              child: Container(
                  width: 1,
                  height: 6,
                  color: context.homl.ink.withValues(alpha: 0.3)),
            ),
            Positioned(
              // A label at the far right is pulled back inside the axis.
              left: math.min(position * width + 3, width - 30),
              bottom: 5,
              child: Text('$year',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: mutedInk)),
            ),
          ],
          if (todayPosition != null)
            Positioned(
              left: todayPosition! * width - 3,
              bottom: -3,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: palette.yellow, shape: BoxShape.circle),
              ),
            ),
        ]);
      }),
    );
  }

  @override
  bool shouldRebuild(_AxisHeader oldDelegate) =>
      oldDelegate.todayPosition != todayPosition ||
      !_sameTicks(oldDelegate.ticks, ticks);

  static bool _sameTicks(List<(int, double)> a, List<(int, double)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One period: what it is and how long it lasted, over its bar on the axis.
class _SpanRow extends StatelessWidget {
  static const double _barHeight = 12;

  /// Narrowest a bar gets, so a few days stay visible on a long axis.
  static const double _minBarWidth = 6;

  final TimelineSpan span;
  final (double, double) extent;
  final String label;
  final String? color;
  final DateTime today;
  final List<double> gridLines;
  final double? todayPosition;
  final VoidCallback onTap;

  const _SpanRow(
      {required this.span,
      required this.extent,
      required this.label,
      required this.color,
      required this.today,
      required this.gridLines,
      required this.todayPosition,
      required this.onTap});

  /// "3 years", or "for 2 years" while it goes on.
  String _length(AppLocalizations l10n) {
    if (!span.isOngoing) {
      return periodLengthLabel(l10n, periodLength(span.start, span.end));
    }
    final elapsed = ongoingLength(span.start, today);
    return elapsed == null ? l10n.event_ongoing : sinceLabel(l10n, elapsed);
  }

  /// "Mar 2019 – Aug 2021", for a period with neither tag nor description.
  String _dates(AppLocalizations l10n, String locale) {
    final format = DateFormat.yMMM(locale);
    final end = span.isOngoing ? l10n.event_ongoing : format.format(span.end);
    return '${format.format(span.start)} \u2013 $end';
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final base =
        color == null ? context.homl.rule : palette.colorFromHex(color!);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: CustomPaint(
        painter: _GridPainter(
            lines: gridLines,
            today: todayPosition,
            lineColor: context.homl.ink.withValues(alpha: 0.06)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    label.isEmpty ? _dates(localization, locale) : label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _length(localization),
                  style: TextStyle(
                      fontSize: 12,
                      color: context.homl.ink.withValues(alpha: 0.55)),
                ),
              ]),
              const SizedBox(height: 5),
              SizedBox(
                height: _barHeight,
                child: LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final (from, to) = extent;
                  final barWidth = math.min(
                      math.max((to - from) * width, _minBarWidth), width);
                  final left = math.min(from * width, width - barWidth);
                  return Stack(children: [
                    Positioned(
                      left: left,
                      width: barWidth,
                      top: 0,
                      bottom: 0,
                      child: _Bar(base: base, isOngoing: span.isOngoing),
                    ),
                  ]);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bar in the category color, hairlined like the chips. An open period
/// fades out on the right: it has not ended.
class _Bar extends StatelessWidget {
  final Color base;
  final bool isOngoing;

  const _Bar({required this.base, required this.isOngoing});

  @override
  Widget build(BuildContext context) {
    final fill = base.withValues(alpha: 0.75);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOngoing ? null : fill,
        gradient: isOngoing
            ? LinearGradient(
                colors: [fill, fill, fill.withValues(alpha: 0)],
                stops: const [0, 0.7, 1])
            : null,
        border: isOngoing
            ? null
            : Border.all(
                color: palette.darken(base, .3).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// The year lines through a row, and the gold today line, drawn behind it
/// so they run unbroken from one row to the next.
class _GridPainter extends CustomPainter {
  final List<double> lines;
  final double? today;

  /// The year lines' color: faint ink of the current brightness.
  final Color lineColor;

  const _GridPainter(
      {required this.lines, required this.today, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    for (final position in lines) {
      final x = position * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    if (today != null) {
      final x = today! * size.width;
      canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = palette.yellow.withValues(alpha: 0.7)
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.today != today ||
      oldDelegate.lines != lines ||
      oldDelegate.lineColor != lineColor;
}
