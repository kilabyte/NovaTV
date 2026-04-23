import 'package:hive_ce/hive.dart';

import '../../features/epg/data/models/epg_metadata_model.dart';
import '../../features/epg/data/models/program_model.dart';
import '../../features/playlist/data/models/channel_model.dart';
import '../utils/app_logger.dart';
import 'hive_index_helper.dart';
import 'hive_storage.dart';

/// Service for managing Hive indexes
/// Builds and maintains indexes for frequently queried fields
class IndexService {
  static const String _channelsBoxName = 'channels';
  static const String _programsBoxPrefix = 'epg_programs_';

  /// Build all indexes on app startup
  /// This should be called after Hive is initialized
  static Future<void> buildAllIndexes() async {
    AppLogger.info('Building Hive indexes on startup...');
    final stopwatch = Stopwatch()..start();

    try {
      // Build channel indexes
      await _buildChannelIndexes();

      // Build EPG program indexes for all playlists
      await _buildEpgIndexes();

      stopwatch.stop();
      AppLogger.info('Index building completed in ${stopwatch.elapsedMilliseconds}ms');
    } catch (e) {
      AppLogger.error('Error building indexes: $e');
      // Don't throw - indexes are optional optimizations
    }
  }

  /// Validate and rebuild indexes if needed on app resume
  /// Checks if indexes exist and are up-to-date, rebuilds if missing or stale
  static Future<void> validateIndexesOnResume() async {
    AppLogger.debug('Validating indexes on app resume...');
    final stopwatch = Stopwatch()..start();

    try {
      bool needsRebuild = false;

      // Check channel indexes
      if (await Hive.boxExists(_channelsBoxName)) {
        final box = await safeOpenBox<ChannelModel>(_channelsBoxName);
        if (box.isNotEmpty) {
          // Check if group index exists
          if (!await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'group')) {
            AppLogger.debug('Channel group index missing, will rebuild');
            needsRebuild = true;
          }
          // Check if favorite index exists
          if (!await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'isFavorite')) {
            AppLogger.debug('Channel favorite index missing, will rebuild');
            needsRebuild = true;
          }
        }
      }

