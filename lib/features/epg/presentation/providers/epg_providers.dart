import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlist/domain/entities/channel.dart';
import '../../data/compute/epg_compute.dart';
import '../../data/datasources/epg_local_data_source.dart';
import '../../data/datasources/epg_remote_data_source.dart';
import '../../data/repositories/epg_repository_impl.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/epg_repository.dart';

/// Provider for EPG local data source
final epgLocalDataSourceProvider = Provider<EpgLocalDataSource>((ref) {
  return EpgLocalDataSourceImpl();
});

/// Provider for EPG remote data source
final epgRemoteDataSourceProvider = Provider<EpgRemoteDataSource>((ref) {
  return EpgRemoteDataSourceImpl();
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

/// Provider for current program of a channel
final currentProgramProvider = FutureProvider.family<Program?, ({String playlistId, String channelId})>((ref, params) async {
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.getCurrentProgram(params.playlistId, params.channelId);
  return result.fold((failure) => null, (program) => program);
});

/// Provider for next program of a channel (up next)
final nextProgramProvider = FutureProvider.family<Program?, ({String playlistId, String channelId})>((ref, params) async {
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
      // Return empty list instead of throwing for cache failures (no EPG data yet)
      // This allows the UI to show empty state instead of error
      return <Program>[];
    }, (programs) => programs);
  } catch (e) {
    // Return empty list on any error to prevent UI crash
    return <Program>[];
  }
});

/// Provider for programs grouped by channel ID (optimized for TV Guide)
/// This caches the processed data to avoid reprocessing on every rebuild
/// Uses compute isolate to process heavy data off the main thread
final programsByChannelProvider = FutureProvider.family<Map<String, List<Program>>, ({List<Program> programs, List<Channel> channels, DateTime startTime, DateTime endTime})>((ref, params) async {
  // Early return for empty data - this is valid and should not throw
  if (params.programs.isEmpty || params.channels.isEmpty) {
    if (kDebugMode) {
      debugPrint('EPG: programsByChannelProvider - empty data (programs: ${params.programs.length}, channels: ${params.channels.length})');
    }
    return <String, List<Program>>{};
  }

  // For small datasets (< 1000 programs), process synchronously to avoid isolate overhead
  // For larger datasets, use compute isolate
  final useCompute = params.programs.length > 1000;

  if (kDebugMode) {
    debugPrint('EPG: programsByChannelProvider - processing ${params.programs.length} programs, ${params.channels.length} channels (useCompute: $useCompute)');
  }

  try {
    Map<String, List<Map<String, dynamic>>> result;

    if (useCompute) {
      // Use compute isolate for heavy processing to prevent UI blocking
      // Convert to JSON for serialization (required for compute isolate)
      final channelsJson = params.channels.map((c) => channelToJson(c)).toList();
      final programsJson = params.programs.map((p) {
        return {'id': p.id, 'channelId': p.channelId, 'title': p.title, 'start': p.start.millisecondsSinceEpoch, 'end': p.end.millisecondsSinceEpoch, 'subtitle': p.subtitle, 'description': p.description, 'category': p.category, 'iconUrl': p.iconUrl, 'episodeNum': p.episodeNum, 'rating': p.rating, 'isNew': p.isNew, 'isLive': p.isLive, 'isPremiere': p.isPremiere};
      }).toList();

      // Process in isolate with timeout to prevent hanging
      result = await compute(groupProgramsByChannel, GroupProgramsParams(programsJson: programsJson, channelsJson: channelsJson, startTimeMs: params.startTime.millisecondsSinceEpoch, endTimeMs: params.endTime.millisecondsSinceEpoch)).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            debugPrint('EPG: compute isolate timed out, falling back to sync processing');
          }
          throw TimeoutException('Program grouping timed out after 30 seconds', const Duration(seconds: 30));
        },
      );
    } else {
      // Process synchronously for small datasets (faster, no isolate overhead)
      result = _groupProgramsByChannelSync(params.programs, params.channels, params.startTime, params.endTime);
    }

    // Convert result back to Program objects
    final map = <String, List<Program>>{};
    for (final entry in result.entries) {
      map[entry.key] = entry.value.map((json) {
        return Program(id: json['id'] as String, channelId: json['channelId'] as String, title: json['title'] as String, start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int), end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int), subtitle: json['subtitle'] as String?, description: json['description'] as String?, category: json['category'] as String?, iconUrl: json['iconUrl'] as String?, episodeNum: json['episodeNum'] as String?, rating: json['rating'] as String?, isNew: json['isNew'] as bool? ?? false, isLive: json['isLive'] as bool? ?? false, isPremiere: json['isPremiere'] as bool? ?? false);
      }).toList();
    }

    if (kDebugMode) {
      debugPrint('EPG: programsByChannelProvider - completed, ${map.length} channels with programs');
    }

    return map;
  } catch (e) {
    // If compute fails, try to process synchronously as fallback
    if (kDebugMode) {
      debugPrint('EPG: compute failed, using sync fallback: $e');
    }

    try {
      // Fallback: process on main thread (slower but works)
      final result = _groupProgramsByChannelSync(params.programs, params.channels, params.startTime, params.endTime);

      // Convert result back to Program objects
      final map = <String, List<Program>>{};
      for (final entry in result.entries) {
        map[entry.key] = entry.value.map((json) {
          return Program(id: json['id'] as String, channelId: json['channelId'] as String, title: json['title'] as String, start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int), end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int), subtitle: json['subtitle'] as String?, description: json['description'] as String?, category: json['category'] as String?, iconUrl: json['iconUrl'] as String?, episodeNum: json['episodeNum'] as String?, rating: json['rating'] as String?, isNew: json['isNew'] as bool? ?? false, isLive: json['isLive'] as bool? ?? false, isPremiere: json['isPremiere'] as bool? ?? false);
        }).toList();
      }

      return map;
    } catch (fallbackError) {
      // If fallback also fails, return empty map
      if (kDebugMode) {
        debugPrint('EPG grouping error (compute and fallback failed): $e');
        debugPrint('Fallback error: $fallbackError');
      }
      return <String, List<Program>>{};
    }
  }
});

