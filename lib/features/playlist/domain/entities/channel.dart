import 'package:equatable/equatable.dart';

/// Represents an IPTV channel parsed from M3U playlist
class Channel extends Equatable {
  /// Unique identifier for the channel
  final String id;

  /// Channel display name
  final String name;

  /// Stream URL
  final String url;

  /// EPG channel ID (tvg-id attribute)
  final String? tvgId;

  /// Channel name from EPG (tvg-name attribute)
  final String? tvgName;

  /// Channel logo URL (tvg-logo attribute)
  final String? logoUrl;

  /// Group/category name (group-title attribute)
  final String? group;

  /// Language (tvg-language attribute)
  final String? language;

  /// Country (tvg-country attribute)
  final String? country;

  /// Shift/offset for EPG (tvg-shift attribute)
  final int? tvgShift;

  /// User agent for stream requests
  final String? userAgent;

  /// Referrer for stream requests
  final String? referrer;

  /// Additional HTTP headers for stream requests
  final Map<String, String>? headers;

  /// License URL for DRM content
  final String? licenseUrl;

  /// License type (e.g., Widevine, PlayReady)
  final String? licenseType;

  /// Whether this channel is marked as favorite
  final bool isFavorite;

  /// Channel number for ordering
  final int? channelNumber;

  /// Playlist ID this channel belongs to
  final String playlistId;

  /// Catchup type (timeshift, archive, etc.)
  final String? catchupType;

  /// Catchup source URL template
  final String? catchupSource;

  /// Catchup days available
  final int? catchupDays;

  const Channel({
    required this.id,
    required this.name,
    required this.url,
    required this.playlistId,
    this.tvgId,
    this.tvgName,
    this.logoUrl,
    this.group,
    this.language,
    this.country,
    this.tvgShift,
    this.userAgent,
    this.referrer,
    this.headers,
    this.licenseUrl,
    this.licenseType,
    this.isFavorite = false,
    this.channelNumber,
    this.catchupType,
    this.catchupSource,
    this.catchupDays,
  });

  /// Get the effective display name (tvgName if available, otherwise name)
  String get displayName => tvgName ?? name;

  /// Get the effective EPG ID (tvgId if available, otherwise id)
  String get epgId => tvgId ?? id;

  /// Check if channel has catchup support
  bool get hasCatchup =>
      catchupType != null && catchupSource != null && catchupDays != null && catchupDays! > 0;

  /// Create a copy with modified fields
  Channel copyWith({
    String? id,
    String? name,
    String? url,
    String? playlistId,
    String? tvgId,
    String? tvgName,
    String? logoUrl,
    String? group,
    String? language,
    String? country,
    int? tvgShift,
    String? userAgent,
    String? referrer,
    Map<String, String>? headers,
    String? licenseUrl,
    String? licenseType,
    bool? isFavorite,
    int? channelNumber,
    String? catchupType,
    String? catchupSource,
    int? catchupDays,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      playlistId: playlistId ?? this.playlistId,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      logoUrl: logoUrl ?? this.logoUrl,
      group: group ?? this.group,
      language: language ?? this.language,
      country: country ?? this.country,
      tvgShift: tvgShift ?? this.tvgShift,
      userAgent: userAgent ?? this.userAgent,
      referrer: referrer ?? this.referrer,
      headers: headers ?? this.headers,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseType: licenseType ?? this.licenseType,
      isFavorite: isFavorite ?? this.isFavorite,
      channelNumber: channelNumber ?? this.channelNumber,
      catchupType: catchupType ?? this.catchupType,
      catchupSource: catchupSource ?? this.catchupSource,
      catchupDays: catchupDays ?? this.catchupDays,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        url,
        playlistId,
        tvgId,
        tvgName,
        logoUrl,
        group,
        language,
        country,
        tvgShift,
        userAgent,
        referrer,
        headers,
        licenseUrl,
        licenseType,
        isFavorite,
        channelNumber,
        catchupType,
        catchupSource,
        catchupDays,
      ];
}
