import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novaiptv/features/epg/data/compute/epg_compute.dart';
import 'package:novaiptv/features/epg/data/datasources/epg_local_data_source.dart';
import 'package:novaiptv/features/playlist/data/datasources/playlist_local_data_source.dart';

import 'support/populated_fixtures.dart';

/// Populated M3U + XMLTV round trip through the production repositories and
/// Hive, then the TV Guide grouping.
///
/// Real providers routinely disagree on tvg-id casing between the M3U
/// ("BBC.One", "CNN.us") and the XMLTV feed ("bbc.one", "cnn.us"). Every
/// Hive read path (program indexes, current-program map used by the channel
/// list and favorites) already matches case-insensitively, so those views
/// show programme data. The guide grid must agree with them: a row that
/// says "No program data" while the channel list shows the airing show is
/// the misrender this test pins down.
void main() {
  late Directory dir;
  late String playlistId;
  final now = DateTime.now();

  setUp(() async {
    dir = await initTestHive();
    playlistId = await persistPopulatedFixture(now);
    await simulateRelaunch();
  });

  tearDown(() async {
    await disposeTestHive(dir);
  });

  test('persisted playlist, channels and programs survive a relaunch intact', () async {
    final playlist = await PlaylistLocalDataSourceImpl().getPlaylist(playlistId);
    expect(playlist, isNotNull);
    expect(playlist!.epgUrl, 'http://example.com/epg.xml.gz');
    expect(playlist.channelCount, 6);

    final channels = await PlaylistLocalDataSourceImpl().getChannels(playlistId);
    expect(channels, hasLength(6));
    expect(channels.map((c) => c.group).toSet(), {'UK, News', 'USA', 'Sports'});
    expect(channels.firstWhere((c) => c.name == 'CNN').channelNumber, 7);
    expect(channels.firstWhere((c) => c.name == 'BBC One +1').tvgShift, 1);

    final programs = await EpgLocalDataSourceImpl().getProgramsInRange(
      playlistId,
      now.subtract(const Duration(days: 1)),
      now.add(const Duration(days: 6)),
    );
    expect(programs, hasLength(4));
  });

  test('channel list lookup (case-insensitive) finds the airing programme for mixed-case tvg-ids', () async {
    final channels = (await PlaylistLocalDataSourceImpl().getAllChannels()).map((m) => m.toEntity()).toList();
    final epg = EpgLocalDataSourceImpl();
    for (final name in ['BBC One HD', 'BBC One SD', 'BBC One +1', 'CNN', 'ESPN']) {
      final channel = channels.firstWhere((c) => c.displayName == name);
      final current = await epg.getCurrentProgram(playlistId, channel.epgId);
      expect(current, isNotNull, reason: '$name should have an airing programme via the indexed read path');
    }
  });

  test('TV Guide grouping agrees with the channel list for mixed-case tvg-ids and keeps tvg-shift', () async {
    final channels = (await PlaylistLocalDataSourceImpl().getAllChannels()).map((m) => m.toEntity()).toList();
    final gridStart = DateTime(now.year, now.month, now.day);
    final gridEnd = gridStart.add(const Duration(days: 7));
    final programs = await EpgLocalDataSourceImpl().getProgramsInRange(playlistId, gridStart, gridEnd);

    final grouped = groupProgramsForGuide(GuideGroupArgs(programs: programs, channels: channels, startTime: gridStart, endTime: gridEnd));

    final byName = {for (final c in channels) c.displayName: c};
    expect(grouped[byName['BBC One HD']!.id]?.map((p) => p.title), containsAll(['BBC News at Six', 'EastEnders']));
    expect(grouped[byName['BBC One SD']!.id]?.map((p) => p.title), containsAll(['BBC News at Six', 'EastEnders']));
    expect(grouped[byName['CNN']!.id]?.single.title, 'CNN Newsroom');
    expect(grouped[byName['ESPN']!.id]?.single.title, 'SportsCenter');
    expect(grouped.containsKey(byName['No EPG Channel']!.id), isFalse);

    // The +1 variant uses a differently-cased tvg-id ("BBC.ONE") AND a
    // tvg-shift; normalising the id must not drop the per-channel shift.
    final base = grouped[byName['BBC One HD']!.id]!;
    final shifted = grouped[byName['BBC One +1']!.id];
    expect(shifted, isNotNull);
    expect(shifted!.map((p) => p.title), base.map((p) => p.title));
    for (var i = 0; i < base.length; i++) {
      expect(shifted[i].start, base[i].start.add(const Duration(hours: 1)));
      expect(shifted[i].end, base[i].end.add(const Duration(hours: 1)));
    }
  });
}
