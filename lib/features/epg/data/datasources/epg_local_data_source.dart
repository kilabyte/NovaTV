import 'package:hive_ce/hive.dart';

import '../../../../core/storage/hive_index_helper.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/program.dart';
import '../models/epg_channel_model.dart';
import '../models/epg_metadata_model.dart';
import '../models/program_model.dart';

/// Local data source for EPG data using Hive
abstract class EpgLocalDataSource {
  /// Save EPG data for a playlist
  Future<void> saveEpgData({required String playlistId, required String sourceUrl, required DateTime? generatedAt, required List<EpgChannel> channels, required List<Program> programs});

  /// Get all programs for a playlist
  Future<List<Program>> getPrograms(String playlistId);

  /// Get programs for a specific channel
  Future<List<Program>> getProgramsForChannel(String playlistId, String channelId);

  /// Get programs for a time range
  Future<List<Program>> getProgramsInRange(String playlistId, DateTime start, DateTime end);

  /// Get current program for a channel
  Future<Program?> getCurrentProgram(String playlistId, String channelId);

  /// Get EPG channels
  Future<List<EpgChannel>> getEpgChannels(String playlistId);

  /// Get EPG metadata
  Future<EpgMetadataModel?> getEpgMetadata(String playlistId);

  /// Delete EPG data for a playlist
  Future<void> deleteEpgData(String playlistId);

  /// Clean up old programs (older than specified days)
  Future<void> cleanupOldPrograms({int daysToKeep = 7});

  /// Search programs by title, description, or category
  Future<List<Program>> searchPrograms(String playlistId, String query);
}

class EpgLocalDataSourceImpl implements EpgLocalDataSource {
  static const String _programsBoxPrefix = 'epg_programs_';
  static const String _channelsBoxPrefix = 'epg_channels_';
  static const String _metadataBoxName = 'epg_metadata';

  @override
  Future<void> saveEpgData({required String playlistId, required String sourceUrl, required DateTime? generatedAt, required List<EpgChannel> channels, required List<Program> programs}) async {
    // Save programs
    final programsBox = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');
    await programsBox.clear();

    final programModels = programs.map((p) => ProgramModel.fromEntity(p)).toList();
    final programMap = {for (var p in programModels) p.id: p};
    await programsBox.putAll(programMap);

    // Save channels
    final channelsBox = await safeOpenBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
    await channelsBox.clear();

    final channelModels = channels.map((c) => EpgChannelModel.fromEntity(c)).toList();
    final channelMap = {for (var c in channelModels) c.id: c};
    await channelsBox.putAll(channelMap);

    // Save metadata
    final metadataBox = await safeOpenBox<EpgMetadataModel>(_metadataBoxName);
    final metadata = EpgMetadataModel(sourceUrl: sourceUrl, playlistId: playlistId, generatedAt: generatedAt, fetchedAt: DateTime.now(), channelCount: channels.length, programCount: programs.length);
    await metadataBox.put(playlistId, metadata);

    // Build indexes for programs (runs in background to not block save operation)
    final boxName = '$_programsBoxPrefix$playlistId';
    _buildProgramIndexes(boxName, programModels).catchError((error) {
      // Index building is optional - log but don't fail the save operation
      // Error will be logged by AppLogger if available
    });
  }

  @override
  Future<List<Program>> getPrograms(String playlistId) async {
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Program>> getProgramsForChannel(String playlistId, String channelId) async {
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');

    // Try to use index if available for faster lookup
    final indexedKeys = await HiveIndexHelper.getIndexedKeys(baseBoxName: '$_programsBoxPrefix$playlistId', fieldName: 'channelId', fieldValue: channelId);

    if (indexedKeys.isNotEmpty) {
      // Use index for fast lookup
      final programs = <Program>[];
      for (final key in indexedKeys) {
        final model = box.get(key);
        if (model != null) {
          programs.add(model.toEntity());
        }
      }
      programs.sort((a, b) => a.start.compareTo(b.start));
      return programs;
    }

    // Fallback to iteration if index doesn't exist
    final filteredPrograms = <Program>[];
    for (final model in box.values) {
      final program = model.toEntity();
      if (program.channelId == channelId) {
        filteredPrograms.add(program);
      }
    }

    filteredPrograms.sort((a, b) => a.start.compareTo(b.start));
    return filteredPrograms;
  }

  @override
  Future<List<Program>> getProgramsInRange(String playlistId, DateTime start, DateTime end) async {
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');

    // Try to use date index if available for faster lookup
    // Get all dates in the range
    final dateKeys = <String>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final dateKey = '${current.year}${current.month.toString().padLeft(2, '0')}${current.day.toString().padLeft(2, '0')}';
      dateKeys.add(dateKey);
      current = current.add(const Duration(days: 1));
    }

    // Collect keys from date index
    final indexedKeys = <dynamic>{};
    for (final dateKey in dateKeys) {
      final keys = await HiveIndexHelper.getIndexedKeys(baseBoxName: '$_programsBoxPrefix$playlistId', fieldName: 'startDate', fieldValue: dateKey);
      indexedKeys.addAll(keys);
    }

    if (indexedKeys.isNotEmpty) {
      // Use index for fast lookup, then filter by exact time range
      final programs = <Program>[];
      for (final key in indexedKeys) {
        final model = box.get(key);
        if (model != null) {
          final program = model.toEntity();
          // Filter: program overlaps with the requested range
          if (program.end.isAfter(start) && program.start.isBefore(end)) {
            programs.add(program);
          }
        }
      }
      programs.sort((a, b) => a.start.compareTo(b.start));
      return programs;
    }

    // Fallback to iteration if index doesn't exist
    final filteredPrograms = <Program>[];
    for (final model in box.values) {
      final program = model.toEntity();
      // Filter: program overlaps with the requested range
      if (program.end.isAfter(start) && program.start.isBefore(end)) {
        filteredPrograms.add(program);
      }
    }

    // Sort only the filtered results
    filteredPrograms.sort((a, b) => a.start.compareTo(b.start));
    return filteredPrograms;
  }

