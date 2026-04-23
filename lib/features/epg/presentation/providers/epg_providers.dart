import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../playlist/presentation/providers/playlist_providers.dart' show dioProvider, playlistsProvider;
import '../../data/datasources/epg_local_data_source.dart';
import '../../data/datasources/epg_remote_data_source.dart';
import '../../data/repositories/epg_repository_impl.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/epg_repository.dart';

/// Provider for EPG local data source
final epgLocalDataSourceProvider = Provider<EpgLocalDataSource>((ref) {
  return EpgLocalDataSourceImpl();
});

/// Provider for EPG remote data source.
/// Uses the app-wide Dio instance so EPG fetches share the same timeouts as
/// M3U fetches; previously this created a fresh Dio() with zero timeouts and
/// stalled EPG URLs could hang forever.
final epgRemoteDataSourceProvider = Provider<EpgRemoteDataSource>((ref) {
  return EpgRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

/// Provider for EPG repository
final epgRepositoryProvider = Provider<EpgRepository>((ref) {
  return EpgRepositoryImpl(localDataSource: ref.watch(epgLocalDataSourceProvider), remoteDataSource: ref.watch(epgRemoteDataSourceProvider));
});

/// Provider for fetching EPG data
final epgFetchProvider = FutureProvider.family<void, ({String playlistId, String url})>((ref, params) async {
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.fetchAndStoreEpg(params.playlistId, params.url);
  return result.fold((failure) => throw Exception(failure.message), (_) {});
});

/// Provider for programs of a specific channel
final channelProgramsProvider = FutureProvider.family<List<Program>, ({String playlistId, String channelId})>((ref, params) async {
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.getProgramsForChannel(params.playlistId, params.channelId);
  return result.fold((failure) => throw Exception(failure.message), (programs) => programs);
});

/// Minute-granularity tick provider so "current program" / "next program"
/// re-evaluate as time advances without the whole widget tree rebuilding
/// every second. Consumers that depend on wall-clock should `watch` this.
final minuteTickProvider = StreamProvider<DateTime>((ref) async* {
  // Emit immediately, then every minute aligned to the next minute boundary.
  yield DateTime.now();
  while (true) {
    final now = DateTime.now();
    final delay = Duration(
      seconds: 60 - now.second,
      milliseconds: -now.millisecond,
    );
    await Future<void>.delayed(delay);
    yield DateTime.now();
  }
});

/// Programs from every playlist in a given time range, merged.
/// Use when the caller doesn't care which playlist a program came from — e.g.
/// the TV Guide displays channels from all playlists and needs programs for
/// every one of them.
final programsInRangeAllPlaylistsProvider =
    FutureProvider.autoDispose.family<List<Program>, ({DateTime start, DateTime end})>((ref, params) async {
  final playlists = await ref.watch(playlistsProvider.future);
  if (playlists.isEmpty) return const <Program>[];
  final repo = ref.read(epgRepositoryProvider);

  // Parallel-fan-out: with 2+ playlists serial waits add up. Hive reads are
  // I/O-light but each call may hit a different on-disk box; `Future.wait`
  // gives us overlap without touching the repo internals.
  final perPlaylist = await Future.wait(playlists.map(
    (p) => repo.getProgramsInRange(p.id, params.start, params.end),
  ));

  final results = <Program>[];
  for (var i = 0; i < perPlaylist.length; i++) {
    perPlaylist[i].fold(
      (failure) => AppLogger.warning(
          'programsInRange for ${playlists[i].id} failed: ${failure.message}'),
      (list) => results.addAll(list),
    );
  }
  return results;
});

/// Map of channelId → the currently-airing [Program] for one playlist.
///
/// Instead of each visible channel row doing its own Hive round-trip through
/// [currentProgramProvider], a single fetch populates the map and every row
/// reads from the same cache. On a 2000-channel TV Guide this turns 2000
/// Hive reads/minute into one. Refreshes every minute via [minuteTickProvider].
final currentProgramsProvider = FutureProvider.autoDispose
    .family<Map<String, Program>, String>((ref, playlistId) async {
  ref.watch(minuteTickProvider);
  if (playlistId.isEmpty) return const {};
  final repository = ref.read(epgRepositoryProvider);
  final now = DateTime.now();
  final result = await repository.getProgramsInRange(
    playlistId,
    now.subtract(const Duration(hours: 6)),
    now.add(const Duration(hours: 6)),
  );
  return result.fold(
    (_) => const <String, Program>{},
    (programs) {
      final map = <String, Program>{};
      for (final p in programs) {
        if (p.start.isBefore(now) && p.end.isAfter(now)) {
          map[p.channelId.toLowerCase()] = p;
        }
      }
      return map;
    },
  );
});

/// Provider for current program of a channel
final currentProgramProvider = FutureProvider.autoDispose.family<Program?, ({String playlistId, String channelId})>((ref, params) async {
  // Re-evaluate every minute so the "NOW" program stays in sync with wall time.
  ref.watch(minuteTickProvider);
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.getCurrentProgram(params.playlistId, params.channelId);
  return result.fold((failure) => null, (program) => program);
});

/// Provider for next program of a channel (up next)
final nextProgramProvider = FutureProvider.autoDispose.family<Program?, ({String playlistId, String channelId})>((ref, params) async {
  ref.watch(minuteTickProvider);
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.getProgramsForChannel(params.playlistId, params.channelId);
  return result.fold((failure) => null, (programs) {
    final now = DateTime.now();
    // Sort programs by start time and find the first one that starts after now
    final sortedPrograms = [...programs]..sort((a, b) => a.start.compareTo(b.start));
    for (final program in sortedPrograms) {
      if (program.start.isAfter(now)) {
        return program;
      }
    }
    return null;
  });
});

/// Provider for programs in a time range
final programsInRangeProvider = FutureProvider.family<List<Program>, ({String playlistId, DateTime start, DateTime end})>((ref, params) async {
  // Early return for empty playlistId
  if (params.playlistId.isEmpty) {
    return <Program>[];
  }

  try {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.getProgramsInRange(params.playlistId, params.start, params.end);
    return result.fold((failure) {
      // Cache miss (no EPG yet) is expected; log anything else.
      AppLogger.warning('programsInRange failed for ${params.playlistId}: ${failure.message}');
      return <Program>[];
    }, (programs) => programs);
  } catch (e, st) {
    AppLogger.error('programsInRange threw for ${params.playlistId}: $e', e, st);
    return <Program>[];
  }
});

/// Provider for checking if EPG data is valid
final hasValidEpgDataProvider = FutureProvider.family<bool, String>((ref, playlistId) async {
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.hasValidEpgData(playlistId);
  return result.fold((failure) => false, (hasData) => hasData);
});

/// State notifier for EPG refresh operations
class EpgRefreshNotifier extends StateNotifier<AsyncValue<void>> {
  final EpgRepository _repository;

  /// In-flight refreshes keyed by playlistId. Used to dedupe concurrent
  /// refresh requests so two callers don't race clear() + putAll() on the
  /// same EPG box and corrupt stored data.
  final Map<String, Future<void>> _inFlight = {};

  EpgRefreshNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Refresh EPG data from remote source
  /// Network fetch and XML parsing run in background threads to prevent UI blocking
  /// XML parsing uses compute isolate (handled in xmltv_parser.dart)
  Future<void> refreshEpg(String playlistId, String url) async {
    final existing = _inFlight[playlistId];
    if (existing != null) return existing;

    state = const AsyncValue.loading();
    final future = _doRefresh(playlistId, url);
    _inFlight[playlistId] = future;
    try {
      await future;
    } finally {
      _inFlight.remove(playlistId);
    }
  }

  Future<void> _doRefresh(String playlistId, String url) async {
    final result = await Future(() => _repository.fetchAndStoreEpg(playlistId, url));
    if (!mounted) return;
    state = result.fold(
      (failure) => AsyncValue.error(failure.message, StackTrace.current),
      (_) => const AsyncValue.data(null),
    );
  }

  Future<void> cleanupOldPrograms({int daysToKeep = 7}) async {
    await _repository.cleanupOldPrograms(daysToKeep: daysToKeep);
  }
}

/// Provider for EPG refresh notifier
final epgRefreshNotifierProvider = StateNotifierProvider<EpgRefreshNotifier, AsyncValue<void>>((ref) {
  return EpgRefreshNotifier(ref.watch(epgRepositoryProvider));
});

/// Selected time slot for the TV guide
final selectedTimeSlotProvider = StateProvider<DateTime>((ref) {
  // Start at the beginning of the current hour
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour);
});

/// Selected date for the TV guide
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Trigger provider for "Go to Now" in TV Guide
/// Increment this value to trigger the TV Guide to scroll to current time
/// Used when: navigating to Guide tab, after EPG refresh, after playlist refresh
final goToNowTriggerProvider = StateProvider<int>((ref) => 0);