      // Check EPG program indexes
      if (await Hive.boxExists('epg_metadata')) {
        final metadataBox = await safeOpenBox<EpgMetadataModel>('epg_metadata');
        for (final key in metadataBox.keys) {
          final playlistId = key.toString();
          final programsBoxName = '$_programsBoxPrefix$playlistId';

          if (await Hive.boxExists(programsBoxName)) {
            final box = await safeOpenBox<ProgramModel>(programsBoxName);
            if (box.isNotEmpty) {
              // Check if channelId index exists
              if (!await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'channelId')) {
                AppLogger.debug('Program channelId index missing for $playlistId, will rebuild');
                needsRebuild = true;
              }
              // Check if startDate index exists
              if (!await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'startDate')) {
                AppLogger.debug('Program startDate index missing for $playlistId, will rebuild');
                needsRebuild = true;
              }
            }
          }
        }
      }

      if (needsRebuild) {
        AppLogger.info('Indexes need rebuilding, starting rebuild...');
        await buildAllIndexes();
      } else {
        stopwatch.stop();
        AppLogger.debug('All indexes validated in ${stopwatch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      AppLogger.warning('Error validating indexes on resume: $e');
      // Don't throw - indexes are optional optimizations
    }
  }

  /// Build indexes for channels, skipping when they already exist (warm
  /// launches shouldn't pay to rebuild indexes that are still valid).
  static Future<void> _buildChannelIndexes() async {
    try {
      if (!await Hive.boxExists(_channelsBoxName)) {
        return;
      }

      final box = await safeOpenBox<ChannelModel>(_channelsBoxName);
      if (box.isEmpty) {
        return;
      }

      final groupExists = await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'group');
      final favExists = await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'isFavorite');
      if (groupExists && favExists) {
        AppLogger.debug('Channel indexes already exist, skipping rebuild');
        return;
      }

      AppLogger.debug('Building channel indexes...');

      if (!groupExists) {
        await HiveIndexHelper.buildIndex<ChannelModel>(baseBoxName: _channelsBoxName, fieldName: 'group', getFieldValue: (c) => c.group ?? '', getKey: (c) => c.id);
      }

      if (!favExists) {
        // Return '' for non-favorites so buildIndex's skip-empty branch keeps
        // the index sparse; matches PlaylistLocalDataSourceImpl's convention.
        await HiveIndexHelper.buildIndex<ChannelModel>(baseBoxName: _channelsBoxName, fieldName: 'isFavorite', getFieldValue: (c) => c.isFavorite ? 'true' : '', getKey: (c) => c.id);
      }

      AppLogger.debug('Channel indexes built successfully');
    } catch (e) {
      AppLogger.warning('Failed to build channel indexes: $e');
    }
  }

  /// Build indexes for EPG programs
  /// Finds all program boxes and builds indexes for each playlist
  static Future<void> _buildEpgIndexes() async {
    try {
      // Find all program boxes (they follow the pattern: epg_programs_<playlistId>)
      // We need to scan for existing boxes or get playlist IDs from metadata
      if (!await Hive.boxExists('epg_metadata')) {
        return;
      }

      final metadataBox = await safeOpenBox('epg_metadata');

      if (metadataBox.isEmpty) {
        return;
      }

      AppLogger.debug('Building EPG program indexes...');

      int playlistCount = 0;
      for (final key in metadataBox.keys) {
        final playlistId = key.toString();
        final programsBoxName = '$_programsBoxPrefix$playlistId';

        if (await Hive.boxExists(programsBoxName)) {
          await _buildProgramIndexesForPlaylist(programsBoxName);
          playlistCount++;
        }
      }

      AppLogger.debug('EPG indexes built for $playlistCount playlist(s)');
    } catch (e) {
      AppLogger.warning('Failed to build EPG indexes: $e');
    }
  }

  /// Build indexes for programs in a specific playlist. Skips when both
  /// indexes already exist to avoid re-scanning 100MB+ program boxes on
  /// every warm launch.
  static Future<void> _buildProgramIndexesForPlaylist(String programsBoxName) async {
    try {
      final box = await safeOpenBox<ProgramModel>(programsBoxName);
      if (box.isEmpty) {
        return;
      }

      final channelIdExists = await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'channelId');
      final startDateExists = await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'startDate');
      if (channelIdExists && startDateExists) {
        return;
      }

      if (!channelIdExists) {
        // Lowercased to match HiveIndexHelper.getIndexedKeys normalization.
        await HiveIndexHelper.buildIndex<ProgramModel>(baseBoxName: programsBoxName, fieldName: 'channelId', getFieldValue: (p) => p.channelId.toLowerCase(), getKey: (p) => p.id);
      }

      if (!startDateExists) {
        // Use date as key (YYYYMMDD format) for efficient range queries.
        await HiveIndexHelper.buildIndex<ProgramModel>(
          baseBoxName: programsBoxName,
          fieldName: 'startDate',
          getFieldValue: (p) {
            final date = p.start;
            return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
          },
          getKey: (p) => p.id,
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to build indexes for $programsBoxName: $e');
    }
  }

  /// Get index statistics for monitoring
  static Future<IndexStatistics> getStatistics() async {
    final stats = IndexStatistics();

    try {
      // Channel indexes
      if (await Hive.boxExists(_channelsBoxName)) {
        final box = await safeOpenBox<ChannelModel>(_channelsBoxName);
        stats.totalChannels = box.length;

        // Check group index
        if (await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'group')) {
          final indexBox = await safeOpenBox<List<dynamic>>('${_channelsBoxName}_index_group');
          stats.channelGroupIndexEntries = indexBox.length;
        }

        // Check isFavorite index
        if (await HiveIndexHelper.indexExists(baseBoxName: _channelsBoxName, fieldName: 'isFavorite')) {
          final indexBox = await safeOpenBox<List<dynamic>>('${_channelsBoxName}_index_isFavorite');
          stats.channelFavoriteIndexEntries = indexBox.length;
        }
      }

      // EPG program indexes
      if (await Hive.boxExists('epg_metadata')) {
        final metadataBox = await safeOpenBox('epg_metadata');
        for (final key in metadataBox.keys) {
          final playlistId = key.toString();
          final programsBoxName = '$_programsBoxPrefix$playlistId';

          if (await Hive.boxExists(programsBoxName)) {
            final box = await safeOpenBox<ProgramModel>(programsBoxName);
            stats.totalPrograms += box.length;
            stats.programBoxesCount++;

            // Check channelId index
            if (await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'channelId')) {
              final indexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_channelId');
              stats.programChannelIndexEntries += indexBox.length;
            }

            // Check startDate index
            if (await HiveIndexHelper.indexExists(baseBoxName: programsBoxName, fieldName: 'startDate')) {
              final indexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_startDate');
              stats.programDateIndexEntries += indexBox.length;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Error getting index statistics: $e');
    }

    return stats;
  }
}

/// Statistics about Hive indexes
class IndexStatistics {
  int totalChannels = 0;
  int channelGroupIndexEntries = 0;
  int channelFavoriteIndexEntries = 0;
  int totalPrograms = 0;
  int programBoxesCount = 0;
  int programChannelIndexEntries = 0;
  int programDateIndexEntries = 0;

  /// Get a summary string
  String getSummary() {
    final buffer = StringBuffer();
    buffer.writeln('Hive Index Statistics:');
    buffer.writeln('  Channels: $totalChannels');
    buffer.writeln('  - Group index entries: $channelGroupIndexEntries');
    buffer.writeln('  - Favorite index entries: $channelFavoriteIndexEntries');
    buffer.writeln('  Programs: $totalPrograms (across $programBoxesCount playlist(s))');
    buffer.writeln('  - ChannelId index entries: $programChannelIndexEntries');
    buffer.writeln('  - StartDate index entries: $programDateIndexEntries');
    return buffer.toString();
  }

  /// Get index coverage percentage
  double getChannelGroupIndexCoverage() {
    if (totalChannels == 0) return 0.0;
    return (channelGroupIndexEntries / totalChannels) * 100;
  }

  /// Get favorite index coverage
  double getChannelFavoriteIndexCoverage() {
    if (totalChannels == 0) return 0.0;
    return (channelFavoriteIndexEntries / totalChannels) * 100;
  }
}