/// Synchronous version of groupProgramsByChannel for small datasets or fallback
Map<String, List<Map<String, dynamic>>> _groupProgramsByChannelSync(List<Program> programs, List<Channel> channels, DateTime startTime, DateTime endTime) {
  final map = <String, List<Map<String, dynamic>>>{};
  final epgIdToChannelId = <String, String>{};

  for (final channel in channels) {
    final epgId = channel.epgId;
    epgIdToChannelId[epgId] = channel.id;
    if (channel.tvgId != null && channel.tvgId != epgId) {
      epgIdToChannelId[channel.tvgId!] = channel.id;
    }
    epgIdToChannelId[channel.id] = channel.id;
  }

  final filteredPrograms = programs.where((p) => p.end.isAfter(startTime) && p.start.isBefore(endTime)).toList();

  for (final program in filteredPrograms) {
    final matchedChannelId = epgIdToChannelId[program.channelId];
    if (matchedChannelId != null) {
      final list = map.putIfAbsent(matchedChannelId, () => <Map<String, dynamic>>[]);
      list.add({'id': program.id, 'channelId': program.channelId, 'title': program.title, 'start': program.start.millisecondsSinceEpoch, 'end': program.end.millisecondsSinceEpoch, 'subtitle': program.subtitle, 'description': program.description, 'category': program.category, 'iconUrl': program.iconUrl, 'episodeNum': program.episodeNum, 'rating': program.rating, 'isNew': program.isNew, 'isLive': program.isLive, 'isPremiere': program.isPremiere});
    }
  }

  // Sort programs by start time for each channel
  for (final key in map.keys) {
    map[key]!.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
  }

  return map;
}

/// Provider for checking if EPG data is valid
final hasValidEpgDataProvider = FutureProvider.family<bool, String>((ref, playlistId) async {
  final repository = ref.read(epgRepositoryProvider);
  final result = await repository.hasValidEpgData(playlistId);
  return result.fold((failure) => false, (hasData) => hasData);
});

/// State notifier for EPG refresh operations
class EpgRefreshNotifier extends StateNotifier<AsyncValue<void>> {
  final EpgRepository _repository;

  EpgRefreshNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Refresh EPG data from remote source
  /// Network fetch and XML parsing run in background threads to prevent UI blocking
  /// XML parsing uses compute isolate (handled in xmltv_parser.dart)
  Future<void> refreshEpg(String playlistId, String url) async {
    state = const AsyncValue.loading();

    // Schedule the fetch operation to run asynchronously
    // This ensures the main thread remains responsive
    final result = await Future(() => _repository.fetchAndStoreEpg(playlistId, url));

    state = result.fold((failure) => AsyncValue.error(failure.message, StackTrace.current), (_) => const AsyncValue.data(null));
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
