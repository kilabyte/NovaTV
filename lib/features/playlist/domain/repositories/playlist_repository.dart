import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/channel.dart';
import '../entities/playlist.dart';

/// Repository interface for playlist operations
abstract class PlaylistRepository {
  /// Get all saved playlists
  Future<Either<Failure, List<Playlist>>> getPlaylists();

  /// Get a single playlist by ID
  Future<Either<Failure, Playlist>> getPlaylist(String id);

  /// Add a new playlist
  Future<Either<Failure, Playlist>> addPlaylist({
    required String name,
    required String url,
    String? epgUrl,
  });

  /// Update an existing playlist
  Future<Either<Failure, Playlist>> updatePlaylist(Playlist playlist);

  /// Delete a playlist and its channels
  Future<Either<Failure, void>> deletePlaylist(String id);

  /// Refresh a playlist by re-fetching and parsing its content
  Future<Either<Failure, Playlist>> refreshPlaylist(String id);

  /// Get all channels for a playlist
  Future<Either<Failure, List<Channel>>> getChannels(String playlistId);

  /// Get all channels from all playlists
  Future<Either<Failure, List<Channel>>> getAllChannels();

  /// Get channels by group
  Future<Either<Failure, List<Channel>>> getChannelsByGroup(String group);

  /// Get all unique groups from all channels
  Future<Either<Failure, List<String>>> getAllGroups();

  /// Search channels by name
  Future<Either<Failure, List<Channel>>> searchChannels(String query);

  /// Get a single channel by ID
  Future<Either<Failure, Channel>> getChannel(String id);

  /// Update a channel (e.g., to mark as favorite)
  Future<Either<Failure, Channel>> updateChannel(Channel channel);

  /// Get favorite channels
  Future<Either<Failure, List<Channel>>> getFavoriteChannels();

  /// Toggle channel favorite status
  Future<Either<Failure, Channel>> toggleFavorite(String channelId);
}
