import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/data/models/event.dart';
import 'package:homl/helpers/activity.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_search.dart';

/// The days a search's results took place on, GitHub style: a column per
/// week, a square per day, the darker the more events that day. The last
/// twelve months by default, or any year with results; it scrolls sideways
/// from the most recent week. A tap on a day narrows the search to it.
class ActivityCalendar extends StatefulWidget {
  /// Side of a day square, and the gap between two.
  static const double cell = 11;
  static const double gap = 2;

  /// The results the calendar shows, before any day range narrowed them:
  /// picking a day must not empty the calendar it was picked in.
  final List<Event> events;

  final DateTime today;

  /// The category color ("#RRGGBB") of the searched tag; null keeps the
  /// app's gold (a text search, an Others tag).
  final String? color;

  /// The day range set on the search, outlined.
  final DayRange? selected;

  final void Function(DateTime day) onDayTap;

  const ActivityCalendar(
      {required this.events,
      required this.today,
      required this.color,
      required this.selected,
      required this.onDayTap,
      super.key});

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  /// The year shown; null for the last twelve months.
  int? _year;

  static const double _step = ActivityCalendar.cell + ActivityCalendar.gap;

  Color _shade(int level) {
    if (level == 0) return context.homl.ink.withValues(alpha: 0.06);
    final base = widget.color == null
        ? palette.yellow
        : palette.darken(palette.colorFromHex(widget.color!), .1);
    return base.withValues(alpha: const [0.0, 0.35, 0.55, 0.78, 1.0][level]);
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final muted = context.homl.ink.withValues(alpha: 0.55);
    final labelStyle = TextStyle(fontSize: 10.5, color: muted);

    final years = activeYears(widget.events, widget.today);
    // A year the search no longer has: back to the last twelve months.
    final year = years.contains(_year) ? _year : null;
    final window = year == null
        ? ActivityWindow.lastYear(widget.today)
        : ActivityWindow.year(year, widget.today);
    final counts = dailyActivity(widget.events, window, widget.today);
    final dayFormat = DateFormat.yMMMEd(locale);
    final monthFormat = DateFormat.MMM(locale);
    final weekdayFormat = DateFormat.E(locale);

    Widget square(DateTime day) {
      final count = counts[day] ?? 0;
      final selected = widget.selected != null &&
          !day.isBefore(widget.selected!.first) &&
          !day.isAfter(widget.selected!.last);
      return Tooltip(
        message: localization.activity_day(count, dayFormat.format(day)),
        child: GestureDetector(
          onTap: () => widget.onDayTap(day),
          child: Container(
            width: ActivityCalendar.cell,
            height: ActivityCalendar.cell,
            decoration: BoxDecoration(
              color: _shade(activityLevel(count)),
              borderRadius: BorderRadius.circular(2.5),
              border: selected
                  ? Border.all(color: context.homl.ink, width: 1.2)
                  : null,
            ),
          ),
        ),
      );
    }

    final grid = SizedBox(
      width: window.weeks * _step,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A month's name over the week holding its first day.
          SizedBox(
            height: 16,
            child: Stack(clipBehavior: Clip.none, children: [
              for (var week = 0; week < window.weeks; week++)
                for (var weekday = 0; weekday < 7; weekday++)
                  if (window.dayAt(week, weekday) case final day
                      when day.day == 1 && window.contains(day))
                    Positioned(
                      left: week * _step,
                      top: 0,
                      child: Text(monthFormat.format(day), style: labelStyle),
                    ),
            ]),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var week = 0; week < window.weeks; week++)
                Padding(
                  padding: const EdgeInsets.only(right: ActivityCalendar.gap),
                  child: Column(children: [
                    for (var weekday = 0; weekday < 7; weekday++)
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: ActivityCalendar.gap),
                        child: window.contains(window.dayAt(week, weekday))
                            ? square(window.dayAt(week, weekday))
                            : const SizedBox(
                                width: ActivityCalendar.cell,
                                height: ActivityCalendar.cell),
                      ),
                  ]),
                ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(localization.activity_title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          PopupMenuButton<int?>(
            tooltip: localization.activity_pickYear,
            initialValue: year,
            onSelected: (picked) => setState(() => _year = picked),
            itemBuilder: (context) => [
              PopupMenuItem<int?>(
                  value: null, child: Text(localization.activity_lastYear)),
              for (final option in years)
                PopupMenuItem<int?>(value: option, child: Text('$option')),
            ],
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(year == null ? localization.activity_lastYear : '$year',
                  style: TextStyle(fontSize: 13, color: muted)),
              Icon(Icons.arrow_drop_down, size: 18, color: muted),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monday, Wednesday and Friday name their rows, as on GitHub.
            Padding(
              padding: const EdgeInsets.only(top: 16, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    SizedBox(
                      height: _step,
                      child: weekday.isEven && weekday < 6
                          ? Text(weekdayFormat.format(window.dayAt(0, weekday)),
                              style: labelStyle)
                          : null,
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // The most recent week shows first, on the right.
                reverse: true,
                child: grid,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(localization.activity_less, style: labelStyle),
            for (var level = 0; level <= 4; level++)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  width: ActivityCalendar.cell,
                  height: ActivityCalendar.cell,
                  decoration: BoxDecoration(
                      color: _shade(level),
                      borderRadius: BorderRadius.circular(2.5)),
                ),
              ),
            const SizedBox(width: 4),
            Text(localization.activity_more, style: labelStyle),
          ],
        ),
      ],
    );
  }
}
