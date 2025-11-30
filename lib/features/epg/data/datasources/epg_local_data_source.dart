import 'package:hive_ce/hive.dart';

import '../../domain/entities/epg_channel.dart';
import '../../domain/entities/program.dart';
import '../models/epg_channel_model.dart';
import '../models/epg_metadata_model.dart';
import '../models/program_model.dart';

/// Local data source for EPG data using Hive
abstract class EpgLocalDataSource {
  /// Save EPG data for a playlist
  Future<void> saveEpgData({
    required String playlistId,
    required String sourceUrl,
    required DateTime? generatedAt,
    required List<EpgChannel> channels,
    required List<Program> programs,
  });

  /// Get all programs for a playlist
  Future<List<Program>> getPrograms(String playlistId);

  /// Get programs for a specific channel
  Future<List<Program>> getProgramsForChannel(String playlistId, String channelId);

  /// Get programs for a time range
  Future<List<Program>> getProgramsInRange(
    String playlistId,
    DateTime start,
    DateTime end,
  );

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
}

class EpgLocalDataSourceImpl implements EpgLocalDataSource {
  static const String _programsBoxPrefix = 'epg_programs_';
  static const String _channelsBoxPrefix = 'epg_channels_';
  static const String _metadataBoxName = 'epg_metadata';

  @override
  Future<void> saveEpgData({
    required String playlistId,
    required String sourceUrl,
    required DateTime? generatedAt,
    required List<EpgChannel> channels,
    required List<Program> programs,
  }) async {
    // Save programs
    final programsBox = await Hive.openBox<ProgramModel>('$_programsBoxPrefix$playlistId');
    await programsBox.clear();

    final programModels = programs.map((p) => ProgramModel.fromEntity(p)).toList();
    final programMap = {for (var p in programModels) p.id: p};
    await programsBox.putAll(programMap);

    // Save channels
    final channelsBox = await Hive.openBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
    await channelsBox.clear();

    final channelModels = channels.map((c) => EpgChannelModel.fromEntity(c)).toList();
    final channelMap = {for (var c in channelModels) c.id: c};
    await channelsBox.putAll(channelMap);

    // Save metadata
    final metadataBox = await Hive.openBox<EpgMetadataModel>(_metadataBoxName);
    final metadata = EpgMetadataModel(
      sourceUrl: sourceUrl,
      playlistId: playlistId,
      generatedAt: generatedAt,
      fetchedAt: DateTime.now(),
      channelCount: channels.length,
      programCount: programs.length,
    );
    await metadataBox.put(playlistId, metadata);
  }

  @override
  Future<List<Program>> getPrograms(String playlistId) async {
    final box = await Hive.openBox<ProgramModel>('$_programsBoxPrefix$playlistId');
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Program>> getProgramsForChannel(String playlistId, String channelId) async {
    final programs = await getPrograms(playlistId);
    return programs.where((p) => p.channelId == channelId).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<List<Program>> getProgramsInRange(
    String playlistId,
    DateTime start,
    DateTime end,
  ) async {
    final programs = await getPrograms(playlistId);
    return programs.where((p) {
      return p.end.isAfter(start) && p.start.isBefore(end);
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<Program?> getCurrentProgram(String playlistId, String channelId) async {
    final programs = await getProgramsForChannel(playlistId, channelId);
    final now = DateTime.now();
    try {
      return programs.firstWhere(
        (p) => p.start.isBefore(now) && p.end.isAfter(now),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<EpgChannel>> getEpgChannels(String playlistId) async {
    final box = await Hive.openBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<EpgMetadataModel?> getEpgMetadata(String playlistId) async {
    final box = await Hive.openBox<EpgMetadataModel>(_metadataBoxName);
    return box.get(playlistId);
  }

  @override
  Future<void> deleteEpgData(String playlistId) async {
    // Delete programs
    if (await Hive.boxExists('$_programsBoxPrefix$playlistId')) {
      final programsBox = await Hive.openBox<ProgramModel>('$_programsBoxPrefix$playlistId');
      await programsBox.deleteFromDisk();
    }

    // Delete channels
    if (await Hive.boxExists('$_channelsBoxPrefix$playlistId')) {
      final channelsBox = await Hive.openBox<EpgChannelModel>('$_channelsBoxPrefix$playlistId');
      await channelsBox.deleteFromDisk();
    }

    // Delete metadata
    final metadataBox = await Hive.openBox<EpgMetadataModel>(_metadataBoxName);
    await metadataBox.delete(playlistId);
  }

  @override
  Future<void> cleanupOldPrograms({int daysToKeep = 7}) async {
    final metadataBox = await Hive.openBox<EpgMetadataModel>(_metadataBoxName);
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));

    for (final metadata in metadataBox.values) {
      final programsBox = await Hive.openBox<ProgramModel>(
        '$_programsBoxPrefix${metadata.playlistId}',
      );

      final keysToDelete = <dynamic>[];
      for (final entry in programsBox.toMap().entries) {
        if (entry.value.end.isBefore(cutoff)) {
          keysToDelete.add(entry.key);
        }
      }

      await programsBox.deleteAll(keysToDelete);
    }
  }
}
