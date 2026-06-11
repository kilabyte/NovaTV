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
