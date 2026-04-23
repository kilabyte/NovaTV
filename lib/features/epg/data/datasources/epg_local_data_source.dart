import 'package:flutter/foundation.dart';
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
      final models = <ProgramModel>[];
      for (final key in indexedKeys) {
        final model = box.get(key);
        if (model != null) models.add(model);
      }
      models.sort((a, b) => a.start.compareTo(b.start));
      return models.map((m) => m.toEntity()).toList(growable: false);
    }

    // Fallback: filter on model fields first, only hydrate entities we keep.
    // Compare case-insensitively to match the indexed path (mixed-case tvg-ids
    // like "BBC.One" vs "bbc.one" are the same channel).
    final needle = channelId.toLowerCase();
    final models = <ProgramModel>[];
    for (final model in box.values) {
      if (model.channelId.toLowerCase() == needle) models.add(model);
    }
    models.sort((a, b) => a.start.compareTo(b.start));
    return models.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<List<Program>> getProgramsInRange(String playlistId, DateTime start, DateTime end) async {
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');

    // Try to use date index if available for faster lookup
    final dateKeys = <String>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final dateKey = '${current.year}${current.month.toString().padLeft(2, '0')}${current.day.toString().padLeft(2, '0')}';
      dateKeys.add(dateKey);
      current = current.add(const Duration(days: 1));
    }

    final indexedKeys = <dynamic>{};
    for (final dateKey in dateKeys) {
      final keys = await HiveIndexHelper.getIndexedKeys(baseBoxName: '$_programsBoxPrefix$playlistId', fieldName: 'startDate', fieldValue: dateKey);
      indexedKeys.addAll(keys);
    }

    if (indexedKeys.isNotEmpty) {
      // Filter on the model before calling toEntity() so we don't allocate
      // Program entities for programs outside the range.
      final models = <ProgramModel>[];
      for (final key in indexedKeys) {
        final model = box.get(key);
        if (model != null && model.end.isAfter(start) && model.start.isBefore(end)) {
          models.add(model);
        }
      }
      models.sort((a, b) => a.start.compareTo(b.start));
      return models.map((m) => m.toEntity()).toList(growable: false);
    }

    final models = <ProgramModel>[];
    for (final model in box.values) {
      if (model.end.isAfter(start) && model.start.isBefore(end)) {
        models.add(model);
      }
    }
    models.sort((a, b) => a.start.compareTo(b.start));
    return models.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<Program?> getCurrentProgram(String playlistId, String channelId) async {
    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');
    final now = DateTime.now();

    final indexedKeys = await HiveIndexHelper.getIndexedKeys(
      baseBoxName: '$_programsBoxPrefix$playlistId',
      fieldName: 'channelId',
      fieldValue: channelId,
    );

    // Scan only the candidate models. Filter on model fields (no toEntity) and
    // short-circuit on the first match; we only hydrate the winning entity.
    if (indexedKeys.isNotEmpty) {
      for (final key in indexedKeys) {
        final m = box.get(key);
        if (m != null && m.start.isBefore(now) && m.end.isAfter(now)) {
          return m.toEntity();
        }
      }
      return null;
    }
    final needle = channelId.toLowerCase();
    for (final m in box.values) {
      if (m.channelId.toLowerCase() == needle && m.start.isBefore(now) && m.end.isAfter(now)) {
        return m.toEntity();
      }
    }
    return null;
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

      // Iterate keys and fetch individually, instead of toMap() which hydrates
      // the entire box (can be hundreds of MB) into a single Map at once.
      final keysToDelete = <dynamic>[];
      for (final key in programsBox.keys) {
        final model = programsBox.get(key);
        if (model != null && model.end.isBefore(cutoff)) {
          keysToDelete.add(key);
        }
      }

      if (keysToDelete.isNotEmpty) {
        await programsBox.deleteAll(keysToDelete);
      }
    }
  }

  @override
  Future<List<Program>> searchPrograms(String playlistId, String query) async {
    final lowerQuery = query.toLowerCase();
    final now = DateTime.now();

    final box = await safeOpenBox<ProgramModel>('$_programsBoxPrefix$playlistId');

    // Filter on the model, only hydrate matches.
    final models = <ProgramModel>[];
    for (final model in box.values) {
      if (model.end.isBefore(now)) continue;

      final title = model.title.toLowerCase();
      final description = model.description?.toLowerCase() ?? '';
      final category = model.category?.toLowerCase() ?? '';

      if (title.contains(lowerQuery) || description.contains(lowerQuery) || category.contains(lowerQuery)) {
        models.add(model);
      }
    }

    models.sort((a, b) => a.start.compareTo(b.start));
    return models.map((m) => m.toEntity()).toList(growable: false);
  }

  /// Build indexes for programs in a playlist.
  /// The tuple extraction runs in a compute isolate so we don't burn the main
  /// isolate grouping hundreds of thousands of entries after each EPG refresh.
  Future<void> _buildProgramIndexes(String programsBoxName, List<ProgramModel> programs) async {
    try {
      // Convert to plain data before sending to the isolate; HiveObjects hold
      // a reference to their box and can't cross isolate boundaries.
      final tuples = programs
          .map((p) => _IndexTuple(p.id, p.channelId, p.start.year, p.start.month, p.start.day))
          .toList(growable: false);

      final result = await compute(_computeProgramIndexes, tuples);

      final channelIdIndexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_channelId');
      await channelIdIndexBox.clear();
      await channelIdIndexBox.putAll(result.channelIdIndex);

      final dateIndexBox = await safeOpenBox<List<dynamic>>('${programsBoxName}_index_startDate');
      await dateIndexBox.clear();
      await dateIndexBox.putAll(result.dateIndex);
    } catch (_) {
      // Index building is optional - don't throw.
    }
  }
}

/// Tuple sent to the index compute isolate. Plain fields only so it serializes
/// cheaply and can't drag in Hive adapters or controllers.
class _IndexTuple {
  final String id;
  final String channelId;
  final int year;
  final int month;
  final int day;
  const _IndexTuple(this.id, this.channelId, this.year, this.month, this.day);
}

class _IndexResult {
  final Map<String, List<dynamic>> channelIdIndex;
  final Map<String, List<dynamic>> dateIndex;
  const _IndexResult(this.channelIdIndex, this.dateIndex);
}

@pragma('vm:entry-point')
_IndexResult _computeProgramIndexes(List<_IndexTuple> tuples) {
  final channelIdIndex = <String, List<dynamic>>{};
  final dateIndex = <String, List<dynamic>>{};
  for (final t in tuples) {
    // HiveIndexHelper.getIndexedKeys lowercases the lookup key on read, so we
    // must store under the lowercased variant too; otherwise mixed-case
    // tvg-ids (e.g. "BBC.One") silently miss the index.
    channelIdIndex.putIfAbsent(t.channelId.toLowerCase(), () => <dynamic>[]).add(t.id);
    final dateKey = '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
    dateIndex.putIfAbsent(dateKey, () => <dynamic>[]).add(t.id);
  }
  return _IndexResult(channelIdIndex, dateIndex);
}
