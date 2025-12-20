import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playlist/domain/entities/channel.dart';
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
  return EpgRepositoryImpl(
    localDataSource: ref.watch(epgLocalDataSourceProvider),
    remoteDataSource: ref.watch(epgRemoteDataSourceProvider),
  );
});

/// Provider for fetching EPG data
final epgFetchProvider = FutureProvider.family<void, ({String playlistId, String url})>(
  (ref, params) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.fetchAndStoreEpg(params.playlistId, params.url);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (_) {},
    );
  },
);

/// Provider for programs of a specific channel
final channelProgramsProvider = FutureProvider.family<List<Program>, ({String playlistId, String channelId})>(
  (ref, params) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.getProgramsForChannel(params.playlistId, params.channelId);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (programs) => programs,
    );
  },
);

/// Provider for current program of a channel
final currentProgramProvider = FutureProvider.family<Program?, ({String playlistId, String channelId})>(
  (ref, params) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.getCurrentProgram(params.playlistId, params.channelId);
    return result.fold(
      (failure) => null,
      (program) => program,
    );
  },
);

/// Provider for next program of a channel (up next)
final nextProgramProvider = FutureProvider.family<Program?, ({String playlistId, String channelId})>(
  (ref, params) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.getProgramsForChannel(params.playlistId, params.channelId);
    return result.fold(
      (failure) => null,
      (programs) {
        final now = DateTime.now();
        // Sort programs by start time and find the first one that starts after now
        final sortedPrograms = [...programs]..sort((a, b) => a.start.compareTo(b.start));
        for (final program in sortedPrograms) {
          if (program.start.isAfter(now)) {
            return program;
          }
        }
        return null;
      },
    );
  },
);

/// Provider for programs in a time range
final programsInRangeProvider = FutureProvider.family<List<Program>, ({String playlistId, DateTime start, DateTime end})>(
  (ref, params) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.getProgramsInRange(params.playlistId, params.start, params.end);
    return result.fold(
      (failure) => throw Exception(failure.message),
      (programs) => programs,
    );
  },
);

/// Provider for programs grouped by channel ID (optimized for TV Guide)
/// This caches the processed data to avoid reprocessing on every rebuild
final programsByChannelProvider = Provider.family<Map<String, List<Program>>, ({
  List<Program> programs,
  List<Channel> channels,
  DateTime startTime,
  DateTime endTime,
})>((ref, params) {
  final map = <String, List<Program>>{};
  
  // Create a mapping from epgId (tvgId or id) to channelId for fast lookup
  final epgIdToChannelId = <String, String>{};
  for (final channel in params.channels) {
    final epgId = channel.epgId; // This is tvgId ?? id
    epgIdToChannelId[epgId] = channel.id;
    // Also map tvgId directly if it exists
    if (channel.tvgId != null && channel.tvgId != epgId) {
      epgIdToChannelId[channel.tvgId!] = channel.id;
    }
    // And map id directly
    epgIdToChannelId[channel.id] = channel.id;
  }
  
  // Pre-filter programs by time range for better performance
  final filteredPrograms = params.programs.where((p) => 
    p.end.isAfter(params.startTime) && p.start.isBefore(params.endTime)
  ).toList();
  
  // Group programs by channel ID - single pass, O(n) complexity
  for (final program in filteredPrograms) {
    // program.channelId contains the tvgId from XMLTV (or sometimes the channel id)
    // Match it using epgId mapping
    final matchedChannelId = epgIdToChannelId[program.channelId];
    
    if (matchedChannelId != null) {
      final list = map.putIfAbsent(matchedChannelId, () => <Program>[]);
      list.add(program);
    }
  }
  
  // Sort programs by start time for each channel (only once, after grouping)
  for (final key in map.keys) {
    map[key]!.sort((a, b) => a.start.compareTo(b.start));
  }
  
  return map;
});

/// Provider for checking if EPG data is valid
final hasValidEpgDataProvider = FutureProvider.family<bool, String>(
  (ref, playlistId) async {
    final repository = ref.read(epgRepositoryProvider);
    final result = await repository.hasValidEpgData(playlistId);
    return result.fold(
      (failure) => false,
      (hasData) => hasData,
    );
  },
);

/// State notifier for EPG refresh operations
class EpgRefreshNotifier extends StateNotifier<AsyncValue<void>> {
  final EpgRepository _repository;

  EpgRefreshNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> refreshEpg(String playlistId, String url) async {
    state = const AsyncValue.loading();
    final result = await _repository.fetchAndStoreEpg(playlistId, url);
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
