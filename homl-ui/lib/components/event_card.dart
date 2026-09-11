import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:homl/components/tag.dart' as components;
import 'package:homl/data/models/event.dart';
import 'package:homl/data/models/tag.dart';
import 'package:homl/helpers/colors.dart' as palette;
import 'package:homl/helpers/event_period.dart';
import 'package:homl/l10n/app_localizations.dart';

/// Event card: white, radius 16, hairline border and soft shadow. Sized by
/// its parent (grid cell); the tags take the rows they can get and the
/// description fades out at the bottom.
class EventCard extends StatelessWidget {
  /// Gap between two chips, horizontally and between two rows.
  static const double _tagSpacing = 5;

  /// Separator between the tags and the description: the hairline plus its
  /// two gaps. Its height is fixed here because the tag rows are computed
  /// from the space left once it is taken out.
  static const double _dividerHeight = 1;
  static const double _separatorHeight = 10 + _dividerHeight + 8;

  static const double _descriptionFontSize = 12;
  static const double _descriptionLineHeight = 1.25;

  final Event event;

  /// Resolves a tag name to its category color (from HomeState.allTagsMap).
  final String? Function(String tagName) tagColorResolver;

  /// Tells whether a tag is one of the month/year date tags. Those only
  /// repeat the date already printed at the top of the card, so they are
  /// left out of the chips.
  final bool Function(Tag tag) isDateTag;

  final VoidCallback? onTap;

  const EventCard(
      {required this.event,
      required this.tagColorResolver,
      required this.isDateTag,
      this.onTap,
      super.key});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final badge = _badgeText(AppLocalizations.of(context)!);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // The Material/InkWell pair gives the tap a ripple over the white
      // decoration without hiding it.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _content(locale, badge),
          ),
        ),
      ),
    );
  }

  /// Text of the period pill next to the date: how long a closed period
  /// lasted, "ongoing" for an open one, nothing for a single day — the
  /// majority of events keep looking exactly as they did.
  String? _badgeText(AppLocalizations l10n) {
    final end = event.endDate;
    if (end != null) {
      return periodLengthLabel(l10n, periodLength(event.date, end));
    }
    if (event.isOngoing) return l10n.event_ongoing;
    return null;
  }

  Widget _content(String locale, String? badge) {
    final tags = event.tags.where((tag) => !isDateTag(tag)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The header is the start date. A period adds a quiet pill under it
        // rather than a range the line has no room for — and under, not next
        // to it: on a phone-width cell the date alone takes most of the line,
        // so a pill beside it would truncate the date on every period card.
        // The rows below are sized from the height actually left, so the
        // extra line costs at most a tag row on a short card.
        Center(
          child: Text(
            DateFormat.yMMMd(locale).format(event.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (badge != null) ...[
          const SizedBox(height: 4),
          Center(child: _PeriodBadge(badge)),
        ],
        const SizedBox(height: 10),
        // The tag rows are sized against the height actually left under the
        // date, hence the LayoutBuilder.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _tagsAndDescription(context, constraints, tags),
          ),
        ),
      ],
    );
  }

  Widget _tagsAndDescription(
      BuildContext context, BoxConstraints constraints, List<Tag> tags) {
    final hasDescription = event.description.isNotEmpty;
    final tagsHeight = hasDescription
        ? _tagsHeight(context, constraints.maxHeight)
        : constraints.maxHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: tagsHeight),
            // The box is a whole number of rows, so a row that does not fit
            // is clipped away entirely (never half a chip) and its tags are
            // simply not shown. [heightFactor] keeps the box down to the
            // rows actually used, so a single row does not push the
            // description away.
            child: ClipRect(
              child: Align(
                alignment: Alignment.topLeft,
                heightFactor: 1,
                child: Wrap(
                  spacing: _tagSpacing,
                  runSpacing: _tagSpacing,
                  children: tags
                      .map((tag) => components.Tag(
                          id: tag.id,
                          text: tag.tag,
                          color: tagColorResolver(tag.tag)))
                      .toList(),
                ),
              ),
            ),
          ),
        if (hasDescription) ...[
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: _dividerHeight),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Text(
              event.description,
              overflow: TextOverflow.fade,
              style: const TextStyle(
                  fontSize: _descriptionFontSize,
                  height: _descriptionLineHeight),
            ),
          ),
        ],
      ],
    );
  }

  /// Height given to the tags when there is a description: every whole row
  /// that fits once the separator and one line of description are set aside.
  /// The description slides down to make room for a second row, but it is
  /// never hidden — at worst it ends up flush with the bottom of the card.
  /// A single row is always granted, even on a card too short for it.
  double _tagsHeight(BuildContext context, double available) {
    final rowHeight = components.Tag.heightOf(context);
    final descriptionLine =
        MediaQuery.textScalerOf(context).scale(_descriptionFontSize) *
            _descriptionLineHeight;

    final free = available - _separatorHeight - descriptionLine;
    // n rows take n * rowHeight plus the (n - 1) gaps between them.
    final rows = ((free + _tagSpacing) / (rowHeight + _tagSpacing)).floor();

    return rows < 1 ? rowHeight : rows * rowHeight + (rows - 1) * _tagSpacing;
  }
}

/// The period pill of the card header. Deliberately not a [components.Tag]:
/// it is not a tag and must not read as one — no category colour, no
/// calendar icon, a muted capsule in the ink of the text.
class _PeriodBadge extends StatelessWidget {
  final String text;

  const _PeriodBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: palette.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.ink.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
