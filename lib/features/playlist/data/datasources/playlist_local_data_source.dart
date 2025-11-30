import 'package:hive_ce/hive.dart';

import '../../../../core/error/exceptions.dart';
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
      _playlistBox = await Hive.openBox<PlaylistModel>(_playlistBoxName);
    }
    return _playlistBox!;
  }

  Future<Box<ChannelModel>> get channelBox async {
    if (_channelBox == null || !_channelBox!.isOpen) {
      _channelBox = await Hive.openBox<ChannelModel>(_channelBoxName);
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
      return box.values.where((c) => c.playlistId == playlistId).toList();
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
      final existingKeys = box.keys
          .where((key) => box.get(key)?.playlistId == playlistId)
          .toList();
      await box.deleteAll(existingKeys);

      // Add new channels
      final entries = {for (var c in channels) c.id: c};
      await box.putAll(entries);
    } catch (e) {
      throw CacheException('Failed to save channels: $e');
    }
  }

  @override
  Future<void> saveChannel(ChannelModel channel) async {
    try {
      final box = await channelBox;
      await box.put(channel.id, channel);
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
      final keysToDelete = box.keys
          .where((key) => box.get(key)?.playlistId == playlistId)
          .toList();
      await box.deleteAll(keysToDelete);
    } catch (e) {
      throw CacheException('Failed to delete channels: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getFavoriteChannels() async {
    try {
      final box = await channelBox;
      return box.values.where((c) => c.isFavorite).toList();
    } catch (e) {
      throw CacheException('Failed to get favorite channels: $e');
    }
  }

  @override
  Future<List<ChannelModel>> getChannelsByGroup(String group) async {
    try {
      final box = await channelBox;
      return box.values.where((c) => c.group == group).toList();
    } catch (e) {
      throw CacheException('Failed to get channels by group: $e');
    }
  }

  @override
  Future<List<ChannelModel>> searchChannels(String query) async {
    try {
      final box = await channelBox;
      final lowerQuery = query.toLowerCase();
      return box.values.where((c) {
        final name = c.name.toLowerCase();
        final tvgName = c.tvgName?.toLowerCase() ?? '';
        final group = c.group?.toLowerCase() ?? '';
        return name.contains(lowerQuery) ||
            tvgName.contains(lowerQuery) ||
            group.contains(lowerQuery);
      }).toList();
    } catch (e) {
      throw CacheException('Failed to search channels: $e');
    }
  }

  @override
  Future<List<String>> getAllGroups() async {
    try {
      final box = await channelBox;
      final groups = box.values
          .where((c) => c.group != null && c.group!.isNotEmpty)
          .map((c) => c.group!)
          .toSet()
          .toList();
      groups.sort();
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
