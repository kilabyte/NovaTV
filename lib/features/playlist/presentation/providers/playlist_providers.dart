import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/playlist_local_data_source.dart';
import '../../data/datasources/playlist_remote_data_source.dart';
import '../../data/parsers/m3u_parser.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/usecases/add_playlist.dart';
import '../../domain/usecases/delete_playlist.dart';
import '../../domain/usecases/get_channels.dart';
import '../../domain/usecases/get_playlists.dart';
import '../../domain/usecases/refresh_playlist.dart';
import '../../domain/usecases/search_channels.dart';
import '../../domain/usecases/toggle_favorite.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../epg/presentation/providers/epg_providers.dart';

// Data source providers
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Accept': '*/*',
    },
  ));
});

final m3uParserProvider = Provider<M3UParser>((ref) => M3UParser());

final playlistLocalDataSourceProvider = Provider<PlaylistLocalDataSource>((ref) {
  return PlaylistLocalDataSourceImpl();
});

final playlistRemoteDataSourceProvider = Provider<PlaylistRemoteDataSource>((ref) {
  return PlaylistRemoteDataSourceImpl(ref.watch(dioProvider));
});

// Repository provider
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepositoryImpl(
    localDataSource: ref.watch(playlistLocalDataSourceProvider),
    remoteDataSource: ref.watch(playlistRemoteDataSourceProvider),
    m3uParser: ref.watch(m3uParserProvider),
  );
});

// Use case providers
final getPlaylistsUseCaseProvider = Provider<GetPlaylists>((ref) {
  return GetPlaylists(ref.watch(playlistRepositoryProvider));
});

final addPlaylistUseCaseProvider = Provider<AddPlaylist>((ref) {
  return AddPlaylist(ref.watch(playlistRepositoryProvider));
});

final refreshPlaylistUseCaseProvider = Provider<RefreshPlaylist>((ref) {
  return RefreshPlaylist(ref.watch(playlistRepositoryProvider));
});

final deletePlaylistUseCaseProvider = Provider<DeletePlaylist>((ref) {
  return DeletePlaylist(ref.watch(playlistRepositoryProvider));
});

final getChannelsUseCaseProvider = Provider<GetChannels>((ref) {
  return GetChannels(ref.watch(playlistRepositoryProvider));
});

final getAllChannelsUseCaseProvider = Provider<GetAllChannels>((ref) {
  return GetAllChannels(ref.watch(playlistRepositoryProvider));
});

final toggleFavoriteUseCaseProvider = Provider<ToggleFavorite>((ref) {
  return ToggleFavorite(ref.watch(playlistRepositoryProvider));
});

final getFavoriteChannelsUseCaseProvider = Provider<GetFavoriteChannels>((ref) {
  return GetFavoriteChannels(ref.watch(playlistRepositoryProvider));
});

final searchChannelsUseCaseProvider = Provider<SearchChannels>((ref) {
  return SearchChannels(ref.watch(playlistRepositoryProvider));
});

// State providers

/// Provider for playlists list
final playlistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final useCase = ref.watch(getPlaylistsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (playlists) => playlists,
  );
});

/// Provider for all channels
final allChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final useCase = ref.watch(getAllChannelsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (channels) => channels,
  );
});

/// Provider for favorite channels
final favoriteChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final useCase = ref.watch(getFavoriteChannelsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (channels) => channels,
  );
});

/// Provider for channels by playlist
final channelsByPlaylistProvider = FutureProvider.family<List<Channel>, String>((ref, playlistId) async {
  final useCase = ref.watch(getChannelsUseCaseProvider);
  final result = await useCase(playlistId);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (channels) => channels,
  );
});

/// Provider for channel search
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Channel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];

  final useCase = ref.watch(searchChannelsUseCaseProvider);
  final result = await useCase(query);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (channels) => channels,
  );
});

/// Provider for channel groups
final channelGroupsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(playlistRepositoryProvider);
  final result = await repository.getAllGroups();
  return result.fold(
    (failure) => throw Exception(failure.message),
    (groups) => groups,
  );
});

/// Currently selected group filter
final selectedGroupProvider = StateProvider<String?>((ref) => null);

/// Filtered channels by selected group
final filteredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  final repository = ref.watch(playlistRepositoryProvider);

  if (selectedGroup == null) {
    final result = await repository.getAllChannels();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (channels) => channels,
    );
  }

  final result = await repository.getChannelsByGroup(selectedGroup);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (channels) => channels,
  );
});

/// Notifier for playlist operations
class PlaylistNotifier extends StateNotifier<AsyncValue<List<Playlist>>> {
  final Ref _ref;

  PlaylistNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(getPlaylistsUseCaseProvider);
    final result = await useCase(const NoParams());
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (playlists) => AsyncValue.data(playlists),
    );
  }

  Future<void> addPlaylist({
    required String name,
    required String url,
    String? epgUrl,
  }) async {
    final useCase = _ref.read(addPlaylistUseCaseProvider);
    final result = await useCase(AddPlaylistParams(
      name: name,
      url: url,
      epgUrl: epgUrl,
    ));

    result.fold(
      (failure) => throw Exception(failure.message),
      (playlist) {
        _loadPlaylists();
        // Invalidate related providers
        _ref.invalidate(allChannelsProvider);
        _ref.invalidate(channelGroupsProvider);

        // Auto-refresh EPG if an EPG URL is available
        final effectiveEpgUrl = playlist.epgUrl;
        if (effectiveEpgUrl != null && effectiveEpgUrl.isNotEmpty) {
          _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(
                playlist.id,
                effectiveEpgUrl,
              );
        }
      },
    );
  }

  Future<void> refreshPlaylist(String playlistId) async {
    final useCase = _ref.read(refreshPlaylistUseCaseProvider);
    final result = await useCase(playlistId);

    result.fold(
      (failure) => throw Exception(failure.message),
      (playlist) {
        _loadPlaylists();
        _ref.invalidate(allChannelsProvider);
        _ref.invalidate(channelGroupsProvider);
        _ref.invalidate(channelsByPlaylistProvider(playlistId));

        // Also refresh EPG if available
        final epgUrl = playlist.epgUrl;
        if (epgUrl != null && epgUrl.isNotEmpty) {
          _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(
                playlist.id,
                epgUrl,
              );
        }
      },
    );
  }

  Future<void> deletePlaylist(String playlistId) async {
    final useCase = _ref.read(deletePlaylistUseCaseProvider);
    final result = await useCase(playlistId);

    result.fold(
      (failure) => throw Exception(failure.message),
      (_) {
        _loadPlaylists();
        _ref.invalidate(allChannelsProvider);
        _ref.invalidate(channelGroupsProvider);
      },
    );
  }

  void refresh() {
    _loadPlaylists();
  }
}

final playlistNotifierProvider = StateNotifierProvider<PlaylistNotifier, AsyncValue<List<Playlist>>>((ref) {
  return PlaylistNotifier(ref);
});

/// Notifier for toggling favorites
class FavoriteNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  FavoriteNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> toggleFavorite(String channelId) async {
    state = const AsyncValue.loading();
    final useCase = _ref.read(toggleFavoriteUseCaseProvider);
    final result = await useCase(channelId);

    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (_) {
        _ref.invalidate(favoriteChannelsProvider);
        _ref.invalidate(allChannelsProvider);
        return const AsyncValue.data(null);
      },
    );
  }
}

final favoriteNotifierProvider = StateNotifierProvider<FavoriteNotifier, AsyncValue<void>>((ref) {
  return FavoriteNotifier(ref);
});
