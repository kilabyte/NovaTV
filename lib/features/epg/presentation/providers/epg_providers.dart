import 'package:flutter_riverpod/flutter_riverpod.dart';

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
