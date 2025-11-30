import 'package:hive_ce/hive.dart';

import '../../domain/entities/playlist.dart';

part 'playlist_model.g.dart';

/// Hive model for Playlist entity
@HiveType(typeId: 0)
class PlaylistModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String url;

  @HiveField(3)
  final String? epgUrl;

  @HiveField(4)
  final DateTime? lastRefreshed;

  @HiveField(5)
  final int channelCount;

  @HiveField(6)
  final bool autoRefresh;

  @HiveField(7)
  final int refreshIntervalHours;

  @HiveField(8)
  final String? lastError;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String? userAgent;

  @HiveField(11)
  final Map<String, String>? headers;

  PlaylistModel({
    required this.id,
    required this.name,
    required this.url,
    this.epgUrl,
    this.lastRefreshed,
    this.channelCount = 0,
    this.autoRefresh = true,
    this.refreshIntervalHours = 24,
    this.lastError,
    required this.createdAt,
    this.userAgent,
    this.headers,
  });

  /// Convert to domain entity
  Playlist toEntity() {
    return Playlist(
      id: id,
      name: name,
      url: url,
      epgUrl: epgUrl,
      lastRefreshed: lastRefreshed,
      channelCount: channelCount,
      autoRefresh: autoRefresh,
      refreshIntervalHours: refreshIntervalHours,
      lastError: lastError,
      createdAt: createdAt,
      userAgent: userAgent,
      headers: headers,
    );
  }

  /// Create from domain entity
  factory PlaylistModel.fromEntity(Playlist playlist) {
    return PlaylistModel(
      id: playlist.id,
      name: playlist.name,
      url: playlist.url,
      epgUrl: playlist.epgUrl,
      lastRefreshed: playlist.lastRefreshed,
      channelCount: playlist.channelCount,
      autoRefresh: playlist.autoRefresh,
      refreshIntervalHours: playlist.refreshIntervalHours,
      lastError: playlist.lastError,
      createdAt: playlist.createdAt,
      userAgent: playlist.userAgent,
      headers: playlist.headers,
    );
  }

  /// Create copy with new values
  PlaylistModel copyWith({
    String? id,
    String? name,
    String? url,
    String? epgUrl,
    DateTime? lastRefreshed,
    int? channelCount,
    bool? autoRefresh,
    int? refreshIntervalHours,
    String? lastError,
    DateTime? createdAt,
    String? userAgent,
    Map<String, String>? headers,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      epgUrl: epgUrl ?? this.epgUrl,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      channelCount: channelCount ?? this.channelCount,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshIntervalHours: refreshIntervalHours ?? this.refreshIntervalHours,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      userAgent: userAgent ?? this.userAgent,
      headers: headers ?? this.headers,
    );
  }
}
