import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/datasources/playlist_local_data_source.dart';
import '../../data/datasources/playlist_remote_data_source.dart';
import '../../data/parsers/m3u_parser.dart';
import '../../data/repositories/playlist_repository_impl.dart';
import '../../data/xtream/xtream_client.dart';
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
import '../../../search/domain/entities/search_result.dart';

// Data source providers
final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 60), headers: {'Accept': '*/*'}));
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
  return PlaylistRepositoryImpl(localDataSource: ref.watch(playlistLocalDataSourceProvider), remoteDataSource: ref.watch(playlistRemoteDataSourceProvider), m3uParser: ref.watch(m3uParserProvider));
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
  return result.fold((failure) => throw Exception(failure.message), (playlists) => playlists);
});

/// Provider for all channels
final allChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final useCase = ref.watch(getAllChannelsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold((failure) => throw Exception(failure.message), (channels) => channels);
});

/// Provider for favorite channels
final favoriteChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final useCase = ref.watch(getFavoriteChannelsUseCaseProvider);
  final result = await useCase(const NoParams());
  return result.fold((failure) => throw Exception(failure.message), (channels) => channels);
});

/// Provider for channels by playlist
final channelsByPlaylistProvider = FutureProvider.family<List<Channel>, String>((ref, playlistId) async {
  final useCase = ref.watch(getChannelsUseCaseProvider);
  final result = await useCase(playlistId);
  return result.fold((failure) => throw Exception(failure.message), (channels) => channels);
});

/// Provider for channel search
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// EPG-id -> Channel lookup map, cached off [allChannelsProvider] so each
/// debounced search query doesn't re-read and re-scan the entire channel box
/// just to map program results back to channels. Keys are lowercased to
/// match the normalization applied when programs are indexed.
final channelByEpgIdProvider = FutureProvider<Map<String, Channel>>((ref) async {
  final channels = await ref.watch(allChannelsProvider.future);
  return {for (final c in channels) c.epgId.toLowerCase(): c};
});

/// Combined search results provider that searches both channels and EPG programs
final searchResultsProvider = FutureProvider.autoDispose<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty || query.length < 2) return [];

  // Debounce: if the query changes within 250ms, cancel this computation.
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 250), () => completer.complete());
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;
  if (ref.read(searchQueryProvider) != query) return [];

  final results = <SearchResult>[];
  final seenChannelIds = <String>{};

  // Search channels first
  final channelUseCase = ref.watch(searchChannelsUseCaseProvider);
  final channelResult = await channelUseCase(query);
  channelResult.fold(
    (failure) => AppLogger.warning('Channel search failed: ${failure.message}'),
    (channels) {
      for (final channel in channels) {
        results.add(ChannelSearchResult(channel));
        seenChannelIds.add(channel.id);
      }
    },
  );

  // Search EPG programs
  final epgLocalDataSource = ref.watch(epgLocalDataSourceProvider);
  final playlistRepository = ref.watch(playlistRepositoryProvider);

  // Cached EPG-id map; avoids re-hydrating every channel per query.
  final channelByEpgId = await ref.watch(channelByEpgIdProvider.future);

  // Get all playlists to search their EPG data
  final playlistsResult = await playlistRepository.getPlaylists();
  await playlistsResult.fold((failure) async {
    AppLogger.warning('Playlist lookup for EPG search failed: ${failure.message}');
  }, (playlists) async {
    for (final playlist in playlists) {
      final programs = await epgLocalDataSource.searchPrograms(playlist.id, query);

      for (final program in programs) {
        final channel = channelByEpgId[program.channelId.toLowerCase()];
        if (channel != null && !seenChannelIds.contains(channel.id)) {
          results.add(ProgramSearchResult(program: program, channel: channel));
          seenChannelIds.add(channel.id);
        }
      }
    }
  });

  return results;
});

/// Provider for channel groups
final channelGroupsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(playlistRepositoryProvider);
  final result = await repository.getAllGroups();
  return result.fold((failure) => throw Exception(failure.message), (groups) => groups);
});

/// Currently selected group filter
final selectedGroupProvider = StateProvider<String?>((ref) => null);

