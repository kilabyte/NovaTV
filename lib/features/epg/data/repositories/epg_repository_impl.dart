import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/epg_data.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/epg_repository.dart';
import '../datasources/epg_local_data_source.dart';
import '../datasources/epg_remote_data_source.dart';

class EpgRepositoryImpl implements EpgRepository {
  final EpgLocalDataSource _localDataSource;
  final EpgRemoteDataSource _remoteDataSource;

  EpgRepositoryImpl({
    required EpgLocalDataSource localDataSource,
    required EpgRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, EpgData>> fetchAndStoreEpg(String playlistId, String url) async {
    try {
      // Fetch EPG data from remote
      final epgData = await _remoteDataSource.fetchEpg(url);

      // Store locally
      await _localDataSource.saveEpgData(
        playlistId: playlistId,
        sourceUrl: url,
        generatedAt: epgData.generatedAt,
        channels: epgData.channels,
        programs: epgData.programs,
      );

      return Right(epgData);
    } on Exception catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Program>>> getPrograms(String playlistId) async {
    try {
      final programs = await _localDataSource.getPrograms(playlistId);
      return Right(programs);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Program>>> getProgramsForChannel(
    String playlistId,
    String channelId,
  ) async {
    try {
      final programs = await _localDataSource.getProgramsForChannel(playlistId, channelId);
      return Right(programs);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Program>>> getProgramsInRange(
    String playlistId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final programs = await _localDataSource.getProgramsInRange(playlistId, start, end);
      return Right(programs);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Program?>> getCurrentProgram(
    String playlistId,
    String channelId,
  ) async {
    try {
      final program = await _localDataSource.getCurrentProgram(playlistId, channelId);
      return Right(program);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<EpgChannel>>> getEpgChannels(String playlistId) async {
    try {
      final channels = await _localDataSource.getEpgChannels(playlistId);
      return Right(channels);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> hasValidEpgData(String playlistId, {int maxAgeHours = 24}) async {
    try {
      final metadata = await _localDataSource.getEpgMetadata(playlistId);
      if (metadata == null) {
        return const Right(false);
      }

      final age = DateTime.now().difference(metadata.fetchedAt);
      return Right(age.inHours < maxAgeHours);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEpgData(String playlistId) async {
    try {
      await _localDataSource.deleteEpgData(playlistId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cleanupOldPrograms({int daysToKeep = 7}) async {
    try {
      await _localDataSource.cleanupOldPrograms(daysToKeep: daysToKeep);
      return const Right(null);
    } on Exception catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
