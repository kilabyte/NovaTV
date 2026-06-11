import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:novaiptv/core/storage/channel_id_migration.dart';
import 'package:novaiptv/features/playlist/data/models/channel_model.dart';
import 'package:novaiptv/features/playlist/data/parsers/m3u_parser.dart';

ChannelModel channel({
  required String id,
  required String name,
  required String url,
  String playlistId = 'pl1',
  String? tvgId,
  String? group,
  bool isFavorite = false,
}) {
  return ChannelModel(id: id, name: name, url: url, playlistId: playlistId, tvgId: tvgId, group: group, isFavorite: isFavorite);
}

String stableId({
  required String url,
  required String name,
  String playlistId = 'pl1',
  String? tvgId,
  String? group,
}) {
  return M3UParser.stableChannelId(playlistId: playlistId, url: url, tvgId: tvgId, name: name, group: group);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novatv_migration_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChannelModelAdapter());
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<Box<ChannelModel>> seedChannels(List<ChannelModel> channels) async {
    final box = await Hive.openBox<ChannelModel>('channels');
    for (final c in channels) {
      await box.put(c.id, c);
    }
    return box;
  }

  Future<Box<dynamic>> seedRecentlyWatched(List<String> ids) async {
    final box = await Hive.openBox<dynamic>('recently_watched');
    await box.put('channel_ids', ids);
    return box;
  }

  test('re-keys legacy IDs, preserves favorites and remaps recently watched', () async {
    final box = await seedChannels([
      channel(id: 'pl1_0', name: 'News', url: 'http://x/news', tvgId: 'news.id', group: 'USA', isFavorite: true),
      channel(id: 'pl1_1', name: 'Sports', url: 'http://x/sports'),
    ]);
    final recentBox = await seedRecentlyWatched(['pl1_1', 'pl1_0', 'unrelated_id']);

    await ChannelIdMigration.run();

    final newsId = stableId(url: 'http://x/news', name: 'News', tvgId: 'news.id', group: 'USA');
    final sportsId = stableId(url: 'http://x/sports', name: 'Sports');

    expect(box.get('pl1_0'), isNull);
    expect(box.get('pl1_1'), isNull);
    expect(box.get(newsId)!.isFavorite, isTrue);
    expect(box.get(newsId)!.name, 'News');
    expect(box.get(sportsId)!.isFavorite, isFalse);
    expect(recentBox.get('channel_ids'), [sportsId, newsId, 'unrelated_id']);
  });

  test('is idempotent: second run changes nothing and the flag short-circuits', () async {
    final box = await seedChannels([
      channel(id: 'pl1_0', name: 'News', url: 'http://x/news', isFavorite: true),
    ]);
    await seedRecentlyWatched(['pl1_0']);

    await ChannelIdMigration.run();
    final firstPass = {for (final k in box.keys) k: box.get(k)!.isFavorite};

    await ChannelIdMigration.run();
    final secondPass = {for (final k in box.keys) k: box.get(k)!.isFavorite};

    expect(secondPass, firstPass);
    final migrations = await Hive.openBox<dynamic>('migrations');
    expect(migrations.get('stable_channel_ids_v1'), isTrue);
  });

  test('mixed box: new-format records are untouched, only legacy records move', () async {
    final existingNewId = stableId(url: 'http://x/movies', name: 'Movies');
    final box = await seedChannels([
      channel(id: existingNewId, name: 'Movies', url: 'http://x/movies', isFavorite: true),
      channel(id: 'pl1_3', name: 'Kids', url: 'http://x/kids'),
    ]);

    await ChannelIdMigration.run();

    final kidsId = stableId(url: 'http://x/kids', name: 'Kids');
    expect(box.length, 2);
    expect(box.get(existingNewId)!.isFavorite, isTrue);
    expect(box.get('pl1_3'), isNull);
    expect(box.get(kidsId), isNotNull);
  });

  test('identical duplicate legacy entries get suffixes in file order', () async {
    final box = await seedChannels([
      channel(id: 'pl1_7', name: 'Dup', url: 'http://x/dup', isFavorite: true),
      channel(id: 'pl1_2', name: 'Dup', url: 'http://x/dup'),
    ]);

    await ChannelIdMigration.run();

    final baseId = stableId(url: 'http://x/dup', name: 'Dup');
    // pl1_2 came first in the original file, so it takes the base ID, the
    // later pl1_7 (the favorite) gets the _1 suffix, matching a fresh parse.
    expect(box.get(baseId)!.isFavorite, isFalse);
    expect(box.get('${baseId}_1')!.isFavorite, isTrue);
    expect(box.get('pl1_2'), isNull);
    expect(box.get('pl1_7'), isNull);
  });

  test('interrupted run resumes without duplicating records or losing favorites', () async {
    final newId = stableId(url: 'http://x/news', name: 'News');
    // Simulate a crash after put(new) but before delete(old): both copies
    // exist, the new copy missed a favorite toggle, and no flag was written.
    final box = await seedChannels([
      channel(id: 'pl1_0', name: 'News', url: 'http://x/news', isFavorite: true),
      channel(id: newId, name: 'News', url: 'http://x/news', isFavorite: false),
      channel(id: 'pl1_1', name: 'Sports', url: 'http://x/sports'),
    ]);

    await ChannelIdMigration.run();

    expect(box.length, 2);
    expect(box.get('pl1_0'), isNull);
    expect(box.get(newId)!.isFavorite, isTrue);
    expect(box.get(stableId(url: 'http://x/sports', name: 'Sports')), isNotNull);
  });

  test('interrupted run with identical duplicates never loses the favorite flag', () async {
    final baseId = stableId(url: 'http://x/dup', name: 'Dup');
    // Simulate a crash after the first duplicate (pl1_2) was fully migrated
    // to the base ID but before the favorited second duplicate (pl1_7) was
    // touched. The resumed run cannot tell the migrated copy apart from the
    // remaining legacy duplicate (identical content), so it merges onto the
    // base ID; the favorite must survive the merge and the next playlist
    // refresh restores the second record.
    final box = await seedChannels([
      channel(id: baseId, name: 'Dup', url: 'http://x/dup'),
      channel(id: 'pl1_7', name: 'Dup', url: 'http://x/dup', isFavorite: true),
    ]);
    await seedRecentlyWatched(['pl1_7']);

    await ChannelIdMigration.run();

    expect(box.get('pl1_7'), isNull);
    expect(box.get(baseId)!.isFavorite, isTrue);
    final recentBox = await Hive.openBox<dynamic>('recently_watched');
    expect(recentBox.get('channel_ids'), [baseId]);
  });

  test('no-op on a box with only new-format IDs', () async {
    final id = stableId(url: 'http://x/a', name: 'A');
    final box = await seedChannels([channel(id: id, name: 'A', url: 'http://x/a')]);

    await ChannelIdMigration.run();

    expect(box.length, 1);
    expect(box.get(id), isNotNull);
    final migrations = await Hive.openBox<dynamic>('migrations');
    expect(migrations.get('stable_channel_ids_v1'), isTrue);
  });
}
