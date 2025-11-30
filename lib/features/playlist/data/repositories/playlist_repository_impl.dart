import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
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

  PlaylistRepositoryImpl({
    required PlaylistLocalDataSource localDataSource,
    required PlaylistRemoteDataSource remoteDataSource,
    required M3UParser m3uParser,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _m3uParser = m3uParser;

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
  Future<Either<Failure, Playlist>> addPlaylist({
    required String name,
    required String url,
    String? epgUrl,
  }) async {
    try {
      final playlistId = _uuid.v4();

      // Fetch and parse the playlist
      final content = await _remoteDataSource.fetchPlaylist(url);

      if (!_m3uParser.isValidM3U(content)) {
        return const Left(ParseFailure('Invalid M3U format'));
      }

      // Parse channels
      final channels = _m3uParser.parse(content, playlistId);

      // Extract EPG URL from playlist header if not provided
      final extractedEpgUrl = epgUrl ??
          _m3uParser.extractEpgUrl(content) ??
          _m3uParser.extractUrlTvg(content);

      // Create playlist model
      final playlist = PlaylistModel(
        id: playlistId,
        name: name,
        url: url,
        epgUrl: extractedEpgUrl,
        lastRefreshed: DateTime.now(),
        channelCount: channels.length,
        createdAt: DateTime.now(),
      );

      // Save playlist and channels
      await _localDataSource.savePlaylist(playlist);
      final channelModels = channels.map((c) => ChannelModel.fromEntity(c)).toList();
      await _localDataSource.saveChannels(playlistId, channelModels);

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
      await _localDataSource.deleteChannels(id);
      await _localDataSource.deletePlaylist(id);
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Playlist>> refreshPlaylist(String id) async {
    try {
      // Get existing playlist
      final existingModel = await _localDataSource.getPlaylist(id);
      if (existingModel == null) {
        return const Left(NotFoundFailure('Playlist not found'));
      }

      // Fetch and parse new content
      final content = await _remoteDataSource.fetchPlaylist(
        existingModel.url,
        headers: existingModel.headers,
      );

      if (!_m3uParser.isValidM3U(content)) {
        // Update playlist with error
        final errorModel = existingModel.copyWith(
          lastError: 'Invalid M3U format',
        );
        await _localDataSource.savePlaylist(errorModel);
        return const Left(ParseFailure('Invalid M3U format'));
      }

      // Parse channels
      final channels = _m3uParser.parse(content, id);

      // Preserve favorite status from existing channels
      final existingChannels = await _localDataSource.getChannels(id);
      final favoriteIds = existingChannels
          .where((c) => c.isFavorite)
          .map((c) => c.tvgId ?? c.name)
          .toSet();

      // Apply favorite status to new channels
      final channelsWithFavorites = channels.map((c) {
        final identifier = c.tvgId ?? c.name;
        if (favoriteIds.contains(identifier)) {
          return c.copyWith(isFavorite: true);
        }
        return c;
      }).toList();

      // Update playlist
      final updatedModel = existingModel.copyWith(
        lastRefreshed: DateTime.now(),
        channelCount: channels.length,
        lastError: null,
      );

      // Save updated playlist and channels
      await _localDataSource.savePlaylist(updatedModel);
      final channelModels = channelsWithFavorites.map((c) => ChannelModel.fromEntity(c)).toList();
      await _localDataSource.saveChannels(id, channelModels);

      return Right(updatedModel.toEntity());
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
