import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:homl/components/settings_group.dart';
import 'package:homl/helpers/theme.dart';
import 'package:homl/l10n/app_localizations.dart';

/// The terms of use and the privacy policy, one card each (drawer, and the
/// notice under the sign-up button). Static text from the `legal_*` keys:
/// every HOML server is self-hosted, so the texts name "the operator of the
/// server" rather than a person (homl-ui/README.md, "Terms & privacy page").
class LegalPage extends StatelessWidget {
  /// The date the page shows as the last update: bump it with any change to
  /// the meaning of the `legal_*` texts.
  static final DateTime updated = DateTime(2026, 11, 16);

  /// Beyond this the lines get too long to read comfortably (web, tablets).
  static const double _maxWidth = 680;

  const LegalPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const LegalPage());
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;
    final date = DateFormat.yMMMMd(localization.localeName).format(updated);

    final terms = [
      (
        localization.legal_termsServiceTitle,
        localization.legal_termsServiceBody
      ),
      (
        localization.legal_termsOperatorTitle,
        localization.legal_termsOperatorBody
      ),
      (
        localization.legal_termsAccountTitle,
        localization.legal_termsAccountBody
      ),
      (localization.legal_termsUseTitle, localization.legal_termsUseBody),
      (
        localization.legal_termsContentTitle,
        localization.legal_termsContentBody
      ),
      (
        localization.legal_termsAvailabilityTitle,
        localization.legal_termsAvailabilityBody
      ),
      (
        localization.legal_termsLiabilityTitle,
        localization.legal_termsLiabilityBody
      ),
      (localization.legal_termsEndTitle, localization.legal_termsEndBody),
      (localization.legal_termsLawTitle, localization.legal_termsLawBody),
    ];
    final privacy = [
      (
        localization.legal_privacyControllerTitle,
        localization.legal_privacyControllerBody
      ),
      (localization.legal_privacyDataTitle, localization.legal_privacyDataBody),
      (
        localization.legal_privacyPurposesTitle,
        localization.legal_privacyPurposesBody
      ),
      (
        localization.legal_privacySecurityTitle,
        localization.legal_privacySecurityBody
      ),
      (
        localization.legal_privacyDeviceTitle,
        localization.legal_privacyDeviceBody
      ),
      (
        localization.legal_privacySharingTitle,
        localization.legal_privacySharingBody
      ),
      (
        localization.legal_privacyRetentionTitle,
        localization.legal_privacyRetentionBody
      ),
      (
        localization.legal_privacyRightsTitle,
        localization.legal_privacyRightsBody
      ),
      (
        localization.legal_privacyChangesTitle,
        localization.legal_privacyChangesBody
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.legal_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final side = ((constraints.maxWidth - _maxWidth) / 2)
            .clamp(16.0, double.infinity);
        // Selectable: a passage of a legal text is something people quote.
        return SelectionArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(side, 16, side, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  localization.legal_updated(date),
                  style: TextStyle(
                      fontSize: 13,
                      color: context.homl.ink.withValues(alpha: 0.5)),
                ),
              ),
              _LegalDocument(
                  heading: localization.legal_termsHeading, sections: terms),
              _LegalDocument(
                  heading: localization.legal_privacyHeading,
                  sections: privacy),
            ],
          ),
        );
      }),
    );
  }
}

/// One of the two texts: its heading, then its sections, in a card.
class _LegalDocument extends StatelessWidget {
  final String heading;
  final List<(String, String)> sections;

  const _LegalDocument({required this.heading, required this.sections});

  @override
  Widget build(BuildContext context) {
    // Full width: the card's column centres a row narrower than itself.
    return SettingsGroup(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Text(
          heading,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      for (final (title, body) in sections)
        _LegalSection(title: title, body: body),
    ]);
  }
}

/// A section: its title, then its text. A line of the text starting with
/// "• " is an item of a list, shown with a hanging indent.
class _LegalSection extends StatelessWidget {
  final String title;
  final String body;

  const _LegalSection({required this.title, required this.body});

  static const _bullet = '• ';

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: 14,
        height: 1.45,
        color: context.homl.ink.withValues(alpha: 0.78));

    final lines = body.split('\n');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: lines[i].startsWith(_bullet)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•', style: style),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(lines[i].substring(_bullet.length),
                                style: style)),
                      ],
                    )
                  : Text(lines[i], style: style),
            ),
        ],
      ),
    );
  }
}
