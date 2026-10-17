import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/epg/data/compute/epg_compute.dart';
import 'package:novaiptv/features/epg/domain/entities/program.dart';
import 'package:novaiptv/features/playlist/domain/entities/channel.dart';

Channel channel(String id, {String? tvgId, int? tvgShift}) {
  return Channel(id: id, name: id, url: 'http://example.com/$id', playlistId: 'p1', tvgId: tvgId, tvgShift: tvgShift);
}

Program program(String channelId, DateTime start, DateTime end, {String title = 'Show'}) {
  return Program(id: '${channelId}_${start.millisecondsSinceEpoch}', channelId: channelId, title: title, start: start, end: end);
}

void main() {
  sportsEventSynthesisTests();

  final gridStart = DateTime(2026, 6, 11);
  final gridEnd = DateTime(2026, 6, 18);

  group('groupProgramsForGuide tvg-id collisions (MEDIUM-5)', () {
    test('every HD/SD variant sharing one tvg-id gets the programs', () {
      final channels = [
        channel('p1_hd', tvgId: 'news.one'),
        channel('p1_sd', tvgId: 'news.one'),
        channel('p1_fhd', tvgId: 'news.one'),
        channel('p1_other', tvgId: 'other.id'),
      ];
      final programs = [
        program('news.one', DateTime(2026, 6, 11, 12), DateTime(2026, 6, 11, 13)),
        program('news.one', DateTime(2026, 6, 11, 13), DateTime(2026, 6, 11, 14)),
        program('other.id', DateTime(2026, 6, 11, 12), DateTime(2026, 6, 11, 13)),
      ];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      expect(map['p1_hd'], hasLength(2));
      expect(map['p1_sd'], hasLength(2));
      expect(map['p1_fhd'], hasLength(2));
      expect(map['p1_other'], hasLength(1));
    });

    test('programs keyed by raw channel id still match', () {
      final channels = [channel('p1_abc')];
      final programs = [program('p1_abc', DateTime(2026, 6, 11, 12), DateTime(2026, 6, 11, 13))];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      expect(map['p1_abc'], hasLength(1));
    });

    test('per-channel lists are sorted by start time', () {
      final channels = [channel('p1_a', tvgId: 'a')];
      final programs = [
        program('a', DateTime(2026, 6, 11, 15), DateTime(2026, 6, 11, 16)),
        program('a', DateTime(2026, 6, 11, 12), DateTime(2026, 6, 11, 13)),
        program('a', DateTime(2026, 6, 11, 13), DateTime(2026, 6, 11, 15)),
      ];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      final starts = map['p1_a']!.map((p) => p.start).toList();
      expect(starts, [DateTime(2026, 6, 11, 12), DateTime(2026, 6, 11, 13), DateTime(2026, 6, 11, 15)]);
    });
  });

  group('groupProgramsForGuide tvg-shift (LOW-5)', () {
    test('shifts programme times by the channel tvg-shift hours', () {
      final channels = [
        channel('p1_base', tvgId: 'movie.ch'),
        channel('p1_plus1', tvgId: 'movie.ch', tvgShift: 1),
        channel('p1_minus2', tvgId: 'movie.ch', tvgShift: -2),
      ];
      final start = DateTime(2026, 6, 11, 20);
      final end = DateTime(2026, 6, 11, 22);
      final programs = [program('movie.ch', start, end)];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      expect(map['p1_base']!.single.start, start);
      expect(map['p1_plus1']!.single.start, start.add(const Duration(hours: 1)));
      expect(map['p1_plus1']!.single.end, end.add(const Duration(hours: 1)));
      expect(map['p1_minus2']!.single.start, start.subtract(const Duration(hours: 2)));
    });

    test('range filtering happens after the shift', () {
      // Program ends exactly at grid start: invisible on the base channel,
      // but the +1 variant shifts it into the window.
      final channels = [
        channel('p1_base', tvgId: 'movie.ch'),
        channel('p1_plus1', tvgId: 'movie.ch', tvgShift: 1),
      ];
      final programs = [program('movie.ch', gridStart.subtract(const Duration(hours: 1)), gridStart)];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      expect(map.containsKey('p1_base'), isFalse);
      expect(map['p1_plus1'], hasLength(1));
    });

    test('programs outside the window are excluded', () {
      final channels = [channel('p1_a', tvgId: 'a')];
      final programs = [
        program('a', gridEnd, gridEnd.add(const Duration(hours: 1))),
        program('a', gridStart.subtract(const Duration(hours: 2)), gridStart.subtract(const Duration(hours: 1))),
      ];

      final map = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

      expect(map, isEmpty);
    });
  });
}

