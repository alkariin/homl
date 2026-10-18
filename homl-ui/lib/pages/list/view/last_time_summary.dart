import 'package:material_ui/material_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_period.dart';
import 'package:homl/helpers/last_time.dart';

/// "Last time": two lines over the results of a search — how long ago it
/// last happened (and the day), then how often:
///
///     Last time: 14 months ago · Aug 12, 2025
///     23 events · 6 this year
class LastTimeSummary extends StatelessWidget {
  final LastTime lastTime;

  /// The day "ago" counts to; the caller passes the render time.
  final DateTime today;

  const LastTimeSummary(
      {required this.lastTime, required this.today, super.key});

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final mutedInk = context.homl.ink.withValues(alpha: 0.65);
    final lastDay = lastTime.lastDay;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: FaIcon(FontAwesomeIcons.clockRotateLeft,
              size: 14, color: palette.yellow),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    TextSpan(text: '${localization.list_lastTime} '),
                    TextSpan(
                      text: lastDay == null
                          ? localization.list_lastTimeNow
                          : agoLabel(localization, lastDay, today),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (lastDay != null)
                      TextSpan(
                        text: ' · ${DateFormat.yMMMd(locale).format(lastDay)}',
                        style: TextStyle(color: mutedInk),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${localization.list_eventCount(lastTime.total)}'
                ' · ${localization.list_thisYearCount(lastTime.thisYear)}',
                style: TextStyle(fontSize: 13, color: mutedInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
