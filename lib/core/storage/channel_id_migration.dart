import 'package:hive_ce/hive.dart';

import '../../features/playlist/data/models/channel_model.dart';
import '../../features/playlist/data/parsers/m3u_parser.dart';
import '../utils/app_logger.dart';
import 'hive_index_helper.dart';
import 'hive_storage.dart';

/// One-time re-key of persisted channel records from the legacy positional
/// IDs (`<playlistId>_<index>`) to the stable content-hashed IDs the M3U
/// parser now generates, so isFavorite flags and the recently-watched list
/// survive the ID scheme change.
///
/// Must run on startup BEFORE any playlist refresh: a refresh under the new
/// scheme prunes the old-ID records as stale keys, which would discard their
/// favorite flags permanently.
class ChannelIdMigration {
  static const String _migrationsBoxName = 'migrations';
  static const String _flagKey = 'stable_channel_ids_v1';
  static const String _channelsBoxName = 'channels';
  static const String _recentlyWatchedBoxName = 'recently_watched';
  static const String _recentlyWatchedKey = 'channel_ids';

  /// Run the migration if it has not completed yet. Never throws: a failure
  /// is logged and retried on the next launch (the completion flag is only
  /// written after a fully successful pass).
  static Future<void> run() async {
    try {
      final migrationsBox = await safeOpenBox<dynamic>(_migrationsBoxName);
      if (migrationsBox.get(_flagKey) == true) return;

      final migrated = await _migrate();
      await migrationsBox.put(_flagKey, true);
      if (migrated > 0) {
        AppLogger.info('Channel ID migration re-keyed $migrated channel(s)');
      }
    } catch (e, st) {
      AppLogger.error('Channel ID migration failed: $e', e, st);
    }
  }

  /// Re-key every old-format channel record and remap the recently-watched
  /// list. Returns the number of re-keyed records.
  ///
  /// Interruption-safe: each record is written under its new key BEFORE the
  /// old key is deleted, so a crash mid-run never loses a record. A re-run
  /// recognizes the already-written copy (same content at the computed new
  /// key) and completes the remaining records; favorite flags are OR-merged
  /// so they can never be dropped.
  static Future<int> _migrate() async {
    if (!await Hive.boxExists(_channelsBoxName)) return 0;
    final box = await safeOpenBox<ChannelModel>(_channelsBoxName);

    // Bucket old-format records per playlist, keeping the legacy positional
    // index so duplicates are re-keyed in original file order and receive
    // the same duplicate suffixes a fresh parse would assign.
    final oldByPlaylist = <String, List<(int, dynamic, ChannelModel)>>{};
    for (final key in box.keys) {
      final model = box.get(key);
      if (model == null) continue;
      final index = _legacyIndexOf(model.id, model.playlistId);
      if (index != null) {
        oldByPlaylist.putIfAbsent(model.playlistId, () => []).add((index, key, model));
      }
    }
    if (oldByPlaylist.isEmpty) return 0;

    final remap = <String, String>{};
    final assigned = <String>{};
    for (final records in oldByPlaylist.values) {
      records.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (_, key, model) in records) {
        final baseId = M3UParser.stableChannelId(
          playlistId: model.playlistId,
          url: model.url,
          tvgId: model.tvgId,
          name: model.name,
          group: model.group,
        );
        var newId = baseId;
        var bump = 1;
        while (true) {
          if (!assigned.contains(newId)) {
            final occupant = box.get(newId);
            // A free slot, or the copy a previous interrupted run already
            // wrote for this same channel, ends the search.
            if (occupant == null || _sameChannel(occupant, model)) break;
          }
          newId = '${baseId}_${bump++}';
        }
        assigned.add(newId);

        final occupant = box.get(newId);
        final isFavorite = model.isFavorite || (occupant?.isFavorite ?? false);
        await box.put(newId, model.copyWith(id: newId, isFavorite: isFavorite));
        if (key != newId) {
          await box.delete(key);
        }
        remap[model.id] = newId;
      }
    }

    await _remapRecentlyWatched(remap);

    // The channel index boxes still reference the deleted legacy keys;
    // rebuild them in place (buildAllIndexes skips boxes whose indexes
    // already exist, so it would not repair them later).
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelsBoxName,
      fieldName: 'group',
      getFieldValue: (c) => c.group ?? '',
      getKey: (c) => c.id,
    );
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelsBoxName,
      fieldName: 'isFavorite',
      getFieldValue: (c) => c.isFavorite ? 'true' : '',
      getKey: (c) => c.id,
    );
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelsBoxName,
      fieldName: 'playlistId',
      getFieldValue: (c) => c.playlistId,
      getKey: (c) => c.id,
    );

    return remap.length;
  }

  /// Extract the positional index from a legacy channel ID, or null if [id]
  /// is not legacy-format. Legacy IDs are `<playlistId>_<decimal index>`;
  /// new-format IDs are `<playlistId>_<15-16 char hex hash>` with an
  /// optional `_<n>` duplicate suffix, so a short all-digit suffix is
  /// unambiguous in practice. A pathological all-digit hash is harmless:
  /// recomputing its stable ID maps it back onto itself.
  static int? _legacyIndexOf(String id, String playlistId) {
    final prefix = '${playlistId}_';
    if (!id.startsWith(prefix)) return null;
    final suffix = id.substring(prefix.length);
    if (suffix.isEmpty || suffix.length > 9) return null;
    for (final unit in suffix.codeUnits) {
      if (unit < 0x30 || unit > 0x39) return null;
    }
    return int.tryParse(suffix);
  }

  /// Whether two records describe the same channel, using the same fields
  /// the stable ID hash is derived from.
  static bool _sameChannel(ChannelModel a, ChannelModel b) {
    return a.playlistId == b.playlistId && a.url == b.url && a.name == b.name && a.tvgId == b.tvgId && a.group == b.group;
  }

  /// Rewrite recently-watched entries through [remap], deduplicating while
  /// preserving order in case two legacy entries now map to one channel.
  static Future<void> _remapRecentlyWatched(Map<String, String> remap) async {
    if (remap.isEmpty || !await Hive.boxExists(_recentlyWatchedBoxName)) return;
    final box = await safeOpenBox<dynamic>(_recentlyWatchedBoxName);
    final stored = box.get(_recentlyWatchedKey);
    if (stored is! List) return;

    final seen = <String>{};
    final updated = <String>[];
    for (final id in stored.whereType<String>()) {
      final mapped = remap[id] ?? id;
      if (seen.add(mapped)) updated.add(mapped);
    }
    await box.put(_recentlyWatchedKey, updated);
  }
}