/// Opt-in synthesis of guide cells from sports event-channel names. Uses the
/// exact provider format observed in the NFL group of a real playlist.
void sportsEventSynthesisTests() {
  final gridStart = DateTime(2026, 10, 16);
  final gridEnd = DateTime(2026, 10, 23);
  final reference = DateTime(2026, 10, 17, 12);

  Channel named(String id, String name, {String? tvgId}) {
    return Channel(id: id, name: name, url: 'http://example.com/$id', playlistId: 'p1', tvgId: tvgId, group: 'NFL');
  }

  final channels = [
    named('redzone', 'NFL RedZone', tvgId: 'nflredzone.us'),
    named('nfl03', 'NFL 03: Falcons vs Bears (10.18 1:00PM ET)'),
    named('nfl13', 'NFL 13: Packers vs Cowboys (10.18 8:20PM ET)'),
    named('nfl15', 'NFL 15: No Event Scheduled'),
    named('mls01', 'MLS 01: FC Cincinnati vs New England Revolution Oct 14 7:30 PM'),
  ];
  final feed = [
    program('nflredzone.us', DateTime.utc(2026, 10, 18, 17), DateTime.utc(2026, 10, 18, 23, 30), title: 'NFL RedZone'),
  ];

  group('groupProgramsForGuide sports event synthesis', () {
    test('disabled (default): event channels without EPG stay empty', () {
      final map = groupProgramsForGuide(GuideGroupArgs(programs: feed, channels: channels, startTime: gridStart, endTime: gridEnd));
      expect(map.keys, ['redzone']);
      expect(map['nfl03'], isNull);
      expect(map['nfl15'], isNull);
    });

    test('enabled: scheduled games get one synthetic cell, placeholders and unparsable names get none', () {
      final map = groupProgramsForGuide(GuideGroupArgs(programs: feed, channels: channels, startTime: gridStart, endTime: gridEnd, synthesizeSportsEvents: true, synthesisReference: reference));
      expect(map['redzone'], hasLength(1));
      expect(map['redzone']!.single.id, isNot(startsWith(syntheticSportsProgramIdPrefix)));

      final falcons = map['nfl03']!.single;
      expect(falcons.id, '${syntheticSportsProgramIdPrefix}nfl03');
      expect(falcons.channelId, 'nfl03');
      expect(falcons.title, 'Falcons vs Bears');
      expect(falcons.category, 'NFL');
      expect(falcons.start.toUtc(), DateTime.utc(2026, 10, 18, 17));
      expect(falcons.end.toUtc(), DateTime.utc(2026, 10, 18, 20));
      expect(falcons.isLive, isTrue);

      expect(map['nfl13']!.single.start.toUtc(), DateTime.utc(2026, 10, 19, 0, 20));
      expect(map['nfl15'], isNull, reason: 'No Event Scheduled must not become a programme');
      expect(map['mls01'], isNull, reason: 'no zone in the name, nothing is invented');
    });

    test('enabled: real EPG always wins over the name', () {
      final withFeed = [
        ...feed,
        program('nfl03', DateTime.utc(2026, 10, 18, 16), DateTime.utc(2026, 10, 18, 19, 30), title: 'From feed'),
      ];
      final map = groupProgramsForGuide(GuideGroupArgs(programs: withFeed, channels: channels, startTime: gridStart, endTime: gridEnd, synthesizeSportsEvents: true, synthesisReference: reference));
      expect(map['nfl03']!.single.title, 'From feed');
    });

    test('enabled: an entirely empty feed still yields synthetic cells', () {
      final map = groupProgramsForGuide(GuideGroupArgs(programs: const [], channels: channels, startTime: gridStart, endTime: gridEnd, synthesizeSportsEvents: true, synthesisReference: reference));
      expect(map.keys.toSet(), {'nfl03', 'nfl13'});
      expect(map['redzone'], isNull);
    });

    test('enabled: a kickoff outside the grid window is dropped', () {
      final map = groupProgramsForGuide(GuideGroupArgs(programs: feed, channels: channels, startTime: DateTime(2026, 10, 20), endTime: DateTime(2026, 10, 27), synthesizeSportsEvents: true, synthesisReference: reference));
      expect(map['nfl03'], isNull);
      expect(map['nfl13'], isNull);
    });
  });
}
