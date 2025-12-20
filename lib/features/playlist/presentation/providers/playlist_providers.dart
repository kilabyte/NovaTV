import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

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
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Combined search results provider that searches both channels and EPG programs
final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty || query.length < 2) return [];

  final results = <SearchResult>[];
  final seenChannelIds = <String>{};

  // Search channels first
  final channelUseCase = ref.watch(searchChannelsUseCaseProvider);
  final channelResult = await channelUseCase(query);
  channelResult.fold((failure) {}, (channels) {
    for (final channel in channels) {
      results.add(ChannelSearchResult(channel));
      seenChannelIds.add(channel.id);
    }
  });

  // Search EPG programs
  final epgLocalDataSource = ref.watch(epgLocalDataSourceProvider);
  final playlistRepository = ref.watch(playlistRepositoryProvider);

  // Get all playlists to search their EPG data
  final playlistsResult = await playlistRepository.getPlaylists();
  await playlistsResult.fold((failure) async {}, (playlists) async {
    // Get all channels for mapping program results
    final allChannelsResult = await playlistRepository.getAllChannels();
    final allChannels = allChannelsResult.fold((failure) => <Channel>[], (channels) => channels);

    // Create a map of EPG channel ID to Channel for quick lookup
    final channelByEpgId = <String, Channel>{};
    for (final channel in allChannels) {
      channelByEpgId[channel.epgId] = channel;
    }

    for (final playlist in playlists) {
      final programs = await epgLocalDataSource.searchPrograms(playlist.id, query);

      for (final program in programs) {
        // Find the channel for this program
        final channel = channelByEpgId[program.channelId];
        if (channel != null && !seenChannelIds.contains(channel.id)) {
          results.add(ProgramSearchResult(program: program, channel: channel));
          // Only add first program match per channel to avoid duplicates
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

  Future<void> addPlaylist({required String name, required String url, String? epgUrl}) async {
    final useCase = _ref.read(addPlaylistUseCaseProvider);
    final result = await useCase(AddPlaylistParams(name: name, url: url, epgUrl: epgUrl));

    result.fold((failure) => throw Exception(failure.message), (playlist) {
      _loadPlaylists();
      // Invalidate related providers
      _ref.invalidate(allChannelsProvider);
      _ref.invalidate(channelGroupsProvider);

      // Auto-refresh EPG if an EPG URL is available
      final effectiveEpgUrl = playlist.epgUrl;
      if (effectiveEpgUrl != null && effectiveEpgUrl.isNotEmpty) {
        _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, effectiveEpgUrl);
      }
    });
  }

  /// Refresh playlist from remote source
  /// Network fetch and M3U parsing run in background threads to prevent UI blocking
  /// M3U parsing uses compute isolate (handled in playlist_repository_impl.dart)
  Future<void> refreshPlaylist(String playlistId) async {
    // Schedule the refresh operation to run asynchronously
    // This ensures the main thread remains responsive
    final useCase = _ref.read(refreshPlaylistUseCaseProvider);
    final result = await Future(() => useCase(playlistId));

    result.fold((failure) => throw Exception(failure.message), (playlist) {
      _loadPlaylists();
      _ref.invalidate(allChannelsProvider);
      _ref.invalidate(channelGroupsProvider);
      _ref.invalidate(channelsByPlaylistProvider(playlistId));

      // Also refresh EPG if available (runs in background)
      final epgUrl = playlist.epgUrl;
      if (epgUrl != null && epgUrl.isNotEmpty) {
        // Schedule EPG refresh to run asynchronously
        Future(() => _ref.read(epgRefreshNotifierProvider.notifier).refreshEpg(playlist.id, epgUrl)).catchError((error) {
          // Silently handle EPG refresh errors - it's a background operation
        });
      }
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    final useCase = _ref.read(deletePlaylistUseCaseProvider);
    final result = await useCase(playlistId);

    result.fold((failure) => throw Exception(failure.message), (_) {
      _loadPlaylists();
      _ref.invalidate(allChannelsProvider);
      _ref.invalidate(channelGroupsProvider);
    });
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
      _ref.invalidate(favoriteChannelsProvider);
      _ref.invalidate(allChannelsProvider);
      return const AsyncValue.data(null);
    });
  }
}

final favoriteNotifierProvider = StateNotifierProvider<FavoriteNotifier, AsyncValue<void>>((ref) {
  return FavoriteNotifier(ref);
});

/// Check if a channel is a favorite
final isFavoriteProvider = FutureProvider.family<bool, String>((ref, channelId) async {
  final favorites = await ref.watch(favoriteChannelsProvider.future);
  return favorites.any((channel) => channel.id == channelId);
});

/// Toggle favorite for a channel (returns a provider that triggers the toggle)
final toggleFavoriteProvider = Provider.family<void, String>((ref, channelId) {
  ref.read(favoriteNotifierProvider.notifier).toggleFavorite(channelId);
});

/// Recently watched channels tracking
/// Stores channel IDs in order of most recently watched (most recent first)
/// Persists to Hive for data persistence across app restarts
class RecentlyWatchedNotifier extends StateNotifier<List<String>> {
  static const int maxRecentChannels = 10;
  static const String _boxName = 'recently_watched';
  static const String _key = 'channel_ids';

  Box? _box;

  RecentlyWatchedNotifier() : super([]) {
    _loadFromHive();
  }

  /// Load recently watched from Hive storage
  Future<void> _loadFromHive() async {
    try {
      _box = await _safeOpenBox(_boxName);
      final stored = _box?.get(_key);
      if (stored != null && stored is List) {
        state = List<String>.from(stored);
      }
    } catch (e) {
      // Silently fail - recently watched is not critical
      debugPrint('Failed to load recently watched: $e');
    }
  }

  /// Safely open a Hive box with retry logic
  Future<Box> _safeOpenBox(String boxName) async {
    const maxRetries = 3;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          return Hive.box(boxName);
        }
        return await Hive.openBox(boxName);
      } catch (e) {
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          if (Hive.isBoxOpen(boxName)) {
            try {
              await Hive.box(boxName).close();
            } catch (_) {}
          }
        } else {
          rethrow;
        }
      }
    }
    throw Exception('Failed to open box $boxName');
  }

  /// Save to Hive storage
  Future<void> _saveToHive() async {
    await _box?.put(_key, state);
  }

  /// Add a channel to recently watched (moves to front if already exists)
  void addChannel(String channelId) {
    final newList = state.where((id) => id != channelId).toList();
    newList.insert(0, channelId);

    // Keep only the most recent N channels
    if (newList.length > maxRecentChannels) {
      newList.removeRange(maxRecentChannels, newList.length);
    }

    state = newList;
    _saveToHive();
  }

  /// Clear all recently watched
  void clear() {
    state = [];
    _saveToHive();
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
