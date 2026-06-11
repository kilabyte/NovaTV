import 'package:hive_ce/hive.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/hive_index_helper.dart';
import '../../../../core/storage/hive_storage.dart';
import '../models/channel_model.dart';
import '../models/playlist_model.dart';

/// Local data source for playlist operations using Hive
abstract class PlaylistLocalDataSource {
  /// Get all playlists
  Future<List<PlaylistModel>> getPlaylists();

  /// Get a single playlist by ID
  Future<PlaylistModel?> getPlaylist(String id);

  /// Save a playlist
  Future<void> savePlaylist(PlaylistModel playlist);

  /// Delete a playlist
  Future<void> deletePlaylist(String id);

  /// Get all channels for a playlist
  Future<List<ChannelModel>> getChannels(String playlistId);

  /// Get all channels
  Future<List<ChannelModel>> getAllChannels();

  /// Save channels (replaces existing channels for the playlist)
  Future<void> saveChannels(String playlistId, List<ChannelModel> channels);

  /// Save a single channel
  Future<void> saveChannel(ChannelModel channel);

  /// Get a channel by ID
  Future<ChannelModel?> getChannel(String id);

  /// Delete all channels for a playlist
  Future<void> deleteChannels(String playlistId);

  /// Get favorite channels
  Future<List<ChannelModel>> getFavoriteChannels();

  /// Get channels by group
  Future<List<ChannelModel>> getChannelsByGroup(String group);

  /// Search channels by name
  Future<List<ChannelModel>> searchChannels(String query);

  /// Get all unique groups
  Future<List<String>> getAllGroups();

  /// Clear all data
  Future<void> clearAll();
}

/// Implementation of PlaylistLocalDataSource using Hive
class PlaylistLocalDataSourceImpl implements PlaylistLocalDataSource {
  static const String _playlistBoxName = 'playlists';
  static const String _channelBoxName = 'channels';

  // Delegate to the project's shared safeOpenBox helper so two concurrent
  // awaiting callers can't both call Hive.openBox and hit a lock error.
  Future<Box<PlaylistModel>> get playlistBox =>
      safeOpenBox<PlaylistModel>(_playlistBoxName);

