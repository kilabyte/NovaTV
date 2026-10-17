import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/epg/data/parsers/sports_event_name_parser.dart';

/// Names copied verbatim from a real provider playlist (October 2026 week).
const nflEventNames = <String>[
  'NFL 01: Broncos vs Seahawks (10.15 8:15PM ET)',
  'NFL 02: Jaguars vs Texans (10.18 9:30AM ET)',
  'NFL 03: Falcons vs Bears (10.18 1:00PM ET)',
  'NFL 04: Browns vs Ravens (10.18 1:00PM ET)',
  'NFL 05: Colts vs Titans (10.18 1:00PM ET)',
  'NFL 06: Patriots vs Jets (10.18 1:00PM ET)',
  'NFL 07: Giants vs Saints (10.18 1:00PM ET)',
  'NFL 08: Eagles vs Panthers (10.18 1:00PM ET)',
  'NFL 09: Buccaneers vs Steelers (10.18 1:00PM ET)',
  'NFL 10: Rams vs Cardinals (10.18 4:05PM ET)',
  'NFL 11: Chiefs vs Chargers (10.18 4:25PM ET)',
  'NFL 12: Raiders vs Bills (10.18 4:25PM ET)',
  'NFL 13: Packers vs Cowboys (10.18 8:20PM ET)',
  'NFL 14: 49ers vs Commanders (10.19 8:15PM ET)',
];

void main() {
  final parser = SportsEventNameParser();
  final reference = DateTime(2026, 10, 17); // Saturday the guide was viewed

  group('SportsEventNameParser real NFL names', () {
    test('all 14 scheduled games parse with a kickoff', () {
      for (final name in nflEventNames) {
        final info = parser.parse(name, reference: reference);
        expect(info, isNotNull, reason: name);
        expect(info!.hasKickoff, isTrue, reason: name);
        expect(info.isNoEvent, isFalse, reason: name);
        expect(info.league, 'NFL');
        expect(info.zone, 'ET');
        expect(info.title, isNot(contains('(')));
      }
    });

    test('kickoff is interpreted as US Eastern with DST (EDT = UTC-4 in October)', () {
      final info = parser.parse('NFL 03: Falcons vs Bears (10.18 1:00PM ET)', reference: reference)!;
      expect(info.start!.toUtc(), DateTime.utc(2026, 10, 18, 17, 0));
      expect(info.end!.toUtc(), DateTime.utc(2026, 10, 18, 20, 0));
      expect(info.title, 'Falcons vs Bears');
      expect(info.slot, 3);
    });

    test('AM, late-evening and odd-minute kickoffs', () {
      expect(parser.parse(nflEventNames[1], reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 13, 30));
      expect(parser.parse(nflEventNames[12], reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 19, 0, 20));
      expect(parser.parse(nflEventNames[10], reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 20, 25));
      expect(parser.parse(nflEventNames[0], reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 16, 0, 15));
    });

    test('"No Event Scheduled" slots are placeholders, never a programme', () {
      for (final name in ['NFL 15: No Event Scheduled', 'NFL 16: No Event Scheduled']) {
        final info = parser.parse(name, reference: reference);
        expect(info, isNotNull);
        expect(info!.isNoEvent, isTrue);
        expect(info.hasKickoff, isFalse);
        expect(info.start, isNull);
      }
    });
  });

  group('SportsEventNameParser other leagues and rejects', () {
    test('NHL names with a feed tag parse, keeping the tag in the title', () {
      final info = parser.parse('NHL 01: Buffalo Sabres @ Toronto Maple Leafs [Maple Leafs Feed] (10.15 7:00PM ET)', reference: reference)!;
      expect(info.league, 'NHL');
      expect(info.title, 'Buffalo Sabres @ Toronto Maple Leafs [Maple Leafs Feed]');
      expect(info.start!.toUtc(), DateTime.utc(2026, 10, 15, 23, 0));
    });

    test('PPV names parse', () {
      final info = parser.parse('PPV 01: Money in the Bank 2026 (10.10 3:00PM ET)', reference: reference)!;
      expect(info.league, 'PPV');
      expect(info.start!.toUtc(), DateTime.utc(2026, 10, 10, 19, 0));
    });

    test('MLS format without a zone is not parsed (nothing is invented)', () {
      expect(parser.parse('MLS 01: FC Cincinnati vs New England Revolution Oct 14 7:30 PM', reference: reference), isNull);
    });

    test('ordinary channel names are not parsed', () {
      expect(parser.parse('NFL Network', reference: reference), isNull);
      expect(parser.parse('NFL RedZone', reference: reference), isNull);
      expect(parser.parse('ESPN', reference: reference), isNull);
      expect(parser.parse('BBC One (10.18 1:00PM ET)', reference: reference), isNull);
    });

    test('unknown zone or impossible date is rejected', () {
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM XYZ)', reference: reference), isNull);
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM AST)', reference: reference), isNull, reason: 'ambiguous zone is rejected');
      expect(parser.parse('NFL 01: A vs B (02.30 1:00PM ET)', reference: reference), isNull);
      expect(parser.parse('NFL 01: A vs B (13.01 1:00PM ET)', reference: reference), isNull);
    });
  });

  group('SportsEventNameParser zones and year resolution', () {
    test('explicit standard/daylight zones are fixed offsets', () {
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM EST)', reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 18, 0));
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM EDT)', reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 17, 0));
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM PT)', reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 20, 0));
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM UTC)', reference: reference)!.start!.toUtc(), DateTime.utc(2026, 10, 18, 13, 0));
    });

    test('ET falls back to standard time after the first Sunday of November', () {
      // 2026: DST ends Sunday Nov 1 at 02:00 local.
      expect(parser.parse('NFL 01: A vs B (11.01 1:00AM ET)', reference: DateTime(2026, 10, 31))!.start!.toUtc(), DateTime.utc(2026, 11, 1, 5, 0));
      expect(parser.parse('NFL 01: A vs B (11.01 1:00PM ET)', reference: DateTime(2026, 10, 31))!.start!.toUtc(), DateTime.utc(2026, 11, 1, 18, 0));
      expect(parser.parse('NFL 01: A vs B (03.08 1:00PM ET)', reference: DateTime(2026, 3, 7))!.start!.toUtc(), DateTime.utc(2026, 3, 8, 17, 0));
    });

    test('month/day resolves to the year nearest the reference', () {
      expect(parser.parse('NFL 01: A vs B (01.04 1:00PM ET)', reference: DateTime(2026, 12, 30))!.start!.year, 2027);
      expect(parser.parse('NFL 01: A vs B (12.28 1:00PM ET)', reference: DateTime(2027, 1, 2))!.start!.year, 2026);
      expect(parser.parse('NFL 01: A vs B (10.18 1:00PM ET)', reference: reference)!.start!.year, 2026);
    });

    test('Feb 29 is accepted only when the resolved year is a leap year', () {
      expect(parser.parse('NFL 01: A vs B (02.29 1:00PM ET)', reference: DateTime(2027, 12, 30))!.start!.year, 2028);
      expect(parser.parse('NFL 01: A vs B (02.29 1:00PM ET)', reference: DateTime(2027, 3, 1)), isNull);
    });
  });
}
