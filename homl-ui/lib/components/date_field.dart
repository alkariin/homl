import 'package:material_ui/material_ui.dart';

import 'package:homl/helpers/date_entry.dart';
import 'package:homl/helpers/theme.dart';

/// A date of the event form, written out in full ("dimanche 15 novembre
/// 2026") in a field dressed like the app's text inputs. It is not typed
/// into: a tap calls [onTap], which opens the date picker — whose pencil
/// still takes a typed date.
class DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const DateField(
      {required this.label,
      required this.date,
      required this.onTap,
      super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final ink = context.homl.ink;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(Icons.calendar_today_outlined,
                size: 20, color: ink.withValues(alpha: 0.55)),
          ),
          child: Text(
            fullDateLabel(date, locale),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, color: ink),
          ),
        ),
      ),
    );
  }
}