  Future<Box<ChannelModel>> get channelBox =>
      safeOpenBox<ChannelModel>(_channelBoxName);

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      final box = await playlistBox;
      return box.values.toList();
    } catch (e) {
      throw CacheException('Failed to get playlists: $e');
    }
  }

  @override
  Future<PlaylistModel?> getPlaylist(String id) async {
    try {
      final box = await playlistBox;
      return box.get(id);
    } catch (e) {
      throw CacheException('Failed to get playlist: $e');
    }
  }

  @override
  Future<void> savePlaylist(PlaylistModel playlist) async {
    try {
      final box = await playlistBox;
      await box.put(playlist.id, playlist);
    } catch (e) {
      throw CacheException('Failed to save playlist: $e');
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      final box = await playlistBox;
      await box.delete(id);
    } catch (e) {
      throw CacheException('Failed to delete playlist: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getChannels(String playlistId) async {
    try {
      final box = await channelBox;

      // Use the playlistId index if available for O(1) lookup instead of
      // scanning every channel on the main isolate.
      final indexedKeys = await HiveIndexHelper.getIndexedKeys(
        baseBoxName: _channelBoxName,
        fieldName: 'playlistId',
        fieldValue: playlistId,
      );
      if (indexedKeys.isNotEmpty) {
        final channels = <ChannelModel>[];
        for (final key in indexedKeys) {
          final c = box.get(key);
          if (c != null) channels.add(c);
        }
        return channels;
      }

      // Fallback: scan for playlists with no index yet (fresh install).
      final channels = <ChannelModel>[];
      for (final channel in box.values) {
        if (channel.playlistId == playlistId) {
          channels.add(channel);
        }
      }
      return channels;
    } catch (e) {
      throw CacheException('Failed to get channels: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getAllChannels() async {
    try {
      final box = await channelBox;
      return box.values.toList();
    } catch (e) {
      throw CacheException('Failed to get all channels: $e');
    }
  }

  @override
  Future<void> saveChannels(String playlistId, List<ChannelModel> channels) async {
    try {
      final box = await channelBox;

      // Find this playlist's existing keys via the playlistId index (kept
      // current by _rebuildChannelIndexes) instead of a full-box scan.
      final indexed = await HiveIndexHelper.getIndexedKeys(
        baseBoxName: _channelBoxName,
        fieldName: 'playlistId',
        fieldValue: playlistId,
      );
      final existingKeys = indexed.isNotEmpty
          ? indexed.toList()
          : box.keys.where((key) => box.get(key)?.playlistId == playlistId).toList();

      // Re-apply any favorite toggle that landed after the caller took its
      // snapshot (refresh holds a snapshot across long awaits); the box value
      // is always the latest user intent because parsing never sets it.
      final entries = <String, ChannelModel>{};
      for (final c in channels) {
        final existing = box.get(c.id);
        entries[c.id] = (existing == null || existing.isFavorite == c.isFavorite)
            ? c
            : c.copyWith(isFavorite: existing.isFavorite);
      }

      // Write the new channels first, then delete only the stale keys.
      // Channel IDs are deterministic, so put-then-prune avoids both the
      // crash-loses-everything window and readers seeing an empty playlist
      // mid-refresh (the previous deleteAll-then-putAll did neither).
      await box.putAll(entries);
      final staleKeys = existingKeys.where((key) => !entries.containsKey(key)).toList();
      await box.deleteAll(staleKeys);

      // Rebuild the group and isFavorite indexes for the entire channel box in
      // one pass. Doing this per-channel (the previous behavior) caused 10k+
      // individual Hive writes and a 5-30s UI freeze on large M3U imports.
      await _rebuildChannelIndexes(box);
    } catch (e) {
      throw CacheException('Failed to save channels: $e');
    }
  }

  /// Bulk-rebuild the group, isFavorite and playlistId indexes from the
  /// current box state. Single clear + putAll per index box.
  Future<void> _rebuildChannelIndexes(Box<ChannelModel> box) async {
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelBoxName,
      fieldName: 'group',
      getFieldValue: (c) => c.group ?? '',
      getKey: (c) => c.id,
    );
    // Only index channels that are actually favorites so the index stays
    // sparse. buildIndex() skips empty field values.
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelBoxName,
      fieldName: 'isFavorite',
      getFieldValue: (c) => c.isFavorite ? 'true' : '',
      getKey: (c) => c.id,
    );
    // Keeps getChannels(playlistId) / deleteChannels O(1) lookup instead of
    // an O(N) main-isolate scan.
    await HiveIndexHelper.buildIndex<ChannelModel>(
      baseBoxName: _channelBoxName,
      fieldName: 'playlistId',
      getFieldValue: (c) => c.playlistId,
      getKey: (c) => c.id,
    );
  }

  @override
  Future<void> saveChannel(ChannelModel channel) async {
    try {
      final box = await channelBox;

      // Get old channel for index update
      final oldChannel = box.get(channel.id);
      final oldGroup = oldChannel?.group;
      final oldIsFavorite = oldChannel?.isFavorite;

      await box.put(channel.id, channel);

      // Update indexes
      if (channel.group != null && channel.group!.isNotEmpty) {
        await HiveIndexHelper.updateIndex<ChannelModel>(baseBoxName: _channelBoxName, fieldName: 'group', item: channel, getFieldValue: (c) => c.group ?? '', getKey: (c) => c.id, oldFieldValue: oldGroup);
      }

      if (channel.isFavorite != oldIsFavorite) {
        // Remove from old index entry
        if (oldIsFavorite == true) {
          await HiveIndexHelper.removeFromIndex(baseBoxName: _channelBoxName, fieldName: 'isFavorite', fieldValue: 'true', key: channel.id);
        }
        // Add to new index entry
        if (channel.isFavorite) {
          await HiveIndexHelper.updateIndex<ChannelModel>(baseBoxName: _channelBoxName, fieldName: 'isFavorite', item: channel, getFieldValue: (c) => c.isFavorite ? 'true' : 'false', getKey: (c) => c.id);
        }
      }
    } catch (e) {
      throw CacheException('Failed to save channel: $e');
    }
  }

  @override
  Future<ChannelModel?> getChannel(String id) async {
    try {
      final box = await channelBox;
      return box.get(id);
    } catch (e) {
      throw CacheException('Failed to get channel: $e');
    }
  }

  @override
  Future<void> deleteChannels(String playlistId) async {
    try {
      final box = await channelBox;

      // Use the playlistId index if present for O(1) key lookup.
      final indexed = await HiveIndexHelper.getIndexedKeys(
        baseBoxName: _channelBoxName,
        fieldName: 'playlistId',
        fieldValue: playlistId,
      );
      final keysToDelete = indexed.isNotEmpty
          ? indexed.toList()
          : box.keys.where((key) => box.get(key)?.playlistId == playlistId).toList();

      await box.deleteAll(keysToDelete);
      // Rebuild indexes so the deleted ids drop out.
      await _rebuildChannelIndexes(box);
    } catch (e) {
      throw CacheException('Failed to delete channels: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getFavoriteChannels() async {
    try {
      final box = await channelBox;

      // Try to use index if available for faster lookup
      final indexedKeys = await HiveIndexHelper.getIndexedKeys(baseBoxName: _channelBoxName, fieldName: 'isFavorite', fieldValue: 'true');

      if (indexedKeys.isNotEmpty) {
        // Use index for fast lookup
        final favorites = <ChannelModel>[];
        for (final key in indexedKeys) {
          final channel = box.get(key);
          if (channel != null && channel.isFavorite) {
            favorites.add(channel);
          }
        }
        return favorites;
      }

      // Fallback to iteration if index doesn't exist
      final favorites = <ChannelModel>[];
      for (final channel in box.values) {
        if (channel.isFavorite) {
          favorites.add(channel);
        }
      }
      return favorites;
    } catch (e) {
      throw CacheException('Failed to get favorite channels: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getChannelsByGroup(String group) async {
    try {
      final box = await channelBox;

      // Try to use index if available for faster lookup
      final indexedKeys = await HiveIndexHelper.getIndexedKeys(baseBoxName: _channelBoxName, fieldName: 'group', fieldValue: group);

      if (indexedKeys.isNotEmpty) {
        // Use index for fast lookup
        final channels = <ChannelModel>[];
        for (final key in indexedKeys) {
          final channel = box.get(key);
          if (channel != null) {
            channels.add(channel);
          }
        }
        return channels;
      }

      // Fallback to iteration if index doesn't exist
      final lowerGroup = group.toLowerCase();
      final filteredChannels = <ChannelModel>[];
      for (final channel in box.values) {
        if (channel.group?.toLowerCase() == lowerGroup) {
          filteredChannels.add(channel);
        }
      }
      return filteredChannels;
    } catch (e) {
      throw CacheException('Failed to get channels by group: $e');
    }
  }

  @override
  Future<List<ChannelModel>> searchChannels(String query) async {
    try {
      final box = await channelBox;
      // CRITICAL: Filter during iteration instead of loading all channels into memory
      final lowerQuery = query.toLowerCase();
      final results = <ChannelModel>[];
      for (final channel in box.values) {
        final name = channel.name.toLowerCase();
        final tvgName = channel.tvgName?.toLowerCase() ?? '';
        final group = channel.group?.toLowerCase() ?? '';
        if (name.contains(lowerQuery) || tvgName.contains(lowerQuery) || group.contains(lowerQuery)) {
          results.add(channel);
        }
      }
      return results;
    } catch (e) {
      throw CacheException('Failed to search channels: $e');
    }
  }

  @override
  Future<List<String>> getAllGroups() async {
    try {
      final box = await channelBox;
      // Filter during iteration and use Set for deduplication
      final groupsSet = <String>{};
      for (final channel in box.values) {
        if (channel.group != null && channel.group!.isNotEmpty) {
          groupsSet.add(channel.group!);
        }
      }
      final groups = groupsSet.toList()..sort();
      return groups;
    } catch (e) {
      throw CacheException('Failed to get groups: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final pBox = await playlistBox;
      final cBox = await channelBox;
      await pBox.clear();
      await cBox.clear();
    } catch (e) {
      throw CacheException('Failed to clear data: $e');
    }
  }
}