/// Filtered channels by selected group
final filteredChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final selectedGroup = ref.watch(selectedGroupProvider);
  final repository = ref.watch(playlistRepositoryProvider);

  if (selectedGroup == null) {
    final result = await repository.getAllChannels();
    return result.fold((failure) => throw Exception(failure.message), (channels) => channels);
  }

  final result = await repository.getChannelsByGroup(selectedGroup);
  return result.fold((failure) => throw Exception(failure.message), (channels) => channels);
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
    state = result.fold((failure) => AsyncValue.error(failure.message, StackTrace.current), (playlists) => AsyncValue.data(playlists));
  }

  /// Add a playlist from Xtream Codes credentials. Translates the
  /// (server, user, pass) tuple into the underlying get.php / xmltv.php URLs
  /// so the existing M3U + EPG pipelines handle it unchanged.
  Future<void> addXtreamPlaylist({
    required String name,
    required String server,
    required String username,
    required String password,
  }) async {
    final client = XtreamClient(baseUrl: server, username: username, password: password);
    await addPlaylist(
      name: name,
      url: client.m3uUrl,
      epgUrl: client.epgUrl,
    );
  }

  Future<void> addPlaylist({required String name, required String url, String? epgUrl}) async {
    final useCase = _ref.read(addPlaylistUseCaseProvider);
    final result = await useCase(AddPlaylistParams(name: name, url: url, epgUrl: epgUrl));

    result.fold((failure) => throw Exception(failure.message), (playlist) {
      _loadPlaylists();
      _invalidateChannelProviders();

      final effectiveEpgUrl = playlist.epgUrl;
      if (effectiveEpgUrl != null && effectiveEpgUrl.isNotEmpty) {
        // Fire-and-forget with an error guard, matching refreshPlaylist: a
        // non-Exception Error from the EPG fetch/parse would otherwise be an
        // unhandled async exception.
        // Background EPG refresh errors are surfaced by the EPG notifier itself.
        Future(() => _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, effectiveEpgUrl)).catchError((Object _) => false);
      }
    });
  }

  /// Refresh playlist from remote source
  Future<void> refreshPlaylist(String playlistId) async {
    final useCase = _ref.read(refreshPlaylistUseCaseProvider);
    final result = await Future(() => useCase(playlistId));

    result.fold((failure) {
      // A cancelled refresh (playlist deleted mid-download) is dropped
      // silently; throwing here would surface an error toast for it.
      if (failure is CancelledFailure) return;
      throw Exception(failure.message);
    }, (playlist) {
      _loadPlaylists();
      _invalidateChannelProviders();
      _ref.invalidate(channelsByPlaylistProvider(playlistId));

      final epgUrl = playlist.epgUrl;
      if (epgUrl != null && epgUrl.isNotEmpty) {
        // Background EPG refresh errors are surfaced by the EPG notifier itself.
        Future(() => _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, epgUrl)).catchError((Object _) => false);
      }
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    // Abort this playlist's in-flight EPG download; the repository cancels
    // the playlist download itself inside deletePlaylist.
    _ref.read(epgRefreshNotifierProvider.notifier).cancelRefresh(playlistId);
    final useCase = _ref.read(deletePlaylistUseCaseProvider);
    final result = await useCase(playlistId);

    await result.fold((failure) async => throw Exception(failure.message), (_) async {
      // Delete orphaned EPG data for this playlist. Failure here is non-fatal:
      // the playlist row is already gone so stale EPG is harmless.
      try {
        await _ref.read(epgRepositoryProvider).deleteEpgData(playlistId);
      } catch (_) {}
      _loadPlaylists();
      _invalidateChannelProviders();
      _ref.invalidate(channelsByPlaylistProvider(playlistId));
    });
  }

  void _invalidateChannelProviders() {
    // playlistsProvider is a separate cached source of truth consumed by the
    // TV Guide fan-out and startup refresh; without this invalidation it
    // would serve the startup-time playlist list for the app's lifetime.
    _ref.invalidate(playlistsProvider);
    _ref.invalidate(allChannelsProvider);
    _ref.invalidate(channelGroupsProvider);
    _ref.invalidate(filteredChannelsProvider);
    _ref.invalidate(favoriteChannelsProvider);
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

    state = result.fold((failure) => AsyncValue.error(failure.message, StackTrace.current), (_) {
      // Only the favorites-derived providers need to recompute: star UI
      // everywhere reads favoriteIdsProvider/isFavoriteProvider. Invalidating
      // allChannels/filteredChannels here re-hydrated and re-sorted the whole
      // channel box on every star tap for no visible benefit.
      _ref.invalidate(favoriteChannelsProvider);
      return const AsyncValue.data(null);
    });
  }
}