  @override
  Future<Program?> getCurrentProgram(String playlistId, String channelId) async {
    final programs = await getProgramsForChannel(playlistId, channelId);
    final now = DateTime.now();
    try {
      return programs.firstWhere((p) => p.start.isBefore(now) && p.end.isAfter(now));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EpgChannel>> getEpgChannels(String playlistId) async {
    final box = await safeOpenBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<EpgMetadataModel?> getEpgMetadata(String playlistId) async {
    final box = await safeOpenBox<EpgMetadataModel>(_metadataBoxName);
    return box.get(playlistId);
  }

  @override
  Future<void> deleteEpgData(String playlistId) async {
    // Delete programs
    if (await Hive.boxExists('$_programsBoxPrefix$playlistId')) {
      final programsBox = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');
      await programsBox.deleteFromDisk();
    }

    // Delete channels
    if (await Hive.boxExists('$_channelsBoxPrefix$playlistId')) {
      final channelsBox = await safeOpenBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
      await channelsBox.deleteFromDisk();
    }

    // Delete metadata
    final metadataBox = await safeOpenBox<EpgMetadataModel>(_metadataBoxName);
    await metadataBox.delete(playlistId);
  }

  @override
  Future<void> cleanupOldPrograms({int daysToKeep = 7}) async {
    final metadataBox = await safeOpenBox<EpgMetadataModel>(_metadataBoxName);
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));

    for (final metadata in metadataBox.values) {
      final programsBox = await safeOpenBox<ProgramModel>('$_programsBoxPrefix${metadata.playlistId}');

      final keysToDelete = <dynamic>[];
      for (final entry in programsBox.toMap().entries) {
        if (entry.value.end.isBefore(cutoff)) {
          keysToDelete.add(entry.key);
        }
      }

      await programsBox.deleteAll(keysToDelete);
    }
  }

  @override
  Future<List<Program>> searchPrograms(String playlistId, String query) async {
    final lowerQuery = query.toLowerCase();
    final now = DateTime.now();

    // Optimize: Filter during iteration instead of loading all programs
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');

    final results = <Program>[];
    for (final model in box.values) {
      final program = model.toEntity();

      // Skip programs that have already ended
      if (program.end.isBefore(now)) continue;

      final title = program.title.toLowerCase();
      final description = program.description?.toLowerCase() ?? '';
      final category = program.category?.toLowerCase() ?? '';

      if (title.contains(lowerQuery) || description.contains(lowerQuery) || category.contains(lowerQuery)) {
        results.add(program);
      }
    }

    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  /// Build indexes for programs in a playlist
  /// This is called after saving EPG data to maintain indexes
  Future<void> _buildProgramIndexes(String programsBoxName, List<ProgramModel> programs) async {
    try {
      // Build channelId index (most frequently queried)
      final channelIdIndex = <String, List<dynamic>>{};
      for (final program in programs) {
        final keys = channelIdIndex.putIfAbsent(program.channelId, () => <dynamic>[]);
        keys.add(program.id);
      }
      final channelIdIndexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_channelId');
      await channelIdIndexBox.clear();
      await channelIdIndexBox.putAll(channelIdIndex);

      // Build startDate index (for time range queries)
      final dateIndex = <String, List<dynamic>>{};
      for (final program in programs) {
        final date = program.start;
        final dateKey = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
        final keys = dateIndex.putIfAbsent(dateKey, () => <dynamic>[]);
        keys.add(program.id);
      }
      final dateIndexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_startDate');
      await dateIndexBox.clear();
      await dateIndexBox.putAll(dateIndex);
    } catch (e) {
      // Index building is optional - don't throw
      // Error will be logged if AppLogger is available
    }
  }
}
