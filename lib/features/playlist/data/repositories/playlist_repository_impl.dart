import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../compute/m3u_parse_compute.dart';
import '../datasources/playlist_local_data_source.dart';
import '../datasources/playlist_remote_data_source.dart';
import '../models/channel_model.dart';
import '../models/playlist_model.dart';
import '../parsers/m3u_parser.dart';

/// Implementation of PlaylistRepository
class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistLocalDataSource _localDataSource;
  final PlaylistRemoteDataSource _remoteDataSource;
  final M3UParser _m3uParser;
  static const _uuid = Uuid();

  /// CancelTokens for in-flight refresh downloads keyed by playlistId, so
  /// deletePlaylist can abort the download instead of racing it.
  final Map<String, CancelToken> _refreshTokens = {};

  PlaylistRepositoryImpl({required PlaylistLocalDataSource localDataSource, required PlaylistRemoteDataSource remoteDataSource, required M3UParser m3uParser}) : _localDataSource = localDataSource, _remoteDataSource = remoteDataSource, _m3uParser = m3uParser;

  @override
  Future<Either<Failure, List<Playlist>>> getPlaylists() async {
    try {
      final models = await _localDataSource.getPlaylists();
      final playlists = models.map((m) => m.toEntity()).toList();
      return Right(playlists);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Playlist>> getPlaylist(String id) async {
    try {
      final model = await _localDataSource.getPlaylist(id);
      if (model == null) {
        return const Left(NotFoundFailure('Playlist not found'));
      }
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Playlist>> addPlaylist({required String name, required String url, String? epgUrl}) async {
    try {
      final playlistId = _uuid.v4();

      // Fetch and parse the playlist
      final content = await _remoteDataSource.fetchPlaylist(url);

      if (!_m3uParser.isValidM3U(content)) {
        return const Left(ParseFailure('Invalid M3U format'));
      }

      // Parse channels in compute isolate to prevent UI blocking
      final channelsJson = await compute(parseM3UContent, ParseM3UParams(content: content, playlistId: playlistId));

      // Reconstruct channels from JSON
      final channels = channelsJson.map((json) {
        return Channel(id: json['id'] as String, name: json['name'] as String, url: json['url'] as String, playlistId: json['playlistId'] as String, tvgId: json['tvgId'] as String?, tvgName: json['tvgName'] as String?, logoUrl: json['logoUrl'] as String?, group: json['group'] as String?, language: json['language'] as String?, country: json['country'] as String?, tvgShift: json['tvgShift'] as int?, userAgent: json['userAgent'] as String?, referrer: json['referrer'] as String?, headers: json['headers'] != null ? Map<String, String>.from(json['headers'] as Map) : null, licenseUrl: json['licenseUrl'] as String?, licenseType: json['licenseType'] as String?, isFavorite: json['isFavorite'] as bool? ?? false, channelNumber: json['channelNumber'] as int?, catchupType: json['catchupType'] as String?, catchupSource: json['catchupSource'] as String?, catchupDays: json['catchupDays'] as int?);
      }).toList();

      // Extract EPG URL from playlist header if not provided
      final extractedEpgUrl = epgUrl ?? _m3uParser.extractEpgUrl(content) ?? _m3uParser.extractUrlTvg(content);

      // Create playlist model
      final playlist = PlaylistModel(id: playlistId, name: name, url: url, epgUrl: extractedEpgUrl, lastRefreshed: DateTime.now(), channelCount: channels.length, createdAt: DateTime.now());

      // Save channels first so a failed channel write can't leave an orphan
      // playlist claiming N channels with zero stored.
      final channelModels = channels.map((c) => ChannelModel.fromEntity(c)).toList();
      await _localDataSource.saveChannels(playlistId, channelModels);
      try {
        await _localDataSource.savePlaylist(playlist);
      } on CacheException {
        // Roll back the channel write so orphaned channels don't linger in
        // the All Channels list.
        try {
          await _localDataSource.deleteChannels(playlistId);
        } catch (_) {}
        rethrow;
      }

      return Right(playlist.toEntity());
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on ParseException catch (e) {
      return Left(ParseFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to add playlist: $e'));
    }
  }

  @override
  Future<Either<Failure, Playlist>> updatePlaylist(Playlist playlist) async {
    try {
      final model = PlaylistModel.fromEntity(playlist);
      await _localDataSource.savePlaylist(model);
      return Right(playlist);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlaylist(String id) async {
    try {
      // Abort any in-flight refresh download for this playlist first so it
      // cannot re-save channels (or surface an error) after the delete.
      _refreshTokens.remove(id)?.cancel('Playlist deleted');
      await _localDataSource.deleteChannels(id);
      await _localDataSource.deletePlaylist(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Playlist>> refreshPlaylist(String id) async {
    final cancelToken = CancelToken();
    // Supersede any refresh already in flight for this playlist. Leaving the
    // old token orphaned would let two refreshes race the channel writes, and
    // deletePlaylist would only be able to cancel the newer one.
    _refreshTokens[id]?.cancel('Superseded by a newer refresh');
    _refreshTokens[id] = cancelToken;
    try {
      // Get existing playlist
      final existingModel = await _localDataSource.getPlaylist(id);
      if (existingModel == null) {
        return const Left(NotFoundFailure('Playlist not found'));
      }

      // Fetch and parse new content
      final content = await _remoteDataSource.fetchPlaylist(existingModel.url, headers: existingModel.headers, cancelToken: cancelToken);

      // The playlist may have been deleted while the download was finishing;
      // bail out before any write resurrects its channels or its row.
      if (cancelToken.isCancelled) {
        return const Left(CancelledFailure('Playlist refresh cancelled'));
      }

      if (!_m3uParser.isValidM3U(content)) {
        // Update playlist with error
        final errorModel = existingModel.copyWith(lastError: 'Invalid M3U format');
        await _localDataSource.savePlaylist(errorModel);
        return const Left(ParseFailure('Invalid M3U format'));
      }

      // Parse channels in compute isolate to prevent UI blocking
      final channelsJson = await compute(parseM3UContent, ParseM3UParams(content: content, playlistId: id));

      // Reconstruct channels from JSON
      final channels = channelsJson.map((json) {
        return Channel(id: json['id'] as String, name: json['name'] as String, url: json['url'] as String, playlistId: json['playlistId'] as String, tvgId: json['tvgId'] as String?, tvgName: json['tvgName'] as String?, logoUrl: json['logoUrl'] as String?, group: json['group'] as String?, language: json['language'] as String?, country: json['country'] as String?, tvgShift: json['tvgShift'] as int?, userAgent: json['userAgent'] as String?, referrer: json['referrer'] as String?, headers: json['headers'] != null ? Map<String, String>.from(json['headers'] as Map) : null, licenseUrl: json['licenseUrl'] as String?, licenseType: json['licenseType'] as String?, isFavorite: json['isFavorite'] as bool? ?? false, channelNumber: json['channelNumber'] as int?, catchupType: json['catchupType'] as String?, catchupSource: json['catchupSource'] as String?, catchupDays: json['catchupDays'] as int?);
      }).toList();

      // Preserve favorite status from existing channels.
      // Identity tuple includes group so duplicate names across groups don't
      // collide (e.g. "News" in "USA" vs "News" in "UK").
      String favKey(String? tvgId, String name, String? group) => '${tvgId ?? ''}|$name|${group ?? ''}';
      final existingChannels = await _localDataSource.getChannels(id);
      final favoriteIds = existingChannels
          .where((c) => c.isFavorite)
          .map((c) => favKey(c.tvgId, c.name, c.group))
          .toSet();

      // Apply favorite status to new channels
      final channelsWithFavorites = channels.map((c) {
        if (favoriteIds.contains(favKey(c.tvgId, c.name, c.group))) {
          return c.copyWith(isFavorite: true);
        }
        return c;
      }).toList();

      // Update playlist (clearLastError explicitly resets the error field —
      // lastError: null alone is a no-op because of the ?? coalesce).
      final updatedModel = existingModel.copyWith(
        lastRefreshed: DateTime.now(),
        channelCount: channels.length,
        clearLastError: true,
      );

      // Parsing in the compute isolate can take seconds; re-check that the
      // playlist wasn't deleted during it before writing anything back.
      if (cancelToken.isCancelled) {
        return const Left(CancelledFailure('Playlist refresh cancelled'));
      }

      // Save channels first; only stamp the playlist as refreshed after the
      // channel write succeeds. The previous ordering recorded a fresh
      // lastRefreshed with no lastError even when the channel save failed,
      // so auto-refresh would not retry for refreshIntervalHours.
      final channelModels = channelsWithFavorites.map((c) => ChannelModel.fromEntity(c)).toList();
      try {
        await _localDataSource.saveChannels(id, channelModels);
      } on CacheException catch (e) {
        final errorModel = existingModel.copyWith(lastError: 'Failed to save channels: ${e.message}');
        try {
          await _localDataSource.savePlaylist(errorModel);
        } catch (_) {}
        return Left(CacheFailure(e.message));
      }
      await _localDataSource.savePlaylist(updatedModel);

      return Right(updatedModel.toEntity());
    } on RequestCancelledException {
      return const Left(CancelledFailure('Playlist refresh cancelled'));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on ParseException catch (e) {
      return Left(ParseFailure(e.message));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    } catch (e) {
      return Left(UnknownFailure('Failed to refresh playlist: $e'));
    } finally {
      if (identical(_refreshTokens[id], cancelToken)) {
        _refreshTokens.remove(id);
      }
    }
  }

  @override
  Future<Either<Failure, List<Channel>>> getChannels(String playlistId) async {
    try {
      final models = await _localDataSource.getChannels(playlistId);
      final channels = models.map((m) => m.toEntity()).toList();
      // Sort by channel number
      channels.sort((a, b) => (a.channelNumber ?? 0).compareTo(b.channelNumber ?? 0));
      return Right(channels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Channel>>> getAllChannels() async {
    try {
      final models = await _localDataSource.getAllChannels();
      final channels = models.map((m) => m.toEntity()).toList();
      // Sort by channel number
      channels.sort((a, b) => (a.channelNumber ?? 0).compareTo(b.channelNumber ?? 0));
      return Right(channels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Channel>>> getChannelsByGroup(String group) async {
    try {
      final models = await _localDataSource.getChannelsByGroup(group);
      final channels = models.map((m) => m.toEntity()).toList();
      channels.sort((a, b) => (a.channelNumber ?? 0).compareTo(b.channelNumber ?? 0));
      return Right(channels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAllGroups() async {
    try {
      final groups = await _localDataSource.getAllGroups();
      return Right(groups);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Channel>>> searchChannels(String query) async {
    try {
      final models = await _localDataSource.searchChannels(query);
      final channels = models.map((m) => m.toEntity()).toList();
      return Right(channels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Channel>> getChannel(String id) async {
    try {
      final model = await _localDataSource.getChannel(id);
      if (model == null) {
        return const Left(NotFoundFailure('Channel not found'));
      }
      return Right(model.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Channel>> updateChannel(Channel channel) async {
    try {
      final model = ChannelModel.fromEntity(channel);
      await _localDataSource.saveChannel(model);
      return Right(channel);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, List<Channel>>> getFavoriteChannels() async {
    try {
      final models = await _localDataSource.getFavoriteChannels();
      final channels = models.map((m) => m.toEntity()).toList();
      return Right(channels);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Channel>> toggleFavorite(String channelId) async {
    try {
      final model = await _localDataSource.getChannel(channelId);
      if (model == null) {
        return const Left(NotFoundFailure('Channel not found'));
      }

      final updatedModel = model.copyWith(isFavorite: !model.isFavorite);
      await _localDataSource.saveChannel(updatedModel);
      return Right(updatedModel.toEntity());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