final favoriteNotifierProvider = StateNotifierProvider<FavoriteNotifier, AsyncValue<void>>((ref) {
  return FavoriteNotifier(ref);
});

/// Set of favorite channel IDs derived once from [favoriteChannelsProvider].
/// Watching this instead of re-scanning the favorites list inside each
/// `isFavoriteProvider` call turns per-row O(N) into O(1).
final favoriteIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final favorites = await ref.watch(favoriteChannelsProvider.future);
  return favorites.map((c) => c.id).toSet();
});

/// Check if a channel is a favorite
final isFavoriteProvider = FutureProvider.autoDispose.family<bool, String>((ref, channelId) async {
  final ids = await ref.watch(favoriteIdsProvider.future);
  return ids.contains(channelId);
});

/// Recently watched channels tracking
/// Stores channel IDs in order of most recently watched (most recent first)
/// Persists to Hive for data persistence across app restarts
class RecentlyWatchedNotifier extends StateNotifier<List<String>> {
  static const int maxRecentChannels = 10;
  static const String _boxName = 'recently_watched';
  static const String _key = 'channel_ids';

  Box? _box;

  /// Completes when the Hive box has been loaded (or failed). Mutations await
  /// this so the initial persisted list can't be clobbered by an early write.
  final Completer<void> _ready = Completer<void>();

  RecentlyWatchedNotifier() : super([]) {
    _loadFromHive();
  }

  /// Load recently watched from Hive storage via the shared safeOpenBox
  /// helper, matching the rest of the codebase.
  Future<void> _loadFromHive() async {
    try {
      _box = await safeOpenBox<dynamic>(_boxName);
      final stored = _box?.get(_key);
      if (stored != null && stored is List) {
        state = List<String>.from(stored);
      }
    } catch (e) {
      debugPrint('Failed to load recently watched: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  /// Save to Hive storage. Retries the box open if the initial load failed
  /// (left _box null) and logs instead of throwing: callers fire-and-forget
  /// this, so a failed put must not become an unhandled async exception.
  Future<void> _saveToHive() async {
    try {
      _box ??= await safeOpenBox<dynamic>(_boxName);
      await _box?.put(_key, state);
    } catch (e) {
      AppLogger.warning('Failed to save recently watched: $e');
    }
  }

  /// Add a channel to recently watched (moves to front if already exists).
  /// Awaits the Hive load first so the persisted list isn't overwritten with
  /// just [channelId] when the user plays a channel during startup.
  Future<void> addChannel(String channelId) async {
    await _ready.future;
    final newList = state.where((id) => id != channelId).toList();
    newList.insert(0, channelId);

    if (newList.length > maxRecentChannels) {
      newList.removeRange(maxRecentChannels, newList.length);
    }

    state = newList;
    await _saveToHive();
  }

  /// Clear all recently watched
  Future<void> clear() async {
    await _ready.future;
    state = [];
    await _saveToHive();
  }
}

final recentlyWatchedNotifierProvider = StateNotifierProvider<RecentlyWatchedNotifier, List<String>>((ref) {
  return RecentlyWatchedNotifier();
});

/// Provider for recently watched channels (as Channel objects)
final recentlyWatchedChannelsProvider = FutureProvider<List<Channel>>((ref) async {
  final recentIds = ref.watch(recentlyWatchedNotifierProvider);
  if (recentIds.isEmpty) return [];

  final repository = ref.watch(playlistRepositoryProvider);
  final allChannelsResult = await repository.getAllChannels();

  return allChannelsResult.fold((failure) => [], (allChannels) {
    // Create a map for quick lookup
    final channelMap = {for (var c in allChannels) c.id: c};

    // Return channels in the order of recently watched
    return recentIds.map((id) => channelMap[id]).whereType<Channel>().toList();
  });
});
