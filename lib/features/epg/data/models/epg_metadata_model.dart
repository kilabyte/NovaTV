import 'package:hive_ce/hive.dart';

part 'epg_metadata_model.g.dart';

/// Stores metadata about an EPG source
@HiveType(typeId: 5)
class EpgMetadataModel extends HiveObject {
  @HiveField(0)
  final String sourceUrl;

  @HiveField(1)
  final String playlistId;

  @HiveField(2)
  final DateTime? generatedAt;

  @HiveField(3)
  final DateTime fetchedAt;

  @HiveField(4)
  final int channelCount;

  @HiveField(5)
  final int programCount;

  @HiveField(6)
  final String? lastError;

  EpgMetadataModel({
    required this.sourceUrl,
    required this.playlistId,
    this.generatedAt,
    required this.fetchedAt,
    required this.channelCount,
    required this.programCount,
    this.lastError,
  });
}
