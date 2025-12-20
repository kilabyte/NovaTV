import 'package:hive_ce/hive.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/hive_index_helper.dart';
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

  Box<PlaylistModel>? _playlistBox;
  Box<ChannelModel>? _channelBox;

  Future<Box<PlaylistModel>> get playlistBox async {
    if (_playlistBox == null || !_playlistBox!.isOpen) {
      try {
        _playlistBox = await Hive.openBox<PlaylistModel>(_playlistBoxName);
      } catch (e) {
        // Handle lock errors - wait and retry
        if (Hive.isBoxOpen(_playlistBoxName)) {
          try {
            await Hive.box<PlaylistModel>(_playlistBoxName).close();
          } catch (_) {
            // Ignore close errors
          }
          await Future.delayed(const Duration(milliseconds: 100));
          _playlistBox = await Hive.openBox<PlaylistModel>(_playlistBoxName);
        } else {
          // Wait and retry once
          await Future.delayed(const Duration(milliseconds: 200));
          _playlistBox = await Hive.openBox<PlaylistModel>(_playlistBoxName);
        }
      }
    }
    return _playlistBox!;
  }

  Future<Box<ChannelModel>> get channelBox async {
    if (_channelBox == null || !_channelBox!.isOpen) {
      try {
        _channelBox = await Hive.openBox<ChannelModel>(_channelBoxName);
      } catch (e) {
        // Handle lock errors - wait and retry
        if (Hive.isBoxOpen(_channelBoxName)) {
          try {
            await Hive.box<ChannelModel>(_channelBoxName).close();
          } catch (_) {
            // Ignore close errors
          }
          await Future.delayed(const Duration(milliseconds: 100));
          _channelBox = await Hive.openBox<ChannelModel>(_channelBoxName);
        } else {
          // Wait and retry once
          await Future.delayed(const Duration(milliseconds: 200));
          _channelBox = await Hive.openBox<ChannelModel>(_channelBoxName);
        }
      }
    }
    return _channelBox!;
  }

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
      // Filter during iteration for better performance
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

      // Delete existing channels for this playlist
      final existingKeys = box.keys.where((key) => box.get(key)?.playlistId == playlistId).toList();

      // Remove from indexes
      for (final key in existingKeys) {
        final oldChannel = box.get(key);
        if (oldChannel != null && oldChannel.group != null) {
          await HiveIndexHelper.removeFromIndex(baseBoxName: _channelBoxName, fieldName: 'group', fieldValue: oldChannel.group!, key: key);
        }
        if (oldChannel?.isFavorite == true) {
          await HiveIndexHelper.removeFromIndex(baseBoxName: _channelBoxName, fieldName: 'isFavorite', fieldValue: 'true', key: key);
        }
      }

      await box.deleteAll(existingKeys);

      // Add new channels
      final entries = {for (var c in channels) c.id: c};
      await box.putAll(entries);

      // Update indexes for new channels
      for (final channel in channels) {
        if (channel.group != null && channel.group!.isNotEmpty) {
          await HiveIndexHelper.updateIndex<ChannelModel>(baseBoxName: _channelBoxName, fieldName: 'group', item: channel, getFieldValue: (c) => c.group ?? '', getKey: (c) => c.id);
        }
        if (channel.isFavorite) {
          await HiveIndexHelper.updateIndex<ChannelModel>(baseBoxName: _channelBoxName, fieldName: 'isFavorite', item: channel, getFieldValue: (c) => c.isFavorite ? 'true' : 'false', getKey: (c) => c.id);
        }
      }
    } catch (e) {
      throw CacheException('Failed to save channels: $e');
    }
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
      final keysToDelete = box.keys.where((key) => box.get(key)?.playlistId == playlistId).toList();
      await box.deleteAll(keysToDelete);
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
