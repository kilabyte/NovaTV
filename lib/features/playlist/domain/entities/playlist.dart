import 'package:equatable/equatable.dart';

/// Represents an M3U playlist
class Playlist extends Equatable {
  /// Unique identifier for the playlist
  final String id;

  /// User-defined name for the playlist
  final String name;

  /// URL to the M3U playlist file
  final String url;

  /// Optional EPG URL associated with this playlist
  final String? epgUrl;

  /// Last time the playlist was refreshed
  final DateTime? lastRefreshed;

  /// Number of channels in this playlist
  final int channelCount;

  /// Whether auto-refresh is enabled for this playlist
  final bool autoRefresh;

  /// Auto-refresh interval in hours
  final int refreshIntervalHours;

  /// Whether this playlist is currently being loaded/refreshed
  final bool isLoading;

  /// Error message if last refresh failed
  final String? lastError;

  /// Date when the playlist was added
  final DateTime createdAt;

  /// Custom user agent for this playlist
  final String? userAgent;

  /// Custom headers for this playlist
  final Map<String, String>? headers;

  const Playlist({
    required this.id,
    required this.name,
    required this.url,
    required this.createdAt,
    this.epgUrl,
    this.lastRefreshed,
    this.channelCount = 0,
    this.autoRefresh = true,
    this.refreshIntervalHours = 24,
    this.isLoading = false,
    this.lastError,
    this.userAgent,
    this.headers,
  });

  /// Check if playlist needs refresh based on interval
  bool get needsRefresh {
    if (!autoRefresh || lastRefreshed == null) return true;
    final difference = DateTime.now().difference(lastRefreshed!);
    return difference.inHours >= refreshIntervalHours;
  }

  /// Check if playlist has associated EPG
  bool get hasEpg => epgUrl != null && epgUrl!.isNotEmpty;

  /// Create a copy with modified fields
  Playlist copyWith({
    String? id,
    String? name,
    String? url,
    String? epgUrl,
    DateTime? lastRefreshed,
    int? channelCount,
    bool? autoRefresh,
    int? refreshIntervalHours,
    bool? isLoading,
    String? lastError,
    DateTime? createdAt,
    String? userAgent,
    Map<String, String>? headers,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      epgUrl: epgUrl ?? this.epgUrl,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      channelCount: channelCount ?? this.channelCount,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshIntervalHours: refreshIntervalHours ?? this.refreshIntervalHours,
      isLoading: isLoading ?? this.isLoading,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      userAgent: userAgent ?? this.userAgent,
      headers: headers ?? this.headers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        url,
        epgUrl,
        lastRefreshed,
        channelCount,
        autoRefresh,
        refreshIntervalHours,
        isLoading,
        lastError,
        createdAt,
        userAgent,
        headers,
      ];
}
