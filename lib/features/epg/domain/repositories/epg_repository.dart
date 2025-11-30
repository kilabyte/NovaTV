import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/epg_channel.dart';
import '../entities/epg_data.dart';
import '../entities/program.dart';

/// Repository interface for EPG operations
abstract class EpgRepository {
  /// Fetch and store EPG data from a URL
  Future<Either<Failure, EpgData>> fetchAndStoreEpg(String playlistId, String url);

  /// Get all programs for a playlist
  Future<Either<Failure, List<Program>>> getPrograms(String playlistId);

  /// Get programs for a specific channel
  Future<Either<Failure, List<Program>>> getProgramsForChannel(
    String playlistId,
    String channelId,
  );

  /// Get programs for a time range
  Future<Either<Failure, List<Program>>> getProgramsInRange(
    String playlistId,
    DateTime start,
    DateTime end,
  );

  /// Get current program for a channel
  Future<Either<Failure, Program?>> getCurrentProgram(
    String playlistId,
    String channelId,
  );

  /// Get EPG channels
  Future<Either<Failure, List<EpgChannel>>> getEpgChannels(String playlistId);

  /// Check if EPG data exists and is fresh
  Future<Either<Failure, bool>> hasValidEpgData(String playlistId, {int maxAgeHours = 24});

  /// Delete EPG data for a playlist
  Future<Either<Failure, void>> deleteEpgData(String playlistId);

  /// Clean up old programs
  Future<Either<Failure, void>> cleanupOldPrograms({int daysToKeep = 7});
}
